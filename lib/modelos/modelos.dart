class Mesa {
  final String id;
  final int numero;
  final String? detalhe;

  Mesa({required this.id, required this.numero, this.detalhe});

  factory Mesa.fromMap(Map<String, dynamic> map) {
    return Mesa(
      id: map['id'],
      numero: map['numero'] ?? 0,
      detalhe: map['detalhe'],
    );
  }

  // Facilita mostrar o nome na tela já formatado
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

  Convidado({
    required this.id,
    required this.nome,
    this.mesaId,
    required this.chegou,
  });

  factory Convidado.fromMap(Map<String, dynamic> map) {
    return Convidado(
      id: map['id'],
      nome: map['nome'],
      mesaId: map['mesa_id'],
      chegou: map['chegou'],
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
      id: map['id'],
      nome: map['nome'],
      sobrenome: map['sobrenome'],
      ocupacao: map['ocupacao'],
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
      id: map['id'],
      staffId: map['staff_id'],
      mensagem: map['mensagem'],
      dataEnvio: DateTime.parse(map['created_at']).toLocal(),
    );
  }
}
