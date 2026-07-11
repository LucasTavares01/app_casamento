import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../banco/banco_instancia.dart';
import '../banco/banco_local.dart';
import '../modelos/modelos.dart';
import 'dispositivo_servico.dart';
import 'sessao_servico.dart';

/// Serviço principal de dados do aplicativo.
///
/// Mesas, convidados e check-in utilizam primeiro o banco SQLite local.
/// Staff e chat ainda continuam utilizando diretamente o Supabase e serão
/// convertidos para offline em uma etapa posterior.
class SupabaseServico {
  final SupabaseClient _supabase = Supabase.instance.client;
  final BancoLocal _banco = bancoLocal;
  final Uuid _uuid = const Uuid();

  // ============================================================
  // MESAS — LEITURA LOCAL
  // ============================================================

  /// Retorna as mesas armazenadas no celular.
  ///
  /// O stream atualiza automaticamente as telas quando uma mesa for
  /// adicionada, editada, excluída ou recebida durante a sincronização.
  Stream<List<Mesa>> listarMesas() {
    final consulta = _banco.select(_banco.mesasLocais)
      ..where((tabela) => tabela.excluido.equals(false))
      ..orderBy([(tabela) => OrderingTerm.asc(tabela.numero)]);

    return consulta.watch().map((registros) {
      return registros.map((registro) {
        return Mesa(
          id: registro.id,
          numero: registro.numero,
          detalhe: registro.detalhe,
        );
      }).toList();
    });
  }

  /// Adiciona uma mesa imediatamente no banco local.
  ///
  /// A operação também fica registrada na fila para ser enviada ao
  /// Supabase quando o aplicativo estiver online.
  Future<void> adicionarMesa(int numero, String? detalhe) async {
    final usuarioId = _obterUsuarioAtualId();
    final id = _uuid.v4();
    final agora = DateTime.now().toUtc();
    final detalheNormalizado = _normalizarTextoOpcional(detalhe);

    final payload = <String, dynamic>{
      'id': id,
      'numero': numero,
      'detalhe': detalheNormalizado,
      'created_at': agora.toIso8601String(),
      'updated_at': agora.toIso8601String(),
      'deleted_at': null,
      'modificado_por_usuario_id': usuarioId,
    };

    await _banco.transaction(() async {
      await _banco
          .into(_banco.mesasLocais)
          .insert(
            MesasLocaisCompanion.insert(
              id: id,
              numero: Value(numero),
              detalhe: Value(detalheNormalizado),
              criadoEm: agora,
              atualizadoEm: agora,
              excluido: const Value(false),
            ),
          );

      await _registrarOperacaoPendente(
        entidade: 'mesa',
        entidadeId: id,
        tipoOperacao: 'inserir',
        payload: payload,
      );
    });
  }

  /// Edita uma mesa no banco local.
  Future<void> editarMesa(String id, int numero, String? detalhe) async {
    final usuarioId = _obterUsuarioAtualId();
    final agora = DateTime.now().toUtc();
    final detalheNormalizado = _normalizarTextoOpcional(detalhe);

    final mesaAtual = await _buscarMesaLocal(id);

    if (mesaAtual == null || mesaAtual.excluido) {
      throw StateError('A mesa não foi encontrada no banco local.');
    }

    final payload = <String, dynamic>{
      'id': id,
      'numero': numero,
      'detalhe': detalheNormalizado,
      'created_at': mesaAtual.criadoEm.toUtc().toIso8601String(),
      'updated_at': agora.toIso8601String(),
      'deleted_at': null,
      'modificado_por_usuario_id': usuarioId,
    };

    await _banco.transaction(() async {
      await (_banco.update(
        _banco.mesasLocais,
      )..where((tabela) => tabela.id.equals(id))).write(
        MesasLocaisCompanion(
          numero: Value(numero),
          detalhe: Value(detalheNormalizado),
          atualizadoEm: Value(agora),
          excluido: const Value(false),
        ),
      );

      await _registrarOperacaoPendente(
        entidade: 'mesa',
        entidadeId: id,
        tipoOperacao: 'atualizar',
        payload: payload,
      );
    });
  }

