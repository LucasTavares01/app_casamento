import 'dart:async';

import 'package:flutter/material.dart';

import '../servicos/casamento_atual_servico.dart';
import '../servicos/relatorio_excel_servico.dart';
import '../servicos/sessao_servico.dart';
import '../servicos/sincronizacao_servico.dart';
import '../modelos/tipos_evento.dart';
import 'porta_entrada.dart';
import 'tela_conta.dart';
import 'tela_principal.dart';

Future<CasamentoAtual?> mostrarDialogoEdicaoEvento({
  required BuildContext context,
  required CasamentoAtualServico servico,
  required CasamentoAtual evento,
}) {
  return showDialog<CasamentoAtual>(
    context: context,
    builder: (_) => _DialogNovoCasamento(servico: servico, existente: evento),
  );
}

enum _AcaoMenuCasamento { editar, excluir }

enum _ModoPerfil { funcionario, cerimonialista }

class TelaCasamentos extends StatefulWidget {
  final int abaInicial;

  const TelaCasamentos({super.key, this.abaInicial = 0});

  @override
  State<TelaCasamentos> createState() => _TelaCasamentosState();
}

class _TelaCasamentosState extends State<TelaCasamentos>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final CasamentoAtualServico _casamentos = CasamentoAtualServico.instance;
  final SincronizacaoServico _sincronizacao = SincronizacaoServico.instance;
  final TextEditingController _pesquisa = TextEditingController();
  final FocusNode _focoPesquisa = FocusNode();

  late Stream<List<CasamentoAtual>> _casamentosEmTempoReal;
  late final TabController _abasController;

  String? _casamentoProcessandoId;
  String? _acaoEmAndamento;
  int _abaSelecionada = 0;
  bool _podeCriarCasamentos = false;
  PapeisContaAtual _papeis = const PapeisContaAtual(
    cerimonialista: false,
    funcionario: false,
  );
  _ModoPerfil _modoPerfil = _ModoPerfil.funcionario;
  bool _habilitandoCerimonialista = false;
  bool _mostrarPesquisa = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _casamentosEmTempoReal = _criarStreamCasamentos();
    final abaInicial = widget.abaInicial.clamp(0, 1).toInt();
    _abaSelecionada = abaInicial;
    _abasController = TabController(
      length: 2,
      initialIndex: abaInicial,
      vsync: this,
    );
    _abasController.addListener(_aoTrocarAba);
    _pesquisa.addListener(_aoPesquisar);
    unawaited(_carregarPermissao());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _abasController.removeListener(_aoTrocarAba);
    _abasController.dispose();
    _pesquisa.removeListener(_aoPesquisar);
    _pesquisa.dispose();
    _focoPesquisa.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recarregar();
    }
  }

  Stream<List<CasamentoAtual>> _criarStreamCasamentos() =>
      _casamentos.listarCasamentosEmTempoReal().asBroadcastStream();

  void _aoTrocarAba() {
    if (_abasController.indexIsChanging) return;
    if (_abaSelecionada == _abasController.index) return;
    setState(() => _abaSelecionada = _abasController.index);
  }

  void _aoPesquisar() {
    if (mounted) setState(() {});
  }

  void _abrirPesquisa() {
    setState(() => _mostrarPesquisa = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focoPesquisa.requestFocus();
    });
  }

  void _fecharPesquisa() {
    _focoPesquisa.unfocus();
    _pesquisa.clear();
    setState(() => _mostrarPesquisa = false);
  }

  Future<void> _carregarPermissao() async {
    try {
      final papeis = await _casamentos.obterPapeisContaAtual();
      if (mounted) {
        final deveAbrirComoFuncionario =
            SessaoServico.instance.deveAbrirComoFuncionario;
        setState(() {
          _papeis = papeis;
          _podeCriarCasamentos = papeis.cerimonialista;
          if (deveAbrirComoFuncionario && papeis.funcionario) {
            _modoPerfil = _ModoPerfil.funcionario;
            _abaSelecionada = 0;
            _abasController.index = 0;
          } else if (papeis.cerimonialista) {
            _modoPerfil = _ModoPerfil.cerimonialista;
          } else if (papeis.funcionario) {
            _modoPerfil = _ModoPerfil.funcionario;
          }
        });
        if (deveAbrirComoFuncionario && papeis.funcionario) {
          unawaited(SessaoServico.instance.consumirAberturaComoFuncionario());
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _podeCriarCasamentos = false);
      }
    }
  }

  Future<void> _habilitarCerimonialista() async {
    if (_habilitandoCerimonialista) return;

    setState(() => _habilitandoCerimonialista = true);
    try {
      await SessaoServico.instance.habilitarPerfilCerimonialista(
        nome: SessaoServico.instance.nomeExibicaoAtual,
      );
      await _carregarPermissao();
      if (!mounted) return;
      setState(() => _modoPerfil = _ModoPerfil.cerimonialista);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conta de cerimonialista habilitada com sucesso.'),
        ),
      );
    } catch (erro) {
      _mostrarErro('Não foi possível habilitar o perfil: $erro');
    } finally {
      if (mounted) setState(() => _habilitandoCerimonialista = false);
    }
  }

  Widget _construirSeletorPerfis() {
    final cerimonialistaAtivo = _modoPerfil == _ModoPerfil.cerimonialista;
    final funcionarioDisponivel = _papeis.funcionario;
    final cerimonialistaDisponivel = _papeis.cerimonialista;

    Widget botao({
      required String texto,
      required bool selecionado,
      required bool disponivel,
      required VoidCallback aoTocar,
      required IconData icone,
    }) {
      return Expanded(
        child: SizedBox(
          height: 48,
          child: disponivel && selecionado
              ? FilledButton.icon(
                  onPressed: aoTocar,
                  icon: Icon(icone),
                  label: Text(texto),
                )
              : OutlinedButton.icon(
                  onPressed: aoTocar,
                  icon: Icon(disponivel ? icone : Icons.lock_outline, size: 19),
                  label: Text(texto),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: disponivel
                        ? null
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    side: BorderSide(
                      color: disponivel
                          ? Theme.of(context).colorScheme.outline
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
        ),
      );
    }

    return Row(
      children: [
        botao(
          texto: 'Funcionário',
          selecionado: !cerimonialistaAtivo,
          disponivel: funcionarioDisponivel,
          aoTocar: () {
            if (!funcionarioDisponivel) {
              unawaited(_recarregarPermissaoAoTentarFuncionario());
              return;
            }
            setState(() => _modoPerfil = _ModoPerfil.funcionario);
          },
          icone: Icons.badge_outlined,
        ),
        const SizedBox(width: 10),
        botao(
          texto: 'Cerimonialista',
          selecionado: cerimonialistaAtivo,
          disponivel: cerimonialistaDisponivel,
          aoTocar: cerimonialistaDisponivel
              ? () => setState(() => _modoPerfil = _ModoPerfil.cerimonialista)
              : _habilitarCerimonialista,
          icone: Icons.fact_check_outlined,
        ),
      ],
    );
  }

  Future<void> _recarregarPermissaoAoTentarFuncionario() async {
    await _carregarPermissao();
    if (!mounted) return;
    if (_papeis.funcionario) {
      setState(() => _modoPerfil = _ModoPerfil.funcionario);
      return;
    }
    _mostrarErro('O perfil de funcionário depende de um convite.');
  }

  void _recarregar() {
    setState(() => _casamentosEmTempoReal = _criarStreamCasamentos());
    unawaited(_carregarPermissao());
  }

  Future<void> _abrir(
    CasamentoAtual casamento, {
    bool abrirCadastros = false,
  }) async {
    try {
      await _casamentos.selecionar(casamento);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TelaPrincipal(
            somenteLeituraInicial: casamento.encerrado,
            abaInicial: abrirCadastros && casamento.ehAdmin ? 2 : 0,
          ),
        ),
      );
    } catch (erro) {
      _mostrarErro(erro.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> _novoCasamento() async {
    final criado = await showDialog<CasamentoAtual>(
      context: context,
      builder: (_) => _DialogNovoCasamento(servico: _casamentos),
    );
    if (criado == null || !mounted) return;
    await _abrir(criado, abrirCadastros: true);
  }

  Future<void> _editarCasamento(CasamentoAtual casamento) async {
    if (!casamento.ehAdmin || casamento.encerrado) return;
    await showDialog<CasamentoAtual>(
      context: context,
      builder: (_) =>
          _DialogNovoCasamento(servico: _casamentos, existente: casamento),
    );
    if (mounted) _recarregar();
  }

  Future<void> _finalizar(CasamentoAtual casamento) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Encerrar evento?'),
        content: Text(
          'O evento “${casamento.descricao}” será finalizado. A equipe '
          'de funcionários continuará vendo o evento em Finalizados, apenas '
          'para consulta, sem poder alterar lista, mesas ou chegadas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Encerrar evento'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    await _executarAcao(
      casamento: casamento,
      acao: 'encerrando',
      executar: () => _casamentos.finalizarCasamento(casamento),
      sucesso: 'Evento encerrado com sucesso.',
      erro: 'Não foi possível encerrar o evento',
    );
  }

  Future<void> _excluir(CasamentoAtual casamento) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_forever_outlined),
        title: const Text('Excluir definitivamente?'),
        content: Text(
          'Todos os dados de “${casamento.descricao}” serão apagados, '
          'incluindo mesas, convidados, check-ins, equipe e histórico. '
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir definitivamente'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    await _executarAcao(
      casamento: casamento,
      acao: 'excluindo',
      executar: () => _casamentos.excluirCasamentoDefinitivamente(casamento),
      sucesso: 'Evento excluído definitivamente.',
      erro: 'Não foi possível excluir o evento',
    );
  }

  Future<void> _gerarRelatorio(CasamentoAtual casamento) async {
    if (_casamentoProcessandoId != null) return;

    setState(() {
      _casamentoProcessandoId = casamento.id;
      _acaoEmAndamento = 'relatorio';
    });

    try {
      await _casamentos.selecionar(casamento);
      final sincronizacao = await _sincronizacao.sincronizarDadosIniciais();
      final relatorio = await RelatorioExcelServico.instance
          .gerarECompartilhar();

      if (!mounted) return;

      final complemento = sincronizacao.sucesso
          ? ''
          : ' O arquivo usou os dados disponíveis neste aparelho.';

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Relatório gerado: ${relatorio.presentes} presentes, '
              '${relatorio.ausentes} ausentes e '
              '${relatorio.conflitos} conflito(s).$complemento',
            ),
          ),
        );
    } catch (erro) {
      _mostrarErro('Não foi possível gerar o relatório: $erro');
    } finally {
      if (mounted) {
        setState(() {
          _casamentoProcessandoId = null;
          _acaoEmAndamento = null;
        });
      }
    }
  }

  Future<void> _executarAcao({
    required CasamentoAtual casamento,
    required String acao,
    required Future<void> Function() executar,
    required String sucesso,
    required String erro,
  }) async {
    if (_casamentoProcessandoId != null) return;

    setState(() {
      _casamentoProcessandoId = casamento.id;
      _acaoEmAndamento = acao;
    });

    try {
      await executar();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(sucesso)));
    } catch (excecao) {
      _mostrarErro('$erro: $excecao');
    } finally {
      if (mounted) {
        setState(() {
          _casamentoProcessandoId = null;
          _acaoEmAndamento = null;
        });
      }
    }
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensagem)));
  }

  Future<void> _sair() async {
    await SessaoServico.instance.encerrarSessao();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const TelaPortaDeEntrada()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Meus eventos'),
            Text(
              _modoPerfil == _ModoPerfil.cerimonialista
                  ? 'Cerimonialista'
                  : 'Funcionário',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _mostrarPesquisa ? 'Fechar pesquisa' : 'Pesquisar eventos',
            onPressed: _mostrarPesquisa ? _fecharPesquisa : _abrirPesquisa,
            icon: Icon(_mostrarPesquisa ? Icons.close : Icons.search),
          ),
          IconButton(
            tooltip: 'Configurações da conta',
            onPressed: () async {
              await Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const TelaConta()));
              if (mounted) await _carregarPermissao();
            },
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _recarregar,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Sair',
            onPressed: _sair,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: StreamBuilder<List<CasamentoAtual>>(
        stream: _casamentosEmTempoReal,
        builder: (context, snapshot) {
          if (!_podeCriarCasamentos ||
              _modoPerfil != _ModoPerfil.cerimonialista ||
              _abaSelecionada != 0) {
            return const SizedBox.shrink();
          }

          return FloatingActionButton.extended(
            onPressed: _novoCasamento,
            icon: const Icon(Icons.add),
            label: const Text('Novo evento'),
          );
        },
      ),
      body: StreamBuilder<List<CasamentoAtual>>(
        stream: _casamentosEmTempoReal,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.waiting &&
              snapshot.hasError) {
            return _EstadoErro(onTentarNovamente: _recarregar);
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final todos = snapshot.data!
              .where(
                (casamento) => _modoPerfil == _ModoPerfil.cerimonialista
                    ? casamento.ehAdmin
                    : !casamento.ehAdmin,
              )
              .toList();
          final ativos = todos
              .where((casamento) => !_estaFinalizadoNaVisao(casamento))
              .toList();
          final finalizados = todos
              .where((casamento) => _estaFinalizadoNaVisao(casamento))
              .toList();

          final listaAtual = _abaSelecionada == 0 ? ativos : finalizados;
          final filtrados = _filtrarCasamentos(listaAtual);

          return Column(
            children: [
              if (_papeis.funcionario && _papeis.cerimonialista)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: _construirSeletorPerfis(),
                ),
              if (_mostrarPesquisa)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _pesquisa,
                    focusNode: _focoPesquisa,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Pesquisar evento',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _pesquisa.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpar pesquisa',
                              onPressed: _pesquisa.clear,
                              icon: const Icon(Icons.close),
                            ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TabBar(
                  controller: _abasController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorWeight: 3,
                  tabs: [
                    Tab(text: 'Meus eventos (${ativos.length})'),
                    Tab(text: 'Finalizados (${finalizados.length})'),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: filtrados.isEmpty
                    ? _EstadoListaVazia(
                        pesquisando: _pesquisa.text.trim().isNotEmpty,
                        finalizados: _abaSelecionada == 1,
                        temEventos: todos.isNotEmpty,
                        podeCriar:
                            _podeCriarCasamentos &&
                            _modoPerfil == _ModoPerfil.cerimonialista,
                        onCriar: _novoCasamento,
                      )
                    : RefreshIndicator(
                        onRefresh: () async => _recarregar(),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                          itemCount: filtrados.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) => _CardCasamento(
                            casamento: filtrados[index],
                            processando:
                                _casamentoProcessandoId == filtrados[index].id,
                            finalizadoNaLista: _estaFinalizadoNaVisao(
                              filtrados[index],
                            ),
                            acaoEmAndamento: _acaoEmAndamento,
                            onAbrir: () => _abrir(filtrados[index]),
                            onEditar: () => _editarCasamento(filtrados[index]),
                            onEncerrar: () => _finalizar(filtrados[index]),
                            onRelatorio: () =>
                                _gerarRelatorio(filtrados[index]),
                            onExcluir: () => _excluir(filtrados[index]),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _estaFinalizadoNaVisao(CasamentoAtual casamento) {
    return casamento.status == 'arquivado' || casamento.status == 'finalizado';
  }

  List<CasamentoAtual> _filtrarCasamentos(List<CasamentoAtual> casamentos) {
    final termo = _normalizar(_pesquisa.text);
    if (termo.isEmpty) return casamentos;

    return casamentos.where((casamento) {
      final data = casamento.dataEvento == null
          ? ''
          : _formatarData(casamento.dataEvento!);
      final conteudo = [
        casamento.descricao,
        casamento.titulo,
        casamento.nomePessoa1,
        casamento.nomePessoa2,
        casamento.localEvento,
        casamento.status,
        _rotuloStatus(casamento.status),
        data,
        casamento.horarioEvento,
      ].whereType<String>().join(' ');

      return _normalizar(conteudo).contains(termo);
    }).toList();
  }

  String _normalizar(String texto) {
    var resultado = texto.trim().toLowerCase();
    const origem = 'áàãâäéèêëíìîïóòõôöúùûüç';
    const destino = 'aaaaaeeeeiiiiooooouuuuc';
    for (var indice = 0; indice < origem.length; indice++) {
      resultado = resultado.replaceAll(origem[indice], destino[indice]);
    }
    return resultado;
  }
}

class _CardCasamento extends StatelessWidget {
  final CasamentoAtual casamento;
  final bool processando;
  final bool finalizadoNaLista;
  final String? acaoEmAndamento;
  final VoidCallback onAbrir;
  final VoidCallback onEditar;
  final VoidCallback onEncerrar;
  final VoidCallback onRelatorio;
  final VoidCallback onExcluir;

  const _CardCasamento({
    required this.casamento,
    required this.processando,
    required this.finalizadoNaLista,
    required this.acaoEmAndamento,
    required this.onAbrir,
    required this.onEditar,
    required this.onEncerrar,
    required this.onRelatorio,
    required this.onExcluir,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final finalizado = casamento.status == 'finalizado';
    final arquivado = casamento.status == 'arquivado';
    final somenteLeitura = casamento.encerrado;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      child: InkWell(
        onTap: processando ? null : onAbrir,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _corFundoStatus(tema.colorScheme),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      casamento.tipoEvento.icone,
                      color: _corTextoStatus(tema.colorScheme),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          casamento.titulo,
                          style: tema.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          casamento.ehAdmin ? 'Administradora' : 'Funcionário',
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: tema.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          casamento.tipoEvento.rotulo,
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: tema.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (casamento.ehAdmin)
                    PopupMenuButton<_AcaoMenuCasamento>(
                      tooltip: 'Mais opções',
                      enabled: !processando,
                      onSelected: (acao) {
                        switch (acao) {
                          case _AcaoMenuCasamento.editar:
                            onEditar();
                            break;
                          case _AcaoMenuCasamento.excluir:
                            onExcluir();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        if (!somenteLeitura)
                          const PopupMenuItem(
                            value: _AcaoMenuCasamento.editar,
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.edit_outlined),
                              title: Text('Editar informações'),
                            ),
                          ),
                        const PopupMenuItem(
                          value: _AcaoMenuCasamento.excluir,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.delete_outline),
                            title: Text('Excluir definitivamente'),
                          ),
                        ),
                      ],
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(top: 10, right: 4),
                      child: Icon(Icons.chevron_right),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _InfoCasamento(
                rotulo: 'Status',
                valor: _rotuloStatus(casamento.status),
                icone: Icons.info_outline,
              ),
              const SizedBox(height: 9),
              _InfoCasamento(
                rotulo: 'Tipo',
                valor: casamento.tipoEvento.rotulo,
                icone: casamento.tipoEvento.icone,
              ),
              if (casamento.descricaoPessoas.isNotEmpty) ...[
                const SizedBox(height: 9),
                _InfoCasamento(
                  rotulo:
                      casamento.rotuloPessoas ??
                      casamento.tipoEvento.rotuloPessoa,
                  valor: casamento.descricaoPessoas,
                  icone: Icons.person_outline,
                ),
              ],
              const SizedBox(height: 9),
              _InfoCasamento(
                rotulo: 'Data',
                valor: casamento.dataEvento == null
                    ? 'Não informada'
                    : _formatarData(casamento.dataEvento!),
                icone: Icons.calendar_today_outlined,
              ),
              const SizedBox(height: 9),
              _InfoCasamento(
                rotulo: 'Horário',
                valor: _formatarHorario(casamento.horarioEvento),
                icone: Icons.schedule_outlined,
              ),
              const SizedBox(height: 9),
              _InfoCasamento(
                rotulo: 'Local',
                valor: casamento.localEvento?.trim().isNotEmpty == true
                    ? casamento.localEvento!.trim()
                    : 'Não informado',
                icone: Icons.location_on_outlined,
              ),
              if (finalizadoNaLista) ...[
                const SizedBox(height: 14),
                Text(
                  finalizado
                      ? 'Este evento foi finalizado e está disponível '
                            'somente para leitura.'
                      : 'Restaure este evento para acessá-lo novamente.',
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (casamento.ehAdmin && !arquivado) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1),
                ),
                if (processando)
                  Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text(_textoAcao(acaoEmAndamento)),
                    ],
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onRelatorio,
                        icon: const Icon(Icons.table_view_outlined),
                        label: const Text('Gerar relatório'),
                      ),
                      if (!finalizado)
                        FilledButton.tonalIcon(
                          onPressed: onEncerrar,
                          icon: const Icon(Icons.event_busy_outlined),
                          label: const Text('Encerrar evento'),
                        ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _corFundoStatus(ColorScheme cores) {
    switch (casamento.status) {
      case 'ativo':
        return cores.primaryContainer;
      case 'finalizado':
        return cores.tertiaryContainer;
      case 'arquivado':
        return cores.surfaceContainerHighest;
      default:
        return cores.secondaryContainer;
    }
  }

  Color _corTextoStatus(ColorScheme cores) {
    switch (casamento.status) {
      case 'ativo':
        return cores.onPrimaryContainer;
      case 'finalizado':
        return cores.onTertiaryContainer;
      case 'arquivado':
        return cores.onSurfaceVariant;
      default:
        return cores.onSecondaryContainer;
    }
  }

  String _textoAcao(String? acao) {
    switch (acao) {
      case 'relatorio':
        return 'Gerando relatório...';
      case 'encerrando':
        return 'Encerrando evento...';
      case 'arquivando':
        return 'Arquivando evento...';
      case 'restaurando':
        return 'Restaurando evento...';
      case 'excluindo':
        return 'Excluindo evento...';
      default:
        return 'Processando...';
    }
  }
}

class _InfoCasamento extends StatelessWidget {
  final String rotulo;
  final String valor;
  final IconData icone;

  const _InfoCasamento({
    required this.rotulo,
    required this.valor,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icone, size: 18, color: tema.colorScheme.onSurfaceVariant),
        const SizedBox(width: 9),
        SizedBox(
          width: 64,
          child: Text(
            '$rotulo:',
            style: tema.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(child: Text(valor, style: tema.textTheme.bodyMedium)),
      ],
    );
  }
}

class _EstadoErro extends StatelessWidget {
  final VoidCallback onTentarNovamente;

  const _EstadoErro({required this.onTentarNovamente});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Não foi possível carregar seus eventos.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onTentarNovamente,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadoListaVazia extends StatelessWidget {
  final bool pesquisando;
  final bool finalizados;
  final bool temEventos;
  final bool podeCriar;
  final VoidCallback onCriar;

  const _EstadoListaVazia({
    required this.pesquisando,
    required this.finalizados,
    required this.temEventos,
    required this.podeCriar,
    required this.onCriar,
  });

  @override
  Widget build(BuildContext context) {
    final titulo = pesquisando
        ? 'Nenhum evento encontrado'
        : finalizados
        ? 'Nenhum evento finalizado'
        : temEventos
        ? 'Nenhum evento ativo'
        : 'Você ainda não tem eventos cadastrados';
    final descricao = pesquisando
        ? 'Tente pesquisar por outro nome, status, data ou local.'
        : finalizados
        ? 'Os eventos finalizados aparecerão aqui.'
        : temEventos
        ? 'Seus eventos finalizados continuam disponíveis na aba Finalizados.'
        : 'Crie o primeiro evento para montar a lista e convidar sua equipe.';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              pesquisando
                  ? Icons.search_off_outlined
                  : finalizados
                  ? Icons.task_alt_outlined
                  : Icons.event_outlined,
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(descricao, textAlign: TextAlign.center),
            if (!pesquisando && !finalizados && podeCriar) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onCriar,
                icon: const Icon(Icons.add),
                label: Text(
                  temEventos ? 'Criar novo evento' : 'Criar primeiro evento',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _rotuloStatus(String status) {
  switch (status) {
    case 'ativo':
      return 'Ativo';
    case 'finalizado':
      return 'Finalizado';
    case 'arquivado':
      return 'Arquivado';
    case 'rascunho':
      return 'Rascunho';
    default:
      return status.isEmpty ? 'Não informado' : status;
  }
}

String _formatarData(DateTime data) {
  return '${data.day.toString().padLeft(2, '0')}/'
      '${data.month.toString().padLeft(2, '0')}/${data.year}';
}

String _formatarHorario(String? horario) {
  final valor = horario?.trim();
  if (valor == null || valor.isEmpty) return 'Não informado';
  return valor.length >= 5 ? valor.substring(0, 5) : valor;
}

class _DialogNovoCasamento extends StatefulWidget {
  final CasamentoAtualServico servico;
  final CasamentoAtual? existente;

  const _DialogNovoCasamento({required this.servico, this.existente});

  @override
  State<_DialogNovoCasamento> createState() => _DialogNovoCasamentoState();
}

class _DialogNovoCasamentoState extends State<_DialogNovoCasamento> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titulo;
  late final TextEditingController _pessoas;
  late final TextEditingController _local;
  late TipoEvento _tipo;
  DateTime? _data;
  TimeOfDay? _hora;
  bool _salvando = false;
  bool _validouData = false;
  bool _validouHora = false;

  bool get _editando => widget.existente != null;

  @override
  void initState() {
    super.initState();
    final existente = widget.existente;
    final nomesAntigos = [
      existente?.nomePessoa1,
      existente?.nomePessoa2,
    ].whereType<String>().where((nome) => nome.trim().isNotEmpty).join(' e ');
    _titulo = TextEditingController(text: existente?.titulo ?? '');
    _pessoas = TextEditingController(text: nomesAntigos);
    _local = TextEditingController(text: existente?.localEvento ?? '');
    _tipo = existente?.tipoEvento ?? TipoEvento.casamento;
    _data = existente?.dataEvento;
    final hora = existente?.horarioEvento;
    if (hora != null && hora.length >= 5) {
      final partes = hora.split(':');
      final horas = int.tryParse(partes.first);
      final minutos = int.tryParse(partes[1]);
      if (horas != null && minutos != null) {
        _hora = TimeOfDay(hour: horas, minute: minutos);
      }
    }
  }

  @override
  void dispose() {
    _titulo.dispose();
    _pessoas.dispose();
    _local.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final data = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _data ?? DateTime.now(),
      locale: const Locale('pt', 'BR'),
      builder: _construirDialogoLocalizado,
    );
    if (data != null) setState(() => _data = data);
  }

  Future<void> _selecionarHora() async {
    final hora = await showTimePicker(
      context: context,
      initialTime: _hora ?? TimeOfDay.now(),
      builder: _construirDialogoLocalizado,
    );
    if (hora != null) setState(() => _hora = hora);
  }

  Widget _construirDialogoLocalizado(BuildContext context, Widget? child) {
    final dadosTela = MediaQuery.of(
      context,
    ).copyWith(alwaysUse24HourFormat: true);
    return MediaQuery(
      data: dadosTela,
      child: Localizations.override(
        context: context,
        locale: const Locale('pt', 'BR'),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }

  Future<void> _salvar() async {
    final valido = _formKey.currentState!.validate();
    setState(() {
      _validouData = true;
      _validouHora = true;
    });
    if (!valido || _data == null || _hora == null) return;

    setState(() => _salvando = true);
    final horario =
        '${_hora!.hour.toString().padLeft(2, '0')}:${_hora!.minute.toString().padLeft(2, '0')}:00';
    try {
      final evento = _editando
          ? await widget.servico.atualizarCasamento(
              casamento: widget.existente!,
              titulo: _titulo.text,
              tipoEvento: _tipo,
              nomePessoa1: _pessoas.text,
              dataEvento: _data!,
              horarioEvento: horario,
              localEvento: _local.text,
            )
          : await widget.servico.criarCasamento(
              titulo: _titulo.text,
              tipoEvento: _tipo,
              nomePessoa1: _pessoas.text,
              dataEvento: _data!,
              horarioEvento: horario,
              localEvento: _local.text,
            );
      if (mounted) Navigator.pop(context, evento);
    } catch (erro) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível salvar: $erro')),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataTexto = _data == null
        ? 'Definir data do evento'
        : '${_data!.day.toString().padLeft(2, '0')}/${_data!.month.toString().padLeft(2, '0')}/${_data!.year}';
    return AlertDialog(
      title: Text(_editando ? 'Editar evento' : 'Novo evento'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<TipoEvento>(
                  initialValue: _tipo,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de evento',
                    border: OutlineInputBorder(),
                  ),
                  items: TipoEvento.values
                      .map(
                        (tipo) => DropdownMenuItem(
                          value: tipo,
                          child: Text(tipo.rotulo),
                        ),
                      )
                      .toList(),
                  onChanged: _salvando
                      ? null
                      : (valor) {
                          if (valor != null) setState(() => _tipo = valor);
                        },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _titulo,
                  decoration: const InputDecoration(
                    labelText: 'Nome do evento',
                    border: OutlineInputBorder(),
                  ),
                  validator: (valor) => (valor?.trim().length ?? 0) >= 2
                      ? null
                      : 'Informe um nome.',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pessoas,
                  decoration: InputDecoration(
                    labelText: '${_tipo.rotuloPessoa} (opcional)',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _local,
                  decoration: const InputDecoration(
                    labelText: 'Local (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _selecionarData,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(dataTexto),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.2,
                      ),
                      minimumSize: const Size.fromHeight(48),
                      textStyle: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (_validouData && _data == null)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'A data é obrigatória.',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _selecionarHora,
                    icon: const Icon(Icons.schedule_outlined),
                    label: Text(
                      _hora == null
                          ? 'Definir horário do evento'
                          : 'Horário: ${_hora!.format(context)}',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1.2,
                      ),
                      minimumSize: const Size.fromHeight(48),
                      textStyle: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (_validouHora && _hora == null)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'O horário é obrigatório.',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _salvando ? null : _salvar,
          child: Text(
            _salvando
                ? 'Salvando...'
                : _editando
                ? 'Salvar'
                : 'Criar',
          ),
        ),
      ],
    );
  }
}
