import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../banco/banco_instancia.dart';
import '../banco/banco_local.dart';
import '../modelos/tipos_evento.dart';

enum PapelNoCasamento { admin, funcionario }

class PapeisContaAtual {
  final bool cerimonialista;
  final bool funcionario;

  const PapeisContaAtual({
    required this.cerimonialista,
    required this.funcionario,
  });

  bool get contaMista => cerimonialista && funcionario;
}

class CasamentoAtual {
  final String id;
  final String organizacaoId;
  final String titulo;
  final String? nomePessoa1;
  final String? nomePessoa2;
  final TipoEvento tipoEvento;
  final String? rotuloPessoas;
  final Map<String, dynamic> detalhesEvento;
  final DateTime? dataEvento;
  final String? horarioEvento;
  final String? localEvento;
  final String status;
  final PapelNoCasamento papel;

  const CasamentoAtual({
    required this.id,
    required this.organizacaoId,
    required this.titulo,
    required this.nomePessoa1,
    required this.nomePessoa2,
    this.tipoEvento = TipoEvento.casamento,
    this.rotuloPessoas,
    this.detalhesEvento = const {},
    required this.dataEvento,
    required this.horarioEvento,
    required this.localEvento,
    required this.status,
    required this.papel,
  });

  bool get ehAdmin => papel == PapelNoCasamento.admin;

  bool get encerrado => status == 'finalizado' || status == 'arquivado';

  String get descricao {
    final nomes = [nomePessoa1, nomePessoa2]
        .whereType<String>()
        .map((nome) => nome.trim())
        .where((nome) => nome.isNotEmpty)
        .join(' e ');
    return nomes.isEmpty ? titulo : nomes;
  }

  String get descricaoPessoas {
    final nomes = [nomePessoa1, nomePessoa2]
        .whereType<String>()
        .map((nome) => nome.trim())
        .where((nome) => nome.isNotEmpty)
        .join(' e ');
    return nomes;
  }

  CasamentoAtual comStatus(String novoStatus) {
    return CasamentoAtual(
      id: id,
      organizacaoId: organizacaoId,
      titulo: titulo,
      nomePessoa1: nomePessoa1,
      nomePessoa2: nomePessoa2,
      tipoEvento: tipoEvento,
      rotuloPessoas: rotuloPessoas,
      detalhesEvento: detalhesEvento,
      dataEvento: dataEvento,
      horarioEvento: horarioEvento,
      localEvento: localEvento,
      status: novoStatus,
      papel: papel,
    );
  }
}

/// Mantém o casamento aberto neste aparelho.
///
/// A cópia offline armazena somente o casamento atualmente aberto. Isso evita
/// misturar listas diferentes no mesmo check-in e reduz os dados sensíveis
/// mantidos no dispositivo.
class CasamentoAtualServico {
  CasamentoAtualServico._();

  static final CasamentoAtualServico instance = CasamentoAtualServico._();

  final SupabaseClient _supabase = Supabase.instance.client;
  final BancoLocal _banco = bancoLocal;

  static const String _chaveCasamentoAtual = 'casamento_atual_v1';

  CasamentoAtual? _casamento;

  CasamentoAtual? get casamento => _casamento;
  String get casamentoId {
    final id = _casamento?.id;
    if (id == null) {
      throw StateError('Nenhum casamento foi selecionado.');
    }
    return id;
  }

  bool get ehAdmin => _casamento?.ehAdmin ?? false;
  bool get somenteLeitura => _casamento?.encerrado ?? false;

  void exigirEdicao() {
    if (somenteLeitura) {
      throw StateError(
        'Este casamento foi encerrado e está disponível somente para leitura.',
      );
    }
  }

