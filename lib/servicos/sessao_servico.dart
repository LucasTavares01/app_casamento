import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../banco/banco_instancia.dart';
import '../banco/banco_local.dart';
import 'casamento_atual_servico.dart';
import 'realtime_servico.dart';

enum SituacaoContaCerimonialista {
  novaConta,
  contaExistenteSemPerfilCerimonialista,
  confirmacaoEmailPendente,
}

class ResultadoContaCerimonialista {
  final SituacaoContaCerimonialista situacao;

  const ResultadoContaCerimonialista(this.situacao);
}

/// Autenticação da conta pelo Supabase Auth.
///
/// O antigo acesso compartilhado por nomes e senhas locais foi substituído
/// por uma conta individual de e-mail. O perfil ainda é espelhado no SQLite
/// porque os registros offline precisam identificar quem fez cada check-in.
class SessaoServico {
  SessaoServico._();

  static final SessaoServico instance = SessaoServico._();

  static const String _chaveLoginGooglePendente =
      'login_google_pendente_em';
  static const String _chaveVinculoGooglePendente =
      'vinculo_google_convite_pendente_em';
  static const String _chavePerfilCerimonialistaGooglePendente =
      'perfil_cerimonialista_google_pendente_em';
  static const Duration _validadeLoginGooglePendente = Duration(minutes: 15);
  static const Duration _validadeVinculoGooglePendente = Duration(minutes: 15);
  static const Duration _validadePerfilCerimonialistaGooglePendente =
      Duration(minutes: 15);

  final BancoLocal _banco = bancoLocal;
  final SupabaseClient _supabase = Supabase.instance.client;
  final StreamController<String> _controladorSessaoRevogada =
      StreamController<String>.broadcast();

  UsuarioAppLocalRegistro? _usuarioAtual;
  User? _usuarioAutenticado;
  Future<void>? _sincronizacaoUsuarioEmAndamento;

  UsuarioAppLocalRegistro? get usuarioAtual => _usuarioAtual;
  User? get _usuarioDoAuth => _usuarioAutenticado ?? _supabase.auth.currentUser;
  String get emailAtual => _usuarioDoAuth?.email ?? '';
  String get nomeExibicaoAtual {
    final usuario = _usuarioDoAuth;
    return usuario == null ? '' : _nomeDoUsuario(usuario);
  }

  String? get sessaoIdAtual => _supabase.auth.currentSession?.accessToken;
  bool get possuiSessaoLocal => _supabase.auth.currentSession != null;
  bool get possuiUsuarioAtivoNoApp => _usuarioAtual != null;
  bool get precisaDefinirSenha {
    final valor = _usuarioDoAuth?.userMetadata?['precisa_definir_senha'];
    return valor == true || valor?.toString().toLowerCase() == 'true';
  }

  bool get ehFuncionarioConvidado {
    final valor = _usuarioDoAuth?.userMetadata?['criar_organizacao'];
    return valor == false || valor?.toString().toLowerCase() == 'false';
  }

  bool get deveAbrirComoFuncionario {
    final valor = _usuarioDoAuth?.userMetadata?['abrir_como_funcionario'];
    return valor == true || valor?.toString().toLowerCase() == 'true';
  }

  Future<void> consumirAberturaComoFuncionario() async {
    if (!deveAbrirComoFuncionario || _usuarioDoAuth == null) return;

    await _supabase.auth.updateUser(
      UserAttributes(data: const {'abrir_como_funcionario': false}),
    );
    _usuarioAutenticado = _supabase.auth.currentUser;
  }

  bool get precisaConcluirPrimeiroAcessoFuncionario =>
      ehFuncionarioConvidado && precisaDefinirSenha;

  Stream<String> get sessoesRevogadas => _controladorSessaoRevogada.stream;

