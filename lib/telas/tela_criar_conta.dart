import 'package:flutter/material.dart';

import '../servicos/sessao_servico.dart';

class TelaCriarConta extends StatefulWidget {
  const TelaCriarConta({super.key});

  @override
  State<TelaCriarConta> createState() => _TelaCriarContaState();
}

class _TelaCriarContaState extends State<TelaCriarConta> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmacaoController = TextEditingController();

  bool _criando = false;
  bool _ocultarSenha = true;
  String? _erro;

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _confirmacaoController.dispose();
    super.dispose();
  }

  Future<void> _criarConta() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _criando = true;
      _erro = null;
    });

    try {
      await SessaoServico.instance.criarConta(
        nome: _nomeController.text,
        email: _emailController.text,
        senha: _senhaController.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (erro) {
      if (!mounted) return;
      setState(() {
        _erro =
            'Não foi possível criar a conta. Verifique os dados e tente novamente.';
      });
    } finally {
      if (mounted) setState(() => _criando = false);
    }
  }

  Future<void> _entrarComGoogle() async {
    setState(() {
      _criando = true;
      _erro = null;
    });

    try {
      await SessaoServico.instance.entrarComGoogle();
    } catch (_) {
      if (mounted) {
        setState(() {
          _erro = 'Não foi possível abrir o login com Google agora.';
        });
      }
    } finally {
      if (mounted) setState(() => _criando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Crie sua conta grátis',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Você será a administradora dos seus casamentos e da sua equipe.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 24),
                    _botaoGoogle(),
                    const SizedBox(height: 20),
                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('ou crie com e-mail'),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _campo(
                      controller: _nomeController,
                      label: 'Seu nome',
                      icone: Icons.person_outline,
                    ),
                    const SizedBox(height: 16),
                    _campo(
                      controller: _emailController,
                      label: 'E-mail',
                      icone: Icons.email_outlined,
                      teclado: TextInputType.emailAddress,
                      validador: (valor) => (valor?.contains('@') ?? false)
                          ? null
                          : 'Digite um e-mail válido.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _senhaController,
                      obscureText: _ocultarSenha,
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _ocultarSenha
                              ? 'Mostrar senha'
                              : 'Ocultar senha',
                          onPressed: () =>
                              setState(() => _ocultarSenha = !_ocultarSenha),
                          icon: Icon(
                            _ocultarSenha
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                      validator: (valor) => (valor?.length ?? 0) >= 6
                          ? null
                          : 'Use pelo menos 6 caracteres.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmacaoController,
                      obscureText: _ocultarSenha,
                      decoration: const InputDecoration(
                        labelText: 'Confirmar senha',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (valor) => valor == _senhaController.text
                          ? null
                          : 'As senhas não são iguais.',
                    ),
                    if (_erro != null) ...[
                      const SizedBox(height: 14),
                      Text(_erro!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _criando ? null : _criarConta,
                        icon: _criando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(
                          _criando ? 'Criando conta...' : 'Criar conta grátis',
                        ),
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

  Widget _campo({
    required TextEditingController controller,
    required String label,
    required IconData icone,
    TextInputType? teclado,
    String? Function(String?)? validador,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: teclado,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icone),
        border: const OutlineInputBorder(),
      ),
      validator:
          validador ??
          (valor) => (valor?.trim().isNotEmpty ?? false)
              ? null
              : 'Preencha este campo.',
    );
  }

  Widget _botaoGoogle() {
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        onPressed: _criando ? null : _entrarComGoogle,
        icon: const Text(
          'G',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4285F4),
          ),
        ),
        label: const Text('Continuar com Google'),
      ),
    );
  }
}
