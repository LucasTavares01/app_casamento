import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';

import '../banco/banco_instancia.dart';
import '../banco/banco_local.dart';

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

/// Gera um relatório completo da recepção em formato Excel (.xlsx).
///
/// O arquivo utiliza exclusivamente os dados que já estão no SQLite local.
/// A tela principal tenta sincronizar o aparelho antes de chamar este serviço.
class RelatorioExcelServico {
  RelatorioExcelServico._();

  static final RelatorioExcelServico instance = RelatorioExcelServico._();

  final BancoLocal _banco = bancoLocal;

  static const String _mimeTypeXlsx =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

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

    final excel = Excel.createExcel();
    final nomePadrao = excel.getDefaultSheet();

    if (nomePadrao != null && nomePadrao != 'Resumo') {
      excel.rename(nomePadrao, 'Resumo');
    }

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

    excel.setDefaultSheet('Resumo');

    final bytes = excel.encode();

    if (bytes == null || bytes.isEmpty) {
      throw StateError('O arquivo Excel não pôde ser criado.');
    }

    final agora = DateTime.now();
    final nomeArquivo =
        'relatorio_casamento_${_formatarParaNomeArquivo(agora)}.xlsx';

    final arquivo = XFile.fromData(
      Uint8List.fromList(bytes),
      mimeType: _mimeTypeXlsx,
      name: nomeArquivo,
    );

    final resultadoCompartilhamento = await SharePlus.instance.share(
      ShareParams(
        title: 'Relatório da recepção',
        subject: 'Relatório completo da recepção',
        text:
            'Relatório completo da recepção: presentes, ausentes, horários e histórico de check-in.',
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

      final observacao = convidado.temConflito
          ? 'Há ações contraditórias que precisam ser resolvidas no aplicativo.'
          : ultimaAlteracao?.observacao ?? '';

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
