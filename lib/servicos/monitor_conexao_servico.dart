import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'sincronizacao_servico.dart';

/// Observa mudanças na rede do aparelho.
///
/// Quando o aparelho passa de sem rede para conectado, uma nova
/// sincronização é iniciada automaticamente.
class MonitorConexaoServico {
  MonitorConexaoServico._();

  static final MonitorConexaoServico instance = MonitorConexaoServico._();

  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _assinatura;

  bool _inicializado = false;
  bool _estavaSemRede = false;

  Future<void> inicializar() async {
    if (_inicializado) {
      return;
    }

    _inicializado = true;

    final estadoInicial = await _connectivity.checkConnectivity();

    _estavaSemRede = _estaSemRede(estadoInicial);

    _assinatura = _connectivity.onConnectivityChanged.listen(
      _quandoConexaoMudar,
    );
  }

  void _quandoConexaoMudar(List<ConnectivityResult> resultados) {
    final estaSemRede = _estaSemRede(resultados);

    final internetVoltou = _estavaSemRede && !estaSemRede;

    _estavaSemRede = estaSemRede;

    if (internetVoltou) {
      unawaited(SincronizacaoServico.instance.sincronizarDadosIniciais());
    }
  }

  bool _estaSemRede(List<ConnectivityResult> resultados) {
    return resultados.isEmpty ||
        resultados.every((resultado) => resultado == ConnectivityResult.none);
  }

  Future<void> encerrar() async {
    await _assinatura?.cancel();
    _assinatura = null;
    _inicializado = false;
  }
}
