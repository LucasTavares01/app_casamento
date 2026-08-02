import 'package:flutter/material.dart';

import '../modelos/modelos_importacao.dart';
import '../servicos/importacao_lista_servico.dart';
import '../servicos/sincronizacao_servico.dart';

class TelaImportacaoLista extends StatefulWidget {
  const TelaImportacaoLista({super.key});

  @override
  State<TelaImportacaoLista> createState() => _TelaImportacaoListaState();
}

class _TelaImportacaoListaState extends State<TelaImportacaoLista> {
  final ImportacaoListaServico _servico = ImportacaoListaServico.instance;

  ResultadoPreviaImportacao? _resultado;
  String? _erro;
  String? _erroPublicacao;
  bool _analisando = false;
  bool _publicando = false;

  Future<void> _selecionarEAnalisar() async {
    if (_analisando) {
      return;
    }

    setState(() {
      _analisando = true;
      _erro = null;
      _erroPublicacao = null;
    });

    try {
      final resultado = await _servico.selecionarEAnalisarArquivo();

      if (!mounted || resultado == null) {
        return;
      }

      setState(() {
        _resultado = resultado;
      });
    } on ImportacaoListaException catch (erro) {
      if (!mounted) {
        return;
      }

      setState(() {
        _erro = erro.mensagem;
      });
    } catch (erro) {
      if (!mounted) {
        return;
      }

      setState(() {
        _erro = 'Não foi possível analisar o arquivo: $erro';
      });
    } finally {
      if (mounted) {
        setState(() {
          _analisando = false;
        });
      }
    }
  }

