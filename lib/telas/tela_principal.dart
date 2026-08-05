import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../modelos/modelos.dart';
import '../servicos/casamento_atual_servico.dart';
import '../servicos/sessao_servico.dart';
import '../servicos/supabase_servico.dart';
import '../servicos/sincronizacao_servico.dart';
import 'aba_cadastro.dart';
import 'aba_equipe.dart';
import 'aba_mesas.dart';
import 'aba_recepcao.dart';
import 'porta_entrada.dart';
import 'tela_conflitos.dart';
import 'tela_casamentos.dart';

enum _AcaoMenuEvento { editar, conflitos, sair }

class TelaPrincipal extends StatefulWidget {
  final bool somenteLeituraInicial;
  final int abaInicial;

  const TelaPrincipal({
    super.key,
    this.somenteLeituraInicial = false,
    this.abaInicial = 0,
  });

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal>
    with WidgetsBindingObserver {
  final SincronizacaoServico _sincronizacao = SincronizacaoServico.instance;
  final SupabaseServico _servico = SupabaseServico();

  late final Stream<List<ConflitoSincronizacao>> _streamConflitos;

  StreamSubscription<String>? _assinaturaSessaoRevogada;
  StreamSubscription<bool>? _assinaturaAcessoCasamento;
  bool _tratandoSessaoRevogada = false;
  bool _tratandoAcessoRevogado = false;
  bool _tratandoEventoFinalizado = false;
  bool _eventoJaFinalizadoAoAbrir = false;

  int _abaSelecionada = 0;

  void _abrirAbaRecepcao() {
    if (!mounted) {
      return;
    }
    setState(() {
      _abaSelecionada = 0;
    });
  }

  @override
  void initState() {
    super.initState();

    _abaSelecionada = widget.abaInicial;

    _streamConflitos = _servico.listarConflitosPendentes();
    _eventoJaFinalizadoAoAbrir =
        widget.somenteLeituraInicial ||
        (CasamentoAtualServico.instance.casamento?.encerrado ?? false);

    WidgetsBinding.instance.addObserver(this);
    _assinaturaSessaoRevogada = SessaoServico.instance.sessoesRevogadas.listen(
      _tratarSessaoRevogada,
    );
    _assinaturaAcessoCasamento = CasamentoAtualServico.instance
        .observarAcessoAoCasamentoSelecionado()
        .listen(
          (possuiAcesso) {
            if (!possuiAcesso) {
              if (widget.somenteLeituraInicial) {
                if (mounted) setState(() {});
                return;
              }
              unawaited(_tratarAcessoAoCasamentoRevogado());
            } else if (mounted) {
              final casamento = CasamentoAtualServico.instance.casamento;
              if (casamento != null &&
                  !casamento.ehAdmin &&
                  casamento.encerrado &&
                  !_eventoJaFinalizadoAoAbrir) {
                unawaited(_tratarEventoFinalizado());
              } else {
                setState(() {});
              }
            }
          },
          onError: (Object erro, StackTrace stackTrace) {
            debugPrint('Erro ao acompanhar acesso ao casamento: $erro');
            debugPrint(stackTrace.toString());
          },
        );
    _sincronizacao.addListener(_atualizarEstadoSincronizacao);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sincronizarAgora();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _assinaturaSessaoRevogada?.cancel();
    _assinaturaAcessoCasamento?.cancel();
    _sincronizacao.removeListener(_atualizarEstadoSincronizacao);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SessaoServico.instance.renovarSessao();
      // Também revalida o acesso ao servidor ao voltar do segundo plano.
      // Isso remove uma cópia offline quando a conta ou o evento foi excluído
      // em outro aparelho enquanto este celular estava sem internet.
      unawaited(_sincronizarAgora());
    }
  }