  /// Restaura a sessão, o perfil e o último casamento usando somente dados já
  /// salvos no aparelho. Nenhuma chamada ao Supabase é feita neste método.
  Future<bool> restaurarSessaoLocal() async {
    final usuario = _supabase.auth.currentUser;
    if (usuario == null || _supabase.auth.currentSession == null) {
      _usuarioAtual = null;
      _usuarioAutenticado = null;
      return false;
    }

    final consulta = _banco.select(_banco.usuariosAppLocais)
      ..where(
        (tabela) => tabela.id.equals(usuario.id) & tabela.ativo.equals(true),
      );
    final perfilLocal = await consulta.getSingleOrNull();
    if (perfilLocal == null) {
      return false;
    }

    _usuarioAutenticado = usuario;
    _usuarioAtual = perfilLocal;
    await CasamentoAtualServico.instance.restaurarDoArmazenamentoLocal(
      usuarioId: usuario.id,
    );
    return true;
  }

  /// Mantido para pontos que precisam restaurar e atualizar explicitamente uma
  /// sessão. Na inicialização, a tela tenta primeiro a cópia local.
  Future<void> inicializar() => sincronizarUsuarioAutenticado();

  Future<void> sincronizarUsuarioAutenticado() async {
    final sincronizacaoAtual = _sincronizacaoUsuarioEmAndamento;
    if (sincronizacaoAtual != null) {
      await sincronizacaoAtual;
      return;
    }

    final novaSincronizacao = _sincronizarUsuarioAutenticadoInterno();
    _sincronizacaoUsuarioEmAndamento = novaSincronizacao;

    try {
      await novaSincronizacao;
    } finally {
      if (identical(_sincronizacaoUsuarioEmAndamento, novaSincronizacao)) {
        _sincronizacaoUsuarioEmAndamento = null;
      }
    }
  }

  Future<void> _sincronizarUsuarioAutenticadoInterno() async {
    final usuarioLocalAuth = _supabase.auth.currentUser;
    if (usuarioLocalAuth == null) {
      _usuarioAtual = null;
      _usuarioAutenticado = null;
      return;
    }

    final resultadoUsuario = await _obterUsuarioAtualizado();
    final usuario = resultadoUsuario.usuario;
    if (usuario == null) {
      _usuarioAtual = null;
      _usuarioAutenticado = null;
      return;
    }
    _usuarioAutenticado = usuario;

    final nome = _nomeDoUsuario(usuario);
    final agora = DateTime.now().toUtc();

    await _banco
        .into(_banco.usuariosAppLocais)
        .insertOnConflictUpdate(
          UsuariosAppLocaisCompanion.insert(
            id: usuario.id,
            nome: nome,
            ordem: const Value(0),
            ativo: const Value(true),
            criadoEm: agora,
          ),
        );

    final consulta = _banco.select(_banco.usuariosAppLocais)
      ..where((tabela) => tabela.id.equals(usuario.id));
    _usuarioAtual = await consulta.getSingleOrNull();
    await CasamentoAtualServico.instance.restaurarDoArmazenamentoLocal(
      usuarioId: usuario.id,
    );

    if (!resultadoUsuario.validadoOnline) {
      throw const ValidacaoSessaoIndisponivelException(
        'Não foi possível validar a sessão pela internet agora.',
      );
    }

    final perfilCerimonialistaGooglePendente =
        await possuiPerfilCerimonialistaGooglePendente();

    if (!perfilCerimonialistaGooglePendente) {
      await _garantirOrganizacaoComTentativas();
    }

    await RealtimeServico.instance.inicializar();
    await limparLoginGooglePendente();
  }

