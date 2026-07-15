import 'package:flutter/material.dart';

import '../banco/banco_local.dart';
import '../servicos/sessao_servico.dart';
import 'tela_principal.dart';

class TelaPortaDeEntrada extends StatefulWidget {
  const TelaPortaDeEntrada({super.key});

  @override
  State<TelaPortaDeEntrada> createState() => _TelaPortaDeEntradaState();
}

class _TelaPortaDeEntradaState extends State<TelaPortaDeEntrada> {
  final SessaoServico _sessaoServico = SessaoServico.instance;
  final TextEditingController _senhaController = TextEditingController();

  List<UsuarioAppLocalRegistro> _usuarios = [];

  String? _usuarioSelecionadoId;
  String _erro = '';

  bool _carregandoUsuarios = true;
  bool _validandoLogin = false;
  bool _ocultarSenha = true;

  @override
  void initState() {
    super.initState();
    _carregarUsuarios();
  }

  @override
  void dispose() {
    _senhaController.dispose();
    super.dispose();
  }

  /// Carrega a lista do banco SQLite do próprio aparelho.
  Future<void> _carregarUsuarios() async {
    try {
      final usuarios = await _sessaoServico.listarUsuariosAtivos();
      final ultimoUsuarioId = await _sessaoServico.obterUltimoUsuarioId();

      String? usuarioInicial;

      final ultimoUsuarioAindaExiste = usuarios.any(
        (usuario) => usuario.id == ultimoUsuarioId,
      );

      if (ultimoUsuarioAindaExiste) {
        usuarioInicial = ultimoUsuarioId;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _usuarios = usuarios;
        _usuarioSelecionadoId = usuarioInicial;
        _carregandoUsuarios = false;
      });
    } catch (erro) {
      if (!mounted) {
        return;
      }

      setState(() {
        _carregandoUsuarios = false;
        _erro = 'Não foi possível carregar os usuários: $erro';
      });
    }
  }

  /// Valida o nome e a senha escolhidos.
  Future<void> _entrar() async {
    FocusScope.of(context).unfocus();

    if (_usuarioSelecionadoId == null) {
      setState(() {
        _erro = 'Selecione o seu nome.';
      });
      return;
    }

    if (_senhaController.text.isEmpty) {
      setState(() {
        _erro = 'Digite a sua senha.';
      });
      return;
    }

    setState(() {
      _validandoLogin = true;
      _erro = '';
    });

    try {
      final loginValido = await _sessaoServico.entrar(
        usuarioId: _usuarioSelecionadoId!,
        senha: _senhaController.text,
      );

      if (!mounted) {
        return;
      }

      if (!loginValido) {
        setState(() {
          _validandoLogin = false;
          _erro = _sessaoServico.ultimoErroLogin ?? 'Não foi possível entrar.';
        });
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const TelaPrincipal()),
      );
    } catch (erro) {
      if (!mounted) {
        return;
      }

      setState(() {
        _validandoLogin = false;
        _erro = 'Não foi possível entrar no aplicativo: $erro';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.favorite,
                    size: 80,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Acesso da Equipe',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Selecione seu nome e digite sua senha.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 32),
                  if (_carregandoUsuarios)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    )
                  else ...[
                    DropdownButtonFormField<String>(
                      key: ValueKey('usuario-$_usuarioSelecionadoId'),
                      initialValue: _usuarioSelecionadoId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Quem está usando o aplicativo?',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      items: _usuarios.map((usuario) {
                        return DropdownMenuItem<String>(
                          value: usuario.id,
                          child: Text(usuario.nome),
                        );
                      }).toList(),
                      onChanged: _validandoLogin
                          ? null
                          : (valor) {
                              setState(() {
                                _usuarioSelecionadoId = valor;
                                _erro = '';
                              });
                            },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _senhaController,
                      obscureText: _ocultarSenha,
                      enabled: !_validandoLogin,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _entrar(),
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: const Icon(Icons.lock),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _ocultarSenha
                              ? 'Mostrar senha'
                              : 'Ocultar senha',
                          onPressed: () {
                            setState(() {
                              _ocultarSenha = !_ocultarSenha;
                            });
                          },
                          icon: Icon(
                            _ocultarSenha
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                    ),
                    if (_erro.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        _erro,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _validandoLogin ? null : _entrar,
                        icon: _validandoLogin
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.login),
                        label: Text(
                          _validandoLogin ? 'Entrando...' : 'Entrar',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
