import 'package:flutter/material.dart';

/// Tipos de ocasião disponíveis no cadastro de eventos.
///
/// Os valores de [valorBanco] são estáveis para que o Supabase possa manter
/// os dados mesmo quando os textos exibidos na interface forem refinados.
enum TipoEvento {
  casamento,
  aniversario,
  formatura,
  festaInfantil,
  chaDeBebe,
  bodas,
  corporativo,
  confraternizacao,
  outro,
}

extension TipoEventoExt on TipoEvento {
  String get valorBanco {
    switch (this) {
      case TipoEvento.casamento:
        return 'casamento';
      case TipoEvento.aniversario:
        return 'aniversario';
      case TipoEvento.formatura:
        return 'formatura';
      case TipoEvento.festaInfantil:
        return 'festa_infantil';
      case TipoEvento.chaDeBebe:
        return 'cha_de_bebe';
      case TipoEvento.bodas:
        return 'bodas';
      case TipoEvento.corporativo:
        return 'corporativo';
      case TipoEvento.confraternizacao:
        return 'confraternizacao';
      case TipoEvento.outro:
        return 'outro';
    }
  }

  String get rotulo {
    switch (this) {
      case TipoEvento.casamento:
        return 'Casamento';
      case TipoEvento.aniversario:
        return 'Aniversário';
      case TipoEvento.formatura:
        return 'Formatura';
      case TipoEvento.festaInfantil:
        return 'Festa infantil';
      case TipoEvento.chaDeBebe:
        return 'Chá de bebê';
      case TipoEvento.bodas:
        return 'Bodas';
      case TipoEvento.corporativo:
        return 'Evento corporativo';
      case TipoEvento.confraternizacao:
        return 'Confraternização';
      case TipoEvento.outro:
        return 'Outro';
    }
  }

  String get rotuloPessoa {
    switch (this) {
      case TipoEvento.casamento:
        return 'Nomes do casal';
      case TipoEvento.aniversario:
        return 'Aniversariante';
      case TipoEvento.formatura:
        return 'Formando(a)';
      case TipoEvento.festaInfantil:
        return 'Nome da criança';
      case TipoEvento.chaDeBebe:
        return 'Nome da família ou bebê';
      case TipoEvento.bodas:
        return 'Nomes do casal';
      case TipoEvento.corporativo:
        return 'Empresa ou organização';
      case TipoEvento.confraternizacao:
        return 'Pessoa ou grupo homenageado';
      case TipoEvento.outro:
        return 'Pessoa, grupo ou organização';
    }
  }

  IconData get icone {
    switch (this) {
      case TipoEvento.casamento:
        return Icons.favorite_outline;
      case TipoEvento.aniversario:
        return Icons.cake_outlined;
      case TipoEvento.formatura:
        return Icons.school_outlined;
      case TipoEvento.festaInfantil:
        return Icons.celebration_outlined;
      case TipoEvento.chaDeBebe:
        return Icons.child_friendly_outlined;
      case TipoEvento.bodas:
        return Icons.auto_awesome_outlined;
      case TipoEvento.corporativo:
        return Icons.business_outlined;
      case TipoEvento.confraternizacao:
        return Icons.groups_outlined;
      case TipoEvento.outro:
        return Icons.event_outlined;
    }
  }
}

TipoEvento tipoEventoFromBanco(Object? valor) {
  final normalizado = valor?.toString().trim().toLowerCase();
  return TipoEvento.values.firstWhere(
    (tipo) => tipo.valorBanco == normalizado,
    orElse: () => TipoEvento.casamento,
  );
}
