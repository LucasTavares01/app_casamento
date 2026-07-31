import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../banco/banco_instancia.dart';
import '../banco/banco_local.dart';
import 'casamento_atual_servico.dart';

/// Resultado da comparação entre a versão da lista existente no celular e a
/// versão oficial publicada no Supabase.
class ResultadoControleVersaoLista {
  final int versaoServidor;
  final int? versaoLocalAnterior;

  /// Indica uma troca real de versão. A primeira ativação do controle não é
  /// tratada como substituição da lista.
  final bool dadosLocaisRedefinidos;
  final bool primeiraAtivacao;

  /// Quantidade estimada de operações que pertencem à versão anterior.
  /// O sincronizador calcula novamente o total no momento da substituição.
  final int operacoesDescartadas;

  const ResultadoControleVersaoLista({
    required this.versaoServidor,
    required this.versaoLocalAnterior,
    required this.dadosLocaisRedefinidos,
    required this.primeiraAtivacao,
    required this.operacoesDescartadas,
  });
}

/// Compara a versão da lista local com a versão oficial do casamento.
///
/// Este serviço não apaga dados. A lista antiga permanece intacta enquanto a
/// nova cópia é baixada. A substituição só acontece dentro de uma transação,
/// depois que todos os downloads terminam com sucesso.
class ControleVersaoListaServico {
  ControleVersaoListaServico._();

  static final ControleVersaoListaServico instance =
      ControleVersaoListaServico._();

  final BancoLocal _banco = bancoLocal;
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _chaveVersaoLocal = 'versao_lista_oficial';
  static const Duration _tempoLimite = Duration(seconds: 15);

  Future<ResultadoControleVersaoLista> validarAntesDoEnvio() async {
    final versaoServidor = await obterVersaoServidor();
    final versaoLocal = await _obterVersaoLocal();

    final primeiraAtivacao = versaoLocal == null;
    final listaMudou = versaoLocal != null && versaoLocal != versaoServidor;

    var operacoesDaVersaoAnterior = 0;

    if (listaMudou) {
      operacoesDaVersaoAnterior =
          (await _banco.select(_banco.operacoesPendentesLocais).get()).length;
    }

    return ResultadoControleVersaoLista(
      versaoServidor: versaoServidor,
      versaoLocalAnterior: versaoLocal,
      dadosLocaisRedefinidos: listaMudou,
      primeiraAtivacao: primeiraAtivacao,
      operacoesDescartadas: operacoesDaVersaoAnterior,
    );
  }

  /// Lê novamente a versão do servidor. O sincronizador usa esta conferência
  /// depois do download para evitar instalar uma cópia que ficou desatualizada
  /// durante a própria sincronização.
  Future<int> obterVersaoServidor() async {
    final resposta = await _supabase
        .from('controle_lista')
        .select('versao')
        .eq('casamento_id', CasamentoAtualServico.instance.casamentoId)
        .maybeSingle()
        .timeout(_tempoLimite);

    return _converterVersao(resposta?['versao']) ?? 1;
  }

  /// Registra a versão somente depois que os dados correspondentes já foram
  /// gravados com sucesso no SQLite.
  Future<void> confirmarVersaoLocal(int versao) async {
    await _banco
        .into(_banco.configuracoesLocais)
        .insertOnConflictUpdate(
          ConfiguracoesLocaisCompanion.insert(
            chave: _chaveVersaoLocal,
            valor: versao.toString(),
            atualizadoEm: DateTime.now().toUtc(),
          ),
        );
  }

  Future<int?> _obterVersaoLocal() async {
    final consulta = _banco.select(_banco.configuracoesLocais)
      ..where((tabela) => tabela.chave.equals(_chaveVersaoLocal));

    final configuracao = await consulta.getSingleOrNull();
    return int.tryParse(configuracao?.valor ?? '');
  }

  int? _converterVersao(dynamic resposta) {
    if (resposta is int) {
      return resposta;
    }

    if (resposta is num) {
      return resposta.toInt();
    }

    if (resposta is String) {
      return int.tryParse(resposta);
    }

    if (resposta is List && resposta.isNotEmpty) {
      return _converterVersao(resposta.first);
    }

    if (resposta is Map && resposta.isNotEmpty) {
      if (resposta.containsKey('versao')) {
        return _converterVersao(resposta['versao']);
      }

      return _converterVersao(resposta.values.first);
    }

    return null;
  }
}
