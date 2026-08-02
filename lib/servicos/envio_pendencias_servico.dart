import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../banco/banco_instancia.dart';
import '../banco/banco_local.dart';
import 'casamento_atual_servico.dart';

/// Resultado do envio da fila local para o Supabase.
class ResultadoEnvioPendencias {
  final int totalEncontradas;
  final int enviadas;
  final int comErro;
  final String? primeiroErro;
  final List<String> detalhesErros;

  const ResultadoEnvioPendencias({
    required this.totalEncontradas,
    required this.enviadas,
    required this.comErro,
    this.primeiroErro,
    this.detalhesErros = const [],
  });

  bool get tudoEnviado => comErro == 0;
}

/// Envia para o Supabase as operações que foram feitas no celular.
///
/// As operações somente são removidas da fila depois que o servidor
/// confirma que recebeu os dados.
class EnvioPendenciasServico {
  EnvioPendenciasServico._();

  static final EnvioPendenciasServico instance = EnvioPendenciasServico._();

  final BancoLocal _banco = bancoLocal;
  final SupabaseClient _supabase = Supabase.instance.client;

  static const Duration _tempoLimiteRequisicao = Duration(seconds: 25);

  /// Envia todas as operações pendentes.
  ///
  /// A ordem é importante:
  ///
  /// 1. Mesas;
  /// 2. Convidados;
  /// 3. Staff;
  /// 4. Mensagens;
  /// 5. Eventos de check-in.
  ///
  /// Os eventos ficam por último para que o trigger do Supabase calcule
  /// o estado final da chegada depois das outras alterações.
  Future<ResultadoEnvioPendencias> enviarPendencias() async {
    if (CasamentoAtualServico.instance.somenteLeitura) {
      return const ResultadoEnvioPendencias(
        totalEncontradas: 0,
        enviadas: 0,
        comErro: 0,
      );
    }

    final pendencias = await _listarPendenciasOrdenadas();

    if (pendencias.isEmpty) {
      return const ResultadoEnvioPendencias(
        totalEncontradas: 0,
        enviadas: 0,
        comErro: 0,
      );
    }

    var quantidadeEnviada = 0;
    var quantidadeComErro = 0;
    String? primeiroErro;
    final detalhesErros = <String>[];

    for (final operacao in pendencias) {
      try {
        await _marcarComoEnviando(operacao.id);

        await _enviarOperacao(operacao);

        await _concluirOperacao(operacao);

        quantidadeEnviada++;
      } catch (erro) {
        quantidadeComErro++;

        primeiroErro ??= erro.toString();
        detalhesErros.add(_montarDetalhesErro(operacao, erro));

        await _marcarComoErro(operacao: operacao, erro: erro);
      }
    }

    return ResultadoEnvioPendencias(
      totalEncontradas: pendencias.length,
      enviadas: quantidadeEnviada,
      comErro: quantidadeComErro,
      primeiroErro: primeiroErro,
      detalhesErros: detalhesErros,
    );
  }

  String _montarDetalhesErro(
    OperacaoPendenteLocalRegistro operacao,
    Object erro,
  ) {
    var mensagemErro = erro.toString();

    if (mensagemErro.length > 2000) {
      mensagemErro = mensagemErro.substring(0, 2000);
    }

    return 'Operação: ${operacao.tipoOperacao}\n'
        'Entidade: ${operacao.entidade}\n'
        'ID do registro: ${operacao.entidadeId}\n'
        'Tentativa: ${operacao.tentativas + 1}\n'
        'Erro: $mensagemErro';
  }

  /// Busca todas as operações e organiza pela dependência das tabelas.
  Future<List<OperacaoPendenteLocalRegistro>>
  _listarPendenciasOrdenadas() async {
    final consulta = _banco.select(_banco.operacoesPendentesLocais)
      ..orderBy([(tabela) => OrderingTerm.asc(tabela.criadoEm)]);

    final pendencias = await consulta.get();

    pendencias.sort((primeira, segunda) {
      final prioridadePrimeira = _prioridadeEntidade(primeira.entidade);

      final prioridadeSegunda = _prioridadeEntidade(segunda.entidade);

      final comparacaoPrioridade = prioridadePrimeira.compareTo(
        prioridadeSegunda,
      );

      if (comparacaoPrioridade != 0) {
        return comparacaoPrioridade;
      }

      return primeira.criadoEm.compareTo(segunda.criadoEm);
    });

    return pendencias;
  }

