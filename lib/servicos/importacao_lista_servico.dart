import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../modelos/modelos_importacao.dart';
import 'casamento_atual_servico.dart';
import 'sessao_servico.dart';

class ImportacaoListaServico {
  ImportacaoListaServico._();

  static final ImportacaoListaServico instance = ImportacaoListaServico._();

  static const int _tamanhoMaximoBytes = 30 * 1024 * 1024;
  static const List<String> _extensoesPermitidas = [
    'pdf',
    'xlsx',
    'xls',
    'csv',
    'tsv',
    'png',
    'jpg',
    'jpeg',
    'webp',
  ];

  final SupabaseClient _supabase = Supabase.instance.client;
  final ImagePicker _imagePicker = ImagePicker();

  Future<ResultadoPreviaImportacao?> selecionarEAnalisarArquivo() async {
    final selecao = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _extensoesPermitidas,
      allowMultiple: false,
      withData: true,
    );

    if (selecao == null || selecao.files.isEmpty) {
      return null;
    }

    final arquivo = selecao.files.single;
    final extensao = (arquivo.extension ?? _obterExtensao(arquivo.name))
        .toLowerCase();

    if (!_extensoesPermitidas.contains(extensao)) {
      throw const ImportacaoListaException(
        'Formato não permitido. Selecione PDF, Excel, CSV ou uma imagem.',
      );
    }

    final bytes = await _obterBytes(arquivo);

    if (bytes.isEmpty) {
      throw const ImportacaoListaException('O arquivo selecionado está vazio.');
    }

    if (bytes.length > _tamanhoMaximoBytes) {
      throw const ImportacaoListaException(
        'O arquivo ultrapassa 30 MB. Reduza o tamanho e tente novamente.',
      );
    }

