import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../banco/banco_instancia.dart';
import '../banco/banco_local.dart';
import 'controle_versao_lista_servico.dart';
import 'casamento_atual_servico.dart';
import 'dispositivo_servico.dart';
import 'envio_pendencias_servico.dart';
import 'sessao_servico.dart';
import 'versao_registro_servico.dart';

enum StatusSincronizacao {
  aguardando,
  verificandoConexao,
  sincronizando,
  concluida,
  offline,
  erro,
}

/// Resultado resumido da última sincronização.
class ResultadoSincronizacao {
  final bool sucesso;
  final bool semConexao;
  final String mensagem;

  final int usuarios;
  final int mesas;
  final int convidados;
  final int staffs;
  final int mensagens;
  final int eventos;

  /// Indica que o servidor publicou uma nova versão da lista e que a cópia
  /// local anterior precisou ser descartada antes do download.
  final bool listaFoiRedefinida;
  final bool primeiraAtivacaoControleLista;
  final int versaoLista;
  final int operacoesLocaisDescartadas;

  const ResultadoSincronizacao({
    required this.sucesso,
    required this.semConexao,
    required this.mensagem,
    this.usuarios = 0,
    this.mesas = 0,
    this.convidados = 0,
    this.staffs = 0,
    this.mensagens = 0,
    this.eventos = 0,
    this.listaFoiRedefinida = false,
    this.primeiraAtivacaoControleLista = false,
    this.versaoLista = 0,
    this.operacoesLocaisDescartadas = 0,
  });

  int get totalRegistros {
    return usuarios + mesas + convidados + staffs + mensagens + eventos;
  }
}

class _ListaAlteradaDuranteDownloadException implements Exception {
  const _ListaAlteradaDuranteDownloadException();

  @override
  String toString() {
    return 'A versão da lista mudou durante o download.';
  }
}

class _PendenciasNaoEnviadasAntesDaAtualizacaoException
    implements Exception {
  final int quantidade;
  final String detalhes;

  const _PendenciasNaoEnviadasAntesDaAtualizacaoException({
    required this.quantidade,
    required this.detalhes,
  });

  @override
  String toString() {
    return '$quantidade alteração(ões) local(is) não puderam ser enviadas '
        'antes da atualização da lista.\n$detalhes';
  }
}

class _PendenciasCriadasDuranteAtualizacaoException implements Exception {
  final int quantidade;

  const _PendenciasCriadasDuranteAtualizacaoException(this.quantidade);

  @override
  String toString() {
    return '$quantidade nova(s) alteração(ões) local(is) foram criada(s) '
        'enquanto a nova lista estava sendo baixada.';
  }
}

/// Faz a cópia dos dados do Supabase para o banco SQLite.
///
/// Nesta primeira fase, este serviço somente baixa os dados.
/// O envio das alterações offline será implementado depois.
class SincronizacaoServico extends ChangeNotifier {
  SincronizacaoServico._();

  static final SincronizacaoServico instance = SincronizacaoServico._();

  final BancoLocal _banco = bancoLocal;
  final SupabaseClient _supabase = Supabase.instance.client;
  final Connectivity _connectivity = Connectivity();

  static const String _recursoSincronizacao = 'dados_servidor';
  static const int _tamanhoPagina = 1000;
  static const Duration _tempoLimitePorPagina = Duration(seconds: 30);
  static const Duration _tempoLimiteVerificacaoConexao = Duration(seconds: 4);

  StatusSincronizacao _status = StatusSincronizacao.aguardando;
  String _mensagem = 'Aguardando sincronização.';
  String? _ultimoErroTecnico;

  DateTime? _ultimaSincronizacao;
  ResultadoSincronizacao? _ultimoResultado;

  bool _sincronizando = false;

  StatusSincronizacao get status => _status;

  String get mensagem => _mensagem;

  String? get ultimoErroTecnico => _ultimoErroTecnico;

  DateTime? get ultimaSincronizacao => _ultimaSincronizacao;

  ResultadoSincronizacao? get ultimoResultado => _ultimoResultado;

  bool get emAndamento => _sincronizando;