  /// Exclui uma mesa de forma lógica.
  ///
  /// Os convidados alocados nela ficam sem mesa, como já era informado
  /// pela tela de confirmação.
  Future<void> excluirMesa(String id) async {
    final usuarioId = _obterUsuarioAtualId();
    final agora = DateTime.now().toUtc();

    final mesaAtual = await _buscarMesaLocal(id);

    if (mesaAtual == null || mesaAtual.excluido) {
      return;
    }

    final convidadosDaMesa =
        await (_banco.select(_banco.convidadosLocais)..where(
              (tabela) =>
                  tabela.mesaId.equals(id) & tabela.excluido.equals(false),
            ))
            .get();

    final payloadMesa = <String, dynamic>{
      'id': id,
      'numero': mesaAtual.numero,
      'detalhe': mesaAtual.detalhe,
      'created_at': mesaAtual.criadoEm.toUtc().toIso8601String(),
      'updated_at': agora.toIso8601String(),
      'deleted_at': agora.toIso8601String(),
      'modificado_por_usuario_id': usuarioId,
    };

    await _banco.transaction(() async {
      await (_banco.update(
        _banco.mesasLocais,
      )..where((tabela) => tabela.id.equals(id))).write(
        MesasLocaisCompanion(
          atualizadoEm: Value(agora),
          excluido: const Value(true),
        ),
      );

      await _registrarOperacaoPendente(
        entidade: 'mesa',
        entidadeId: id,
        tipoOperacao: 'excluir',
        payload: payloadMesa,
      );

      for (final convidado in convidadosDaMesa) {
        await (_banco.update(
          _banco.convidadosLocais,
        )..where((tabela) => tabela.id.equals(convidado.id))).write(
          ConvidadosLocaisCompanion(
            mesaId: const Value<String?>(null),
            atualizadoEm: Value(agora),
          ),
        );

        final payloadConvidado = <String, dynamic>{
          'id': convidado.id,
          'nome': convidado.nome,
          'mesa_id': null,
          'chegou': convidado.chegou,
          'created_at': convidado.criadoEm.toUtc().toIso8601String(),
          'updated_at': agora.toIso8601String(),
          'deleted_at': null,
          'modificado_por_usuario_id': usuarioId,
        };

        await _registrarOperacaoPendente(
          entidade: 'convidado',
          entidadeId: convidado.id,
          tipoOperacao: 'atualizar',
          payload: payloadConvidado,
        );
      }
    });
  }

  // ============================================================
  // CONVIDADOS — LEITURA LOCAL
  // ============================================================

  Stream<List<Convidado>> listarConvidados() {
    final consulta = _banco.select(_banco.convidadosLocais)
      ..where((tabela) => tabela.excluido.equals(false))
      ..orderBy([(tabela) => OrderingTerm.asc(tabela.nome)]);

    return consulta.watch().map((registros) {
      return registros.map((registro) {
        return Convidado(
          id: registro.id,
          nome: registro.nome,
          mesaId: registro.mesaId,
          chegou: registro.chegou,
          temConflito: registro.temConflito,
          eventosAtuaisIds: _decodificarListaDeIds(registro.eventosAtuaisJson),
        );
      }).toList();
    });
  }

  /// Adiciona um convidado no banco local.
  Future<void> adicionarConvidado(String nome, String? mesaId) async {
    final usuarioId = _obterUsuarioAtualId();
    final id = _uuid.v4();
    final agora = DateTime.now().toUtc();
    final nomeNormalizado = nome.trim();

    final payload = <String, dynamic>{
      'id': id,
      'nome': nomeNormalizado,
      'mesa_id': mesaId,
      'chegou': false,
      'created_at': agora.toIso8601String(),
      'updated_at': agora.toIso8601String(),
      'deleted_at': null,
      'modificado_por_usuario_id': usuarioId,
    };

    await _banco.transaction(() async {
      await _banco
          .into(_banco.convidadosLocais)
          .insert(
            ConvidadosLocaisCompanion.insert(
              id: id,
              nome: nomeNormalizado,
              mesaId: Value(mesaId),
              chegou: const Value(false),
              temConflito: const Value(false),
              eventosAtuaisJson: const Value('[]'),
              criadoEm: agora,
              atualizadoEm: agora,
              excluido: const Value(false),
            ),
          );

      await _registrarOperacaoPendente(
        entidade: 'convidado',
        entidadeId: id,
        tipoOperacao: 'inserir',
        payload: payload,
      );
    });
  }