  Future<PapeisContaAtual> obterPapeisContaAtual() async {
    if (_supabase.auth.currentUser == null) {
      return const PapeisContaAtual(cerimonialista: false, funcionario: false);
    }

    final resposta = await _supabase.rpc('obter_papeis_conta_atual_v1');
    final dados = resposta is Map
        ? Map<String, dynamic>.from(resposta)
        : const <String, dynamic>{};

    return PapeisContaAtual(
      cerimonialista: dados['cerimonialista'] == true,
      funcionario: dados['funcionario'] == true,
    );
  }

  Future<bool> possuiPerfilCerimonialista() async {
    final papeis = await obterPapeisContaAtual();
    return papeis.cerimonialista;
  }

  /// Garante a organização administrativa da conta sem apagar ou substituir
  /// vínculos de funcionário. Assim, o mesmo usuário pode atuar nos dois papéis.
  Future<void> garantirOrganizacaoDaCerimonialista() async {
    final usuario = _supabase.auth.currentUser;
    if (usuario == null) return;

    final metadados = usuario.userMetadata ?? const <String, dynamic>{};
    final deveCriarOrganizacao = metadados['criar_organizacao'];
    if (deveCriarOrganizacao == false ||
        deveCriarOrganizacao?.toString().toLowerCase() == 'false') {
      return;
    }

    if (await possuiPerfilCerimonialista()) {
      return;
    }

    final nome =
        _textoOpcional(metadados['nome']) ??
        _textoOpcional(metadados['full_name']) ??
        (usuario.email ?? 'Minha cerimonial').split('@').first;

    await _supabase.rpc(
      'habilitar_perfil_cerimonialista_v1',
      params: {'p_nome': nome},
    );
  }

  Future<List<CasamentoAtual>> listarCasamentos() async {
    final usuarioId = _supabase.auth.currentUser?.id;
    if (usuarioId == null) {
      return const [];
    }

    final casamentos = await _supabase
        .from('casamentos')
        .select(
          'id, organizacao_id, titulo, nome_pessoa_1, nome_pessoa_2, tipo_evento, rotulo_pessoas, detalhes_evento, data_evento, hora_evento, local_evento, status',
        )
        .order('data_evento', ascending: false);

    final organizacoesAdmin = await _supabase
        .from('membros_organizacao')
        .select('organizacao_id')
        .eq('usuario_id', usuarioId)
        .eq('papel', 'admin')
        .eq('ativo', true);

    final idsOrganizacoesAdmin = (organizacoesAdmin as List)
        .map((item) => (item as Map)['organizacao_id']?.toString())
        .whereType<String>()
        .toSet();

    final vinculos = await _supabase
        .from('membros_casamento')
        .select('casamento_id, papel')
        .eq('usuario_id', usuarioId)
        .eq('ativo', true);

    final papeisPorCasamento = <String, PapelNoCasamento>{
      for (final item in vinculos as List)
        if ((item as Map)['casamento_id'] != null)
          item['casamento_id'].toString(): item['papel'] == 'admin'
              ? PapelNoCasamento.admin
              : PapelNoCasamento.funcionario,
    };

    final resultado = <CasamentoAtual>[];

    for (final item in casamentos as List) {
      final registro = Map<String, dynamic>.from(item as Map);
      final organizacaoId = registro['organizacao_id'].toString();
      final id = registro['id'].toString();
      final ehAdminNaOrganizacao = idsOrganizacoesAdmin.contains(organizacaoId);
      final papelNoCasamento = papeisPorCasamento[id];

      CasamentoAtual criarRegistro(PapelNoCasamento papel) {
        return CasamentoAtual(
          id: id,
          organizacaoId: organizacaoId,
          titulo: registro['titulo']?.toString() ?? 'Casamento',
          nomePessoa1: _textoOpcional(registro['nome_pessoa_1']),
          nomePessoa2: _textoOpcional(registro['nome_pessoa_2']),
          tipoEvento: tipoEventoFromBanco(registro['tipo_evento']),
          rotuloPessoas: _textoOpcional(registro['rotulo_pessoas']),
          detalhesEvento: _mapa(registro['detalhes_evento']),
          dataEvento: DateTime.tryParse(
            registro['data_evento']?.toString() ?? '',
          ),
          horarioEvento: _textoOpcional(registro['hora_evento']),
          localEvento: _textoOpcional(registro['local_evento']),
          status: registro['status']?.toString() ?? 'rascunho',
          papel: papel,
        );
      }

      // Uma conta mista pode ter os dois acessos ao mesmo casamento. O
      // registro administrativo vem da organização; o registro de funcionário
      // vem do convite específico para o casamento.
      if (ehAdminNaOrganizacao) {
        resultado.add(criarRegistro(PapelNoCasamento.admin));
      }
      if (papelNoCasamento == PapelNoCasamento.funcionario) {
        resultado.add(criarRegistro(PapelNoCasamento.funcionario));
      } else if (!ehAdminNaOrganizacao && papelNoCasamento != null) {
        resultado.add(criarRegistro(papelNoCasamento));
      }
    }

    return resultado;
  }

