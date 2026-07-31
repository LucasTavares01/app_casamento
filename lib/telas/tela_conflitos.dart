import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../modelos/modelos.dart';
import '../servicos/supabase_servico.dart';

class TelaConflitos extends StatefulWidget {
  final String? conflitoIdInicial;

  const TelaConflitos({super.key, this.conflitoIdInicial});

  @override
  State<TelaConflitos> createState() => _TelaConflitosState();
}

class _TelaConflitosState extends State<TelaConflitos> {
  final SupabaseServico _servico = SupabaseServico();

  late Stream<List<ConflitoSincronizacao>> _streamConflitos;
  late final Stream<List<Mesa>> _streamMesas;
  late final Stream<List<Convidado>> _streamConvidados;
  late final Stream<List<UsuarioApp>> _streamUsuarios;

  final Set<String> _conflitosEmResolucao = <String>{};

  @override
  void initState() {
    super.initState();
    _streamConflitos = _servico.listarConflitosPendentes();
    _streamMesas = _servico.listarMesas();
    _streamConvidados = _servico.listarConvidados();
    _streamUsuarios = _servico.listarUsuariosApp();
  }

  void _recarregarConflitos() {
    setState(() {
      _streamConflitos = _servico.listarConflitosPendentes();
    });
  }

  Future<void> _resolverMesa({
    required ConflitoSincronizacao conflito,
    required String resolucao,
    String? novaMesaId,
  }) async {
    if (_conflitosEmResolucao.contains(conflito.id)) return;

    setState(() => _conflitosEmResolucao.add(conflito.id));

    try {
      await _servico.resolverConflitoMesaCheckin(
        conflitoId: conflito.id,
        resolucao: resolucao,
        novaMesaId: novaMesaId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Conflito resolvido. Todos os aparelhos serão atualizados automaticamente.',
          ),
        ),
      );
    } catch (erro) {
      if (mounted) await _mostrarErroResolucao(erro);
    } finally {
      if (mounted) {
        setState(() => _conflitosEmResolucao.remove(conflito.id));
      }
    }
  }

  Future<void> _resolverGenerico(
    ConflitoSincronizacao conflito,
    String resolucao,
  ) async {
    if (_conflitosEmResolucao.contains(conflito.id)) return;

    setState(() => _conflitosEmResolucao.add(conflito.id));

    try {
      await _servico.resolverConflitoGenerico(
        conflitoId: conflito.id,
        resolucao: resolucao,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Conflito resolvido. Todos os aparelhos serão atualizados automaticamente.',
          ),
        ),
      );
    } catch (erro) {
      if (mounted) await _mostrarErroResolucao(erro);
    } finally {
      if (mounted) {
        setState(() => _conflitosEmResolucao.remove(conflito.id));
      }
    }
  }

  Future<void> _mostrarErroResolucao(Object erro) async {
    final mensagem = erro.toString();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Expanded(child: Text('Erro ao resolver conflito')),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 420),
            child: SingleChildScrollView(child: SelectableText(mensagem)),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: mensagem));
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(
                  dialogContext,
                ).showSnackBar(const SnackBar(content: Text('Erro copiado.')));
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copiar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  bool _ehConflitoMesaCheckin(ConflitoSincronizacao conflito) {
    final tipo = conflito.tipo.toLowerCase();
    return tipo.contains('mesa') && tipo != 'mesa_alteracao_concorrente';
  }

  bool _ehConflitoConvidadoRemovidoCheckin(
    ConflitoSincronizacao conflito,
  ) {
    return conflito.tipo.toLowerCase() ==
        'convidado_inexistente_durante_checkin';
  }

  Iterable<Map<String, dynamic>> _mapasRecursivos(dynamic valor) sync* {
    if (valor is Map) {
      final mapa = Map<String, dynamic>.from(valor);
      yield mapa;
      for (final item in mapa.values) {
        yield* _mapasRecursivos(item);
      }
      return;
    }

    if (valor is Iterable) {
      for (final item in valor) {
        yield* _mapasRecursivos(item);
      }
    }
  }

  dynamic _valorRecursivo(dynamic valor, List<String> chaves) {
    final chavesSet = chaves.toSet();
    for (final mapa in _mapasRecursivos(valor)) {
      for (final chave in chavesSet) {
        if (mapa.containsKey(chave) && mapa[chave] != null) {
          return mapa[chave];
        }
      }
    }
    return null;
  }

  String? _textoRecursivo(dynamic valor, List<String> chaves) {
    final encontrado = _valorRecursivo(valor, chaves);
    final texto = encontrado?.toString().trim();
    if (texto == null || texto.isEmpty || texto.toLowerCase() == 'null') {
      return null;
    }
    return texto;
  }

  bool? _booleanoRecursivo(dynamic valor, List<String> chaves) {
    final encontrado = _valorRecursivo(valor, chaves);
    if (encontrado is bool) return encontrado;
    if (encontrado is num) return encontrado != 0;

    final texto = encontrado?.toString().trim().toLowerCase();
    if (texto == 'true' || texto == '1' || texto == 'sim') return true;
    if (texto == 'false' || texto == '0' || texto == 'nao' || texto == 'não') {
      return false;
    }
    return null;
  }

  Map<String, dynamic>? _mapaDireto(Map<String, dynamic> origem, String chave) {
    final valor = origem[chave];
    if (valor is Map) return Map<String, dynamic>.from(valor);
    return null;
  }

  bool _possuiDataExclusao(Map<String, dynamic>? mapa) {
    final valor = mapa?['deleted_at']?.toString().trim();
    return valor != null && valor.isNotEmpty && valor.toLowerCase() != 'null';
  }

  Map<String, dynamic>? _payloadLocal(ConflitoSincronizacao conflito) {
    Map<String, dynamic>? melhor;
    var melhorPontuacao = -1;

    for (final mapa in _mapasRecursivos(conflito.dados)) {
      var pontuacao = 0;
      if (mapa.containsKey('base_updated_at')) pontuacao += 8;
      if (mapa.containsKey('modificado_por_usuario_id')) pontuacao += 5;
      if (mapa.containsKey('mesa_id')) pontuacao += 3;
      if (mapa.containsKey('nome')) pontuacao += 2;
      if (mapa.containsKey('tipo_acao')) pontuacao += 3;
      if (mapa.containsKey('estado_resultante')) pontuacao += 2;

      if (pontuacao > melhorPontuacao) {
        melhorPontuacao = pontuacao;
        melhor = mapa;
      }
    }

    return melhorPontuacao > 0 ? melhor : null;
  }

  String _nomeUsuario({
    required String fallback,
    String? nomeDireto,
    String? usuarioId,
    required Map<String, String> usuariosPorId,
  }) {
    final nome = nomeDireto?.trim();
    if (nome != null && nome.isNotEmpty && nome != 'null') return nome;

    final id = usuarioId?.trim();
    if (id != null && id.isNotEmpty) {
      final nomeMapeado = usuariosPorId[id];
      if (nomeMapeado != null && nomeMapeado.trim().isNotEmpty) {
        return nomeMapeado;
      }
    }

    return fallback;
  }

  Mesa? _mesaPorId(List<Mesa> mesas, String? id) {
    if (id == null || id.isEmpty) return null;
    for (final mesa in mesas) {
      if (mesa.id == id) return mesa;
    }
    return null;
  }

  String _nomeMesa({
    required List<Mesa> mesas,
    String? id,
    String? numero,
    String? detalhe,
    String fallback = 'Sem mesa',
  }) {
    final mesa = _mesaPorId(mesas, id);
    if (mesa != null) return mesa.nomeExibicao;

    final numeroNormalizado = numero?.trim();
    final detalheNormalizado = detalhe?.trim();
    if (numeroNormalizado != null && numeroNormalizado.isNotEmpty) {
      if (detalheNormalizado != null && detalheNormalizado.isNotEmpty) {
        return 'Mesa $numeroNormalizado - $detalheNormalizado';
      }
      return 'Mesa $numeroNormalizado';
    }

    return fallback;
  }

  String _formatarDataHora(DateTime data) {
    final local = data.toLocal();
    final dia = local.day.toString().padLeft(2, '0');
    final mes = local.month.toString().padLeft(2, '0');
    final ano = local.year.toString();
    final hora = local.hour.toString().padLeft(2, '0');
    final minuto = local.minute.toString().padLeft(2, '0');
    return '$dia/$mes/$ano às $hora:$minuto';
  }

  String _acaoCheckin(String? tipo, bool? estado) {
    switch (tipo) {
      case 'confirmou_chegada':
        return 'marcou como presente';
      case 'removeu_chegada':
        return 'marcou como não presente';
      case 'resolveu_como_presente':
        return 'definiu como presente';
      case 'resolveu_como_ausente':
        return 'definiu como não presente';
    }

    if (estado != null) {
      return estado ? 'marcou como presente' : 'marcou como não presente';
    }

    return 'fez uma alteração';
  }

  _ResumoConflito _montarResumo({
    required ConflitoSincronizacao conflito,
    required List<Mesa> mesas,
    required List<Convidado> convidados,
    required Map<String, String> usuariosPorId,
  }) {
    final payload = _payloadLocal(conflito) ?? const <String, dynamic>{};

    Convidado? convidadoLocal;
    for (final item in convidados) {
      if (item.id == conflito.convidadoId) {
        convidadoLocal = item;
        break;
      }
    }

    final nomeConvidado =
        _textoRecursivo(conflito.dados, const [
          'convidado_nome',
          'nome_convidado',
        ]) ??
        convidadoLocal?.nome ??
        'Convidado não identificado';

    final usuarioLocalId =
        _textoRecursivo(conflito.dados, const [
          'usuario_local_id',
          'evento_usuario_id',
        ]) ??
        payload['modificado_por_usuario_id']?.toString() ??
        conflito.usuarioCheckinId;

    final usuarioLocalNome = _nomeUsuario(
      fallback: 'Usuário do celular',
      nomeDireto:
          _textoRecursivo(conflito.dados, const [
            'usuario_local_nome',
            'evento_usuario_nome',
          ]) ??
          conflito.usuarioCheckinNome,
      usuarioId: usuarioLocalId,
      usuariosPorId: usuariosPorId,
    );

    final usuarioServidorId =
        _textoRecursivo(conflito.dados, const [
          'usuario_servidor_id',
          'convidado_modificado_por_usuario_id_servidor',
          'mesa_modificada_por_usuario_id_servidor',
        ]) ??
        conflito.usuarioAlteracaoMesaId;

    final usuarioServidorNome = _nomeUsuario(
      fallback: 'Outro usuário',
      nomeDireto:
          _textoRecursivo(conflito.dados, const [
            'usuario_servidor_nome',
            'convidado_modificado_por_usuario_nome_servidor',
            'mesa_modificada_por_usuario_nome_servidor',
          ]) ??
          conflito.usuarioAlteracaoMesaNome,
      usuarioId: usuarioServidorId,
      usuariosPorId: usuariosPorId,
    );

    final mesaOriginalId =
        _textoRecursivo(conflito.dados, const [
          'mesa_original_id',
          'mesa_id_contexto',
        ]) ??
        conflito.mesaId;

    final mesaOriginal = _nomeMesa(
      mesas: mesas,
      id: mesaOriginalId,
      numero: _textoRecursivo(conflito.dados, const [
        'mesa_original_numero',
        'mesa_numero_contexto',
      ]),
      detalhe: _textoRecursivo(conflito.dados, const [
        'mesa_original_detalhe',
        'mesa_detalhe_contexto',
      ]),
    );

    final mesaLocalId =
        _textoRecursivo(conflito.dados, const ['mesa_local_id']) ??
        payload['mesa_id']?.toString();

    final mesaLocal = _nomeMesa(
      mesas: mesas,
      id: mesaLocalId,
      numero: _textoRecursivo(conflito.dados, const ['mesa_local_numero']),
      detalhe: _textoRecursivo(conflito.dados, const ['mesa_local_detalhe']),
    );

    final mesaServidorId =
        _textoRecursivo(conflito.dados, const [
          'mesa_servidor_id',
          'convidado_mesa_id_servidor',
        ]) ??
        convidadoLocal?.mesaId;

    final mesaServidor = _nomeMesa(
      mesas: mesas,
      id: mesaServidorId,
      numero: _textoRecursivo(conflito.dados, const [
        'mesa_servidor_numero',
        'convidado_mesa_numero_servidor',
      ]),
      detalhe: _textoRecursivo(conflito.dados, const [
        'mesa_servidor_detalhe',
        'convidado_mesa_detalhe_servidor',
      ]),
    );

    final tipo = conflito.tipo.toLowerCase();
    final operacaoLocalDireta = _mapaDireto(conflito.dados, 'operacao_local');
    final versaoServidorDireta = _mapaDireto(conflito.dados, 'versao_servidor');
    final origemOperacao = _textoRecursivo(conflito.dados, const [
      'operacao_origem',
      'acao_usuario',
    ])?.toLowerCase();

    final localExcluiuMesa =
        _possuiDataExclusao(operacaoLocalDireta) ||
        origemOperacao == 'exclusao_mesa' ||
        origemOperacao == 'excluiu_mesa';

    final servidorExcluiuMesa =
        _possuiDataExclusao(versaoServidorDireta) ||
        _textoRecursivo(conflito.dados, const [
              'mesa_excluida_em_servidor',
              'mesa_deleted_at',
            ]) !=
            null;

    String fraseLocal;
    String fraseServidor;
    String titulo;

    if (tipo == 'convidado_inexistente_durante_checkin') {
      titulo = 'Convidado removido durante check-in offline';

      final tipoAcao = _textoRecursivo(conflito.dados, const [
        'evento_tipo_acao',
        'tipo_acao',
      ]);
      final estado = _booleanoRecursivo(conflito.dados, const [
        'evento_estado_resultante',
        'estado_resultante',
      ]);

      fraseLocal =
          '$usuarioLocalNome ${_acaoCheckin(tipoAcao, estado)} para '
          '$nomeConvidado enquanto o aparelho estava offline.';
      fraseServidor =
          'A nova lista oficial removeu $nomeConvidado antes de o aparelho '
          'sincronizar.';
    } else if (conflito.envolveMesaExcluida) {
      titulo = 'Uma mesa foi excluída enquanto havia outra alteração';
      final tipoAcao = _textoRecursivo(conflito.dados, const [
        'evento_tipo_acao',
        'tipo_acao',
      ]);
      final estado = _booleanoRecursivo(conflito.dados, const [
        'evento_estado_resultante',
        'estado_resultante',
      ]);

      String acaoLocalSemExclusao;
      if (tipo.contains('checkin') || conflito.eventoCheckinId != null) {
        acaoLocalSemExclusao =
            '$usuarioLocalNome ${_acaoCheckin(tipoAcao, estado)} para $nomeConvidado enquanto o aparelho estava offline.';
      } else if (mesaLocalId != null && mesaLocalId != mesaOriginalId) {
        acaoLocalSemExclusao =
            '$usuarioLocalNome moveu $nomeConvidado de $mesaOriginal para $mesaLocal.';
      } else {
        acaoLocalSemExclusao =
            '$usuarioLocalNome alterou os dados de $nomeConvidado enquanto o aparelho estava offline.';
      }

      String acaoServidorSemExclusao;
      if (mesaServidorId != null && mesaServidorId != mesaOriginalId) {
        acaoServidorSemExclusao =
            '$usuarioServidorNome moveu $nomeConvidado de $mesaOriginal para $mesaServidor.';
      } else {
        acaoServidorSemExclusao =
            '$usuarioServidorNome alterou o mesmo registro na nuvem.';
      }

      if (localExcluiuMesa && !servidorExcluiuMesa) {
        fraseLocal = '$usuarioLocalNome excluiu $mesaOriginal.';
        fraseServidor = acaoServidorSemExclusao;
      } else {
        fraseLocal = acaoLocalSemExclusao;
        fraseServidor = '$usuarioServidorNome excluiu $mesaOriginal.';
      }
    } else if (tipo == 'convidado_alteracao_concorrente') {
      titulo = 'O mesmo convidado foi alterado por duas pessoas';
      fraseLocal = mesaLocalId != null
          ? '$usuarioLocalNome moveu $nomeConvidado de $mesaOriginal para $mesaLocal.'
          : '$usuarioLocalNome alterou os dados de $nomeConvidado no celular.';
      fraseServidor = mesaServidorId != null
          ? '$usuarioServidorNome moveu $nomeConvidado de $mesaOriginal para $mesaServidor.'
          : '$usuarioServidorNome alterou os dados de $nomeConvidado na nuvem.';
    } else if (tipo == 'mesa_alteracao_concorrente') {
      titulo = 'A mesma mesa foi alterada por duas pessoas';
      fraseLocal = '$usuarioLocalNome alterou $mesaOriginal no celular.';
      fraseServidor = '$usuarioServidorNome também alterou $mesaOriginal.';
    } else if (tipo.contains('checkin')) {
      titulo = 'A presença foi alterada de duas formas diferentes';
      final tipoAcao = _textoRecursivo(conflito.dados, const [
        'evento_tipo_acao',
        'tipo_acao',
      ]);
      final estadoLocal = _booleanoRecursivo(conflito.dados, const [
        'evento_estado_resultante',
        'estado_resultante',
      ]);
      final estadoServidor = _booleanoRecursivo(conflito.dados, const [
        'convidado_chegou_servidor',
        'estado_servidor',
      ]);
      fraseLocal =
          '$usuarioLocalNome ${_acaoCheckin(tipoAcao, estadoLocal)} para $nomeConvidado.';
      fraseServidor =
          '$usuarioServidorNome ${_acaoCheckin(null, estadoServidor)} para $nomeConvidado.';
    } else {
      titulo = 'Alterações simultâneas';
      fraseLocal = '$usuarioLocalNome enviou uma alteração feita no celular.';
      fraseServidor =
          '$usuarioServidorNome já havia alterado o mesmo registro na nuvem.';
    }

    final nomesAfetados = conflito.convidadosAfetadosNomes.isNotEmpty
        ? conflito.convidadosAfetadosNomes
        : [nomeConvidado];

    return _ResumoConflito(
      titulo: titulo,
      nomeConvidado: conflito.convidadoId == null && tipo.contains('mesa')
          ? mesaOriginal
          : nomeConvidado,
      usuarioLocal: usuarioLocalNome,
      usuarioServidor: usuarioServidorNome,
      fraseLocal: fraseLocal,
      fraseServidor: fraseServidor,
      mesaOriginal: mesaOriginal,
      convidadosAfetadosNomes: nomesAfetados,
      localExcluiuMesa: localExcluiuMesa,
      servidorExcluiuMesa: servidorExcluiuMesa,
    );
  }

  Future<void> _confirmarResolucaoGenerica({
    required ConflitoSincronizacao conflito,
    required String resolucao,
    required String texto,
  }) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar resolução'),
          content: Text(
            '$texto\n\nEssa decisão será enviada em tempo real para todos os aparelhos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );

    if (confirmou == true) {
      await _resolverGenerico(conflito, resolucao);
    }
  }

  Future<void> _confirmarResolucaoMesa({
    required ConflitoSincronizacao conflito,
    required String resolucao,
    required String texto,
  }) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar resolução'),
          content: Text(
            '$texto\n\nEssa decisão será enviada em tempo real para todos os aparelhos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );

    if (confirmou == true) {
      await _resolverMesa(conflito: conflito, resolucao: resolucao);
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
      builder: (dialogContext) {
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
                items: mesas
                    .map(
                      (mesa) => DropdownMenuItem<String>(
                        value: mesa.id,
                        child: Text(mesa.nomeExibicao),
                      ),
                    )
                    .toList(),
                onChanged: (valor) {
                  setDialogState(() => mesaSelecionadaId = valor);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: mesaSelecionadaId == null
                      ? null
                      : () => Navigator.pop(dialogContext, mesaSelecionadaId),
                  child: const Text('Mover convidado'),
                ),
              ],
            );
          },
        );
      },
    );

    if (resultado != null && resultado.isNotEmpty) {
      await _resolverMesa(
        conflito: conflito,
        resolucao: 'mover_para_outra_mesa',
        novaMesaId: resultado,
      );
    }
  }

  String _detalhesTecnicos(ConflitoSincronizacao conflito) {
    final jsonFormatado = const JsonEncoder.withIndent(
      '  ',
    ).convert(conflito.dados);

    return '''Tipo: ${conflito.tipo}
Descrição original: ${conflito.descricao}
Convidado ID: ${conflito.convidadoId ?? 'Não informado'}
Mesa ID: ${conflito.mesaId ?? 'Não informado'}
Evento ID: ${conflito.eventoCheckinId ?? 'Não informado'}
Usuário local ID: ${conflito.usuarioCheckinId ?? 'Não informado'}
Usuário servidor ID: ${conflito.usuarioAlteracaoMesaId ?? 'Não informado'}
Conflito ID: ${conflito.id}

Dados registrados pelo servidor:
$jsonFormatado''';
  }

  Future<void> _abrirDetalhes(ConflitoSincronizacao conflito) async {
    final detalhes = _detalhesTecnicos(conflito);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Detalhes técnicos'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700, maxHeight: 560),
            child: SingleChildScrollView(
              child: SelectableText(
                detalhes,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: detalhes));
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Detalhes copiados.')),
                );
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copiar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _selecionarNovaMesaParaConvidado({
    required ConflitoSincronizacao conflito,
    required String convidadoId,
    required String convidadoNome,
    required List<Mesa> mesas,
  }) async {
    String? mesaSelecionadaId;

    final novaMesaId = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('Nova mesa para $convidadoNome'),
              content: SizedBox(
                width: double.maxFinite,
                child: DropdownButtonFormField<String>(
                  initialValue: mesaSelecionadaId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Selecione a nova mesa',
                    border: OutlineInputBorder(),
                  ),
                  items: mesas.map((mesa) {
                    return DropdownMenuItem<String>(
                      value: mesa.id,
                      child: Text(mesa.nomeExibicao),
                    );
                  }).toList(),
                  onChanged: (valor) {
                    setStateDialog(() => mesaSelecionadaId = valor);
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: mesaSelecionadaId == null
                      ? null
                      : () => Navigator.pop(dialogContext, mesaSelecionadaId),
                  child: const Text('Confirmar nova mesa'),
                ),
              ],
            );
          },
        );
      },
    );

    if (novaMesaId == null || !mounted) return;

    final chaveResolucao = '${conflito.id}:$convidadoId';
    setState(() => _conflitosEmResolucao.add(chaveResolucao));

    try {
      await _servico.realocarConvidadoAposExclusao(
        conflitoId: conflito.id,
        convidadoId: convidadoId,
        novaMesaId: novaMesaId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$convidadoNome recebeu uma nova mesa. '
            'Os outros aparelhos serão atualizados automaticamente.',
          ),
        ),
      );
    } catch (erro) {
      if (mounted) await _mostrarErroResolucao(erro);
    } finally {
      if (mounted) {
        setState(() => _conflitosEmResolucao.remove(chaveResolucao));
      }
    }
  }

  Widget _cardAvisoMesaExcluida({
    required ConflitoSincronizacao conflito,
    required List<Mesa> mesas,
    required List<Convidado> convidados,
    required Map<String, String> usuariosPorId,
  }) {
    final usuarioExclusaoId = _textoRecursivo(conflito.dados, const [
      'usuario_exclusao_id',
    ]);
    final usuarioExclusao = _nomeUsuario(
      fallback: 'Outro usuário',
      nomeDireto:
          _textoRecursivo(conflito.dados, const ['usuario_exclusao_nome']) ??
          conflito.usuarioAlteracaoMesaNome,
      usuarioId: usuarioExclusaoId ?? conflito.usuarioAlteracaoMesaId,
      usuariosPorId: usuariosPorId,
    );

    final mesaExcluida = _nomeMesa(
      mesas: mesas,
      id:
          _textoRecursivo(conflito.dados, const ['mesa_original_id']) ??
          conflito.mesaId,
      numero: _textoRecursivo(conflito.dados, const ['mesa_original_numero']),
      detalhe: _textoRecursivo(conflito.dados, const ['mesa_original_detalhe']),
      fallback: 'Mesa excluída',
    );

    final idsAfetados = conflito.convidadosAfetadosIds.toList();
    final nomesFallback = conflito.convidadosAfetadosNomes;

    final convidadosAfetados = <({String id, String nome, bool chegou})>[];
    for (var indice = 0; indice < idsAfetados.length; indice++) {
      final id = idsAfetados[indice];
      Convidado? encontrado;
      for (final convidado in convidados) {
        if (convidado.id == id) {
          encontrado = convidado;
          break;
        }
      }

      convidadosAfetados.add((
        id: id,
        nome:
            encontrado?.nome ??
            (indice < nomesFallback.length
                ? nomesFallback[indice]
                : 'Convidado não identificado'),
        chegou: encontrado?.chegou ?? false,
      ));
    }

    convidadosAfetados.sort(
      (a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()),
    );

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
                  Icons.table_restaurant_outlined,
                  color: Colors.amber.shade900,
                  size: 30,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mesa excluída: escolha novas mesas',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$mesaExcluida • ${_formatarDataHora(conflito.criadoEm)}',
                        style: TextStyle(
                          color: Colors.grey.shade800,
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
                  '$usuarioExclusao excluiu $mesaExcluida.',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  convidadosAfetados.length == 1
                      ? '1 convidado ficou sem mesa. O check-in e as outras '
                            'alterações foram preservados.'
                      : '${convidadosAfetados.length} convidados ficaram sem '
                            'mesa. Os check-ins e as outras alterações foram '
                            'preservados.',
                ),
                const SizedBox(height: 14),
                ...convidadosAfetados.map((item) {
                  final chaveResolucao = '${conflito.id}:${item.id}';
                  final resolvendo = _conflitosEmResolucao.contains(
                    chaveResolucao,
                  );

                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              item.chegou
                                  ? Icons.check_circle
                                  : Icons.person_outline,
                              color: item.chegou
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.nome,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item.chegou
                              ? 'Presente. Precisa apenas receber uma nova mesa.'
                              : 'Não presente. Precisa receber uma nova mesa.',
                          style: TextStyle(color: Colors.grey.shade800),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: resolvendo
                                ? null
                                : () => _selecionarNovaMesaParaConvidado(
                                    conflito: conflito,
                                    convidadoId: item.id,
                                    convidadoNome: item.nome,
                                    mesas: mesas,
                                  ),
                            icon: resolvendo
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.swap_horiz),
                            label: Text(
                              resolvendo ? 'Salvando...' : 'Escolher nova mesa',
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                TextButton.icon(
                  onPressed: () => _abrirDetalhes(conflito),
                  icon: const Icon(Icons.manage_search),
                  label: const Text('Ver detalhes técnicos'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _blocoAcao({
    required IconData icone,
    required Color cor,
    required String usuario,
    required String frase,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        border: Border.all(color: cor.withValues(alpha: 0.40)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: cor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  usuario,
                  style: TextStyle(
                    color: cor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(frase, style: const TextStyle(fontSize: 14, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardConflito({
    required ConflitoSincronizacao conflito,
    required List<Mesa> mesas,
    required List<Convidado> convidados,
    required Map<String, String> usuariosPorId,
  }) {
    if (conflito.ehAvisoMesaExcluidaRevisao) {
      return _cardAvisoMesaExcluida(
        conflito: conflito,
        mesas: mesas,
        convidados: convidados,
        usuariosPorId: usuariosPorId,
      );
    }

    final resumo = _montarResumo(
      conflito: conflito,
      mesas: mesas,
      convidados: convidados,
      usuariosPorId: usuariosPorId,
    );

    final resolvendo = _conflitosEmResolucao.contains(conflito.id);
    final conflitoMesa = _ehConflitoMesaCheckin(conflito);
    final conflitoConvidadoRemovido =
        _ehConflitoConvidadoRemovidoCheckin(conflito);
    final usuarioExclusao = resumo.localExcluiuMesa
        ? resumo.usuarioLocal
        : resumo.usuarioServidor;
    final usuarioOutraAlteracao = resumo.localExcluiuMesa
        ? resumo.usuarioServidor
        : resumo.usuarioLocal;

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
                        resumo.titulo,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${resumo.nomeConvidado} • ${_formatarDataHora(conflito.criadoEm)}',
                        style: TextStyle(
                          color: Colors.grey.shade800,
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
                  'O que aconteceu',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _blocoAcao(
                  icone: Icons.phone_android,
                  cor: Colors.deepOrange,
                  usuario: resumo.usuarioLocal,
                  frase: resumo.fraseLocal,
                ),
                _blocoAcao(
                  icone: Icons.cloud_outlined,
                  cor: Colors.blue,
                  usuario: resumo.usuarioServidor,
                  frase: resumo.fraseServidor,
                ),
                if (conflito.envolveMesaExcluida &&
                    resumo.convidadosAfetadosNomes.length > 1) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade200),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'A mesa excluída afeta ${resumo.convidadosAfetadosNomes.length} convidados:\n'
                      '${resumo.convidadosAfetadosNomes.join(', ')}',
                      style: TextStyle(color: Colors.red.shade900),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () => _abrirDetalhes(conflito),
                  icon: const Icon(Icons.manage_search),
                  label: const Text('Ver detalhes técnicos'),
                ),
                const Divider(height: 28),
                const Text(
                  'Qual mudança deve permanecer?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 12),
                if (resolvendo)
                  const Center(child: CircularProgressIndicator())
                else if (conflitoConvidadoRemovido)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _confirmarResolucaoGenerica(
                          conflito: conflito,
                          resolucao: 'restaurar_aplicar_local',
                          texto:
                              'Restaurar ${resumo.nomeConvidado} na lista '
                              'oficial e aplicar o check-in feito por '
                              '${resumo.usuarioLocal}?',
                        ),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: Text(
                          'Restaurar ${resumo.nomeConvidado} e aplicar '
                          'check-in de ${resumo.usuarioLocal}',
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _confirmarResolucaoGenerica(
                          conflito: conflito,
                          resolucao: 'manter_servidor',
                          texto:
                              'Manter ${resumo.nomeConvidado} removido, '
                              'conforme a nova lista oficial? O check-in '
                              'offline não será aplicado.',
                        ),
                        icon: const Icon(Icons.person_remove_outlined),
                        label: const Text(
                          'Manter remoção da nova lista oficial',
                        ),
                      ),
                    ],
                  )
                else if (conflitoMesa)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _confirmarResolucaoMesa(
                          conflito: conflito,
                          resolucao: 'restaurar_mesa',
                          texto:
                              'Restaurar ${resumo.mesaOriginal} e manter a mudança feita por $usuarioOutraAlteracao?',
                        ),
                        icon: const Icon(Icons.restore),
                        label: Text(
                          'Restaurar mesa e manter mudança de $usuarioOutraAlteracao',
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _confirmarResolucaoMesa(
                          conflito: conflito,
                          resolucao: 'manter_sem_mesa',
                          texto:
                              'Manter a exclusão feita por $usuarioExclusao? Os convidados afetados ficarão sem essa mesa.',
                        ),
                        icon: const Icon(Icons.delete_outline),
                        label: Text(
                          'Manter exclusão feita por $usuarioExclusao',
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _escolherOutraMesa(
                          conflito: conflito,
                          mesas: mesas,
                        ),
                        icon: const Icon(Icons.swap_horiz),
                        label: const Text('Mover convidado para outra mesa'),
                      ),
                    ],
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _confirmarResolucaoGenerica(
                          conflito: conflito,
                          resolucao:
                              conflito.tipo == 'checkin_convidado_excluido'
                              ? 'restaurar_aplicar_local'
                              : 'aplicar_local',
                          texto: resumo.localExcluiuMesa
                              ? 'Manter a exclusão feita por ${resumo.usuarioLocal}?'
                              : 'Manter a mudança feita por ${resumo.usuarioLocal}?',
                        ),
                        icon: Icon(
                          resumo.localExcluiuMesa
                              ? Icons.delete_outline
                              : Icons.phone_android,
                        ),
                        label: Text(
                          resumo.localExcluiuMesa
                              ? 'Manter exclusão feita por ${resumo.usuarioLocal}'
                              : 'Manter mudança feita por ${resumo.usuarioLocal}',
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _confirmarResolucaoGenerica(
                          conflito: conflito,
                          resolucao: 'manter_servidor',
                          texto: resumo.servidorExcluiuMesa
                              ? 'Manter a exclusão feita por ${resumo.usuarioServidor}?'
                              : 'Manter a mudança feita por ${resumo.usuarioServidor}?',
                        ),
                        icon: Icon(
                          resumo.servidorExcluiuMesa
                              ? Icons.delete_outline
                              : Icons.cloud_done_outlined,
                        ),
                        label: Text(
                          resumo.servidorExcluiuMesa
                              ? 'Manter exclusão feita por ${resumo.usuarioServidor}'
                              : 'Manter mudança feita por ${resumo.usuarioServidor}',
                        ),
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
      appBar: AppBar(
        title: const Text('Conflitos de sincronização'),
        actions: [
          IconButton(
            tooltip: 'Recarregar conflitos',
            onPressed: _recarregarConflitos,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: StreamBuilder<List<Mesa>>(
        stream: _streamMesas,
        builder: (context, snapMesas) {
          final mesas = snapMesas.data ?? <Mesa>[];

          return StreamBuilder<List<Convidado>>(
            stream: _streamConvidados,
            builder: (context, snapConvidados) {
              final convidados = snapConvidados.data ?? <Convidado>[];

              return StreamBuilder<List<UsuarioApp>>(
                stream: _streamUsuarios,
                builder: (context, snapUsuarios) {
                  final usuarios = snapUsuarios.data ?? <UsuarioApp>[];
                  final usuariosPorId = <String, String>{
                    for (final usuario in usuarios) usuario.id: usuario.nome,
                  };

                  return StreamBuilder<List<ConflitoSincronizacao>>(
                    stream: _streamConflitos,
                    builder: (context, snapConflitos) {
                      if (snapConflitos.connectionState ==
                              ConnectionState.waiting &&
                          !snapConflitos.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapConflitos.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 48,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Não foi possível carregar os conflitos.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SelectableText(
                                  snapConflitos.error.toString(),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _recarregarConflitos,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Tentar novamente'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final conflitos = List<ConflitoSincronizacao>.from(
                        snapConflitos.data ?? <ConflitoSincronizacao>[],
                      );

                      final conflitoIdInicial = widget.conflitoIdInicial;
                      if (conflitoIdInicial != null) {
                        conflitos.sort((primeiro, segundo) {
                          if (primeiro.id == conflitoIdInicial) return -1;
                          if (segundo.id == conflitoIdInicial) return 1;
                          return segundo.criadoEm.compareTo(primeiro.criadoEm);
                        });
                      }

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
                          return _cardConflito(
                            conflito: conflitos[index],
                            mesas: mesas,
                            convidados: convidados,
                            usuariosPorId: usuariosPorId,
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
      ),
    );
  }
}

class _ResumoConflito {
  final String titulo;
  final String nomeConvidado;
  final String usuarioLocal;
  final String usuarioServidor;
  final String fraseLocal;
  final String fraseServidor;
  final String mesaOriginal;
  final List<String> convidadosAfetadosNomes;
  final bool localExcluiuMesa;
  final bool servidorExcluiuMesa;

  const _ResumoConflito({
    required this.titulo,
    required this.nomeConvidado,
    required this.usuarioLocal,
    required this.usuarioServidor,
    required this.fraseLocal,
    required this.fraseServidor,
    required this.mesaOriginal,
    required this.convidadosAfetadosNomes,
    required this.localExcluiuMesa,
    required this.servidorExcluiuMesa,
  });
}
