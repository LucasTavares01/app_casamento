import 'package:flutter/material.dart';

import '../modelos/modelos.dart';
import '../servicos/supabase_servico.dart';

class AbaRecepcao extends StatefulWidget {
  const AbaRecepcao({super.key});

  @override
  State<AbaRecepcao> createState() => _AbaRecepcaoState();
}

class _AbaRecepcaoState extends State<AbaRecepcao> {
  final SupabaseServico _servico = SupabaseServico();

  late final Stream<List<Mesa>> _streamMesas;
  late final Stream<List<Convidado>> _streamConvidados;
  late final Stream<List<UsuarioApp>> _streamUsuarios;
  late final Stream<List<EventoCheckin>> _streamEventos;

  String _textoBusca = '';
  String? _mesaFiltroId;

  final TextEditingController _controladorBusca = TextEditingController();
  final FocusNode _focoBusca = FocusNode();

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

  @override
  void initState() {
    super.initState();

    _streamMesas = _servico.listarMesas();
    _streamConvidados = _servico.listarConvidados();
    _streamUsuarios = _servico.listarUsuariosApp();
    _streamEventos = _servico.listarEventosCheckin();
  }

  @override
  void dispose() {
    _controladorBusca.dispose();
    _focoBusca.dispose();
    super.dispose();
  }

