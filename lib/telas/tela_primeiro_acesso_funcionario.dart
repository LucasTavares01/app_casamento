import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../servicos/sessao_servico.dart';
import 'tela_casamentos.dart';

class TelaPrimeiroAcessoFuncionario extends StatefulWidget {
  const TelaPrimeiroAcessoFuncionario({super.key});

  @override
  State<TelaPrimeiroAcessoFuncionario> createState() =>
      _TelaPrimeiroAcessoFuncionarioState();
}

class _TelaPrimeiroAcessoFuncionarioState
    extends State<TelaPrimeiroAcessoFuncionario>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _senhaController = TextEditingController();
  final _confirmacaoController = TextEditingController();

  StreamSubscription<AuthState>? _mudancasAutenticacao;
  bool _processando = false;
  bool _abrindoProximaTela = false;
  bool _ocultarSenha = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mudancasAutenticacao = Supabase.instance.client.auth.onAuthStateChange
        .listen((estado) {
          if (estado.event == AuthChangeEvent.signedIn ||
              estado.event == AuthChangeEvent.userUpdated) {
            unawaited(_tentarConcluirGoogle(silencioso: true));
          }
        });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_tentarConcluirGoogle(silencioso: true));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_tentarConcluirGoogle(silencioso: false));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mudancasAutenticacao?.cancel();
    _senhaController.dispose();
    _confirmacaoController.dispose();
    super.dispose();
  }

  Future<void> _vincularGoogle() async {
    if (_processando) return;

    setState(() {
      _processando = true;
      _erro = null;
    });

    try {
      await SessaoServico.instance.vincularGoogleAoConvite();
    } on AuthException catch (erro) {
      if (!mounted) return;
      setState(() => _erro = _mensagemErroGoogle(erro.message));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível abrir o cadastro com Google agora.';
      });
    } finally {
      if (mounted && !_abrindoProximaTela) {
        setState(() => _processando = false);
      }
    }
  }

  Future<void> _tentarConcluirGoogle({required bool silencioso}) async {
    if (_processando || _abrindoProximaTela || !mounted) return;

    final haviaVinculoPendente =
        await SessaoServico.instance.possuiVinculoGooglePendente();
    if (!haviaVinculoPendente || !mounted) return;

    setState(() {
      _processando = true;
      _erro = null;
    });

    try {
      final concluido =
          await SessaoServico.instance.concluirVinculoGooglePendente();
      if (!mounted) return;

      if (concluido) {
        _abrirCasamentos();
        return;
      }

      if (!silencioso) {
        setState(() {
          _erro =
              'A conta Google não foi vinculada. Tente novamente ou crie uma senha.';
        });
      }
    } on AuthException catch (erro) {
      if (!mounted) return;
      setState(() => _erro = _mensagemErroGoogle(erro.message));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível concluir o cadastro com Google.';
      });
    } finally {
      if (mounted && !_abrindoProximaTela) {
        setState(() => _processando = false);
      }
    }
  }

  Future<void> _criarSenha() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || _processando) return;

    setState(() {
      _processando = true;
      _erro = null;
    });

    try {
      await SessaoServico.instance.definirSenhaInicial(_senhaController.text);
      if (!mounted) return;
      _abrirCasamentos();
    } on AuthException catch (erro) {
      if (!mounted) return;
      setState(() => _erro = erro.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível criar sua senha. Tente novamente.';
      });
    } finally {
      if (mounted && !_abrindoProximaTela) {
        setState(() => _processando = false);
      }
    }
  }

  void _abrirCasamentos() {
    if (_abrindoProximaTela || !mounted) return;
    _abrindoProximaTela = true;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const TelaCasamentos()),
      (route) => false,
    );
  }

  String _mensagemErroGoogle(String mensagem) {
    final texto = mensagem.toLowerCase();
    if (texto.contains('already') && texto.contains('linked')) {
      return 'Essa conta Google já está vinculada a outro usuário.';
    }
    if (texto.contains('identity') && texto.contains('exists')) {
      return 'Essa conta Google já está sendo usada por outro cadastro.';
    }
    return 'Não foi possível vincular a conta Google. $mensagem';
  }

  @override
  Widget build(BuildContext context) {
    final sessao = SessaoServico.instance;
    final nome = sessao.nomeExibicaoAtual.trim();
    final email = sessao.emailAtual.trim();

    return PopScope(
      canPop: false,
      child: Scaffold(
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
                      Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 72,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Primeiro acesso',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Como esta é a primeira vez que você usa o aplicativo, finalize a criação da sua conta para acessar o evento.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 22),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (nome.isNotEmpty) ...[
                                Text(
                                  nome,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                                const SizedBox(height: 4),
                              ],
                              Row(
                                children: [
                                  const Icon(Icons.email_outlined, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(email)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _processando ? null : _vincularGoogle,
                          icon: const Text(
                            'G',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4285F4),
                            ),
                          ),
                          label: const Text('Criar acesso com Google'),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('ou crie uma senha'),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _senhaController,
                        obscureText: _ocultarSenha,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'Nova senha',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: _ocultarSenha
                                ? 'Mostrar senha'
                                : 'Ocultar senha',
                            onPressed: _processando
                                ? null
                                : () => setState(
                                    () => _ocultarSenha = !_ocultarSenha,
                                  ),
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
                        autofillHints: const [AutofillHints.newPassword],
                        onFieldSubmitted: (_) => _criarSenha(),
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
                        Text(
                          _erro!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _processando ? null : _criarSenha,
                          icon: _processando
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: Text(
                            _processando
                                ? 'Concluindo cadastro...'
                                : 'Criar acesso com senha',
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
}
