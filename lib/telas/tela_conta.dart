import 'package:flutter/material.dart';

import '../servicos/casamento_atual_servico.dart';
import '../servicos/sessao_servico.dart';
import 'porta_entrada.dart';

class TelaConta extends StatefulWidget {
  const TelaConta({super.key});

  @override
  State<TelaConta> createState() => _TelaContaState();
}

class _TelaContaState extends State<TelaConta> {
  late final TextEditingController _nome;
  late final TextEditingController _email;
  PapeisContaAtual? _papeis;
  bool _salvando = false;
  bool _habilitando = false;

  @override
  void initState() {
    super.initState();
    _nome = TextEditingController(text: SessaoServico.instance.nomeExibicaoAtual);
    _email = TextEditingController(text: SessaoServico.instance.emailAtual);
    _carregarPapeis();
  }

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _carregarPapeis() async {
    try {
      final papeis = await CasamentoAtualServico.instance.obterPapeisContaAtual();
      if (mounted) setState(() => _papeis = papeis);
    } catch (_) {
      if (mounted) setState(() => _papeis = null);
    }
  }

  Future<void> _salvarPerfil() async {
    final nome = _nome.text.trim();
    if (nome.length < 2) {
      _mostrarMensagem('Informe um nome válido.');
      return;
    }

    setState(() => _salvando = true);
    try {
      await SessaoServico.instance.atualizarPerfil(nome: nome);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil atualizado em todas as contas.')),
      );
    } catch (erro) {
      _mostrarMensagem('Não foi possível atualizar o perfil: $erro');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _habilitarCerimonialista() async {
    if (_habilitando) return;
    setState(() => _habilitando = true);
    try {
      await SessaoServico.instance.habilitarPerfilCerimonialista(
        nome: _nome.text,
      );
      await _carregarPapeis();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conta de cerimonialista habilitada.')),
      );
    } catch (erro) {
      _mostrarMensagem('Não foi possível habilitar a conta: $erro');
    } finally {
      if (mounted) setState(() => _habilitando = false);
    }
  }

  void _mostrarMensagem(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensagem)));
  }

  Future<void> _trocarConta(BuildContext context) async {
    await SessaoServico.instance.encerrarSessao();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const TelaPortaDeEntrada()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final nome = SessaoServico.instance.nomeExibicaoAtual;
    final email = SessaoServico.instance.emailAtual;

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações da conta')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      child: Text(
                        nome.isEmpty ? '?' : nome.substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nome.isEmpty ? 'Sua conta' : nome,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email.isEmpty ? 'E-mail não identificado' : email,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Informações pessoais',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  children: [
                    TextField(
                      controller: _nome,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nome',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _email,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _salvando ? null : _salvarPerfil,
                        icon: _salvando
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined),
                        label: const Text('Salvar alterações'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Perfis de acesso',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _construirPerfis(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Sessão', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.switch_account_outlined),
                title: const Text('Trocar de conta'),
                subtitle: const Text('Sair para entrar ou criar outra conta.'),
                onTap: () => _trocarConta(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirPerfis() {
    final papeis = _papeis;
    if (papeis == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _linhaPerfil(
          icone: Icons.badge_outlined,
          titulo: 'Funcionário',
          ativo: papeis.funcionario,
          descricao: papeis.funcionario
              ? 'Acesso aos casamentos para os quais você foi convidado.'
              : 'Disponível quando uma cerimonialista enviar um convite.',
        ),
        const Divider(height: 24),
        _linhaPerfil(
          icone: Icons.favorite_outline,
          titulo: 'Cerimonialista',
          ativo: papeis.cerimonialista,
          descricao: papeis.cerimonialista
              ? 'Você pode criar e administrar seus casamentos.'
              : 'Habilite este perfil para criar e administrar casamentos.',
        ),
        if (!papeis.cerimonialista) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _habilitando ? null : _habilitarCerimonialista,
              icon: _habilitando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_open_outlined),
              label: const Text('Habilitar conta de cerimonialista'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _linhaPerfil({
    required IconData icone,
    required String titulo,
    required bool ativo,
    required String descricao,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, color: ativo ? null : Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(titulo,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  Icon(
                    ativo ? Icons.check_circle : Icons.circle_outlined,
                    size: 19,
                    color: ativo ? Colors.green : Colors.grey,
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(descricao),
            ],
          ),
        ),
      ],
    );
  }
}