  Future<ResultadoSincronizacao> sincronizarDadosIniciais() async {
    if (_sincronizando) {
      return _ultimoResultado ??
          const ResultadoSincronizacao(
            sucesso: false,
            semConexao: false,
            mensagem: 'A sincronização já está em andamento.',
          );
    }

    _sincronizando = true;
    _ultimoErroTecnico = null;

    try {
      _alterarStatus(
        StatusSincronizacao.verificandoConexao,
        'Verificando conexão...',
      );

      final semNenhumaRede = await _verificarSeEstaSemRede();

      if (semNenhumaRede == true) {
        const resultado = ResultadoSincronizacao(
          sucesso: false,
          semConexao: true,
          mensagem: 'Sem conexão. As alterações continuam salvas no celular.',
        );

        _ultimoResultado = resultado;
        _alterarStatus(StatusSincronizacao.offline, resultado.mensagem);
        return resultado;
      }

      _alterarStatus(
        StatusSincronizacao.sincronizando,
        'Conectando ao servidor...',
      );

      await DispositivoServico.instance.obterOuCriarId();

      _alterarStatus(StatusSincronizacao.sincronizando, 'Validando sessão...');
      await SessaoServico.instance.exigirSessaoAtivaParaSincronizar();

      _alterarStatus(
        StatusSincronizacao.sincronizando,
        'Validando a versão da lista oficial...',
      );

      final controleVersao = await ControleVersaoListaServico.instance
          .validarAntesDoEnvio();
      final listaMudou = controleVersao.dadosLocaisRedefinidos;
      final precisaConfirmarVersao =
          controleVersao.versaoLocalAnterior != controleVersao.versaoServidor;

      _alterarStatus(
        StatusSincronizacao.sincronizando,
        listaMudou
            ? 'Enviando alterações pendentes antes de atualizar a lista...'
            : 'Enviando alterações pendentes...',
      );

      final resultadoEnvio = await EnvioPendenciasServico.instance
          .enviarPendencias();

      if (resultadoEnvio.comErro > 0) {
        _ultimoErroTecnico = resultadoEnvio.detalhesErros.isNotEmpty
            ? resultadoEnvio.detalhesErros.join(
                '\n\n--------------------\n\n',
              )
            : resultadoEnvio.primeiroErro ??
                  'Uma ou mais alterações locais não puderam ser enviadas.';

        try {
          await _registrarErroSincronizacao(_ultimoErroTecnico!);
        } catch (_) {
          // A falha ao registrar o diagnóstico não deve interromper o
          // restante da sincronização.
        }

        if (listaMudou) {
          throw _PendenciasNaoEnviadasAntesDaAtualizacaoException(
            quantidade: resultadoEnvio.comErro,
            detalhes: _ultimoErroTecnico!,
          );
        }
      }

      if (listaMudou) {
        _alterarStatus(
          StatusSincronizacao.sincronizando,
          'Alterações locais protegidas. Baixando a nova lista...',
        );
      }

      _alterarStatus(StatusSincronizacao.sincronizando, 'Baixando usuários...');
      final usuarios = await _buscarTodasAsLinhas('usuarios_app');

      _alterarStatus(StatusSincronizacao.sincronizando, 'Baixando mesas...');
      final mesas = await _buscarTodasAsLinhas('mesas');

      _alterarStatus(
        StatusSincronizacao.sincronizando,
        'Baixando convidados...',
      );
      final convidados = await _buscarTodasAsLinhas('convidados');

      _alterarStatus(StatusSincronizacao.sincronizando, 'Baixando equipe...');
      final staffs = await _buscarTodasAsLinhas('staff');

      _alterarStatus(
        StatusSincronizacao.sincronizando,
        'Baixando mensagens...',
      );
      final mensagens = await _buscarTodasAsLinhas('chat');

      _alterarStatus(
        StatusSincronizacao.sincronizando,
        'Baixando histórico de check-in...',
      );
      final eventos = await _buscarTodasAsLinhas('eventos_checkin');

      _alterarStatus(
        StatusSincronizacao.sincronizando,
        'Carregando conflitos pendentes...',
      );
      final conflitosConvidadosRemovidos =
          await _buscarConflitosConvidadosRemovidosPendentes();

      if (precisaConfirmarVersao) {
        _alterarStatus(
          StatusSincronizacao.sincronizando,
          'Confirmando a versão da lista baixada...',
        );

        final versaoDepoisDoDownload = await ControleVersaoListaServico.instance
            .obterVersaoServidor();

        if (versaoDepoisDoDownload != controleVersao.versaoServidor) {
          throw const _ListaAlteradaDuranteDownloadException();
        }
      }

      _alterarStatus(
        StatusSincronizacao.sincronizando,
        listaMudou
            ? 'Instalando a nova lista com segurança...'
            : 'Salvando os dados no celular...',
      );

      final contextoPendencias = listaMudou
          ? const _ContextoPendencias(
              chavesPendentes: <String>{},
              convidadosComCheckinPendente: <String>{},
              mesasReferenciadasPorPendencias: <String>{},
            )
          : await _carregarContextoPendencias();

      const operacoesLocaisDescartadas = 0;

      await _banco.transaction(() async {
        if (listaMudou) {
          final pendenciasCriadasDuranteDownload = await _banco
              .select(_banco.operacoesPendentesLocais)
              .get();

          if (pendenciasCriadasDuranteDownload.isNotEmpty) {
            throw _PendenciasCriadasDuranteAtualizacaoException(
              pendenciasCriadasDuranteDownload.length,
            );
          }

          // A substituição só começa depois que:
          // 1. todas as pendências anteriores foram processadas pelo servidor;
          // 2. todos os dados novos foram baixados;
          // 3. foi confirmado que nenhuma nova pendência surgiu durante o
          //    download.
          //
          // A fila de operações nunca é apagada por uma atualização de lista.
          // Se qualquer gravação falhar, a transação inteira é revertida e a
          // lista antiga continua disponível.
          await _banco.delete(_banco.eventosCheckinLocais).go();
          await _banco.delete(_banco.mensagensChatLocais).go();
          await _banco.delete(_banco.staffsLocais).go();
          await _banco.delete(_banco.convidadosLocais).go();
          await _banco.delete(_banco.mesasLocais).go();
          await _banco.delete(_banco.sincronizacoesLocais).go();
          await VersaoRegistroServico.instance.limparTodasAsVersoes();
        }

        await _salvarUsuarios(usuarios);
        await _salvarMesas(mesas, contextoPendencias);
        await _salvarConvidados(convidados, contextoPendencias);
        await _salvarStaffs(staffs, contextoPendencias);
        await _salvarMensagens(mensagens, contextoPendencias);
        await _salvarEventos(eventos, contextoPendencias);

        await _reconciliarMesas(mesas, contextoPendencias);
        await _reconciliarEventos(eventos, contextoPendencias);
        await _reconciliarConvidados(convidados, contextoPendencias);

        // Um convidado removido pela nova lista continua visível enquanto o
        // conflito aguarda a decisão do administrador. O registro é mantido
        // somente no SQLite, destacado como conflito. Quando o administrador
        // escolher manter a remoção, o conflito deixa de estar pendente e o
        // próximo sincronismo remove o convidado. Quando escolher restaurar,
        // o registro oficial volta do Supabase normalmente.
        await _preservarConvidadosComConflito(
          conflitosConvidadosRemovidos,
        );

        if (precisaConfirmarVersao) {
          await ControleVersaoListaServico.instance.confirmarVersaoLocal(
            controleVersao.versaoServidor,
          );
        }
      });

      final agora = DateTime.now().toUtc();
      await _registrarFimSincronizacao(agora);

      final mensagemFinal = _montarMensagemSucesso(
        usuarios: usuarios.length,
        mesas: mesas.length,
        convidados: convidados.length,
        staffs: staffs.length,
        mensagens: mensagens.length,
        eventos: eventos.length,
        operacoesEnviadas: resultadoEnvio.enviadas,
        operacoesComErro: resultadoEnvio.comErro,
        listaFoiRedefinida: listaMudou,
        primeiraAtivacaoControleLista: controleVersao.primeiraAtivacao,
        versaoLista: controleVersao.versaoServidor,
      );

      final terminouSemErro = resultadoEnvio.comErro == 0;

      final resultado = ResultadoSincronizacao(
        sucesso: terminouSemErro,
        semConexao: false,
        usuarios: usuarios.length,
        mesas: mesas.length,
        convidados: convidados.length,
        staffs: staffs.length,
        mensagens: mensagens.length,
        eventos: eventos.length,
        listaFoiRedefinida: listaMudou,
        primeiraAtivacaoControleLista: controleVersao.primeiraAtivacao,
        versaoLista: controleVersao.versaoServidor,
        operacoesLocaisDescartadas: operacoesLocaisDescartadas,
        mensagem: mensagemFinal,
      );

      _ultimaSincronizacao = agora;
      _ultimoResultado = resultado;

      _alterarStatus(
        terminouSemErro
            ? StatusSincronizacao.concluida
            : StatusSincronizacao.erro,
        mensagemFinal,
      );

      return resultado;
    } on SessaoInvalidaException catch (erro) {
      return _tratarErro(erro, erro.mensagem);
    } on ValidacaoSessaoIndisponivelException catch (erro) {
      return _tratarErro(erro, erro.mensagem);
    } on _PendenciasNaoEnviadasAntesDaAtualizacaoException catch (erro) {
      return _tratarErro(
        erro,
        'A nova lista não foi instalada porque '
        '${erro.quantidade} alteração(ões) local(is) ainda não puderam ser '
        'processadas pelo servidor. A lista anterior foi mantida no celular.',
      );
    } on _PendenciasCriadasDuranteAtualizacaoException catch (erro) {
      return _tratarErro(
        erro,
        'Uma nova alteração foi feita enquanto a lista estava sendo baixada. '
        'A lista anterior foi mantida. Sincronize novamente para enviar a '
        'alteração antes de instalar a nova lista.',
      );
    } on _ListaAlteradaDuranteDownloadException catch (erro) {
      return _tratarErro(
        erro,
        'A lista oficial mudou durante o download. '
        'A cópia antiga foi mantida no celular. Tente sincronizar novamente.',
      );
    } on TimeoutException catch (erro) {
      return _tratarErro(
        erro,
        'O servidor demorou para responder. '
        'As alterações continuam salvas no celular.',
      );
    } catch (erro) {
      return _tratarErro(
        erro,
        'Não foi possível concluir a sincronização. '
        'As alterações continuam salvas no celular.',
      );
    } finally {
      _sincronizando = false;
      notifyListeners();
    }
  }

