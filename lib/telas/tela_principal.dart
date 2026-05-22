import 'package:flutter/material.dart';
import 'aba_recepcao.dart';
import 'aba_cadastro.dart'; // Pode importar a aba de cadastro também
import 'aba_mesas.dart';
import 'aba_equipe.dart';

class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> {
  int _abaSelecionada = 0;

  // Lista com as 4 telas (por enquanto, apenas "placeholders" vazios)
  final List<Widget> _telas = [
    const AbaRecepcao(),
    const AbaMesas(),
    const AbaCadastro(),
    const AbaEquipe(), // <-- E pronto! Aplicativo 100% completo!
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão do Casamento'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      // O corpo do app vai mudar dependendo da aba selecionada
      body: _telas[_abaSelecionada],

      // O menu na parte inferior da tela
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType
            .fixed, // Permite ter mais de 3 itens sem sumir o texto
        currentIndex: _abaSelecionada,
        onTap: (index) {
          setState(() {
            _abaSelecionada = index; // Atualiza a tela quando clica na aba
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Recepção'),
          BottomNavigationBarItem(
            icon: Icon(Icons.table_restaurant),
            label: 'Mesas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Cadastros',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Equipe'),
        ],
      ),
    );
  }
}
