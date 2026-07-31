import 'package:flutter/material.dart';

import '../servicos/sessao_servico.dart';
import 'porta_entrada.dart';

class TelaConta extends StatelessWidget {
  const TelaConta({super.key});

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
}
