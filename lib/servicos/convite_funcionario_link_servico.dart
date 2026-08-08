import 'dart:async';

import 'package:app_links/app_links.dart';

import '../banco/banco_instancia.dart';
import '../banco/banco_local.dart';

/// Recebe o convite próprio do ConfirmaAi sem pedir ao Supabase para consumir
/// um token OTP no clique. O valor guardado é um token opaco de uso único.
class ConviteFuncionarioLinkServico {
  ConviteFuncionarioLinkServico._();

  static final ConviteFuncionarioLinkServico instance =
      ConviteFuncionarioLinkServico._();

  static const _chaveToken = 'convite_funcionario_app_token_pendente';

  final BancoLocal _banco = bancoLocal;
  final AppLinks _appLinks = AppLinks();
  final StreamController<String> _novosConvites =
      StreamController<String>.broadcast();
  StreamSubscription<Uri>? _assinatura;
  String? _tokenPendente;

  String? get tokenPendente => _tokenPendente;
  bool get possuiTokenPendente => (_tokenPendente ?? '').isNotEmpty;
  Stream<String> get novosConvites => _novosConvites.stream;

  Future<void> inicializar() async {
    final local = await (_banco.select(_banco.configuracoesLocais)
          ..where((tabela) => tabela.chave.equals(_chaveToken)))
        .getSingleOrNull();
    _tokenPendente = local?.valor.trim();

    try {
      final inicial = await _appLinks.getInitialLink();
      if (inicial != null) await _processar(inicial);
    } catch (_) {
      // O aplicativo continua funcionando normalmente quando não há link.
    }

    await _assinatura?.cancel();
    _assinatura = _appLinks.uriLinkStream.listen((uri) {
      unawaited(_processar(uri));
    });
  }

  Future<void> _processar(Uri uri) async {
    final ehLinkInterno = uri.scheme == 'br.com.appcasamento' &&
        uri.host == 'convite-funcionario';
    final ehLinkWeb = uri.scheme == 'https' &&
        uri.host == 'confirmaai-convites.netlify.app' &&
        uri.path.startsWith('/convite-funcionario');

    if (!ehLinkInterno && !ehLinkWeb) {
      return;
    }

    final token = uri.queryParameters['token']?.trim() ?? '';
    if (token.isEmpty) return;

    await definirToken(token);
  }

  /// Guarda um token recebido por um fluxo autenticado, mesmo quando o
  /// funcionário entrou diretamente com o Google e não abriu o link original.
  Future<void> definirToken(String token) async {
    token = token.trim();
    if (token.isEmpty) return;

    _tokenPendente = token;
    await (_banco.into(_banco.configuracoesLocais).insertOnConflictUpdate(
          ConfiguracoesLocaisCompanion.insert(
            chave: _chaveToken,
            valor: token,
            atualizadoEm: DateTime.now().toUtc(),
          ),
        ));

    if (!_novosConvites.isClosed) _novosConvites.add(token);
  }

  Future<void> limpar() async {
    _tokenPendente = null;
    await (_banco.delete(_banco.configuracoesLocais)
          ..where((tabela) => tabela.chave.equals(_chaveToken)))
        .go();
  }

  Future<void> dispose() async {
    await _assinatura?.cancel();
    await _novosConvites.close();
  }
}