  /// Atualiza a lista assim que um casamento ou vínculo de acesso mudar,
  /// inclusive se a alteração vier de outro aparelho.
  Stream<List<CasamentoAtual>> listarCasamentosEmTempoReal() async* {
    if (_supabase.auth.currentUser == null) {
      yield const [];
      return;
    }

    final atualizacoes = StreamController<void>();
    final assinaturas = <StreamSubscription<dynamic>>[];

    void agendarAtualizacao() {
      if (!atualizacoes.isClosed) atualizacoes.add(null);
    }

    void observar(Stream<dynamic> stream) {
      assinaturas.add(
        stream.listen(
          (_) => agendarAtualizacao(),
          onError: atualizacoes.addError,
        ),
      );
    }

    observar(_supabase.from('casamentos').stream(primaryKey: ['id']));
    observar(
      _supabase
          .from('membros_organizacao')
          .stream(primaryKey: ['organizacao_id', 'usuario_id']),
    );
    observar(
      _supabase
          .from('membros_casamento')
          .stream(primaryKey: ['casamento_id', 'usuario_id']),
    );
    agendarAtualizacao();

    try {
      await for (final _ in atualizacoes.stream) {
        yield await listarCasamentos();
      }
    } finally {
      await Future.wait(assinaturas.map((assinatura) => assinatura.cancel()));
      await atualizacoes.close();
    }
  }

  /// Informa imediatamente quando o casamento selecionado deixa de estar
  /// disponível para a conta atual. O encerramento não revoga o acesso:
  /// nesse caso o casamento permanece disponível em modo somente leitura.
  ///
  /// As tabelas são observadas pelo Realtime e, a cada mudança, o acesso é
  /// confirmado novamente pelo próprio RLS do Supabase. Se a consulta não
  /// devolver o casamento, a conta não pode mais permanecer dentro dele.
  Stream<bool> observarAcessoAoCasamentoSelecionado() async* {
    final casamentoSelecionado = _casamento;
    final usuarioId = _supabase.auth.currentUser?.id;

    if (casamentoSelecionado == null || usuarioId == null) {
      yield false;
      return;
    }

    final atualizacoes = StreamController<void>();
    final assinaturas = <StreamSubscription<dynamic>>[];

    void agendarVerificacao() {
      if (!atualizacoes.isClosed) {
        atualizacoes.add(null);
      }
    }

    void observar(Stream<dynamic> stream) {
      assinaturas.add(
        stream.listen(
          (_) => agendarVerificacao(),
          onError: atualizacoes.addError,
        ),
      );
    }

    observar(_supabase.from('casamentos').stream(primaryKey: ['id']));
    observar(
      _supabase
          .from('membros_casamento')
          .stream(primaryKey: ['casamento_id', 'usuario_id']),
    );
    observar(
      _supabase
          .from('membros_organizacao')
          .stream(primaryKey: ['organizacao_id', 'usuario_id']),
    );

    agendarVerificacao();

    try {
      await for (final _ in atualizacoes.stream) {
        final registros = await _supabase
            .from('casamentos')
            .select('id, status')
            .eq('id', casamentoSelecionado.id)
            .limit(1);

        final lista = registros as List;
        if (lista.isEmpty) {
          yield false;
          continue;
        }

        final statusAtual = (lista.first as Map)['status']?.toString();
        if (statusAtual != null &&
            statusAtual != _casamento?.status &&
            _casamento != null) {
          _casamento = _casamento!.comStatus(statusAtual);
        }
        yield true;
      }
    } finally {
      await Future.wait(assinaturas.map((assinatura) => assinatura.cancel()));
      await atualizacoes.close();
    }
  }

