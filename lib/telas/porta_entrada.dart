import 'package:flutter/material.dart';
import 'tela_principal.dart'; // Vamos criar esse arquivo no próximo passo

class TelaPortaDeEntrada extends StatefulWidget {
  const TelaPortaDeEntrada({super.key});

  @override
  State<TelaPortaDeEntrada> createState() => _TelaPortaDeEntradaState();
}

class _TelaPortaDeEntradaState extends State<TelaPortaDeEntrada> {
  final _senhaController = TextEditingController();
  final String _senhaCorreta = 'festa123'; // Defina a sua senha mestre aqui
  String _erro = '';

  void _entrar() {
    if (_senhaController.text == _senhaCorreta) {
      // Se a senha estiver certa, troca a tela atual pela Tela Principal
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const TelaPrincipal()),
      );
    } else {
      // Se estiver errada, mostra o erro na tela
      setState(() {
        _erro = 'Senha incorreta. Tente novamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.favorite, size: 80, color: Colors.deepPurple),
              const SizedBox(height: 24),
              const Text(
                'Acesso da Equipe',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _senhaController,
                obscureText: true, // Esconde o texto (vira bolinhas)
                decoration: InputDecoration(
                  labelText: 'Senha Mestra',
                  border: const OutlineInputBorder(),
                  errorText: _erro.isEmpty ? null : _erro,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _entrar,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50), // Botão largo
                ),
                child: const Text('Entrar', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
