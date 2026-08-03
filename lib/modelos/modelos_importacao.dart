class ResultadoPreviaImportacao {
  final String arquivoNome;
  final String resumo;
  final List<MesaPreviaImportacao> mesas;
  final List<ConvidadoPreviaImportacao> convidadosSemMesa;
  final List<AvisoPreviaImportacao> avisos;

  const ResultadoPreviaImportacao({
    required this.arquivoNome,
    required this.resumo,
    required this.mesas,
    required this.convidadosSemMesa,
    required this.avisos,
  });

  factory ResultadoPreviaImportacao.fromJson(Map<String, dynamic> json) {
    return ResultadoPreviaImportacao(
      arquivoNome: _texto(
        json['arquivo_nome'],
        fallback: 'Arquivo selecionado',
      ),
      resumo: _texto(json['resumo']),
      mesas: _listaMapas(
        json['mesas'],
      ).map(MesaPreviaImportacao.fromJson).toList(growable: false),
      convidadosSemMesa: _listaMapas(
        json['convidados_sem_mesa'],
      ).map(ConvidadoPreviaImportacao.fromJson).toList(growable: false),
      avisos: _listaMapas(
        json['avisos'],
      ).map(AvisoPreviaImportacao.fromJson).toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'arquivo_nome': arquivoNome,
      'resumo': resumo,
      'mesas': mesas.map((mesa) => mesa.toJson()).toList(growable: false),
      'convidados_sem_mesa': convidadosSemMesa
          .map((convidado) => convidado.toJson())
          .toList(growable: false),
      'avisos': avisos.map((aviso) => aviso.toJson()).toList(growable: false),
    };
  }

  ResultadoPreviaImportacao copyWith({
    String? arquivoNome,
    String? resumo,
    List<MesaPreviaImportacao>? mesas,
    List<ConvidadoPreviaImportacao>? convidadosSemMesa,
    List<AvisoPreviaImportacao>? avisos,
  }) {
    return ResultadoPreviaImportacao(
      arquivoNome: arquivoNome ?? this.arquivoNome,
      resumo: resumo ?? this.resumo,
      mesas: mesas ?? this.mesas,
      convidadosSemMesa: convidadosSemMesa ?? this.convidadosSemMesa,
      avisos: avisos ?? this.avisos,
    );
  }

  int get quantidadeMesas => mesas.length;

  int get quantidadeConvidados {
    return convidadosSemMesa.length +
        mesas.fold<int>(0, (total, mesa) => total + mesa.convidados.length);
  }

  int get quantidadeBebes => todosConvidados
      .where((convidado) => convidado.categoria == CategoriaConvidado.bebe)
      .length;

  int get quantidadeNaoPagantes => todosConvidados
      .where(
        (convidado) =>
            convidado.categoria == CategoriaConvidado.naoPaganteComLugar,
      )
      .length;

  int get quantidadePagantes50 => todosConvidados
      .where((convidado) => convidado.categoria == CategoriaConvidado.pagante50)
      .length;

  List<ConvidadoPreviaImportacao> get todosConvidados => [
    for (final mesa in mesas) ...mesa.convidados,
    ...convidadosSemMesa,
  ];
}

class MesaPreviaImportacao {
  final int? numero;
  final String nomeExibicao;
  final String detalhe;
  final int? capacidade;
  final List<ConvidadoPreviaImportacao> convidados;
  final bool numeroGeradoAutomaticamente;

  const MesaPreviaImportacao({
    required this.numero,
    required this.nomeExibicao,
    required this.detalhe,
    required this.capacidade,
    required this.convidados,
    this.numeroGeradoAutomaticamente = false,
  });

