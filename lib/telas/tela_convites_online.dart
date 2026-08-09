import 'dart:async';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../modelos/modelos.dart';
import '../servicos/casamento_atual_servico.dart';
import '../servicos/supabase_servico.dart';

class TelaConvitesOnline extends StatefulWidget {
  final bool mostrarAppBar;

  const TelaConvitesOnline({super.key, this.mostrarAppBar = true});

  @override
  State<TelaConvitesOnline> createState() => _TelaConvitesOnlineState();
}

class _ItemFilaConvite {
  final Convidado convidado;
  final String canal;

  const _ItemFilaConvite({required this.convidado, required this.canal});
}

class _TelaConvitesOnlineState extends State<TelaConvitesOnline> {
  final SupabaseServico _servico = SupabaseServico();
  late final Stream<List<Map<String, dynamic>>> _convitesStream;

  String _busca = '';
  String _filtroStatus = 'todos';
  bool _processandoEnvio = false;
  List<_ItemFilaConvite> _fila = const [];
  int _indiceFila = -1;
  bool _aguardandoContinuar = false;
  final Set<String> _adiadosNaFila = {};
  final Set<String> _pendentesNaFila = {};
  final Map<String, Map<String, String>> _convitesPreparados = {};
  final Set<String> _whatsAppsEnviadosLocalmente = {};

  bool get _filaAtiva => _indiceFila >= 0 && _indiceFila < _fila.length;

  /// Funcionários acompanham os convites, mas não podem disparar mensagens.
  /// Eventos encerrados também permanecem somente para leitura.
  bool get _podeEnviarConvites =>
      CasamentoAtualServico.instance.ehAdmin &&
      !CasamentoAtualServico.instance.somenteLeitura;

  @override
  void initState() {
    super.initState();
    _convitesStream = _servico.observarConvitesOnline();
  }

  void _atualizar() {
    if (!mounted) return;
    setState(() {});
  }

  String? _normalizarTelefone(String? valor) {
    final digitos = (valor ?? '').replaceAll(RegExp(r'\D'), '');
    if (digitos.isEmpty) return null;

    final comCodigo = digitos.startsWith('55') ? digitos : '55$digitos';
    if (comCodigo.length != 12 && comCodigo.length != 13) return null;
    return comCodigo;
  }

  List<String> _canaisEnviados(Map<String, dynamic>? convite) {
    final valor = convite?['canais_enviados'];
    if (valor is List) {
      return valor.map((item) => item.toString()).toList();
    }
    return const [];
  }

  bool _podeEnviar(Map<String, dynamic>? convite) {
    final status = convite?['status']?.toString();
    return status != 'confirmado' && status != 'recusado';
  }

  Future<List<_ItemFilaConvite>> _montarFilaWhatsApp(
    List<Convidado> convidados,
    Map<String, Map<String, dynamic>> convites,
  ) async {
    final fila = <_ItemFilaConvite>[];

    for (final convidado in convidados) {
      final convite = convites[convidado.id];
      if (_normalizarTelefone(convidado.whatsapp) != null &&
          _podeEnviar(convite) &&
          !_canaisEnviados(convite).contains('whatsapp') &&
          !_whatsAppsEnviadosLocalmente.contains(convidado.id)) {
        fila.add(_ItemFilaConvite(convidado: convidado, canal: 'whatsapp'));
      }
    }

    return fila;
  }

  Future<void> _iniciarFila(
    List<Convidado> convidados,
    Map<String, Map<String, dynamic>> convites,
  ) async {
    if (!_podeEnviarConvites || _processandoEnvio) return;

    final fila = await _montarFilaWhatsApp(convidados, convites);
    if (!mounted) return;

    if (fila.isEmpty) {
      _mostrarMensagem('Não há WhatsApps pendentes com número informado.');
      return;
    }

    setState(() {
      _fila = fila;
      _indiceFila = 0;
      _aguardandoContinuar = true;
      _adiadosNaFila.clear();
      _pendentesNaFila.clear();
    });

    await _mostrarConviteDaFila(primeiro: true);
  }

