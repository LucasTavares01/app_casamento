import 'dart:async';

import 'package:flutter/foundation.dart';

import '../modelos/modelos.dart';
import 'supabase_servico.dart';

/// Estado completo usado pelas abas de confirmação do evento atual.
///
/// Os três conjuntos de dados são publicados juntos. Isso evita que a tela
/// monte uma combinação temporária de convidados, convites e confirmações de
/// momentos diferentes.
class RecepcaoConfirmacoesSnapshot {
  final List<Convidado> convidados;
  final List<Map<String, dynamic>> convites;
  final List<Map<String, dynamic>> confirmacoes;

  const RecepcaoConfirmacoesSnapshot({
    required this.convidados,
    required this.convites,
    required this.confirmacoes,
  });
}

List<Map<String, dynamic>> removerConfirmacaoOtimista(
  List<Map<String, dynamic>> registros,
  String idOtimista,
) {
  return registros
      .where((registro) => registro['id']?.toString() != idOtimista)
      .map((registro) => Map<String, dynamic>.from(registro))
      .toList();
}

/// Mantém uma única leitura compartilhada dos dados usados pelas abas
/// Presença e Online do evento atual.
///
/// As abas recebem o último snapshot completo. Assim, trocar de aba não cria
/// novas consultas nem mostra uma fotografia parcialmente antiga enquanto uma
/// das fontes ainda está atualizando.
class RecepcaoConfirmacoesEstado extends ChangeNotifier {
  final SupabaseServico _servico;

  final StreamController<RecepcaoConfirmacoesSnapshot> _estadoController =
      StreamController<RecepcaoConfirmacoesSnapshot>.broadcast(sync: true);

  late final StreamSubscription<List<Convidado>> _convidadosAssinatura;
  late final StreamSubscription<List<Map<String, dynamic>>> _convitesAssinatura;
  late final StreamSubscription<List<Map<String, dynamic>>>
  _confirmacoesAssinatura;

  List<Convidado>? _convidados;
  List<Map<String, dynamic>>? _convites;
  List<Map<String, dynamic>>? _confirmacoes;
  RecepcaoConfirmacoesSnapshot? _ultimoEstado;
  Object? _erro;
  String? _mensagemErro;
  bool _encerrado = false;
  int _sequenciaOtimista = 0;
  Timer? _carregamentoTimer;

  RecepcaoConfirmacoesEstado(this._servico) {
    _estadoController.onListen = () {
      final valor = _ultimoEstado;
      if (valor != null && !_encerrado) {
        _estadoController.add(valor);
      }
    };

    _convidadosAssinatura = _servico.listarConvidados().listen(
      _receberConvidados,
      onError: _receberErro,
    );
    _convitesAssinatura = _servico.observarConvitesOnline().listen(
      _receberConvites,
      onError: _receberErro,
    );
    _confirmacoesAssinatura = _servico.observarConfirmacoesConvidados().listen(
      _receberConfirmacoes,
      onError: _receberErro,
    );
    _carregamentoTimer = Timer(const Duration(seconds: 8), () {
      if (!_encerrado && _ultimoEstado == null && _erro == null) {
        _receberErro(
          TimeoutException('Dados online ainda não chegaram.'),
          StackTrace.current,
        );
      }
    });
  }

  Stream<RecepcaoConfirmacoesSnapshot> get estadoStream =>
      _estadoController.stream;

  RecepcaoConfirmacoesSnapshot? get ultimoEstado => _ultimoEstado;

  Object? get erro => _erro;

  String? get mensagemErro => _mensagemErro;

  void _receberConvidados(List<Convidado> valor) {
    if (_encerrado) return;
    _convidados = List<Convidado>.unmodifiable(valor);
    _publicarEstado();
  }

  void _receberConvites(List<Map<String, dynamic>> valor) {
    if (_encerrado) return;
    _convites = _copiarRegistros(valor);
    _publicarEstado();
  }

  void _receberConfirmacoes(List<Map<String, dynamic>> valor) {
    if (_encerrado) return;
    _confirmacoes = _copiarRegistros(valor);
    _publicarEstado();
  }

  void _publicarEstado() {
    if (_encerrado ||
        _convidados == null ||
        _convites == null ||
        _confirmacoes == null) {
      return;
    }

    _erro = null;
    _mensagemErro = null;
    _carregamentoTimer?.cancel();
    _carregamentoTimer = null;
    _ultimoEstado = RecepcaoConfirmacoesSnapshot(
      convidados: _convidados!,
      convites: _convites!,
      confirmacoes: _confirmacoes!,
    );
    if (_estadoController.hasListener) {
      _estadoController.add(_ultimoEstado!);
    }
    notifyListeners();
  }

  void _receberErro(Object erro, StackTrace stackTrace) {
    if (_encerrado) return;
    _erro = erro;
    _mensagemErro =
        'Não foi possível carregar os dados online. Verifique a internet e tente novamente.';
    if (_estadoController.hasListener) {
      _estadoController.addError(erro, stackTrace);
    }
    notifyListeners();
  }

  List<Map<String, dynamic>> _copiarRegistros(
    List<Map<String, dynamic>> registros,
  ) {
    return List<Map<String, dynamic>>.unmodifiable(
      registros.map((registro) => Map<String, dynamic>.from(registro)),
    );
  }

  /// Atualiza a confirmação imediatamente nas duas abas e confirma a
  /// alteração no Supabase em seguida.
  Future<void> marcarConfirmacaoManual({
    required String convidadoId,
    required bool confirmado,
  }) async {
    final idOtimista = 'otimista-$convidadoId-${++_sequenciaOtimista}';
    final atuais = List<Map<String, dynamic>>.from(_confirmacoes ?? const []);
    atuais.removeWhere(
      (registro) => registro['convidado_id']?.toString() == convidadoId,
    );
    atuais.add({
      'id': 'otimista-$convidadoId',
      'convidado_id': convidadoId,
      'status': confirmado ? 'confirmado' : 'aguardando',
      'origem': 'manual',
    });
    _confirmacoes = _copiarRegistros(atuais);
    _publicarEstado();

    try {
      await _servico.marcarConfirmacaoConvidado(
        convidadoId: convidadoId,
        confirmado: confirmado,
      );
    } catch (_) {
      // Remove somente a confirmação otimista desta chamada. Restaurar a
      // lista inteira poderia apagar a confirmação feita por outra chamada
      // simultânea ou por outro aparelho.
      final atuaisDepoisDoErro = List<Map<String, dynamic>>.from(
        _confirmacoes ?? const [],
      );
      _confirmacoes = _copiarRegistros(
        removerConfirmacaoOtimista(atuaisDepoisDoErro, idOtimista),
      );
      _publicarEstado();
      rethrow;
    }
  }

  Future<void> fechar() async {
    if (_encerrado) return;
    _encerrado = true;
    _carregamentoTimer?.cancel();
    _carregamentoTimer = null;
    await Future.wait([
      _convidadosAssinatura.cancel(),
      _convitesAssinatura.cancel(),
      _confirmacoesAssinatura.cancel(),
      _estadoController.close(),
    ]);
    super.dispose();
  }
}