  /// Edita um convidado no banco local.
  Future<void> editarConvidado(String id, String nome, String? mesaId) async {
    final usuarioId = _obterUsuarioAtualId();
    final agora = DateTime.now().toUtc();
    final nomeNormalizado = nome.trim();

    final convidadoAtual = await _buscarConvidadoLocal(id);

    if (convidadoAtual == null || convidadoAtual.excluido) {
      throw StateError('O convidado não foi encontrado no banco local.');
    }

    final payload = <String, dynamic>{
      'id': id,
      'nome': nomeNormalizado,
      'mesa_id': mesaId,
      'chegou': convidadoAtual.chegou,
      'created_at': convidadoAtual.criadoEm.toUtc().toIso8601String(),
      'updated_at': agora.toIso8601String(),
      'deleted_at': null,
      'modificado_por_usuario_id': usuarioId,
    };

    await _banco.transaction(() async {
      await (_banco.update(
        _banco.convidadosLocais,
      )..where((tabela) => tabela.id.equals(id))).write(
        ConvidadosLocaisCompanion(
          nome: Value(nomeNormalizado),
          mesaId: Value(mesaId),
          atualizadoEm: Value(agora),
          excluido: const Value(false),
        ),
      );

      await _registrarOperacaoPendente(
        entidade: 'convidado',
        entidadeId: id,
        tipoOperacao: 'atualizar',
        payload: payload,
      );
    });
  }

  /// Exclui um convidado de forma lógica.
  Future<void> excluirConvidado(String id) async {
    final usuarioId = _obterUsuarioAtualId();
    final agora = DateTime.now().toUtc();

    final convidadoAtual = await _buscarConvidadoLocal(id);

    if (convidadoAtual == null || convidadoAtual.excluido) {
      return;
    }

    final payload = <String, dynamic>{
      'id': id,
      'nome': convidadoAtual.nome,
      'mesa_id': convidadoAtual.mesaId,
      'chegou': convidadoAtual.chegou,
      'created_at': convidadoAtual.criadoEm.toUtc().toIso8601String(),
      'updated_at': agora.toIso8601String(),
      'deleted_at': agora.toIso8601String(),
      'modificado_por_usuario_id': usuarioId,
    };

    await _banco.transaction(() async {
      await (_banco.update(
        _banco.convidadosLocais,
      )..where((tabela) => tabela.id.equals(id))).write(
        ConvidadosLocaisCompanion(
          atualizadoEm: Value(agora),
          excluido: const Value(true),
        ),
      );

      await _registrarOperacaoPendente(
        entidade: 'convidado',
        entidadeId: id,
        tipoOperacao: 'excluir',
        payload: payload,
      );
    });
  }

  // ============================================================
  // USUÁRIOS E HISTÓRICO LOCAL DE CHECK-IN
  // ============================================================

  /// Retorna os quatro usuários armazenados no banco local.
  ///
  /// Este stream permite que a interface transforme o ID do autor em nome.
  Stream<List<UsuarioApp>> listarUsuariosApp() {
    final consulta = _banco.select(_banco.usuariosAppLocais)
      ..where((tabela) => tabela.ativo.equals(true))
      ..orderBy([(tabela) => OrderingTerm.asc(tabela.ordem)]);

    return consulta.watch().map((registros) {
      return registros.map((registro) {
        return UsuarioApp(
          id: registro.id,
          nome: registro.nome,
          ordem: registro.ordem,
          ativo: registro.ativo,
        );
      }).toList();
    });
  }

