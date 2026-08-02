import 'package:flutter/material.dart';

import '../servicos/equipe_servico.dart';

class AbaEquipe extends StatefulWidget {
  const AbaEquipe({super.key});

  @override
  State<AbaEquipe> createState() => _AbaEquipeState();
}

class _AbaEquipeState extends State<AbaEquipe> {
  final EquipeServico _servico = EquipeServico.instance;
  final TextEditingController _busca = TextEditingController();
  late Stream<List<MembroEquipe>> _equipeEmTempoReal;

  @override
  void initState() {
    super.initState();
    _equipeEmTempoReal = _servico.listarEmTempoReal();
  }

  void _recarregar() =>
      setState(() => _equipeEmTempoReal = _servico.listarEmTempoReal());

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<void> _mostrarMensagem({
    required String titulo,
    required String mensagem,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(titulo),
        content: Text(mensagem),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _convidar() async {
    final resultado = await showDialog<ResultadoConviteFuncionario>(
      context: context,
      builder: (_) => _DialogConvidarFuncionario(servico: _servico),
    );
    if (resultado == null || !mounted) return;

    _recarregar();

    final mensagem = resultado.contaMista
        ? 'Este e-mail já pertencia a um cerimonialista. O perfil de '
              'funcionário foi adicionado à mesma conta, sem alterar a senha.'
        : resultado.notificacaoEnviada
            ? 'Convite enviado com sucesso. A pessoa receberá o acesso por e-mail.'
            : resultado.mensagemNotificacao ??
                  (resultado.conviteEnviado
                      ? 'A conta foi preparada, mas não foi possível enviar o e-mail.'
                      : 'O acesso foi liberado, mas não foi possível enviar o e-mail.');

    await _mostrarMensagem(
      titulo: resultado.contaMista
          ? 'Conta mista criada'
          : resultado.notificacaoEnviada
              ? 'Convite enviado'
              : 'Acesso liberado',
      mensagem: mensagem,
    );
  }

  Future<void> _desativar(MembroEquipe membro) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover acesso?'),
        content: Text('${membro.nome} não poderá mais acessar este casamento.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmar != true) {
      return;
    }
    try {
      await _servico.desativar(membro);
      _recarregar();
      if (mounted) {
        await _mostrarMensagem(
          titulo: 'Acesso removido',
          mensagem:
              '${membro.nome} não pode mais acessar este casamento.',
        );
      }
    } catch (erro) {
      if (mounted) {
        await _mostrarMensagem(
          titulo: 'Não foi possível remover',
          mensagem: erro.toString(),
        );
      }
    }
  }

  Future<void> _convidarParaEsteCasamento(MembroEquipe membro) async {
    try {
      final resultado = await _servico.convidarParaEsteCasamento(membro);
      _recarregar();
      if (!mounted) return;

      await _mostrarMensagem(
        titulo: resultado.notificacaoEnviada
            ? 'Convite enviado'
            : 'Acesso liberado',
        mensagem: resultado.contaMista
            ? '${membro.nome} continuará usando a mesma conta como '
                  'cerimonialista e funcionário.'
            : resultado.notificacaoEnviada
                ? '${membro.nome} foi convidado e recebeu um e-mail.'
                : resultado.mensagemNotificacao ??
                      '${membro.nome} foi incluído neste casamento, mas o '
                          'e-mail não pôde ser enviado.',
      );
    } catch (erro) {
      if (mounted) {
        await _mostrarMensagem(
          titulo: 'Não foi possível incluir',
          mensagem: erro.toString(),
        );
      }
    }
  }

  Future<void> _removerDaEquipe(MembroEquipe membro) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir funcionário da equipe?'),
        content: Text(
          '${membro.nome} será removido da sua lista e perderá acesso a todos '
          'os seus casamentos. A conta da pessoa não será apagada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await _servico.removerDaEquipe(membro);
      _recarregar();
      if (mounted) {
        await _mostrarMensagem(
          titulo: 'Funcionário removido',
          mensagem: '${membro.nome} foi removido da equipe.',
        );
      }
    } catch (erro) {
      if (mounted) {
        await _mostrarMensagem(
          titulo: 'Não foi possível excluir',
          mensagem: erro.toString(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _convidar,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Adicionar funcionário'),
      ),
      body: StreamBuilder<List<MembroEquipe>>(
        stream: _equipeEmTempoReal,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Não foi possível carregar a equipe: ${snapshot.error}',
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final todosOsMembros = snapshot.data!;
          if (todosOsMembros.isEmpty) {
            return const Center(
              child: Text('Nenhum funcionário cadastrado na sua equipe ainda.'),
            );
          }
          final termo = _busca.text.trim().toLowerCase();
          final membros = todosOsMembros
              .where(
                (membro) =>
                    termo.isEmpty ||
                    membro.nome.toLowerCase().contains(termo) ||
                    (membro.email?.toLowerCase().contains(termo) ?? false),
              )
              .toList();
          return RefreshIndicator(
            onRefresh: () async => _recarregar(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 92),
              itemCount: membros.isEmpty ? 2 : membros.length + 1,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: _busca,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Buscar funcionário',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  );
                }
                if (membros.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('Nenhum funcionário encontrado.'),
                    ),
                  );
                }
                final membro = membros[index - 1];
                return ListTile(
                  leading: CircleAvatar(
                    child: const Icon(Icons.badge_outlined),
                  ),
                  title: Text(membro.nome),
                  subtitle: Text(
                    '${membro.email ?? 'Funcionário'} • ${_statusDoMembro(membro)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (membro.convidadoParaEsteCasamento)
                        IconButton(
                          tooltip: 'Remover acesso deste casamento',
                          icon: const Icon(Icons.person_remove_outlined),
                          onPressed: () => _desativar(membro),
                        )
                      else
                        FilledButton(
                          onPressed: () => _convidarParaEsteCasamento(membro),
                          child: const Text('Convidar'),
                        ),
                      PopupMenuButton<String>(
                        tooltip: 'Opções do funcionário',
                        onSelected: (acao) {
                          if (acao == 'excluir') _removerDaEquipe(membro);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'excluir',
                            child: Text('Excluir da equipe'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _statusDoMembro(MembroEquipe membro) {
    if (!membro.convidadoParaEsteCasamento) {
      return 'sem acesso a este casamento';
    }
    return membro.conviteAceito ? 'convite aceito' : 'aguardando aceite';
  }
}

class _DialogConvidarFuncionario extends StatefulWidget {
  final EquipeServico servico;
  const _DialogConvidarFuncionario({required this.servico});

  @override
  State<_DialogConvidarFuncionario> createState() =>
      _DialogConvidarFuncionarioState();
}

class _DialogConvidarFuncionarioState
    extends State<_DialogConvidarFuncionario> {
  final _formKey = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _enviando = true);
    try {
      final resultado = await widget.servico.convidarFuncionario(
        nome: _nome.text,
        email: _email.text,
      );
      if (mounted) {
        Navigator.pop(context, resultado);
      }
    } catch (erro) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Não foi possível enviar'),
            content: Text(erro.toString()),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _enviando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar funcionário'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nome,
              decoration: const InputDecoration(
                labelText: 'Nome',
                border: OutlineInputBorder(),
              ),
              validator: (valor) => (valor?.trim().isNotEmpty ?? false)
                  ? null
                  : 'Informe o nome.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                border: OutlineInputBorder(),
              ),
              validator: (valor) => valor?.contains('@') ?? false
                  ? null
                  : 'Informe um e-mail válido.',
            ),
            const SizedBox(height: 12),
            const Text(
              'A pessoa entrará na sua equipe e receberá acesso a este casamento.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _enviando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _enviando ? null : _enviar,
          child: Text(_enviando ? 'Enviando...' : 'Enviar convite'),
        ),
      ],
    );
  }
}