  /// Verifica se o aparelho está explicitamente sem rede.
  ///
  /// O connectivity_plus é usado somente como uma indicação. Em alguns
  /// aparelhos essa consulta pode demorar ou não responder. Nesse caso, o
  /// aplicativo continua e tenta falar diretamente com o Supabase, evitando
  /// ficar preso indefinidamente em "Verificando conexão...".
  Future<bool?> _verificarSeEstaSemRede() async {
    try {
      final resultados = await _connectivity.checkConnectivity().timeout(
        _tempoLimiteVerificacaoConexao,
      );

      return resultados.isEmpty ||
          resultados.every((resultado) => resultado == ConnectivityResult.none);
    } on TimeoutException {
      debugPrint(
        'A verificação de conectividade excedeu o tempo limite. '
        'A sincronização tentará acessar o Supabase diretamente.',
      );
      return null;
    } catch (erro) {
      debugPrint(
        'Não foi possível consultar o estado da rede: $erro. '
        'A sincronização tentará acessar o Supabase diretamente.',
      );
      return null;
    }
  }

  /// Busca todas as linhas usando páginas de até 1.000 registros.
  Future<List<Map<String, dynamic>>> _buscarTodasAsLinhas(
    String nomeTabela,
  ) async {
    final todasAsLinhas = <Map<String, dynamic>>[];
    var inicio = 0;

    while (true) {
      final fim = inicio + _tamanhoPagina - 1;

      final consulta = _tabelaPertenceAoCasamento(nomeTabela)
          ? _supabase
                .from(nomeTabela)
                .select()
                .eq('casamento_id', CasamentoAtualServico.instance.casamentoId)
                .order('created_at', ascending: true)
                .range(inicio, fim)
          : _supabase
                .from(nomeTabela)
                .select()
                .order('created_at', ascending: true)
                .range(inicio, fim);

      final resposta = await consulta.timeout(_tempoLimitePorPagina);

      final pagina = resposta
          .map((registro) => Map<String, dynamic>.from(registro))
          .toList();

      todasAsLinhas.addAll(pagina);

      if (pagina.length < _tamanhoPagina) {
        break;
      }

      inicio += _tamanhoPagina;
    }

    return todasAsLinhas;
  }