  Future<void> _garantirOrganizacaoComTentativas() async {
    Object? ultimoErro;
    StackTrace? ultimaPilha;

    for (var tentativa = 1; tentativa <= 5; tentativa++) {
      try {
        await CasamentoAtualServico.instance
            .garantirOrganizacaoDaCerimonialista();
        return;
      } catch (erro, stackTrace) {
        ultimoErro = erro;
        ultimaPilha = stackTrace;

        final sessaoAindaAtiva =
            _supabase.auth.currentSession != null &&
            _supabase.auth.currentUser != null;
        if (!sessaoAindaAtiva || tentativa == 5) {
          Error.throwWithStackTrace(erro, stackTrace);
        }

        debugPrint(
          'Conta ainda não ficou pronta após o login '
          '(tentativa $tentativa de 5): $erro',
        );
        await Future<void>.delayed(
          Duration(milliseconds: 600 * tentativa),
        );
      }
    }

    if (ultimoErro != null && ultimaPilha != null) {
      Error.throwWithStackTrace(ultimoErro, ultimaPilha);
    }
  }

  Future<void> entrarComEmail({
    required String email,
    required String senha,
  }) async {
    await prepararNovaAutenticacao();
    await _supabase.auth.signInWithPassword(
      email: _normalizarEmail(email),
      password: senha,
    );
    await sincronizarUsuarioAutenticado();
  }

  Future<ResultadoContaCerimonialista> prepararContaCerimonialista({
    required String nome,
    required String email,
    required String senha,
  }) async {
    await prepararNovaAutenticacao();

    final emailNormalizado = _normalizarEmail(email);
    final nomeNormalizado = nome.trim();

    try {
      final contaJaExiste = await emailCadastrado(emailNormalizado);
      if (contaJaExiste) {
        return const ResultadoContaCerimonialista(
          SituacaoContaCerimonialista.contaExistenteSemPerfilCerimonialista,
        );
      }

      final resposta = await _supabase.auth.signUp(
        email: emailNormalizado,
        password: senha,
        emailRedirectTo: kIsWeb ? null : 'br.com.appcasamento://login-callback',
        data: {
          'nome': nomeNormalizado,
          'criar_organizacao': true,
          'cadastro_concluido': true,
        },
      );

      if (resposta.session == null) {
        return const ResultadoContaCerimonialista(
          SituacaoContaCerimonialista.confirmacaoEmailPendente,
        );
      }

      await habilitarPerfilCerimonialista(nome: nomeNormalizado);
      return const ResultadoContaCerimonialista(
        SituacaoContaCerimonialista.novaConta,
      );
    } on AuthException catch (erro) {
      if (_erroIndicaContaExistente(erro)) {
        return const ResultadoContaCerimonialista(
          SituacaoContaCerimonialista.contaExistenteSemPerfilCerimonialista,
        );
      }
      rethrow;
    }
  }

  Future<void> habilitarPerfilCerimonialista({
    required String nome,
  }) async {
    final usuario = _supabase.auth.currentUser;
    if (usuario == null || _supabase.auth.currentSession == null) {
      throw const AuthException(
        'Entre na conta existente antes de habilitar o perfil de cerimonialista.',
      );
    }

    final nomeNormalizado = nome.trim().isEmpty
        ? _nomeDoUsuario(usuario)
        : nome.trim();

    await _supabase.auth.updateUser(
      UserAttributes(
        data: {
          'nome': nomeNormalizado,
          'criar_organizacao': true,
          'cadastro_concluido': true,
          'precisa_definir_senha': false,
        },
      ),
    );

    await _supabase.rpc(
      'habilitar_perfil_cerimonialista_v1',
      params: {'p_nome': nomeNormalizado},
    );

    await sincronizarUsuarioAutenticado();
  }

  Future<void> atualizarPerfil({required String nome}) async {
    final nomeNormalizado = nome.trim();
    if (nomeNormalizado.length < 2) {
      throw const AuthException('Informe um nome válido.');
    }

    if (_supabase.auth.currentSession == null ||
        _supabase.auth.currentUser == null) {
      throw const AuthException('Entre na conta para editar o perfil.');
    }

    await _supabase.rpc(
      'atualizar_perfil_usuario_v1',
      params: {'p_nome': nomeNormalizado},
    );
    await sincronizarUsuarioAutenticado();
  }

