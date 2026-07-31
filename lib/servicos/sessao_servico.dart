import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../banco/banco_instancia.dart';
import '../banco/banco_local.dart';
import 'casamento_atual_servico.dart';
import 'realtime_servico.dart';

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
  static const Duration _validadeLoginGooglePendente = Duration(minutes: 15);
  static const Duration _validadeVinculoGooglePendente = Duration(minutes: 15);

  final BancoLocal _banco = bancoLocal;
  final SupabaseClient _supabase = Supabase.instance.client;
  final StreamController<String> _controladorSessaoRevogada =
      StreamController<String>.broadcast();

  UsuarioAppLocalRegistro? _usuarioAtual;
  User? _usuarioAutenticado;

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

    await CasamentoAtualServico.instance.garantirOrganizacaoDaCerimonialista();
    await RealtimeServico.instance.inicializar();
    await limparLoginGooglePendente();
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

  Future<void> criarConta({
    required String nome,
    required String email,
    required String senha,
  }) async {
    await prepararNovaAutenticacao();
    final resposta = await _supabase.auth.signUp(
      email: _normalizarEmail(email),
      password: senha,
      data: {'nome': nome.trim(), 'criar_organizacao': true},
    );

    if (resposta.session != null) {
      await sincronizarUsuarioAutenticado();
    }
  }

  /// Abre o navegador para que a pessoa escolha uma conta Google.
  ///
  /// A sessão anterior do Supabase é removida somente deste aparelho antes de
  /// abrir o navegador. Isso não desconecta as contas Google do celular, então
  /// elas continuam disponíveis no seletor de contas.
  Future<void> entrarComGoogle() async {
    await prepararNovaAutenticacao();
    await _marcarLoginGooglePendente();

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
      rethrow;
    }
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
    await RealtimeServico.instance.encerrar();
    _usuarioAtual = null;
    _usuarioAutenticado = null;
    await CasamentoAtualServico.instance.limparPersistido();

    if (_supabase.auth.currentSession != null) {
      await _supabase.auth.signOut(scope: SignOutScope.local);
    }
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
  }

  Future<void> encerrarSessao() async {
    await limparLoginGooglePendente();
    await limparVinculoGooglePendente();
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