  Future<CasamentoAtual> criarCasamento({
    required String titulo,
    String? nomePessoa1,
    String? nomePessoa2,
    TipoEvento tipoEvento = TipoEvento.casamento,
    String? rotuloPessoas,
    Map<String, dynamic>? detalhesEvento,
    DateTime? dataEvento,
    String? horarioEvento,
    String? localEvento,
  }) async {
    final usuarioId = _supabase.auth.currentUser?.id;
    if (usuarioId == null) {
      throw StateError('Entre novamente para criar um casamento.');
    }

    final organizacoes = await _supabase
        .from('membros_organizacao')
        .select('organizacao_id')
        .eq('usuario_id', usuarioId)
        .eq('papel', 'admin')
        .eq('ativo', true)
        .limit(1);

    if (organizacoes.isEmpty) {
      throw StateError('Sua conta ainda não possui uma organização.');
    }

    final organizacaoId = (organizacoes.first as Map)['organizacao_id']
        .toString();
    final tituloLimpo = _textoObrigatorio(titulo);
    if (dataEvento == null || _textoOpcional(horarioEvento) == null) {
      throw ArgumentError('Informe a data e o horário do evento.');
    }
    final criado = await _supabase
        .from('casamentos')
        .insert({
          'organizacao_id': organizacaoId,
          'titulo': tituloLimpo,
          'nome_pessoa_1': _textoOpcional(nomePessoa1),
          'nome_pessoa_2': _textoOpcional(nomePessoa2),
          'tipo_evento': tipoEvento.valorBanco,
          'rotulo_pessoas': _textoOpcional(rotuloPessoas),
          'detalhes_evento': detalhesEvento ?? const <String, dynamic>{},
          'evento_completo': true,
          'data_evento': dataEvento.toIso8601String().split('T').first,
          'hora_evento': _textoOpcional(horarioEvento),
          'local_evento': _textoOpcional(localEvento),
          'status': 'rascunho',
        })
        .select(
          'id, organizacao_id, titulo, nome_pessoa_1, nome_pessoa_2, tipo_evento, rotulo_pessoas, detalhes_evento, data_evento, hora_evento, local_evento, status',
        )
        .single();

    final registro = Map<String, dynamic>.from(criado);
    return CasamentoAtual(
      id: registro['id'].toString(),
      organizacaoId: registro['organizacao_id'].toString(),
      titulo: registro['titulo'].toString(),
      nomePessoa1: _textoOpcional(registro['nome_pessoa_1']),
      nomePessoa2: _textoOpcional(registro['nome_pessoa_2']),
      tipoEvento: tipoEventoFromBanco(registro['tipo_evento']),
      rotuloPessoas: _textoOpcional(registro['rotulo_pessoas']),
      detalhesEvento: _mapa(registro['detalhes_evento']),
      dataEvento: DateTime.tryParse(registro['data_evento']?.toString() ?? ''),
      horarioEvento: _textoOpcional(registro['hora_evento']),
      localEvento: _textoOpcional(registro['local_evento']),
      status: registro['status']?.toString() ?? 'rascunho',
      papel: PapelNoCasamento.admin,
    );
  }

