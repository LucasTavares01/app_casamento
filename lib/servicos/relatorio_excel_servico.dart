import 'dart:convert';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../banco/banco_instancia.dart';
import '../banco/banco_local.dart';
import 'casamento_atual_servico.dart';

class ResultadoRelatorioExcel {
  final String nomeArquivo;
  final int totalConvidados;
  final int presentes;
  final int ausentes;
  final int conflitos;
  final ShareResultStatus statusCompartilhamento;

  const ResultadoRelatorioExcel({
    required this.nomeArquivo,
    required this.totalConvidados,
    required this.presentes,
    required this.ausentes,
    required this.conflitos,
    required this.statusCompartilhamento,
  });
}


class _DestaqueRelatorioIa {
  final String titulo;
  final String texto;
  final String tipo;

  const _DestaqueRelatorioIa({
    required this.titulo,
    required this.texto,
    required this.tipo,
  });

  factory _DestaqueRelatorioIa.fromJson(Map<String, dynamic> json) {
    final tipo = (json['tipo'] ?? 'neutro').toString().trim().toLowerCase();
    return _DestaqueRelatorioIa(
      titulo: (json['titulo'] ?? 'Destaque').toString().trim(),
      texto: (json['texto'] ?? '').toString().trim(),
      tipo: const {'positivo', 'atencao', 'neutro'}.contains(tipo)
          ? tipo
          : 'neutro',
    );
  }
}

class _InsightsRelatorioIa {
  final String tituloDashboard;
  final String resumoExecutivo;
  final List<_DestaqueRelatorioIa> destaques;
  final List<String> alertas;
  final List<String> recomendacoes;
  final String modelo;
  final bool geradoPorIa;
  final String? aviso;

  const _InsightsRelatorioIa({
    required this.tituloDashboard,
    required this.resumoExecutivo,
    required this.destaques,
    required this.alertas,
    required this.recomendacoes,
    required this.modelo,
    required this.geradoPorIa,
    this.aviso,
  });
}

class _ItemGraficoDashboard {
  final String nome;
  final int valor;
  final CellStyle estilo;

  const _ItemGraficoDashboard({
    required this.nome,
    required this.valor,
    required this.estilo,
  });
}

class _ResumoMesaRelatorio {
  final String nome;
  final int total;
  final int presentes;
  final int ausentes;
  final int conflitos;

  const _ResumoMesaRelatorio({
    required this.nome,
    required this.total,
    required this.presentes,
    required this.ausentes,
    required this.conflitos,
  });

  double get taxaPresenca => total == 0 ? 0 : presentes / total;
}


/// Gera um relatório completo da recepção em formato Excel (.xlsx).
///
/// O arquivo utiliza exclusivamente os dados que já estão no SQLite local.
/// A tela principal tenta sincronizar o aparelho antes de chamar este serviço.
class RelatorioExcelServico {
  RelatorioExcelServico._();

  static final RelatorioExcelServico instance = RelatorioExcelServico._();

  final BancoLocal _banco = bancoLocal;
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _mimeTypeXlsx =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  static const MethodChannel _canalArquivos = MethodChannel(
    'br.com.appcasamento/arquivos',
  );

  Future<ResultadoRelatorioExcel> gerarECompartilhar() async {
    final mesas = await _banco.select(_banco.mesasLocais).get();
    final convidados = await _banco.select(_banco.convidadosLocais).get();
    final usuarios = await _banco.select(_banco.usuariosAppLocais).get();
    final eventos = await _banco.select(_banco.eventosCheckinLocais).get();

    final convidadosAtivos = convidados
        .where((convidado) => !convidado.excluido)
        .toList();

    convidadosAtivos.sort((primeiro, segundo) {
      final comparacao = primeiro.nome.toLowerCase().compareTo(
        segundo.nome.toLowerCase(),
      );

      if (comparacao != 0) {
        return comparacao;
      }

      return primeiro.id.compareTo(segundo.id);
    });

    eventos.sort(_compararEventos);

    final mesasPorId = <String, MesaLocalRegistro>{
      for (final mesa in mesas) mesa.id: mesa,
    };

    final convidadosPorId = <String, ConvidadoLocalRegistro>{
      for (final convidado in convidados) convidado.id: convidado,
    };

    final usuariosPorId = <String, String>{
      for (final usuario in usuarios) usuario.id: usuario.nome,
    };

    final eventosPorConvidado = <String, List<EventoCheckinLocalRegistro>>{};

    for (final evento in eventos) {
      eventosPorConvidado
          .putIfAbsent(evento.convidadoId, () => <EventoCheckinLocalRegistro>[])
          .add(evento);
    }

    final totalConvidados = convidadosAtivos.length;
    final presentes = convidadosAtivos
        .where((convidado) => convidado.chegou && !convidado.temConflito)
        .length;
    final ausentes = convidadosAtivos
        .where((convidado) => !convidado.chegou && !convidado.temConflito)
        .length;
    final conflitos = convidadosAtivos
        .where((convidado) => convidado.temConflito)
        .length;

    final casamento = CasamentoAtualServico.instance.casamento;
    if (casamento == null) {
      throw StateError('Nenhum casamento foi selecionado para o relatório.');
    }

    final observacoesPorConvidado = await _buscarObservacoesConvidados(
      casamento.id,
    );

    final resumosMesas = _calcularResumoMesas(
      convidados: convidadosAtivos,
      mesasPorId: mesasPorId,
    );
    final chegadasPorHora = _calcularChegadasPorHora(
      convidados: convidadosAtivos,
      eventosPorConvidado: eventosPorConvidado,
    );

    final insights = await _gerarInsightsComIa(
      casamentoId: casamento.id,
      casamento: casamento,
      convidados: convidadosAtivos,
      observacoesPorConvidado: observacoesPorConvidado,
      resumosMesas: resumosMesas,
      chegadasPorHora: chegadasPorHora,
      totalConvidados: totalConvidados,
      presentes: presentes,
      ausentes: ausentes,
      conflitos: conflitos,
    );

    final excel = Excel.createExcel();
    final nomePadrao = excel.getDefaultSheet();

    if (nomePadrao != null && nomePadrao != 'Dashboard') {
      excel.rename(nomePadrao, 'Dashboard');
    }

    _montarDashboardIa(
      excel: excel,
      casamento: casamento,
      insights: insights,
      resumosMesas: resumosMesas,
      chegadasPorHora: chegadasPorHora,
      totalConvidados: totalConvidados,
      presentes: presentes,
      ausentes: ausentes,
      conflitos: conflitos,
    );

    _montarResumo(
      excel: excel,
      convidados: convidadosAtivos,
      mesasPorId: mesasPorId,
      eventosPorConvidado: eventosPorConvidado,
      totalConvidados: totalConvidados,
      presentes: presentes,
      ausentes: ausentes,
      conflitos: conflitos,
    );

    _montarConvidados(
      excel: excel,
      convidados: convidadosAtivos,
      mesasPorId: mesasPorId,
      usuariosPorId: usuariosPorId,
      eventosPorConvidado: eventosPorConvidado,
      observacoesPorConvidado: observacoesPorConvidado,
    );

    _montarHistorico(
      excel: excel,
      eventos: eventos,
      convidadosPorId: convidadosPorId,
      mesasPorId: mesasPorId,
      usuariosPorId: usuariosPorId,
    );

    _montarMesas(
      excel: excel,
      convidados: convidadosAtivos,
      mesasPorId: mesasPorId,
    );

    excel.setDefaultSheet('Dashboard');

    final bytes = excel.encode();

    if (bytes == null || bytes.isEmpty) {
      throw StateError('O arquivo Excel não pôde ser criado.');
    }

    final agora = DateTime.now();
    final nomeArquivo =
        'relatorio_casamento_${_formatarParaNomeArquivo(agora)}.xlsx';

    final bytesArquivo = Uint8List.fromList(bytes);

    await _salvarCopiaEmDownloads(
      nomeArquivo: nomeArquivo,
      bytes: bytesArquivo,
    );

    final arquivo = XFile.fromData(
      bytesArquivo,
      mimeType: _mimeTypeXlsx,
      name: nomeArquivo,
    );

    final resultadoCompartilhamento = await SharePlus.instance.share(
      ShareParams(
        title: 'Dashboard da recepção',
        subject: 'Relatório inteligente da recepção',
        text:
            'Dashboard da recepção com análise por IA, indicadores, convidados, mesas e histórico de check-in.',
        files: [arquivo],
        fileNameOverrides: [nomeArquivo],
      ),
    );

    return ResultadoRelatorioExcel(
      nomeArquivo: nomeArquivo,
      totalConvidados: totalConvidados,
      presentes: presentes,
      ausentes: ausentes,
      conflitos: conflitos,
      statusCompartilhamento: resultadoCompartilhamento.status,
    );
  }


