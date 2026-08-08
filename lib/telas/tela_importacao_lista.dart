import 'dart:async';

import 'package:flutter/material.dart';

import '../modelos/modelos_importacao.dart';
import '../servicos/importacao_lista_servico.dart';
import '../servicos/sincronizacao_servico.dart';
import '../servicos/supabase_servico.dart';

class TelaImportacaoLista extends StatefulWidget {
  const TelaImportacaoLista({super.key});

  @override
  State<TelaImportacaoLista> createState() => _TelaImportacaoListaState();
}

class _TelaImportacaoListaState extends State<TelaImportacaoLista>
    with WidgetsBindingObserver {
  final ImportacaoListaServico _servico = ImportacaoListaServico.instance;

  ResultadoPreviaImportacao? _resultado;
  ArquivoListaSelecionado? _arquivoSelecionado;
  String? _erro;
  String? _erroPublicacao;
  bool _analisando = false;
  bool _publicando = false;
  bool? _possuiListaAtual;
  Timer? _carregamentoTimer;
  DateTime? _inicioAnalise;
  Duration _tempoAnalisando = Duration.zero;
  String _mensagemCarregamento = 'Preparando sua lista…';
  bool _appEmSegundoPlano = false;
  bool _analisePassouEmSegundoPlano = false;
  bool _retomarAnaliseAoVoltar = false;

  bool get _analiseDemorada => _tempoAnalisando.inSeconds >= 45;
  bool get _podeSairDuranteAnalise => _tempoAnalisando.inSeconds >= 90;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_atualizarEstadoDaLista());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (_analisando) _analisePassouEmSegundoPlano = true;
      _appEmSegundoPlano = true;
      return;
    }

    if (state != AppLifecycleState.resumed) return;
    _appEmSegundoPlano = false;

    if (_retomarAnaliseAoVoltar && _arquivoSelecionado != null) {
      _retomarAnaliseAoVoltar = false;
      _analisando = false;
      unawaited(_analisarArquivoSelecionado());
    }
  }

  Future<void> _atualizarEstadoDaLista() async {
    try {
      final servico = SupabaseServico();
      final mesas = await servico.listarMesas().first;
      final convidados = await servico.listarConvidados().first;
      if (mounted) {
        setState(() {
          _possuiListaAtual = mesas.isNotEmpty || convidados.isNotEmpty;
        });
      }
    } catch (_) {
      // Em caso de dúvida, mantemos a confirmação completa para evitar que
      // uma lista existente seja substituída sem aviso.
      if (mounted) {
        setState(() {
          _possuiListaAtual = true;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _carregamentoTimer?.cancel();
    super.dispose();
  }

  Future<void> _selecionarArquivo() async {
    if (_analisando || _publicando) return;

    try {
      final arquivo = await _servico.selecionarArquivo();
      if (!mounted || arquivo == null) return;

      setState(() {
        _arquivoSelecionado = arquivo;
        _resultado = null;
        _erro = null;
        _erroPublicacao = null;
      });
    } on ImportacaoListaException catch (erro) {
      if (mounted) setState(() => _erro = erro.mensagem);
    } catch (erro) {
      if (mounted) setState(() => _erro = 'Não foi possível selecionar o arquivo: $erro');
    }
  }

  Future<void> _tirarFoto() async {
    if (_analisando || _publicando) return;

    try {
      final arquivo = await _servico.tirarFoto();
      if (!mounted || arquivo == null) return;

      setState(() {
        _arquivoSelecionado = arquivo;
        _resultado = null;
        _erro = null;
        _erroPublicacao = null;
      });
    } on ImportacaoListaException catch (erro) {
      if (mounted) setState(() => _erro = erro.mensagem);
    } catch (erro) {
      if (mounted) setState(() => _erro = 'Não foi possível obter a foto: $erro');
    }
  }

  Future<void> _analisarArquivoSelecionado() async {
    final arquivo = _arquivoSelecionado;
    if (_analisando || _publicando || arquivo == null) return;

    await _executarAnalise(() => _servico.analisarArquivo(arquivo));
  }

  Future<void> _tentarAnaliseNovamente() async {
    if (_arquivoSelecionado != null) {
      await _analisarArquivoSelecionado();
    } else {
      await _selecionarArquivo();
    }
  }

  Future<void> _executarAnalise(
    Future<ResultadoPreviaImportacao> Function() iniciar,
  ) async {
    if (_analisando) return;

    setState(() {
      _analisando = true;
      _erro = null;
      _erroPublicacao = null;
      _inicioAnalise = DateTime.now();
      _tempoAnalisando = Duration.zero;
      _mensagemCarregamento = 'Preparando sua lista…';
      _analisePassouEmSegundoPlano = false;
    });
    _carregamentoTimer?.cancel();
    _carregamentoTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _atualizarCarregamento(),
    );

    try {
      final resultado = await iniciar();

      if (!mounted) return;

      setState(() {
        _resultado = resultado;
      });
    } on ImportacaoListaException catch (erro) {
      if (!mounted) {
        return;
      }

      if (_appEmSegundoPlano || _analisePassouEmSegundoPlano) {
        _prepararRetomadaDaAnalise();
      } else {
        setState(() => _erro = erro.mensagem);
      }
    } catch (erro) {
      if (!mounted) {
        return;
      }

      if (_appEmSegundoPlano || _analisePassouEmSegundoPlano) {
        _prepararRetomadaDaAnalise();
      } else {
        setState(() => _erro = 'Não foi possível analisar o arquivo: $erro');
      }
    } finally {
      _carregamentoTimer?.cancel();
      _carregamentoTimer = null;
      if (mounted && !_retomarAnaliseAoVoltar) {
        setState(() {
          _analisando = false;
          _inicioAnalise = null;
        });
      }
    }
  }

  void _prepararRetomadaDaAnalise() {
    _retomarAnaliseAoVoltar = true;
    _mensagemCarregamento =
        'A análise será retomada quando você voltar ao aplicativo…';

    if (_appEmSegundoPlano || !mounted) return;

    _retomarAnaliseAoVoltar = false;
    _analisando = false;
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        if (mounted) unawaited(_analisarArquivoSelecionado());
      }),
    );
  }

  void _atualizarCarregamento() {
    final inicio = _inicioAnalise;
    if (!mounted || inicio == null) {
      return;
    }

    final tempo = DateTime.now().difference(inicio);
    String mensagem;
    if (tempo.inSeconds < 4) {
      mensagem = 'Preparando sua lista…';
    } else if (tempo.inSeconds < 9) {
      mensagem = 'Lendo o arquivo…';
    } else if (tempo.inSeconds < 15) {
      mensagem = 'Identificando as mesas…';
    } else if (tempo.inSeconds < 22) {
      mensagem = 'Organizando os convidados…';
    } else if (tempo.inSeconds < 30) {
      mensagem = 'Conferindo nomes e observações…';
    } else if (tempo.inSeconds < 40) {
      mensagem = 'Verificando possíveis dúvidas…';
    } else if (tempo.inSeconds < 45) {
      mensagem = 'Montando a prévia para revisão…';
    } else if (tempo.inSeconds < 90) {
      mensagem = 'A lista é grande; ainda estamos trabalhando nela…';
    } else {
      mensagem =
          'Ainda trabalhando. Você pode aguardar ou voltar e tentar depois.';
    }

    setState(() {
      _tempoAnalisando = tempo;
      _mensagemCarregamento = mensagem;
    });
  }

  void _voltarDuranteAnalise() {
    if (_publicando || !_analisando) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _editarNomeConvidado({
    required int indiceConvidado,
    int? indiceMesa,
  }) async {
    final resultadoAtual = _resultado;
    if (resultadoAtual == null) {
      return;
    }

    final convidado = indiceMesa == null
        ? resultadoAtual.convidadosSemMesa[indiceConvidado]
        : resultadoAtual.mesas[indiceMesa].convidados[indiceConvidado];
    final valores = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _DialogEditarConvidado(convidado: convidado),
    );
    final nome = valores?['nome']?.trim();
    if (!mounted || nome == null || nome.isEmpty) {
      return;
    }

    final convidadoAtualizado = convidado.copyWith(
      nome: nome,
      email: valores?['email'],
      whatsapp: valores?['whatsapp'],
    );
    if (indiceMesa == null) {
      final convidados = [...resultadoAtual.convidadosSemMesa];
      convidados[indiceConvidado] = convidadoAtualizado;
      setState(() {
        _resultado = resultadoAtual.copyWith(convidadosSemMesa: convidados);
      });
      return;
    }

    final mesas = [...resultadoAtual.mesas];
    final convidados = [...mesas[indiceMesa].convidados];
    convidados[indiceConvidado] = convidadoAtualizado;
    mesas[indiceMesa] = mesas[indiceMesa].copyWith(convidados: convidados);
    setState(() {
      _resultado = resultadoAtual.copyWith(mesas: mesas);
    });
  }

  Future<void> _editarDetalheMesa(int indiceMesa) async {
    final resultadoAtual = _resultado;
    if (resultadoAtual == null) {
      return;
    }

    final mesa = resultadoAtual.mesas[indiceMesa];
    final novoDetalhe = await showDialog<String>(
      context: context,
      builder: (_) => _DialogEditarDetalheMesa(valorInicial: mesa.detalhe),
    );

    if (!mounted || novoDetalhe == null) {
      return;
    }

    final mesas = [...resultadoAtual.mesas];
    mesas[indiceMesa] = mesa.copyWith(detalhe: novoDetalhe.trim());
    setState(() {
      _resultado = resultadoAtual.copyWith(mesas: mesas);
    });
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
                    'A lista ainda possui problemas que impedem a publicação:',
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

    await _atualizarEstadoDaLista();
    if (!mounted) {
      return;
    }
    final possuiListaAtual = _possuiListaAtual ?? true;

    final confirmado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            possuiListaAtual ? 'Substituir a lista atual?' : 'Salvar lista?',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A nova lista possui ${resultado.quantidadeMesas} mesas e '
                  '${resultado.quantidadeConvidados} convidados.',
                ),
                if (possuiListaAtual) ...[
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
                ] else ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Este evento ainda não possui uma lista cadastrada. Esta '
                    'será a primeira lista salva para ele.',
                  ),
                ],
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
                if (possuiListaAtual) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'A substituição é permanente.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
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
              label: Text(
                possuiListaAtual ? 'Substituir agora' : 'Salvar lista',
              ),
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
                    : _selecionarArquivo,
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
              _mensagemCarregamento,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Estamos preparando uma prévia para você revisar. Você pode '
              'alternar de aplicativo; se o sistema pausar a conexão, '
              'retomaremos automaticamente quando você voltar.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            const _AvisoSeguro(),
            if (_analiseDemorada) ...[
              const SizedBox(height: 14),
              Text(
                _podeSairDuranteAnalise
                    ? 'Você pode voltar e tentar novamente depois. A lista atual continuará intacta.'
                    : 'Listas maiores podem levar um pouco mais de tempo.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_podeSairDuranteAnalise) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _voltarDuranteAnalise,
                icon: const Icon(Icons.arrow_back),
                label: const Text('Voltar e tentar depois'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatarTamanho(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _construirInicio() {
    final arquivo = _arquivoSelecionado;

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
                  'Importe sua lista de convidados',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Escolha um arquivo ou fotografe a lista para preparar uma '
                  'prévia de mesas e convidados.',
                ),
                const SizedBox(height: 18),
                Text(
                  'Formatos: PDF, Excel, CSV ou imagem',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 18),
                if (arquivo == null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _selecionarArquivo,
                      icon: const Icon(Icons.upload_file_outlined),
                      label: const Text('Escolher arquivo'),
                    ),
                  ),
                ] else ...[
                  Card(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.insert_drive_file_outlined),
                      title: Text(
                        arquivo.nome,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${_formatarTamanho(arquivo.tamanhoBytes)} • pronto para enviar',
                      ),
                      trailing: IconButton(
                        tooltip: 'Remover arquivo selecionado',
                        onPressed: () => setState(() {
                          _arquivoSelecionado = null;
                          _erro = null;
                        }),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _analisarArquivoSelecionado,
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: const Text('Enviar para análise'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _selecionarArquivo,
                      icon: const Icon(Icons.upload_file_outlined),
                      label: const Text('Escolher outro arquivo'),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _tirarFoto,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(
                      arquivo == null ? 'Tirar foto da lista' : 'Tirar outra foto',
                    ),
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
          _CartaoErro(mensagem: _erro!, tentarNovamente: _tentarAnaliseNovamente),
        ],
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
          _CartaoErro(mensagem: _erro!, tentarNovamente: _tentarAnaliseNovamente),
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
          for (
            var indiceMesa = 0;
            indiceMesa < resultado.mesas.length;
            indiceMesa++
          )
            _construirMesa(resultado.mesas[indiceMesa], indiceMesa),
        if (resultado.convidadosSemMesa.isNotEmpty) ...[
          const SizedBox(height: 12),
          _construirConvidadosSemMesa(resultado.convidadosSemMesa),
        ],
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: _selecionarArquivo,
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

  Widget _construirMesa(MesaPreviaImportacao mesa, int indiceMesa) {
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
            if (capacidade != null)
              mesa.capacidadeInferidaAutomaticamente
                  ? '$capacidade lugar(es) — quantidade identificada'
                  : '$capacidade lugar(es)',
            if (mesa.numeroGeradoAutomaticamente) 'número automático',
          ].join(' • '),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Editar descrição da mesa',
              onPressed: () => _editarDetalheMesa(indiceMesa),
              icon: const Icon(Icons.edit_outlined),
            ),
            if (excede)
              Tooltip(
                message:
                    '${mesa.quantidadeConvidados - capacidade!} convidado(s) acima da capacidade informada. Ninguém será removido.',
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                ),
              ),
            const Icon(Icons.expand_more),
          ],
        ),
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
            for (
              var indiceConvidado = 0;
              indiceConvidado < mesa.convidados.length;
              indiceConvidado++
            )
              _construirConvidado(
                mesa.convidados[indiceConvidado],
                indiceConvidado: indiceConvidado,
                indiceMesa: indiceMesa,
              ),
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
          for (
            var indiceConvidado = 0;
            indiceConvidado < convidados.length;
            indiceConvidado++
          )
            _construirConvidado(
              convidados[indiceConvidado],
              indiceConvidado: indiceConvidado,
            ),
        ],
      ),
    );
  }

  Widget _construirConvidado(
    ConvidadoPreviaImportacao convidado, {
    required int indiceConvidado,
    int? indiceMesa,
  }) {
    final informacoes = <String>[];
    if (convidado.leituraComBaixaConfianca) {
      informacoes.add('Confira este nome');
    }
    if (convidado.categoria != CategoriaConvidado.normal) {
      informacoes.add(convidado.categoria.rotulo);
    }
    if (convidado.email?.trim().isNotEmpty == true) {
      informacoes.add('E-mail: ${convidado.email}');
    }
    if (convidado.whatsapp?.trim().isNotEmpty == true) {
      informacoes.add('WhatsApp: ${convidado.whatsapp}');
    }

    return ListTile(
      dense: true,
      leading: Icon(
        convidado.leituraComBaixaConfianca
            ? Icons.help_outline
            : Icons.person_outline,
        color: convidado.leituraComBaixaConfianca ? Colors.orange : null,
      ),
      title: Text(convidado.nomeComDescricao),
      subtitle: informacoes.isEmpty ? null : Text(informacoes.join(' • ')),
      trailing: IconButton(
        tooltip: 'Editar convidado',
        onPressed: () => _editarNomeConvidado(
          indiceConvidado: indiceConvidado,
          indiceMesa: indiceMesa,
        ),
        icon: const Icon(Icons.edit_outlined),
      ),
    );
  }
}