  bool _tabelaPertenceAoCasamento(String tabela) {
    return const {
      'mesas',
      'convidados',
      'staff',
      'chat',
      'eventos_checkin',
      'conflitos_sincronizacao',
      'controle_lista',
    }.contains(tabela);
  }

  /// Lê as operações ainda não enviadas para evitar que uma cópia do
  /// servidor apague silenciosamente uma alteração offline.
  Future<_ContextoPendencias> _carregarContextoPendencias() async {
    final operacoes = await _banco
        .select(_banco.operacoesPendentesLocais)
        .get();

    final chavesPendentes = <String>{};
    final convidadosComCheckinPendente = <String>{};
    final mesasReferenciadasPorPendencias = <String>{};

    for (final operacao in operacoes) {
      chavesPendentes.add(
        _montarChavePendente(operacao.entidade, operacao.entidadeId),
      );

      Map<String, dynamic>? payload;

      try {
        final valorDecodificado = jsonDecode(operacao.payloadJson);

        if (valorDecodificado is Map) {
          payload = Map<String, dynamic>.from(valorDecodificado);
        }
      } catch (_) {
        // A operação continua preservada na fila. Um JSON inválido não deve
        // interromper a reconciliação dos outros registros.
      }

      if (operacao.entidade == 'convidado' && payload != null) {
        final mesaId = payload['mesa_id']?.toString();

        if (mesaId != null && mesaId.isNotEmpty) {
          mesasReferenciadasPorPendencias.add(mesaId);
        }
      }

      if (operacao.entidade == 'evento_checkin' && payload != null) {
        final convidadoId = payload['convidado_id']?.toString();

        if (convidadoId != null && convidadoId.isNotEmpty) {
          convidadosComCheckinPendente.add(convidadoId);
        }
      }
    }

    for (final convidadoId in convidadosComCheckinPendente) {
      final consulta = _banco.select(_banco.convidadosLocais)
        ..where((tabela) => tabela.id.equals(convidadoId));

      final convidado = await consulta.getSingleOrNull();
      final mesaId = convidado?.mesaId;

      if (mesaId != null && mesaId.isNotEmpty) {
        mesasReferenciadasPorPendencias.add(mesaId);
      }
    }

    return _ContextoPendencias(
      chavesPendentes: chavesPendentes,
      convidadosComCheckinPendente: convidadosComCheckinPendente,
      mesasReferenciadasPorPendencias: mesasReferenciadasPorPendencias,
    );
  }

  Future<List<Map<String, dynamic>>>
  _buscarConflitosConvidadosRemovidosPendentes() async {
    final resposta = await _supabase
        .from('conflitos_sincronizacao')
        .select()
        .eq('casamento_id', CasamentoAtualServico.instance.casamentoId)
        .eq('status', 'pendente')
        .eq('tipo', 'convidado_inexistente_durante_checkin')
        .order('created_at', ascending: true)
        .timeout(_tempoLimitePorPagina);

    return resposta
        .map((registro) => Map<String, dynamic>.from(registro))
        .toList();
  }

  Future<void> _preservarConvidadosComConflito(
    List<Map<String, dynamic>> conflitos,
  ) async {
    for (final conflito in conflitos) {
      final dados = _converterMapaJson(conflito['dados']);
      final convidadoId = _primeiroTextoNaoVazio([
        conflito['convidado_id'],
        dados['convidado_id'],
      ]);
      final eventoId = _primeiroTextoNaoVazio([
        conflito['evento_checkin_id'],
        dados['evento_checkin_id'],
      ]);
      final usuarioId = _primeiroTextoNaoVazio([
        conflito['usuario_checkin_id'],
        dados['usuario_local_id'],
      ]);
      final nome = _primeiroTextoNaoVazio([
        dados['convidado_nome'],
        _primeiroItemLista(dados['convidados_afetados_nomes']),
      ]);

      if (convidadoId == null ||
          eventoId == null ||
          usuarioId == null ||
          nome == null) {
        debugPrint(
          'Conflito de convidado removido sem dados suficientes para '
          'preservação local: ${conflito['id']}',
        );
        continue;
      }

      final mesaIdAntiga = _primeiroTextoNaoVazio([
        conflito['mesa_id'],
        dados['mesa_id_contexto'],
        dados['mesa_original_id'],
      ]);
      final mesaNumero = _lerInteiroOpcional(dados['mesa_numero_contexto']);
      final mesaDestinoId = await _encontrarMesaLocalDoConflito(
        mesaIdAntiga: mesaIdAntiga,
        mesaNumero: mesaNumero,
      );

      final estadoResultante = _lerBooleano(
        dados['estado_resultante'],
        padrao: false,
      );
      final dataDispositivo = _lerData(
        dados['data_dispositivo'],
        padrao: _lerData(
          conflito['created_at'],
          padrao: DateTime.now().toUtc(),
        ),
      );
      final sequenciaDispositivo = _lerInteiro(
        dados['sequencia_dispositivo'],
        padrao: 1,
      );
      final dispositivoId = _primeiroTextoNaoVazio([
            dados['dispositivo_id'],
          ]) ??
          'conflito-${conflito['id']}';
      final tipoAcao = _primeiroTextoNaoVazio([
            dados['tipo_acao'],
          ]) ??
          (estadoResultante ? 'confirmou_chegada' : 'removeu_chegada');
      final eventosBaseJson = _converterListaParaJson(dados['eventos_base']);
      final observacao = _lerTextoOpcional(dados['observacao']);
      final dataServidor = _lerDataOpcional(conflito['created_at']);
      final agora = DateTime.now().toUtc();

      await _banco
          .into(_banco.convidadosLocais)
          .insertOnConflictUpdate(
            ConvidadosLocaisCompanion.insert(
              id: convidadoId,
              nome: nome,
              mesaId: Value(mesaDestinoId),
              chegou: Value(estadoResultante),
              temConflito: const Value(true),
              eventosAtuaisJson: Value(jsonEncode([eventoId])),
              criadoEm: dataDispositivo,
              atualizadoEm: agora,
              excluido: const Value(false),
            ),
          );

      await _banco
          .into(_banco.eventosCheckinLocais)
          .insertOnConflictUpdate(
            EventosCheckinLocaisCompanion.insert(
              id: eventoId,
              convidadoId: convidadoId,
              usuarioId: usuarioId,
              tipoAcao: tipoAcao,
              estadoResultante: estadoResultante,
              eventosBaseJson: Value(eventosBaseJson),
              dataDispositivo: dataDispositivo,
              sequenciaDispositivo: sequenciaDispositivo,
              dispositivoId: dispositivoId,
              dataServidor: Value(dataServidor),
              observacao: Value(observacao),
              sincronizado: const Value(true),
            ),
          );
    }
  }

