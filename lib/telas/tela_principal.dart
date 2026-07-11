import 'package:flutter/material.dart';

import '../modelos/modelos.dart';
import '../servicos/sessao_servico.dart';
import '../servicos/supabase_servico.dart';
import '../servicos/sincronizacao_servico.dart';
import 'aba_cadastro.dart';
import 'aba_equipe.dart';
import 'aba_mesas.dart';
import 'aba_recepcao.dart';
import 'porta_entrada.dart';
import 'tela_conflitos.dart';

class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  final SincronizacaoServico _sincronizacao = SincronizacaoServico.instance;
  final SupabaseServico _servico = SupabaseServico();

  late final Stream<List<ConflitoSincronizacao>> _streamConflitos;

  int _abaSelecionada = 0;

  final List<Widget> _telas = [
    const AbaRecepcao(),
    const AbaMesas(),
    const AbaCadastro(),
    const AbaEquipe(),
  ];

  @override
  void initState() {
    super.initState();

    _streamConflitos = _servico.listarConflitosPendentes();

    _sincronizacao.addListener(_atualizarEstadoSincronizacao);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sincronizarAgora();
    });
  }

  @override
  void dispose() {
    _sincronizacao.removeListener(_atualizarEstadoSincronizacao);

    super.dispose();
  }

  void _atualizarEstadoSincronizacao() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  Future<void> _sincronizarAgora() async {
    if (_sincronizacao.emAndamento) {
      return;
    }

    final resultado = await _sincronizacao.sincronizarDadosIniciais();

    if (!mounted) {
      return;
    }

    if (!resultado.sucesso && !resultado.semConexao) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(resultado.mensagem)));
    }
  }

  Future<void> _abrirConflitos() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TelaConflitos()),
    );
  }

  Widget _construirBotaoConflitos() {
    return StreamBuilder<List<ConflitoSincronizacao>>(
      stream: _streamConflitos,
      builder: (context, snapshot) {
        final quantidade = snapshot.data?.length ?? 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              tooltip: quantidade == 0
                  ? 'Nenhum conflito pendente'
                  : '$quantidade conflito(s) pendente(s)',
              onPressed: _abrirConflitos,
              icon: Icon(
                quantidade == 0
                    ? Icons.verified_outlined
                    : Icons.warning_amber_rounded,
              ),
            ),
            if (quantidade > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    quantidade > 99 ? '99+' : quantidade.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
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

    SessaoServico.instance.encerrarSessao();

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

  Widget _construirBarraSincronizacao() {
    return Material(
      color: _obterCorFundoSincronizacao(),
      child: InkWell(
        onTap: _sincronizacao.emAndamento ? null : _sincronizarAgora,
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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Gestão do Casamento', style: TextStyle(fontSize: 19)),
            Text(
              'Usuário: $nomeUsuario',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          _construirBotaoConflitos(),
          IconButton(
            tooltip: 'Sincronizar agora',
            onPressed: _sincronizacao.emAndamento ? null : _sincronizarAgora,
            icon: const Icon(Icons.sync),
          ),
          IconButton(
            tooltip: 'Sair',
            onPressed: _sair,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          _construirBarraSincronizacao(),
          Expanded(child: _telas[_abaSelecionada]),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _abaSelecionada,
        onTap: (index) {
          setState(() {
            _abaSelecionada = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Recepção'),
          BottomNavigationBarItem(
            icon: Icon(Icons.table_restaurant),
            label: 'Mesas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Cadastros',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Equipe'),
        ],
      ),
    );
  }
}