class _DialogEditarConvidado extends StatefulWidget {
  const _DialogEditarConvidado({required this.convidado});

  final ConvidadoPreviaImportacao convidado;

  @override
  State<_DialogEditarConvidado> createState() => _DialogEditarConvidadoState();
}

class _DialogEditarConvidadoState extends State<_DialogEditarConvidado> {
  late final TextEditingController _nome;
  late final TextEditingController _email;
  late final TextEditingController _whatsapp;

  @override
  void initState() {
    super.initState();
    _nome = TextEditingController(text: widget.convidado.nome);
    _email = TextEditingController(text: widget.convidado.email ?? '');
    _whatsapp = TextEditingController(text: widget.convidado.whatsapp ?? '');
  }

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _whatsapp.dispose();
    super.dispose();
  }

  void _salvar() {
    Navigator.of(context).pop({
      'nome': _nome.text,
      'email': _email.text,
      'whatsapp': _whatsapp.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar convidado'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nome,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nome'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-mail'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _whatsapp,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'WhatsApp / telefone',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _salvar, child: const Text('Salvar')),
      ],
    );
  }
}

class _DialogEditarDetalheMesa extends StatefulWidget {
  const _DialogEditarDetalheMesa({required this.valorInicial});

  final String valorInicial;

  @override
  State<_DialogEditarDetalheMesa> createState() =>
      _DialogEditarDetalheMesaState();
}

class _DialogEditarDetalheMesaState extends State<_DialogEditarDetalheMesa> {
  late final TextEditingController _controlador;

  @override
  void initState() {
    super.initState();
    _controlador = TextEditingController(text: widget.valorInicial);
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  void _salvar() {
    Navigator.of(context).pop(_controlador.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar descrição da mesa'),
      content: TextField(
        controller: _controlador,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Descrição',
          hintText: 'Ex.: Família, amigos, fornecedores…',
        ),
        onSubmitted: (_) => _salvar(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _salvar, child: const Text('Salvar')),
      ],
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
        color: Theme.of(context).colorScheme.primaryContainer,
        border: Border.all(color: Theme.of(context).colorScheme.primary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.fact_check_outlined),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'A IA pode cometer erros. Revise a prévia antes de confirmar; '
              'nenhuma informação será alterada antes da sua confirmação.',
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