  factory MesaPreviaImportacao.fromJson(Map<String, dynamic> json) {
    return MesaPreviaImportacao(
      numero: _inteiroOpcional(json['numero']),
      nomeExibicao: _texto(json['nome_exibicao'], fallback: 'Mesa sem nome'),
      detalhe: _texto(json['detalhe']),
      capacidade: _inteiroOpcional(json['capacidade']),
      convidados: _listaMapas(
        json['convidados'],
      ).map(ConvidadoPreviaImportacao.fromJson).toList(growable: false),
      numeroGeradoAutomaticamente:
          json['numero_gerado_automaticamente'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'numero': numero,
      'nome_exibicao': nomeExibicao,
      'detalhe': detalhe,
      'capacidade': capacidade,
      'numero_gerado_automaticamente': numeroGeradoAutomaticamente,
      'convidados': convidados
          .map((convidado) => convidado.toJson())
          .toList(growable: false),
    };
  }

  MesaPreviaImportacao copyWith({
    int? numero,
    String? nomeExibicao,
    String? detalhe,
    int? capacidade,
    List<ConvidadoPreviaImportacao>? convidados,
    bool? numeroGeradoAutomaticamente,
  }) {
    return MesaPreviaImportacao(
      numero: numero ?? this.numero,
      nomeExibicao: nomeExibicao ?? this.nomeExibicao,
      detalhe: detalhe ?? this.detalhe,
      capacidade: capacidade ?? this.capacidade,
      convidados: convidados ?? this.convidados,
      numeroGeradoAutomaticamente:
          numeroGeradoAutomaticamente ?? this.numeroGeradoAutomaticamente,
    );
  }

  int get quantidadeConvidados => convidados.length;

  int? get diferencaCapacidade {
    final capacidadeAtual = capacidade;
    if (capacidadeAtual == null) {
      return null;
    }
    return quantidadeConvidados - capacidadeAtual;
  }

  bool get excedeCapacidade => (diferencaCapacidade ?? 0) > 0;

  String get titulo {
    final nome = nomeExibicao.trim();
    if (nome.isNotEmpty) {
      return nome;
    }

    final numeroAtual = numero;
    return numeroAtual == null ? 'Mesa sem número' : 'Mesa $numeroAtual';
  }
}

class ConvidadoPreviaImportacao {
  final String nome;
  final String? descricao;
  final CategoriaConvidado categoria;
  final double confianca;

  const ConvidadoPreviaImportacao({
    required this.nome,
    required this.descricao,
    required this.categoria,
    required this.confianca,
  });

  factory ConvidadoPreviaImportacao.fromJson(Map<String, dynamic> json) {
    final descricao = _textoOpcional(json['descricao']);

    return ConvidadoPreviaImportacao(
      nome: _texto(json['nome'], fallback: 'Nome não identificado'),
      descricao: descricao,
      categoria: CategoriaConvidado.fromJson(json['categoria']),
      confianca: _numero(
        json['confianca'],
        fallback: 1,
      ).clamp(0.0, 1.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nome': nome,
      'descricao': descricao,
      'categoria': categoria.valorJson,
      'confianca': confianca,
    };
  }

  ConvidadoPreviaImportacao copyWith({
    String? nome,
    String? descricao,
    CategoriaConvidado? categoria,
    double? confianca,
  }) {
    return ConvidadoPreviaImportacao(
      nome: nome ?? this.nome,
      descricao: descricao ?? this.descricao,
      categoria: categoria ?? this.categoria,
      confianca: confianca ?? this.confianca,
    );
  }

  String get nomeComDescricao {
    final descricaoAtual = descricao?.trim();
    if (descricaoAtual == null || descricaoAtual.isEmpty) {
      return nome;
    }

    final descricaoNormalizada = descricaoAtual.toLowerCase();
    if (nome.toLowerCase().contains(descricaoNormalizada)) {
      return nome;
    }

    return '$nome ($descricaoAtual)';
  }

  bool get leituraComBaixaConfianca => confianca < 0.75;
}

enum CategoriaConvidado {
  normal,
  bebe,
  naoPaganteComLugar,
  pagante50,
  outra;

  static CategoriaConvidado fromJson(dynamic valor) {
    switch (valor?.toString()) {
      case 'bebe':
        return CategoriaConvidado.bebe;
      case 'nao_pagante_com_lugar':
        return CategoriaConvidado.naoPaganteComLugar;
      case 'pagante_50':
        return CategoriaConvidado.pagante50;
      case 'outra':
        return CategoriaConvidado.outra;
      default:
        return CategoriaConvidado.normal;
    }
  }

  String get valorJson {
    switch (this) {
      case CategoriaConvidado.normal:
        return 'normal';
      case CategoriaConvidado.bebe:
        return 'bebe';
      case CategoriaConvidado.naoPaganteComLugar:
        return 'nao_pagante_com_lugar';
      case CategoriaConvidado.pagante50:
        return 'pagante_50';
      case CategoriaConvidado.outra:
        return 'outra';
    }
  }

  String get rotulo {
    switch (this) {
      case CategoriaConvidado.normal:
        return 'Normal';
      case CategoriaConvidado.bebe:
        return 'Bebê';
      case CategoriaConvidado.naoPaganteComLugar:
        return 'Não pagante';
      case CategoriaConvidado.pagante50:
        return 'Pagante 50%';
      case CategoriaConvidado.outra:
        return 'Observação';
    }
  }
}

class AvisoPreviaImportacao {
  final TipoAvisoImportacao tipo;
  final String mensagem;
  final int? mesaNumero;
  final String? convidadoNome;

  const AvisoPreviaImportacao({
    required this.tipo,
    required this.mensagem,
    required this.mesaNumero,
    required this.convidadoNome,
  });

