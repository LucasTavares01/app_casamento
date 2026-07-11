import 'dart:async';

import 'sincronizacao_servico.dart';

/// Agenda sincronizações automáticas sem executar várias ao mesmo tempo.
///
/// Alterações feitas em sequência são agrupadas. Se uma nova solicitação
/// chegar durante uma sincronização, apenas uma nova execução será agendada
/// depois que a atual terminar.
class SincronizacaoAutomaticaServico {
  SincronizacaoAutomaticaServico._();

  static final SincronizacaoAutomaticaServico instance =
      SincronizacaoAutomaticaServico._();

  static const Duration _atrasoPadrao = Duration(milliseconds: 900);
  static const Duration _atrasoDepoisDeExecucao = Duration(milliseconds: 900);
  static const Duration _novaVerificacaoSeOcupado = Duration(seconds: 1);

  Timer? _temporizador;
  bool _executando = false;
  bool _solicitacaoPendente = false;

  bool get executando => _executando;

  /// Agenda uma sincronização automática.
  ///
  /// Chamadas repetidas reiniciam o temporizador para que várias alterações
  /// próximas sejam enviadas juntas.
  void agendar({Duration atraso = _atrasoPadrao}) {
    _solicitacaoPendente = true;
    _agendarTemporizador(atraso);
  }

  /// Solicita uma sincronização sem o atraso normal.
  void sincronizarAgora() {
    agendar(atraso: Duration.zero);
  }

  void _agendarTemporizador(Duration atraso) {
    _temporizador?.cancel();
    _temporizador = Timer(atraso, () => unawaited(_executarQuandoPossivel()));
  }

  Future<void> _executarQuandoPossivel() async {
    _temporizador = null;

    if (!_solicitacaoPendente) {
      return;
    }

    if (_executando || SincronizacaoServico.instance.emAndamento) {
      _agendarTemporizador(_novaVerificacaoSeOcupado);
      return;
    }

    _solicitacaoPendente = false;
    _executando = true;

    try {
      await SincronizacaoServico.instance.sincronizarDadosIniciais();
    } catch (_) {
      // O SincronizacaoServico já registra e exibe o erro. Este catch evita
      // que uma exceção inesperada deixe o agendador permanentemente ocupado.
    } finally {
      _executando = false;

      if (_solicitacaoPendente) {
        _agendarTemporizador(_atrasoDepoisDeExecucao);
      }
    }
  }

  void cancelarAgendamento() {
    _temporizador?.cancel();
    _temporizador = null;
    _solicitacaoPendente = false;
    _executando = false;
  }
}
