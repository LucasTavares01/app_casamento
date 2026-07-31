import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../modelos/modelos.dart';
import '../servicos/supabase_servico.dart';

class AbaCadastro extends StatefulWidget {
  const AbaCadastro({super.key});

  @override
  State<AbaCadastro> createState() => _AbaCadastroState();
}

class _AbaCadastroState extends State<AbaCadastro> {
  final SupabaseServico _servico = SupabaseServico();

  late final Stream<List<Mesa>> _streamMesas;
  late final Stream<List<Convidado>> _streamConvidados;
  final TextEditingController _buscaConvidadosController =
      TextEditingController();

  final Set<String> _mesasSelecionadas = <String>{};
  final Set<String> _convidadosSelecionados = <String>{};

  bool _excluindoMesas = false;
  bool _excluindoConvidados = false;
  String _textoBuscaConvidados = '';

  bool get _modoSelecaoMesas => _mesasSelecionadas.isNotEmpty;

  bool get _modoSelecaoConvidados => _convidadosSelecionados.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _streamMesas = _servico.listarMesas();
    _streamConvidados = _servico.listarConvidados();
  }

  @override
  void dispose() {
    _buscaConvidadosController.dispose();
    super.dispose();
  }

  void _dialogMesa({Mesa? mesaEdit}) {
    final numeroCtrl = TextEditingController(
      text: mesaEdit != null ? mesaEdit.numero.toString() : '',
    );
    final detalheCtrl = TextEditingController(text: mesaEdit?.detalhe ?? '');

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
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
                  hintText: 'Detalhe (ex: 8 lugares) - Opcional',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final numero = int.tryParse(numeroCtrl.text.trim()) ?? 0;

                Navigator.pop(context);

                try {
                  if (mesaEdit == null) {
                    await _servico.adicionarMesa(numero, detalheCtrl.text);
                  } else {
                    await _servico.editarMesa(
                      mesaEdit.id,
                      numero,
                      detalheCtrl.text,
                    );
                  }
                } catch (erro) {
                  _mostrarErro('Não foi possível salvar a mesa: $erro');
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _dialogConfirmarExclusaoMesa(Mesa mesa) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir Mesa'),
          content: Text(
            'Tem certeza que deseja excluir a ${mesa.nomeExibicao}?\n\n'
            'Os convidados desta mesa ficarão sem mesa.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Excluir',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirmou != true) {
      return;
    }

    try {
      await _servico.excluirMesa(mesa.id);
    } catch (erro) {
      _mostrarErro('Não foi possível excluir a mesa: $erro');
    }
  }

  void _dialogConvidado(List<Mesa> mesas, {Convidado? convidadoEdit}) {
    final nomeCtrl = TextEditingController(text: convidadoEdit?.nome ?? '');
    const valorSemMesa = '__sem_mesa__';
    var valorMesaSelecionada = convidadoEdit?.mesaId ?? valorSemMesa;

    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
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
                    value: valorMesaSelecionada,
                    isExpanded: true,
                    hint: const Text('Selecionar Mesa (Opcional)'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: valorSemMesa,
                        child: Text('Sem mesa'),
                      ),
                      ...mesas.map((mesa) {
                        return DropdownMenuItem<String>(
                          value: mesa.id,
                          child: Text(mesa.nomeExibicao),
                        );
                      }),
                    ],
                    onChanged: (valor) {
                      setDialogState(() {
                        valorMesaSelecionada = valor ?? valorSemMesa;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);

                    try {
                      if (convidadoEdit == null) {
                        await _servico.adicionarConvidado(
                          nomeCtrl.text,
                          valorMesaSelecionada == valorSemMesa
                              ? null
                              : valorMesaSelecionada,
                        );
                      } else {
                        await _servico.editarConvidado(
                          convidadoEdit.id,
                          nomeCtrl.text,
                          valorMesaSelecionada == valorSemMesa
                              ? null
                              : valorMesaSelecionada,
                        );
                      }
                    } catch (erro) {
                      _mostrarErro(
                        'Não foi possível salvar o convidado: $erro',
                      );
                    }
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _dialogConfirmarExclusaoConvidado(Convidado convidado) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir Convidado'),
          content: Text(
            'Tem certeza que deseja excluir ${convidado.nome} da lista?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Excluir',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirmou != true) {
      return;
    }

    try {
      await _servico.excluirConvidado(convidado.id);
    } catch (erro) {
      _mostrarErro('Não foi possível excluir o convidado: $erro');
    }
  }

  void _alternarSelecaoMesa(String mesaId) {
    if (_excluindoMesas) {
      return;
    }

    setState(() {
      if (_mesasSelecionadas.contains(mesaId)) {
        _mesasSelecionadas.remove(mesaId);
      } else {
        _mesasSelecionadas.add(mesaId);
      }
    });
  }

  void _iniciarSelecaoMesa(String mesaId) {
    if (_excluindoMesas) {
      return;
    }

    setState(() {
      _mesasSelecionadas.add(mesaId);
    });
  }

  void _cancelarSelecaoMesas() {
    if (_excluindoMesas) {
      return;
    }

    setState(() {
      _mesasSelecionadas.clear();
    });
  }

  void _selecionarOuLimparTodasMesas(List<Mesa> mesas) {
    if (_excluindoMesas) {
      return;
    }

    final idsVisiveis = mesas.map((mesa) => mesa.id).toSet();
    final todasSelecionadas =
        idsVisiveis.isNotEmpty &&
        idsVisiveis.every(_mesasSelecionadas.contains);

    setState(() {
      if (todasSelecionadas) {
        _mesasSelecionadas.removeAll(idsVisiveis);
      } else {
        _mesasSelecionadas.addAll(idsVisiveis);
      }
    });
  }

  void _alternarSelecaoConvidado(String convidadoId) {
    if (_excluindoConvidados) {
      return;
    }

    setState(() {
      if (_convidadosSelecionados.contains(convidadoId)) {
        _convidadosSelecionados.remove(convidadoId);
      } else {
        _convidadosSelecionados.add(convidadoId);
      }
    });
  }

  void _iniciarSelecaoConvidado(String convidadoId) {
    if (_excluindoConvidados) {
      return;
    }

    setState(() {
      _convidadosSelecionados.add(convidadoId);
    });
  }

  void _cancelarSelecaoConvidados() {
    if (_excluindoConvidados) {
      return;
    }

    setState(() {
      _convidadosSelecionados.clear();
    });
  }

  void _selecionarOuLimparTodosConvidados(List<Convidado> convidados) {
    if (_excluindoConvidados) {
      return;
    }

    final idsVisiveis = convidados.map((convidado) => convidado.id).toSet();

    final todosSelecionados =
        idsVisiveis.isNotEmpty &&
        idsVisiveis.every(_convidadosSelecionados.contains);

    setState(() {
      if (todosSelecionados) {
        _convidadosSelecionados.removeAll(idsVisiveis);
      } else {
        _convidadosSelecionados.addAll(idsVisiveis);
      }
    });
  }

  Future<void> _excluirMesasSelecionadas(List<Mesa> mesas) async {
    final mesasSelecionadas = mesas.where((mesa) {
      return _mesasSelecionadas.contains(mesa.id);
    }).toList();

    if (mesasSelecionadas.isEmpty || _excluindoMesas) {
      return;
    }

    final quantidade = mesasSelecionadas.length;

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            quantidade == 1
                ? 'Excluir mesa selecionada'
                : 'Excluir $quantidade mesas',
          ),
          content: Text(
            quantidade == 1
                ? 'A mesa selecionada será excluída. Os convidados dela ficarão sem mesa.'
                : 'As $quantidade mesas selecionadas serão excluídas. Os convidados delas ficarão sem mesa.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.delete),
              label: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmou != true || !mounted) {
      return;
    }

    setState(() {
      _excluindoMesas = true;
    });

    final idsComErro = <String>{};
    var excluidas = 0;

    for (final mesa in mesasSelecionadas) {
      try {
        await _servico.excluirMesa(mesa.id);
        excluidas++;
      } catch (_) {
        idsComErro.add(mesa.id);
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _excluindoMesas = false;
      _mesasSelecionadas
        ..clear()
        ..addAll(idsComErro);
    });

    if (idsComErro.isEmpty) {
      _mostrarSucesso(
        excluidas == 1
            ? '1 mesa excluída. A sincronização será feita automaticamente.'
            : '$excluidas mesas excluídas. A sincronização será feita automaticamente.',
      );
    } else {
      _mostrarErro(
        '$excluidas mesa(s) excluída(s), mas ${idsComErro.length} não puderam ser excluídas.',
      );
    }
  }

  Future<void> _excluirConvidadosSelecionados(
    List<Convidado> convidados,
  ) async {
    final convidadosSelecionados = convidados.where((convidado) {
      return _convidadosSelecionados.contains(convidado.id);
    }).toList();

    if (convidadosSelecionados.isEmpty || _excluindoConvidados) {
      return;
    }

    final quantidade = convidadosSelecionados.length;

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            quantidade == 1
                ? 'Excluir convidado selecionado'
                : 'Excluir $quantidade convidados',
          ),
          content: Text(
            quantidade == 1
                ? 'O convidado selecionado será removido da lista.'
                : 'Os $quantidade convidados selecionados serão removidos da lista.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.delete),
              label: const Text('Excluir'),
            ),
          ],
        );
      },
    );

    if (confirmou != true || !mounted) {
      return;
    }

    setState(() {
      _excluindoConvidados = true;
    });

    final idsComErro = <String>{};
    var excluidos = 0;

    for (final convidado in convidadosSelecionados) {
      try {
        await _servico.excluirConvidado(convidado.id);
        excluidos++;
      } catch (_) {
        idsComErro.add(convidado.id);
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _excluindoConvidados = false;
      _convidadosSelecionados
        ..clear()
        ..addAll(idsComErro);
    });

    if (idsComErro.isEmpty) {
      _mostrarSucesso(
        excluidos == 1
            ? '1 convidado excluído. A sincronização será feita automaticamente.'
            : '$excluidos convidados excluídos. A sincronização será feita automaticamente.',
      );
    } else {
      _mostrarErro(
        '$excluidos convidado(s) excluído(s), mas ${idsComErro.length} não puderam ser excluídos.',
      );
    }
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: Colors.red.shade700),
    );
  }

  void _mostrarSucesso(String mensagem) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: Colors.green.shade700),
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
      stream: _streamMesas,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Erro ao carregar mesas: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final mesas = snapshot.data!;

        _removerSelecoesInexistentesMesas(mesas);

        return Scaffold(
          floatingActionButton: _modoSelecaoMesas
              ? null
              : FloatingActionButton(
                  onPressed: _excluindoMesas
                      ? null
                      : () {
                          _dialogMesa();
                        },
                  child: const Icon(Icons.add),
                ),
          body: Column(
            children: [
              if (_modoSelecaoMesas) _barraSelecaoMesas(mesas),
              Expanded(
                child: mesas.isEmpty
                    ? const Center(child: Text('Nenhuma mesa cadastrada.'))
                    : ListView.separated(
                        itemCount: mesas.length,
                        separatorBuilder: (context, index) {
                          return const Divider(height: 1);
                        },
                        itemBuilder: (context, index) {
                          final mesa = mesas[index];
                          final selecionada = _mesasSelecionadas.contains(
                            mesa.id,
                          );

                          return Material(
                            color: selecionada
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Colors.transparent,
                            child: ListTile(
                              selected: selecionada,
                              onLongPress: () {
                                _iniciarSelecaoMesa(mesa.id);
                              },
                              onTap: _modoSelecaoMesas
                                  ? () {
                                      _alternarSelecaoMesa(mesa.id);
                                    }
                                  : null,
                              leading: _modoSelecaoMesas
                                  ? Checkbox(
                                      value: selecionada,
                                      onChanged: (_) {
                                        _alternarSelecaoMesa(mesa.id);
                                      },
                                    )
                                  : const Icon(Icons.grid_view),
                              title: Text(
                                mesa.nomeExibicao,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              trailing: _modoSelecaoMesas
                                  ? null
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          tooltip: 'Editar mesa',
                                          icon: const Icon(
                                            Icons.edit,
                                            color: Colors.grey,
                                          ),
                                          onPressed: () {
                                            _dialogMesa(mesaEdit: mesa);
                                          },
                                        ),
                                        IconButton(
                                          tooltip: 'Excluir mesa',
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.redAccent,
                                          ),
                                          onPressed: () {
                                            _dialogConfirmarExclusaoMesa(mesa);
                                          },
                                        ),
                                      ],
                                    ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _barraSelecaoMesas(List<Mesa> mesas) {
    final idsVisiveis = mesas.map((mesa) => mesa.id).toSet();
    final todasSelecionadas =
        idsVisiveis.isNotEmpty &&
        idsVisiveis.every(_mesasSelecionadas.contains);

    return Material(
      elevation: 2,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Cancelar seleção',
                onPressed: _excluindoMesas ? null : _cancelarSelecaoMesas,
                icon: const Icon(Icons.close),
              ),
              Expanded(
                child: Text(
                  '${_mesasSelecionadas.length} selecionada(s)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              TextButton.icon(
                onPressed: _excluindoMesas
                    ? null
                    : () {
                        _selecionarOuLimparTodasMesas(mesas);
                      },
                icon: Icon(
                  todasSelecionadas ? Icons.deselect : Icons.select_all,
                ),
                label: Text(todasSelecionadas ? 'Limpar' : 'Tudo'),
              ),
              if (_excluindoMesas)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              else
                IconButton(
                  tooltip: 'Excluir selecionadas',
                  onPressed: () {
                    _excluirMesasSelecionadas(mesas);
                  },
                  icon: const Icon(Icons.delete, color: Colors.red),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _listaConvidados() {
    return StreamBuilder<List<Mesa>>(
      stream: _streamMesas,
      builder: (context, snapMesas) {
        if (snapMesas.hasError) {
          return Center(
            child: Text('Erro ao carregar mesas: ${snapMesas.error}'),
          );
        }

        final mesas = snapMesas.data ?? <Mesa>[];

        return StreamBuilder<List<Convidado>>(
          stream: _streamConvidados,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Erro ao carregar convidados: ${snapshot.error}'),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final convidados = snapshot.data!;
            final termoBusca = _textoBuscaConvidados.trim().toLowerCase();
            final convidadosFiltrados = termoBusca.isEmpty
                ? convidados
                : convidados.where((convidado) {
                    return convidado.nome.toLowerCase().contains(termoBusca);
                  }).toList();

            _removerSelecoesInexistentesConvidados(convidados);

            return Scaffold(
              floatingActionButton: _modoSelecaoConvidados
                  ? null
                  : FloatingActionButton(
                      onPressed: _excluindoConvidados
                          ? null
                          : () {
                              _dialogConvidado(mesas);
                            },
                      child: const Icon(Icons.person_add),
                    ),
              body: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: TextField(
                      controller: _buscaConvidadosController,
                      enabled: !_excluindoConvidados,
                      onChanged: (texto) {
                        setState(() {
                          _textoBuscaConvidados = texto;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Pesquisar convidado',
                        hintText: 'Digite o nome do convidado',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _textoBuscaConvidados.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Limpar pesquisa',
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _buscaConvidadosController.clear();
                                  setState(() {
                                    _textoBuscaConvidados = '';
                                  });
                                },
                              ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  if (_modoSelecaoConvidados)
                    _barraSelecaoConvidados(convidadosFiltrados),
                  Expanded(
                    child: convidadosFiltrados.isEmpty
                        ? const Center(
                            child: Text('Nenhum convidado encontrado.'),
                          )
                        : ListView.separated(
                            itemCount: convidadosFiltrados.length,
                            separatorBuilder: (context, index) {
                              return const Divider(height: 1);
                            },
                            itemBuilder: (context, index) {
                              final convidado = convidadosFiltrados[index];
                              final selecionado = _convidadosSelecionados
                                  .contains(convidado.id);

                              var nomeMesa = 'Sem mesa';

                              if (convidado.mesaId != null) {
                                final mesa = mesas.firstWhere(
                                  (item) {
                                    return item.id == convidado.mesaId;
                                  },
                                  orElse: () {
                                    return Mesa(id: '', numero: 0);
                                  },
                                );

                                if (mesa.id.isNotEmpty) {
                                  nomeMesa = mesa.nomeExibicao;
                                }
                              }

                              return Material(
                                color: selecionado
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.primaryContainer
                                    : Colors.transparent,
                                child: ListTile(
                                  selected: selecionado,
                                  onLongPress: () {
                                    _iniciarSelecaoConvidado(convidado.id);
                                  },
                                  onTap: _modoSelecaoConvidados
                                      ? () {
                                          _alternarSelecaoConvidado(
                                            convidado.id,
                                          );
                                        }
                                      : null,
                                  leading: _modoSelecaoConvidados
                                      ? Checkbox(
                                          value: selecionado,
                                          onChanged: (_) {
                                            _alternarSelecaoConvidado(
                                              convidado.id,
                                            );
                                          },
                                        )
                                      : const CircleAvatar(
                                          child: Icon(Icons.person),
                                        ),
                                  title: Text(
                                    convidado.nome,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(nomeMesa),
                                  trailing: _modoSelecaoConvidados
                                      ? null
                                      : Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              tooltip: 'Editar convidado',
                                              icon: const Icon(
                                                Icons.edit,
                                                color: Colors.grey,
                                              ),
                                              onPressed: () {
                                                _dialogConvidado(
                                                  mesas,
                                                  convidadoEdit: convidado,
                                                );
                                              },
                                            ),
                                            IconButton(
                                              tooltip: 'Excluir convidado',
                                              icon: const Icon(
                                                Icons.delete,
                                                color: Colors.redAccent,
                                              ),
                                              onPressed: () {
                                                _dialogConfirmarExclusaoConvidado(
                                                  convidado,
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _barraSelecaoConvidados(List<Convidado> convidados) {
    final idsVisiveis = convidados.map((convidado) => convidado.id).toSet();

    final todosSelecionados =
        idsVisiveis.isNotEmpty &&
        idsVisiveis.every(_convidadosSelecionados.contains);

    return Material(
      elevation: 2,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Cancelar seleção',
                onPressed: _excluindoConvidados
                    ? null
                    : _cancelarSelecaoConvidados,
                icon: const Icon(Icons.close),
              ),
              Expanded(
                child: Text(
                  '${_convidadosSelecionados.length} selecionado(s)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              TextButton.icon(
                onPressed: _excluindoConvidados
                    ? null
                    : () {
                        _selecionarOuLimparTodosConvidados(convidados);
                      },
                icon: Icon(
                  todosSelecionados ? Icons.deselect : Icons.select_all,
                ),
                label: Text(todosSelecionados ? 'Limpar' : 'Tudo'),
              ),
              if (_excluindoConvidados)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                )
              else
                IconButton(
                  tooltip: 'Excluir selecionados',
                  onPressed: () {
                    _excluirConvidadosSelecionados(convidados);
                  },
                  icon: const Icon(Icons.delete, color: Colors.red),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _removerSelecoesInexistentesMesas(List<Mesa> mesas) {
    final idsExistentes = mesas.map((mesa) => mesa.id).toSet();

    if (_mesasSelecionadas.every(idsExistentes.contains)) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _mesasSelecionadas.retainAll(idsExistentes);
      });
    });
  }

  void _removerSelecoesInexistentesConvidados(List<Convidado> convidados) {
    final idsExistentes = convidados.map((convidado) => convidado.id).toSet();

    if (_convidadosSelecionados.every(idsExistentes.contains)) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _convidadosSelecionados.retainAll(idsExistentes);
      });
    });
  }
}