  Future<String?> _encontrarMesaLocalDoConflito({
    required String? mesaIdAntiga,
    required int? mesaNumero,
  }) async {
    if (mesaIdAntiga != null) {
      final porId = _banco.select(_banco.mesasLocais)
        ..where(
          (tabela) =>
              tabela.id.equals(mesaIdAntiga) &
              tabela.excluido.equals(false),
        );

      final mesa = await porId.getSingleOrNull();
      if (mesa != null) {
        return mesa.id;
      }
    }

    if (mesaNumero != null) {
      final porNumero = _banco.select(_banco.mesasLocais)
        ..where(
          (tabela) =>
              tabela.numero.equals(mesaNumero) &
              tabela.excluido.equals(false),
        )
        ..orderBy([(tabela) => OrderingTerm.asc(tabela.criadoEm)])
        ..limit(1);

      final mesa = await porNumero.getSingleOrNull();
      if (mesa != null) {
        return mesa.id;
      }
    }

    return null;
  }

  Map<String, dynamic> _converterMapaJson(dynamic valor) {
    if (valor is Map<String, dynamic>) {
      return valor;
    }

    if (valor is Map) {
      return Map<String, dynamic>.from(valor);
    }

    if (valor is String && valor.trim().isNotEmpty) {
      try {
        final convertido = jsonDecode(valor);
        if (convertido is Map) {
          return Map<String, dynamic>.from(convertido);
        }
      } catch (_) {
        // Um conflito malformado é ignorado individualmente.
      }
    }

    return <String, dynamic>{};
  }

  String? _primeiroTextoNaoVazio(List<dynamic> valores) {
    for (final valor in valores) {
      final texto = valor?.toString().trim();
      if (texto != null && texto.isNotEmpty && texto != 'null') {
        return texto;
      }
    }

    return null;
  }

  dynamic _primeiroItemLista(dynamic valor) {
    if (valor is List && valor.isNotEmpty) {
      return valor.first;
    }

    return null;
  }

  int? _lerInteiroOpcional(dynamic valor) {
    if (valor == null) {
      return null;
    }

    if (valor is int) {
      return valor;
    }

    if (valor is num) {
      return valor.toInt();
    }

    return int.tryParse(valor.toString());
  }

  Future<void> _salvarUsuarios(List<Map<String, dynamic>> registros) async {
    for (final registro in registros) {
      final id = _lerTextoObrigatorio(registro['id']);
      final criadoEm = _lerData(
        registro['created_at'],
        padrao: DateTime.now().toUtc(),
      );

      await _banco
          .into(_banco.usuariosAppLocais)
          .insertOnConflictUpdate(
            UsuariosAppLocaisCompanion.insert(
              id: id,
              nome: _lerTextoObrigatorio(registro['nome']),
              ordem: Value(_lerInteiro(registro['ordem'], padrao: 0)),
              ativo: Value(_lerBooleano(registro['ativo'], padrao: true)),
              criadoEm: criadoEm,
            ),
          );
    }
  }

  Future<void> _salvarMesas(
    List<Map<String, dynamic>> registros,
    _ContextoPendencias pendencias,
  ) async {
    for (final registro in registros) {
      final id = _lerTextoObrigatorio(registro['id']);

      if (_possuiPendencia(pendencias, entidade: 'mesa', entidadeId: id)) {
        continue;
      }

      final criadoEm = _lerData(
        registro['created_at'],
        padrao: DateTime.now().toUtc(),
      );

      final atualizadoEm = _lerData(registro['updated_at'], padrao: criadoEm);

      await _banco
          .into(_banco.mesasLocais)
          .insertOnConflictUpdate(
            MesasLocaisCompanion.insert(
              id: id,
              numero: Value(_lerInteiro(registro['numero'], padrao: 0)),
              detalhe: Value(_lerTextoOpcional(registro['detalhe'])),
              criadoEm: criadoEm,
              atualizadoEm: atualizadoEm,
              excluido: Value(registro['deleted_at'] != null),
            ),
          );

      await VersaoRegistroServico.instance.salvarVersaoConfirmada(
        entidade: 'mesa',
        id: id,
        updatedAt:
            registro['updated_at']?.toString() ??
            atualizadoEm.toIso8601String(),
      );
    }
  }

