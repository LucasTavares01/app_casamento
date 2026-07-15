import 'dart:async';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../banco/banco_instancia.dart';
import '../banco/banco_local.dart';
import 'dispositivo_servico.dart';

/// Controla o usuário que entrou no aplicativo e garante uma única sessão
/// ativa por usuário no servidor.
class SessaoServico {
  SessaoServico._();

  static final SessaoServico instance = SessaoServico._();

  final BancoLocal _banco = bancoLocal;
  final SupabaseClient _supabase = Supabase.instance.client;
  final StreamController<String> _controladorSessaoRevogada =
      StreamController<String>.broadcast();

  UsuarioAppLocalRegistro? _usuarioAtual;
  Timer? _heartbeat;
  String? _sessaoIdAtual;
  String? _ultimoErroLogin;
  bool _revogacaoJaNotificada = false;

  static const String _chaveUltimoUsuario = 'ultimo_usuario_id';
  static const Duration _intervaloHeartbeat = Duration(seconds: 45);

  static const List<_UsuarioInicial> _usuariosIniciais = [
    _UsuarioInicial(
      id: '10000000-0000-4000-8000-000000000001',
      nome: 'Gabriela',
      senha: 'festa1',
      ordem: 1,
    ),
    _UsuarioInicial(
      id: '10000000-0000-4000-8000-000000000002',
      nome: 'William',
      senha: 'festa2',
      ordem: 2,
    ),
    _UsuarioInicial(
      id: '10000000-0000-4000-8000-000000000003',
      nome: 'Joice',
      senha: 'festa3',
      ordem: 3,
    ),
    _UsuarioInicial(
      id: '10000000-0000-4000-8000-000000000004',
      nome: 'Pedro',
      senha: 'festa4',
      ordem: 4,
    ),
  ];

  UsuarioAppLocalRegistro? get usuarioAtual => _usuarioAtual;
  String? get ultimoErroLogin => _ultimoErroLogin;
  bool get possuiSessaoLocal => _usuarioAtual != null && _sessaoIdAtual != null;

  /// Emite uma mensagem quando o servidor informa que esta sessão perdeu a
  /// reserva para outra sessão.
  Stream<String> get sessoesRevogadas => _controladorSessaoRevogada.stream;

  Future<void> inicializar() async => _garantirUsuariosLocais();

  Future<void> _garantirUsuariosLocais() async {
    final agora = DateTime.now().toUtc();
    for (final usuario in _usuariosIniciais) {
      await _banco
          .into(_banco.usuariosAppLocais)
          .insertOnConflictUpdate(
            UsuariosAppLocaisCompanion.insert(
              id: usuario.id,
              nome: usuario.nome,
              ordem: Value(usuario.ordem),
              ativo: const Value(true),
              criadoEm: agora,
            ),
          );
    }
  }

  Future<List<UsuarioAppLocalRegistro>> listarUsuariosAtivos() {
    final consulta = _banco.select(_banco.usuariosAppLocais)
      ..where((tabela) => tabela.ativo.equals(true))
      ..orderBy([(tabela) => OrderingTerm.asc(tabela.ordem)]);
    return consulta.get();
  }

  Future<String?> obterUltimoUsuarioId() async {
    final consulta = _banco.select(_banco.configuracoesLocais)
      ..where((tabela) => tabela.chave.equals(_chaveUltimoUsuario));
    return (await consulta.getSingleOrNull())?.valor;
  }

  /// O login exige internet para reservar uma sessão exclusiva no servidor.
  ///
  /// A exclusividade usa um ID novo para cada tentativa de login. Portanto,
  /// mesmo que dois emuladores tenham sido clonados e possuam o mesmo ID de
  /// dispositivo, eles não serão tratados como a mesma sessão.
  Future<bool> entrar({
    required String usuarioId,
    required String senha,
  }) async {
    _ultimoErroLogin = null;

    final usuarioInicial = _usuariosIniciais
        .cast<_UsuarioInicial?>()
        .firstWhere((usuario) => usuario?.id == usuarioId, orElse: () => null);

    if (usuarioInicial == null || senha.trim() != usuarioInicial.senha) {
      _ultimoErroLogin = 'Senha incorreta para o usuário selecionado.';
      return false;
    }

    final consulta = _banco.select(_banco.usuariosAppLocais)
      ..where(
        (tabela) => tabela.id.equals(usuarioId) & tabela.ativo.equals(true),
      );
    final usuarioEncontrado = await consulta.getSingleOrNull();

    if (usuarioEncontrado == null) {
      _ultimoErroLogin = 'Este usuário está desativado.';
      return false;
    }

    final dispositivoId = await DispositivoServico.instance.obterOuCriarId();
    final novaSessaoId = const Uuid().v4();

    try {
      final resposta = await _supabase
          .rpc(
            'adquirir_sessao_usuario_v2',
            params: {
              'p_usuario_id': usuarioId,
              'p_dispositivo_id': dispositivoId,
              'p_sessao_id': novaSessaoId,
            },
          )
          .timeout(const Duration(seconds: 12));

      final mapa = _converterResposta(resposta);
      final permitido = mapa['permitido'] == true;

      if (!permitido) {
        _ultimoErroLogin =
            mapa['mensagem']?.toString() ??
            'Este usuário já está conectado em outro aparelho.';
        return false;
      }
    } on TimeoutException {
      _ultimoErroLogin =
          'É necessário estar online para iniciar uma nova sessão.';
      return false;
    } catch (_) {
      _ultimoErroLogin =
          'Não foi possível validar a sessão. Verifique a internet e tente novamente.';
      return false;
    }

    _usuarioAtual = usuarioEncontrado;
    _sessaoIdAtual = novaSessaoId;
    _revogacaoJaNotificada = false;

    await _banco
        .into(_banco.configuracoesLocais)
        .insertOnConflictUpdate(
          ConfiguracoesLocaisCompanion.insert(
            chave: _chaveUltimoUsuario,
            valor: usuarioId,
            atualizadoEm: DateTime.now().toUtc(),
          ),
        );

    _iniciarHeartbeat();
    return true;
  }

