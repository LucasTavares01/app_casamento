import 'package:uuid/uuid.dart';

import '../banco/banco_instancia.dart';
import '../banco/banco_local.dart';

/// Controla a identificação única desta instalação do aplicativo.
///
/// Cada celular ou instalação recebe um UUID diferente. Esse identificador
/// será incluído nas alterações offline para sabermos de qual aparelho
/// cada ação saiu.
class DispositivoServico {
  DispositivoServico._();

  static final DispositivoServico instance = DispositivoServico._();

  final BancoLocal _banco = bancoLocal;

  static const String _chaveDispositivoId = 'dispositivo_id';
  static const String _chaveSequencia = 'sequencia_dispositivo';

  String? _idEmMemoria;

  /// Prepara o identificador durante a abertura do aplicativo.
  Future<void> inicializar() async {
    await obterOuCriarId();
  }

  /// Retorna o identificador existente ou cria um novo.
  ///
  /// O valor fica salvo no SQLite e continua sendo o mesmo depois que
  /// o aplicativo é fechado e aberto novamente.
  Future<String> obterOuCriarId() async {
    if (_idEmMemoria != null && _idEmMemoria!.isNotEmpty) {
      return _idEmMemoria!;
    }

    final consulta = _banco.select(_banco.configuracoesLocais)
      ..where((tabela) => tabela.chave.equals(_chaveDispositivoId));

    final configuracao = await consulta.getSingleOrNull();
    final idExistente = configuracao?.valor.trim();

    if (idExistente != null && idExistente.isNotEmpty) {
      _idEmMemoria = idExistente;
      return idExistente;
    }

    final novoId = const Uuid().v4();
    final agora = DateTime.now().toUtc();

    await _banco
        .into(_banco.configuracoesLocais)
        .insertOnConflictUpdate(
          ConfiguracoesLocaisCompanion.insert(
            chave: _chaveDispositivoId,
            valor: novoId,
            atualizadoEm: agora,
          ),
        );

    _idEmMemoria = novoId;

    return novoId;
  }

  /// Cria um número sequencial para cada ação feita neste aparelho.
  ///
  /// Exemplo:
  /// ação 1, ação 2, ação 3...
  ///
  /// Esse número ajudará a manter a ordem das ações realizadas offline.
  Future<int> proximaSequencia() {
    return _banco.transaction(() async {
      final consulta = _banco.select(_banco.configuracoesLocais)
        ..where((tabela) => tabela.chave.equals(_chaveSequencia));

      final configuracao = await consulta.getSingleOrNull();
      final sequenciaAtual = int.tryParse(configuracao?.valor ?? '') ?? 0;
      final proximaSequencia = sequenciaAtual + 1;

      await _banco
          .into(_banco.configuracoesLocais)
          .insertOnConflictUpdate(
            ConfiguracoesLocaisCompanion.insert(
              chave: _chaveSequencia,
              valor: proximaSequencia.toString(),
              atualizadoEm: DateTime.now().toUtc(),
            ),
          );

      return proximaSequencia;
    });
  }

  /// Retorna apenas o início do ID para exibição e diagnóstico.
  Future<String> obterIdCurto() async {
    final idCompleto = await obterOuCriarId();

    if (idCompleto.length <= 8) {
      return idCompleto;
    }

    return idCompleto.substring(0, 8);
  }
}