  Future<void> _salvarConvidados(
    List<Map<String, dynamic>> registros,
    _ContextoPendencias pendencias,
  ) async {
    for (final registro in registros) {
      final id = _lerTextoObrigatorio(registro['id']);

      final possuiAlteracaoDireta = _possuiPendencia(
        pendencias,
        entidade: 'convidado',
        entidadeId: id,
      );

      final possuiCheckinPendente = pendencias.convidadosComCheckinPendente
          .contains(id);

      if (possuiAlteracaoDireta || possuiCheckinPendente) {
        continue;
      }

      final criadoEm = _lerData(
        registro['created_at'],
        padrao: DateTime.now().toUtc(),
      );

      final atualizadoEm = _lerData(registro['updated_at'], padrao: criadoEm);

      await _banco
          .into(_banco.convidadosLocais)
          .insertOnConflictUpdate(
            ConvidadosLocaisCompanion.insert(
              id: id,
              nome: _lerTextoObrigatorio(registro['nome']),
              mesaId: Value(_lerTextoOpcional(registro['mesa_id'])),
              chegou: Value(_lerBooleano(registro['chegou'], padrao: false)),
              temConflito: Value(
                _lerBooleano(registro['tem_conflito'], padrao: false),
              ),
              eventosAtuaisJson: Value(
                _converterListaParaJson(registro['eventos_atuais']),
              ),
              criadoEm: criadoEm,
              atualizadoEm: atualizadoEm,
              excluido: Value(registro['deleted_at'] != null),
            ),
          );

      await VersaoRegistroServico.instance.salvarVersaoConfirmada(
        entidade: 'convidado',
        id: id,
        updatedAt:
            registro['updated_at']?.toString() ??
            atualizadoEm.toIso8601String(),
      );
    }
  }

  Future<void> _salvarStaffs(
    List<Map<String, dynamic>> registros,
    _ContextoPendencias pendencias,
  ) async {
    for (final registro in registros) {
      final id = _lerTextoObrigatorio(registro['id']);

      if (_possuiPendencia(pendencias, entidade: 'staff', entidadeId: id)) {
        continue;
      }

      final criadoEm = _lerData(
        registro['created_at'],
        padrao: DateTime.now().toUtc(),
      );

      final atualizadoEm = _lerData(registro['updated_at'], padrao: criadoEm);

      await _banco
          .into(_banco.staffsLocais)
          .insertOnConflictUpdate(
            StaffsLocaisCompanion.insert(
              id: id,
              nome: _lerTextoObrigatorio(registro['nome']),
              sobrenome: _lerTextoObrigatorio(registro['sobrenome']),
              ocupacao: _lerTextoObrigatorio(registro['ocupacao']),
              criadoEm: criadoEm,
              atualizadoEm: atualizadoEm,
              excluido: Value(registro['deleted_at'] != null),
            ),
          );
    }
  }

  Future<void> _salvarMensagens(
    List<Map<String, dynamic>> registros,
    _ContextoPendencias pendencias,
  ) async {
    for (final registro in registros) {
      final id = _lerTextoObrigatorio(registro['id']);

      if (_possuiPendencia(
        pendencias,
        entidade: 'mensagem_chat',
        entidadeId: id,
      )) {
        continue;
      }

      final criadoEm = _lerData(
        registro['created_at'],
        padrao: DateTime.now().toUtc(),
      );

      final dataServidor = _lerDataOpcional(registro['updated_at']);

      await _banco
          .into(_banco.mensagensChatLocais)
          .insertOnConflictUpdate(
            MensagensChatLocaisCompanion.insert(
              id: id,
              staffId: _lerTextoObrigatorio(registro['staff_id']),
              mensagem: _lerTextoObrigatorio(registro['mensagem']),
              criadoEm: criadoEm,
              dataServidor: Value(dataServidor),
              excluido: Value(registro['deleted_at'] != null),
            ),
          );
    }
  }

  Future<void> _salvarEventos(
    List<Map<String, dynamic>> registros,
    _ContextoPendencias pendencias,
  ) async {
    for (final registro in registros) {
      final id = _lerTextoObrigatorio(registro['id']);

      if (_possuiPendencia(
        pendencias,
        entidade: 'evento_checkin',
        entidadeId: id,
      )) {
        continue;
      }

      await _banco
          .into(_banco.eventosCheckinLocais)
          .insertOnConflictUpdate(
            EventosCheckinLocaisCompanion.insert(
              id: id,
              convidadoId: _lerTextoObrigatorio(registro['convidado_id']),
              usuarioId: _lerTextoObrigatorio(registro['usuario_id']),
              tipoAcao: _lerTextoObrigatorio(registro['tipo_acao']),
              estadoResultante: _lerBooleano(
                registro['estado_resultante'],
                padrao: false,
              ),
              eventosBaseJson: Value(
                _converterListaParaJson(registro['eventos_base']),
              ),
              dataDispositivo: _lerData(
                registro['data_dispositivo'],
                padrao: DateTime.now().toUtc(),
              ),
              sequenciaDispositivo: _lerInteiro(
                registro['sequencia_dispositivo'],
                padrao: 1,
              ),
              dispositivoId: _lerTextoObrigatorio(registro['dispositivo_id']),
              dataServidor: Value(_lerDataOpcional(registro['data_servidor'])),
              observacao: Value(_lerTextoOpcional(registro['observacao'])),
              sincronizado: const Value(true),
            ),
          );
    }
  }

