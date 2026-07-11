import 'package:flutter/material.dart';

import '../modelos/modelos.dart';
import '../servicos/supabase_servico.dart';

class TelaConflitos extends StatefulWidget {
  const TelaConflitos({super.key});

  @override
  State<TelaConflitos> createState() => _TelaConflitosState();
}

class _TelaConflitosState extends State<TelaConflitos> {
  final SupabaseServico _servico = SupabaseServico();

  late final Stream<List<ConflitoSincronizacao>> _streamConflitos;
  late final Stream<List<Mesa>> _streamMesas;

  final Set<String> _conflitosEmResolucao = <String>{};

  @override
  void initState() {
    super.initState();
    _streamConflitos = _servico.listarConflitosPendentes();
    _streamMesas = _servico.listarMesas();
  }

  Future<void> _resolver({
    required ConflitoSincronizacao conflito,
    required String resolucao,
    String? novaMesaId,
  }) async {
    if (_conflitosEmResolucao.contains(conflito.id)) {
      return;
    }

    setState(() {
      _conflitosEmResolucao.add(conflito.id);
    });

    try {
      await _servico.resolverConflitoMesaCheckin(
        conflitoId: conflito.id,
        resolucao: resolucao,
        novaMesaId: novaMesaId,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Conflito resolvido. Os aparelhos serão atualizados automaticamente.',
          ),
        ),
      );
    } catch (erro) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível resolver o conflito: $erro')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _conflitosEmResolucao.remove(conflito.id);
        });
      }
    }
  }

  Future<void> _confirmarRestauracao(ConflitoSincronizacao conflito) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Restaurar mesa'),
          content: const Text(
            'A mesa original será restaurada e o convidado será colocado novamente nela. O check-in será mantido.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restaurar'),
            ),
          ],
        );
      },
    );

    if (confirmou == true) {
      await _resolver(conflito: conflito, resolucao: 'restaurar_mesa');
    }
  }

  Future<void> _confirmarSemMesa(ConflitoSincronizacao conflito) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Manter sem mesa'),
          content: const Text(
            'A mesa continuará removida. O convidado ficará sem mesa, mas o check-in será mantido.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );

    if (confirmou == true) {
      await _resolver(conflito: conflito, resolucao: 'manter_sem_mesa');
    }
  }

  Future<void> _escolherOutraMesa({
    required ConflitoSincronizacao conflito,
    required List<Mesa> mesas,
  }) async {
    if (mesas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não existe outra mesa disponível.')),
      );
      return;
    }

    String? mesaSelecionadaId;

    final resultado = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Escolher outra mesa'),
              content: DropdownButtonFormField<String>(
                initialValue: mesaSelecionadaId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Nova mesa do convidado',
                  border: OutlineInputBorder(),
                ),
                items: mesas.map((mesa) {
                  return DropdownMenuItem<String>(
                    value: mesa.id,
                    child: Text(mesa.nomeExibicao),
                  );
                }).toList(),
                onChanged: (valor) {
                  setDialogState(() {
                    mesaSelecionadaId = valor;
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: mesaSelecionadaId == null
                      ? null
                      : () => Navigator.pop(context, mesaSelecionadaId),
                  child: const Text('Mover convidado'),
                ),
              ],
            );
          },
        );
      },
    );

    if (resultado != null && resultado.isNotEmpty) {
      await _resolver(
        conflito: conflito,
        resolucao: 'mover_para_outra_mesa',
        novaMesaId: resultado,
      );
    }
  }

  String _formatarDataHora(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year.toString();
    final hora = data.hour.toString().padLeft(2, '0');
    final minuto = data.minute.toString().padLeft(2, '0');

    return '$dia/$mes/$ano às $hora:$minuto';
  }

  Widget _construirCard({
    required ConflitoSincronizacao conflito,
    required List<Mesa> mesas,
  }) {
    final resolvendo = _conflitosEmResolucao.contains(conflito.id);
    final nomeConvidado =
        conflito.dados['convidado_nome']?.toString() ?? 'Convidado';
    final numeroMesa =
        conflito.dados['mesa_numero_contexto']?.toString() ?? '?';

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      elevation: 3,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: Colors.amber.shade100,
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.amber.shade900,
                  size: 30,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conflito.titulo,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatarDataHora(conflito.criadoEm),
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nomeConvidado,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mesa usada no aparelho offline: $numeroMesa',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Text(conflito.descricao),
                if (conflito.usuarioCheckinNome != null) ...[
                  const SizedBox(height: 8),
                  Text('Check-in feito por: ${conflito.usuarioCheckinNome}'),
                ],
                if (conflito.usuarioAlteracaoMesaNome != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Mesa alterada por: ${conflito.usuarioAlteracaoMesaNome}',
                  ),
                ],
                const SizedBox(height: 16),
                if (resolvendo)
                  const Center(child: CircularProgressIndicator())
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _confirmarRestauracao(conflito),
                        icon: const Icon(Icons.restore),
                        label: const Text('Restaurar mesa'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _confirmarSemMesa(conflito),
                        icon: const Icon(Icons.person_outline),
                        label: const Text('Manter sem mesa'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _escolherOutraMesa(
                          conflito: conflito,
                          mesas: mesas,
                        ),
                        icon: const Icon(Icons.swap_horiz),
                        label: const Text('Escolher outra mesa'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Conflitos de sincronização')),
      body: StreamBuilder<List<Mesa>>(
        stream: _streamMesas,
        builder: (context, snapshotMesas) {
          final mesas = snapshotMesas.data ?? <Mesa>[];

          return StreamBuilder<List<ConflitoSincronizacao>>(
            stream: _streamConflitos,
            builder: (context, snapshotConflitos) {
              if (snapshotConflitos.connectionState ==
                      ConnectionState.waiting &&
                  !snapshotConflitos.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshotConflitos.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Não foi possível carregar os conflitos. Verifique a internet e tente novamente.\n\n${snapshotConflitos.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final conflitos =
                  snapshotConflitos.data ?? <ConflitoSincronizacao>[];

              if (conflitos.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: Colors.green,
                          size: 58,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Nenhum conflito pendente.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: conflitos.length,
                itemBuilder: (context, index) {
                  return _construirCard(
                    conflito: conflitos[index],
                    mesas: mesas,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