  /// Retorna todo o histórico de check-in armazenado no celular.
  ///
  /// O histórico inclui ações ainda não sincronizadas e ações já recebidas
  /// do Supabase.
  Stream<List<EventoCheckin>> listarEventosCheckin() {
    final consulta = _banco.select(_banco.eventosCheckinLocais)
      ..orderBy([
        (tabela) => OrderingTerm.asc(tabela.dataDispositivo),
        (tabela) => OrderingTerm.asc(tabela.sequenciaDispositivo),
      ]);

    return consulta.watch().map((registros) {
      return registros.map((registro) {
        return EventoCheckin(
          id: registro.id,
          convidadoId: registro.convidadoId,
          usuarioId: registro.usuarioId,
          tipoAcao: registro.tipoAcao,
          estadoResultante: registro.estadoResultante,
          eventosBaseIds: _decodificarListaDeIds(registro.eventosBaseJson),
          dataDispositivo: registro.dataDispositivo.toLocal(),
          sequenciaDispositivo: registro.sequenciaDispositivo,
          dispositivoId: registro.dispositivoId,
          dataServidor: registro.dataServidor?.toLocal(),
          observacao: registro.observacao,
          sincronizado: registro.sincronizado,
        );
      }).toList();
    });
  }

  // ============================================================
  // CHECK-IN — AÇÕES LOCAIS COM AUTORIA
  // ============================================================

  /// Confirma que o convidado chegou.
  ///
  /// Cria um evento separado, contendo o usuário, o aparelho e o horário.
  Future<void> confirmarChegada(String id) async {
    await _registrarAcaoCheckin(
      convidadoId: id,
      chegou: true,
      tipoAcao: 'confirmou_chegada',
    );
  }

  /// Remove a confirmação de chegada.
  Future<void> removerChegada(String id) async {
    await _registrarAcaoCheckin(
      convidadoId: id,
      chegou: false,
      tipoAcao: 'removeu_chegada',
    );
  }

  /// Resolve um conflito escolhendo o estado correto do convidado.
  ///
  /// O novo evento será criado com base em todos os eventos atuais.
  /// Assim, as ações conflitantes continuam no histórico, mas deixam de
  /// representar o estado atual.
  Future<void> resolverConflito({
    required String convidadoId,
    required bool presente,
  }) async {
    await _registrarAcaoCheckin(
      convidadoId: convidadoId,
      chegou: presente,
      tipoAcao: presente ? 'resolveu_como_presente' : 'resolveu_como_ausente',
    );
  }

  Future<void> _registrarAcaoCheckin({
    required String convidadoId,
    required bool chegou,
    required String tipoAcao,
  }) async {
    final usuarioId = _obterUsuarioAtualId();

    final dispositivoId = await DispositivoServico.instance.obterOuCriarId();

    final sequencia = await DispositivoServico.instance.proximaSequencia();

    final convidadoAtual = await _buscarConvidadoLocal(convidadoId);

    if (convidadoAtual == null || convidadoAtual.excluido) {
      throw StateError('O convidado não foi encontrado no banco local.');
    }

    final agora = DateTime.now().toUtc();
    final eventoId = _uuid.v4();

    final eventosBase = _decodificarListaDeIds(
      convidadoAtual.eventosAtuaisJson,
    );

    final eventosBaseJson = jsonEncode(eventosBase);

    final eventosAtuaisJson = jsonEncode([eventoId]);

    final payloadEvento = <String, dynamic>{
      'id': eventoId,
      'convidado_id': convidadoId,
      'usuario_id': usuarioId,
      'tipo_acao': tipoAcao,
      'estado_resultante': chegou,
      'eventos_base': eventosBase,
      'data_dispositivo': agora.toIso8601String(),
      'sequencia_dispositivo': sequencia,
      'dispositivo_id': dispositivoId,
      'observacao': null,
      'created_at': agora.toIso8601String(),
    };

    await _banco.transaction(() async {
      await _banco
          .into(_banco.eventosCheckinLocais)
          .insert(
            EventosCheckinLocaisCompanion.insert(
              id: eventoId,
              convidadoId: convidadoId,
              usuarioId: usuarioId,
              tipoAcao: tipoAcao,
              estadoResultante: chegou,
              eventosBaseJson: Value(eventosBaseJson),
              dataDispositivo: agora,
              sequenciaDispositivo: sequencia,
              dispositivoId: dispositivoId,
              observacao: const Value<String?>(null),
              sincronizado: const Value(false),
            ),
          );

      await (_banco.update(
        _banco.convidadosLocais,
      )..where((tabela) => tabela.id.equals(convidadoId))).write(
        ConvidadosLocaisCompanion(
          chegou: Value(chegou),
          temConflito: const Value(false),
          eventosAtuaisJson: Value(eventosAtuaisJson),
          atualizadoEm: Value(agora),
        ),
      );

      await _registrarOperacaoPendente(
        entidade: 'evento_checkin',
        entidadeId: eventoId,
        tipoOperacao: 'inserir',
        payload: payloadEvento,
      );
    });
  }

