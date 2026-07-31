import 'package:flutter/material.dart';

import '../servicos/sessao_servico.dart';
import 'tela_casamentos.dart';

class TelaDefinirSenha extends StatefulWidget {
  const TelaDefinirSenha({
    super.key,
    this.recuperacao = false,
    this.funcionario = false,
  });

  final bool recuperacao;
  final bool funcionario;

  @override
  State<TelaDefinirSenha> createState() => _TelaDefinirSenhaState();
}

class _TelaDefinirSenhaState extends State<TelaDefinirSenha> {
  final _formKey = GlobalKey<FormState>();
  final _senha = TextEditingController();
  final _confirmacao = TextEditingController();
  bool _salvando = false;
  bool _ocultarSenha = true;
  String? _erro;

  @override
  void dispose() {
    _senha.dispose();
    _confirmacao.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await SessaoServico.instance.definirSenhaInicial(_senha.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const TelaCasamentos()),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _erro = 'Não foi possível salvar a senha. Tente novamente.';
        });
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titulo = widget.recuperacao
        ? 'Crie uma nova senha'
        : widget.funcionario
        ? 'Criar acesso de funcionário'
        : 'Defina sua senha';
    final descricao = widget.recuperacao
        ? 'Escolha uma nova senha para voltar a acessar sua conta.'
        : widget.funcionario
        ? 'Você foi convidado para ajudar em um casamento. Crie sua senha para concluir seu acesso como funcionário.'
        : 'Para concluir o convite, crie uma senha para seu acesso.';

    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.lock_reset_outlined,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      titulo,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      descricao,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _senha,
                      obscureText: _ocultarSenha,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Nova senha',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _ocultarSenha
                              ? 'Mostrar senha'
                              : 'Ocultar senha',
                          icon: Icon(
                            _ocultarSenha
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () =>
                              setState(() => _ocultarSenha = !_ocultarSenha),
                        ),
                      ),
                      validator: (valor) => (valor?.length ?? 0) >= 6
                          ? null
                          : 'Use pelo menos 6 caracteres.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmacao,
                      obscureText: _ocultarSenha,
                      onFieldSubmitted: (_) => _salvar(),
                      decoration: const InputDecoration(
                        labelText: 'Confirmar nova senha',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (valor) => valor == _senha.text
                          ? null
                          : 'As senhas não são iguais.',
                    ),
                    if (_erro != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _erro!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _salvando ? null : _salvar,
                        icon: _salvando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(_salvando ? 'Salvando...' : 'Salvar senha'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