  /// Exclui definitivamente a conta autenticada.
  ///
  /// A exclusão nunca entra na fila offline: ela só é considerada concluída
  /// depois que o RPC transacional do Supabase termina com sucesso. Só então
  /// os dados locais são removidos e a sessão é encerrada neste aparelho.
  Future<void> excluirConta({required String emailConfirmacao}) async {
    final usuario = _supabase.auth.currentUser;
    final sessao = _supabase.auth.currentSession;
    final email = _normalizarEmail(usuario?.email ?? '');

    if (usuario == null || sessao == null || email.isEmpty) {
      throw const AuthException('Entre novamente para excluir sua conta.');
    }

    if (_normalizarEmail(emailConfirmacao) != email) {
      throw const AuthException('O e-mail de confirmação não confere.');
    }

    await _supabase.rpc(
      'excluir_conta_atual_v1',
      params: {'p_email_confirmacao': emailConfirmacao.trim()},
    );

    // Depois do retorno do servidor, não há mais uma conta válida para
    // sincronizar. A limpeza e o logout precisam acontecer mesmo se algum
    // detalhe local falhar.
    try {
      await _limparTodosOsDadosLocais();
    } finally {
      await RealtimeServico.instance.encerrar();
      _usuarioAtual = null;
      _usuarioAutenticado = null;
      _sincronizacaoUsuarioEmAndamento = null;
      try {
        await _supabase.auth.signOut(scope: SignOutScope.local);
      } catch (erro) {
        // A identidade já foi apagada no servidor. O estado local do Auth
        // ainda precisa ser descartado mesmo quando o SDK rejeita o logout.
        debugPrint('A conta foi excluída; logout local já foi forçado: $erro');
      }
    }
  }

  Future<bool> emailCadastrado(String email) async {
    final resposta = await _supabase.rpc(
      'email_cadastrado_v1',
      params: {'p_email': _normalizarEmail(email)},
    );
    return resposta == true;
  }

  bool _erroIndicaContaExistente(AuthException erro) {
    final codigo = erro.code?.toLowerCase() ?? '';
    final mensagem = erro.message.toLowerCase();

    return codigo == 'user_already_exists' ||
        codigo == 'email_exists' ||
        mensagem.contains('already registered') ||
        mensagem.contains('already exists') ||
        mensagem.contains('user already registered');
  }