  void _iniciarHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(_intervaloHeartbeat, (_) {
      renovarSessao();
    });
  }

  /// Renova a sessão atual.
  ///
  /// Retorna:
  /// - `true`: a sessão continua sendo deste aplicativo;
  /// - `false`: outra sessão assumiu o usuário ou a sessão não existe mais;
  /// - `null`: não foi possível consultar o servidor, normalmente por estar
  ///   offline. Nesse caso o trabalho local continua permitido.
  Future<bool?> renovarSessao() async {
    final usuario = _usuarioAtual;
    final sessaoId = _sessaoIdAtual;

    if (usuario == null || sessaoId == null) {
      return false;
    }

    try {
      final dispositivoId = await DispositivoServico.instance.obterOuCriarId();
      final resposta = await _supabase
          .rpc(
            'renovar_sessao_usuario_v2',
            params: {
              'p_usuario_id': usuario.id,
              'p_dispositivo_id': dispositivoId,
              'p_sessao_id': sessaoId,
            },
          )
          .timeout(const Duration(seconds: 10));

      final renovada = _converterBooleano(resposta);

      if (!renovada) {
        _revogarSessaoLocal(
          'A sessão de ${usuario.nome} não está mais ativa neste aparelho. '
          'Esse usuário pode ter sido conectado em outro aparelho.',
        );
      }

      return renovada;
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Antes de qualquer envio à nuvem, exige que esta instalação ainda seja a
  /// dona da sessão. Assim, um aparelho que voltou do modo offline não envia
  /// alterações caso o usuário já tenha iniciado sessão em outro aparelho.
  Future<void> exigirSessaoAtivaParaSincronizar() async {
    if (!possuiSessaoLocal) {
      throw const SessaoInvalidaException(
        'Não existe uma sessão ativa neste aparelho. Entre novamente.',
      );
    }

    final resultado = await renovarSessao();

    if (resultado == true) {
      return;
    }

    if (resultado == false) {
      throw const SessaoInvalidaException(
        'Sua sessão foi encerrada porque este usuário está ativo em outro aparelho.',
      );
    }

    throw const ValidacaoSessaoIndisponivelException(
      'Não foi possível validar a sessão no servidor. '
      'As alterações continuam salvas no celular e não foram enviadas.',
    );
  }

  Future<void> encerrarSessao() async {
    _heartbeat?.cancel();
    _heartbeat = null;

    final usuario = _usuarioAtual;
    final sessaoId = _sessaoIdAtual;

    _usuarioAtual = null;
    _sessaoIdAtual = null;
    _revogacaoJaNotificada = false;

    if (usuario == null || sessaoId == null) {
      return;
    }

    try {
      final dispositivoId = await DispositivoServico.instance.obterOuCriarId();
      await _supabase
          .rpc(
            'liberar_sessao_usuario_v2',
            params: {
              'p_usuario_id': usuario.id,
              'p_dispositivo_id': dispositivoId,
              'p_sessao_id': sessaoId,
            },
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // A sessão expira automaticamente no servidor.
    }
  }

  void _revogarSessaoLocal(String mensagem) {
    _heartbeat?.cancel();
    _heartbeat = null;
    _usuarioAtual = null;
    _sessaoIdAtual = null;

    if (_revogacaoJaNotificada) {
      return;
    }

    _revogacaoJaNotificada = true;
    _controladorSessaoRevogada.add(mensagem);
  }

  bool _converterBooleano(dynamic resposta) {
    if (resposta is bool) {
      return resposta;
    }

    if (resposta is List && resposta.isNotEmpty) {
      return _converterBooleano(resposta.first);
    }

    if (resposta is Map) {
      final valor = resposta['renovada'] ?? resposta['resultado'];
      return valor == true;
    }

    return resposta?.toString().toLowerCase() == 'true';
  }

  Map<String, dynamic> _converterResposta(dynamic resposta) {
    if (resposta is Map) {
      return Map<String, dynamic>.from(resposta);
    }

    if (resposta is List && resposta.isNotEmpty && resposta.first is Map) {
      return Map<String, dynamic>.from(resposta.first as Map);
    }

    return <String, dynamic>{};
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

class _UsuarioInicial {
  final String id;
  final String nome;
  final String senha;
  final int ordem;

  const _UsuarioInicial({
    required this.id,
    required this.nome,
    required this.senha,
    required this.ordem,
  });
}
