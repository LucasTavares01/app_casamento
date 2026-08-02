import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../banco/banco_instancia.dart';
import '../banco/banco_local.dart';
import '../modelos/modelos.dart';
import 'dispositivo_servico.dart';
import 'casamento_atual_servico.dart';
import 'sessao_servico.dart';
import 'sincronizacao_automatica_servico.dart';
import 'versao_registro_servico.dart';

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
    _exigirEdicao();
    final usuarioId = _obterUsuarioAtualId();
    final usuarioNome = _obterUsuarioAtualNome();
    final id = _uuid.v4();
    final agora = DateTime.now().toUtc();
    final detalheNormalizado = _normalizarTextoOpcional(detalhe);

    final payload = <String, dynamic>{
      'id': id,
      'casamento_id': _casamentoAtualId,
      'numero': numero,
      'detalhe': detalheNormalizado,
      'created_at': agora.toIso8601String(),
      'updated_at': agora.toIso8601String(),
      'deleted_at': null,
      'modificado_por_usuario_id': usuarioId,
      'modificado_por_usuario_nome': usuarioNome,
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

    _agendarSincronizacaoDepoisDaGravacao();
  }

  /// Edita uma mesa no banco local.
  Future<void> editarMesa(String id, int numero, String? detalhe) async {
    _exigirEdicao();
    final usuarioId = _obterUsuarioAtualId();
    final usuarioNome = _obterUsuarioAtualNome();
    final agora = DateTime.now().toUtc();
    final detalheNormalizado = _normalizarTextoOpcional(detalhe);

    final mesaAtual = await _buscarMesaLocal(id);

    if (mesaAtual == null || mesaAtual.excluido) {
      throw StateError('A mesa não foi encontrada no banco local.');
    }

    final versaoBase = await VersaoRegistroServico.instance.obterVersaoBase(
      entidade: 'mesa',
      id: id,
      fallback: mesaAtual.atualizadoEm,
    );

    final payload = <String, dynamic>{
      'id': id,
      'casamento_id': _casamentoAtualId,
      'numero': numero,
      'detalhe': detalheNormalizado,
      'created_at': mesaAtual.criadoEm.toUtc().toIso8601String(),
      'base_updated_at': versaoBase,
      'updated_at': agora.toIso8601String(),
      'deleted_at': null,
      'modificado_por_usuario_id': usuarioId,
      'modificado_por_usuario_nome': usuarioNome,
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

    _agendarSincronizacaoDepoisDaGravacao();
  }

  /// Exclui uma mesa de forma lógica.
  ///
  /// Os convidados alocados nela ficam sem mesa, como já era informado
  /// pela tela de confirmação.
  Future<void> excluirMesa(String id) async {
    _exigirEdicao();
    final usuarioId = _obterUsuarioAtualId();
    final usuarioNome = _obterUsuarioAtualNome();
    final agora = DateTime.now().toUtc();

    final mesaAtual = await _buscarMesaLocal(id);

    if (mesaAtual == null || mesaAtual.excluido) {
      return;
    }

    final versaoBaseMesa = await VersaoRegistroServico.instance.obterVersaoBase(
      entidade: 'mesa',
      id: id,
      fallback: mesaAtual.atualizadoEm,
    );

    final convidadosDaMesa =
        await (_banco.select(_banco.convidadosLocais)..where(
              (tabela) =>
                  tabela.mesaId.equals(id) & tabela.excluido.equals(false),
            ))
            .get();

    final payloadMesa = <String, dynamic>{
      'id': id,
      'casamento_id': _casamentoAtualId,
      'numero': mesaAtual.numero,
      'detalhe': mesaAtual.detalhe,
      'created_at': mesaAtual.criadoEm.toUtc().toIso8601String(),
      'base_updated_at': versaoBaseMesa,
      'updated_at': agora.toIso8601String(),
      'deleted_at': agora.toIso8601String(),
      'modificado_por_usuario_id': usuarioId,
      'modificado_por_usuario_nome': usuarioNome,
      'operacao_origem': 'exclusao_mesa',
      'acao_usuario': 'excluiu_mesa',
      'convidados_afetados_ids': convidadosDaMesa
          .map((item) => item.id)
          .toList(),
      'convidados_afetados_nomes': convidadosDaMesa
          .map((item) => item.nome)
          .toList(),
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

      // A exclusão da mesa é enviada como uma única operação. Os convidados
      // são retirados da mesa somente na cópia local para a interface reagir
      // imediatamente. Não criamos uma operação pendente por convidado, pois
      // isso gerava um conflito falso para cada pessoa da mesa quando outro
      // aparelho ainda possuía alterações offline.
      for (final convidado in convidadosDaMesa) {
        await (_banco.update(
          _banco.convidadosLocais,
        )..where((tabela) => tabela.id.equals(convidado.id))).write(
          ConvidadosLocaisCompanion(
            mesaId: const Value<String?>(null),
            atualizadoEm: Value(agora),
          ),
        );
      }
    });

    _agendarSincronizacaoDepoisDaGravacao();
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
    _exigirEdicao();
    final usuarioId = _obterUsuarioAtualId();
    final usuarioNome = _obterUsuarioAtualNome();
    final id = _uuid.v4();
    final agora = DateTime.now().toUtc();
    final nomeNormalizado = nome.trim();

    final payload = <String, dynamic>{
      'id': id,
      'casamento_id': _casamentoAtualId,
      'nome': nomeNormalizado,
      'mesa_id': mesaId,
      'chegou': false,
      'created_at': agora.toIso8601String(),
      'updated_at': agora.toIso8601String(),
      'deleted_at': null,
      'modificado_por_usuario_id': usuarioId,
      'modificado_por_usuario_nome': usuarioNome,
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

    _agendarSincronizacaoDepoisDaGravacao();
  }

  /// Edita um convidado no banco local.
  Future<void> editarConvidado(String id, String nome, String? mesaId) async {
    _exigirEdicao();
    final usuarioId = _obterUsuarioAtualId();
    final usuarioNome = _obterUsuarioAtualNome();
    final agora = DateTime.now().toUtc();
    final nomeNormalizado = nome.trim();

    final convidadoAtual = await _buscarConvidadoLocal(id);

    if (convidadoAtual == null || convidadoAtual.excluido) {
      throw StateError('O convidado não foi encontrado no banco local.');
    }

    final versaoBase = await VersaoRegistroServico.instance.obterVersaoBase(
      entidade: 'convidado',
      id: id,
      fallback: convidadoAtual.atualizadoEm,
    );

    final mesaAnterior = convidadoAtual.mesaId == null
        ? null
        : await _buscarMesaLocal(convidadoAtual.mesaId!);
    final mesaNova = mesaId == null ? null : await _buscarMesaLocal(mesaId);

    final payload = <String, dynamic>{
      'id': id,
      'casamento_id': _casamentoAtualId,
      'nome': nomeNormalizado,
      'mesa_id': mesaId,
      'chegou': convidadoAtual.chegou,
      'created_at': convidadoAtual.criadoEm.toUtc().toIso8601String(),
      'base_updated_at': versaoBase,
      'updated_at': agora.toIso8601String(),
      'deleted_at': null,
      'modificado_por_usuario_id': usuarioId,
      'modificado_por_usuario_nome': usuarioNome,
      'mesa_anterior_id': convidadoAtual.mesaId,
      'mesa_anterior_numero': mesaAnterior?.numero,
      'mesa_anterior_detalhe': mesaAnterior?.detalhe,
      'mesa_nova_id': mesaId,
      'mesa_nova_numero': mesaNova?.numero,
      'mesa_nova_detalhe': mesaNova?.detalhe,
      'convidado_nome_anterior': convidadoAtual.nome,
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

    _agendarSincronizacaoDepoisDaGravacao();
  }

  /// Exclui um convidado de forma lógica.
  Future<void> excluirConvidado(String id) async {
    _exigirEdicao();
    final usuarioId = _obterUsuarioAtualId();
    final usuarioNome = _obterUsuarioAtualNome();
    final agora = DateTime.now().toUtc();

    final convidadoAtual = await _buscarConvidadoLocal(id);

    if (convidadoAtual == null || convidadoAtual.excluido) {
      return;
    }

    final versaoBase = await VersaoRegistroServico.instance.obterVersaoBase(
      entidade: 'convidado',
      id: id,
      fallback: convidadoAtual.atualizadoEm,
    );

    final payload = <String, dynamic>{
      'id': id,
      'casamento_id': _casamentoAtualId,
      'nome': convidadoAtual.nome,
      'mesa_id': convidadoAtual.mesaId,
      'chegou': convidadoAtual.chegou,
      'created_at': convidadoAtual.criadoEm.toUtc().toIso8601String(),
      'base_updated_at': versaoBase,
      'updated_at': agora.toIso8601String(),
      'deleted_at': agora.toIso8601String(),
      'modificado_por_usuario_id': usuarioId,
      'modificado_por_usuario_nome': usuarioNome,
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

    _agendarSincronizacaoDepoisDaGravacao();
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
  // CONFLITOS DE SINCRONIZAÇÃO — LEITURA E RESOLUÇÃO ONLINE
  // ============================================================

  /// Retorna os conflitos pendentes criados pelo Supabase.
  ///
  /// Esses conflitos surgem quando uma ação offline foi feita usando uma mesa
  /// que já havia sido removida ou alterada por outro aparelho.
  Stream<List<ConflitoSincronizacao>> listarConflitosPendentes() async* {
    // A tela precisa receber uma fotografia inicial imediatamente, mesmo que o
    // canal Realtime demore para assinar ou não repita o último valor para um
    // novo ouvinte. Por isso fazemos primeiro uma consulta normal e, depois,
    // mantemos a lista atualizada pelo Realtime.
    final dadosIniciais = await _supabase
        .from('conflitos_sincronizacao')
        .select()
        .eq('casamento_id', _casamentoAtualId)
        .eq('status', 'pendente')
        .order('created_at', ascending: false)
        .timeout(const Duration(seconds: 12));

    yield dadosIniciais
        .map(
          (registro) => ConflitoSincronizacao.fromMap(
            Map<String, dynamic>.from(registro),
          ),
        )
        .toList();

    // O filtro é feito no aplicativo. Isso evita que uma assinatura Realtime
    // filtrada fique aguardando indefinidamente em alguns aparelhos, mas ainda
    // mantém criação, alteração e resolução de conflitos em tempo real.
    yield* _supabase
        .from('conflitos_sincronizacao')
        .stream(primaryKey: ['id'])
        .eq('casamento_id', _casamentoAtualId)
        .order('created_at', ascending: false)
        .map((dados) {
          return dados
              .where(
                (registro) =>
                    registro['status']?.toString().toLowerCase() == 'pendente',
              )
              .map(
                (registro) => ConflitoSincronizacao.fromMap(
                  Map<String, dynamic>.from(registro),
                ),
              )
              .toList();
        });
  }

  /// Retorna, em tempo real, operações locais que falharam ao sincronizar.
  ///
  /// A Recepção usa este stream para destacar imediatamente o convidado
  /// afetado, mesmo antes de existir um conflito registrado no servidor.
  Stream<List<ErroSincronizacaoLocal>> listarErrosSincronizacaoLocais() {
    final consulta = _banco.select(_banco.operacoesPendentesLocais)
      ..where((tabela) => tabela.status.equals('erro'))
      ..orderBy([(tabela) => OrderingTerm.desc(tabela.criadoEm)]);

    return consulta.watch().map((registros) {
      return registros.map((registro) {
        final convidadosAfetados = <String>{};
        Map<String, dynamic> payload = <String, dynamic>{};

        try {
          final valor = jsonDecode(registro.payloadJson);
          if (valor is Map) {
            payload = Map<String, dynamic>.from(valor);
          }
        } catch (_) {
          // O erro original continuará disponível em [ultimoErro].
        }

        if (registro.entidade == 'convidado') {
          convidadosAfetados.add(registro.entidadeId);
        }

        if (registro.entidade == 'evento_checkin') {
          final convidadoId = payload['convidado_id']?.toString().trim();
          if (convidadoId != null && convidadoId.isNotEmpty) {
            convidadosAfetados.add(convidadoId);
          }
        }

        final idsExtras = payload['convidados_afetados_ids'];
        if (idsExtras is Iterable) {
          convidadosAfetados.addAll(
            idsExtras
                .map((item) => item.toString().trim())
                .where((item) => item.isNotEmpty),
          );
        }

        return ErroSincronizacaoLocal(
          id: registro.id,
          entidade: registro.entidade,
          entidadeId: registro.entidadeId,
          tipoOperacao: registro.tipoOperacao,
          convidadosAfetadosIds: convidadosAfetados,
          mensagem:
              registro.ultimoErro ??
              'A alteração ainda não conseguiu ser enviada ao servidor.',
          criadoEm: registro.criadoEm.toLocal(),
        );
      }).toList();
    });
  }

  /// Resolve um conflito envolvendo uma mesa usada durante um check-in.
  ///
  /// Valores aceitos em [resolucao]:
  ///
  /// restaurar_mesa
  /// manter_sem_mesa
  /// mover_para_outra_mesa
  Future<void> resolverConflitoMesaCheckin({
    required String conflitoId,
    required String resolucao,
    String? novaMesaId,
  }) async {
    _exigirEdicao();
    final usuarioId = _obterUsuarioAtualId();

    await _supabase.rpc(
      'resolver_conflito_mesa_checkin',
      params: {
        'p_conflito_id': conflitoId,
        'p_usuario_id': usuarioId,
        'p_resolucao': resolucao,
        'p_nova_mesa_id': novaMesaId,
      },
    );

    SincronizacaoAutomaticaServico.instance.sincronizarAgora();
  }

  Future<void> resolverConflitoGenerico({
    required String conflitoId,
    required String resolucao,
  }) async {
    _exigirEdicao();
    await _supabase.rpc(
      'resolver_conflito_generico_v1',
      params: {
        'p_conflito_id': conflitoId,
        'p_usuario_id': _obterUsuarioAtualId(),
        'p_resolucao': resolucao,
      },
    );
    SincronizacaoAutomaticaServico.instance.sincronizarAgora();
  }

  /// Atribui uma nova mesa a um convidado que ficou sem mesa após a exclusão
  /// concorrente da mesa anterior.
  ///
  /// A atualização é feita diretamente no servidor porque este aviso já é
  /// uma decisão administrativa. O Supabase atualiza o aviso agrupado e os
  /// outros aparelhos recebem o resultado em tempo real.
  Future<void> realocarConvidadoAposExclusao({
    required String conflitoId,
    required String convidadoId,
    required String novaMesaId,
  }) async {
    _exigirEdicao();
    await _supabase.rpc(
      'realocar_convidado_apos_exclusao_v1',
      params: {
        'p_conflito_id': conflitoId,
        'p_convidado_id': convidadoId,
        'p_nova_mesa_id': novaMesaId,
        'p_usuario_id': _obterUsuarioAtualId(),
      },
    );

    SincronizacaoAutomaticaServico.instance.sincronizarAgora();
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
    _exigirEdicao();
    final usuarioId = _obterUsuarioAtualId();
    final usuarioNome = _obterUsuarioAtualNome();

    final dispositivoId = await DispositivoServico.instance.obterOuCriarId();

    final sequencia = await DispositivoServico.instance.proximaSequencia();

    final convidadoAtual = await _buscarConvidadoLocal(convidadoId);

    if (convidadoAtual == null || convidadoAtual.excluido) {
      throw StateError('O convidado não foi encontrado no banco local.');
    }

    MesaLocalRegistro? mesaContexto;
    final mesaContextoId = convidadoAtual.mesaId;

    if (mesaContextoId != null && mesaContextoId.isNotEmpty) {
      mesaContexto = await _buscarMesaLocal(mesaContextoId);
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
      'casamento_id': _casamentoAtualId,
      'convidado_id': convidadoId,
      'convidado_nome_contexto': convidadoAtual.nome,
      'usuario_id': usuarioId,
      'usuario_nome': usuarioNome,
      'tipo_acao': tipoAcao,
      'estado_resultante': chegou,
      'eventos_base': eventosBase,
      'data_dispositivo': agora.toIso8601String(),
      'sequencia_dispositivo': sequencia,
      'dispositivo_id': dispositivoId,
      'mesa_id_contexto': mesaContextoId,
      'mesa_numero_contexto': mesaContexto?.numero,
      'mesa_detalhe_contexto': mesaContexto?.detalhe,
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

    _agendarSincronizacaoDepoisDaGravacao();
  }

  // ============================================================
  // STAFF E CHAT — AINDA ONLINE NESTA ETAPA
  // ============================================================

  Future<void> adicionarStaff(
    String nome,
    String sobrenome,
    String ocupacao,
  ) async {
    _exigirEdicao();
    await _supabase.from('staff').insert({
      'casamento_id': _casamentoAtualId,
      'nome': nome,
      'sobrenome': sobrenome,
      'ocupacao': ocupacao,
    });
  }

  Stream<List<Staff>> listarStaff() {
    return _supabase
        .from('staff')
        .stream(primaryKey: ['id'])
        .eq('casamento_id', _casamentoAtualId)
        .map((dados) => dados.map((s) => Staff.fromMap(s)).toList());
  }

  Future<void> enviarMensagem(String staffId, String mensagem) async {
    _exigirEdicao();
    await _supabase.from('chat').insert({
      'casamento_id': _casamentoAtualId,
      'staff_id': staffId,
      'mensagem': mensagem,
    });
  }

  Stream<List<MensagemChat>> listarMensagens() {
    return _supabase
        .from('chat')
        .stream(primaryKey: ['id'])
        .eq('casamento_id', _casamentoAtualId)
        .order('created_at', ascending: true)
        .map((dados) => dados.map((m) => MensagemChat.fromMap(m)).toList());
  }

  // ============================================================
  // MÉTODOS AUXILIARES
  // ============================================================

  String get _casamentoAtualId => CasamentoAtualServico.instance.casamentoId;

  void _exigirEdicao() {
    CasamentoAtualServico.instance.exigirEdicao();
  }

  /// Retorna o usuário que entrou no aplicativo.
  String _obterUsuarioAtualId() {
    final usuarioAtual = SessaoServico.instance.usuarioAtual;

    if (usuarioAtual == null) {
      throw StateError('Nenhum usuário está identificado no aplicativo.');
    }

    return usuarioAtual.id;
  }

  String _obterUsuarioAtualNome() {
    final usuarioAtual = SessaoServico.instance.usuarioAtual;

    if (usuarioAtual == null) {
      throw StateError('Nenhum usuário está identificado no aplicativo.');
    }

    return usuarioAtual.nome;
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

  /// Agenda a sincronização somente depois que a transação local terminou.
  ///
  /// Iniciar a sincronização enquanto o SQLite ainda está gravando a alteração
  /// pode fazer o sincronizador aguardar a própria transação e ficar preso.
  void _agendarSincronizacaoDepoisDaGravacao() {
    SincronizacaoAutomaticaServico.instance.agendar();
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