  Future<CasamentoAtual> atualizarCasamento({
    required CasamentoAtual casamento,
    required String titulo,
    required TipoEvento tipoEvento,
    String? nomePessoa1,
    String? nomePessoa2,
    String? rotuloPessoas,
    Map<String, dynamic>? detalhesEvento,
    required DateTime dataEvento,
    required String horarioEvento,
    String? localEvento,
  }) async {
    if (!casamento.ehAdmin || casamento.encerrado) {
      throw StateError('Este evento não está disponível para edição.');
    }

    final tituloLimpo = _textoObrigatorio(titulo);
    final horarioLimpo = _textoObrigatorio(horarioEvento);
    final resposta = await _supabase
        .from('casamentos')
        .update({
          'titulo': tituloLimpo,
          'tipo_evento': tipoEvento.valorBanco,
          'nome_pessoa_1': _textoOpcional(nomePessoa1),
          'nome_pessoa_2': _textoOpcional(nomePessoa2),
          'rotulo_pessoas': _textoOpcional(rotuloPessoas),
          'detalhes_evento': detalhesEvento ?? const <String, dynamic>{},
          'data_evento': dataEvento.toIso8601String().split('T').first,
          'hora_evento': horarioLimpo,
          'local_evento': _textoOpcional(localEvento),
          'evento_completo': true,
        })
        .eq('id', casamento.id)
        .select(
          'id, organizacao_id, titulo, nome_pessoa_1, nome_pessoa_2, tipo_evento, rotulo_pessoas, detalhes_evento, data_evento, hora_evento, local_evento, status',
        )
        .single();

    final registro = Map<String, dynamic>.from(resposta);
    final atualizado = CasamentoAtual(
      id: registro['id'].toString(),
      organizacaoId: registro['organizacao_id'].toString(),
      titulo: registro['titulo'].toString(),
      nomePessoa1: _textoOpcional(registro['nome_pessoa_1']),
      nomePessoa2: _textoOpcional(registro['nome_pessoa_2']),
      tipoEvento: tipoEventoFromBanco(registro['tipo_evento']),
      rotuloPessoas: _textoOpcional(registro['rotulo_pessoas']),
      detalhesEvento: _mapa(registro['detalhes_evento']),
      dataEvento: DateTime.tryParse(registro['data_evento']?.toString() ?? ''),
      horarioEvento: _textoOpcional(registro['hora_evento']),
      localEvento: _textoOpcional(registro['local_evento']),
      status: registro['status']?.toString() ?? casamento.status,
      papel: casamento.papel,
    );
    if (_casamento?.id == atualizado.id && _casamento?.papel == atualizado.papel) {
      _casamento = atualizado;
      final usuarioId = _supabase.auth.currentUser?.id;
      if (usuarioId != null) await _salvarCasamentoAtual(atualizado, usuarioId);
    }
    return atualizado;
  }

  Future<void> finalizarCasamento(CasamentoAtual casamento) async {
    if (!casamento.ehAdmin) {
      throw StateError('Somente administradoras podem encerrar um casamento.');
    }
    await _supabase.rpc(
      'finalizar_casamento_v1',
      params: {'p_casamento_id': casamento.id},
    );
  }

  Future<void> arquivarCasamento(CasamentoAtual casamento) async {
    if (!casamento.ehAdmin) {
      throw StateError('Somente administradoras podem arquivar um casamento.');
    }

    await _supabase.rpc(
      'arquivar_casamento_v1',
      params: {'p_casamento_id': casamento.id},
    );

    if (_casamento?.id == casamento.id) {
      await limparPersistido();
    }
  }

  Future<void> restaurarCasamentoArquivado(CasamentoAtual casamento) async {
    if (!casamento.ehAdmin) {
      throw StateError('Somente administradoras podem restaurar um casamento.');
    }

    await _supabase.rpc(
      'restaurar_casamento_arquivado_v1',
      params: {'p_casamento_id': casamento.id},
    );
  }

