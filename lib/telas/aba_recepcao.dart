import 'package:flutter/material.dart';
import '../servicos/supabase_servico.dart';
import '../modelos/modelos.dart';

class AbaRecepcao extends StatefulWidget {
  const AbaRecepcao({super.key});

  @override
  State<AbaRecepcao> createState() => _AbaRecepcaoState();
}

class _AbaRecepcaoState extends State<AbaRecepcao> {
  final _servico = SupabaseServico();
  String _textoBusca = '';
  String?
  _mesaFiltroId; // Variável que vai guardar a mesa selecionada no filtro (null = todas)

  final List<Color> _coresPasteis = [
    Colors.pink.shade100,
    Colors.blue.shade100,
    Colors.green.shade100,
    Colors.orange.shade100,
    Colors.purple.shade100,
    Colors.teal.shade100,
    Colors.yellow.shade100,
    Colors.cyan.shade100,
    Colors.red.shade100,
    Colors.indigo.shade100,
    Colors.amber.shade100,
    Colors.lightGreen.shade100,
  ];

  void _mostrarConfirmacao(Convidado convidado) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Chegada'),
        content: Text('Deseja confirmar a chegada de ${convidado.nome}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              _servico.confirmarChegada(convidado.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text(
              'Confirmar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDesfazerChegada(Convidado convidado) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desfazer Check-in'),
        content: Text(
          'Deseja remover o status de chegada de ${convidado.nome}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              _servico.removerChegada(convidado.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remover', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Subimos o StreamBuilder de Mesas para abraçar a tela toda,
    // assim conseguimos usar as mesas para montar o menu de Filtro lá no topo.
    return StreamBuilder<List<Mesa>>(
      stream: _servico.listarMesas(),
      builder: (context, snapMesas) {
        if (snapMesas.hasError) {
          return Center(child: Text('Erro: ${snapMesas.error}'));
        }

        final mesas = snapMesas.data ?? [];

        return Column(
          children: [
            // BARRA DE PESQUISA POR NOME
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar convidado por nome...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
                onChanged: (valor) =>
                    setState(() => _textoBusca = valor.toLowerCase()),
              ),
            ),

            // NOVO: FILTRO POR MESA
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: DropdownButtonFormField<String?>(
                value: _mesaFiltroId,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.filter_list),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                isExpanded: true,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text(
                      'Todas as Mesas (Sem filtro)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...mesas.map(
                    (m) => DropdownMenuItem(
                      value: m.id,
                      child: Text(m.nomeExibicao),
                    ),
                  ),
                ],
                onChanged: (valor) {
                  setState(() {
                    _mesaFiltroId = valor;
                  });
                },
              ),
            ),

            // LISTA DE CONVIDADOS
            Expanded(
              child: StreamBuilder<List<Convidado>>(
                stream: _servico.listarConvidados(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Erro: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // 1. Aplica a Busca por Texto E o Filtro de Mesa
                  final convidadosFiltrados = snapshot.data!.where((c) {
                    final bateNome = c.nome.toLowerCase().contains(_textoBusca);
                    final bateMesa =
                        _mesaFiltroId == null || c.mesaId == _mesaFiltroId;
                    return bateNome &&
                        bateMesa; // Tem que passar nos dois filtros
                  }).toList();

                  // 2. Ordena (Mesa por número, depois nome)
                  convidadosFiltrados.sort((a, b) {
                    final mesaA = mesas.firstWhere(
                      (m) => m.id == a.mesaId,
                      orElse: () => Mesa(id: '', numero: 99999),
                    );
                    final mesaB = mesas.firstWhere(
                      (m) => m.id == b.mesaId,
                      orElse: () => Mesa(id: '', numero: 99999),
                    );

                    int compMesa = mesaA.numero.compareTo(mesaB.numero);
                    if (compMesa != 0) return compMesa;
                    return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
                  });

                  if (convidadosFiltrados.isEmpty) {
                    return const Center(
                      child: Text('Nenhum convidado encontrado.'),
                    );
                  }

                  return ListView.builder(
                    itemCount: convidadosFiltrados.length,
                    itemBuilder: (context, index) {
                      final convidado = convidadosFiltrados[index];
                      final mesa = mesas.firstWhere(
                        (m) => m.id == convidado.mesaId,
                        orElse: () => Mesa(id: '', numero: -1),
                      );

                      Color corFundo = Colors.white;
                      if (mesa.numero != -1) {
                        corFundo =
                            _coresPasteis[(mesa.numero) % _coresPasteis.length];
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        color: corFundo,
                        elevation: convidado.chegou ? 0 : 3,
                        child: ListTile(
                          title: Text(
                            convidado.nome,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: convidado.chegou
                                  ? Colors.black38
                                  : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            mesa.numero != -1
                                ? mesa.nomeExibicao
                                : 'Sem mesa definida',
                          ),
                          trailing: convidado.chegou
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 36,
                                  ),
                                  onPressed: () =>
                                      _mostrarDesfazerChegada(convidado),
                                )
                              : IconButton(
                                  icon: const Icon(
                                    Icons.how_to_reg,
                                    color: Colors.deepPurple,
                                    size: 32,
                                  ),
                                  onPressed: () =>
                                      _mostrarConfirmacao(convidado),
                                ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