    return _analisarBytes(
      arquivoNome: arquivo.name,
      mimeType: _obterMimeType(extensao),
      bytes: bytes,
    );
  }

  Future<ResultadoPreviaImportacao?> tirarFotoEAnalisar() async {
    late final XFile? foto;
    try {
      foto = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
      );
    } on PlatformException catch (erro) {
      if (erro.code == 'camera_access_denied') {
        throw const ImportacaoListaException(
          'O acesso à câmera foi negado. Permita a câmera nas configurações do aparelho e tente novamente.',
        );
      }
      throw const ImportacaoListaException(
        'Não foi possível abrir a câmera. Tente novamente.',
      );
    }

    if (foto == null) {
      return null;
    }

    final bytes = await foto.readAsBytes();
    if (bytes.isEmpty) {
      throw const ImportacaoListaException('A foto selecionada está vazia.');
    }

    return _analisarBytes(
      arquivoNome: foto.name.isEmpty ? 'foto_lista.jpg' : foto.name,
      mimeType: 'image/jpeg',
      bytes: bytes,
    );
  }

  Future<ResultadoPreviaImportacao> _analisarBytes({
    required String arquivoNome,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    if (bytes.length > _tamanhoMaximoBytes) {
      throw const ImportacaoListaException(
        'O arquivo ultrapassa 30 MB. Reduza o tamanho e tente novamente.',
      );
    }

    final usuario = SessaoServico.instance.usuarioAtual;
    if (usuario == null) {
      throw const ImportacaoListaException(
        'Sua sessão não está ativa. Entre novamente no aplicativo.',
      );
    }

    try {
      final resposta = await _supabase.functions
          .invoke(
            'analisar-lista-convidados',
            body: {
              'arquivo_nome': arquivoNome,
              'mime_type': mimeType,
              'arquivo_base64': base64Encode(bytes),
              'casamento_id': CasamentoAtualServico.instance.casamentoId,
            },
          )
          .timeout(const Duration(minutes: 3));

      final dados = _converterMapa(resposta.data);

      if (resposta.status < 200 || resposta.status >= 300) {
        throw ImportacaoListaException(
          _obterMensagemErro(dados) ??
              'O servidor não conseguiu analisar o arquivo.',
        );
      }

      final resultadoBruto = dados['resultado'];
      if (resultadoBruto is! Map) {
        throw const ImportacaoListaException(
          'A IA respondeu em um formato inesperado. Tente novamente.',
        );
      }

      return _normalizarMesasSemNumero(
        ResultadoPreviaImportacao.fromJson(
          Map<String, dynamic>.from(resultadoBruto),
        ),
      );
    } on ImportacaoListaException {
      rethrow;
    } on FunctionException catch (erro) {
      final detalhes = _converterMapa(erro.details);
      throw ImportacaoListaException(
        _obterMensagemErro(detalhes) ??
            'Não foi possível analisar a lista agora. Tente novamente.',
      );
    } on SocketException {
      throw const ImportacaoListaException(
        'Sem conexão com a internet. A análise por IA precisa estar online.',
      );
    } on TimeoutException {
      throw const ImportacaoListaException(
        'A análise demorou mais que o esperado. Tente novamente em instantes.',
      );
    } on FormatException {
      throw const ImportacaoListaException(
        'Não foi possível interpretar o resultado da análise. Tente novamente.',
      );
    } catch (_) {
      throw const ImportacaoListaException(
        'Não foi possível analisar a lista agora. Tente novamente.',
      );
    }
  }

  ResultadoPreviaImportacao _normalizarMesasSemNumero(
    ResultadoPreviaImportacao resultado,
  ) {
    final numerosUsados = resultado.mesas
        .map((mesa) => mesa.numero)
        .whereType<int>()
        .where((numero) => numero >= 0)
        .toSet();
    var proximoNumero = 1;
    final avisos = resultado.avisos
        .where((aviso) => aviso.tipo != TipoAvisoImportacao.mesaSemNumero)
        .toList();
    final mesas = <MesaPreviaImportacao>[];

    for (final mesa in resultado.mesas) {
      final numeroAtual = mesa.numero;
      if (numeroAtual != null && numeroAtual >= 0) {
        mesas.add(mesa);
        continue;
      }

      while (numerosUsados.contains(proximoNumero)) {
        proximoNumero++;
      }
      final numeroGerado = proximoNumero++;
      numerosUsados.add(numeroGerado);
      mesas.add(
        mesa.copyWith(numero: numeroGerado, numeroGeradoAutomaticamente: true),
      );
      avisos.add(
        AvisoPreviaImportacao(
          tipo: TipoAvisoImportacao.mesaSemNumero,
          mensagem:
              '${mesa.titulo} não tinha número. O número $numeroGerado foi atribuído automaticamente; revise antes de confirmar.',
          mesaNumero: numeroGerado,
          convidadoNome: null,
        ),
      );
    }

    return resultado.copyWith(mesas: mesas, avisos: avisos);
  }

  List<String> validarParaPublicacao(ResultadoPreviaImportacao resultado) {
    final problemas = <String>[];

    if (resultado.quantidadeConvidados == 0) {
      problemas.add('Nenhum convidado foi identificado no arquivo.');
    }

    final mesasSemNumero = resultado.mesas
        .where((mesa) => mesa.numero == null || mesa.numero! < 0)
        .toList(growable: false);
    if (mesasSemNumero.isNotEmpty) {
      problemas.add(
        '${mesasSemNumero.length} mesa(s) estão sem número válido.',
      );
    }

    final numeros = <int, int>{};
    for (final mesa in resultado.mesas) {
      final numero = mesa.numero;
      if (numero == null || numero < 0) {
        continue;
      }
      numeros[numero] = (numeros[numero] ?? 0) + 1;
    }

    final duplicados =
        numeros.entries
            .where((entrada) => entrada.value > 1)
            .map((entrada) => entrada.key)
            .toList(growable: false)
          ..sort();
    if (duplicados.isNotEmpty) {
      problemas.add(
        'Existem números de mesa repetidos: ${duplicados.join(', ')}.',
      );
    }

    final nomesVazios = resultado.todosConvidados
        .where((convidado) => convidado.nome.trim().isEmpty)
        .length;
    if (nomesVazios > 0) {
      problemas.add('$nomesVazios convidado(s) estão sem nome.');
    }

    return problemas;
  }

  Future<ResultadoPublicacaoLista> publicarLista(
    ResultadoPreviaImportacao resultado,
  ) async {
    final problemas = validarParaPublicacao(resultado);
    if (problemas.isNotEmpty) {
      throw ImportacaoListaException(problemas.join('\n'));
    }

    final usuario = SessaoServico.instance.usuarioAtual;

    if (usuario == null) {
      throw const ImportacaoListaException(
        'Sua sessão não está ativa. Entre novamente no aplicativo.',
      );
    }

    try {
      final resposta = await _supabase.functions
          .invoke(
            'publicar-lista-convidados',
            body: {
              'resultado': resultado.toJson(),
              'casamento_id': CasamentoAtualServico.instance.casamentoId,
            },
          )
          .timeout(const Duration(minutes: 2));

      final dados = _converterMapa(resposta.data);

      if (resposta.status < 200 || resposta.status >= 300) {
        throw ImportacaoListaException(
          _obterMensagemErro(dados) ??
              'O servidor não conseguiu substituir a lista.',
        );
      }

      final resultadoBruto = dados['resultado'];
      if (resultadoBruto is! Map) {
        throw const ImportacaoListaException(
          'O servidor publicou a lista, mas retornou uma confirmação inválida.',
        );
      }

      return ResultadoPublicacaoLista.fromJson(
        Map<String, dynamic>.from(resultadoBruto),
      );
    } on ImportacaoListaException {
      rethrow;
    } on FunctionException catch (erro) {
      final detalhes = _converterMapa(erro.details);
      throw ImportacaoListaException(
        _obterMensagemErro(detalhes) ??
            'Não foi possível acessar o publicador da lista. '
                'Confirme se a Edge Function foi publicada.',
      );
    } on SocketException {
      throw const ImportacaoListaException(
        'Sem conexão com a internet. A publicação precisa estar online.',
      );
    } on FormatException {
      throw const ImportacaoListaException(
        'O servidor retornou uma confirmação inválida.',
      );
    } catch (erro) {
      final texto = erro.toString().trim();
      throw ImportacaoListaException(
        texto.isEmpty
            ? 'Não foi possível substituir a lista.'
            : 'Não foi possível substituir a lista: $texto',
      );
    }
  }

  Future<Uint8List> _obterBytes(PlatformFile arquivo) async {
    final bytesEmMemoria = arquivo.bytes;
    if (bytesEmMemoria != null) {
      return bytesEmMemoria;
    }

    final caminho = arquivo.path;
    if (caminho == null || caminho.isEmpty) {
      throw const ImportacaoListaException(
        'O Android não permitiu ler o arquivo selecionado.',
      );
    }

    return File(caminho).readAsBytes();
  }

  Map<String, dynamic> _converterMapa(dynamic valor) {
    if (valor is Map) {
      return Map<String, dynamic>.from(valor);
    }

    if (valor is String && valor.trim().isNotEmpty) {
      final convertido = jsonDecode(valor);
      if (convertido is Map) {
        return Map<String, dynamic>.from(convertido);
      }
    }

    return <String, dynamic>{};
  }

  String? _obterMensagemErro(Map<String, dynamic> dados) {
    final mensagem = dados['mensagem'] ?? dados['message'] ?? dados['error'];
    final texto = mensagem?.toString().trim();
    return texto == null || texto.isEmpty ? null : texto;
  }

  String _obterExtensao(String nome) {
    final indice = nome.lastIndexOf('.');
    if (indice < 0 || indice == nome.length - 1) {
      return '';
    }
    return nome.substring(indice + 1);
  }

  String _obterMimeType(String extensao) {
    switch (extensao) {
      case 'pdf':
        return 'application/pdf';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'csv':
        return 'text/csv';
      case 'tsv':
        return 'text/tab-separated-values';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }
}

class ImportacaoListaException implements Exception {
  final String mensagem;

  const ImportacaoListaException(this.mensagem);

  @override
  String toString() => mensagem;
}
