import 'dart:async';

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
  bool _processandoEnvio = false;
  List<_ItemFilaConvite> _fila = const [];
  int _indiceFila = -1;
  bool _aguardandoContinuar = false;
  final Map<String, Map<String, String>> _convitesPreparados = {};
  final Set<String> _emailsEnviadosLocalmente = {};
  final Set<String> _whatsAppsEnviadosLocalmente = {};

  bool get _filaAtiva => _indiceFila >= 0 && _indiceFila < _fila.length;

  @override
  void initState() {
    super.initState();
    _convitesStream = _servico.observarConvitesOnline();
  }

  void _atualizar() {
    if (!mounted) return;
    setState(() {});
  }

  bool _emailValido(String? valor) {
    final email = (valor ?? '').trim();
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
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
    if (_processandoEnvio) return;

    final emailsPendentes = convidados
        .where((convidado) {
          final convite = convites[convidado.id];
          return _emailValido(convidado.email) &&
              _podeEnviar(convite) &&
              !_canaisEnviados(convite).contains('email') &&
              !_emailsEnviadosLocalmente.contains(convidado.id);
        })
        .map((convidado) => convidado.id)
        .toList(growable: false);

    if (emailsPendentes.isNotEmpty) {
      await _enviarEmailsEmLote(emailsPendentes);
      if (!mounted) return;
    }

    final fila = await _montarFilaWhatsApp(convidados, convites);
    if (!mounted) return;

    if (fila.isEmpty) {
      _mostrarMensagem(
        emailsPendentes.isNotEmpty
            ? 'E-mails processados. Não há WhatsApps pendentes.'
            : 'Não há WhatsApps pendentes com número informado.',
      );
      return;
    }

    setState(() {
      _fila = fila;
      _indiceFila = 0;
      _aguardandoContinuar = false;
    });

    await _abrirItemDaFila();
  }

  int _contarEmailsPendentes(
    List<Convidado> convidados,
    Map<String, Map<String, dynamic>> convites,
  ) {
    return convidados.where((convidado) {
      final convite = convites[convidado.id];
      return _emailValido(convidado.email) &&
          _podeEnviar(convite) &&
          !_canaisEnviados(convite).contains('email') &&
          !_emailsEnviadosLocalmente.contains(convidado.id);
    }).length;
  }

  Future<void> _enviarEmailsEmLote(List<String> convidadoIds) async {
    if (convidadoIds.isEmpty || _processandoEnvio) return;

    setState(() => _processandoEnvio = true);
    try {
      final resultado = await _servico.enviarConvitesEmailEmLote(
        convidadoIds: convidadoIds,
      );
      final links = resultado['links'];
      if (links is List) {
        for (final item in links) {
          if (item is! Map) continue;
          final convidadoId = item['convidado_id']?.toString().trim();
          final conviteId = item['convite_id']?.toString().trim();
          final link = item['link']?.toString().trim();
          if (convidadoId == null ||
              convidadoId.isEmpty ||
              conviteId == null ||
              conviteId.isEmpty ||
              link == null ||
              link.isEmpty) {
            continue;
          }
          _convitesPreparados[convidadoId] = {'id': conviteId, 'link': link};
        }
      }

      final enviados = resultado['enviados'];
      if (enviados is List) {
        for (final item in enviados) {
          if (item is Map) {
            final id = item['convidado_id']?.toString().trim();
            if (id != null && id.isNotEmpty) {
              _emailsEnviadosLocalmente.add(id);
            }
          }
        }
      }

      final falhas = resultado['emails_falhos']?.toString() ?? '0';
      final enviadosTotal = resultado['emails_enviados']?.toString() ?? '0';
      _mostrarMensagem(
        'E-mails enviados pelo servidor: $enviadosTotal. Falhas: $falhas.',
      );
    } catch (erro) {
      _mostrarMensagem('Não foi possível enviar os e-mails: $erro');
    } finally {
      if (mounted) setState(() => _processandoEnvio = false);
    }
  }

  Future<void> _enviarEmailIndividual(Convidado convidado) async {
    if (!_emailValido(convidado.email) || _processandoEnvio) return;
    await _enviarEmailsEmLote([convidado.id]);
  }

  Future<void> _abrirItemDaFila() async {
    if (!mounted || !_filaAtiva || _aguardandoContinuar) return;

    final item = _fila[_indiceFila];
    await _prepararEnvio(item.convidado, item.canal, daFila: true);
  }

  Future<void> _continuarFila() async {
    if (!_filaAtiva || _processandoEnvio) return;

    setState(() {
      _aguardandoContinuar = false;
    });
    await _abrirItemDaFila();
  }

  Future<void> _pararFila() async {
    if (!_filaAtiva && !_processandoEnvio) return;

    setState(() {
      _fila = const [];
      _indiceFila = -1;
      _aguardandoContinuar = false;
    });
    _mostrarMensagem('Envio sequencial interrompido.');
  }

  Future<void> _avancarFila({required bool enviado}) async {
    if (!mounted || !_filaAtiva) return;

    final proximoIndice = _indiceFila + 1;
    if (proximoIndice >= _fila.length) {
      setState(() {
        _fila = const [];
        _indiceFila = -1;
        _aguardandoContinuar = false;
      });
      _mostrarMensagem(
        enviado
            ? 'Todos os convites da sequência foram processados.'
            : 'Convite pulado. A sequência foi concluída.',
      );
      return;
    }

    final proximo = _fila[proximoIndice];
    setState(() {
      _indiceFila = proximoIndice;
      _aguardandoContinuar = true;
    });

    final continuar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Próximo convite'),
          content: Text('O próximo é ${proximo.convidado.nome}, por WhatsApp.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Parar fila'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continuar'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (continuar == true) {
      setState(() {
        _aguardandoContinuar = false;
      });
      await _abrirItemDaFila();
    } else {
      await _pararFila();
    }
  }

  Future<Map<String, String>> _prepararConvite(Convidado convidado) async {
    final convitePreparado = _convitesPreparados[convidado.id];
    if (convitePreparado != null) {
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
    return 'Olá, ${convidado.nome}!\n\n'
        'Você está convidado para $evento.\n\n'
        'Acesse o link abaixo para conferir os detalhes e confirmar sua '
        'presença:\n$link';
  }

  Future<void> _prepararEnvio(
    Convidado convidado,
    String canal, {
    required bool daFila,
  }) async {
    if (_processandoEnvio) return;

    final telefone = _normalizarTelefone(convidado.whatsapp);
    if (canal != 'whatsapp' || telefone == null) {
      _mostrarMensagem('Este convidado não possui um WhatsApp válido.');
      return;
    }

    setState(() => _processandoEnvio = true);

    try {
      final convite = await _prepararConvite(convidado);
      final link = convite['link']!;
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
            title: Text('WhatsApp aberto'),
            content: Text(
              daFila
                  ? 'A mensagem de ${convidado.nome} foi preparada. Toque em Enviar no WhatsApp e depois volte ao ConfirmaAi para continuar.'
                  : 'A mensagem foi preparada para ${convidado.nome}. Depois de tocar em Enviar, confirme o registro no ConfirmaAi.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(daFila ? 'Pular' : 'Ainda não'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(
                  daFila ? 'Enviar e continuar' : 'Marcar como enviado',
                ),
              ),
            ],
          );
        },
      );

      if (marcouComoEnviado == true) {
        _whatsAppsEnviadosLocalmente.add(convidado.id);
        await _servico.registrarEnvioConviteOnline(
          conviteId: convite['id']!,
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

  void _mostrarMensagem(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  Widget build(BuildContext context) {
    final casamento = CasamentoAtualServico.instance.casamento;

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

          final convidados =
              convidadosSnapshot.data!
                  .where(
                    (convidado) =>
                        convidado.nome.toLowerCase().contains(_busca),
                  )
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

              final totalEmail = convidados
                  .where((c) => _emailValido(c.email))
                  .length;
              final totalWhatsApp = convidados
                  .where((c) => _normalizarTelefone(c.whatsapp) != null)
                  .length;
              final filaPendente = _montarFilaWhatsApp(convidados, convites);
              final emailsPendentes = _contarEmailsPendentes(
                convidados,
                convites,
              );

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Buscar convidado',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (valor) {
                        setState(() => _busca = valor.trim().toLowerCase());
                      },
                    ),
                  ),
                  Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.mark_email_unread_outlined),
                      title: Text(
                        '$totalEmail e-mails • $totalWhatsApp WhatsApps',
                      ),
                      subtitle: Text(
                        casamento == null
                            ? 'Cada mensagem será preparada com o link individual do convite.'
                            : 'Evento: ${casamento.titulo}.',
                      ),
                    ),
                  ),
                  FutureBuilder<List<_ItemFilaConvite>>(
                    future: filaPendente,
                    builder: (context, filaSnapshot) {
                      final quantidade = filaSnapshot.data?.length ?? 0;
                      final textoBotao = _filaAtiva
                          ? _aguardandoContinuar
                                ? 'Continuar envio (${_indiceFila + 1}/${_fila.length})'
                                : 'Parar envio (${_indiceFila + 1}/${_fila.length})'
                          : emailsPendentes > 0
                          ? 'Enviar e-mails e WhatsApps ($emailsPendentes + $quantidade)'
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
                  if (_filaAtiva)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                      child: Text(
                        'Os e-mails são enviados pelo servidor. Depois, cada WhatsApp é aberto individualmente para você tocar em Enviar.',
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
                              final emailValido = _emailValido(convidado.email);
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
                                      emailValido || telefoneValido
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
                                        emailValido
                                            ? 'E-mail: ${convidado.email}'
                                            : 'E-mail não informado',
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Preparar e-mail',
                                        onPressed:
                                            emailValido && !_processandoEnvio
                                            ? () => _enviarEmailIndividual(
                                                convidado,
                                              )
                                            : null,
                                        icon: const Icon(Icons.email_outlined),
                                      ),
                                      IconButton(
                                        tooltip: 'Abrir WhatsApp',
                                        onPressed:
                                            telefoneValido && !_processandoEnvio
                                            ? () => _prepararEnvio(
                                                convidado,
                                                'whatsapp',
                                                daFila: false,
                                              )
                                            : null,
                                        icon: const Icon(Icons.chat_outlined),
                                      ),
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