  factory AvisoPreviaImportacao.fromJson(Map<String, dynamic> json) {
    return AvisoPreviaImportacao(
      tipo: TipoAvisoImportacao.fromJson(json['tipo']),
      mensagem: _texto(json['mensagem'], fallback: 'Revisão necessária.'),
      mesaNumero: _inteiroOpcional(json['mesa_numero']),
      convidadoNome: _textoOpcional(json['convidado_nome']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tipo': tipo.valorJson,
      'mensagem': mensagem,
      'mesa_numero': mesaNumero,
      'convidado_nome': convidadoNome,
    };
  }
}

enum TipoAvisoImportacao {
  nomeIlegivel,
  possivelDuplicidade,
  mesaSemNumero,
  convidadoSemMesa,
  capacidadeDivergente,
  informacaoIncompleta,
  outro;

  static TipoAvisoImportacao fromJson(dynamic valor) {
    switch (valor?.toString()) {
      case 'nome_ilegivel':
        return TipoAvisoImportacao.nomeIlegivel;
      case 'possivel_duplicidade':
        return TipoAvisoImportacao.possivelDuplicidade;
      case 'mesa_sem_numero':
        return TipoAvisoImportacao.mesaSemNumero;
      case 'convidado_sem_mesa':
        return TipoAvisoImportacao.convidadoSemMesa;
      case 'capacidade_divergente':
        return TipoAvisoImportacao.capacidadeDivergente;
      case 'informacao_incompleta':
        return TipoAvisoImportacao.informacaoIncompleta;
      default:
        return TipoAvisoImportacao.outro;
    }
  }

  String get valorJson {
    switch (this) {
      case TipoAvisoImportacao.nomeIlegivel:
        return 'nome_ilegivel';
      case TipoAvisoImportacao.possivelDuplicidade:
        return 'possivel_duplicidade';
      case TipoAvisoImportacao.mesaSemNumero:
        return 'mesa_sem_numero';
      case TipoAvisoImportacao.convidadoSemMesa:
        return 'convidado_sem_mesa';
      case TipoAvisoImportacao.capacidadeDivergente:
        return 'capacidade_divergente';
      case TipoAvisoImportacao.informacaoIncompleta:
        return 'informacao_incompleta';
      case TipoAvisoImportacao.outro:
        return 'outro';
    }
  }

  String get rotulo {
    switch (this) {
      case TipoAvisoImportacao.nomeIlegivel:
        return 'Nome possivelmente ilegível';
      case TipoAvisoImportacao.possivelDuplicidade:
        return 'Possível duplicidade';
      case TipoAvisoImportacao.mesaSemNumero:
        return 'Mesa sem número';
      case TipoAvisoImportacao.convidadoSemMesa:
        return 'Convidado sem mesa';
      case TipoAvisoImportacao.capacidadeDivergente:
        return 'Capacidade divergente';
      case TipoAvisoImportacao.informacaoIncompleta:
        return 'Informação incompleta';
      case TipoAvisoImportacao.outro:
        return 'Revisão';
    }
  }
}

class ResultadoPublicacaoLista {
  final int versao;
  final int mesas;
  final int convidados;
  final int convidadosSemMesa;
  final String publicadoPor;

  const ResultadoPublicacaoLista({
    required this.versao,
    required this.mesas,
    required this.convidados,
    required this.convidadosSemMesa,
    required this.publicadoPor,
  });

  factory ResultadoPublicacaoLista.fromJson(Map<String, dynamic> json) {
    return ResultadoPublicacaoLista(
      versao: _inteiroOpcional(json['versao']) ?? 0,
      mesas: _inteiroOpcional(json['mesas']) ?? 0,
      convidados: _inteiroOpcional(json['convidados']) ?? 0,
      convidadosSemMesa: _inteiroOpcional(json['convidados_sem_mesa']) ?? 0,
      publicadoPor: _texto(json['publicado_por']),
    );
  }
}

List<Map<String, dynamic>> _listaMapas(dynamic valor) {
  if (valor is! List) {
    return const [];
  }

  return valor
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

String _texto(dynamic valor, {String fallback = ''}) {
  final texto = valor?.toString().trim();
  return texto == null || texto.isEmpty ? fallback : texto;
}

String? _textoOpcional(dynamic valor) {
  final texto = valor?.toString().trim();
  return texto == null || texto.isEmpty ? null : texto;
}

int? _inteiroOpcional(dynamic valor) {
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

double _numero(dynamic valor, {required double fallback}) {
  if (valor is num) {
    return valor.toDouble();
  }
  return double.tryParse(valor?.toString() ?? '') ?? fallback;
}
