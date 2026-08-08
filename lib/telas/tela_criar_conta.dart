import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../servicos/casamento_atual_servico.dart';
import '../servicos/sessao_servico.dart';

class TelaCriarConta extends StatefulWidget {
  const TelaCriarConta({super.key});

  @override
  State<TelaCriarConta> createState() => _TelaCriarContaState();
}

class _TelaCriarContaState extends State<TelaCriarConta>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmacaoController = TextEditingController();

  bool _criando = false;
  bool _ocultarSenha = true;
  bool _aguardandoRetornoGoogle = false;
  bool _loginGoogleEmAndamento = false;
  String? _erro;

  StreamSubscription<AuthState>? _mudancasAutenticacao;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mudancasAutenticacao = Supabase.instance.client.auth.onAuthStateChange
        .listen((estado) {
          if (_loginGoogleEmAndamento &&
              (estado.event == AuthChangeEvent.signedIn ||
                  estado.event == AuthChangeEvent.userUpdated)) {
            unawaited(_aguardarCriacaoGoogle());
          }
        });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed ||
        !_criando ||
        !_loginGoogleEmAndamento) {
      return;
    }

    if (SessaoServico.instance.possuiSessaoLocal) {
      unawaited(_aguardarCriacaoGoogle());
    } else {
      _loginGoogleEmAndamento = false;
      setState(() => _criando = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mudancasAutenticacao?.cancel();
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
      final resultado =
          await SessaoServico.instance.prepararContaCerimonialista(
        nome: _nomeController.text,
        email: _emailController.text,
        senha: _senhaController.text,
      );

      if (!mounted) return;

      switch (resultado.situacao) {
        case SituacaoContaCerimonialista.novaConta:
          await _mostrarMensagem(
            titulo: 'Conta criada',
            mensagem:
                'Seu perfil de cerimonialista foi criado com sucesso.',
          );
          if (mounted) Navigator.pop(context);
          return;

        case SituacaoContaCerimonialista.confirmacaoEmailPendente:
          await _mostrarMensagem(
            titulo: 'Confirme seu e-mail',
            mensagem:
                'Enviamos uma mensagem para ${_emailController.text.trim()}. '
                'Abra o e-mail e confirme seu cadastro para continuar.',
          );
          if (mounted) Navigator.pop(context);
          return;

        case SituacaoContaCerimonialista
              .contaExistenteSemPerfilCerimonialista:
          await _mostrarMensagem(
            titulo: 'E-mail já cadastrado',
            mensagem:
                'Este e-mail já está cadastrado no sistema. Entre na conta '
                'existente e habilite a conta de cerimonialista pelo seu '
                'perfil, quando desejar.',
          );
          if (mounted) Navigator.pop(context);
          return;
      }
    } on AuthException catch (erro) {
      if (!mounted) return;
      setState(() => _erro = _mensagemAuth(erro));
    } catch (erro) {
      if (!mounted) return;
      setState(() {
        _erro =
            'Não foi possível criar ou atualizar a conta. Tente novamente.';
      });
    } finally {
      if (mounted) setState(() => _criando = false);
    }
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

  String _mensagemAuth(AuthException erro) {
    final mensagem = erro.message.toLowerCase();
    if (mensagem.contains('password')) {
      return 'A senha informada não atende aos requisitos de segurança.';
    }
    if (mensagem.contains('email')) {
      return 'Não foi possível validar este e-mail. Confira o endereço informado.';
    }
    return 'Não foi possível concluir o cadastro. ${erro.message}';
  }

  Future<void> _entrarComGoogle() async {
    setState(() {
      _criando = true;
      _loginGoogleEmAndamento = true;
      _erro = null;
    });

    try {
      await SessaoServico.instance.entrarComGoogle(
        solicitarPerfilCerimonialista: true,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _erro = 'Não foi possível abrir o login com Google agora.';
          _criando = false;
          _loginGoogleEmAndamento = false;
        });
      }
    }
  }

  Future<void> _aguardarCriacaoGoogle() async {
    if (!mounted ||
        !_loginGoogleEmAndamento ||
        _aguardandoRetornoGoogle) {
      return;
    }
    _aguardandoRetornoGoogle = true;

    try {
      for (var tentativa = 0; tentativa < 20; tentativa++) {
        if (!mounted) return;

        if (!SessaoServico.instance.possuiSessaoLocal) {
          if (tentativa == 0) {
            await Future<void>.delayed(const Duration(milliseconds: 300));
            continue;
          }
          _loginGoogleEmAndamento = false;
          if (mounted) setState(() => _criando = false);
          return;
        }

        try {
          final papeis = await CasamentoAtualServico.instance
              .obterPapeisContaAtual();
          final fluxoAindaPendente = await SessaoServico.instance
              .possuiPerfilCerimonialistaGooglePendente();

          if (papeis.cerimonialista || !fluxoAindaPendente) {
            _loginGoogleEmAndamento = false;
            if (mounted) setState(() => _criando = false);
            return;
          }
        } catch (_) {
          // O fluxo principal da porta de entrada ainda pode estar concluindo
          // o RPC. A próxima tentativa verifica novamente sem liberar cliques.
        }

        await Future<void>.delayed(const Duration(milliseconds: 300));
      }

      if (mounted) {
        _loginGoogleEmAndamento = false;
        setState(() {
          _criando = false;
          _erro =
              'A criação da conta ainda não foi confirmada. Tente novamente.';
        });
      }
    } finally {
      _aguardandoRetornoGoogle = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_criando,
      child: Scaffold(
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
                      'Você será a administradora dos seus eventos e da sua equipe.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 24),
                    if (_criando) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 16),
                    ],
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
                      validator: (valor) =>
                          valor?.trim() == _senhaController.text.trim()
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