  Future<void> _tratarSessaoRevogada(String mensagem) async {
    if (!mounted || _tratandoSessaoRevogada) {
      return;
    }

    _tratandoSessaoRevogada = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sessão encerrada'),
          content: Text(mensagem),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendi'),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const TelaPortaDeEntrada()),
      (route) => false,
    );
  }

  Future<void> _tratarAcessoAoCasamentoRevogado() async {
    if (!mounted || _tratandoAcessoRevogado) {
      return;
    }

    _tratandoAcessoRevogado = true;
    CasamentoAtualServico.instance.limpar();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Evento indisponível'),
          content: const Text(
            'Este evento foi encerrado ou seu acesso foi removido. '
            'A lista de eventos será atualizada agora.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Entendi'),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const TelaCasamentos()),
      (route) => false,
    );
  }

  Future<void> _tratarEventoFinalizado() async {
    if (!mounted || _tratandoEventoFinalizado) return;
    _tratandoEventoFinalizado = true;

    CasamentoAtualServico.instance.limpar();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const TelaCasamentos(abaInicial: 1)),
      (route) => false,
    );
  }

  void _atualizarEstadoSincronizacao() {
    if (!mounted) {
      return;
    }

    // A sincronização continua acontecendo em tempo real, mas mudanças comuns
    // de status não inserem nem removem elementos do layout. Assim, a lista
    // não se desloca toda vez que um check-in é enviado ao servidor.
    setState(() {});
  }

  bool get _deveMostrarAvisoSincronizacao {
    return _sincronizacao.status == StatusSincronizacao.offline ||
        _sincronizacao.status == StatusSincronizacao.erro;
  }

  Future<void> _sincronizarAgora({
    bool mostrarErroAutomaticamente = false,
  }) async {
    if (_sincronizacao.emAndamento) {
      return;
    }

    final resultado = await _sincronizacao.sincronizarDadosIniciais();

    if (!mounted) {
      return;
    }

    if (!resultado.semConexao &&
        CasamentoAtualServico.instance.casamento != null) {
      try {
        final possuiAcesso = await CasamentoAtualServico.instance
            .confirmarAcessoOnline();
        if (!possuiAcesso) {
          await _tratarAcessoAoCasamentoRevogado();
          return;
        }
      } catch (erro) {
        // Uma falha transitória de rede não deve expulsar quem está usando a
        // cópia offline. O Realtime e a próxima sincronização tentarão de
        // novo quando o servidor estiver acessível.
        debugPrint('Não foi possível confirmar o acesso ao evento: $erro');
      }
    }

    if (resultado.listaFoiRedefinida) {
      if (resultado.operacoesLocaisDescartadas > 0) {
        await _mostrarAvisoListaRedefinida(resultado);

        if (!mounted) {
          return;
        }
      } else {
        _mostrarAvisoRapidoListaAtualizada(resultado.versaoLista);
      }
    }

    if (!resultado.sucesso &&
        !resultado.semConexao &&
        mostrarErroAutomaticamente) {
      await _abrirDetalhesSincronizacao();
    }
  }

  Future<void> _mostrarAvisoListaRedefinida(
    ResultadoSincronizacao resultado,
  ) async {
    final texto = StringBuffer()
      ..writeln(
        'A versão ${resultado.versaoLista} da lista foi baixada e salva por '
        'completo antes de substituir a cópia anterior deste celular.',
      )
      ..writeln()
      ..writeln(
        '${resultado.operacoesLocaisDescartadas} alteração(ões) local(is) '
        'pertenciam à lista anterior e não foram enviadas ao servidor.',
      );

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded),
              SizedBox(width: 10),
              Expanded(child: Text('Lista atualizada')),
            ],
          ),
          content: Text(texto.toString()),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Entendi'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarAvisoRapidoListaAtualizada(int versao) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Lista atualizada para a versão $versao.'),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  Future<void> _aoTocarBarraSincronizacao() async {
    if (_sincronizacao.emAndamento) {
      return;
    }

    if (_sincronizacao.status == StatusSincronizacao.erro) {
      await _abrirDetalhesSincronizacao();
      return;
    }

    await _sincronizarAgora(mostrarErroAutomaticamente: true);
  }

  Future<void> _abrirDetalhesSincronizacao() async {
    if (!mounted) {
      return;
    }

    final mensagem = _sincronizacao.mensagem.trim();
    final erroTecnico = _sincronizacao.ultimoErroTecnico?.trim();
    final ultimaSincronizacao = _sincronizacao.ultimaSincronizacao;

    final detalhesParaCopiar = StringBuffer()
      ..writeln('Status: ${_obterTituloStatusSincronizacao()}')
      ..writeln('Mensagem: $mensagem');

    if (ultimaSincronizacao != null) {
      detalhesParaCopiar.writeln(
        'Última sincronização concluída: '
        '${_formatarDataHora(ultimaSincronizacao.toLocal())}',
      );
    }

    if (erroTecnico != null && erroTecnico.isNotEmpty) {
      detalhesParaCopiar
        ..writeln()
        ..writeln('Detalhes técnicos:')
        ..write(erroTecnico);
    }

    final tentarNovamente = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                _obterIconeSincronizacao(),
                color: _obterCorIconeSincronizacao(),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(_obterTituloStatusSincronizacao())),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 520),
            child: SingleChildScrollView(
              child: SelectableText(detalhesParaCopiar.toString()),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: detalhesParaCopiar.toString()),
                );

                if (!dialogContext.mounted) {
                  return;
                }

                ScaffoldMessenger.of(dialogContext)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(content: Text('Detalhes do erro copiados.')),
                  );
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copiar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Fechar'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        );
      },
    );

    if (tentarNovamente == true && mounted) {
      await _sincronizarAgora(mostrarErroAutomaticamente: true);
    }
  }

  Future<void> _editarEventoAtual() async {
    final evento = CasamentoAtualServico.instance.casamento;
    if (evento == null || !evento.ehAdmin || evento.encerrado) return;

    await mostrarDialogoEdicaoEvento(
      context: context,
      servico: CasamentoAtualServico.instance,
      evento: evento,
    );

    if (mounted) setState(() {});
  }

  String _obterTituloStatusSincronizacao() {
    switch (_sincronizacao.status) {
      case StatusSincronizacao.aguardando:
        return 'Aguardando sincronização';
      case StatusSincronizacao.verificandoConexao:
        return 'Verificando conexão';
      case StatusSincronizacao.sincronizando:
        return 'Sincronizando dados';
      case StatusSincronizacao.concluida:
        return 'Sincronização concluída';
      case StatusSincronizacao.offline:
        return 'Dispositivo offline';
      case StatusSincronizacao.erro:
        return 'Erro de sincronização';
    }
  }

  String _formatarDataHora(DateTime data) {
    String doisDigitos(int valor) => valor.toString().padLeft(2, '0');

    return '${doisDigitos(data.day)}/${doisDigitos(data.month)}/${data.year} '
        '${doisDigitos(data.hour)}:${doisDigitos(data.minute)}:'
        '${doisDigitos(data.second)}';
  }

  Future<void> _abrirConflitos() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TelaConflitos()),
    );
  }

  Widget _construirMenuEvento({
    required bool ehAdmin,
    required bool somenteLeitura,
  }) {
    return StreamBuilder<List<ConflitoSincronizacao>>(
      stream: _streamConflitos,
      builder: (context, snapshot) {
        final quantidade = snapshot.data?.length ?? 0;

        return PopupMenuButton<_AcaoMenuEvento>(
          tooltip: 'Mais opções',
          icon: const Icon(Icons.more_vert),
          onSelected: (acao) {
            switch (acao) {
              case _AcaoMenuEvento.editar:
                unawaited(_editarEventoAtual());
                break;
              case _AcaoMenuEvento.conflitos:
                unawaited(_abrirConflitos());
                break;
              case _AcaoMenuEvento.sair:
                unawaited(_sair());
                break;
            }
          },
          itemBuilder: (_) => [
            if (ehAdmin && !somenteLeitura)
              const PopupMenuItem(
                value: _AcaoMenuEvento.editar,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Editar informações do evento'),
                ),
              ),
            if (!somenteLeitura)
              PopupMenuItem(
                value: _AcaoMenuEvento.conflitos,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    quantidade == 0
                        ? Icons.verified_outlined
                        : Icons.warning_amber_rounded,
                  ),
                  title: Text(
                    quantidade == 0
                        ? 'Conflitos de sincronização'
                        : 'Conflitos de sincronização ($quantidade)',
                  ),
                ),
              ),
            const PopupMenuItem(
              value: _AcaoMenuEvento.sair,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.logout),
                title: Text('Sair do aplicativo'),
              ),
            ),
          ],
        );
      },
    );
  }

  void _abrirMeusCasamentos() {
    FocusManager.instance.primaryFocus?.unfocus();

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const TelaCasamentos()),
    );
  }

  Future<void> _sair() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sair do aplicativo'),
          content: const Text('Deseja voltar para a tela de identificação?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Sair'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !mounted) {
      return;
    }

    await SessaoServico.instance.encerrarSessao();

    if (!mounted) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const TelaPortaDeEntrada()),
    );
  }

  IconData _obterIconeSincronizacao() {
    switch (_sincronizacao.status) {
      case StatusSincronizacao.aguardando:
        return Icons.cloud_queue;

      case StatusSincronizacao.verificandoConexao:
        return Icons.wifi_find;

      case StatusSincronizacao.sincronizando:
        return Icons.sync;

      case StatusSincronizacao.concluida:
        return Icons.cloud_done;

      case StatusSincronizacao.offline:
        return Icons.cloud_off;

      case StatusSincronizacao.erro:
        return Icons.error_outline;
    }
  }

  Color _obterCorFundoSincronizacao() {
    switch (_sincronizacao.status) {
      case StatusSincronizacao.aguardando:
        return Colors.grey.shade200;

      case StatusSincronizacao.verificandoConexao:
        return Colors.blue.shade50;

      case StatusSincronizacao.sincronizando:
        return Colors.blue.shade50;

      case StatusSincronizacao.concluida:
        return Colors.green.shade50;

      case StatusSincronizacao.offline:
        return Colors.orange.shade50;

      case StatusSincronizacao.erro:
        return Colors.red.shade50;
    }
  }

  Color _obterCorIconeSincronizacao() {
    switch (_sincronizacao.status) {
      case StatusSincronizacao.aguardando:
        return Colors.grey.shade700;

      case StatusSincronizacao.verificandoConexao:
        return Colors.blue.shade700;

      case StatusSincronizacao.sincronizando:
        return Colors.blue.shade700;

      case StatusSincronizacao.concluida:
        return Colors.green.shade700;

      case StatusSincronizacao.offline:
        return Colors.orange.shade800;

      case StatusSincronizacao.erro:
        return Colors.red.shade700;
    }
  }

  Widget _construirBotaoSincronizacao() {
    final cor = _obterCorIconeSincronizacao();

    return IconButton(
      tooltip: _sincronizacao.emAndamento
          ? 'Sincronizando...'
          : 'Sincronizar agora',
      onPressed: _sincronizacao.emAndamento
          ? null
          : () => _sincronizarAgora(mostrarErroAutomaticamente: true),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: _sincronizacao.emAndamento
            ? SizedBox(
                key: const ValueKey('sincronizando'),
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: cor),
              )
            : Icon(
                _obterIconeSincronizacao(),
                key: ValueKey(_sincronizacao.status),
                color: cor,
              ),
      ),
    );
  }

  Widget _construirBarraSincronizacao() {
    return Material(
      color: _obterCorFundoSincronizacao(),
      child: InkWell(
        onTap: _sincronizacao.emAndamento ? null : _aoTocarBarraSincronizacao,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              if (_sincronizacao.emAndamento)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _obterCorIconeSincronizacao(),
                  ),
                )
              else
                Icon(
                  _obterIconeSincronizacao(),
                  size: 20,
                  color: _obterCorIconeSincronizacao(),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _sincronizacao.mensagem,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _obterCorIconeSincronizacao(),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!_sincronizacao.emAndamento)
                Icon(
                  Icons.refresh,
                  size: 19,
                  color: _obterCorIconeSincronizacao(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuarioAtual = SessaoServico.instance.usuarioAtual;
    final nomeUsuario = usuarioAtual?.nome ?? 'Não identificado';
    final casamento = CasamentoAtualServico.instance.casamento;
    final ehAdmin = CasamentoAtualServico.instance.ehAdmin;
    final somenteLeitura = CasamentoAtualServico.instance.somenteLeitura;
    final telas = <Widget>[
      const AbaRecepcao(),
      const AbaMesas(),
      if (ehAdmin && !somenteLeitura)
        AbaCadastro(onListaImportada: _abrirAbaRecepcao),
      if (ehAdmin && !somenteLeitura) const AbaEquipe(),
    ];
    final navegacao = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.event_outlined),
        selectedIcon: Icon(Icons.event),
        label: 'Eventos',
      ),
      const NavigationDestination(icon: Icon(Icons.search), label: 'Recepção'),
      const NavigationDestination(
        icon: Icon(Icons.table_restaurant),
        label: 'Mesas',
      ),
      if (ehAdmin && !somenteLeitura)
        const NavigationDestination(
          icon: Icon(Icons.add_circle_outline),
          label: 'Cadastros',
        ),
      if (ehAdmin && !somenteLeitura)
        const NavigationDestination(
          icon: Icon(Icons.groups_outlined),
          label: 'Equipe',
        ),
    ];

    if (_abaSelecionada >= telas.length) {
      _abaSelecionada = 0;
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              casamento?.titulo ?? 'Gestão do Evento',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
            ),
            Text(
              '${ehAdmin ? 'Responsável' : 'Membro da equipe'}'
              '${somenteLeitura ? ' • Somente leitura' : ''}: $nomeUsuario',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          _construirBotaoSincronizacao(),
          _construirMenuEvento(
            ehAdmin: ehAdmin,
            somenteLeitura: somenteLeitura,
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: telas[_abaSelecionada]),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !_deveMostrarAvisoSincronizacao,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                offset: _deveMostrarAvisoSincronizacao
                    ? Offset.zero
                    : const Offset(0, -1),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _deveMostrarAvisoSincronizacao ? 1 : 0,
                  child: _construirBarraSincronizacao(),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _abaSelecionada + 1,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) {
          FocusManager.instance.primaryFocus?.unfocus();

          if (index == 0) {
            _abrirMeusCasamentos();
            return;
          }

          setState(() {
            _abaSelecionada = index - 1;
          });
        },
        destinations: navegacao,
      ),
    );
  }
}