  /// Abre o navegador para que a pessoa escolha uma conta Google.
  ///
  /// A sessão anterior do Supabase é removida somente deste aparelho antes de
  /// abrir o navegador. Isso não desconecta as contas Google do celular, então
  /// elas continuam disponíveis no seletor de contas.
  Future<void> entrarComGoogle({
    bool solicitarPerfilCerimonialista = false,
  }) async {
    await prepararNovaAutenticacao();
    await _marcarLoginGooglePendente();
    if (solicitarPerfilCerimonialista) {
      await _marcarPerfilCerimonialistaGooglePendente();
    }

    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'br.com.appcasamento://login-callback',
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
        queryParams: const {'prompt': 'select_account'},
      );
    } catch (_) {
      await limparLoginGooglePendente();
      await limparPerfilCerimonialistaGooglePendente();
      rethrow;
    }
  }

  Future<bool> possuiPerfilCerimonialistaGooglePendente() async {
    return _possuiMarcadorPendente(
      chave: _chavePerfilCerimonialistaGooglePendente,
      validade: _validadePerfilCerimonialistaGooglePendente,
    );
  }

  Future<void> limparPerfilCerimonialistaGooglePendente() async {
    await (_banco.delete(_banco.configuracoesLocais)
          ..where(
            (tabela) => tabela.chave.equals(
              _chavePerfilCerimonialistaGooglePendente,
            ),
          ))
        .go();
  }

  /// Vincula uma conta Google à conta criada pelo convite.
  ///
  /// O usuário já está autenticado pelo link recebido por e-mail. Por isso,
  /// este fluxo não encerra a sessão atual: ele adiciona o Google como uma
  /// nova forma de entrar na mesma conta de funcionário.
  Future<void> vincularGoogleAoConvite() async {
    if (_supabase.auth.currentSession == null ||
        !precisaConcluirPrimeiroAcessoFuncionario) {
      throw const AuthException(
        'O convite não está disponível para vincular uma conta Google.',
      );
    }

    await _marcarVinculoGooglePendente();

    try {
      await _supabase.auth.linkIdentity(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : 'br.com.appcasamento://login-callback',
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
        queryParams: const {'prompt': 'select_account'},
      );
    } catch (_) {
      await limparVinculoGooglePendente();
      rethrow;
    }
  }

  /// Finaliza o primeiro acesso depois que o navegador retorna do Google.
  /// Retorna `true` somente quando a identidade Google já estiver vinculada.
  Future<bool> concluirVinculoGooglePendente() async {
    if (!await possuiVinculoGooglePendente()) return false;
    if (_supabase.auth.currentSession == null) {
      await limparVinculoGooglePendente();
      return false;
    }

    for (var tentativa = 0; tentativa < 8; tentativa++) {
      final identidades = await _supabase.auth.getUserIdentities();
      final possuiGoogle = identidades.any(
        (identidade) => identidade.provider.toLowerCase() == 'google',
      );

      if (possuiGoogle) {
        await _supabase.auth.updateUser(
          UserAttributes(
            data: const {
              'precisa_definir_senha': false,
              'criar_organizacao': false,
              'cadastro_concluido': true,
            },
          ),
        );
        await limparVinculoGooglePendente();
        await sincronizarUsuarioAutenticado();
        return true;
      }

      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    await limparVinculoGooglePendente();
    return false;
  }

  Future<void> enviarRecuperacaoDeSenha(String email) {
    return _supabase.auth.resetPasswordForEmail(
      _normalizarEmail(email),
      redirectTo: kIsWeb ? null : 'br.com.appcasamento://login-callback',
    );
  }

  Future<void> definirSenhaInicial(String senha) async {
    await _supabase.auth.updateUser(
      UserAttributes(
        password: senha,
        data: const {'precisa_definir_senha': false},
      ),
    );
    await sincronizarUsuarioAutenticado();
  }

  Future<bool> possuiVinculoGooglePendente() async {
    return _possuiMarcadorPendente(
      chave: _chaveVinculoGooglePendente,
      validade: _validadeVinculoGooglePendente,
    );
  }

  Future<void> limparVinculoGooglePendente() async {
    await (_banco.delete(_banco.configuracoesLocais)
          ..where(
            (tabela) => tabela.chave.equals(_chaveVinculoGooglePendente),
          ))
        .go();
  }

  /// Indica que o aplicativo estava aguardando o retorno do navegador.
  /// O marcador fica no SQLite para sobreviver caso o Android encerre o
  /// processo enquanto a pessoa está fazendo login no Google.
  Future<bool> possuiLoginGooglePendente() async {
    return _possuiMarcadorPendente(
      chave: _chaveLoginGooglePendente,
      validade: _validadeLoginGooglePendente,
    );
  }

  Future<void> limparLoginGooglePendente() async {
    await (_banco.delete(_banco.configuracoesLocais)
          ..where((tabela) => tabela.chave.equals(_chaveLoginGooglePendente)))
        .go();
  }

  /// Limpa somente a sessão Supabase deste aparelho antes de uma nova entrada.
  /// A conta Google continua salva no navegador/celular e aparecerá novamente
  /// no seletor de contas.
  Future<void> prepararNovaAutenticacao() async {
    await limparLoginGooglePendente();
    await limparVinculoGooglePendente();
    await limparPerfilCerimonialistaGooglePendente();
    await RealtimeServico.instance.encerrar();
    _usuarioAtual = null;
    _usuarioAutenticado = null;
    await CasamentoAtualServico.instance.limparPersistido();

    if (_supabase.auth.currentSession != null) {
      await _supabase.auth.signOut(scope: SignOutScope.local);
    }
  }

  /// Descarta o estado local da conta anterior sem derrubar a sessão que o
  /// Supabase acabou de abrir para a conta do convite.
  Future<void> limparDadosLocaisAoTrocarUsuario() async {
    await limparLoginGooglePendente();
    await limparVinculoGooglePendente();
    await limparPerfilCerimonialistaGooglePendente();
    await RealtimeServico.instance.encerrar();
    _usuarioAtual = null;
    _usuarioAutenticado = null;
    await CasamentoAtualServico.instance.limparPersistido();
  }

  /// Mantido para os serviços de sincronização. A renovação do token é feita
  /// automaticamente pelo Supabase; basta confirmar que ainda há uma sessão.
  Future<bool?> renovarSessao() async => _supabase.auth.currentSession != null;

  Future<void> exigirSessaoAtivaParaSincronizar() async {
    if (_supabase.auth.currentSession == null ||
        _supabase.auth.currentUser == null ||
        _usuarioAtual == null) {
      throw const SessaoInvalidaException(
        'Sua sessão expirou. Entre novamente para sincronizar.',
      );
    }

    try {
      await _supabase.auth.getUser();
    } on AuthException catch (erro) {
      if (_erroIndicaContaRemovida(erro)) {
        await _tratarContaRemovidaNoServidor();
        throw const SessaoInvalidaException(
          'Esta conta foi excluída. Entre novamente para continuar.',
        );
      }
      rethrow;
    }
  }

  Future<void> encerrarSessao() async {
    await limparLoginGooglePendente();
    await limparVinculoGooglePendente();
    await limparPerfilCerimonialistaGooglePendente();
    await RealtimeServico.instance.encerrar();
    _usuarioAtual = null;
    _usuarioAutenticado = null;
    await CasamentoAtualServico.instance.limparPersistido();
    await _supabase.auth.signOut(scope: SignOutScope.local);
  }

  Future<void> _marcarLoginGooglePendente() {
    return _salvarMarcadorPendente(_chaveLoginGooglePendente);
  }

  Future<void> _marcarVinculoGooglePendente() {
    return _salvarMarcadorPendente(_chaveVinculoGooglePendente);
  }

  Future<void> _marcarPerfilCerimonialistaGooglePendente() {
    return _salvarMarcadorPendente(
      _chavePerfilCerimonialistaGooglePendente,
    );
  }

  Future<void> _salvarMarcadorPendente(String chave) async {
    final agora = DateTime.now().toUtc();
    await _banco
        .into(_banco.configuracoesLocais)
        .insertOnConflictUpdate(
          ConfiguracoesLocaisCompanion.insert(
            chave: chave,
            valor: agora.toIso8601String(),
            atualizadoEm: agora,
          ),
        );
  }

  /// Limpa os dados da conta que ficaram no SQLite, preservando somente o ID
  /// deste aparelho para que ele continue sendo reconhecido após um novo
  /// cadastro.
  Future<void> _limparTodosOsDadosLocais() async {
    final dispositivo = await (_banco.select(
      _banco.configuracoesLocais,
    )..where((tabela) => tabela.chave.equals('dispositivo_id'))).getSingleOrNull();

    await _banco.transaction(() async {
      await _banco.delete(_banco.mensagensChatLocais).go();
      await _banco.delete(_banco.staffsLocais).go();
      await _banco.delete(_banco.eventosCheckinLocais).go();
      await _banco.delete(_banco.convidadosLocais).go();
      await _banco.delete(_banco.mesasLocais).go();
      await _banco.delete(_banco.operacoesPendentesLocais).go();
      await _banco.delete(_banco.sincronizacoesLocais).go();
      await _banco.delete(_banco.usuariosAppLocais).go();
      await _banco.delete(_banco.configuracoesLocais).go();

      if (dispositivo != null) {
        await _banco
            .into(_banco.configuracoesLocais)
            .insert(ConfiguracoesLocaisCompanion.insert(
              chave: dispositivo.chave,
              valor: dispositivo.valor,
              atualizadoEm: dispositivo.atualizadoEm,
            ));
      }
    });

    await CasamentoAtualServico.instance.limparPersistido();
  }

  Future<void> _tratarContaRemovidaNoServidor() async {
    try {
      await _limparTodosOsDadosLocais();
    } finally {
      await RealtimeServico.instance.encerrar();
      _usuarioAtual = null;
      _usuarioAutenticado = null;
      try {
        await _supabase.auth.signOut(scope: SignOutScope.local);
      } catch (_) {
        // O token pode já ter sido invalidado pelo servidor.
      }
      if (!_controladorSessaoRevogada.isClosed) {
        _controladorSessaoRevogada.add(
          'Sua conta foi excluída e o acesso foi encerrado neste aparelho.',
        );
      }
    }
  }

  bool _erroIndicaContaRemovida(AuthException erro) {
    final codigo = erro.code?.toLowerCase() ?? '';
    final mensagem = erro.message.toLowerCase();
    const codigos = {
      'user_not_found',
      'user_banned',
    };

    return codigos.contains(codigo) ||
        mensagem.contains('user not found') ||
        mensagem.contains('user does not exist') ||
        mensagem.contains('user from sub claim');
  }

  Future<bool> _possuiMarcadorPendente({
    required String chave,
    required Duration validade,
  }) async {
    final consulta = _banco.select(_banco.configuracoesLocais)
      ..where((tabela) => tabela.chave.equals(chave));
    final registro = await consulta.getSingleOrNull();
    final criadoEm = DateTime.tryParse(registro?.valor ?? '')?.toUtc();

    if (criadoEm == null ||
        DateTime.now().toUtc().difference(criadoEm) > validade) {
      await (_banco.delete(_banco.configuracoesLocais)
            ..where((tabela) => tabela.chave.equals(chave)))
          .go();
      return false;
    }
    return true;
  }

  Future<({User? usuario, bool validadoOnline})>
  _obterUsuarioAtualizado() async {
    final usuarioLocal = _supabase.auth.currentUser;
    if (usuarioLocal == null) {
      return (usuario: null, validadoOnline: false);
    }

    try {
      final usuarioAtualizado = (await _supabase.auth.getUser()).user;
      return (
        usuario: usuarioAtualizado ?? usuarioLocal,
        validadoOnline: true,
      );
    } on AuthException catch (erro) {
      if (_erroIndicaContaRemovida(erro)) {
        await _tratarContaRemovidaNoServidor();
        return (usuario: null, validadoOnline: true);
      }

      // Sem internet, o Supabase mantém a sessão persistida no aparelho. A
      // tela inicial poderá abrir a cópia offline do último casamento.
      debugPrint('Usando usuário da sessão local: $erro');
      return (usuario: usuarioLocal, validadoOnline: false);
    } catch (erro) {
      // Sem internet, o Supabase mantém a sessão persistida no aparelho. A
      // tela inicial poderá abrir a cópia offline do último casamento.
      debugPrint('Usando usuário da sessão local: $erro');
      return (usuario: usuarioLocal, validadoOnline: false);
    }
  }

  String _normalizarEmail(String email) => email.trim().toLowerCase();

  String _nomeDoUsuario(User usuario) {
    final metadados = usuario.userMetadata ?? const <String, dynamic>{};
    final nome = metadados['nome'] ?? metadados['full_name'];
    final texto = nome?.toString().trim();
    if (texto != null && texto.isNotEmpty) {
      return texto;
    }
    return (usuario.email ?? 'Usuário').split('@').first;
  }
}

class SessaoInvalidaException implements Exception {
  final String mensagem;

  const SessaoInvalidaException(this.mensagem);

  @override
  String toString() => mensagem;
}

class ValidacaoSessaoIndisponivelException implements Exception {
  final String mensagem;

  const ValidacaoSessaoIndisponivelException(this.mensagem);

  @override
  String toString() => mensagem;
}