  /// Remove do SQLite mesas que não existem mais como registros ativos no
  /// Supabase. Mesas com alterações offline pendentes são preservadas.
  Future<void> _reconciliarMesas(
    List<Map<String, dynamic>> registrosServidor,
    _ContextoPendencias pendencias,
  ) async {
    final idsAtivosServidor = _obterIdsAtivosServidor(registrosServidor);

    final mesasLocais = await _banco.select(_banco.mesasLocais).get();

    for (final mesa in mesasLocais) {
      if (idsAtivosServidor.contains(mesa.id)) {
        continue;
      }

      final possuiAlteracaoPendente = _possuiPendencia(
        pendencias,
        entidade: 'mesa',
        entidadeId: mesa.id,
      );

      final possuiDependenciaPendente = pendencias
          .mesasReferenciadasPorPendencias
          .contains(mesa.id);

      if (possuiAlteracaoPendente || possuiDependenciaPendente) {
        continue;
      }

      await (_banco.update(
        _banco.convidadosLocais,
      )..where((tabela) => tabela.mesaId.equals(mesa.id))).write(
        ConvidadosLocaisCompanion(
          mesaId: const Value<String?>(null),
          atualizadoEm: Value(DateTime.now().toUtc()),
        ),
      );

      await (_banco.delete(
        _banco.mesasLocais,
      )..where((tabela) => tabela.id.equals(mesa.id))).go();

      await VersaoRegistroServico.instance.removerVersao(
        entidade: 'mesa',
        id: mesa.id,
      );
    }
  }

  /// Remove do SQLite convidados que já não existem como registros ativos no
  /// Supabase. Alterações locais e check-ins ainda pendentes são preservados.
  Future<void> _reconciliarConvidados(
    List<Map<String, dynamic>> registrosServidor,
    _ContextoPendencias pendencias,
  ) async {
    final idsAtivosServidor = _obterIdsAtivosServidor(registrosServidor);

    final convidadosLocais = await _banco.select(_banco.convidadosLocais).get();

    for (final convidado in convidadosLocais) {
      if (idsAtivosServidor.contains(convidado.id)) {
        continue;
      }

      final possuiAlteracaoPendente = _possuiPendencia(
        pendencias,
        entidade: 'convidado',
        entidadeId: convidado.id,
      );

      final possuiCheckinPendente = pendencias.convidadosComCheckinPendente
          .contains(convidado.id);

      if (possuiAlteracaoPendente || possuiCheckinPendente) {
        continue;
      }

      await (_banco.delete(
        _banco.eventosCheckinLocais,
      )..where((tabela) => tabela.convidadoId.equals(convidado.id))).go();

      await (_banco.delete(
        _banco.convidadosLocais,
      )..where((tabela) => tabela.id.equals(convidado.id))).go();

      await VersaoRegistroServico.instance.removerVersao(
        entidade: 'convidado',
        id: convidado.id,
      );
    }
  }

  /// Remove eventos locais que não existem mais no servidor, exceto eventos
  /// que ainda aguardam envio.
  Future<void> _reconciliarEventos(
    List<Map<String, dynamic>> registrosServidor,
    _ContextoPendencias pendencias,
  ) async {
    final idsServidor = registrosServidor
        .map((registro) => _lerTextoObrigatorio(registro['id']))
        .where((id) => id.isNotEmpty)
        .toSet();

    final eventosLocais = await _banco
        .select(_banco.eventosCheckinLocais)
        .get();

    for (final evento in eventosLocais) {
      if (idsServidor.contains(evento.id)) {
        continue;
      }

      if (_possuiPendencia(
        pendencias,
        entidade: 'evento_checkin',
        entidadeId: evento.id,
      )) {
        continue;
      }

      await (_banco.delete(
        _banco.eventosCheckinLocais,
      )..where((tabela) => tabela.id.equals(evento.id))).go();
    }
  }