  Future<void> _confirmarPublicacao(ResultadoPreviaImportacao resultado) async {
    if (_publicando || _analisando) {
      return;
    }

    final problemas = _servico.validarParaPublicacao(resultado);
    if (problemas.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Corrija antes de publicar'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'A lista ainda possui problemas que impedem a substituição:',
                  ),
                  const SizedBox(height: 12),
                  for (final problema in problemas)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline, size: 19),
                          const SizedBox(width: 8),
                          Expanded(child: Text(problema)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Entendi'),
              ),
            ],
          );
        },
      );
      return;
    }

    final confirmado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Substituir a lista atual?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A nova lista possui ${resultado.quantidadeMesas} mesas e '
                  '${resultado.quantidadeConvidados} convidados.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ao confirmar, serão substituídos:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  '• lista atual de mesas e convidados\n'
                  '• check-ins e históricos de presença\n'
                  '• conflitos e operações antigas\n'
                  '• equipe e mensagens do chat',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Os usuários e as sessões ativas serão preservados. Todos os '
                  'aparelhos receberão a nova versão da lista em tempo real.',
                ),
                if (resultado.avisos.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'A prévia possui ${resultado.avisos.length} aviso(s). '
                      'Ao continuar, você confirma que revisou esses itens.',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const Text(
                  'A substituição é permanente.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Substituir agora'),
            ),
          ],
        );
      },
    );

    if (confirmado != true || !mounted) {
      return;
    }

    setState(() {
      _publicando = true;
      _erroPublicacao = null;
    });

    try {
      final publicacao = await _servico.publicarLista(resultado);

      var sincronizacaoConcluida = false;
      try {
        final sincronizacao = await SincronizacaoServico.instance
            .sincronizarDadosIniciais();
        sincronizacaoConcluida = sincronizacao.sucesso;
      } catch (_) {
        sincronizacaoConcluida = false;
      }

      if (!mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.cloud_done_outlined),
                SizedBox(width: 10),
                Expanded(child: Text('Nova lista publicada')),
              ],
            ),
            content: Text(
              'Versão ${publicacao.versao} publicada com '
              '${publicacao.mesas} mesas e ${publicacao.convidados} convidados.'
              '${publicacao.convidadosSemMesa > 0 ? '\n\n${publicacao.convidadosSemMesa} convidado(s) ficaram sem mesa.' : ''}'
              '\n\n${sincronizacaoConcluida ? 'Este aparelho já recebeu a nova lista.' : 'A lista foi publicada. Este aparelho terminará de baixá-la na próxima sincronização.'}'
              '\nOs demais aparelhos serão atualizados em tempo real.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Concluir'),
              ),
            ],
          );
        },
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ImportacaoListaException catch (erro) {
      if (!mounted) {
        return;
      }
      setState(() {
        _erroPublicacao = erro.mensagem;
      });
    } catch (erro) {
      if (!mounted) {
        return;
      }
      setState(() {
        _erroPublicacao = 'Não foi possível substituir a lista: $erro';
      });
    } finally {
      if (mounted) {
        setState(() {
          _publicando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultado = _resultado;

    return PopScope(
      canPop: !_publicando,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Importar lista de convidados'),
          actions: [
            if (resultado != null)
              IconButton(
                tooltip: 'Analisar outro arquivo',
                onPressed: _analisando || _publicando
                    ? null
                    : _selecionarEAnalisar,
                icon: const Icon(Icons.upload_file_outlined),
              ),
          ],
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _publicando
                ? _construirPublicacao()
                : _analisando
                ? _construirCarregamento()
                : resultado == null
                ? _construirInicio()
                : _construirPrevia(resultado),
          ),
        ),
      ),
    );
  }

  Widget _construirPublicacao() {
    return Center(
      key: const ValueKey('publicando'),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 22),
            Text(
              'Atualizando a lista oficial',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Não feche o aplicativo. A versão oficial está sendo atualizada '
              'e todos os dados da nova lista estão sendo gravados.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirCarregamento() {
    return Center(
      key: const ValueKey('analisando'),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 22),
            Text(
              'Preparando sua lista',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Estamos identificando as mesas e os convidados. '
              'Isso pode levar alguns minutos.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            const _AvisoSeguro(),
          ],
        ),
      ),
    );
  }

  Widget _construirInicio() {
    return ListView(
      key: const ValueKey('inicio'),
      padding: const EdgeInsets.all(18),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.document_scanner_outlined,
                  size: 42,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 14),
                Text(
                  'Selecione a lista do casamento',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                const Text(
                  'A IA identificará todas as mesas e todas as pessoas, mesmo '
                  'quando a quantidade de convidados for maior que a quantidade '
                  'de lugares informada.',
                ),
                const SizedBox(height: 18),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('PDF')),
                    Chip(label: Text('Excel')),
                    Chip(label: Text('CSV')),
                    Chip(label: Text('Imagem')),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _selecionarEAnalisar,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Selecionar e analisar arquivo'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _AvisoSeguro(),
        if (_erro != null) ...[
          const SizedBox(height: 12),
          _CartaoErro(mensagem: _erro!, tentarNovamente: _selecionarEAnalisar),
        ],
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'O que a IA vai procurar',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                _LinhaInformativa(
                  icone: Icons.table_restaurant_outlined,
                  texto: 'Número, nome, detalhe e capacidade de cada mesa.',
                ),
                _LinhaInformativa(
                  icone: Icons.people_alt_outlined,
                  texto: 'Todos os convidados, sem limitar pelos lugares.',
                ),
                _LinhaInformativa(
                  icone: Icons.child_care_outlined,
                  texto: 'Bebês, não pagantes e pagantes de 50%.',
                ),
                _LinhaInformativa(
                  icone: Icons.warning_amber_rounded,
                  texto:
                      'Nomes ilegíveis, possíveis duplicidades e dados incompletos.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _construirPrevia(ResultadoPreviaImportacao resultado) {
    return ListView(
      key: const ValueKey('previa'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: [
        const _AvisoSeguro(),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resultado.arquivoNome,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (resultado.resumo.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(resultado.resumo),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _ResumoItem(
                      icone: Icons.table_restaurant_outlined,
                      valor: resultado.quantidadeMesas.toString(),
                      rotulo: 'Mesas',
                    ),
                    _ResumoItem(
                      icone: Icons.people_alt_outlined,
                      valor: resultado.quantidadeConvidados.toString(),
                      rotulo: 'Convidados',
                    ),
                    _ResumoItem(
                      icone: Icons.warning_amber_rounded,
                      valor: resultado.avisos.length.toString(),
                      rotulo: 'Revisões',
                    ),
                    if (resultado.quantidadeBebes > 0)
                      _ResumoItem(
                        icone: Icons.child_care_outlined,
                        valor: resultado.quantidadeBebes.toString(),
                        rotulo: 'Bebês',
                      ),
                    if (resultado.quantidadeNaoPagantes > 0)
                      _ResumoItem(
                        icone: Icons.person_outline,
                        valor: resultado.quantidadeNaoPagantes.toString(),
                        rotulo: 'Não pagantes',
                      ),
                    if (resultado.quantidadePagantes50 > 0)
                      _ResumoItem(
                        icone: Icons.percent,
                        valor: resultado.quantidadePagantes50.toString(),
                        rotulo: 'Pagantes 50%',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_erro != null) ...[
          const SizedBox(height: 12),
          _CartaoErro(mensagem: _erro!, tentarNovamente: _selecionarEAnalisar),
        ],
        if (resultado.avisos.isNotEmpty) ...[
          const SizedBox(height: 12),
          _construirAvisos(resultado.avisos),
        ],
        const SizedBox(height: 18),
        Text(
          'Mesas encontradas',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        if (resultado.mesas.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Nenhuma mesa foi identificada no arquivo.'),
            ),
          )
        else
          for (final mesa in resultado.mesas) _construirMesa(mesa),
        if (resultado.convidadosSemMesa.isNotEmpty) ...[
          const SizedBox(height: 12),
          _construirConvidadosSemMesa(resultado.convidadosSemMesa),
        ],
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: _selecionarEAnalisar,
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Analisar outro arquivo'),
        ),
        const SizedBox(height: 10),
        if (_erroPublicacao != null) ...[
          _CartaoErroPublicacao(mensagem: _erroPublicacao!),
          const SizedBox(height: 10),
        ],
        FilledButton.icon(
          onPressed: () => _confirmarPublicacao(resultado),
          icon: const Icon(Icons.cloud_upload_outlined),
          label: const Text('Substituir lista atual'),
        ),
        const SizedBox(height: 8),
        const Text(
          'A lista só será alterada depois da confirmação. A publicação cria uma '
          'nova versão oficial e atualiza os aparelhos em tempo real.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _construirAvisos(List<AvisoPreviaImportacao> avisos) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: ExpansionTile(
        leading: Icon(
          Icons.fact_check_outlined,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
        title: Text(
          '${avisos.length} item(ns) precisam de revisão',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
        children: [
          for (final aviso in avisos)
            ListTile(
              dense: true,
              leading: const Icon(Icons.warning_amber_rounded),
              title: Text(aviso.tipo.rotulo),
              subtitle: Text(aviso.mensagem),
            ),
        ],
      ),
    );
  }

  Widget _construirMesa(MesaPreviaImportacao mesa) {
    final capacidade = mesa.capacidade;
    final excede = mesa.excedeCapacidade;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: CircleAvatar(child: Text(mesa.numero?.toString() ?? '?')),
        title: Text(
          mesa.titulo,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          [
            if (mesa.detalhe.isNotEmpty) mesa.detalhe,
            '${mesa.quantidadeConvidados} convidado(s)',
            if (capacidade != null) '$capacidade lugar(es)',
          ].join(' • '),
        ),
        trailing: excede
            ? Tooltip(
                message:
                    '${mesa.quantidadeConvidados - capacidade!} convidado(s) acima da capacidade informada. Ninguém será removido.',
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                ),
              )
            : null,
        children: [
          if (excede)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.orange.shade50,
              child: Text(
                'A mesa possui ${mesa.quantidadeConvidados} convidados para '
                '$capacidade lugares. Todos foram mantidos.',
                style: TextStyle(color: Colors.orange.shade900),
              ),
            ),
          if (mesa.convidados.isEmpty)
            const ListTile(title: Text('Nenhum convidado identificado.'))
          else
            for (final convidado in mesa.convidados)
              _construirConvidado(convidado),
        ],
      ),
    );
  }

  Widget _construirConvidadosSemMesa(
    List<ConvidadoPreviaImportacao> convidados,
  ) {
    return Card(
      color: Colors.orange.shade50,
      child: ExpansionTile(
        leading: const Icon(Icons.person_search_outlined, color: Colors.orange),
        title: Text(
          '${convidados.length} convidado(s) sem mesa',
          style: TextStyle(
            color: Colors.orange.shade900,
            fontWeight: FontWeight.bold,
          ),
        ),
        children: [
          for (final convidado in convidados) _construirConvidado(convidado),
        ],
      ),
    );
  }

  Widget _construirConvidado(ConvidadoPreviaImportacao convidado) {
    return ListTile(
      dense: true,
      leading: Icon(
        convidado.leituraComBaixaConfianca
            ? Icons.help_outline
            : Icons.person_outline,
        color: convidado.leituraComBaixaConfianca ? Colors.orange : null,
      ),
      title: Text(convidado.nomeComDescricao),
      subtitle: convidado.leituraComBaixaConfianca
          ? Text(
              'Leitura com ${(convidado.confianca * 100).round()}% de confiança',
            )
          : null,
      trailing: convidado.categoria == CategoriaConvidado.normal
          ? null
          : Chip(
              visualDensity: VisualDensity.compact,
              label: Text(
                convidado.categoria.rotulo,
                style: const TextStyle(fontSize: 11),
              ),
            ),
    );
  }
}

class _AvisoSeguro extends StatelessWidget {
  const _AvisoSeguro();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border.all(color: Colors.blue.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.visibility_outlined, color: Colors.blue),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Esta é apenas uma prévia. Nenhuma informação será alterada até '
              'você revisar e confirmar a importação.',
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumoItem extends StatelessWidget {
  final IconData icone;
  final String valor;
  final String rotulo;

  const _ResumoItem({
    required this.icone,
    required this.valor,
    required this.rotulo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 135,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icone, size: 22),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  valor,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(rotulo, style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartaoErro extends StatelessWidget {
  final String mensagem;
  final Future<void> Function() tentarNovamente;

  const _CartaoErro({required this.mensagem, required this.tentarNovamente});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Não foi possível analisar',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(mensagem),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: tentarNovamente,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartaoErroPublicacao extends StatelessWidget {
  final String mensagem;

  const _CartaoErroPublicacao({required this.mensagem});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SelectableText(
                mensagem,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinhaInformativa extends StatelessWidget {
  final IconData icone;
  final String texto;

  const _LinhaInformativa({required this.icone, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(texto)),
        ],
      ),
    );
  }
}
