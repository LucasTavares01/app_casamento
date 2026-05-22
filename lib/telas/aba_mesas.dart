import 'package:flutter/material.dart';
import '../servicos/supabase_servico.dart';
import '../modelos/modelos.dart';

class AbaMesas extends StatefulWidget {
  const AbaMesas({super.key});

  @override
  State<AbaMesas> createState() => _AbaMesasState();
}

class _AbaMesasState extends State<AbaMesas> {
  final _servico = SupabaseServico();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Mesa>>(
      stream: _servico.listarMesas(),
      builder: (context, snapMesas) {
        if (snapMesas.hasError) {
          return Center(child: Text('Erro nas Mesas: ${snapMesas.error}'));
        }
        if (!snapMesas.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final mesas = snapMesas.data!;

        return StreamBuilder<List<Convidado>>(
          stream: _servico.listarConvidados(),
          builder: (context, snapConvidados) {
            if (snapConvidados.hasError) {
              return Center(
                child: Text('Erro nos Convidados: ${snapConvidados.error}'),
              );
            }
            if (!snapConvidados.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final todosConvidados = snapConvidados.data!;

            if (mesas.isEmpty) {
              return const Center(
                child: Text('Nenhuma mesa cadastrada ainda.'),
              );
            }

            return ListView.builder(
              itemCount: mesas.length,
              itemBuilder: (context, index) {
                final mesa = mesas[index];
                final convidadosDaMesa = todosConvidados
                    .where((c) => c.mesaId == mesa.id)
                    .toList();
                final presentes = convidadosDaMesa
                    .where((c) => c.chegou)
                    .length;
                final faltam = convidadosDaMesa.length - presentes;

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  elevation: 2,
                  child: ExpansionTile(
                    title: Text(
                      mesa.nomeExibicao,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Text(
                      'Total alocado: ${convidadosDaMesa.length} pessoas',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Chegaram: $presentes',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Restam: $faltam',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    children: convidadosDaMesa.isEmpty
                        ? [
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('Ninguém alocado nesta mesa ainda.'),
                            ),
                          ]
                        : convidadosDaMesa.map((convidado) {
                            return ListTile(
                              title: Text(convidado.nome),
                              trailing: Icon(
                                convidado.chegou
                                    ? Icons.check_circle
                                    : Icons.access_time,
                                color: convidado.chegou
                                    ? Colors.green
                                    : Colors.grey.shade400,
                              ),
                            );
                          }).toList(),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
