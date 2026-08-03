import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../servicos/casamento_atual_servico.dart';
import '../servicos/sessao_servico.dart';
import 'tela_casamentos.dart';
import 'tela_criar_conta.dart';
import 'tela_definir_senha.dart';
import 'tela_primeiro_acesso_funcionario.dart';
import 'tela_principal.dart';

class TelaPortaDeEntrada extends StatefulWidget {
  const TelaPortaDeEntrada({super.key});

  @override
  State<TelaPortaDeEntrada> createState() => _TelaPortaDeEntradaState();
}

class _TelaPortaDeEntradaState extends State<TelaPortaDeEntrada>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final Connectivity _connectivity = Connectivity();

  static const Duration _tempoLimitePorTentativa = Duration(seconds: 20);
  static const int _maximoTentativasCarregarConta = 3;

  bool _carregando = false;
  bool _ocultarSenha = true;
  bool _abrindoProximaTela = false;
  bool _processandoRetornoAuth = false;
  String? _erro;
  StreamSubscription<AuthState>? _mudancasAutenticacao;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mudancasAutenticacao = Supabase.instance.client.auth.onAuthStateChange
        .listen(
          _processarEventoAuth,
          onError: (Object erro, StackTrace stackTrace) {
            if (!mounted) return;
            setState(() {
              _carregando = false;
              _erro = 'Não foi possível concluir a autenticação agora.';
            });
          },
        );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_concluirLoginGooglePendente());
      unawaited(_concluirSessaoExistente());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_concluirLoginGooglePendente());
      unawaited(_concluirSessaoExistente());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailController.dispose();
    _senhaController.dispose();
    _mudancasAutenticacao?.cancel();
    super.dispose();
  }

  Future<void> _processarEventoAuth(AuthState dados) async {
    if (!mounted) return;

    if (dados.event == AuthChangeEvent.passwordRecovery) {
      _abrirDefinirSenha(recuperacao: true);
      return;
    }

    if (dados.session == null) return;

    if (dados.event == AuthChangeEvent.signedIn) {
      await _concluirSessaoAutenticada();
      return;
    }

    if (dados.event == AuthChangeEvent.initialSession) {
      await _concluirSessaoAutenticada();
    }
  }

  Future<void> _concluirLoginGooglePendente() async {
    if (_abrindoProximaTela || _processandoRetornoAuth || !mounted) return;
    if (!await SessaoServico.instance.possuiLoginGooglePendente()) return;
    if (!SessaoServico.instance.possuiSessaoLocal) return;
    await _concluirSessaoAutenticada();
  }

  Future<void> _concluirSessaoExistente() async {
    if (_abrindoProximaTela || _processandoRetornoAuth || !mounted) return;
    if (!SessaoServico.instance.possuiSessaoLocal) return;
    await _concluirSessaoAutenticada();
  }

  Future<void> _concluirSessaoAutenticada() async {
    if (_abrindoProximaTela || _processandoRetornoAuth || !mounted) return;
    _processandoRetornoAuth = true;

    if (mounted) {
      setState(() {
        _carregando = true;
        _erro = null;
      });
    }

    final sessao = SessaoServico.instance;
    var restaurouSessaoLocal = false;

    try {
      restaurouSessaoLocal = await sessao.restaurarSessaoLocal();
      final possuiCasamentoLocal =
          CasamentoAtualServico.instance.casamento != null;
      final semRede = await _estaSemRede();

      if (semRede && restaurouSessaoLocal && possuiCasamentoLocal) {
        _abrirCasamentoOffline();
        return;
      }

      await _sincronizarContaComTentativas(sessao);
      final encerrouFluxoGooglePorContaExistente =
          await _concluirPerfilCerimonialistaGooglePendente();
      if (encerrouFluxoGooglePorContaExistente) return;
      if (mounted) _abrirAposAutenticacao();
    } catch (erro, stackTrace) {
      debugPrint('ERRO AO CARREGAR CONTA: $erro');
      debugPrint(stackTrace.toString());

      final possuiCasamentoLocal =
          CasamentoAtualServico.instance.casamento != null;
      if (restaurouSessaoLocal && possuiCasamentoLocal) {
        _abrirCasamentoOffline();
        return;
      }

      if (mounted) {
        setState(() {
          _erro = restaurouSessaoLocal
              ? 'Sem conexão. Abra um casamento com internet pelo menos uma vez antes de usá-lo offline.'
              : 'Não foi possível carregar sua conta. Verifique a conexão e tente novamente.';
        });
      }
    } finally {
      _processandoRetornoAuth = false;
      if (mounted && !_abrindoProximaTela) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _sincronizarContaComTentativas(
    SessaoServico sessao,
  ) async {
    Object? ultimoErro;
    StackTrace? ultimaPilha;

    for (
      var tentativa = 1;
      tentativa <= _maximoTentativasCarregarConta;
      tentativa++
    ) {
      try {
        await sessao
            .sincronizarUsuarioAutenticado()
            .timeout(_tempoLimitePorTentativa);
        return;
      } catch (erro, stackTrace) {
        ultimoErro = erro;
        ultimaPilha = stackTrace;

        final podeTentarNovamente =
            sessao.possuiSessaoLocal &&
            tentativa < _maximoTentativasCarregarConta;
        if (!podeTentarNovamente) {
          Error.throwWithStackTrace(erro, stackTrace);
        }

        debugPrint(
          'Aguardando a criação completa da conta '
          '(tentativa $tentativa de $_maximoTentativasCarregarConta): $erro',
        );
        await Future<void>.delayed(
          Duration(milliseconds: 800 * tentativa),
        );
      }
    }

    if (ultimoErro != null && ultimaPilha != null) {
      Error.throwWithStackTrace(ultimoErro, ultimaPilha);
    }
  }

  Future<bool> _concluirPerfilCerimonialistaGooglePendente() async {
    final sessao = SessaoServico.instance;
    if (!await sessao.possuiPerfilCerimonialistaGooglePendente()) {
      return false;
    }

    final papeis =
        await CasamentoAtualServico.instance.obterPapeisContaAtual();

    if (papeis.cerimonialista || papeis.funcionario) {
      await sessao.limparPerfilCerimonialistaGooglePendente();

      if (mounted) {
        await _mostrarMensagem(
          titulo: 'E-mail já cadastrado',
          mensagem:
              'Este e-mail já está cadastrado. O perfil de cerimonialista '
              'não pode ser criado por este fluxo. Entre na conta existente '
              'e habilite o perfil pelo seu próprio cadastro.',
        );
      }
      await sessao.encerrarSessao();
      return true;
    }

    if (!mounted) return true;

    await sessao.habilitarPerfilCerimonialista(
      nome: sessao.nomeExibicaoAtual,
    );
    await sessao.limparPerfilCerimonialistaGooglePendente();

    if (mounted) {
      await _mostrarMensagem(
        titulo: papeis.funcionario
            ? 'Conta mista criada'
            : 'Perfil de cerimonialista criado',
        mensagem: papeis.funcionario
            ? 'Pronto! Esta conta agora funciona como funcionário e como '
                  'cerimonialista.'
            : 'Seu perfil de cerimonialista foi criado com sucesso.',
      );
    }
    return false;
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

  Future<bool> _estaSemRede() async {
    try {
      final resultados = await _connectivity.checkConnectivity().timeout(
        const Duration(seconds: 3),
      );
      return resultados.isEmpty ||
          resultados.every((resultado) => resultado == ConnectivityResult.none);
    } catch (_) {
      // Estado desconhecido: tentamos atualizar pelo Supabase e usamos a cópia
      // offline caso a chamada falhe ou exceda o tempo limite.
      return false;
    }
  }

  void _abrirCasamentoOffline() {
    if (_abrindoProximaTela || !mounted) return;

    if (SessaoServico.instance.precisaConcluirPrimeiroAcessoFuncionario ||
        SessaoServico.instance.precisaDefinirSenha) {
      setState(() {
        _erro = 'Conecte-se à internet para concluir o primeiro acesso.';
      });
      return;
    }

    _abrindoProximaTela = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const TelaPrincipal()),
    );
  }

  Future<void> _entrarComGoogle() async {
    setState(() {
      _carregando = true;
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
      if (mounted && !_processandoRetornoAuth) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _entrar() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      await SessaoServico.instance.entrarComEmail(
        email: _emailController.text,
        senha: _senhaController.text,
      );
      if (mounted) _abrirAposAutenticacao();
    } catch (_) {
      if (mounted) {
        setState(() {
          _erro = 'E-mail ou senha incorretos. Tente novamente.';
        });
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _recuperarSenha() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _erro = 'Digite seu e-mail para recuperar a senha.');
      return;
    }

    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final cadastrado =
          await SessaoServico.instance.emailCadastrado(email);

      if (!mounted) return;

      if (!cadastrado) {
        await _mostrarMensagem(
          titulo: 'E-mail não cadastrado',
          mensagem:
              'Não encontramos uma conta com o e-mail $email. '
              'Confira o endereço digitado ou crie uma nova conta.',
        );
        return;
      }

      await SessaoServico.instance.enviarRecuperacaoDeSenha(email);
      if (!mounted) return;

      await _mostrarMensagem(
        titulo: 'E-mail enviado',
        mensagem:
            'Enviamos para $email um link para redefinir sua senha. '
            'Verifique também a pasta de spam ou lixo eletrônico.',
      );
    } catch (_) {
      if (mounted) {
        await _mostrarMensagem(
          titulo: 'Não foi possível enviar',
          mensagem:
              'Não conseguimos enviar o e-mail de recuperação agora. '
              'Tente novamente em alguns instantes.',
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _abrirAposAutenticacao() {
    if (_abrindoProximaTela || !mounted) return;

    if (SessaoServico.instance.precisaConcluirPrimeiroAcessoFuncionario) {
      _abrirPrimeiroAcessoFuncionario();
      return;
    }

    if (SessaoServico.instance.precisaDefinirSenha) {
      _abrirDefinirSenha();
      return;
    }

    _abrindoProximaTela = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const TelaCasamentos()),
    );
  }

  void _abrirPrimeiroAcessoFuncionario() {
    if (_abrindoProximaTela || !mounted) return;
    _abrindoProximaTela = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const TelaPrimeiroAcessoFuncionario(),
      ),
    );
  }

  void _abrirDefinirSenha({
    bool recuperacao = false,
    bool funcionario = false,
  }) {
    if (_abrindoProximaTela || !mounted) return;
    _abrindoProximaTela = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TelaDefinirSenha(
          recuperacao: recuperacao,
          funcionario: funcionario,
        ),
      ),
    );
  }

  Future<void> _criarConta() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const TelaCriarConta()));
    if (mounted && SessaoServico.instance.possuiSessaoLocal) {
      _abrirAposAutenticacao();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Image.asset(
                        'assets/branding/confirmaai_icon.png',
                        width: 82,
                        height: 82,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'ConfirmaAi',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Entre para acessar seus eventos e sua equipe.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (valor) {
                        final email = valor?.trim() ?? '';
                        return email.contains('@')
                            ? null
                            : 'Digite um e-mail válido.';
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _senhaController,
                      obscureText: _ocultarSenha,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _entrar(),
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
                      validator: (valor) =>
                          (valor?.isEmpty ?? true) ? 'Digite sua senha.' : null,
                    ),
                    if (_erro != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _erro!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _carregando ? null : _entrar,
                        icon: _carregando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.login),
                        label: Text(_carregando ? 'Entrando...' : 'Entrar'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _carregando ? null : _entrarComGoogle,
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
                    ),
                    TextButton(
                      onPressed: _carregando ? null : _recuperarSenha,
                      child: const Text('Esqueci minha senha'),
                    ),
                    Text(
                      'Recebeu um convite para trabalhar? Abra o link recebido no seu e-mail para criar ou acessar sua conta de funcionário.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                    const Divider(height: 34),
                    OutlinedButton.icon(
                      onPressed: _carregando ? null : _criarConta,
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('Criar conta de cerimonialista'),
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
