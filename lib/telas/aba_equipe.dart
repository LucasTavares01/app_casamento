import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../servicos/casamento_atual_servico.dart';
import '../servicos/equipe_servico.dart';

enum _AcaoMembroEquipe { convidar, remover, excluir }

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

    if (resultado.linkWhatsApp != null &&
        resultado.telefoneWhatsApp != null &&
        await _perguntarEnviarWhatsApp()) {
      await _abrirWhatsApp(
        telefone: resultado.telefoneWhatsApp!,
        linkConvite: resultado.linkWhatsApp!,
      );
    }

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
          mensagem: '${membro.nome} não pode mais acessar este casamento.',
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

      if (resultado.linkWhatsApp != null &&
          resultado.telefoneWhatsApp != null &&
          await _perguntarEnviarWhatsApp()) {
        await _abrirWhatsApp(
          telefone: resultado.telefoneWhatsApp!,
          linkConvite: resultado.linkWhatsApp!,
        );
      }

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

  Future<bool> _perguntarEnviarWhatsApp() async {
    final enviar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enviar também pelo WhatsApp?'),
        content: const Text(
          'Deseja abrir o WhatsApp com a mensagem e o link seguro do convite?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Agora não'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.chat_outlined),
            label: const Text('Abrir WhatsApp'),
          ),
        ],
      ),
    );
    return enviar == true;
  }

  Future<void> _abrirWhatsApp({
    required String telefone,
    required String linkConvite,
  }) async {
    final evento =
        CasamentoAtualServico.instance.casamento?.titulo ?? 'seu evento';
    final mensagem = Uri.encodeComponent(
      'Você foi convidado para participar da equipe do evento '
      '"$evento" no ConfirmaAi.\n\n'
      'Acesse o convite por este link seguro:\n$linkConvite',
    );
    final uri = Uri.parse('https://wa.me/$telefone?text=$mensagem');
    final abriu = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!abriu && mounted) {
      await _mostrarMensagem(
        titulo: 'Não foi possível abrir o WhatsApp',
        mensagem:
            'O convite continua disponível por e-mail. Verifique se o '
            'WhatsApp está instalado neste aparelho.',
      );
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

  Future<void> _mostrarDetalhesMembro(MembroEquipe membro) async {
    final resultado = await showDialog<_ResultadoDialogMembro>(
      context: context,
      builder: (_) => _DialogMembroEquipe(membro: membro),
      barrierDismissible: true,
    );

    if (!mounted || resultado == null) {
      return;
    }

    try {
      if (resultado.salvar) {
        await _servico.atualizarDadosFuncionario(
          membro: membro,
          nome: resultado.nome,
          email: resultado.email,
          telefone: _normalizarTelefone(resultado.telefone),
        );
        _recarregar();
      }

      switch (resultado.acao) {
        case null:
          if (resultado.salvar && mounted) {
            await _mostrarMensagem(
              titulo: 'Dados atualizados',
              mensagem: 'Os dados de ${resultado.nome} foram atualizados.',
            );
          }
        case _AcaoMembroEquipe.convidar:
          await _convidarParaEsteCasamento(membro);
        case _AcaoMembroEquipe.remover:
          await _desativar(membro);
        case _AcaoMembroEquipe.excluir:
          await _removerDaEquipe(membro);
      }
    } catch (erro) {
      if (mounted) {
        await _mostrarMensagem(
          titulo: 'Não foi possível atualizar',
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
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      leading: const CircleAvatar(
                        child: Icon(Icons.badge_outlined),
                      ),
                      title: Text(
                        membro.nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: Text(
                        _statusDoMembro(membro),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _corDoStatus(context, membro),
                        ),
                      ),
                      trailing: IconButton(
                        tooltip: membro.convidadoParaEsteCasamento
                            ? 'Remover deste evento'
                            : 'Convidar para este evento',
                        icon: Icon(
                          membro.convidadoParaEsteCasamento
                              ? Icons.person_remove_outlined
                              : Icons.person_add_alt_1,
                        ),
                        onPressed: membro.convidadoParaEsteCasamento
                            ? () => _desativar(membro)
                            : () => _convidarParaEsteCasamento(membro),
                      ),
                      onTap: () => _mostrarDetalhesMembro(membro),
                    ),
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
      return 'Não convidado';
    }
    return membro.conviteAceito ? 'Aceito' : 'Aguardando aceite';
  }

  Color _corDoStatus(BuildContext context, MembroEquipe membro) {
    if (!membro.convidadoParaEsteCasamento) {
      return Theme.of(context).colorScheme.onSurfaceVariant;
    }
    return membro.conviteAceito
        ? Colors.green.shade700
        : Theme.of(context).colorScheme.primary;
  }

  String? _normalizarTelefone(String valor) {
    final digitos = valor.replaceAll(RegExp(r'\D'), '');
    if (digitos.isEmpty) return null;
    final comCodigo = digitos.startsWith('55') ? digitos : '55$digitos';
    if (comCodigo.length != 12 && comCodigo.length != 13) return null;
    return comCodigo;
  }
}

class _ResultadoDialogMembro {
  final String nome;
  final String email;
  final String telefone;
  final bool salvar;
  final _AcaoMembroEquipe? acao;

  const _ResultadoDialogMembro({
    required this.nome,
    required this.email,
    required this.telefone,
    required this.salvar,
    required this.acao,
  });
}

enum _DecisaoEdicao { salvar, descartar }

class _DialogMembroEquipe extends StatefulWidget {
  final MembroEquipe membro;

  const _DialogMembroEquipe({required this.membro});

  @override
  State<_DialogMembroEquipe> createState() => _DialogMembroEquipeState();
}

class _DialogMembroEquipeState extends State<_DialogMembroEquipe> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nome;
  late final TextEditingController _email;
  late final TextEditingController _telefone;
  bool _processandoSaida = false;

  MembroEquipe get _membro => widget.membro;

  bool get _possuiAlteracoes =>
      _nome.text.trim() != _membro.nome.trim() ||
      _email.text.trim().toLowerCase() !=
          (_membro.email ?? '').trim().toLowerCase() ||
      _telefone.text.trim() != (_membro.telefone ?? '').trim();

  @override
  void initState() {
    super.initState();
    _nome = TextEditingController(text: _membro.nome);
    _email = TextEditingController(text: _membro.email ?? '');
    _telefone = TextEditingController(text: _membro.telefone ?? '');
    _nome.addListener(_atualizarEstadoDoFormulario);
    _email.addListener(_atualizarEstadoDoFormulario);
    _telefone.addListener(_atualizarEstadoDoFormulario);
  }

  @override
  void dispose() {
    _nome.removeListener(_atualizarEstadoDoFormulario);
    _email.removeListener(_atualizarEstadoDoFormulario);
    _telefone.removeListener(_atualizarEstadoDoFormulario);
    _nome.dispose();
    _email.dispose();
    _telefone.dispose();
    super.dispose();
  }

  void _atualizarEstadoDoFormulario() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _sair([_AcaoMembroEquipe? acao]) async {
    if (_processandoSaida) {
      return;
    }

    if (!_possuiAlteracoes) {
      _fechar(salvar: false, acao: acao);
      return;
    }

    setState(() => _processandoSaida = true);
    final decisao = await showDialog<_DecisaoEdicao>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Salvar alterações?'),
          content: Text(
            acao == null
                ? 'Você alterou os dados deste funcionário. Deseja salvar antes de fechar?'
                : 'Você alterou os dados deste funcionário. Deseja salvar antes de continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Continuar editando'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _DecisaoEdicao.descartar),
              child: const Text('Descartar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _DecisaoEdicao.salvar),
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
    if (!mounted) {
      return;
    }
    setState(() => _processandoSaida = false);

    if (decisao == null) {
      return;
    }
    if (decisao == _DecisaoEdicao.salvar &&
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    _fechar(salvar: decisao == _DecisaoEdicao.salvar, acao: acao);
  }

  void _fechar({required bool salvar, required _AcaoMembroEquipe? acao}) {
    Navigator.pop(
      context,
      _ResultadoDialogMembro(
        nome: _nome.text.trim(),
        email: _email.text.trim(),
        telefone: _telefone.text.trim(),
        salvar: salvar,
        acao: acao,
      ),
    );
  }

  void _salvarEFechar() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    _fechar(salvar: true, acao: null);
  }

  @override
  Widget build(BuildContext context) {
    final alturaMaxima = MediaQuery.sizeOf(context).height * 0.82;
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(_sair());
        }
      },
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: alturaMaxima),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Dados do funcionário',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _nome,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nome',
                      border: OutlineInputBorder(),
                    ),
                    validator: (valor) => (valor?.trim().length ?? 0) >= 2
                        ? null
                        : 'Informe um nome válido.',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      border: OutlineInputBorder(),
                    ),
                    validator: (valor) {
                      final email = valor?.trim() ?? '';
                      final telefone = _normalizarTelefone(_telefone.text);
                      if (email.isEmpty && telefone == null) {
                        return 'Informe um e-mail ou um WhatsApp.';
                      }
                      if (email.isNotEmpty && !email.contains('@')) {
                        return 'Informe um e-mail válido.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _telefone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'WhatsApp (opcional)',
                      hintText: 'DDD + número',
                      prefixIcon: Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (valor) {
                      final telefone = _normalizarTelefone(valor ?? '');
                      if ((valor ?? '').trim().isEmpty || telefone != null) {
                        return null;
                      }
                      return 'Informe DDD e número válidos.';
                    },
                  ),
                  const SizedBox(height: 14),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    child: Text(_statusDoMembro(_membro)),
                  ),
                  const SizedBox(height: 20),
                  if (!_membro.convidadoParaEsteCasamento)
                    FilledButton.icon(
                      onPressed: _processandoSaida
                          ? null
                          : () => _sair(_AcaoMembroEquipe.convidar),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Convidar para este evento'),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: _processandoSaida
                          ? null
                          : () => _sair(_AcaoMembroEquipe.remover),
                      icon: const Icon(Icons.person_remove_outlined),
                      label: const Text('Remover deste evento'),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _processandoSaida
                        ? null
                        : () => _sair(_AcaoMembroEquipe.excluir),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Excluir da equipe'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _processandoSaida
                        ? null
                        : _possuiAlteracoes
                        ? _salvarEFechar
                        : _sair,
                    child: Text(
                      _possuiAlteracoes ? 'Salvar e fechar' : 'Fechar',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _statusDoMembro(MembroEquipe membro) {
    if (!membro.convidadoParaEsteCasamento) {
      return 'Não convidado';
    }
    return membro.conviteAceito ? 'Aceito' : 'Aguardando aceite';
  }

  String? _normalizarTelefone(String valor) {
    final digitos = valor.replaceAll(RegExp(r'\D'), '');
    if (digitos.isEmpty) return null;
    final comCodigo = digitos.startsWith('55') ? digitos : '55$digitos';
    if (comCodigo.length != 12 && comCodigo.length != 13) return null;
    return comCodigo;
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
  final _telefone = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _telefone.dispose();
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
        telefone: _telefone.text,
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
      scrollable: true,
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
              validator: (valor) {
                final email = valor?.trim() ?? '';
                final telefone = _normalizarTelefone(_telefone.text);
                if (email.isEmpty && telefone == null) {
                  return 'Informe um e-mail ou um WhatsApp.';
                }
                if (email.isNotEmpty && !email.contains('@')) {
                  return 'Informe um e-mail válido.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _telefone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'WhatsApp (opcional)',
                hintText: 'DDD + número',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (valor) {
                final telefone = _normalizarTelefone(valor ?? '');
                if ((valor ?? '').trim().isEmpty || telefone != null) {
                  return null;
                }
                return 'Informe DDD e número válidos.';
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'Informe pelo menos um contato. O e-mail envia o convite por '
              'e-mail; o WhatsApp abre uma mensagem pronta com o link seguro.',
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

  String? _normalizarTelefone(String valor) {
    final digitos = valor.replaceAll(RegExp(r'\D'), '');
    if (digitos.isEmpty) return null;
    final comCodigo = digitos.startsWith('55') ? digitos : '55$digitos';
    if (comCodigo.length != 12 && comCodigo.length != 13) return null;
    return comCodigo;
  }
}