  int _prioridadeEntidade(String entidade) {
    switch (entidade) {
      case 'mesa':
        return 10;

      case 'convidado':
        return 20;

      case 'staff':
        return 30;

      case 'mensagem_chat':
        return 40;

      case 'evento_checkin':
        return 50;

      default:
        return 100;
    }
  }

  Future<void> _enviarOperacao(OperacaoPendenteLocalRegistro operacao) async {
    final payload = _decodificarPayload(operacao.payloadJson);

    switch (operacao.entidade) {
      case 'mesa':
        await _enviarEntidadeComConflito(
          entidade: 'mesa',
          operacao: operacao,
          payload: payload,
        );
        return;

      case 'convidado':
        await _enviarEntidadeComConflito(
          entidade: 'convidado',
          operacao: operacao,
          payload: payload,
        );
        return;

      case 'staff':
        await _enviarRegistroComUpsert(tabela: 'staff', payload: payload);
        return;

      case 'mensagem_chat':
        await _enviarRegistroComUpsert(tabela: 'chat', payload: payload);
        return;

      case 'evento_checkin':
        await _enviarEventoCheckin(payload);
        return;

      default:
        throw StateError(
          'Entidade desconhecida na fila: ${operacao.entidade}.',
        );
    }
  }

  Future<void> _enviarEntidadeComConflito({
    required String entidade,
    required OperacaoPendenteLocalRegistro operacao,
    required Map<String, dynamic> payload,
  }) async {
    await _supabase
        .rpc(
          'aplicar_operacao_entidade_v2',
          params: {
            'p_operacao_id': operacao.id,
            'p_entidade': entidade,
            'p_tipo_operacao': operacao.tipoOperacao,
            'p_payload': payload,
          },
        )
        .timeout(_tempoLimiteRequisicao);
  }

  /// Insere ou atualiza o registro usando o ID criado no celular.
  ///
  /// Isso torna a operação segura para ser repetida depois de uma
  /// interrupção de internet.
  Future<void> _enviarRegistroComUpsert({
    required String tabela,
    required Map<String, dynamic> payload,
  }) async {
    await _supabase
        .from(tabela)
        .upsert(payload, onConflict: 'id')
        .timeout(_tempoLimiteRequisicao);
  }

  /// Envia um evento utilizando a função criada no Supabase.
  ///
  /// A versão v5 recebe o casamento e o nome do convidado diretamente do payload. Isso permite
  /// registrar um conflito mesmo quando a nova lista oficial já removeu o
  /// convidado e a mesa conhecidos pelo aparelho offline.
  Future<void> _enviarEventoCheckin(Map<String, dynamic> payload) async {
    final eventoId = _lerTextoObrigatorio(payload['id']);
    final convidadoId = _lerTextoObrigatorio(payload['convidado_id']);

    final resposta = await _supabase
        .rpc(
          'registrar_evento_checkin_v5',
          params: {
            'p_id': eventoId,
            'p_casamento_id': _lerTextoObrigatorio(payload['casamento_id']),
            'p_convidado_id': convidadoId,
            'p_convidado_nome_contexto': _lerTextoObrigatorio(
              payload['convidado_nome_contexto'],
            ),
            'p_usuario_id': _lerTextoObrigatorio(payload['usuario_id']),
            'p_tipo_acao': _lerTextoObrigatorio(payload['tipo_acao']),
            'p_estado_resultante': _lerBooleano(payload['estado_resultante']),
            'p_eventos_base': _lerListaDeTextos(payload['eventos_base']),
            'p_data_dispositivo': _lerTextoObrigatorio(
              payload['data_dispositivo'],
            ),
            'p_sequencia_dispositivo': _lerInteiro(
              payload['sequencia_dispositivo'],
            ),
            'p_dispositivo_id': _lerTextoObrigatorio(payload['dispositivo_id']),
            'p_mesa_id_contexto': payload['mesa_id_contexto'],
            'p_mesa_numero_contexto': payload['mesa_numero_contexto'],
            'p_mesa_detalhe_contexto': payload['mesa_detalhe_contexto'],
            'p_observacao': payload['observacao'],
          },
        )
        .timeout(_tempoLimiteRequisicao);

    final respostaConvertida = _converterRespostaRpc(resposta);

    final eventoRegistrado = _lerBooleano(
      respostaConvertida['evento_registrado'],
    );

    final conflitoId = respostaConvertida['conflito_id']?.toString();
    final conflitoCriado = conflitoId != null && conflitoId.isNotEmpty;

    if (!eventoRegistrado && !conflitoCriado) {
      throw StateError(
        'O servidor não registrou o check-in nem criou um conflito. '
        'A operação continuará pendente para evitar perda de dados.',
      );
    }

    final dataServidor = DateTime.tryParse(
      respostaConvertida['data_servidor']?.toString() ?? '',
    )?.toUtc();

    await (_banco.update(
      _banco.eventosCheckinLocais,
    )..where((tabela) => tabela.id.equals(eventoId))).write(
      EventosCheckinLocaisCompanion(
        sincronizado: const Value(true),
        dataServidor: Value(dataServidor),
      ),
    );

    if (conflitoCriado) {
      await (_banco.update(
        _banco.convidadosLocais,
      )..where((tabela) => tabela.id.equals(convidadoId))).write(
        const ConvidadosLocaisCompanion(
          temConflito: Value(true),
        ),
      );
    }
  }

