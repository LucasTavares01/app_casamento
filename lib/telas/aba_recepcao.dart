import 'dart:async';

import 'package:flutter/material.dart';

import '../modelos/modelos.dart';
import '../servicos/casamento_atual_servico.dart';
import '../servicos/supabase_servico.dart';
import 'tela_conflitos.dart';
import 'tela_convites_online.dart';

/// Mantém uma única leitura da origem e repete o último valor para cada nova
/// montagem da aba. Isso evita tanto listeners duplicados quanto carregamento
/// infinito quando o TabBarView remonta a Recepção.
class _StreamComUltimoValor<T> {
  final StreamController<T> _controlador;
  late final StreamSubscription<T> _assinatura;
  T? _ultimoValor;
  bool _temUltimoValor = false;
  bool _encerrado = false;

  _StreamComUltimoValor(Stream<T> origem)
    : _controlador = StreamController<T>.broadcast(sync: true) {
    _controlador.onListen = () {
      if (_temUltimoValor && !_encerrado) {
        _controlador.add(_ultimoValor as T);
      }
    };

    _assinatura = origem.listen(
      (valor) {
        _ultimoValor = valor;
        _temUltimoValor = true;
        if (_controlador.hasListener && !_encerrado) {
          _controlador.add(valor);
        }
      },
      onError: (Object erro, StackTrace stackTrace) {
        if (_controlador.hasListener && !_encerrado) {
          _controlador.addError(erro, stackTrace);
        }
      },
    );
  }

  Stream<T> get stream => _controlador.stream;

  Future<void> dispose() async {
    if (_encerrado) {
      return;
    }
    _encerrado = true;
    await _assinatura.cancel();
    await _controlador.close();
  }
}

class _AlertaConvidadoSincronizacao {
  final String id;
  final String titulo;
  final String mensagem;
  final bool conflitoServidor;
  final DateTime criadoEm;

  const _AlertaConvidadoSincronizacao({
    required this.id,
    required this.titulo,
    required this.mensagem,
    required this.conflitoServidor,
    required this.criadoEm,
  });
}

class AbaRecepcao extends StatefulWidget {
  const AbaRecepcao({super.key});

  @override
  State<AbaRecepcao> createState() => _AbaRecepcaoState();
}

class _AbaRecepcaoState extends State<AbaRecepcao> {
  final SupabaseServico _servico = SupabaseServico();

  late final _StreamComUltimoValor<List<Mesa>> _streamMesas;
  late final _StreamComUltimoValor<List<Convidado>> _streamConvidados;
  late final _StreamComUltimoValor<List<UsuarioApp>> _streamUsuarios;
  late final _StreamComUltimoValor<List<EventoCheckin>> _streamEventos;
  late final _StreamComUltimoValor<List<ConflitoSincronizacao>>
  _streamConflitos;
  late final _StreamComUltimoValor<List<ErroSincronizacaoLocal>>
  _streamErrosSincronizacao;

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

