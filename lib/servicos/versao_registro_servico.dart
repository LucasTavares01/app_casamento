import 'package:drift/drift.dart';

import '../banco/banco_instancia.dart';
import '../banco/banco_local.dart';

/// Guarda a versão exata recebida do Supabase para mesas e convidados.
///
/// O SQLite converte DateTime e pode perder parte da precisão do timestamp.
/// Para detectar alterações simultâneas corretamente, o app precisa enviar ao
/// servidor exatamente o texto de `updated_at` que recebeu da nuvem.
class VersaoRegistroServico {
  VersaoRegistroServico._();

  static final VersaoRegistroServico instance = VersaoRegistroServico._();

  final BancoLocal _banco = bancoLocal;

  static const String _prefixo = 'versao_registro_servidor:';

  String _chave(String entidade, String id) => '$_prefixo$entidade:$id';

  /// Retorna a última versão confirmada pelo servidor.
  ///
  /// O fallback existe para instalações que ainda não fizeram a primeira
  /// sincronização depois desta correção.
  Future<String> obterVersaoBase({
    required String entidade,
    required String id,
    required DateTime fallback,
  }) async {
    final consulta = _banco.select(_banco.configuracoesLocais)
      ..where((tabela) => tabela.chave.equals(_chave(entidade, id)));

    final registro = await consulta.getSingleOrNull();
    final valor = registro?.valor.trim();

    if (valor != null && valor.isNotEmpty) {
      return valor;
    }

    return fallback.toUtc().toIso8601String();
  }

  /// Salva o texto exato de `updated_at` devolvido pelo Supabase.
  Future<void> salvarVersaoConfirmada({
    required String entidade,
    required String id,
    required String updatedAt,
  }) async {
    final valor = updatedAt.trim();
    if (valor.isEmpty) return;

    await _banco
        .into(_banco.configuracoesLocais)
        .insertOnConflictUpdate(
          ConfiguracoesLocaisCompanion.insert(
            chave: _chave(entidade, id),
            valor: valor,
            atualizadoEm: DateTime.now().toUtc(),
          ),
        );
  }

  Future<void> removerVersao({
    required String entidade,
    required String id,
  }) async {
    await (_banco.delete(
      _banco.configuracoesLocais,
    )..where((tabela) => tabela.chave.equals(_chave(entidade, id)))).go();
  }

  /// Apaga somente as versões dos registros, preservando identificação do
  /// aparelho, usuário, sequência offline e versão global da lista.
  Future<void> limparTodasAsVersoes() async {
    await (_banco.delete(
      _banco.configuracoesLocais,
    )..where((tabela) => tabela.chave.like('$_prefixo%'))).go();
  }
}