  Map<String, dynamic> _converterRespostaRpc(dynamic resposta) {
    if (resposta is Map<String, dynamic>) {
      return resposta;
    }

    if (resposta is Map) {
      return Map<String, dynamic>.from(resposta);
    }

    if (resposta is List && resposta.isNotEmpty && resposta.first is Map) {
      return Map<String, dynamic>.from(resposta.first as Map);
    }

    return <String, dynamic>{};
  }

  Map<String, dynamic> _decodificarPayload(String payloadJson) {
    final valor = jsonDecode(payloadJson);

    if (valor is! Map) {
      throw const FormatException(
        'O conteúdo da operação pendente não é um objeto JSON.',
      );
    }

    return Map<String, dynamic>.from(valor);
  }

  Future<void> _marcarComoEnviando(String operacaoId) async {
    await (_banco.update(
      _banco.operacoesPendentesLocais,
    )..where((tabela) => tabela.id.equals(operacaoId))).write(
      const OperacoesPendentesLocaisCompanion(
        status: Value('enviando'),
        ultimoErro: Value<String?>(null),
      ),
    );
  }

  Future<void> _marcarComoErro({
    required OperacaoPendenteLocalRegistro operacao,
    required Object erro,
  }) async {
    var mensagemErro = erro.toString();

    if (mensagemErro.length > 2000) {
      mensagemErro = mensagemErro.substring(0, 2000);
    }

    await (_banco.update(
      _banco.operacoesPendentesLocais,
    )..where((tabela) => tabela.id.equals(operacao.id))).write(
      OperacoesPendentesLocaisCompanion(
        status: const Value('erro'),
        tentativas: Value(operacao.tentativas + 1),
        ultimoErro: Value(mensagemErro),
      ),
    );
  }

  /// Remove da fila somente depois que o Supabase confirmou o envio.
  Future<void> _concluirOperacao(OperacaoPendenteLocalRegistro operacao) async {
    await (_banco.delete(
      _banco.operacoesPendentesLocais,
    )..where((tabela) => tabela.id.equals(operacao.id))).go();
  }

  String _lerTextoObrigatorio(dynamic valor) {
    final texto = valor?.toString();

    if (texto == null || texto.isEmpty) {
      throw const FormatException(
        'Existe um campo obrigatório vazio na operação pendente.',
      );
    }

    return texto;
  }

  int _lerInteiro(dynamic valor) {
    if (valor is int) {
      return valor;
    }

    if (valor is num) {
      return valor.toInt();
    }

    final convertido = int.tryParse(valor?.toString() ?? '');

    if (convertido == null) {
      throw const FormatException(
        'Existe um número inválido na operação pendente.',
      );
    }

    return convertido;
  }

  bool _lerBooleano(dynamic valor) {
    if (valor is bool) {
      return valor;
    }

    final texto = valor?.toString().toLowerCase();

    if (texto == 'true' || texto == '1') {
      return true;
    }

    if (texto == 'false' || texto == '0') {
      return false;
    }

    throw const FormatException(
      'Existe um valor booleano inválido na operação pendente.',
    );
  }

  List<String> _lerListaDeTextos(dynamic valor) {
    if (valor == null) {
      return [];
    }

    if (valor is List) {
      return valor
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    return [];
  }
}