  void _removerFocoBusca() {
    _focoBusca.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _confirmarChegada(Convidado convidado) async {
    try {
      await _servico.confirmarChegada(convidado.id);
    } catch (erro) {
      _mostrarErro('Não foi possível confirmar a chegada: $erro');
    }
  }

  Future<void> _removerChegada(Convidado convidado) async {
    try {
      await _servico.removerChegada(convidado.id);
    } catch (erro) {
      _mostrarErro('Não foi possível remover a chegada: $erro');
    }
  }

  Future<void> _resolverConflito({
    required Convidado convidado,
    required bool presente,
  }) async {
    try {
      await _servico.resolverConflito(
        convidadoId: convidado.id,
        presente: presente,
      );
    } catch (erro) {
      _mostrarErro('Não foi possível resolver o conflito: $erro');
    }
  }

  void _mostrarConfirmacao(Convidado convidado) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar chegada'),
          content: Text('Deseja confirmar a chegada de ${convidado.nome}?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _confirmarChegada(convidado);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text(
                'Confirmar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _mostrarDesfazerChegada(Convidado convidado) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Desfazer check-in'),
          content: Text(
            'Deseja remover o status de chegada de ${convidado.nome}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _removerChegada(convidado);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Remover',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _mostrarConfirmacaoResolucao({
    required Convidado convidado,
    required bool presente,
  }) {
    final estadoEscolhido = presente
        ? 'confirmar que o convidado chegou'
        : 'confirmar que o convidado não chegou';

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Resolver conflito'),
          content: Text(
            'Deseja $estadoEscolhido?\n\n'
            'As ações anteriores continuarão disponíveis no histórico.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);

                _resolverConflito(convidado: convidado, presente: presente);
              },
              child: const Text('Resolver'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarHistorico({
    required Convidado convidado,
    required List<EventoCheckin> eventos,
    required Map<String, String> usuariosPorId,
  }) {
    final eventosOrdenados = List<EventoCheckin>.from(eventos)
      ..sort((primeiro, segundo) {
        return segundo.dataDispositivo.compareTo(primeiro.dataDispositivo);
      });

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Histórico de ${convidado.nome}'),
          content: SizedBox(
            width: double.maxFinite,
            child: eventosOrdenados.isEmpty
                ? const Text('Nenhuma ação registrada.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: eventosOrdenados.length,
                    separatorBuilder: (context, index) {
                      return const Divider();
                    },
                    itemBuilder: (context, index) {
                      final evento = eventosOrdenados[index];

                      final nomeUsuario =
                          usuariosPorId[evento.usuarioId] ??
                          'Usuário desconhecido';

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          _iconeDoEvento(evento),
                          color: _corDoEvento(evento),
                        ),
                        title: Text('$nomeUsuario ${evento.descricaoAcao}.'),
                        subtitle: Text(
                          '${_formatarDataHora(evento.dataDispositivo)}\n'
                          '${evento.sincronizado ? 'Sincronizado' : 'Aguardando sincronização'}',
                        ),
                        isThreeLine: true,
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  IconData _iconeDoEvento(EventoCheckin evento) {
    switch (evento.tipoAcao) {
      case 'confirmou_chegada':
        return Icons.how_to_reg;

      case 'removeu_chegada':
        return Icons.person_off;

      case 'resolveu_como_presente':
        return Icons.verified;

      case 'resolveu_como_ausente':
        return Icons.cancel;

      default:
        return Icons.history;
    }
  }

  Color _corDoEvento(EventoCheckin evento) {
    return evento.estadoResultante ? Colors.green : Colors.red;
  }

  String _formatarDataHora(DateTime data) {
    final dataLocal = data.toLocal();

    final dia = dataLocal.day.toString().padLeft(2, '0');
    final mes = dataLocal.month.toString().padLeft(2, '0');
    final ano = dataLocal.year.toString();

    final hora = dataLocal.hour.toString().padLeft(2, '0');
    final minuto = dataLocal.minute.toString().padLeft(2, '0');

    return '$dia/$mes/$ano às $hora:$minuto';
  }

  String _textoQuantidadeLugares(Mesa mesa) {
    final detalhe = mesa.detalhe?.trim();

    if (detalhe == null || detalhe.isEmpty) {
      return 'Lugares não informados';
    }

    return detalhe;
  }

  String _nomesDosEventos({
    required List<EventoCheckin> eventos,
    required Map<String, String> usuariosPorId,
  }) {
    final nomes = <String>[];

    for (final evento in eventos) {
      final nome = usuariosPorId[evento.usuarioId] ?? 'Usuário desconhecido';

      if (!nomes.contains(nome)) {
        nomes.add(nome);
      }
    }

    if (nomes.isEmpty) {
      return 'Usuário desconhecido';
    }

    if (nomes.length == 1) {
      return nomes.first;
    }

    if (nomes.length == 2) {
      return '${nomes[0]} e ${nomes[1]}';
    }

    final inicio = nomes.sublist(0, nomes.length - 1);

    return '${inicio.join(', ')} e ${nomes.last}';
  }

  List<EventoCheckin> _obterEventosAtuais({
    required Convidado convidado,
    required List<EventoCheckin> todosEventos,
  }) {
    final idsAtuais = convidado.eventosAtuaisIds.toSet();

    if (idsAtuais.isEmpty) {
      return [];
    }

    final eventosAtuais = todosEventos.where((evento) {
      return evento.convidadoId == convidado.id &&
          idsAtuais.contains(evento.id);
    }).toList();

    eventosAtuais.sort((primeiro, segundo) {
      return primeiro.dataDispositivo.compareTo(segundo.dataDispositivo);
    });

    return eventosAtuais;
  }

  Widget _construirCabecalhoCard({
    required Convidado convidado,
    required Mesa mesa,
  }) {
    final possuiMesa = mesa.id.isNotEmpty && mesa.numero >= 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              convidado.nome,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                height: 1.1,
                color: convidado.chegou && !convidado.temConflito
                    ? Colors.black54
                    : Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(width: 1, height: 52, color: Colors.black12),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  possuiMesa ? 'MESA ${mesa.numero}' : 'SEM MESA',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  possuiMesa ? _textoQuantidadeLugares(mesa) : 'Não definida',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          if (convidado.temConflito)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.warning_amber, color: Colors.amber, size: 38),
            )
          else if (convidado.chegou)
            IconButton(
              tooltip: 'Remover chegada',
              onPressed: () {
                _mostrarDesfazerChegada(convidado);
              },
              icon: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 38,
              ),
            )
          else
            IconButton(
              tooltip: 'Confirmar chegada',
              onPressed: () {
                _mostrarConfirmacao(convidado);
              },
              icon: const Icon(
                Icons.how_to_reg,
                color: Colors.deepPurple,
                size: 35,
              ),
            ),
        ],
      ),
    );
  }

  Widget _construirLinhaEstadoEHistorico({
    required Convidado convidado,
    required List<EventoCheckin> eventosAtuais,
    required List<EventoCheckin> eventosDoConvidado,
    required Map<String, String> usuariosPorId,
  }) {
    String? textoEstado;
    IconData? iconeEstado;
    Color? corEstado;

    if (eventosAtuais.isEmpty) {
      if (convidado.chegou) {
        textoEstado = 'Chegada confirmada antes do histórico de autoria.';
        iconeEstado = Icons.check_circle;
        corEstado = Colors.green.shade800;
      }
    } else {
      final nomes = _nomesDosEventos(
        eventos: eventosAtuais,
        usuariosPorId: usuariosPorId,
      );

      final possuiResolucao = eventosAtuais.any((evento) {
        return evento.tipoAcao == 'resolveu_como_presente' ||
            evento.tipoAcao == 'resolveu_como_ausente';
      });

      if (convidado.chegou) {
        textoEstado = possuiResolucao
            ? 'Definido como presente por: $nomes'
            : 'Confirmado por: $nomes';

        iconeEstado = Icons.check_circle;
        corEstado = Colors.green.shade800;
      } else {
        textoEstado = possuiResolucao
            ? 'Definido como não presente por: $nomes'
            : 'Removido por: $nomes';

        iconeEstado = Icons.person_off;
        corEstado = Colors.red.shade700;
      }
    }

    final possuiHistorico = eventosDoConvidado.isNotEmpty;

    if (textoEstado == null && !possuiHistorico) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 7, 6, 7),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: textoEstado == null
                ? const SizedBox.shrink()
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(iconeEstado, size: 18, color: corEstado),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          textoEstado,
                          style: TextStyle(
                            color: corEstado,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          if (possuiHistorico)
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(0, 38),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () {
                _mostrarHistorico(
                  convidado: convidado,
                  eventos: eventosDoConvidado,
                  usuariosPorId: usuariosPorId,
                );
              },
              icon: const Icon(Icons.history, size: 18),
              label: const Text(
                'Ver histórico',
                style: TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _construirPainelConflito({
    required Convidado convidado,
    required List<EventoCheckin> eventosAtuais,
    required List<EventoCheckin> eventosDoConvidado,
    required Map<String, String> usuariosPorId,
  }) {
    final confirmacoes = eventosAtuais.where((evento) {
      return evento.estadoResultante;
    }).toList();

    final remocoes = eventosAtuais.where((evento) {
      return !evento.estadoResultante;
    }).toList();

    final nomesConfirmacoes = _nomesDosEventos(
      eventos: confirmacoes,
      usuariosPorId: usuariosPorId,
    );

    final nomesRemocoes = _nomesDosEventos(
      eventos: remocoes,
      usuariosPorId: usuariosPorId,
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber.shade700),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.amber.shade900),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Conflito de check-in',
                  style: TextStyle(
                    color: Colors.amber.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              if (eventosDoConvidado.isNotEmpty)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 36),
                  ),
                  onPressed: () {
                    _mostrarHistorico(
                      convidado: convidado,
                      eventos: eventosDoConvidado,
                      usuariosPorId: usuariosPorId,
                    );
                  },
                  icon: const Icon(Icons.history, size: 17),
                  label: const Text(
                    'Histórico',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Confirmaram: $nomesConfirmacoes'),
          Text('Removeram: $nomesRemocoes'),
          const SizedBox(height: 12),
          const Text(
            'Escolha a situação correta:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  _mostrarConfirmacaoResolucao(
                    convidado: convidado,
                    presente: false,
                  );
                },
                icon: const Icon(Icons.person_off),
                label: const Text('Não chegou'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  _mostrarConfirmacaoResolucao(
                    convidado: convidado,
                    presente: true,
                  );
                },
                icon: const Icon(Icons.how_to_reg),
                label: const Text('Chegou'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construirCardConvidado({
    required Convidado convidado,
    required Mesa mesa,
    required List<EventoCheckin> todosEventos,
    required Map<String, String> usuariosPorId,
  }) {
    var corFundo = Colors.white;

    if (mesa.numero >= 0) {
      corFundo = _coresPasteis[mesa.numero % _coresPasteis.length];
    }

    final eventosDoConvidado = todosEventos.where((evento) {
      return evento.convidadoId == convidado.id;
    }).toList();

    final eventosAtuais = _obterEventosAtuais(
      convidado: convidado,
      todosEventos: todosEventos,
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: corFundo,
      elevation: convidado.temConflito
          ? 5
          : convidado.chegou
          ? 1
          : 3,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _construirCabecalhoCard(convidado: convidado, mesa: mesa),
          if (convidado.temConflito)
            _construirPainelConflito(
              convidado: convidado,
              eventosAtuais: eventosAtuais,
              eventosDoConvidado: eventosDoConvidado,
              usuariosPorId: usuariosPorId,
            )
          else
            _construirLinhaEstadoEHistorico(
              convidado: convidado,
              eventosAtuais: eventosAtuais,
              eventosDoConvidado: eventosDoConvidado,
              usuariosPorId: usuariosPorId,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Mesa>>(
      stream: _streamMesas,
      builder: (context, snapMesas) {
        if (snapMesas.hasError) {
          return Center(
            child: Text('Erro ao carregar mesas: ${snapMesas.error}'),
          );
        }

        if (!snapMesas.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final mesas = snapMesas.data!;

        return StreamBuilder<List<UsuarioApp>>(
          stream: _streamUsuarios,
          builder: (context, snapUsuarios) {
            if (snapUsuarios.hasError) {
              return Center(
                child: Text('Erro ao carregar usuários: ${snapUsuarios.error}'),
              );
            }

            if (!snapUsuarios.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final usuarios = snapUsuarios.data!;

            final usuariosPorId = <String, String>{
              for (final usuario in usuarios) usuario.id: usuario.nome,
            };

            return StreamBuilder<List<EventoCheckin>>(
              stream: _streamEventos,
              builder: (context, snapEventos) {
                if (snapEventos.hasError) {
                  return Center(
                    child: Text(
                      'Erro ao carregar histórico: ${snapEventos.error}',
                    ),
                  );
                }

                if (!snapEventos.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final todosEventos = snapEventos.data!;

                return StreamBuilder<List<Convidado>>(
                  stream: _streamConvidados,
                  builder: (context, snapConvidados) {
                    if (snapConvidados.hasError) {
                      return Center(
                        child: Text(
                          'Erro ao carregar convidados: '
                          '${snapConvidados.error}',
                        ),
                      );
                    }

                    if (!snapConvidados.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final convidadosFiltrados = snapConvidados.data!.where((
                      convidado,
                    ) {
                      final bateNome = convidado.nome.toLowerCase().contains(
                        _textoBusca,
                      );

                      final bateMesa =
                          _mesaFiltroId == null ||
                          convidado.mesaId == _mesaFiltroId;

                      return bateNome && bateMesa;
                    }).toList();

                    convidadosFiltrados.sort((primeiro, segundo) {
                      final mesaPrimeiro = mesas.firstWhere(
                        (mesa) => mesa.id == primeiro.mesaId,
                        orElse: () => Mesa(id: '', numero: 99999),
                      );

                      final mesaSegundo = mesas.firstWhere(
                        (mesa) => mesa.id == segundo.mesaId,
                        orElse: () => Mesa(id: '', numero: 99999),
                      );

                      final comparacaoMesa = mesaPrimeiro.numero.compareTo(
                        mesaSegundo.numero,
                      );

                      if (comparacaoMesa != 0) {
                        return comparacaoMesa;
                      }

                      return primeiro.nome.toLowerCase().compareTo(
                        segundo.nome.toLowerCase(),
                      );
                    });

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                          child: TextField(
                            controller: _controladorBusca,
                            focusNode: _focoBusca,
                            autofocus: false,
                            textInputAction: TextInputAction.search,
                            onTapOutside: (_) => _removerFocoBusca(),
                            decoration: InputDecoration(
                              hintText: 'Buscar convidado por nome...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              isDense: true,
                            ),
                            onChanged: (valor) {
                              setState(() {
                                _textoBusca = valor.toLowerCase();
                              });
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                          child: DropdownButtonFormField<String?>(
                            key: ValueKey('filtro-mesa-$_mesaFiltroId'),
                            initialValue: _mesaFiltroId,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.filter_list),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                            ),
                            isExpanded: true,
                            onTap: _removerFocoBusca,
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text(
                                  'Todas as mesas',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              ...mesas.map((mesa) {
                                return DropdownMenuItem<String?>(
                                  value: mesa.id,
                                  child: Text(mesa.nomeExibicao),
                                );
                              }),
                            ],
                            onChanged: (valor) {
                              _removerFocoBusca();

                              setState(() {
                                _mesaFiltroId = valor;
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: convidadosFiltrados.isEmpty
                              ? const Center(
                                  child: Text('Nenhum convidado encontrado.'),
                                )
                              : ListView.builder(
                                  keyboardDismissBehavior:
                                      ScrollViewKeyboardDismissBehavior.onDrag,
                                  itemCount: convidadosFiltrados.length,
                                  padding: const EdgeInsets.only(bottom: 12),
                                  itemBuilder: (context, index) {
                                    final convidado =
                                        convidadosFiltrados[index];

                                    final mesa = mesas.firstWhere(
                                      (item) => item.id == convidado.mesaId,
                                      orElse: () => Mesa(id: '', numero: -1),
                                    );

                                    return _construirCardConvidado(
                                      convidado: convidado,
                                      mesa: mesa,
                                      todosEventos: todosEventos,
                                      usuariosPorId: usuariosPorId,
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