  Future<void> _salvarCopiaEmDownloads({
    required String nomeArquivo,
    required Uint8List bytes,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      final resultado = await _canalArquivos.invokeMapMethod<String, dynamic>(
        'salvarEmDownloads',
        <String, dynamic>{
          'nomeArquivo': nomeArquivo,
          'mimeType': _mimeTypeXlsx,
          'bytes': bytes,
        },
      );

      final local = resultado?['local']?.toString().trim();
      if (local == null || local.isEmpty) {
        throw PlatformException(
          code: 'RESPOSTA_INVALIDA',
          message: 'O Android não confirmou onde o relatório foi salvo.',
        );
      }
    } on PlatformException catch (erro) {
      final mensagem = erro.message?.trim();
      throw StateError(
        mensagem == null || mensagem.isEmpty
            ? 'Não foi possível salvar o relatório na pasta Downloads.'
            : 'Não foi possível salvar o relatório na pasta Downloads: '
                '$mensagem',
      );
    } on MissingPluginException {
      throw StateError(
        'O recurso de salvar em Downloads ainda não foi carregado. '
        'Feche o aplicativo completamente e execute-o novamente.',
      );
    }
  }


  Future<Map<String, String>> _buscarObservacoesConvidados(
    String casamentoId,
  ) async {
    try {
      final resposta = await _supabase
          .from('convidados')
          .select('id, observacao, deleted_at')
          .eq('casamento_id', casamentoId);

      final observacoes = <String, String>{};

      for (final item in resposta as List) {
        final registro = Map<String, dynamic>.from(item as Map);
        if (registro['deleted_at'] != null) continue;

        final id = registro['id']?.toString().trim();
        final observacao = registro['observacao']?.toString().trim();

        if (id != null &&
            id.isNotEmpty &&
            observacao != null &&
            observacao.isNotEmpty) {
          observacoes[id] = observacao;
        }
      }

      return observacoes;
    } catch (_) {
      // O relatório continua sendo gerado mesmo sem conexão. Nesse caso,
      // somente as observações do servidor deixam de aparecer.
      return const <String, String>{};
    }
  }


  Future<_InsightsRelatorioIa> _gerarInsightsComIa({
    required String casamentoId,
    required CasamentoAtual casamento,
    required List<ConvidadoLocalRegistro> convidados,
    required Map<String, String> observacoesPorConvidado,
    required List<_ResumoMesaRelatorio> resumosMesas,
    required Map<String, int> chegadasPorHora,
    required int totalConvidados,
    required int presentes,
    required int ausentes,
    required int conflitos,
  }) async {
    final observacoes = convidados
        .where(
          (item) =>
              observacoesPorConvidado[item.id]?.trim().isNotEmpty == true,
        )
        .take(250)
        .map(
          (item) => {
            'nome': item.nome,
            'observacao': observacoesPorConvidado[item.id]!.trim(),
          },
        )
        .toList(growable: false);

    final payload = <String, dynamic>{
      'casamento': {
        'titulo': casamento.titulo,
        'descricao': casamento.descricao,
        'data': casamento.dataEvento?.toIso8601String(),
        'horario': casamento.horarioEvento,
        'local': casamento.localEvento,
        'status': casamento.status,
      },
      'indicadores': {
        'total_convidados': totalConvidados,
        'presentes': presentes,
        'ausentes': ausentes,
        'conflitos': conflitos,
        'taxa_presenca': totalConvidados == 0
            ? 0
            : presentes / totalConvidados,
        'convidados_com_observacao': observacoes.length,
      },
      'mesas': resumosMesas
          .map(
            (mesa) => {
              'nome': mesa.nome,
              'total': mesa.total,
              'presentes': mesa.presentes,
              'ausentes': mesa.ausentes,
              'conflitos': mesa.conflitos,
              'taxa_presenca': mesa.taxaPresenca,
            },
          )
          .toList(growable: false),
      'chegadas_por_hora': chegadasPorHora,
      'observacoes_relevantes': observacoes,
    };

    try {
      final resposta = await _supabase.functions
          .invoke(
            'gerar-relatorio-ia',
            body: {
              'casamento_id': casamentoId,
              'dados': payload,
            },
          )
          .timeout(const Duration(minutes: 2));

      final dados = _converterMapa(resposta.data);
      if (resposta.status < 200 || resposta.status >= 300) {
        throw StateError(
          _mensagemDaResposta(dados) ??
              'A IA não conseguiu gerar a análise do relatório.',
        );
      }

      final resultado = _converterMapa(dados['resultado']);
      if (resultado.isEmpty) {
        throw StateError('A IA retornou uma análise vazia.');
      }

      final metadados = _converterMapa(dados['metadados']);
      final destaquesBrutos = resultado['destaques'];
      final alertasBrutos = resultado['alertas'];
      final recomendacoesBrutas = resultado['recomendacoes'];

      return _InsightsRelatorioIa(
        tituloDashboard: _textoOuPadrao(
          resultado['titulo_dashboard'],
          'Dashboard da recepção',
        ),
        resumoExecutivo: _textoOuPadrao(
          resultado['resumo_executivo'],
          _resumoDeterministico(
            total: totalConvidados,
            presentes: presentes,
            ausentes: ausentes,
            conflitos: conflitos,
          ),
        ),
        destaques: destaquesBrutos is List
            ? destaquesBrutos
                  .whereType<Map>()
                  .map(
                    (item) => _DestaqueRelatorioIa.fromJson(
                      Map<String, dynamic>.from(item),
                    ),
                  )
                  .where((item) => item.texto.isNotEmpty)
                  .take(4)
                  .toList(growable: false)
            : const [],
        alertas: _listaDeTextos(alertasBrutos, limite: 5),
        recomendacoes: _listaDeTextos(recomendacoesBrutas, limite: 5),
        modelo: _textoOuPadrao(metadados['modelo'], 'Gemini'),
        geradoPorIa: true,
      );
    } catch (erro) {
      return _InsightsRelatorioIa(
        tituloDashboard: 'Dashboard da recepção',
        resumoExecutivo: _resumoDeterministico(
          total: totalConvidados,
          presentes: presentes,
          ausentes: ausentes,
          conflitos: conflitos,
        ),
        destaques: [
          _DestaqueRelatorioIa(
            titulo: 'Presença geral',
            texto: totalConvidados == 0
                ? 'A lista não possui convidados ativos.'
                : '${_formatarPercentual(presentes / totalConvidados)} dos convidados estão presentes.',
            tipo: 'neutro',
          ),
        ],
        alertas: conflitos > 0
            ? ['$conflitos conflito(s) ainda precisam ser resolvido(s).']
            : const [],
        recomendacoes: const [
          'Consulte as abas Convidados, Mesas e Histórico para os detalhes operacionais.',
        ],
        modelo: 'Análise local',
        geradoPorIa: false,
        aviso:
            'A IA não respondeu e o aplicativo criou uma análise local. Detalhe: ${_limitarTexto(erro.toString(), 180)}',
      );
    }
  }

