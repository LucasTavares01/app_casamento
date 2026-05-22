import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../servicos/supabase_servico.dart';
import '../modelos/modelos.dart';

class AbaCadastro extends StatefulWidget {
  const AbaCadastro({super.key});

  @override
  State<AbaCadastro> createState() => _AbaCadastroState();
}

class _AbaCadastroState extends State<AbaCadastro> {
  final _servico = SupabaseServico();

  void _dialogMesa({Mesa? mesaEdit}) {
    final numeroCtrl = TextEditingController(
      text: mesaEdit != null ? mesaEdit.numero.toString() : '',
    );
    final detalheCtrl = TextEditingController(text: mesaEdit?.detalhe ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(mesaEdit == null ? 'Nova Mesa' : 'Editar Mesa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: numeroCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                hintText: 'Número da Mesa (ex: 1)',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: detalheCtrl,
              decoration: const InputDecoration(
                hintText: 'Detalhe (ex: Padrinhos) - Opcional',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              int numero = int.tryParse(numeroCtrl.text) ?? 0;
              if (mesaEdit == null) {
                _servico.adicionarMesa(numero, detalheCtrl.text);
              } else {
                _servico.editarMesa(mesaEdit.id, numero, detalheCtrl.text);
              }
              Navigator.pop(context);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _dialogConfirmarExclusaoMesa(Mesa mesa) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Mesa'),
        content: Text(
          'Tem certeza que deseja excluir a ${mesa.nomeExibicao}? (Os convidados nela ficarão sem mesa).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              _servico.excluirMesa(mesa.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _dialogConvidado(List<Mesa> mesas, {Convidado? convidadoEdit}) {
    final nomeCtrl = TextEditingController(text: convidadoEdit?.nome ?? '');
    String? mesaSelecionada = convidadoEdit?.mesaId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            convidadoEdit == null ? 'Novo Convidado' : 'Editar Convidado',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeCtrl,
                decoration: const InputDecoration(
                  hintText: 'Nome do Convidado',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButton<String>(
                value: mesaSelecionada,
                isExpanded: true,
                hint: const Text('Selecionar Mesa (Opcional)'),
                items: mesas
                    .map(
                      (m) => DropdownMenuItem(
                        value: m.id,
                        child: Text(m.nomeExibicao),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setDialogState(() => mesaSelecionada = val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (convidadoEdit == null) {
                  _servico.adicionarConvidado(nomeCtrl.text, mesaSelecionada);
                } else {
                  _servico.editarConvidado(
                    convidadoEdit.id,
                    nomeCtrl.text,
                    mesaSelecionada,
                  );
                }
                Navigator.pop(context);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  void _dialogConfirmarExclusaoConvidado(Convidado convidado) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Convidado'),
        content: Text(
          'Tem certeza que deseja excluir ${convidado.nome} da lista?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              _servico.excluirConvidado(convidado.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: const TabBar(
          tabs: [
            Tab(text: 'MESAS', icon: Icon(Icons.table_bar)),
            Tab(text: 'CONVIDADOS', icon: Icon(Icons.person_add)),
          ],
        ),
        body: TabBarView(children: [_listaMesas(), _listaConvidados()]),
      ),
    );
  }

  Widget _listaMesas() {
    return StreamBuilder<List<Mesa>>(
      stream: _servico.listarMesas(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final mesas = snapshot.data!;
        return Scaffold(
          floatingActionButton: FloatingActionButton(
            onPressed: () => _dialogMesa(),
            child: const Icon(Icons.add),
          ),
          body: ListView.builder(
            itemCount: mesas.length,
            itemBuilder: (context, i) => ListTile(
              title: Text(mesas[i].nomeExibicao),
              leading: const Icon(Icons.grid_view),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.grey),
                    onPressed: () => _dialogMesa(mesaEdit: mesas[i]),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () => _dialogConfirmarExclusaoMesa(mesas[i]),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _listaConvidados() {
    return StreamBuilder<List<Mesa>>(
      stream: _servico.listarMesas(),
      builder: (context, snapMesas) {
        return StreamBuilder<List<Convidado>>(
          stream: _servico.listarConvidados(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final convidados = snapshot.data!;
            return Scaffold(
              floatingActionButton: FloatingActionButton(
                onPressed: () => _dialogConvidado(snapMesas.data ?? []),
                child: const Icon(Icons.person_add),
              ),
              body: ListView.builder(
                itemCount: convidados.length,
                itemBuilder: (context, i) {
                  final conv = convidados[i];
                  String nomeMesa = 'Sem mesa';
                  if (conv.mesaId != null) {
                    final m = (snapMesas.data ?? []).firstWhere(
                      (mesa) => mesa.id == conv.mesaId,
                      orElse: () => Mesa(id: '', numero: 0),
                    );
                    if (m.id.isNotEmpty) nomeMesa = m.nomeExibicao;
                  }
                  return ListTile(
                    title: Text(conv.nome),
                    subtitle: Text(nomeMesa),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.grey),
                          onPressed: () => _dialogConvidado(
                            snapMesas.data ?? [],
                            convidadoEdit: conv,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.redAccent,
                          ),
                          onPressed: () =>
                              _dialogConfirmarExclusaoConvidado(conv),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
