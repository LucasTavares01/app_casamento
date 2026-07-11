class Mesa {
  final String id;
  final int numero;
  final String? detalhe;

  Mesa({required this.id, required this.numero, this.detalhe});

  factory Mesa.fromMap(Map<String, dynamic> map) {
    return Mesa(
      id: map['id']?.toString() ?? '',
      numero: _converterInteiro(map['numero']),
      detalhe: map['detalhe']?.toString(),
    );
  }

  String get nomeExibicao {
    if (detalhe != null && detalhe!.trim().isNotEmpty) {
      return 'Mesa $numero - $detalhe';
    }

    return 'Mesa $numero';
  }
}

class Convidado {
  final String id;
  final String nome;
  final String? mesaId;
  final bool chegou;

  /// Indica que existem ações atuais contraditórias.
  ///
  /// Exemplo:
  /// William confirmou a chegada e Joice removeu a chegada enquanto
  /// ambos estavam offline.
  final bool temConflito;

  /// IDs dos eventos que representam o estado atual do convidado.
  ///
  /// Normalmente existe apenas um. Pode haver mais de um quando duas
  /// pessoas fizeram ações offline antes de sincronizar.
  final List<String> eventosAtuaisIds;

  Convidado({
    required this.id,
    required this.nome,
    this.mesaId,
    required this.chegou,
    this.temConflito = false,
    this.eventosAtuaisIds = const [],
  });

  factory Convidado.fromMap(Map<String, dynamic> map) {
    return Convidado(
      id: map['id']?.toString() ?? '',
      nome: map['nome']?.toString() ?? '',
      mesaId: map['mesa_id']?.toString(),
      chegou: _converterBooleano(map['chegou']),
      temConflito: _converterBooleano(map['tem_conflito']),
      eventosAtuaisIds: _converterListaDeIds(map['eventos_atuais']),
    );
  }
}

class Staff {
  final String id;
  final String nome;
  final String sobrenome;
  final String ocupacao;

  Staff({
    required this.id,
    required this.nome,
    required this.sobrenome,
    required this.ocupacao,
  });

  factory Staff.fromMap(Map<String, dynamic> map) {
    return Staff(
      id: map['id']?.toString() ?? '',
      nome: map['nome']?.toString() ?? '',
      sobrenome: map['sobrenome']?.toString() ?? '',
      ocupacao: map['ocupacao']?.toString() ?? '',
    );
  }
}

class MensagemChat {
  final String id;
  final String staffId;
  final String mensagem;
  final DateTime dataEnvio;

  MensagemChat({
    required this.id,
    required this.staffId,
    required this.mensagem,
    required this.dataEnvio,
  });

  factory MensagemChat.fromMap(Map<String, dynamic> map) {
    return MensagemChat(
      id: map['id']?.toString() ?? '',
      staffId: map['staff_id']?.toString() ?? '',
      mensagem: map['mensagem']?.toString() ?? '',
      dataEnvio:
          DateTime.tryParse(map['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}

/// Usuário disponível na identificação inicial do aplicativo.
class UsuarioApp {
  final String id;
  final String nome;
  final int ordem;
  final bool ativo;

  UsuarioApp({
    required this.id,
    required this.nome,
    required this.ordem,
    required this.ativo,
  });
}

/// Ação individual feita no check-in.
///
/// Cada confirmação, remoção ou resolução cria um registro separado.
class EventoCheckin {
  final String id;
  final String convidadoId;
  final String usuarioId;
  final String tipoAcao;
  final bool estadoResultante;
  final List<String> eventosBaseIds;
  final DateTime dataDispositivo;
  final int sequenciaDispositivo;
  final String dispositivoId;
  final DateTime? dataServidor;
  final String? observacao;
  final bool sincronizado;

  EventoCheckin({
    required this.id,
    required this.convidadoId,
    required this.usuarioId,
    required this.tipoAcao,
    required this.estadoResultante,
    required this.eventosBaseIds,
    required this.dataDispositivo,
    required this.sequenciaDispositivo,
    required this.dispositivoId,
    this.dataServidor,
    this.observacao,
    required this.sincronizado,
  });

  String get descricaoAcao {
    switch (tipoAcao) {
      case 'confirmou_chegada':
        return 'confirmou a chegada';

      case 'removeu_chegada':
        return 'removeu a confirmação de chegada';

      case 'resolveu_como_presente':
        return 'resolveu o conflito como presente';

      case 'resolveu_como_ausente':
        return 'resolveu o conflito como não presente';

      default:
        return tipoAcao;
    }
  }
}

/// Conflito criado no servidor quando uma alteração offline usa dados que já
/// foram modificados ou removidos por outro aparelho.
class ConflitoSincronizacao {
  final String id;
  final String tipo;
  final String titulo;
  final String descricao;
  final String status;
  final String? convidadoId;
  final String? mesaId;
  final String? eventoCheckinId;
  final String? usuarioCheckinNome;
  final String? usuarioAlteracaoMesaNome;
  final Map<String, dynamic> dados;
  final DateTime criadoEm;

  ConflitoSincronizacao({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.descricao,
    required this.status,
    this.convidadoId,
    this.mesaId,
    this.eventoCheckinId,
    this.usuarioCheckinNome,
    this.usuarioAlteracaoMesaNome,
    required this.dados,
    required this.criadoEm,
  });

  factory ConflitoSincronizacao.fromMap(Map<String, dynamic> map) {
    final dadosBrutos = map['dados'];

    return ConflitoSincronizacao(
      id: map['id']?.toString() ?? '',
      tipo: map['tipo']?.toString() ?? '',
      titulo: map['titulo']?.toString() ?? 'Conflito de sincronização',
      descricao: map['descricao']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pendente',
      convidadoId: map['convidado_id']?.toString(),
      mesaId: map['mesa_id']?.toString(),
      eventoCheckinId: map['evento_checkin_id']?.toString(),
      usuarioCheckinNome: map['usuario_checkin_nome']?.toString(),
      usuarioAlteracaoMesaNome: map['usuario_alteracao_mesa_nome']?.toString(),
      dados: dadosBrutos is Map
          ? Map<String, dynamic>.from(dadosBrutos)
          : <String, dynamic>{},
      criadoEm:
          DateTime.tryParse(map['created_at']?.toString() ?? '')?.toLocal() ??
          DateTime.now(),
    );
  }
}

int _converterInteiro(dynamic valor) {
  if (valor is int) {
    return valor;
  }

  if (valor is num) {
    return valor.toInt();
  }

  return int.tryParse(valor?.toString() ?? '') ?? 0;
}

bool _converterBooleano(dynamic valor) {
  if (valor is bool) {
    return valor;
  }

  final texto = valor?.toString().toLowerCase();

  return texto == 'true' || texto == '1';
}

List<String> _converterListaDeIds(dynamic valor) {
  if (valor == null) {
    return [];
  }

  if (valor is List) {
    return valor
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  final texto = valor.toString().trim();

  if (texto.isEmpty) {
    return [];
  }

  if (texto.startsWith('{') && texto.endsWith('}')) {
    final conteudo = texto.substring(1, texto.length - 1);

    if (conteudo.trim().isEmpty) {
      return [];
    }

    return conteudo
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  return [];
}