  Set<String> _obterIdsAtivosServidor(List<Map<String, dynamic>> registros) {
    return registros
        .where((registro) => registro['deleted_at'] == null)
        .map((registro) => _lerTextoObrigatorio(registro['id']))
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<void> _registrarFimSincronizacao(DateTime agora) async {
    await _banco
        .into(_banco.sincronizacoesLocais)
        .insertOnConflictUpdate(
          SincronizacoesLocaisCompanion.insert(
            recurso: _recursoSincronizacao,
            ultimaSincronizacao: Value(agora),
            cursorServidor: Value(agora.toIso8601String()),
            emAndamento: const Value(false),
            ultimoErro: const Value<String?>(null),
          ),
        );
  }

  Future<void> _registrarErroSincronizacao(String erro) async {
    final existente = await _buscarRegistroSincronizacao();

    await _banco
        .into(_banco.sincronizacoesLocais)
        .insertOnConflictUpdate(
          SincronizacoesLocaisCompanion.insert(
            recurso: _recursoSincronizacao,
            ultimaSincronizacao: Value(existente?.ultimaSincronizacao),
            cursorServidor: Value(existente?.cursorServidor),
            emAndamento: const Value(false),
            ultimoErro: Value(erro),
          ),
        );
  }

  Future<SincronizacaoLocalRegistro?> _buscarRegistroSincronizacao() async {
    final consulta = _banco.select(_banco.sincronizacoesLocais)
      ..where((tabela) => tabela.recurso.equals(_recursoSincronizacao));

    return consulta.getSingleOrNull();
  }

  Future<ResultadoSincronizacao> _tratarErro(
    Object erro,
    String mensagemAmigavel,
  ) async {
    _ultimoErroTecnico = erro.toString();

    try {
      await _registrarErroSincronizacao(_ultimoErroTecnico!);
    } catch (_) {
      // O erro original continua sendo o mais importante.
    }

    final resultado = ResultadoSincronizacao(
      sucesso: false,
      semConexao: false,
      mensagem: mensagemAmigavel,
    );

    _ultimoResultado = resultado;

    _alterarStatus(StatusSincronizacao.erro, mensagemAmigavel);

    return resultado;
  }

  bool _possuiPendencia(
    _ContextoPendencias pendencias, {
    required String entidade,
    required String entidadeId,
  }) {
    return pendencias.chavesPendentes.contains(
      _montarChavePendente(entidade, entidadeId),
    );
  }

  String _montarChavePendente(String entidade, String entidadeId) {
    return '$entidade::$entidadeId';
  }

  String _montarMensagemSucesso({
    required int usuarios,
    required int mesas,
    required int convidados,
    required int staffs,
    required int mensagens,
    required int eventos,
    required int operacoesEnviadas,
    required int operacoesComErro,
    required bool listaFoiRedefinida,
    required bool primeiraAtivacaoControleLista,
    required int versaoLista,
  }) {
    String resumoEnvio;

    if (operacoesEnviadas == 0 && operacoesComErro == 0) {
      resumoEnvio = 'Nenhuma alteração local estava pendente.';
    } else if (operacoesComErro == 0) {
      resumoEnvio = '$operacoesEnviadas alterações locais foram enviadas.';
    } else {
      resumoEnvio =
          '$operacoesEnviadas alterações foram enviadas e '
          '$operacoesComErro continuam pendentes.';
    }

    var avisoLista = '';

    if (listaFoiRedefinida) {
      final descricao = primeiraAtivacaoControleLista
          ? 'Controle da lista ativado'
          : 'Nova lista oficial instalada com segurança';

      avisoLista = '$descricao (versão $versaoLista). ';
    }

    return '${avisoLista}Sincronizado: '
        '$usuarios usuários, '
        '$mesas mesas, '
        '$convidados convidados, '
        '$staffs staff, '
        '$mensagens mensagens e '
        '$eventos eventos. '
        '$resumoEnvio';
  }

  void _alterarStatus(StatusSincronizacao novoStatus, String novaMensagem) {
    _status = novoStatus;
    _mensagem = novaMensagem;
    notifyListeners();
  }

  String _lerTextoObrigatorio(dynamic valor) {
    return valor?.toString() ?? '';
  }

  String? _lerTextoOpcional(dynamic valor) {
    if (valor == null) {
      return null;
    }

    return valor.toString();
  }

  int _lerInteiro(dynamic valor, {required int padrao}) {
    if (valor is int) {
      return valor;
    }

    if (valor is num) {
      return valor.toInt();
    }

    return int.tryParse(valor?.toString() ?? '') ?? padrao;
  }

  bool _lerBooleano(dynamic valor, {required bool padrao}) {
    if (valor is bool) {
      return valor;
    }

    final texto = valor?.toString().toLowerCase();

    if (texto == 'true' || texto == '1') {
      return true;
    }

    if (texto == 'false' || texto == '0') {
      return false;
    }

    return padrao;
  }

  DateTime _lerData(dynamic valor, {required DateTime padrao}) {
    if (valor is DateTime) {
      return valor.toUtc();
    }

    final dataConvertida = DateTime.tryParse(valor?.toString() ?? '');

    return dataConvertida?.toUtc() ?? padrao.toUtc();
  }

  DateTime? _lerDataOpcional(dynamic valor) {
    if (valor == null) {
      return null;
    }

    if (valor is DateTime) {
      return valor.toUtc();
    }

    return DateTime.tryParse(valor.toString())?.toUtc();
  }

  String _converterListaParaJson(dynamic valor) {
    if (valor == null) {
      return '[]';
    }

    if (valor is List) {
      return jsonEncode(valor.map((item) => item.toString()).toList());
    }

    final texto = valor.toString().trim();

    if (texto.isEmpty) {
      return '[]';
    }

    if (texto.startsWith('{') && texto.endsWith('}')) {
      final conteudo = texto.substring(1, texto.length - 1);

      if (conteudo.trim().isEmpty) {
        return '[]';
      }

      final itens = conteudo
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();

      return jsonEncode(itens);
    }

    try {
      final valorDecodificado = jsonDecode(texto);

      if (valorDecodificado is List) {
        return jsonEncode(valorDecodificado);
      }
    } catch (_) {
      // Continua para o retorno seguro abaixo.
    }

    return '[]';
  }
}

class _ContextoPendencias {
  final Set<String> chavesPendentes;
  final Set<String> convidadosComCheckinPendente;
  final Set<String> mesasReferenciadasPorPendencias;

  const _ContextoPendencias({
    required this.chavesPendentes,
    required this.convidadosComCheckinPendente,
    required this.mesasReferenciadasPorPendencias,
  });
}
