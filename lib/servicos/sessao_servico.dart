import 'package:drift/drift.dart';

import '../banco/banco_instancia.dart';
import '../banco/banco_local.dart';

/// Controla o usuário que entrou no aplicativo.
///
/// Durante esta fase do projeto, os usuários e as senhas ficam definidos
/// diretamente no aplicativo. Isso permite que o login funcione offline.
class SessaoServico {
  SessaoServico._();

  static final SessaoServico instance = SessaoServico._();

  final BancoLocal _banco = bancoLocal;

  UsuarioAppLocalRegistro? _usuarioAtual;

  static const String _chaveUltimoUsuario = 'ultimo_usuario_id';

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

  /// Usuário que está utilizando o aplicativo neste momento.
  UsuarioAppLocalRegistro? get usuarioAtual => _usuarioAtual;

  /// Prepara os quatro usuários no banco local.
  ///
  /// Este método é executado quando o aplicativo é iniciado e não depende
  /// de acesso à internet.
  Future<void> inicializar() async {
    await _garantirUsuariosLocais();
  }

  /// Insere ou atualiza os quatro usuários fixos no banco local.
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

  /// Retorna os usuários ativos na ordem definida para o campo de seleção.
  Future<List<UsuarioAppLocalRegistro>> listarUsuariosAtivos() {
    final consulta = _banco.select(_banco.usuariosAppLocais)
      ..where((tabela) => tabela.ativo.equals(true))
      ..orderBy([(tabela) => OrderingTerm.asc(tabela.ordem)]);

    return consulta.get();
  }

  /// Retorna o ID do usuário escolhido na última utilização.
  ///
  /// Isso serve apenas para deixar o nome previamente selecionado.
  /// A senha continuará sendo solicitada toda vez que o aplicativo abrir.
  Future<String?> obterUltimoUsuarioId() async {
    final consulta = _banco.select(_banco.configuracoesLocais)
      ..where((tabela) => tabela.chave.equals(_chaveUltimoUsuario));

    final configuracao = await consulta.getSingleOrNull();

    return configuracao?.valor;
  }

  /// Valida o usuário e a senha sem depender da internet.
  Future<bool> entrar({
    required String usuarioId,
    required String senha,
  }) async {
    String? senhaCorreta;

    for (final usuario in _usuariosIniciais) {
      if (usuario.id == usuarioId) {
        senhaCorreta = usuario.senha;
        break;
      }
    }

    if (senhaCorreta == null || senha.trim() != senhaCorreta) {
      return false;
    }

    final consulta = _banco.select(_banco.usuariosAppLocais)
      ..where(
        (tabela) => tabela.id.equals(usuarioId) & tabela.ativo.equals(true),
      );

    final usuarioEncontrado = await consulta.getSingleOrNull();

    if (usuarioEncontrado == null) {
      return false;
    }

    _usuarioAtual = usuarioEncontrado;

    await _banco
        .into(_banco.configuracoesLocais)
        .insertOnConflictUpdate(
          ConfiguracoesLocaisCompanion.insert(
            chave: _chaveUltimoUsuario,
            valor: usuarioId,
            atualizadoEm: DateTime.now().toUtc(),
          ),
        );

    return true;
  }

  /// Remove somente a sessão que está ativa na memória.
  ///
  /// O último nome utilizado continua salvo para aparecer previamente
  /// selecionado na próxima abertura.
  void encerrarSessao() {
    _usuarioAtual = null;
  }
}

/// Estrutura interna usada para definir os usuários e suas senhas.
///
/// Esta classe não representa uma tabela do Supabase.
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