  Future<bool> _confirmarReenvio(
    Convidado convidado, {
    required String canal,
    required Map<String, dynamic>? convite,
  }) async {
    final resposta = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Reenviar convite?'),
          content: Text(
            '${convidado.nome} já respondeu: ${_status(convite)}. '
            'Deseja gerar um novo link e reenviar por $canal?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Reenviar'),
            ),
          ],
        );
      },
    );
    return resposta == true;
  }

  Future<void> _abrirItemDaFila() async {
    if (!mounted || !_filaAtiva || _aguardandoContinuar) return;

    final item = _fila[_indiceFila];
    await _prepararEnvio(item.convidado, item.canal, daFila: true);
  }

  Future<void> _mostrarConviteDaFila({required bool primeiro}) async {
    if (!mounted || !_filaAtiva) return;

    final item = _fila[_indiceFila];
    setState(() => _aguardandoContinuar = true);

    final enviar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(primeiro ? 'Primeiro convite' : 'Próximo convite'),
          content: Text(
            '${primeiro ? 'O primeiro' : 'O próximo'} convite será preparado '
            'para ${item.convidado.nome}. Ao tocar em Enviar, o WhatsApp '
            'abrirá com a mensagem pronta para esse número.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Parar envio'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (enviar == true) {
      setState(() => _aguardandoContinuar = false);
      await _abrirItemDaFila();
    } else {
      await _pararFila();
    }
  }

  Future<void> _continuarFila() async {
    if (!_filaAtiva || _processandoEnvio) return;
    await _mostrarConviteDaFila(primeiro: false);
  }

  Future<void> _pararFila() async {
    if (!_filaAtiva && !_processandoEnvio) return;

    setState(() {
      _fila = const [];
      _indiceFila = -1;
      _aguardandoContinuar = false;
      _adiadosNaFila.clear();
      _pendentesNaFila.clear();
    });
    _mostrarMensagem('Envio sequencial interrompido.');
  }

  Future<void> _avancarFila({required bool enviado}) async {
    if (!mounted || !_filaAtiva) return;

    final itemAtual = _fila[_indiceFila];
    final idAtual = itemAtual.convidado.id;
    final deveTentarNovamente = !enviado && _adiadosNaFila.add(idAtual);
    if (enviado) {
      _adiadosNaFila.remove(idAtual);
      _pendentesNaFila.remove(idAtual);
    } else if (!deveTentarNovamente) {
      _pendentesNaFila.add(idAtual);
    }

    if (deveTentarNovamente) {
      _fila.add(itemAtual);
    }

    final proximoIndice = _indiceFila + 1;
    if (proximoIndice >= _fila.length) {
      final pendentes = _pendentesNaFila.length;
      setState(() {
        _fila = const [];
        _indiceFila = -1;
        _aguardandoContinuar = false;
        _adiadosNaFila.clear();
        _pendentesNaFila.clear();
      });
      _mostrarMensagem(
        pendentes == 0
            ? 'Todos os convites da sequência foram processados.'
            : '$pendentes convite(s) ficaram pendentes para uma nova tentativa.',
      );
      return;
    }

    setState(() {
      _indiceFila = proximoIndice;
      _aguardandoContinuar = true;
    });
    await _mostrarConviteDaFila(primeiro: false);
  }

  Future<Map<String, String>> _prepararConvite(
    Convidado convidado, {
    bool renovar = false,
  }) async {
    if (!_podeEnviarConvites) {
      throw StateError('Funcionários não podem enviar convites online.');
    }

    final convitePreparado = _convitesPreparados[convidado.id];
    if (!renovar && convitePreparado != null) {
      return convitePreparado;
    }

    final convite = await _servico.criarConviteOnline(convidado.id);
    final token = convite['token']?.toString().trim();
    final conviteId = convite['id']?.toString().trim();

    if (token == null ||
        token.isEmpty ||
        conviteId == null ||
        conviteId.isEmpty) {
      throw StateError('O convite não recebeu um link válido.');
    }

    final preparado = {
      'id': conviteId,
      'link': 'https://confirmaaiweb.netlify.app/convite?token=$token',
    };
    _convitesPreparados[convidado.id] = preparado;
    return preparado;
  }

  String _textoConvite(Convidado convidado, String link) {
    final evento =
        CasamentoAtualServico.instance.casamento?.titulo ?? 'seu evento';
    final prazo = CasamentoAtualServico.instance.casamento?.dataLimiteConfirmacao;
    final prazoTexto = prazo == null
        ? ''
        : '\n\nConfirme sua presença até ${_formatarData(prazo)}.';
    return 'Olá, ${convidado.nome}!\n\n'
        'Você está convidado para $evento.\n\n'
        'Acesse o link abaixo para conferir os detalhes e confirmar sua '
        'presença:$prazoTexto\n$link';
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  Future<void> _prepararEnvio(
    Convidado convidado,
    String canal, {
    required bool daFila,
    Map<String, dynamic>? convite,
  }) async {
    if (!_podeEnviarConvites || _processandoEnvio) return;

    final reenvio = !daFila && !_podeEnviar(convite)
        ? await _confirmarReenvio(convidado, canal: 'WhatsApp', convite: convite)
        : false;
    if (!daFila && !_podeEnviar(convite) && !reenvio) return;

    final telefone = _normalizarTelefone(convidado.whatsapp);
    if (canal != 'whatsapp' || telefone == null) {
      _mostrarMensagem('Este convidado não possui um WhatsApp válido.');
      return;
    }

    setState(() => _processandoEnvio = true);

    try {
      final convitePreparado = await _prepararConvite(
        convidado,
        renovar: !daFila && reenvio,
      );
      final link = convitePreparado['link']!;
      final texto = _textoConvite(convidado, link);
      final uri = Uri.parse(
        'https://wa.me/$telefone?text=${Uri.encodeComponent(texto)}',
      );

      final abriu = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!abriu) {
        throw StateError('Não foi possível abrir o WhatsApp neste aparelho.');
      }

      if (!mounted) return;

      final marcouComoEnviado = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Mensagem no WhatsApp'),
            content: Text(
              daFila
                  ? 'Depois de tocar em Enviar no WhatsApp, volte manualmente ao ConfirmaAi e confirme se a mensagem de ${convidado.nome} foi enviada.'
                  : 'A mensagem foi preparada para ${convidado.nome}. Depois de tocar em Enviar, confirme o registro no ConfirmaAi.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(daFila ? 'Não enviei' : 'Ainda não'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(
                  daFila ? 'Sim, enviei' : 'Marcar como enviado',
                ),
              ),
            ],
          );
        },
      );

      if (marcouComoEnviado == true) {
        _whatsAppsEnviadosLocalmente.add(convidado.id);
        await _servico.registrarEnvioConviteOnline(
          conviteId: convitePreparado['id']!,
          canal: canal,
        );
        if (mounted) {
          _mostrarMensagem('WhatsApp marcado como enviado.');
          _atualizar();
        }
      }

      if (daFila && mounted) {
        setState(() => _processandoEnvio = false);
        await _avancarFila(enviado: marcouComoEnviado == true);
      }
    } catch (erro) {
      if (mounted) {
        _mostrarMensagem('Não foi possível preparar o convite: $erro');
      }
    } finally {
      if (mounted) {
        setState(() => _processandoEnvio = false);
      }
    }
  }

  String _status(Map<String, dynamic>? convite) {
    switch (convite?['status']?.toString()) {
      case 'enviado':
        return 'Enviado';
      case 'aberto':
        return 'Link acessado';
      case 'confirmado':
        return 'Presença confirmada';
      case 'recusado':
        return 'Não participará';
      default:
        return 'Ainda não enviado';
    }
  }

  IconData _iconeStatus(Map<String, dynamic>? convite) {
    switch (convite?['status']?.toString()) {
      case 'confirmado':
        return Icons.check_circle;
      case 'recusado':
        return Icons.cancel;
      case 'enviado':
      case 'aberto':
        return Icons.schedule;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  Color _corStatus(Map<String, dynamic>? convite) {
    switch (convite?['status']?.toString()) {
      case 'confirmado':
        return Colors.green.shade700;
      case 'recusado':
        return Colors.red.shade700;
      case 'enviado':
      case 'aberto':
        return Colors.orange.shade800;
      default:
        return Colors.grey.shade700;
    }
  }

  String _chaveStatus(Map<String, dynamic>? convite) {
    switch (convite?['status']?.toString()) {
      case 'enviado':
        return 'enviado';
      case 'aberto':
        return 'aberto';
      case 'confirmado':
        return 'confirmado';
      case 'recusado':
        return 'recusado';
      default:
        return 'pendente';
    }
  }

  Future<void> _selecionarFiltroStatus() async {
    final selecionado = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        const opcoes = <String, String>{
          'todos': 'Todos os status',
          'pendente': 'Ainda não enviado',
          'enviado': 'Enviado',
          'aberto': 'Link acessado',
          'confirmado': 'Presença confirmada',
          'recusado': 'Não participará',
        };

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Filtrar por status',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              ...opcoes.entries.map(
                (opcao) => ListTile(
                  leading: Icon(
                    opcao.key == _filtroStatus
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(opcao.value),
                  onTap: () => Navigator.of(context).pop(opcao.key),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (selecionado != null && mounted) {
      setState(() => _filtroStatus = selecionado);
    }
  }

  void _mostrarMensagem(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.mostrarAppBar
          ? AppBar(
              title: const Text('Convites online'),
              actions: [
                IconButton(
                  tooltip: 'Atualizar',
                  onPressed: _processandoEnvio ? null : _atualizar,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            )
          : null,
      body: StreamBuilder<List<Convidado>>(
        stream: _servico.listarConvidados(),
        builder: (context, convidadosSnapshot) {
          if (convidadosSnapshot.hasError) {
            return const Center(
              child: Text('Não foi possível carregar convidados.'),
            );
          }
          if (!convidadosSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final convidadosTodos =
              convidadosSnapshot.data!
                  .toList()
                ..sort(
                  (a, b) =>
                      a.nome.toLowerCase().compareTo(b.nome.toLowerCase()),
                );

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _convitesStream,
            builder: (context, convitesSnapshot) {
              final convites = <String, Map<String, dynamic>>{
                for (final convite in convitesSnapshot.data ?? const [])
                  convite['convidado_id'].toString(): convite,
              };

              final convidados = convidadosTodos
                  .where(
                    (convidado) =>
                        convidado.nome.toLowerCase().contains(_busca) &&
                        (_filtroStatus == 'todos' ||
                            _chaveStatus(convites[convidado.id]) ==
                                _filtroStatus),
                  )
                  .toList(growable: false);

              final filaPendente = _podeEnviarConvites
                  ? _montarFilaWhatsApp(convidadosTodos, convites)
                  : Future.value(const <_ItemFilaConvite>[]);

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 12, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText: 'Buscar convidado',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            onChanged: (valor) {
                              setState(
                                () => _busca = valor.trim().toLowerCase(),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 2),
                        IconButton(
                          tooltip: 'Filtrar por status',
                          onPressed: _selecionarFiltroStatus,
                          icon: Icon(
                            Icons.filter_list,
                            color: _filtroStatus == 'todos'
                                ? null
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_podeEnviarConvites)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                      child: Text(
                        'Somente leitura: acompanhe o status dos convites.',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    FutureBuilder<List<_ItemFilaConvite>>(
                      future: filaPendente,
                      builder: (context, filaSnapshot) {
                        final quantidade = filaSnapshot.data?.length ?? 0;
                        final textoBotao = _filaAtiva
                            ? _aguardandoContinuar
                                  ? 'Preparar WhatsApp (${_indiceFila + 1}/${_fila.length})'
                                  : 'Parar envio (${_indiceFila + 1}/${_fila.length})'
                            : 'Iniciar WhatsApps ($quantidade)';

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _processandoEnvio
                                  ? null
                                  : _filaAtiva
                                  ? (_aguardandoContinuar
                                        ? _continuarFila
                                        : _pararFila)
                                  : () => _iniciarFila(convidados, convites),
                              icon: Icon(
                                _filaAtiva && !_aguardandoContinuar
                                    ? Icons.stop_circle_outlined
                                    : Icons.send,
                              ),
                              label: Text(textoBotao),
                            ),
                          ),
                        );
                      },
                    ),
                  if (_filaAtiva && _podeEnviarConvites)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                      child: Text(
                        'Cada WhatsApp é aberto individualmente para você tocar em Enviar.',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (convitesSnapshot.connectionState ==
                      ConnectionState.waiting)
                    const LinearProgressIndicator(),
                  Expanded(
                    child: convidados.isEmpty
                        ? const Center(
                            child: Text('Nenhum convidado encontrado.'),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                            itemCount: convidados.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final convidado = convidados[index];
                              final convite = convites[convidado.id];
                              final telefoneValido =
                                  _normalizarTelefone(convidado.whatsapp) !=
                                  null;
                              final emailInformado =
                                  convidado.email?.trim().isNotEmpty == true;
                              final corStatus = _corStatus(convite);

                              return Card(
                                child: ListTile(
                                  contentPadding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    8,
                                    8,
                                  ),
                                  leading: CircleAvatar(
                                    child: Icon(
                                      telefoneValido
                                          ? Icons.person
                                          : Icons.person_outline,
                                    ),
                                  ),
                                  title: Text(
                                    convidado.nome,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _status(convite),
                                        style: TextStyle(color: corStatus),
                                      ),
                                      Text(
                                        telefoneValido
                                            ? 'WhatsApp: ${convidado.whatsapp}'
                                            : 'WhatsApp não informado',
                                      ),
                                      Text(
                                        emailInformado
                                            ? 'E-mail: ${convidado.email}'
                                            : 'E-mail não informado',
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_podeEnviarConvites) ...[
                                        IconButton(
                                          tooltip: _podeEnviar(convite)
                                              ? 'Abrir WhatsApp'
                                              : 'Reenviar WhatsApp',
                                            onPressed:
                                                telefoneValido &&
                                                    !_processandoEnvio
                                              ? () => _prepararEnvio(
                                                  convidado,
                                                  'whatsapp',
                                                  daFila: false,
                                                  convite: convite,
                                                )
                                              : null,
                                          icon: const FaIcon(
                                            FontAwesomeIcons.whatsapp,
                                            size: 22,
                                          ),
                                        ),
                                      ],
                                      Icon(
                                        _iconeStatus(convite),
                                        color: corStatus,
                                        size: 22,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