  Future<void> excluirCasamentoDefinitivamente(CasamentoAtual casamento) async {
    if (!casamento.ehAdmin) {
      throw StateError('Somente administradoras podem excluir um casamento.');
    }

    await _supabase.rpc(
      'excluir_casamento_definitivamente_v1',
      params: {'p_casamento_id': casamento.id},
    );

    if (_casamento?.id == casamento.id) {
      await limparPersistido();
    }
  }

  /// Restaura o último casamento aberto sem acessar a internet.
  ///
  /// O casamento fica associado ao usuário autenticado para impedir que outra
  /// conta aberta no mesmo aparelho reutilize uma cópia local que não pertence
  /// a ela.
  Future<bool> restaurarDoArmazenamentoLocal({
    required String usuarioId,
  }) async {
    if (_casamento != null) {
      return true;
    }

    final consulta = _banco.select(_banco.configuracoesLocais)
      ..where((tabela) => tabela.chave.equals(_chaveCasamentoAtual));
    final registro = await consulta.getSingleOrNull();
    if (registro == null) {
      return false;
    }

    try {
      final decodificado = jsonDecode(registro.valor);
      if (decodificado is! Map) {
        await _removerCasamentoPersistido();
        return false;
      }

      final dados = Map<String, dynamic>.from(decodificado);
      if (dados['usuario_id']?.toString() != usuarioId) {
        return false;
      }

      final id = dados['id']?.toString().trim() ?? '';
      final organizacaoId = dados['organizacao_id']?.toString().trim() ?? '';
      if (id.isEmpty || organizacaoId.isEmpty) {
        await _removerCasamentoPersistido();
        return false;
      }

      _casamento = CasamentoAtual(
        id: id,
        organizacaoId: organizacaoId,
        titulo: dados['titulo']?.toString() ?? 'Casamento',
        nomePessoa1: _textoOpcional(dados['nome_pessoa_1']),
        nomePessoa2: _textoOpcional(dados['nome_pessoa_2']),
        tipoEvento: tipoEventoFromBanco(dados['tipo_evento']),
        rotuloPessoas: _textoOpcional(dados['rotulo_pessoas']),
        detalhesEvento: _mapa(dados['detalhes_evento']),
        dataEvento: DateTime.tryParse(dados['data_evento']?.toString() ?? ''),
        horarioEvento: _textoOpcional(dados['horario_evento']),
        localEvento: _textoOpcional(dados['local_evento']),
        status: dados['status']?.toString() ?? 'ativo',
        papel: dados['papel']?.toString() == 'admin'
            ? PapelNoCasamento.admin
            : PapelNoCasamento.funcionario,
      );
      return true;
    } catch (_) {
      await _removerCasamentoPersistido();
      return false;
    }
  }