  void _montarDashboardIa({
    required Excel excel,
    required CasamentoAtual casamento,
    required _InsightsRelatorioIa insights,
    required List<_ResumoMesaRelatorio> resumosMesas,
    required Map<String, int> chegadasPorHora,
    required int totalConvidados,
    required int presentes,
    required int ausentes,
    required int conflitos,
  }) {
    final planilha = excel['Dashboard'];

    planilha.merge(
      CellIndex.indexByString('A1'),
      CellIndex.indexByString('H2'),
      customValue: TextCellValue(insights.tituloDashboard.toUpperCase()),
    );
    planilha.setMergedCellStyle(
      CellIndex.indexByString('A1'),
      _estiloDashboardTitulo,
    );
    planilha.setRowHeight(0, 34);
    planilha.setRowHeight(1, 20);

    final dadosEvento = <String>[
      casamento.descricao,
      if (casamento.dataEvento != null)
        _formatarSomenteData(casamento.dataEvento!),
      if (casamento.horarioEvento?.trim().isNotEmpty == true)
        casamento.horarioEvento!.trim(),
      if (casamento.localEvento?.trim().isNotEmpty == true)
        casamento.localEvento!.trim(),
    ].join(' • ');

    planilha.merge(
      CellIndex.indexByString('A3'),
      CellIndex.indexByString('H3'),
      customValue: TextCellValue(dadosEvento),
    );
    planilha.setMergedCellStyle(
      CellIndex.indexByString('A3'),
      _estiloDashboardSubtitulo,
    );

    _preencherCartaoDashboard(
      planilha,
      colunaInicial: 0,
      titulo: 'CONVIDADOS',
      valor: '$totalConvidados',
      estiloValor: _estiloDashboardValorRoxo,
    );
    _preencherCartaoDashboard(
      planilha,
      colunaInicial: 2,
      titulo: 'PRESENTES',
      valor: '$presentes',
      estiloValor: _estiloDashboardValorVerde,
    );
    _preencherCartaoDashboard(
      planilha,
      colunaInicial: 4,
      titulo: 'AUSENTES',
      valor: '$ausentes',
      estiloValor: _estiloDashboardValorVermelho,
    );
    _preencherCartaoDashboard(
      planilha,
      colunaInicial: 6,
      titulo: 'CONFLITOS',
      valor: '$conflitos',
      estiloValor: conflitos > 0
          ? _estiloDashboardValorLaranja
          : _estiloDashboardValorVerde,
    );

    _tituloSecaoDashboard(planilha, linha: 8, inicio: 0, fim: 3, titulo: 'PRESENÇA GERAL');
    _tituloSecaoDashboard(planilha, linha: 8, inicio: 4, fim: 7, titulo: 'CHEGADAS POR HORÁRIO');

    final valoresStatus = <_ItemGraficoDashboard>[
      _ItemGraficoDashboard(
        nome: 'Presentes',
        valor: presentes,
        estilo: _estiloGraficoVerde,
      ),
      _ItemGraficoDashboard(
        nome: 'Ausentes',
        valor: ausentes,
        estilo: _estiloGraficoVermelho,
      ),
      _ItemGraficoDashboard(
        nome: 'Conflitos',
        valor: conflitos,
        estilo: _estiloGraficoLaranja,
      ),
    ];

    var linhaGrafico = 9;
    for (final item in valoresStatus) {
      _definirCelula(
        planilha,
        linha: linhaGrafico,
        coluna: 0,
        valor: TextCellValue(item.nome),
        estilo: _estiloDashboardRotulo,
      );
      planilha.merge(
        CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: linhaGrafico),
        CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: linhaGrafico),
        customValue: TextCellValue(
          '${_barraProgresso(item.valor, totalConvidados, blocos: 18)}  ${item.valor}',
        ),
      );
      planilha.setMergedCellStyle(
        CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: linhaGrafico),
        item.estilo,
      );
      planilha.setRowHeight(linhaGrafico, 25);
      linhaGrafico += 2;
    }

    final maxChegadas = chegadasPorHora.values.fold<int>(
      0,
      (maior, valor) => valor > maior ? valor : maior,
    );
    final horarios = chegadasPorHora.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (horarios.isEmpty) {
      planilha.merge(
        CellIndex.indexByString('E10'),
        CellIndex.indexByString('H14'),
        customValue: TextCellValue('Nenhuma chegada confirmada.'),
      );
      planilha.setMergedCellStyle(
        CellIndex.indexByString('E10'),
        _estiloDashboardTextoCentral,
      );
    } else {
      var linhaHora = 9;
      for (final entrada in horarios.take(6)) {
        _definirCelula(
          planilha,
          linha: linhaHora,
          coluna: 4,
          valor: TextCellValue(entrada.key),
          estilo: _estiloDashboardRotulo,
        );
        planilha.merge(
          CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: linhaHora),
          CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: linhaHora),
          customValue: TextCellValue(
            '${_barraProgresso(entrada.value, maxChegadas, blocos: 14)}  ${entrada.value}',
          ),
        );
        planilha.setMergedCellStyle(
          CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: linhaHora),
          _estiloGraficoRoxo,
        );
        linhaHora++;
      }
    }

    _tituloSecaoDashboard(planilha, linha: 16, inicio: 0, fim: 7, titulo: 'ANÁLISE INTELIGENTE');
    planilha.merge(
      CellIndex.indexByString('A18'),
      CellIndex.indexByString('H21'),
      customValue: TextCellValue(insights.resumoExecutivo),
    );
    planilha.setMergedCellStyle(
      CellIndex.indexByString('A18'),
      _estiloDashboardResumoIa,
    );

    var proximaLinha = 22;
    if (insights.destaques.isNotEmpty) {
      _tituloSecaoDashboard(
        planilha,
        linha: proximaLinha,
        inicio: 0,
        fim: 7,
        titulo: 'DESTAQUES',
      );
      proximaLinha += 2;

      for (var indice = 0; indice < insights.destaques.length; indice++) {
        final destaque = insights.destaques[indice];
        final inicio = indice.isEven ? 0 : 4;
        final linha = proximaLinha + (indice ~/ 2) * 4;
        planilha.merge(
          CellIndex.indexByColumnRow(columnIndex: inicio, rowIndex: linha),
          CellIndex.indexByColumnRow(columnIndex: inicio + 3, rowIndex: linha + 2),
          customValue: TextCellValue('${destaque.titulo}\n${destaque.texto}'),
        );
        planilha.setMergedCellStyle(
          CellIndex.indexByColumnRow(columnIndex: inicio, rowIndex: linha),
          _estiloDestaque(destaque.tipo),
        );
      }
      proximaLinha += ((insights.destaques.length + 1) ~/ 2) * 4;
    }

    _tituloSecaoDashboard(
      planilha,
      linha: proximaLinha,
      inicio: 0,
      fim: 3,
      titulo: 'ALERTAS',
    );
    _tituloSecaoDashboard(
      planilha,
      linha: proximaLinha,
      inicio: 4,
      fim: 7,
      titulo: 'RECOMENDAÇÕES',
    );
    proximaLinha += 2;

    final quantidadeLinhas = [
      insights.alertas.length,
      insights.recomendacoes.length,
      1,
    ].reduce((a, b) => a > b ? a : b);

    for (var indice = 0; indice < quantidadeLinhas; indice++) {
      final alerta = indice < insights.alertas.length
          ? '• ${insights.alertas[indice]}'
          : indice == 0
          ? 'Nenhum alerta crítico identificado.'
          : '';
      final recomendacao = indice < insights.recomendacoes.length
          ? '• ${insights.recomendacoes[indice]}'
          : '';

      planilha.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: proximaLinha + indice),
        CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: proximaLinha + indice),
        customValue: TextCellValue(alerta),
      );
      planilha.setMergedCellStyle(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: proximaLinha + indice),
        _estiloDashboardAlerta,
      );

      planilha.merge(
        CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: proximaLinha + indice),
        CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: proximaLinha + indice),
        customValue: TextCellValue(recomendacao),
      );
      planilha.setMergedCellStyle(
        CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: proximaLinha + indice),
        _estiloDashboardRecomendacao,
      );
    }

    proximaLinha += quantidadeLinhas + 1;
    _tituloSecaoDashboard(
      planilha,
      linha: proximaLinha,
      inicio: 0,
      fim: 7,
      titulo: 'MESAS COM MAIOR MOVIMENTO',
    );
    proximaLinha += 2;

    _escreverCabecalho(
      planilha,
      linha: proximaLinha,
      titulos: const [
        'Mesa',
        'Total',
        'Presentes',
        'Ausentes',
        'Conflitos',
        'Presença',
        'Indicador',
        'Situação',
      ],
    );
    proximaLinha++;

    final mesasOrdenadas = List<_ResumoMesaRelatorio>.from(resumosMesas)
      ..sort((a, b) => b.total.compareTo(a.total));
    for (final mesa in mesasOrdenadas.take(8)) {
      _escreverLinha(
        planilha,
        linha: proximaLinha,
        valores: [
          TextCellValue(mesa.nome),
          IntCellValue(mesa.total),
          IntCellValue(mesa.presentes),
          IntCellValue(mesa.ausentes),
          IntCellValue(mesa.conflitos),
          DoubleCellValue(mesa.taxaPresenca),
          TextCellValue(_barraProgresso(mesa.presentes, mesa.total, blocos: 12)),
          TextCellValue(
            mesa.conflitos > 0
                ? 'Atenção'
                : mesa.taxaPresenca >= 0.8
                ? 'Ótima presença'
                : 'Acompanhar',
          ),
        ],
      );
      _aplicarEstilo(
        planilha,
        linha: proximaLinha,
        coluna: 5,
        estilo: _estiloPercentualTabela,
      );
      proximaLinha++;
    }

    final fonte = insights.geradoPorIa
        ? 'Análise gerada por IA (${insights.modelo}).'
        : 'Análise local utilizada porque a IA não estava disponível.';
    final rodape = insights.aviso == null ? fonte : '$fonte ${insights.aviso}';
    proximaLinha += 1;
    planilha.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: proximaLinha),
      CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: proximaLinha + 1),
      customValue: TextCellValue(
        '$rodape Gerado em ${_formatarDataHora(DateTime.now())}.',
      ),
    );
    planilha.setMergedCellStyle(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: proximaLinha),
      _estiloNota,
    );

    final larguras = <double>[18, 17, 17, 17, 18, 17, 17, 20];
    for (var coluna = 0; coluna < larguras.length; coluna++) {
      planilha.setColumnWidth(coluna, larguras[coluna]);
    }
  }

  List<_ResumoMesaRelatorio> _calcularResumoMesas({
    required List<ConvidadoLocalRegistro> convidados,
    required Map<String, MesaLocalRegistro> mesasPorId,
  }) {
    final grupos = <String, List<ConvidadoLocalRegistro>>{};
    for (final convidado in convidados) {
      grupos
          .putIfAbsent(
            convidado.mesaId ?? '__sem_mesa__',
            () => <ConvidadoLocalRegistro>[],
          )
          .add(convidado);
    }

    final resultado = <_ResumoMesaRelatorio>[];
    for (final entrada in grupos.entries) {
      final grupo = entrada.value;
      final presentes = grupo
          .where((item) => item.chegou && !item.temConflito)
          .length;
      final conflitos = grupo.where((item) => item.temConflito).length;
      resultado.add(
        _ResumoMesaRelatorio(
          nome: entrada.key == '__sem_mesa__'
              ? 'Sem mesa'
              : _nomeMesa(
                  mesasPorId[entrada.key],
                  mesaIdOriginal: entrada.key,
                ),
          total: grupo.length,
          presentes: presentes,
          ausentes: grupo.length - presentes - conflitos,
          conflitos: conflitos,
        ),
      );
    }

    resultado.sort((a, b) => a.nome.compareTo(b.nome));
    return resultado;
  }

  Map<String, int> _calcularChegadasPorHora({
    required List<ConvidadoLocalRegistro> convidados,
    required Map<String, List<EventoCheckinLocalRegistro>> eventosPorConvidado,
  }) {
    final resultado = <String, int>{};
    for (final convidado in convidados) {
      if (!convidado.chegou || convidado.temConflito) continue;
      final evento = _obterEventoAtualPresente(
        convidado: convidado,
        eventos: eventosPorConvidado[convidado.id] ?? const [],
      );
      if (evento == null) continue;
      final hora = evento.dataDispositivo.toLocal().hour;
      final chave = '${_doisDigitos(hora)}:00';
      resultado[chave] = (resultado[chave] ?? 0) + 1;
    }
    return resultado;
  }

  void _preencherCartaoDashboard(
    Sheet planilha, {
    required int colunaInicial,
    required String titulo,
    required String valor,
    required CellStyle estiloValor,
  }) {
    planilha.merge(
      CellIndex.indexByColumnRow(columnIndex: colunaInicial, rowIndex: 4),
      CellIndex.indexByColumnRow(columnIndex: colunaInicial + 1, rowIndex: 4),
      customValue: TextCellValue(titulo),
    );
    planilha.setMergedCellStyle(
      CellIndex.indexByColumnRow(columnIndex: colunaInicial, rowIndex: 4),
      _estiloDashboardCartaoTitulo,
    );
    planilha.merge(
      CellIndex.indexByColumnRow(columnIndex: colunaInicial, rowIndex: 5),
      CellIndex.indexByColumnRow(columnIndex: colunaInicial + 1, rowIndex: 6),
      customValue: TextCellValue(valor),
    );
    planilha.setMergedCellStyle(
      CellIndex.indexByColumnRow(columnIndex: colunaInicial, rowIndex: 5),
      estiloValor,
    );
  }

  void _tituloSecaoDashboard(
    Sheet planilha, {
    required int linha,
    required int inicio,
    required int fim,
    required String titulo,
  }) {
    planilha.merge(
      CellIndex.indexByColumnRow(columnIndex: inicio, rowIndex: linha),
      CellIndex.indexByColumnRow(columnIndex: fim, rowIndex: linha),
      customValue: TextCellValue(titulo),
    );
    planilha.setMergedCellStyle(
      CellIndex.indexByColumnRow(columnIndex: inicio, rowIndex: linha),
      _estiloDashboardSecao,
    );
  }

  String _barraProgresso(int valor, int total, {required int blocos}) {
    if (total <= 0 || valor <= 0) {
      return List<String>.filled(blocos, '░').join();
    }
    final preenchidos = ((valor / total) * blocos)
        .round()
        .clamp(0, blocos)
        .toInt();
    final cheios = List<String>.filled(preenchidos, '█').join();
    final vazios = List<String>.filled(blocos - preenchidos, '░').join();
    return '$cheios$vazios';
  }

  Map<String, dynamic> _converterMapa(dynamic valor) {
    if (valor is Map<String, dynamic>) return valor;
    if (valor is Map) return Map<String, dynamic>.from(valor);
    return const <String, dynamic>{};
  }

  String? _mensagemDaResposta(Map<String, dynamic> dados) {
    for (final chave in const ['mensagem', 'message', 'error']) {
      final texto = dados[chave]?.toString().trim();
      if (texto != null && texto.isNotEmpty) return texto;
    }
    return null;
  }

  String _textoOuPadrao(dynamic valor, String padrao) {
    final texto = valor?.toString().trim();
    return texto == null || texto.isEmpty ? padrao : texto;
  }

  List<String> _listaDeTextos(dynamic valor, {required int limite}) {
    if (valor is! List) return const [];
    return valor
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .take(limite)
        .toList(growable: false);
  }

  String _resumoDeterministico({
    required int total,
    required int presentes,
    required int ausentes,
    required int conflitos,
  }) {
    final taxa = total == 0 ? 0.0 : presentes / total;
    return 'O evento possui $total convidado(s), com $presentes presente(s), '
        '$ausentes ausente(s) e $conflitos conflito(s). A taxa atual de '
        'presença é ${_formatarPercentual(taxa)}.';
  }

  String _formatarPercentual(double valor) =>
      '${(valor * 100).toStringAsFixed(1).replaceAll('.', ',')}%';

  String _formatarSomenteData(DateTime data) {
    final local = data.toLocal();
    return '${_doisDigitos(local.day)}/${_doisDigitos(local.month)}/${local.year}';
  }

  String _limitarTexto(String texto, int limite) {
    final limpo = texto.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (limpo.length <= limite) return limpo;
    return '${limpo.substring(0, limite - 1)}…';
  }

  void _montarResumo({
    required Excel excel,
    required List<ConvidadoLocalRegistro> convidados,
    required Map<String, MesaLocalRegistro> mesasPorId,
    required Map<String, List<EventoCheckinLocalRegistro>> eventosPorConvidado,
    required int totalConvidados,
    required int presentes,
    required int ausentes,
    required int conflitos,
  }) {
    final planilha = excel['Resumo'];

    planilha.merge(
      CellIndex.indexByString('A1'),
      CellIndex.indexByString('F1'),
      customValue: TextCellValue('RELATÓRIO COMPLETO DA RECEPÇÃO'),
    );
    planilha.setMergedCellStyle(CellIndex.indexByString('A1'), _estiloTitulo);
    planilha.setRowHeight(0, 30);

    planilha.merge(
      CellIndex.indexByString('A2'),
      CellIndex.indexByString('F2'),
      customValue: TextCellValue(
        'Gerado em ${_formatarDataHora(DateTime.now())}',
      ),
    );
    planilha.setMergedCellStyle(
      CellIndex.indexByString('A2'),
      _estiloSubtitulo,
    );

    _preencherKpi(
      planilha,
      linha: 3,
      coluna: 0,
      titulo: 'TOTAL',
      valor: totalConvidados,
    );
    _preencherKpi(
      planilha,
      linha: 3,
      coluna: 2,
      titulo: 'PRESENTES',
      valor: presentes,
    );
    _preencherKpi(
      planilha,
      linha: 3,
      coluna: 4,
      titulo: 'AUSENTES',
      valor: ausentes,
    );

    final taxaPresenca = totalConvidados == 0
        ? 0.0
        : presentes / totalConvidados;

    _definirCelula(
      planilha,
      linha: 5,
      coluna: 0,
      valor: TextCellValue('PERCENTUAL DE PRESENÇA'),
      estilo: _estiloRotuloKpi,
    );
    _definirCelula(
      planilha,
      linha: 6,
      coluna: 0,
      valor: DoubleCellValue(taxaPresenca),
      estilo: _estiloPercentualKpi,
    );

    _definirCelula(
      planilha,
      linha: 5,
      coluna: 2,
      valor: TextCellValue('CONFLITOS PENDENTES'),
      estilo: _estiloRotuloKpi,
    );
    _definirCelula(
      planilha,
      linha: 6,
      coluna: 2,
      valor: IntCellValue(conflitos),
      estilo: conflitos > 0 ? _estiloValorAlerta : _estiloValorKpi,
    );

    final chegadasAtuais = <DateTime>[];

    for (final convidado in convidados) {
      if (!convidado.chegou || convidado.temConflito) {
        continue;
      }

      final eventoAtual = _obterEventoAtualPresente(
        convidado: convidado,
        eventos: eventosPorConvidado[convidado.id] ?? const [],
      );

      if (eventoAtual != null) {
        chegadasAtuais.add(eventoAtual.dataDispositivo.toLocal());
      }
    }

    chegadasAtuais.sort();

    _definirCelula(
      planilha,
      linha: 5,
      coluna: 4,
      valor: TextCellValue('PRIMEIRA / ÚLTIMA CHEGADA'),
      estilo: _estiloRotuloKpi,
    );
    _definirCelula(
      planilha,
      linha: 6,
      coluna: 4,
      valor: TextCellValue(
        chegadasAtuais.isEmpty
            ? 'Nenhuma chegada confirmada'
            : '${_formatarDataHora(chegadasAtuais.first)} / '
                  '${_formatarDataHora(chegadasAtuais.last)}',
      ),
      estilo: _estiloValorTextoKpi,
    );

    const linhaCabecalhoMesas = 9;

    _escreverCabecalho(
      planilha,
      linha: linhaCabecalhoMesas,
      titulos: const [
        'Mesa',
        'Total',
        'Presentes',
        'Ausentes',
        'Conflitos',
        'Presença',
      ],
    );

    final grupos = <String, List<ConvidadoLocalRegistro>>{};

    for (final convidado in convidados) {
      final chave = convidado.mesaId ?? '__sem_mesa__';
      grupos
          .putIfAbsent(chave, () => <ConvidadoLocalRegistro>[])
          .add(convidado);
    }

    final chavesOrdenadas = grupos.keys.toList()
      ..sort((primeiro, segundo) {
        if (primeiro == '__sem_mesa__') {
          return 1;
        }
        if (segundo == '__sem_mesa__') {
          return -1;
        }

        final numeroPrimeiro = mesasPorId[primeiro]?.numero ?? 999999;
        final numeroSegundo = mesasPorId[segundo]?.numero ?? 999999;
        return numeroPrimeiro.compareTo(numeroSegundo);
      });

    var linha = linhaCabecalhoMesas + 1;

    for (final chave in chavesOrdenadas) {
      final grupo = grupos[chave]!;
      final total = grupo.length;
      final presentesMesa = grupo
          .where((convidado) => convidado.chegou && !convidado.temConflito)
          .length;
      final conflitosMesa = grupo
          .where((convidado) => convidado.temConflito)
          .length;
      final ausentesMesa = total - presentesMesa - conflitosMesa;
      final taxa = total == 0 ? 0.0 : presentesMesa / total;

      final nomeMesa = chave == '__sem_mesa__'
          ? 'Sem mesa'
          : _nomeMesa(mesasPorId[chave], mesaIdOriginal: chave);

      _escreverLinha(
        planilha,
        linha: linha,
        valores: [
          TextCellValue(nomeMesa),
          IntCellValue(total),
          IntCellValue(presentesMesa),
          IntCellValue(ausentesMesa),
          IntCellValue(conflitosMesa),
          DoubleCellValue(taxa),
        ],
      );

      _aplicarEstilo(
        planilha,
        linha: linha,
        coluna: 5,
        estilo: _estiloPercentualTabela,
      );

      linha++;
    }

    final linhaNota = linha + 1;
    planilha.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: linhaNota),
      CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: linhaNota),
      customValue: TextCellValue(
        'Observação: os horários usam o momento registrado no aparelho. '
        'A aba Histórico também mostra o horário recebido pelo servidor, quando disponível.',
      ),
    );
    planilha.setMergedCellStyle(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: linhaNota),
      _estiloNota,
    );

    planilha.setColumnWidth(0, 28);
    planilha.setColumnWidth(1, 12);
    planilha.setColumnWidth(2, 14);
    planilha.setColumnWidth(3, 14);
    planilha.setColumnWidth(4, 14);
    planilha.setColumnWidth(5, 18);
  }

  void _montarConvidados({
    required Excel excel,
    required List<ConvidadoLocalRegistro> convidados,
    required Map<String, MesaLocalRegistro> mesasPorId,
    required Map<String, String> usuariosPorId,
    required Map<String, List<EventoCheckinLocalRegistro>> eventosPorConvidado,
    required Map<String, String> observacoesPorConvidado,
  }) {
    final planilha = excel['Convidados'];

    _escreverTituloDaPlanilha(
      planilha,
      ultimaColuna: 11,
      titulo: 'LISTA COMPLETA DE CONVIDADOS',
    );

    const linhaCabecalho = 2;

    _escreverCabecalho(
      planilha,
      linha: linhaCabecalho,
      titulos: const [
        'Convidado',
        'Mesa',
        'Status final',
        'Chegada atual',
        'Confirmado por',
        'Primeira confirmação',
        'Última alteração',
        'Responsável pela última alteração',
        'Quantidade de ações',
        'Sincronização',
        'Observação',
        'ID do convidado',
      ],
    );

    var linha = linhaCabecalho + 1;

    for (final convidado in convidados) {
      final eventos = List<EventoCheckinLocalRegistro>.from(
        eventosPorConvidado[convidado.id] ?? const [],
      )..sort(_compararEventos);

      final primeiroPresente = _primeiroEventoPresente(eventos);
      final eventoAtualPresente = _obterEventoAtualPresente(
        convidado: convidado,
        eventos: eventos,
      );
      final ultimaAlteracao = eventos.isEmpty ? null : eventos.last;

      final status = convidado.temConflito
          ? 'CONFLITO'
          : convidado.chegou
          ? 'PRESENTE'
          : 'AUSENTE';

      final sincronizacao = eventos.isEmpty
          ? 'Sem ações'
          : eventos.every((evento) => evento.sincronizado)
          ? 'Sincronizado'
          : 'Pendente';

      final observacaoCadastro = observacoesPorConvidado[convidado.id];
      final observacoes = <String>[
        if (observacaoCadastro?.trim().isNotEmpty == true)
          observacaoCadastro!.trim(),
        if (convidado.temConflito)
          'Há ações contraditórias que precisam ser resolvidas no aplicativo.'
        else if (ultimaAlteracao?.observacao?.trim().isNotEmpty == true)
          ultimaAlteracao!.observacao!.trim(),
      ];
      final observacao = observacoes.join(' | ');

      _escreverLinha(
        planilha,
        linha: linha,
        valores: [
          TextCellValue(convidado.nome),
          TextCellValue(
            _nomeMesa(
              mesasPorId[convidado.mesaId],
              mesaIdOriginal: convidado.mesaId,
            ),
          ),
          TextCellValue(status),
          TextCellValue(
            _formatarDataHoraOuTraco(eventoAtualPresente?.dataDispositivo),
          ),
          TextCellValue(
            eventoAtualPresente == null
                ? '-'
                : _nomeUsuario(eventoAtualPresente.usuarioId, usuariosPorId),
          ),
          TextCellValue(
            _formatarDataHoraOuTraco(primeiroPresente?.dataDispositivo),
          ),
          TextCellValue(
            _formatarDataHoraOuTraco(ultimaAlteracao?.dataDispositivo),
          ),
          TextCellValue(
            ultimaAlteracao == null
                ? '-'
                : _nomeUsuario(ultimaAlteracao.usuarioId, usuariosPorId),
          ),
          IntCellValue(eventos.length),
          TextCellValue(sincronizacao),
          TextCellValue(observacao),
          TextCellValue(convidado.id),
        ],
      );

      _aplicarEstilo(
        planilha,
        linha: linha,
        coluna: 2,
        estilo: convidado.temConflito
            ? _estiloStatusConflito
            : convidado.chegou
            ? _estiloStatusPresente
            : _estiloStatusAusente,
      );

      if (sincronizacao == 'Pendente') {
        _aplicarEstilo(
          planilha,
          linha: linha,
          coluna: 9,
          estilo: _estiloStatusPendente,
        );
      }

      linha++;
    }

    final larguras = <double>[28, 24, 15, 20, 22, 20, 20, 30, 18, 16, 44, 38];

    for (var coluna = 0; coluna < larguras.length; coluna++) {
      planilha.setColumnWidth(coluna, larguras[coluna]);
    }
  }

  void _montarHistorico({
    required Excel excel,
    required List<EventoCheckinLocalRegistro> eventos,
    required Map<String, ConvidadoLocalRegistro> convidadosPorId,
    required Map<String, MesaLocalRegistro> mesasPorId,
    required Map<String, String> usuariosPorId,
  }) {
    final planilha = excel['Histórico'];

    _escreverTituloDaPlanilha(
      planilha,
      ultimaColuna: 11,
      titulo: 'HISTÓRICO COMPLETO DE CHECK-IN',
    );

    const linhaCabecalho = 2;

    _escreverCabecalho(
      planilha,
      linha: linhaCabecalho,
      titulos: const [
        'Data/hora no aparelho',
        'Data/hora no servidor',
        'Convidado',
        'Mesa atual',
        'Ação',
        'Estado resultante',
        'Responsável',
        'Sincronização',
        'Dispositivo',
        'Sequência',
        'Observação',
        'ID do evento',
      ],
    );

    var linha = linhaCabecalho + 1;

    for (final evento in eventos) {
      final convidado = convidadosPorId[evento.convidadoId];
      final nomeConvidado = convidado == null
          ? 'Convidado não encontrado'
          : convidado.excluido
          ? '${convidado.nome} (excluído)'
          : convidado.nome;

      _escreverLinha(
        planilha,
        linha: linha,
        valores: [
          TextCellValue(_formatarDataHora(evento.dataDispositivo)),
          TextCellValue(_formatarDataHoraOuTraco(evento.dataServidor)),
          TextCellValue(nomeConvidado),
          TextCellValue(
            _nomeMesa(
              mesasPorId[convidado?.mesaId],
              mesaIdOriginal: convidado?.mesaId,
            ),
          ),
          TextCellValue(_descricaoAcao(evento.tipoAcao)),
          TextCellValue(evento.estadoResultante ? 'PRESENTE' : 'AUSENTE'),
          TextCellValue(_nomeUsuario(evento.usuarioId, usuariosPorId)),
          TextCellValue(evento.sincronizado ? 'Sincronizado' : 'Pendente'),
          TextCellValue(evento.dispositivoId),
          IntCellValue(evento.sequenciaDispositivo),
          TextCellValue(evento.observacao ?? ''),
          TextCellValue(evento.id),
        ],
      );

      _aplicarEstilo(
        planilha,
        linha: linha,
        coluna: 5,
        estilo: evento.estadoResultante
            ? _estiloStatusPresente
            : _estiloStatusAusente,
      );

      if (!evento.sincronizado) {
        _aplicarEstilo(
          planilha,
          linha: linha,
          coluna: 7,
          estilo: _estiloStatusPendente,
        );
      }

      linha++;
    }

    final larguras = <double>[23, 23, 28, 24, 34, 18, 24, 16, 40, 12, 42, 38];

    for (var coluna = 0; coluna < larguras.length; coluna++) {
      planilha.setColumnWidth(coluna, larguras[coluna]);
    }
  }

  void _montarMesas({
    required Excel excel,
    required List<ConvidadoLocalRegistro> convidados,
    required Map<String, MesaLocalRegistro> mesasPorId,
  }) {
    final planilha = excel['Mesas'];

    _escreverTituloDaPlanilha(
      planilha,
      ultimaColuna: 7,
      titulo: 'DETALHAMENTO POR MESA',
    );

    const linhaCabecalho = 2;

    _escreverCabecalho(
      planilha,
      linha: linhaCabecalho,
      titulos: const [
        'Mesa',
        'Detalhe',
        'Total',
        'Presentes',
        'Ausentes',
        'Conflitos',
        'Presença',
        'Convidados presentes',
      ],
    );

    final chaves =
        <String>{
          ...convidados.map((convidado) => convidado.mesaId ?? '__sem_mesa__'),
          ...mesasPorId.values
              .where((mesa) => !mesa.excluido)
              .map((mesa) => mesa.id),
        }.toList()..sort((primeiro, segundo) {
          if (primeiro == '__sem_mesa__') {
            return 1;
          }
          if (segundo == '__sem_mesa__') {
            return -1;
          }
          return (mesasPorId[primeiro]?.numero ?? 999999).compareTo(
            mesasPorId[segundo]?.numero ?? 999999,
          );
        });

    var linha = linhaCabecalho + 1;

    for (final chave in chaves) {
      final convidadosMesa = convidados.where((convidado) {
        final chaveConvidado = convidado.mesaId ?? '__sem_mesa__';
        return chaveConvidado == chave;
      }).toList();

      convidadosMesa.sort(
        (primeiro, segundo) =>
            primeiro.nome.toLowerCase().compareTo(segundo.nome.toLowerCase()),
      );

      final total = convidadosMesa.length;
      final presentes = convidadosMesa
          .where((convidado) => convidado.chegou && !convidado.temConflito)
          .toList();
      final conflitos = convidadosMesa
          .where((convidado) => convidado.temConflito)
          .length;
      final ausentes = total - presentes.length - conflitos;
      final taxa = total == 0 ? 0.0 : presentes.length / total;
      final mesa = chave == '__sem_mesa__' ? null : mesasPorId[chave];

      _escreverLinha(
        planilha,
        linha: linha,
        valores: [
          TextCellValue(
            chave == '__sem_mesa__'
                ? 'Sem mesa'
                : _nomeMesa(mesa, mesaIdOriginal: chave),
          ),
          TextCellValue(mesa?.detalhe?.trim() ?? ''),
          IntCellValue(total),
          IntCellValue(presentes.length),
          IntCellValue(ausentes),
          IntCellValue(conflitos),
          DoubleCellValue(taxa),
          TextCellValue(
            presentes.map((convidado) => convidado.nome).join(', '),
          ),
        ],
      );

      _aplicarEstilo(
        planilha,
        linha: linha,
        coluna: 6,
        estilo: _estiloPercentualTabela,
      );

      linha++;
    }

    final larguras = <double>[28, 28, 12, 14, 14, 14, 14, 60];

    for (var coluna = 0; coluna < larguras.length; coluna++) {
      planilha.setColumnWidth(coluna, larguras[coluna]);
    }
  }

  void _escreverTituloDaPlanilha(
    Sheet planilha, {
    required int ultimaColuna,
    required String titulo,
  }) {
    planilha.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      CellIndex.indexByColumnRow(columnIndex: ultimaColuna, rowIndex: 0),
      customValue: TextCellValue(titulo),
    );
    planilha.setMergedCellStyle(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      _estiloTitulo,
    );
    planilha.setRowHeight(0, 30);

    planilha.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
      CellIndex.indexByColumnRow(columnIndex: ultimaColuna, rowIndex: 1),
      customValue: TextCellValue(
        'Gerado em ${_formatarDataHora(DateTime.now())}',
      ),
    );
    planilha.setMergedCellStyle(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
      _estiloSubtitulo,
    );
  }

  void _preencherKpi(
    Sheet planilha, {
    required int linha,
    required int coluna,
    required String titulo,
    required int valor,
  }) {
    _definirCelula(
      planilha,
      linha: linha,
      coluna: coluna,
      valor: TextCellValue(titulo),
      estilo: _estiloRotuloKpi,
    );
    _definirCelula(
      planilha,
      linha: linha + 1,
      coluna: coluna,
      valor: IntCellValue(valor),
      estilo: _estiloValorKpi,
    );
  }

  void _escreverCabecalho(
    Sheet planilha, {
    required int linha,
    required List<String> titulos,
  }) {
    for (var coluna = 0; coluna < titulos.length; coluna++) {
      _definirCelula(
        planilha,
        linha: linha,
        coluna: coluna,
        valor: TextCellValue(titulos[coluna]),
        estilo: _estiloCabecalho,
      );
    }

    planilha.setRowHeight(linha, 25);
  }

  void _escreverLinha(
    Sheet planilha, {
    required int linha,
    required List<CellValue?> valores,
  }) {
    for (var coluna = 0; coluna < valores.length; coluna++) {
      _definirCelula(
        planilha,
        linha: linha,
        coluna: coluna,
        valor: valores[coluna],
        estilo: _estiloCorpo,
      );
    }
  }

  void _definirCelula(
    Sheet planilha, {
    required int linha,
    required int coluna,
    required CellValue? valor,
    required CellStyle estilo,
  }) {
    final celula = planilha.cell(
      CellIndex.indexByColumnRow(columnIndex: coluna, rowIndex: linha),
    );

    celula.value = valor;
    celula.cellStyle = estilo;
  }

  void _aplicarEstilo(
    Sheet planilha, {
    required int linha,
    required int coluna,
    required CellStyle estilo,
  }) {
    planilha
            .cell(
              CellIndex.indexByColumnRow(columnIndex: coluna, rowIndex: linha),
            )
            .cellStyle =
        estilo;
  }

  EventoCheckinLocalRegistro? _obterEventoAtualPresente({
    required ConvidadoLocalRegistro convidado,
    required List<EventoCheckinLocalRegistro> eventos,
  }) {
    if (!convidado.chegou || eventos.isEmpty) {
      return null;
    }

    final idsAtuais = _decodificarIds(convidado.eventosAtuaisJson);
    final atuaisPresentes = eventos.where((evento) {
      return idsAtuais.contains(evento.id) && evento.estadoResultante;
    }).toList()..sort(_compararEventos);

    if (atuaisPresentes.isNotEmpty) {
      return atuaisPresentes.last;
    }

    final presentes =
        eventos.where((evento) => evento.estadoResultante).toList()
          ..sort(_compararEventos);

    return presentes.isEmpty ? null : presentes.last;
  }

  EventoCheckinLocalRegistro? _primeiroEventoPresente(
    List<EventoCheckinLocalRegistro> eventos,
  ) {
    for (final evento in eventos) {
      if (evento.estadoResultante) {
        return evento;
      }
    }

    return null;
  }

  Set<String> _decodificarIds(String json) {
    try {
      final valor = jsonDecode(json);

      if (valor is List) {
        return valor.map((item) => item.toString()).toSet();
      }
    } catch (_) {
      // Mantém lista vazia se um valor antigo estiver inválido.
    }

    return <String>{};
  }

  int _compararEventos(
    EventoCheckinLocalRegistro primeiro,
    EventoCheckinLocalRegistro segundo,
  ) {
    final comparacaoData = primeiro.dataDispositivo.compareTo(
      segundo.dataDispositivo,
    );

    if (comparacaoData != 0) {
      return comparacaoData;
    }

    final comparacaoDispositivo = primeiro.dispositivoId.compareTo(
      segundo.dispositivoId,
    );

    if (comparacaoDispositivo != 0) {
      return comparacaoDispositivo;
    }

    return primeiro.sequenciaDispositivo.compareTo(
      segundo.sequenciaDispositivo,
    );
  }

  String _nomeMesa(MesaLocalRegistro? mesa, {required String? mesaIdOriginal}) {
    if (mesaIdOriginal == null || mesaIdOriginal.isEmpty) {
      return 'Sem mesa';
    }

    if (mesa == null) {
      return 'Mesa não encontrada';
    }

    final detalhe = mesa.detalhe?.trim();

    if (detalhe != null && detalhe.isNotEmpty) {
      return 'Mesa ${mesa.numero} - $detalhe';
    }

    return 'Mesa ${mesa.numero}';
  }

  String _nomeUsuario(String usuarioId, Map<String, String> usuariosPorId) {
    return usuariosPorId[usuarioId] ?? 'Usuário não encontrado';
  }

  String _descricaoAcao(String tipoAcao) {
    switch (tipoAcao) {
      case 'confirmou_chegada':
        return 'Confirmou a chegada';
      case 'removeu_chegada':
        return 'Removeu a confirmação de chegada';
      case 'resolveu_como_presente':
        return 'Resolveu o conflito como presente';
      case 'resolveu_como_ausente':
        return 'Resolveu o conflito como ausente';
      default:
        return tipoAcao;
    }
  }

  String _formatarDataHoraOuTraco(DateTime? data) {
    return data == null ? '-' : _formatarDataHora(data);
  }

  String _formatarDataHora(DateTime data) {
    final local = data.toLocal();

    return '${_doisDigitos(local.day)}/${_doisDigitos(local.month)}/'
        '${local.year} ${_doisDigitos(local.hour)}:'
        '${_doisDigitos(local.minute)}:${_doisDigitos(local.second)}';
  }

  String _formatarParaNomeArquivo(DateTime data) {
    final local = data.toLocal();

    return '${local.year}${_doisDigitos(local.month)}${_doisDigitos(local.day)}_'
        '${_doisDigitos(local.hour)}${_doisDigitos(local.minute)}'
        '${_doisDigitos(local.second)}';
  }

  String _doisDigitos(int valor) => valor.toString().padLeft(2, '0');

  Border get _bordaFina =>
      Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.grey400);


  CellStyle get _estiloDashboardTitulo => CellStyle(
    backgroundColorHex: ExcelColor.indigo700,
    fontColorHex: ExcelColor.white,
    fontSize: 22,
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    textWrapping: TextWrapping.WrapText,
  );

  CellStyle get _estiloDashboardSubtitulo => CellStyle(
    backgroundColorHex: ExcelColor.indigo50,
    fontColorHex: ExcelColor.indigo900,
    fontSize: 11,
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    textWrapping: TextWrapping.WrapText,
    bottomBorder: _bordaFina,
  );

  CellStyle get _estiloDashboardCartaoTitulo => CellStyle(
    backgroundColorHex: ExcelColor.blueGrey100,
    fontColorHex: ExcelColor.blueGrey900,
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _bordaFina,
    rightBorder: _bordaFina,
    topBorder: _bordaFina,
    bottomBorder: _bordaFina,
  );

  CellStyle get _estiloDashboardValorRoxo => _estiloValorDashboard(
    fundo: ExcelColor.indigo50,
    fonte: ExcelColor.indigo900,
  );

  CellStyle get _estiloDashboardValorVerde => _estiloValorDashboard(
    fundo: ExcelColor.green100,
    fonte: ExcelColor.green900,
  );

  CellStyle get _estiloDashboardValorVermelho => _estiloValorDashboard(
    fundo: ExcelColor.red100,
    fonte: ExcelColor.red900,
  );

  CellStyle get _estiloDashboardValorLaranja => _estiloValorDashboard(
    fundo: ExcelColor.orange100,
    fonte: ExcelColor.orange900,
  );

  CellStyle _estiloValorDashboard({
    required ExcelColor fundo,
    required ExcelColor fonte,
  }) => CellStyle(
    backgroundColorHex: fundo,
    fontColorHex: fonte,
    fontSize: 24,
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _bordaFina,
    rightBorder: _bordaFina,
    topBorder: _bordaFina,
    bottomBorder: _bordaFina,
  );

  CellStyle get _estiloDashboardSecao => CellStyle(
    backgroundColorHex: ExcelColor.indigo700,
    fontColorHex: ExcelColor.white,
    bold: true,
    horizontalAlign: HorizontalAlign.Left,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _bordaFina,
    rightBorder: _bordaFina,
    topBorder: _bordaFina,
    bottomBorder: _bordaFina,
  );

  CellStyle get _estiloDashboardRotulo => CellStyle(
    backgroundColorHex: ExcelColor.grey100,
    fontColorHex: ExcelColor.blueGrey900,
    bold: true,
    horizontalAlign: HorizontalAlign.Left,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _bordaFina,
    rightBorder: _bordaFina,
    topBorder: _bordaFina,
    bottomBorder: _bordaFina,
  );

  CellStyle get _estiloGraficoVerde => _estiloGrafico(ExcelColor.green900);
  CellStyle get _estiloGraficoVermelho => _estiloGrafico(ExcelColor.red900);
  CellStyle get _estiloGraficoLaranja => _estiloGrafico(ExcelColor.orange900);
  CellStyle get _estiloGraficoRoxo => _estiloGrafico(ExcelColor.indigo900);

  CellStyle _estiloGrafico(ExcelColor fonte) => CellStyle(
    backgroundColorHex: ExcelColor.white,
    fontColorHex: fonte,
    bold: true,
    horizontalAlign: HorizontalAlign.Left,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _bordaFina,
    rightBorder: _bordaFina,
    topBorder: _bordaFina,
    bottomBorder: _bordaFina,
  );

  CellStyle get _estiloDashboardTextoCentral => CellStyle(
    backgroundColorHex: ExcelColor.grey100,
    fontColorHex: ExcelColor.grey700,
    italic: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    textWrapping: TextWrapping.WrapText,
    leftBorder: _bordaFina,
    rightBorder: _bordaFina,
    topBorder: _bordaFina,
    bottomBorder: _bordaFina,
  );

  CellStyle get _estiloDashboardResumoIa => CellStyle(
    backgroundColorHex: ExcelColor.indigo50,
    fontColorHex: ExcelColor.indigo900,
    fontSize: 12,
    bold: true,
    horizontalAlign: HorizontalAlign.Left,
    verticalAlign: VerticalAlign.Center,
    textWrapping: TextWrapping.WrapText,
    leftBorder: _bordaFina,
    rightBorder: _bordaFina,
    topBorder: _bordaFina,
    bottomBorder: _bordaFina,
  );

  CellStyle _estiloDestaque(String tipo) {
    switch (tipo) {
      case 'positivo':
        return _estiloPainelDashboard(
          fundo: ExcelColor.green100,
          fonte: ExcelColor.green900,
        );
      case 'atencao':
        return _estiloPainelDashboard(
          fundo: ExcelColor.orange100,
          fonte: ExcelColor.orange900,
        );
      default:
        return _estiloPainelDashboard(
          fundo: ExcelColor.blueGrey100,
          fonte: ExcelColor.blueGrey900,
        );
    }
  }

  CellStyle _estiloPainelDashboard({
    required ExcelColor fundo,
    required ExcelColor fonte,
  }) => CellStyle(
    backgroundColorHex: fundo,
    fontColorHex: fonte,
    bold: true,
    horizontalAlign: HorizontalAlign.Left,
    verticalAlign: VerticalAlign.Center,
    textWrapping: TextWrapping.WrapText,
    leftBorder: _bordaFina,
    rightBorder: _bordaFina,
    topBorder: _bordaFina,
    bottomBorder: _bordaFina,
  );

  CellStyle get _estiloDashboardAlerta => CellStyle(
    backgroundColorHex: ExcelColor.red50,
    fontColorHex: ExcelColor.red900,
    horizontalAlign: HorizontalAlign.Left,
    verticalAlign: VerticalAlign.Center,
    textWrapping: TextWrapping.WrapText,
    leftBorder: _bordaFina,
    rightBorder: _bordaFina,
    topBorder: _bordaFina,
    bottomBorder: _bordaFina,
  );

  CellStyle get _estiloDashboardRecomendacao => CellStyle(
    backgroundColorHex: ExcelColor.green50,
    fontColorHex: ExcelColor.green900,
    horizontalAlign: HorizontalAlign.Left,
    verticalAlign: VerticalAlign.Center,
    textWrapping: TextWrapping.WrapText,
    leftBorder: _bordaFina,
    rightBorder: _bordaFina,
    topBorder: _bordaFina,
    bottomBorder: _bordaFina,
  );

  CellStyle get _estiloTitulo => CellStyle(
    backgroundColorHex: ExcelColor.indigo700,
    fontColorHex: ExcelColor.white,
    fontSize: 18,
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
  );

  CellStyle get _estiloSubtitulo => CellStyle(
    backgroundColorHex: ExcelColor.indigo50,
    fontColorHex: ExcelColor.indigo900,
    fontSize: 11,
    italic: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
  );

  CellStyle get _estiloCabecalho => CellStyle(
    backgroundColorHex: ExcelColor.blueGrey800,
    fontColorHex: ExcelColor.white,
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    textWrapping: TextWrapping.WrapText,
    leftBorder: _bordaFina,
    rightBorder: _bordaFina,
    topBorder: _bordaFina,
    bottomBorder: _bordaFina,
  );

  CellStyle get _estiloCorpo => CellStyle(
    fontColorHex: ExcelColor.black,
    verticalAlign: VerticalAlign.Center,
    textWrapping: TextWrapping.WrapText,
    leftBorder: _bordaFina,
    rightBorder: _bordaFina,
    topBorder: _bordaFina,
    bottomBorder: _bordaFina,
  );

  CellStyle get _estiloRotuloKpi => CellStyle(
    backgroundColorHex: ExcelColor.blueGrey100,
    fontColorHex: ExcelColor.blueGrey900,
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    textWrapping: TextWrapping.WrapText,
    leftBorder: _bordaFina,
    rightBorder: _bordaFina,
    topBorder: _bordaFina,
    bottomBorder: _bordaFina,
  );

  CellStyle get _estiloValorKpi => CellStyle(
    backgroundColorHex: ExcelColor.white,
    fontColorHex: ExcelColor.indigo900,
    fontSize: 20,
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _bordaFina,
    rightBorder: _bordaFina,
    topBorder: _bordaFina,
    bottomBorder: _bordaFina,
  );

  CellStyle get _estiloValorAlerta => CellStyle(
    backgroundColorHex: ExcelColor.orange100,
    fontColorHex: ExcelColor.orange900,
    fontSize: 20,
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _bordaFina,
    rightBorder: _bordaFina,
    topBorder: _bordaFina,
    bottomBorder: _bordaFina,
  );

  CellStyle get _estiloValorTextoKpi => CellStyle(
    backgroundColorHex: ExcelColor.white,
    fontColorHex: ExcelColor.indigo900,
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    textWrapping: TextWrapping.WrapText,
    leftBorder: _bordaFina,
    rightBorder: _bordaFina,
    topBorder: _bordaFina,
    bottomBorder: _bordaFina,
  );

  CellStyle get _estiloPercentualKpi => CellStyle(
    backgroundColorHex: ExcelColor.green50,
    fontColorHex: ExcelColor.green900,
    fontSize: 20,
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    numberFormat: CustomNumericNumFormat(formatCode: '0.0%'),
    leftBorder: _bordaFina,
    rightBorder: _bordaFina,
    topBorder: _bordaFina,
    bottomBorder: _bordaFina,
  );

  CellStyle get _estiloPercentualTabela => CellStyle(
    fontColorHex: ExcelColor.black,
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    numberFormat: CustomNumericNumFormat(formatCode: '0.0%'),
    leftBorder: _bordaFina,
    rightBorder: _bordaFina,
    topBorder: _bordaFina,
    bottomBorder: _bordaFina,
  );

  CellStyle get _estiloStatusPresente => CellStyle(
    backgroundColorHex: ExcelColor.green100,
    fontColorHex: ExcelColor.green900,
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _bordaFina,
    rightBorder: _bordaFina,
    topBorder: _bordaFina,
    bottomBorder: _bordaFina,
  );

  CellStyle get _estiloStatusAusente => CellStyle(
    backgroundColorHex: ExcelColor.red100,
    fontColorHex: ExcelColor.red900,
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _bordaFina,
    rightBorder: _bordaFina,
    topBorder: _bordaFina,
    bottomBorder: _bordaFina,
  );

  CellStyle get _estiloStatusConflito => CellStyle(
    backgroundColorHex: ExcelColor.orange100,
    fontColorHex: ExcelColor.orange900,
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _bordaFina,
    rightBorder: _bordaFina,
    topBorder: _bordaFina,
    bottomBorder: _bordaFina,
  );

  CellStyle get _estiloStatusPendente => CellStyle(
    backgroundColorHex: ExcelColor.yellow100,
    fontColorHex: ExcelColor.orange900,
    bold: true,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _bordaFina,
    rightBorder: _bordaFina,
    topBorder: _bordaFina,
    bottomBorder: _bordaFina,
  );

  CellStyle get _estiloNota => CellStyle(
    backgroundColorHex: ExcelColor.grey100,
    fontColorHex: ExcelColor.grey800,
    italic: true,
    textWrapping: TextWrapping.WrapText,
    verticalAlign: VerticalAlign.Center,
    leftBorder: _bordaFina,
    rightBorder: _bordaFina,
    topBorder: _bordaFina,
    bottomBorder: _bordaFina,
  );
}