  // ============================================================
  // STAFF E CHAT — AINDA ONLINE NESTA ETAPA
  // ============================================================

  Future<void> adicionarStaff(
    String nome,
    String sobrenome,
    String ocupacao,
  ) async {
    await _supabase.from('staff').insert({
      'nome': nome,
      'sobrenome': sobrenome,
      'ocupacao': ocupacao,
    });
  }

  Stream<List<Staff>> listarStaff() {
    return _supabase
        .from('staff')
        .stream(primaryKey: ['id'])
        .map((dados) => dados.map((s) => Staff.fromMap(s)).toList());
  }

  Future<void> enviarMensagem(String staffId, String mensagem) async {
    await _supabase.from('chat').insert({
      'staff_id': staffId,
      'mensagem': mensagem,
    });
  }

  Stream<List<MensagemChat>> listarMensagens() {
    return _supabase
        .from('chat')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map((dados) => dados.map((m) => MensagemChat.fromMap(m)).toList());
  }

  // ============================================================
  // MÉTODOS AUXILIARES
  // ============================================================

  /// Retorna o usuário que entrou no aplicativo.
  String _obterUsuarioAtualId() {
    final usuarioAtual = SessaoServico.instance.usuarioAtual;

    if (usuarioAtual == null) {
      throw StateError('Nenhum usuário está identificado no aplicativo.');
    }

    return usuarioAtual.id;
  }

  Future<MesaLocalRegistro?> _buscarMesaLocal(String id) {
    final consulta = _banco.select(_banco.mesasLocais)
      ..where((tabela) => tabela.id.equals(id));

    return consulta.getSingleOrNull();
  }

  Future<ConvidadoLocalRegistro?> _buscarConvidadoLocal(String id) {
    final consulta = _banco.select(_banco.convidadosLocais)
      ..where((tabela) => tabela.id.equals(id));

    return consulta.getSingleOrNull();
  }

  /// Adiciona uma operação à fila de sincronização.
  ///
  /// Caso a mesma entidade já tenha uma operação pendente, a fila mantém
  /// somente o estado mais recente.
  Future<void> _registrarOperacaoPendente({
    required String entidade,
    required String entidadeId,
    required String tipoOperacao,
    required Map<String, dynamic> payload,
  }) async {
    final consulta = _banco.select(_banco.operacoesPendentesLocais)
      ..where(
        (tabela) =>
            tabela.entidade.equals(entidade) &
            tabela.entidadeId.equals(entidadeId),
      );

    final operacoesExistentes = await consulta.get();

    var tipoFinal = tipoOperacao;

    final jaEraInsercao = operacoesExistentes.any(
      (operacao) => operacao.tipoOperacao == 'inserir',
    );

    if (jaEraInsercao && tipoOperacao != 'excluir') {
      tipoFinal = 'inserir';
    }

    await (_banco.delete(_banco.operacoesPendentesLocais)..where(
          (tabela) =>
              tabela.entidade.equals(entidade) &
              tabela.entidadeId.equals(entidadeId),
        ))
        .go();

    await _banco
        .into(_banco.operacoesPendentesLocais)
        .insert(
          OperacoesPendentesLocaisCompanion.insert(
            id: _uuid.v4(),
            entidade: entidade,
            entidadeId: entidadeId,
            tipoOperacao: tipoFinal,
            payloadJson: jsonEncode(payload),
            criadoEm: DateTime.now().toUtc(),
            tentativas: const Value(0),
            ultimoErro: const Value<String?>(null),
            status: const Value('pendente'),
          ),
        );
  }

  String? _normalizarTextoOpcional(String? valor) {
    final texto = valor?.trim();

    if (texto == null || texto.isEmpty) {
      return null;
    }

    return texto;
  }

  List<String> _decodificarListaDeIds(String valorJson) {
    try {
      final valor = jsonDecode(valorJson);

      if (valor is! List) {
        return [];
      }

      return valor
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