  Future<void> selecionar(CasamentoAtual casamento) async {
    final usuarioId = _supabase.auth.currentUser?.id;
    if (usuarioId == null) {
      throw StateError('Entre novamente para abrir o casamento.');
    }

    // Depois que o Android encerra o processo, a memória é perdida, mas o
    // casamento continua salvo no SQLite. Restaurá-lo antes da comparação
    // impede que a mesma lista seja apagada e baixada novamente.
    await restaurarDoArmazenamentoLocal(usuarioId: usuarioId);

    if (_casamento?.id == casamento.id &&
        _casamento?.papel == casamento.papel) {
      _casamento = casamento;
      await _salvarCasamentoAtual(casamento, usuarioId);
      return;
    }

    // O mesmo evento pode aparecer nas duas visões de uma conta mista. Nesse
    // caso, trocar de papel não deve apagar os dados locais, mas ainda precisa
    // registrar o aceite quando a pessoa abrir a versão de funcionário.
    if (_casamento?.id == casamento.id) {
      if (!casamento.ehAdmin && !casamento.encerrado) {
        await _supabase.rpc(
          'aceitar_convite_casamento_v1',
          params: {'p_casamento_id': casamento.id},
        );
      }
      _casamento = casamento;
      await _salvarCasamentoAtual(casamento, usuarioId);
      return;
    }

    final pendencias = await _banco
        .select(_banco.operacoesPendentesLocais)
        .get();
    if (pendencias.isNotEmpty) {
      throw StateError(
        'Sincronize as alterações pendentes antes de trocar de casamento.',
      );
    }

    if (!casamento.ehAdmin && !casamento.encerrado) {
      await _supabase.rpc(
        'aceitar_convite_casamento_v1',
        params: {'p_casamento_id': casamento.id},
      );
    }

    await _banco.transaction(() async {
      await _banco.delete(_banco.mensagensChatLocais).go();
      await _banco.delete(_banco.staffsLocais).go();
      await _banco.delete(_banco.eventosCheckinLocais).go();
      await _banco.delete(_banco.convidadosLocais).go();
      await _banco.delete(_banco.mesasLocais).go();
      await _banco.delete(_banco.sincronizacoesLocais).go();
      await (_banco.delete(
        _banco.configuracoesLocais,
      )..where((tabela) => tabela.chave.like('versao_registro_%'))).go();
    });

    _casamento = casamento;
    await _salvarCasamentoAtual(casamento, usuarioId);
  }

  Future<void> _salvarCasamentoAtual(
    CasamentoAtual casamento,
    String usuarioId,
  ) async {
    final agora = DateTime.now().toUtc();
    final dados = <String, dynamic>{
      'usuario_id': usuarioId,
      'id': casamento.id,
      'organizacao_id': casamento.organizacaoId,
      'titulo': casamento.titulo,
      'nome_pessoa_1': casamento.nomePessoa1,
      'nome_pessoa_2': casamento.nomePessoa2,
      'tipo_evento': casamento.tipoEvento.valorBanco,
      'rotulo_pessoas': casamento.rotuloPessoas,
      'detalhes_evento': casamento.detalhesEvento,
      'data_evento': casamento.dataEvento?.toIso8601String(),
      'horario_evento': casamento.horarioEvento,
      'local_evento': casamento.localEvento,
      'status': casamento.status,
      'papel': casamento.ehAdmin ? 'admin' : 'funcionario',
    };

    await _banco
        .into(_banco.configuracoesLocais)
        .insertOnConflictUpdate(
          ConfiguracoesLocaisCompanion.insert(
            chave: _chaveCasamentoAtual,
            valor: jsonEncode(dados),
            atualizadoEm: agora,
          ),
        );
  }

  Future<void> _removerCasamentoPersistido() async {
    await (_banco.delete(
      _banco.configuracoesLocais,
    )..where((tabela) => tabela.chave.equals(_chaveCasamentoAtual))).go();
  }

  /// Limpa imediatamente o casamento em memória e agenda a remoção da cópia
  /// persistida. Mantemos este método síncrono para os pontos antigos da tela.
  void limpar() {
    _casamento = null;
    unawaited(_removerCasamentoPersistido());
  }

  /// Versão aguardável usada no logout e em ações que precisam garantir que o
  /// casamento não será restaurado na próxima abertura do aplicativo.
  Future<void> limparPersistido() async {
    _casamento = null;
    await _removerCasamentoPersistido();
  }

  String? _textoOpcional(Object? valor) {
    final texto = valor?.toString().replaceAll('\u0000', '').trim();
    return texto == null || texto.isEmpty ? null : texto;
  }

  String _textoObrigatorio(String valor) {
    final texto = valor.replaceAll('\u0000', '').trim();
    if (texto.isEmpty) {
      throw ArgumentError('Informe um nome para o casamento.');
    }
    return texto;
  }

  Map<String, dynamic> _mapa(Object? valor) {
    if (valor is Map) return Map<String, dynamic>.from(valor);
    return const <String, dynamic>{};
  }
}