    _streamMesas = _StreamComUltimoValor(_servico.listarMesas());
    _streamConvidados = _StreamComUltimoValor(_servico.listarConvidados());
    _streamUsuarios = _StreamComUltimoValor(_servico.listarUsuariosApp());
    _streamEventos = _StreamComUltimoValor(_servico.listarEventosCheckin());
    _streamConflitos = _StreamComUltimoValor(
      _servico.listarConflitosPendentes(),
    );
    _streamErrosSincronizacao = _StreamComUltimoValor(
      _servico.listarErrosSincronizacaoLocais(),
    );
  }

  @override
  void dispose() {
    _controladorBusca.dispose();
    _focoBusca.dispose();
    unawaited(_streamMesas.dispose());
    unawaited(_streamConvidados.dispose());
    unawaited(_streamUsuarios.dispose());
    unawaited(_streamEventos.dispose());
    unawaited(_streamConflitos.dispose());
    unawaited(_streamErrosSincronizacao.dispose());
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

  String _mensagemConflitoRecepcao(ConflitoSincronizacao conflito) {
    if (conflito.ehAvisoMesaExcluidaRevisao) {
      return 'A mesa onde este convidado estava foi excluída. '
          'Toque aqui e selecione uma nova mesa.';
    }

    if (conflito.envolveMesaExcluida) {
      return 'A mesa onde este convidado estava foi excluída. '
          'Abra os conflitos para revisar o que aconteceu.';
    }

    final tipo = conflito.tipo.toLowerCase();
    if (tipo.contains('convidado_alteracao_concorrente')) {
      return 'Este convidado foi alterado por dois usuários. '
          'Escolha qual mudança deve permanecer.';
    }

    if (tipo.contains('checkin')) {
      return 'A presença deste convidado recebeu alterações diferentes. '
          'Escolha qual mudança deve permanecer.';
    }

    if (tipo.contains('mesa')) {
      return 'Existe um conflito envolvendo a mesa deste convidado.';
    }

    return 'Existe um conflito de sincronização neste convidado.';
  }

  Map<String, List<_AlertaConvidadoSincronizacao>> _montarAlertasPorConvidado({
    required List<Convidado> convidados,
    required List<ConflitoSincronizacao> conflitos,
    required List<ErroSincronizacaoLocal> erros,
  }) {
    final alertas = <String, List<_AlertaConvidadoSincronizacao>>{};

    void adicionar(String convidadoId, _AlertaConvidadoSincronizacao alerta) {
      if (convidadoId.trim().isEmpty) return;
      alertas.putIfAbsent(convidadoId, () => []).add(alerta);
    }

    for (final conflito in conflitos) {
      final ids = <String>{...conflito.convidadosAfetadosIds};

      if (conflito.envolveMesaExcluida && conflito.mesaId != null) {
        ids.addAll(
          convidados
              .where((convidado) => convidado.mesaId == conflito.mesaId)
              .map((convidado) => convidado.id),
        );
      }

      for (final convidadoId in ids) {
        adicionar(
          convidadoId,
          _AlertaConvidadoSincronizacao(
            id: conflito.id,
            titulo: conflito.envolveMesaExcluida
                ? 'Mesa excluída'
                : 'Conflito de sincronização',
            mensagem: _mensagemConflitoRecepcao(conflito),
            conflitoServidor: true,
            criadoEm: conflito.criadoEm,
          ),
        );
      }
    }

    for (final erro in erros) {
      final ids = <String>{...erro.convidadosAfetadosIds};

      if (erro.entidade == 'mesa') {
        ids.addAll(
          convidados
              .where((convidado) => convidado.mesaId == erro.entidadeId)
              .map((convidado) => convidado.id),
        );
      }

      for (final convidadoId in ids) {
        adicionar(
          convidadoId,
          _AlertaConvidadoSincronizacao(
            id: erro.id,
            titulo: 'Erro de sincronização',
            mensagem:
                'A última alteração deste convidado ainda não conseguiu ser '
                'enviada. Toque no aviso vermelho do topo para ver o erro.',
            conflitoServidor: false,
            criadoEm: erro.criadoEm,
          ),
        );
      }
    }

    for (final lista in alertas.values) {
      lista.sort((a, b) => b.criadoEm.compareTo(a.criadoEm));
    }

    return alertas;
  }

  Future<void> _abrirConflitos(String? conflitoId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TelaConflitos(conflitoIdInicial: conflitoId),
      ),
    );
  }

  Widget _construirPainelAlertas(List<_AlertaConvidadoSincronizacao> alertas) {
    if (alertas.isEmpty) return const SizedBox.shrink();

    final alerta = alertas.first;
    final quantidadeExtra = alertas.length - 1;
    final somenteLeitura = CasamentoAtualServico.instance.somenteLeitura;

    return Material(
      color: Colors.red.shade50,
      child: InkWell(
        onTap: !somenteLeitura && alerta.conflitoServidor
            ? () => _abrirConflitos(alerta.id)
            : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.red.shade200),
              bottom: BorderSide(color: Colors.red.shade200),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      somenteLeitura
                          ? 'Histórico preservado (somente leitura)'
                          : alerta.titulo,
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      somenteLeitura
                          ? 'Este casamento foi encerrado; nenhuma alteração '
                                'pode ser registrada.'
                          : alerta.mensagem,
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontSize: 13,
                      ),
                    ),
                    if (quantidadeExtra > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '+ $quantidadeExtra outro(s) aviso(s) neste convidado',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (alerta.conflitoServidor && !somenteLeitura)
                const Padding(
                  padding: EdgeInsets.only(left: 6, top: 8),
                  child: Icon(Icons.chevron_right),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirCabecalhoCard({
    required Convidado convidado,
    required Mesa mesa,
    required bool possuiAlerta,
  }) {
    final possuiMesa = mesa.id.isNotEmpty && mesa.numero >= 0;
    final temAlerta = convidado.temConflito || possuiAlerta;
    final somenteLeitura = CasamentoAtualServico.instance.somenteLeitura;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (temAlerta) ...[
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.priority_high_rounded,
                color: Colors.white,
                size: 25,
              ),
            ),
            const SizedBox(width: 9),
          ],
          Expanded(
            child: Text(
              convidado.nome,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                height: 1.1,
                color: convidado.chegou && !temAlerta
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
          if (temAlerta)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.warning_amber, color: Colors.amber, size: 38),
            )
          else if (somenteLeitura)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.lock_outline, color: Colors.grey, size: 34),
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

  Widget _construirCardConvidado({
    required Convidado convidado,
    required Mesa mesa,
    required List<EventoCheckin> todosEventos,
    required Map<String, String> usuariosPorId,
    required List<_AlertaConvidadoSincronizacao> alertas,
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

    final temAlerta = convidado.temConflito || alertas.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: corFundo,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: temAlerta
            ? BorderSide(color: Colors.red.shade600, width: 2.5)
            : BorderSide.none,
      ),
      elevation: temAlerta
          ? 6
          : convidado.chegou
          ? 1
          : 3,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _construirCabecalhoCard(
            convidado: convidado,
            mesa: mesa,
            possuiAlerta: alertas.isNotEmpty,
          ),
          if (alertas.isNotEmpty) _construirPainelAlertas(alertas),
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

  Widget _conteudoRecepcao() {
    return StreamBuilder<List<Mesa>>(
      stream: _streamMesas.stream,
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
          stream: _streamUsuarios.stream,
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
              stream: _streamEventos.stream,
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
                  stream: _streamConvidados.stream,
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

                    final todosConvidados = snapConvidados.data!;

                    return StreamBuilder<List<ConflitoSincronizacao>>(
                      stream: _streamConflitos.stream,
                      builder: (context, snapConflitos) {
                        final conflitos =
                            snapConflitos.data ?? <ConflitoSincronizacao>[];

                        return StreamBuilder<List<ErroSincronizacaoLocal>>(
                          stream: _streamErrosSincronizacao.stream,
                          builder: (context, snapErros) {
                            final erros =
                                snapErros.data ?? <ErroSincronizacaoLocal>[];

                            final alertasPorConvidado =
                                _montarAlertasPorConvidado(
                                  convidados: todosConvidados,
                                  conflitos: conflitos,
                                  erros: erros,
                                );

                            final convidadosFiltrados = todosConvidados.where((
                              convidado,
                            ) {
                              final bateNome = convidado.nome
                                  .toLowerCase()
                                  .contains(_textoBusca);

                              final bateMesa =
                                  _mesaFiltroId == null ||
                                  convidado.mesaId == _mesaFiltroId;

                              return bateNome && bateMesa;
                            }).toList();

                            convidadosFiltrados.sort((primeiro, segundo) {
                              final primeiroComAlerta =
                                  primeiro.temConflito ||
                                  (alertasPorConvidado[primeiro.id]
                                          ?.isNotEmpty ??
                                      false);

                              final segundoComAlerta =
                                  segundo.temConflito ||
                                  (alertasPorConvidado[segundo.id]
                                          ?.isNotEmpty ??
                                      false);

                              if (primeiroComAlerta != segundoComAlerta) {
                                return primeiroComAlerta ? -1 : 1;
                              }

                              final mesaPrimeiro = mesas.firstWhere(
                                (mesa) => mesa.id == primeiro.mesaId,
                                orElse: () => Mesa(id: '', numero: 99999),
                              );

                              final mesaSegundo = mesas.firstWhere(
                                (mesa) => mesa.id == segundo.mesaId,
                                orElse: () => Mesa(id: '', numero: 99999),
                              );

                              final comparacaoMesa = mesaPrimeiro.numero
                                  .compareTo(mesaSegundo.numero);

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
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    12,
                                    12,
                                    6,
                                  ),
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
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    0,
                                    12,
                                    6,
                                  ),
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
                                      contentPadding:
                                          const EdgeInsets.symmetric(
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
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
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
                                          child: Text(
                                            'Nenhum convidado encontrado.',
                                          ),
                                        )
                                      : ListView.builder(
                                          keyboardDismissBehavior:
                                              ScrollViewKeyboardDismissBehavior
                                                  .onDrag,
                                          itemCount: convidadosFiltrados.length,
                                          padding: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          itemBuilder: (context, index) {
                                            final convidado =
                                                convidadosFiltrados[index];

                                            final mesa = mesas.firstWhere(
                                              (item) =>
                                                  item.id == convidado.mesaId,
                                              orElse: () =>
                                                  Mesa(id: '', numero: -1),
                                            );

                                            return _construirCardConvidado(
                                              convidado: convidado,
                                              mesa: mesa,
                                              todosEventos: todosEventos,
                                              usuariosPorId: usuariosPorId,
                                              alertas:
                                                  alertasPorConvidado[convidado
                                                      .id] ??
                                                  const [],
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
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          SizedBox(
            height: 58,
            child: TabBar(
              labelPadding: EdgeInsets.zero,
              indicatorPadding: EdgeInsets.zero,
              tabs: [
                Tab(
                  height: 58,
                  iconMargin: EdgeInsets.zero,
                  icon: Icon(Icons.how_to_reg, size: 25),
                  text: 'RECEPÇÃO',
                ),
                Tab(
                  height: 58,
                  iconMargin: EdgeInsets.zero,
                  icon: Icon(Icons.mail_outline, size: 25),
                  text: 'CONVITES ONLINE',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _conteudoRecepcao(),
                const TelaConvitesOnline(mostrarAppBar: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
