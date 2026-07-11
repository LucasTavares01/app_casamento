// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'banco_local.dart';

// ignore_for_file: type=lint
class $MesasLocaisTable extends MesasLocais
    with TableInfo<$MesasLocaisTable, MesaLocalRegistro> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MesasLocaisTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _numeroMeta = const VerificationMeta('numero');
  @override
  late final GeneratedColumn<int> numero = GeneratedColumn<int>(
    'numero',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _detalheMeta = const VerificationMeta(
    'detalhe',
  );
  @override
  late final GeneratedColumn<String> detalhe = GeneratedColumn<String>(
    'detalhe',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _criadoEmMeta = const VerificationMeta(
    'criadoEm',
  );
  @override
  late final GeneratedColumn<DateTime> criadoEm = GeneratedColumn<DateTime>(
    'criado_em',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atualizadoEmMeta = const VerificationMeta(
    'atualizadoEm',
  );
  @override
  late final GeneratedColumn<DateTime> atualizadoEm = GeneratedColumn<DateTime>(
    'atualizado_em',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _excluidoMeta = const VerificationMeta(
    'excluido',
  );
  @override
  late final GeneratedColumn<bool> excluido = GeneratedColumn<bool>(
    'excluido',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("excluido" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    numero,
    detalhe,
    criadoEm,
    atualizadoEm,
    excluido,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mesas_locais';
  @override
  VerificationContext validateIntegrity(
    Insertable<MesaLocalRegistro> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('numero')) {
      context.handle(
        _numeroMeta,
        numero.isAcceptableOrUnknown(data['numero']!, _numeroMeta),
      );
    }
    if (data.containsKey('detalhe')) {
      context.handle(
        _detalheMeta,
        detalhe.isAcceptableOrUnknown(data['detalhe']!, _detalheMeta),
      );
    }
    if (data.containsKey('criado_em')) {
      context.handle(
        _criadoEmMeta,
        criadoEm.isAcceptableOrUnknown(data['criado_em']!, _criadoEmMeta),
      );
    } else if (isInserting) {
      context.missing(_criadoEmMeta);
    }
    if (data.containsKey('atualizado_em')) {
      context.handle(
        _atualizadoEmMeta,
        atualizadoEm.isAcceptableOrUnknown(
          data['atualizado_em']!,
          _atualizadoEmMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_atualizadoEmMeta);
    }
    if (data.containsKey('excluido')) {
      context.handle(
        _excluidoMeta,
        excluido.isAcceptableOrUnknown(data['excluido']!, _excluidoMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MesaLocalRegistro map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MesaLocalRegistro(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      numero: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}numero'],
      )!,
      detalhe: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detalhe'],
      ),
      criadoEm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}criado_em'],
      )!,
      atualizadoEm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}atualizado_em'],
      )!,
      excluido: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}excluido'],
      )!,
    );
  }

  @override
  $MesasLocaisTable createAlias(String alias) {
    return $MesasLocaisTable(attachedDatabase, alias);
  }
}

class MesaLocalRegistro extends DataClass
    implements Insertable<MesaLocalRegistro> {
  final String id;
  final int numero;
  final String? detalhe;
  final DateTime criadoEm;
  final DateTime atualizadoEm;

  /// Exclusões offline serão inicialmente mantidas como exclusão lógica.
  ///
  /// Isso evita que o registro desapareça antes de o Supabase receber
  /// a solicitação de exclusão.
  final bool excluido;
  const MesaLocalRegistro({
    required this.id,
    required this.numero,
    this.detalhe,
    required this.criadoEm,
    required this.atualizadoEm,
    required this.excluido,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['numero'] = Variable<int>(numero);
    if (!nullToAbsent || detalhe != null) {
      map['detalhe'] = Variable<String>(detalhe);
    }
    map['criado_em'] = Variable<DateTime>(criadoEm);
    map['atualizado_em'] = Variable<DateTime>(atualizadoEm);
    map['excluido'] = Variable<bool>(excluido);
    return map;
  }

  MesasLocaisCompanion toCompanion(bool nullToAbsent) {
    return MesasLocaisCompanion(
      id: Value(id),
      numero: Value(numero),
      detalhe: detalhe == null && nullToAbsent
          ? const Value.absent()
          : Value(detalhe),
      criadoEm: Value(criadoEm),
      atualizadoEm: Value(atualizadoEm),
      excluido: Value(excluido),
    );
  }

  factory MesaLocalRegistro.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MesaLocalRegistro(
      id: serializer.fromJson<String>(json['id']),
      numero: serializer.fromJson<int>(json['numero']),
      detalhe: serializer.fromJson<String?>(json['detalhe']),
      criadoEm: serializer.fromJson<DateTime>(json['criadoEm']),
      atualizadoEm: serializer.fromJson<DateTime>(json['atualizadoEm']),
      excluido: serializer.fromJson<bool>(json['excluido']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'numero': serializer.toJson<int>(numero),
      'detalhe': serializer.toJson<String?>(detalhe),
      'criadoEm': serializer.toJson<DateTime>(criadoEm),
      'atualizadoEm': serializer.toJson<DateTime>(atualizadoEm),
      'excluido': serializer.toJson<bool>(excluido),
    };
  }

  MesaLocalRegistro copyWith({
    String? id,
    int? numero,
    Value<String?> detalhe = const Value.absent(),
    DateTime? criadoEm,
    DateTime? atualizadoEm,
    bool? excluido,
  }) => MesaLocalRegistro(
    id: id ?? this.id,
    numero: numero ?? this.numero,
    detalhe: detalhe.present ? detalhe.value : this.detalhe,
    criadoEm: criadoEm ?? this.criadoEm,
    atualizadoEm: atualizadoEm ?? this.atualizadoEm,
    excluido: excluido ?? this.excluido,
  );
  MesaLocalRegistro copyWithCompanion(MesasLocaisCompanion data) {
    return MesaLocalRegistro(
      id: data.id.present ? data.id.value : this.id,
      numero: data.numero.present ? data.numero.value : this.numero,
      detalhe: data.detalhe.present ? data.detalhe.value : this.detalhe,
      criadoEm: data.criadoEm.present ? data.criadoEm.value : this.criadoEm,
      atualizadoEm: data.atualizadoEm.present
          ? data.atualizadoEm.value
          : this.atualizadoEm,
      excluido: data.excluido.present ? data.excluido.value : this.excluido,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MesaLocalRegistro(')
          ..write('id: $id, ')
          ..write('numero: $numero, ')
          ..write('detalhe: $detalhe, ')
          ..write('criadoEm: $criadoEm, ')
          ..write('atualizadoEm: $atualizadoEm, ')
          ..write('excluido: $excluido')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, numero, detalhe, criadoEm, atualizadoEm, excluido);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MesaLocalRegistro &&
          other.id == this.id &&
          other.numero == this.numero &&
          other.detalhe == this.detalhe &&
          other.criadoEm == this.criadoEm &&
          other.atualizadoEm == this.atualizadoEm &&
          other.excluido == this.excluido);
}

class MesasLocaisCompanion extends UpdateCompanion<MesaLocalRegistro> {
  final Value<String> id;
  final Value<int> numero;
  final Value<String?> detalhe;
  final Value<DateTime> criadoEm;
  final Value<DateTime> atualizadoEm;
  final Value<bool> excluido;
  final Value<int> rowid;
  const MesasLocaisCompanion({
    this.id = const Value.absent(),
    this.numero = const Value.absent(),
    this.detalhe = const Value.absent(),
    this.criadoEm = const Value.absent(),
    this.atualizadoEm = const Value.absent(),
    this.excluido = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MesasLocaisCompanion.insert({
    required String id,
    this.numero = const Value.absent(),
    this.detalhe = const Value.absent(),
    required DateTime criadoEm,
    required DateTime atualizadoEm,
    this.excluido = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       criadoEm = Value(criadoEm),
       atualizadoEm = Value(atualizadoEm);
  static Insertable<MesaLocalRegistro> custom({
    Expression<String>? id,
    Expression<int>? numero,
    Expression<String>? detalhe,
    Expression<DateTime>? criadoEm,
    Expression<DateTime>? atualizadoEm,
    Expression<bool>? excluido,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (numero != null) 'numero': numero,
      if (detalhe != null) 'detalhe': detalhe,
      if (criadoEm != null) 'criado_em': criadoEm,
      if (atualizadoEm != null) 'atualizado_em': atualizadoEm,
      if (excluido != null) 'excluido': excluido,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MesasLocaisCompanion copyWith({
    Value<String>? id,
    Value<int>? numero,
    Value<String?>? detalhe,
    Value<DateTime>? criadoEm,
    Value<DateTime>? atualizadoEm,
    Value<bool>? excluido,
    Value<int>? rowid,
  }) {
    return MesasLocaisCompanion(
      id: id ?? this.id,
      numero: numero ?? this.numero,
      detalhe: detalhe ?? this.detalhe,
      criadoEm: criadoEm ?? this.criadoEm,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
      excluido: excluido ?? this.excluido,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (numero.present) {
      map['numero'] = Variable<int>(numero.value);
    }
    if (detalhe.present) {
      map['detalhe'] = Variable<String>(detalhe.value);
    }
    if (criadoEm.present) {
      map['criado_em'] = Variable<DateTime>(criadoEm.value);
    }
    if (atualizadoEm.present) {
      map['atualizado_em'] = Variable<DateTime>(atualizadoEm.value);
    }
    if (excluido.present) {
      map['excluido'] = Variable<bool>(excluido.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MesasLocaisCompanion(')
          ..write('id: $id, ')
          ..write('numero: $numero, ')
          ..write('detalhe: $detalhe, ')
          ..write('criadoEm: $criadoEm, ')
          ..write('atualizadoEm: $atualizadoEm, ')
          ..write('excluido: $excluido, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConvidadosLocaisTable extends ConvidadosLocais
    with TableInfo<$ConvidadosLocaisTable, ConvidadoLocalRegistro> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConvidadosLocaisTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nomeMeta = const VerificationMeta('nome');
  @override
  late final GeneratedColumn<String> nome = GeneratedColumn<String>(
    'nome',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mesaIdMeta = const VerificationMeta('mesaId');
  @override
  late final GeneratedColumn<String> mesaId = GeneratedColumn<String>(
    'mesa_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _chegouMeta = const VerificationMeta('chegou');
  @override
  late final GeneratedColumn<bool> chegou = GeneratedColumn<bool>(
    'chegou',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("chegou" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _temConflitoMeta = const VerificationMeta(
    'temConflito',
  );
  @override
  late final GeneratedColumn<bool> temConflito = GeneratedColumn<bool>(
    'tem_conflito',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("tem_conflito" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _eventosAtuaisJsonMeta = const VerificationMeta(
    'eventosAtuaisJson',
  );
  @override
  late final GeneratedColumn<String> eventosAtuaisJson =
      GeneratedColumn<String>(
        'eventos_atuais_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('[]'),
      );
  static const VerificationMeta _criadoEmMeta = const VerificationMeta(
    'criadoEm',
  );
  @override
  late final GeneratedColumn<DateTime> criadoEm = GeneratedColumn<DateTime>(
    'criado_em',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atualizadoEmMeta = const VerificationMeta(
    'atualizadoEm',
  );
  @override
  late final GeneratedColumn<DateTime> atualizadoEm = GeneratedColumn<DateTime>(
    'atualizado_em',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _excluidoMeta = const VerificationMeta(
    'excluido',
  );
  @override
  late final GeneratedColumn<bool> excluido = GeneratedColumn<bool>(
    'excluido',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("excluido" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    nome,
    mesaId,
    chegou,
    temConflito,
    eventosAtuaisJson,
    criadoEm,
    atualizadoEm,
    excluido,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'convidados_locais';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConvidadoLocalRegistro> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('nome')) {
      context.handle(
        _nomeMeta,
        nome.isAcceptableOrUnknown(data['nome']!, _nomeMeta),
      );
    } else if (isInserting) {
      context.missing(_nomeMeta);
    }
    if (data.containsKey('mesa_id')) {
      context.handle(
        _mesaIdMeta,
        mesaId.isAcceptableOrUnknown(data['mesa_id']!, _mesaIdMeta),
      );
    }
    if (data.containsKey('chegou')) {
      context.handle(
        _chegouMeta,
        chegou.isAcceptableOrUnknown(data['chegou']!, _chegouMeta),
      );
    }
    if (data.containsKey('tem_conflito')) {
      context.handle(
        _temConflitoMeta,
        temConflito.isAcceptableOrUnknown(
          data['tem_conflito']!,
          _temConflitoMeta,
        ),
      );
    }
    if (data.containsKey('eventos_atuais_json')) {
      context.handle(
        _eventosAtuaisJsonMeta,
        eventosAtuaisJson.isAcceptableOrUnknown(
          data['eventos_atuais_json']!,
          _eventosAtuaisJsonMeta,
        ),
      );
    }
    if (data.containsKey('criado_em')) {
      context.handle(
        _criadoEmMeta,
        criadoEm.isAcceptableOrUnknown(data['criado_em']!, _criadoEmMeta),
      );
    } else if (isInserting) {
      context.missing(_criadoEmMeta);
    }
    if (data.containsKey('atualizado_em')) {
      context.handle(
        _atualizadoEmMeta,
        atualizadoEm.isAcceptableOrUnknown(
          data['atualizado_em']!,
          _atualizadoEmMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_atualizadoEmMeta);
    }
    if (data.containsKey('excluido')) {
      context.handle(
        _excluidoMeta,
        excluido.isAcceptableOrUnknown(data['excluido']!, _excluidoMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConvidadoLocalRegistro map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConvidadoLocalRegistro(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      nome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nome'],
      )!,
      mesaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mesa_id'],
      ),
      chegou: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}chegou'],
      )!,
      temConflito: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}tem_conflito'],
      )!,
      eventosAtuaisJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}eventos_atuais_json'],
      )!,
      criadoEm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}criado_em'],
      )!,
      atualizadoEm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}atualizado_em'],
      )!,
      excluido: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}excluido'],
      )!,
    );
  }

  @override
  $ConvidadosLocaisTable createAlias(String alias) {
    return $ConvidadosLocaisTable(attachedDatabase, alias);
  }
}

class ConvidadoLocalRegistro extends DataClass
    implements Insertable<ConvidadoLocalRegistro> {
  final String id;
  final String nome;
  final String? mesaId;
  final bool chegou;

  /// Indica que existem ações simultâneas e contraditórias.
  final bool temConflito;

  /// Lista em formato JSON dos eventos que formam o estado atual.
  ///
  /// Exemplo:
  /// ["id-evento-william", "id-evento-joice"]
  final String eventosAtuaisJson;
  final DateTime criadoEm;
  final DateTime atualizadoEm;
  final bool excluido;
  const ConvidadoLocalRegistro({
    required this.id,
    required this.nome,
    this.mesaId,
    required this.chegou,
    required this.temConflito,
    required this.eventosAtuaisJson,
    required this.criadoEm,
    required this.atualizadoEm,
    required this.excluido,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['nome'] = Variable<String>(nome);
    if (!nullToAbsent || mesaId != null) {
      map['mesa_id'] = Variable<String>(mesaId);
    }
    map['chegou'] = Variable<bool>(chegou);
    map['tem_conflito'] = Variable<bool>(temConflito);
    map['eventos_atuais_json'] = Variable<String>(eventosAtuaisJson);
    map['criado_em'] = Variable<DateTime>(criadoEm);
    map['atualizado_em'] = Variable<DateTime>(atualizadoEm);
    map['excluido'] = Variable<bool>(excluido);
    return map;
  }

  ConvidadosLocaisCompanion toCompanion(bool nullToAbsent) {
    return ConvidadosLocaisCompanion(
      id: Value(id),
      nome: Value(nome),
      mesaId: mesaId == null && nullToAbsent
          ? const Value.absent()
          : Value(mesaId),
      chegou: Value(chegou),
      temConflito: Value(temConflito),
      eventosAtuaisJson: Value(eventosAtuaisJson),
      criadoEm: Value(criadoEm),
      atualizadoEm: Value(atualizadoEm),
      excluido: Value(excluido),
    );
  }

  factory ConvidadoLocalRegistro.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConvidadoLocalRegistro(
      id: serializer.fromJson<String>(json['id']),
      nome: serializer.fromJson<String>(json['nome']),
      mesaId: serializer.fromJson<String?>(json['mesaId']),
      chegou: serializer.fromJson<bool>(json['chegou']),
      temConflito: serializer.fromJson<bool>(json['temConflito']),
      eventosAtuaisJson: serializer.fromJson<String>(json['eventosAtuaisJson']),
      criadoEm: serializer.fromJson<DateTime>(json['criadoEm']),
      atualizadoEm: serializer.fromJson<DateTime>(json['atualizadoEm']),
      excluido: serializer.fromJson<bool>(json['excluido']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'nome': serializer.toJson<String>(nome),
      'mesaId': serializer.toJson<String?>(mesaId),
      'chegou': serializer.toJson<bool>(chegou),
      'temConflito': serializer.toJson<bool>(temConflito),
      'eventosAtuaisJson': serializer.toJson<String>(eventosAtuaisJson),
      'criadoEm': serializer.toJson<DateTime>(criadoEm),
      'atualizadoEm': serializer.toJson<DateTime>(atualizadoEm),
      'excluido': serializer.toJson<bool>(excluido),
    };
  }

  ConvidadoLocalRegistro copyWith({
    String? id,
    String? nome,
    Value<String?> mesaId = const Value.absent(),
    bool? chegou,
    bool? temConflito,
    String? eventosAtuaisJson,
    DateTime? criadoEm,
    DateTime? atualizadoEm,
    bool? excluido,
  }) => ConvidadoLocalRegistro(
    id: id ?? this.id,
    nome: nome ?? this.nome,
    mesaId: mesaId.present ? mesaId.value : this.mesaId,
    chegou: chegou ?? this.chegou,
    temConflito: temConflito ?? this.temConflito,
    eventosAtuaisJson: eventosAtuaisJson ?? this.eventosAtuaisJson,
    criadoEm: criadoEm ?? this.criadoEm,
    atualizadoEm: atualizadoEm ?? this.atualizadoEm,
    excluido: excluido ?? this.excluido,
  );
  ConvidadoLocalRegistro copyWithCompanion(ConvidadosLocaisCompanion data) {
    return ConvidadoLocalRegistro(
      id: data.id.present ? data.id.value : this.id,
      nome: data.nome.present ? data.nome.value : this.nome,
      mesaId: data.mesaId.present ? data.mesaId.value : this.mesaId,
      chegou: data.chegou.present ? data.chegou.value : this.chegou,
      temConflito: data.temConflito.present
          ? data.temConflito.value
          : this.temConflito,
      eventosAtuaisJson: data.eventosAtuaisJson.present
          ? data.eventosAtuaisJson.value
          : this.eventosAtuaisJson,
      criadoEm: data.criadoEm.present ? data.criadoEm.value : this.criadoEm,
      atualizadoEm: data.atualizadoEm.present
          ? data.atualizadoEm.value
          : this.atualizadoEm,
      excluido: data.excluido.present ? data.excluido.value : this.excluido,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConvidadoLocalRegistro(')
          ..write('id: $id, ')
          ..write('nome: $nome, ')
          ..write('mesaId: $mesaId, ')
          ..write('chegou: $chegou, ')
          ..write('temConflito: $temConflito, ')
          ..write('eventosAtuaisJson: $eventosAtuaisJson, ')
          ..write('criadoEm: $criadoEm, ')
          ..write('atualizadoEm: $atualizadoEm, ')
          ..write('excluido: $excluido')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    nome,
    mesaId,
    chegou,
    temConflito,
    eventosAtuaisJson,
    criadoEm,
    atualizadoEm,
    excluido,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConvidadoLocalRegistro &&
          other.id == this.id &&
          other.nome == this.nome &&
          other.mesaId == this.mesaId &&
          other.chegou == this.chegou &&
          other.temConflito == this.temConflito &&
          other.eventosAtuaisJson == this.eventosAtuaisJson &&
          other.criadoEm == this.criadoEm &&
          other.atualizadoEm == this.atualizadoEm &&
          other.excluido == this.excluido);
}

class ConvidadosLocaisCompanion
    extends UpdateCompanion<ConvidadoLocalRegistro> {
  final Value<String> id;
  final Value<String> nome;
  final Value<String?> mesaId;
  final Value<bool> chegou;
  final Value<bool> temConflito;
  final Value<String> eventosAtuaisJson;
  final Value<DateTime> criadoEm;
  final Value<DateTime> atualizadoEm;
  final Value<bool> excluido;
  final Value<int> rowid;
  const ConvidadosLocaisCompanion({
    this.id = const Value.absent(),
    this.nome = const Value.absent(),
    this.mesaId = const Value.absent(),
    this.chegou = const Value.absent(),
    this.temConflito = const Value.absent(),
    this.eventosAtuaisJson = const Value.absent(),
    this.criadoEm = const Value.absent(),
    this.atualizadoEm = const Value.absent(),
    this.excluido = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConvidadosLocaisCompanion.insert({
    required String id,
    required String nome,
    this.mesaId = const Value.absent(),
    this.chegou = const Value.absent(),
    this.temConflito = const Value.absent(),
    this.eventosAtuaisJson = const Value.absent(),
    required DateTime criadoEm,
    required DateTime atualizadoEm,
    this.excluido = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       nome = Value(nome),
       criadoEm = Value(criadoEm),
       atualizadoEm = Value(atualizadoEm);
  static Insertable<ConvidadoLocalRegistro> custom({
    Expression<String>? id,
    Expression<String>? nome,
    Expression<String>? mesaId,
    Expression<bool>? chegou,
    Expression<bool>? temConflito,
    Expression<String>? eventosAtuaisJson,
    Expression<DateTime>? criadoEm,
    Expression<DateTime>? atualizadoEm,
    Expression<bool>? excluido,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nome != null) 'nome': nome,
      if (mesaId != null) 'mesa_id': mesaId,
      if (chegou != null) 'chegou': chegou,
      if (temConflito != null) 'tem_conflito': temConflito,
      if (eventosAtuaisJson != null) 'eventos_atuais_json': eventosAtuaisJson,
      if (criadoEm != null) 'criado_em': criadoEm,
      if (atualizadoEm != null) 'atualizado_em': atualizadoEm,
      if (excluido != null) 'excluido': excluido,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConvidadosLocaisCompanion copyWith({
    Value<String>? id,
    Value<String>? nome,
    Value<String?>? mesaId,
    Value<bool>? chegou,
    Value<bool>? temConflito,
    Value<String>? eventosAtuaisJson,
    Value<DateTime>? criadoEm,
    Value<DateTime>? atualizadoEm,
    Value<bool>? excluido,
    Value<int>? rowid,
  }) {
    return ConvidadosLocaisCompanion(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      mesaId: mesaId ?? this.mesaId,
      chegou: chegou ?? this.chegou,
      temConflito: temConflito ?? this.temConflito,
      eventosAtuaisJson: eventosAtuaisJson ?? this.eventosAtuaisJson,
      criadoEm: criadoEm ?? this.criadoEm,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
      excluido: excluido ?? this.excluido,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (nome.present) {
      map['nome'] = Variable<String>(nome.value);
    }
    if (mesaId.present) {
      map['mesa_id'] = Variable<String>(mesaId.value);
    }
    if (chegou.present) {
      map['chegou'] = Variable<bool>(chegou.value);
    }
    if (temConflito.present) {
      map['tem_conflito'] = Variable<bool>(temConflito.value);
    }
    if (eventosAtuaisJson.present) {
      map['eventos_atuais_json'] = Variable<String>(eventosAtuaisJson.value);
    }
    if (criadoEm.present) {
      map['criado_em'] = Variable<DateTime>(criadoEm.value);
    }
    if (atualizadoEm.present) {
      map['atualizado_em'] = Variable<DateTime>(atualizadoEm.value);
    }
    if (excluido.present) {
      map['excluido'] = Variable<bool>(excluido.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConvidadosLocaisCompanion(')
          ..write('id: $id, ')
          ..write('nome: $nome, ')
          ..write('mesaId: $mesaId, ')
          ..write('chegou: $chegou, ')
          ..write('temConflito: $temConflito, ')
          ..write('eventosAtuaisJson: $eventosAtuaisJson, ')
          ..write('criadoEm: $criadoEm, ')
          ..write('atualizadoEm: $atualizadoEm, ')
          ..write('excluido: $excluido, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UsuariosAppLocaisTable extends UsuariosAppLocais
    with TableInfo<$UsuariosAppLocaisTable, UsuarioAppLocalRegistro> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsuariosAppLocaisTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nomeMeta = const VerificationMeta('nome');
  @override
  late final GeneratedColumn<String> nome = GeneratedColumn<String>(
    'nome',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ordemMeta = const VerificationMeta('ordem');
  @override
  late final GeneratedColumn<int> ordem = GeneratedColumn<int>(
    'ordem',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _ativoMeta = const VerificationMeta('ativo');
  @override
  late final GeneratedColumn<bool> ativo = GeneratedColumn<bool>(
    'ativo',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("ativo" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _criadoEmMeta = const VerificationMeta(
    'criadoEm',
  );
  @override
  late final GeneratedColumn<DateTime> criadoEm = GeneratedColumn<DateTime>(
    'criado_em',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, nome, ordem, ativo, criadoEm];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'usuarios_app_locais';
  @override
  VerificationContext validateIntegrity(
    Insertable<UsuarioAppLocalRegistro> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('nome')) {
      context.handle(
        _nomeMeta,
        nome.isAcceptableOrUnknown(data['nome']!, _nomeMeta),
      );
    } else if (isInserting) {
      context.missing(_nomeMeta);
    }
    if (data.containsKey('ordem')) {
      context.handle(
        _ordemMeta,
        ordem.isAcceptableOrUnknown(data['ordem']!, _ordemMeta),
      );
    }
    if (data.containsKey('ativo')) {
      context.handle(
        _ativoMeta,
        ativo.isAcceptableOrUnknown(data['ativo']!, _ativoMeta),
      );
    }
    if (data.containsKey('criado_em')) {
      context.handle(
        _criadoEmMeta,
        criadoEm.isAcceptableOrUnknown(data['criado_em']!, _criadoEmMeta),
      );
    } else if (isInserting) {
      context.missing(_criadoEmMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UsuarioAppLocalRegistro map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UsuarioAppLocalRegistro(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      nome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nome'],
      )!,
      ordem: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordem'],
      )!,
      ativo: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}ativo'],
      )!,
      criadoEm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}criado_em'],
      )!,
    );
  }

  @override
  $UsuariosAppLocaisTable createAlias(String alias) {
    return $UsuariosAppLocaisTable(attachedDatabase, alias);
  }
}

class UsuarioAppLocalRegistro extends DataClass
    implements Insertable<UsuarioAppLocalRegistro> {
  final String id;
  final String nome;
  final int ordem;
  final bool ativo;
  final DateTime criadoEm;
  const UsuarioAppLocalRegistro({
    required this.id,
    required this.nome,
    required this.ordem,
    required this.ativo,
    required this.criadoEm,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['nome'] = Variable<String>(nome);
    map['ordem'] = Variable<int>(ordem);
    map['ativo'] = Variable<bool>(ativo);
    map['criado_em'] = Variable<DateTime>(criadoEm);
    return map;
  }

  UsuariosAppLocaisCompanion toCompanion(bool nullToAbsent) {
    return UsuariosAppLocaisCompanion(
      id: Value(id),
      nome: Value(nome),
      ordem: Value(ordem),
      ativo: Value(ativo),
      criadoEm: Value(criadoEm),
    );
  }

  factory UsuarioAppLocalRegistro.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UsuarioAppLocalRegistro(
      id: serializer.fromJson<String>(json['id']),
      nome: serializer.fromJson<String>(json['nome']),
      ordem: serializer.fromJson<int>(json['ordem']),
      ativo: serializer.fromJson<bool>(json['ativo']),
      criadoEm: serializer.fromJson<DateTime>(json['criadoEm']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'nome': serializer.toJson<String>(nome),
      'ordem': serializer.toJson<int>(ordem),
      'ativo': serializer.toJson<bool>(ativo),
      'criadoEm': serializer.toJson<DateTime>(criadoEm),
    };
  }

  UsuarioAppLocalRegistro copyWith({
    String? id,
    String? nome,
    int? ordem,
    bool? ativo,
    DateTime? criadoEm,
  }) => UsuarioAppLocalRegistro(
    id: id ?? this.id,
    nome: nome ?? this.nome,
    ordem: ordem ?? this.ordem,
    ativo: ativo ?? this.ativo,
    criadoEm: criadoEm ?? this.criadoEm,
  );
  UsuarioAppLocalRegistro copyWithCompanion(UsuariosAppLocaisCompanion data) {
    return UsuarioAppLocalRegistro(
      id: data.id.present ? data.id.value : this.id,
      nome: data.nome.present ? data.nome.value : this.nome,
      ordem: data.ordem.present ? data.ordem.value : this.ordem,
      ativo: data.ativo.present ? data.ativo.value : this.ativo,
      criadoEm: data.criadoEm.present ? data.criadoEm.value : this.criadoEm,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UsuarioAppLocalRegistro(')
          ..write('id: $id, ')
          ..write('nome: $nome, ')
          ..write('ordem: $ordem, ')
          ..write('ativo: $ativo, ')
          ..write('criadoEm: $criadoEm')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, nome, ordem, ativo, criadoEm);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UsuarioAppLocalRegistro &&
          other.id == this.id &&
          other.nome == this.nome &&
          other.ordem == this.ordem &&
          other.ativo == this.ativo &&
          other.criadoEm == this.criadoEm);
}

class UsuariosAppLocaisCompanion
    extends UpdateCompanion<UsuarioAppLocalRegistro> {
  final Value<String> id;
  final Value<String> nome;
  final Value<int> ordem;
  final Value<bool> ativo;
  final Value<DateTime> criadoEm;
  final Value<int> rowid;
  const UsuariosAppLocaisCompanion({
    this.id = const Value.absent(),
    this.nome = const Value.absent(),
    this.ordem = const Value.absent(),
    this.ativo = const Value.absent(),
    this.criadoEm = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UsuariosAppLocaisCompanion.insert({
    required String id,
    required String nome,
    this.ordem = const Value.absent(),
    this.ativo = const Value.absent(),
    required DateTime criadoEm,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       nome = Value(nome),
       criadoEm = Value(criadoEm);
  static Insertable<UsuarioAppLocalRegistro> custom({
    Expression<String>? id,
    Expression<String>? nome,
    Expression<int>? ordem,
    Expression<bool>? ativo,
    Expression<DateTime>? criadoEm,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nome != null) 'nome': nome,
      if (ordem != null) 'ordem': ordem,
      if (ativo != null) 'ativo': ativo,
      if (criadoEm != null) 'criado_em': criadoEm,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UsuariosAppLocaisCompanion copyWith({
    Value<String>? id,
    Value<String>? nome,
    Value<int>? ordem,
    Value<bool>? ativo,
    Value<DateTime>? criadoEm,
    Value<int>? rowid,
  }) {
    return UsuariosAppLocaisCompanion(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      ordem: ordem ?? this.ordem,
      ativo: ativo ?? this.ativo,
      criadoEm: criadoEm ?? this.criadoEm,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (nome.present) {
      map['nome'] = Variable<String>(nome.value);
    }
    if (ordem.present) {
      map['ordem'] = Variable<int>(ordem.value);
    }
    if (ativo.present) {
      map['ativo'] = Variable<bool>(ativo.value);
    }
    if (criadoEm.present) {
      map['criado_em'] = Variable<DateTime>(criadoEm.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsuariosAppLocaisCompanion(')
          ..write('id: $id, ')
          ..write('nome: $nome, ')
          ..write('ordem: $ordem, ')
          ..write('ativo: $ativo, ')
          ..write('criadoEm: $criadoEm, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StaffsLocaisTable extends StaffsLocais
    with TableInfo<$StaffsLocaisTable, StaffLocalRegistro> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StaffsLocaisTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nomeMeta = const VerificationMeta('nome');
  @override
  late final GeneratedColumn<String> nome = GeneratedColumn<String>(
    'nome',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sobrenomeMeta = const VerificationMeta(
    'sobrenome',
  );
  @override
  late final GeneratedColumn<String> sobrenome = GeneratedColumn<String>(
    'sobrenome',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ocupacaoMeta = const VerificationMeta(
    'ocupacao',
  );
  @override
  late final GeneratedColumn<String> ocupacao = GeneratedColumn<String>(
    'ocupacao',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _criadoEmMeta = const VerificationMeta(
    'criadoEm',
  );
  @override
  late final GeneratedColumn<DateTime> criadoEm = GeneratedColumn<DateTime>(
    'criado_em',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atualizadoEmMeta = const VerificationMeta(
    'atualizadoEm',
  );
  @override
  late final GeneratedColumn<DateTime> atualizadoEm = GeneratedColumn<DateTime>(
    'atualizado_em',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _excluidoMeta = const VerificationMeta(
    'excluido',
  );
  @override
  late final GeneratedColumn<bool> excluido = GeneratedColumn<bool>(
    'excluido',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("excluido" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    nome,
    sobrenome,
    ocupacao,
    criadoEm,
    atualizadoEm,
    excluido,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'staffs_locais';
  @override
  VerificationContext validateIntegrity(
    Insertable<StaffLocalRegistro> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('nome')) {
      context.handle(
        _nomeMeta,
        nome.isAcceptableOrUnknown(data['nome']!, _nomeMeta),
      );
    } else if (isInserting) {
      context.missing(_nomeMeta);
    }
    if (data.containsKey('sobrenome')) {
      context.handle(
        _sobrenomeMeta,
        sobrenome.isAcceptableOrUnknown(data['sobrenome']!, _sobrenomeMeta),
      );
    } else if (isInserting) {
      context.missing(_sobrenomeMeta);
    }
    if (data.containsKey('ocupacao')) {
      context.handle(
        _ocupacaoMeta,
        ocupacao.isAcceptableOrUnknown(data['ocupacao']!, _ocupacaoMeta),
      );
    } else if (isInserting) {
      context.missing(_ocupacaoMeta);
    }
    if (data.containsKey('criado_em')) {
      context.handle(
        _criadoEmMeta,
        criadoEm.isAcceptableOrUnknown(data['criado_em']!, _criadoEmMeta),
      );
    } else if (isInserting) {
      context.missing(_criadoEmMeta);
    }
    if (data.containsKey('atualizado_em')) {
      context.handle(
        _atualizadoEmMeta,
        atualizadoEm.isAcceptableOrUnknown(
          data['atualizado_em']!,
          _atualizadoEmMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_atualizadoEmMeta);
    }
    if (data.containsKey('excluido')) {
      context.handle(
        _excluidoMeta,
        excluido.isAcceptableOrUnknown(data['excluido']!, _excluidoMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StaffLocalRegistro map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StaffLocalRegistro(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      nome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nome'],
      )!,
      sobrenome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sobrenome'],
      )!,
      ocupacao: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ocupacao'],
      )!,
      criadoEm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}criado_em'],
      )!,
      atualizadoEm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}atualizado_em'],
      )!,
      excluido: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}excluido'],
      )!,
    );
  }

  @override
  $StaffsLocaisTable createAlias(String alias) {
    return $StaffsLocaisTable(attachedDatabase, alias);
  }
}

class StaffLocalRegistro extends DataClass
    implements Insertable<StaffLocalRegistro> {
  final String id;
  final String nome;
  final String sobrenome;
  final String ocupacao;
  final DateTime criadoEm;
  final DateTime atualizadoEm;
  final bool excluido;
  const StaffLocalRegistro({
    required this.id,
    required this.nome,
    required this.sobrenome,
    required this.ocupacao,
    required this.criadoEm,
    required this.atualizadoEm,
    required this.excluido,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['nome'] = Variable<String>(nome);
    map['sobrenome'] = Variable<String>(sobrenome);
    map['ocupacao'] = Variable<String>(ocupacao);
    map['criado_em'] = Variable<DateTime>(criadoEm);
    map['atualizado_em'] = Variable<DateTime>(atualizadoEm);
    map['excluido'] = Variable<bool>(excluido);
    return map;
  }

  StaffsLocaisCompanion toCompanion(bool nullToAbsent) {
    return StaffsLocaisCompanion(
      id: Value(id),
      nome: Value(nome),
      sobrenome: Value(sobrenome),
      ocupacao: Value(ocupacao),
      criadoEm: Value(criadoEm),
      atualizadoEm: Value(atualizadoEm),
      excluido: Value(excluido),
    );
  }

  factory StaffLocalRegistro.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StaffLocalRegistro(
      id: serializer.fromJson<String>(json['id']),
      nome: serializer.fromJson<String>(json['nome']),
      sobrenome: serializer.fromJson<String>(json['sobrenome']),
      ocupacao: serializer.fromJson<String>(json['ocupacao']),
      criadoEm: serializer.fromJson<DateTime>(json['criadoEm']),
      atualizadoEm: serializer.fromJson<DateTime>(json['atualizadoEm']),
      excluido: serializer.fromJson<bool>(json['excluido']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'nome': serializer.toJson<String>(nome),
      'sobrenome': serializer.toJson<String>(sobrenome),
      'ocupacao': serializer.toJson<String>(ocupacao),
      'criadoEm': serializer.toJson<DateTime>(criadoEm),
      'atualizadoEm': serializer.toJson<DateTime>(atualizadoEm),
      'excluido': serializer.toJson<bool>(excluido),
    };
  }

  StaffLocalRegistro copyWith({
    String? id,
    String? nome,
    String? sobrenome,
    String? ocupacao,
    DateTime? criadoEm,
    DateTime? atualizadoEm,
    bool? excluido,
  }) => StaffLocalRegistro(
    id: id ?? this.id,
    nome: nome ?? this.nome,
    sobrenome: sobrenome ?? this.sobrenome,
    ocupacao: ocupacao ?? this.ocupacao,
    criadoEm: criadoEm ?? this.criadoEm,
    atualizadoEm: atualizadoEm ?? this.atualizadoEm,
    excluido: excluido ?? this.excluido,
  );
  StaffLocalRegistro copyWithCompanion(StaffsLocaisCompanion data) {
    return StaffLocalRegistro(
      id: data.id.present ? data.id.value : this.id,
      nome: data.nome.present ? data.nome.value : this.nome,
      sobrenome: data.sobrenome.present ? data.sobrenome.value : this.sobrenome,
      ocupacao: data.ocupacao.present ? data.ocupacao.value : this.ocupacao,
      criadoEm: data.criadoEm.present ? data.criadoEm.value : this.criadoEm,
      atualizadoEm: data.atualizadoEm.present
          ? data.atualizadoEm.value
          : this.atualizadoEm,
      excluido: data.excluido.present ? data.excluido.value : this.excluido,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StaffLocalRegistro(')
          ..write('id: $id, ')
          ..write('nome: $nome, ')
          ..write('sobrenome: $sobrenome, ')
          ..write('ocupacao: $ocupacao, ')
          ..write('criadoEm: $criadoEm, ')
          ..write('atualizadoEm: $atualizadoEm, ')
          ..write('excluido: $excluido')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    nome,
    sobrenome,
    ocupacao,
    criadoEm,
    atualizadoEm,
    excluido,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StaffLocalRegistro &&
          other.id == this.id &&
          other.nome == this.nome &&
          other.sobrenome == this.sobrenome &&
          other.ocupacao == this.ocupacao &&
          other.criadoEm == this.criadoEm &&
          other.atualizadoEm == this.atualizadoEm &&
          other.excluido == this.excluido);
}

class StaffsLocaisCompanion extends UpdateCompanion<StaffLocalRegistro> {
  final Value<String> id;
  final Value<String> nome;
  final Value<String> sobrenome;
  final Value<String> ocupacao;
  final Value<DateTime> criadoEm;
  final Value<DateTime> atualizadoEm;
  final Value<bool> excluido;
  final Value<int> rowid;
  const StaffsLocaisCompanion({
    this.id = const Value.absent(),
    this.nome = const Value.absent(),
    this.sobrenome = const Value.absent(),
    this.ocupacao = const Value.absent(),
    this.criadoEm = const Value.absent(),
    this.atualizadoEm = const Value.absent(),
    this.excluido = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StaffsLocaisCompanion.insert({
    required String id,
    required String nome,
    required String sobrenome,
    required String ocupacao,
    required DateTime criadoEm,
    required DateTime atualizadoEm,
    this.excluido = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       nome = Value(nome),
       sobrenome = Value(sobrenome),
       ocupacao = Value(ocupacao),
       criadoEm = Value(criadoEm),
       atualizadoEm = Value(atualizadoEm);
  static Insertable<StaffLocalRegistro> custom({
    Expression<String>? id,
    Expression<String>? nome,
    Expression<String>? sobrenome,
    Expression<String>? ocupacao,
    Expression<DateTime>? criadoEm,
    Expression<DateTime>? atualizadoEm,
    Expression<bool>? excluido,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nome != null) 'nome': nome,
      if (sobrenome != null) 'sobrenome': sobrenome,
      if (ocupacao != null) 'ocupacao': ocupacao,
      if (criadoEm != null) 'criado_em': criadoEm,
      if (atualizadoEm != null) 'atualizado_em': atualizadoEm,
      if (excluido != null) 'excluido': excluido,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StaffsLocaisCompanion copyWith({
    Value<String>? id,
    Value<String>? nome,
    Value<String>? sobrenome,
    Value<String>? ocupacao,
    Value<DateTime>? criadoEm,
    Value<DateTime>? atualizadoEm,
    Value<bool>? excluido,
    Value<int>? rowid,
  }) {
    return StaffsLocaisCompanion(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      sobrenome: sobrenome ?? this.sobrenome,
      ocupacao: ocupacao ?? this.ocupacao,
      criadoEm: criadoEm ?? this.criadoEm,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
      excluido: excluido ?? this.excluido,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (nome.present) {
      map['nome'] = Variable<String>(nome.value);
    }
    if (sobrenome.present) {
      map['sobrenome'] = Variable<String>(sobrenome.value);
    }
    if (ocupacao.present) {
      map['ocupacao'] = Variable<String>(ocupacao.value);
    }
    if (criadoEm.present) {
      map['criado_em'] = Variable<DateTime>(criadoEm.value);
    }
    if (atualizadoEm.present) {
      map['atualizado_em'] = Variable<DateTime>(atualizadoEm.value);
    }
    if (excluido.present) {
      map['excluido'] = Variable<bool>(excluido.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StaffsLocaisCompanion(')
          ..write('id: $id, ')
          ..write('nome: $nome, ')
          ..write('sobrenome: $sobrenome, ')
          ..write('ocupacao: $ocupacao, ')
          ..write('criadoEm: $criadoEm, ')
          ..write('atualizadoEm: $atualizadoEm, ')
          ..write('excluido: $excluido, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MensagensChatLocaisTable extends MensagensChatLocais
    with TableInfo<$MensagensChatLocaisTable, MensagemChatLocalRegistro> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MensagensChatLocaisTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _staffIdMeta = const VerificationMeta(
    'staffId',
  );
  @override
  late final GeneratedColumn<String> staffId = GeneratedColumn<String>(
    'staff_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mensagemMeta = const VerificationMeta(
    'mensagem',
  );
  @override
  late final GeneratedColumn<String> mensagem = GeneratedColumn<String>(
    'mensagem',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _criadoEmMeta = const VerificationMeta(
    'criadoEm',
  );
  @override
  late final GeneratedColumn<DateTime> criadoEm = GeneratedColumn<DateTime>(
    'criado_em',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataServidorMeta = const VerificationMeta(
    'dataServidor',
  );
  @override
  late final GeneratedColumn<DateTime> dataServidor = GeneratedColumn<DateTime>(
    'data_servidor',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _excluidoMeta = const VerificationMeta(
    'excluido',
  );
  @override
  late final GeneratedColumn<bool> excluido = GeneratedColumn<bool>(
    'excluido',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("excluido" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    staffId,
    mensagem,
    criadoEm,
    dataServidor,
    excluido,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mensagens_chat_locais';
  @override
  VerificationContext validateIntegrity(
    Insertable<MensagemChatLocalRegistro> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('staff_id')) {
      context.handle(
        _staffIdMeta,
        staffId.isAcceptableOrUnknown(data['staff_id']!, _staffIdMeta),
      );
    } else if (isInserting) {
      context.missing(_staffIdMeta);
    }
    if (data.containsKey('mensagem')) {
      context.handle(
        _mensagemMeta,
        mensagem.isAcceptableOrUnknown(data['mensagem']!, _mensagemMeta),
      );
    } else if (isInserting) {
      context.missing(_mensagemMeta);
    }
    if (data.containsKey('criado_em')) {
      context.handle(
        _criadoEmMeta,
        criadoEm.isAcceptableOrUnknown(data['criado_em']!, _criadoEmMeta),
      );
    } else if (isInserting) {
      context.missing(_criadoEmMeta);
    }
    if (data.containsKey('data_servidor')) {
      context.handle(
        _dataServidorMeta,
        dataServidor.isAcceptableOrUnknown(
          data['data_servidor']!,
          _dataServidorMeta,
        ),
      );
    }
    if (data.containsKey('excluido')) {
      context.handle(
        _excluidoMeta,
        excluido.isAcceptableOrUnknown(data['excluido']!, _excluidoMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MensagemChatLocalRegistro map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MensagemChatLocalRegistro(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      staffId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}staff_id'],
      )!,
      mensagem: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mensagem'],
      )!,
      criadoEm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}criado_em'],
      )!,
      dataServidor: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}data_servidor'],
      ),
      excluido: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}excluido'],
      )!,
    );
  }

  @override
  $MensagensChatLocaisTable createAlias(String alias) {
    return $MensagensChatLocaisTable(attachedDatabase, alias);
  }
}

class MensagemChatLocalRegistro extends DataClass
    implements Insertable<MensagemChatLocalRegistro> {
  final String id;
  final String staffId;
  final String mensagem;
  final DateTime criadoEm;
  final DateTime? dataServidor;
  final bool excluido;
  const MensagemChatLocalRegistro({
    required this.id,
    required this.staffId,
    required this.mensagem,
    required this.criadoEm,
    this.dataServidor,
    required this.excluido,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['staff_id'] = Variable<String>(staffId);
    map['mensagem'] = Variable<String>(mensagem);
    map['criado_em'] = Variable<DateTime>(criadoEm);
    if (!nullToAbsent || dataServidor != null) {
      map['data_servidor'] = Variable<DateTime>(dataServidor);
    }
    map['excluido'] = Variable<bool>(excluido);
    return map;
  }

  MensagensChatLocaisCompanion toCompanion(bool nullToAbsent) {
    return MensagensChatLocaisCompanion(
      id: Value(id),
      staffId: Value(staffId),
      mensagem: Value(mensagem),
      criadoEm: Value(criadoEm),
      dataServidor: dataServidor == null && nullToAbsent
          ? const Value.absent()
          : Value(dataServidor),
      excluido: Value(excluido),
    );
  }

  factory MensagemChatLocalRegistro.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MensagemChatLocalRegistro(
      id: serializer.fromJson<String>(json['id']),
      staffId: serializer.fromJson<String>(json['staffId']),
      mensagem: serializer.fromJson<String>(json['mensagem']),
      criadoEm: serializer.fromJson<DateTime>(json['criadoEm']),
      dataServidor: serializer.fromJson<DateTime?>(json['dataServidor']),
      excluido: serializer.fromJson<bool>(json['excluido']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'staffId': serializer.toJson<String>(staffId),
      'mensagem': serializer.toJson<String>(mensagem),
      'criadoEm': serializer.toJson<DateTime>(criadoEm),
      'dataServidor': serializer.toJson<DateTime?>(dataServidor),
      'excluido': serializer.toJson<bool>(excluido),
    };
  }

  MensagemChatLocalRegistro copyWith({
    String? id,
    String? staffId,
    String? mensagem,
    DateTime? criadoEm,
    Value<DateTime?> dataServidor = const Value.absent(),
    bool? excluido,
  }) => MensagemChatLocalRegistro(
    id: id ?? this.id,
    staffId: staffId ?? this.staffId,
    mensagem: mensagem ?? this.mensagem,
    criadoEm: criadoEm ?? this.criadoEm,
    dataServidor: dataServidor.present ? dataServidor.value : this.dataServidor,
    excluido: excluido ?? this.excluido,
  );
  MensagemChatLocalRegistro copyWithCompanion(
    MensagensChatLocaisCompanion data,
  ) {
    return MensagemChatLocalRegistro(
      id: data.id.present ? data.id.value : this.id,
      staffId: data.staffId.present ? data.staffId.value : this.staffId,
      mensagem: data.mensagem.present ? data.mensagem.value : this.mensagem,
      criadoEm: data.criadoEm.present ? data.criadoEm.value : this.criadoEm,
      dataServidor: data.dataServidor.present
          ? data.dataServidor.value
          : this.dataServidor,
      excluido: data.excluido.present ? data.excluido.value : this.excluido,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MensagemChatLocalRegistro(')
          ..write('id: $id, ')
          ..write('staffId: $staffId, ')
          ..write('mensagem: $mensagem, ')
          ..write('criadoEm: $criadoEm, ')
          ..write('dataServidor: $dataServidor, ')
          ..write('excluido: $excluido')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, staffId, mensagem, criadoEm, dataServidor, excluido);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MensagemChatLocalRegistro &&
          other.id == this.id &&
          other.staffId == this.staffId &&
          other.mensagem == this.mensagem &&
          other.criadoEm == this.criadoEm &&
          other.dataServidor == this.dataServidor &&
          other.excluido == this.excluido);
}

class MensagensChatLocaisCompanion
    extends UpdateCompanion<MensagemChatLocalRegistro> {
  final Value<String> id;
  final Value<String> staffId;
  final Value<String> mensagem;
  final Value<DateTime> criadoEm;
  final Value<DateTime?> dataServidor;
  final Value<bool> excluido;
  final Value<int> rowid;
  const MensagensChatLocaisCompanion({
    this.id = const Value.absent(),
    this.staffId = const Value.absent(),
    this.mensagem = const Value.absent(),
    this.criadoEm = const Value.absent(),
    this.dataServidor = const Value.absent(),
    this.excluido = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MensagensChatLocaisCompanion.insert({
    required String id,
    required String staffId,
    required String mensagem,
    required DateTime criadoEm,
    this.dataServidor = const Value.absent(),
    this.excluido = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       staffId = Value(staffId),
       mensagem = Value(mensagem),
       criadoEm = Value(criadoEm);
  static Insertable<MensagemChatLocalRegistro> custom({
    Expression<String>? id,
    Expression<String>? staffId,
    Expression<String>? mensagem,
    Expression<DateTime>? criadoEm,
    Expression<DateTime>? dataServidor,
    Expression<bool>? excluido,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (staffId != null) 'staff_id': staffId,
      if (mensagem != null) 'mensagem': mensagem,
      if (criadoEm != null) 'criado_em': criadoEm,
      if (dataServidor != null) 'data_servidor': dataServidor,
      if (excluido != null) 'excluido': excluido,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MensagensChatLocaisCompanion copyWith({
    Value<String>? id,
    Value<String>? staffId,
    Value<String>? mensagem,
    Value<DateTime>? criadoEm,
    Value<DateTime?>? dataServidor,
    Value<bool>? excluido,
    Value<int>? rowid,
  }) {
    return MensagensChatLocaisCompanion(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      mensagem: mensagem ?? this.mensagem,
      criadoEm: criadoEm ?? this.criadoEm,
      dataServidor: dataServidor ?? this.dataServidor,
      excluido: excluido ?? this.excluido,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (staffId.present) {
      map['staff_id'] = Variable<String>(staffId.value);
    }
    if (mensagem.present) {
      map['mensagem'] = Variable<String>(mensagem.value);
    }
    if (criadoEm.present) {
      map['criado_em'] = Variable<DateTime>(criadoEm.value);
    }
    if (dataServidor.present) {
      map['data_servidor'] = Variable<DateTime>(dataServidor.value);
    }
    if (excluido.present) {
      map['excluido'] = Variable<bool>(excluido.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MensagensChatLocaisCompanion(')
          ..write('id: $id, ')
          ..write('staffId: $staffId, ')
          ..write('mensagem: $mensagem, ')
          ..write('criadoEm: $criadoEm, ')
          ..write('dataServidor: $dataServidor, ')
          ..write('excluido: $excluido, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EventosCheckinLocaisTable extends EventosCheckinLocais
    with TableInfo<$EventosCheckinLocaisTable, EventoCheckinLocalRegistro> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventosCheckinLocaisTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _convidadoIdMeta = const VerificationMeta(
    'convidadoId',
  );
  @override
  late final GeneratedColumn<String> convidadoId = GeneratedColumn<String>(
    'convidado_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usuarioIdMeta = const VerificationMeta(
    'usuarioId',
  );
  @override
  late final GeneratedColumn<String> usuarioId = GeneratedColumn<String>(
    'usuario_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tipoAcaoMeta = const VerificationMeta(
    'tipoAcao',
  );
  @override
  late final GeneratedColumn<String> tipoAcao = GeneratedColumn<String>(
    'tipo_acao',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _estadoResultanteMeta = const VerificationMeta(
    'estadoResultante',
  );
  @override
  late final GeneratedColumn<bool> estadoResultante = GeneratedColumn<bool>(
    'estado_resultante',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("estado_resultante" IN (0, 1))',
    ),
  );
  static const VerificationMeta _eventosBaseJsonMeta = const VerificationMeta(
    'eventosBaseJson',
  );
  @override
  late final GeneratedColumn<String> eventosBaseJson = GeneratedColumn<String>(
    'eventos_base_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _dataDispositivoMeta = const VerificationMeta(
    'dataDispositivo',
  );
  @override
  late final GeneratedColumn<DateTime> dataDispositivo =
      GeneratedColumn<DateTime>(
        'data_dispositivo',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _sequenciaDispositivoMeta =
      const VerificationMeta('sequenciaDispositivo');
  @override
  late final GeneratedColumn<int> sequenciaDispositivo = GeneratedColumn<int>(
    'sequencia_dispositivo',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dispositivoIdMeta = const VerificationMeta(
    'dispositivoId',
  );
  @override
  late final GeneratedColumn<String> dispositivoId = GeneratedColumn<String>(
    'dispositivo_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataServidorMeta = const VerificationMeta(
    'dataServidor',
  );
  @override
  late final GeneratedColumn<DateTime> dataServidor = GeneratedColumn<DateTime>(
    'data_servidor',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _observacaoMeta = const VerificationMeta(
    'observacao',
  );
  @override
  late final GeneratedColumn<String> observacao = GeneratedColumn<String>(
    'observacao',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sincronizadoMeta = const VerificationMeta(
    'sincronizado',
  );
  @override
  late final GeneratedColumn<bool> sincronizado = GeneratedColumn<bool>(
    'sincronizado',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sincronizado" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    convidadoId,
    usuarioId,
    tipoAcao,
    estadoResultante,
    eventosBaseJson,
    dataDispositivo,
    sequenciaDispositivo,
    dispositivoId,
    dataServidor,
    observacao,
    sincronizado,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'eventos_checkin_locais';
  @override
  VerificationContext validateIntegrity(
    Insertable<EventoCheckinLocalRegistro> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('convidado_id')) {
      context.handle(
        _convidadoIdMeta,
        convidadoId.isAcceptableOrUnknown(
          data['convidado_id']!,
          _convidadoIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_convidadoIdMeta);
    }
    if (data.containsKey('usuario_id')) {
      context.handle(
        _usuarioIdMeta,
        usuarioId.isAcceptableOrUnknown(data['usuario_id']!, _usuarioIdMeta),
      );
    } else if (isInserting) {
      context.missing(_usuarioIdMeta);
    }
    if (data.containsKey('tipo_acao')) {
      context.handle(
        _tipoAcaoMeta,
        tipoAcao.isAcceptableOrUnknown(data['tipo_acao']!, _tipoAcaoMeta),
      );
    } else if (isInserting) {
      context.missing(_tipoAcaoMeta);
    }
    if (data.containsKey('estado_resultante')) {
      context.handle(
        _estadoResultanteMeta,
        estadoResultante.isAcceptableOrUnknown(
          data['estado_resultante']!,
          _estadoResultanteMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_estadoResultanteMeta);
    }
    if (data.containsKey('eventos_base_json')) {
      context.handle(
        _eventosBaseJsonMeta,
        eventosBaseJson.isAcceptableOrUnknown(
          data['eventos_base_json']!,
          _eventosBaseJsonMeta,
        ),
      );
    }
    if (data.containsKey('data_dispositivo')) {
      context.handle(
        _dataDispositivoMeta,
        dataDispositivo.isAcceptableOrUnknown(
          data['data_dispositivo']!,
          _dataDispositivoMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dataDispositivoMeta);
    }
    if (data.containsKey('sequencia_dispositivo')) {
      context.handle(
        _sequenciaDispositivoMeta,
        sequenciaDispositivo.isAcceptableOrUnknown(
          data['sequencia_dispositivo']!,
          _sequenciaDispositivoMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sequenciaDispositivoMeta);
    }
    if (data.containsKey('dispositivo_id')) {
      context.handle(
        _dispositivoIdMeta,
        dispositivoId.isAcceptableOrUnknown(
          data['dispositivo_id']!,
          _dispositivoIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dispositivoIdMeta);
    }
    if (data.containsKey('data_servidor')) {
      context.handle(
        _dataServidorMeta,
        dataServidor.isAcceptableOrUnknown(
          data['data_servidor']!,
          _dataServidorMeta,
        ),
      );
    }
    if (data.containsKey('observacao')) {
      context.handle(
        _observacaoMeta,
        observacao.isAcceptableOrUnknown(data['observacao']!, _observacaoMeta),
      );
    }
    if (data.containsKey('sincronizado')) {
      context.handle(
        _sincronizadoMeta,
        sincronizado.isAcceptableOrUnknown(
          data['sincronizado']!,
          _sincronizadoMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {dispositivoId, sequenciaDispositivo},
  ];
  @override
  EventoCheckinLocalRegistro map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EventoCheckinLocalRegistro(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      convidadoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}convidado_id'],
      )!,
      usuarioId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}usuario_id'],
      )!,
      tipoAcao: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tipo_acao'],
      )!,
      estadoResultante: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}estado_resultante'],
      )!,
      eventosBaseJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}eventos_base_json'],
      )!,
      dataDispositivo: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}data_dispositivo'],
      )!,
      sequenciaDispositivo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequencia_dispositivo'],
      )!,
      dispositivoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dispositivo_id'],
      )!,
      dataServidor: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}data_servidor'],
      ),
      observacao: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}observacao'],
      ),
      sincronizado: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sincronizado'],
      )!,
    );
  }

  @override
  $EventosCheckinLocaisTable createAlias(String alias) {
    return $EventosCheckinLocaisTable(attachedDatabase, alias);
  }
}

class EventoCheckinLocalRegistro extends DataClass
    implements Insertable<EventoCheckinLocalRegistro> {
  final String id;
  final String convidadoId;
  final String usuarioId;

  /// Valores possíveis:
  ///
  /// confirmou_chegada
  /// removeu_chegada
  /// resolveu_como_presente
  /// resolveu_como_ausente
  final String tipoAcao;
  final bool estadoResultante;

  /// Eventos que o aparelho conhecia no momento da nova ação.
  ///
  /// A lista é armazenada como JSON porque o SQLite não utiliza diretamente
  /// o tipo uuid[] existente no PostgreSQL.
  final String eventosBaseJson;
  final DateTime dataDispositivo;
  final int sequenciaDispositivo;
  final String dispositivoId;
  final DateTime? dataServidor;
  final String? observacao;
  final bool sincronizado;
  const EventoCheckinLocalRegistro({
    required this.id,
    required this.convidadoId,
    required this.usuarioId,
    required this.tipoAcao,
    required this.estadoResultante,
    required this.eventosBaseJson,
    required this.dataDispositivo,
    required this.sequenciaDispositivo,
    required this.dispositivoId,
    this.dataServidor,
    this.observacao,
    required this.sincronizado,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['convidado_id'] = Variable<String>(convidadoId);
    map['usuario_id'] = Variable<String>(usuarioId);
    map['tipo_acao'] = Variable<String>(tipoAcao);
    map['estado_resultante'] = Variable<bool>(estadoResultante);
    map['eventos_base_json'] = Variable<String>(eventosBaseJson);
    map['data_dispositivo'] = Variable<DateTime>(dataDispositivo);
    map['sequencia_dispositivo'] = Variable<int>(sequenciaDispositivo);
    map['dispositivo_id'] = Variable<String>(dispositivoId);
    if (!nullToAbsent || dataServidor != null) {
      map['data_servidor'] = Variable<DateTime>(dataServidor);
    }
    if (!nullToAbsent || observacao != null) {
      map['observacao'] = Variable<String>(observacao);
    }
    map['sincronizado'] = Variable<bool>(sincronizado);
    return map;
  }

  EventosCheckinLocaisCompanion toCompanion(bool nullToAbsent) {
    return EventosCheckinLocaisCompanion(
      id: Value(id),
      convidadoId: Value(convidadoId),
      usuarioId: Value(usuarioId),
      tipoAcao: Value(tipoAcao),
      estadoResultante: Value(estadoResultante),
      eventosBaseJson: Value(eventosBaseJson),
      dataDispositivo: Value(dataDispositivo),
      sequenciaDispositivo: Value(sequenciaDispositivo),
      dispositivoId: Value(dispositivoId),
      dataServidor: dataServidor == null && nullToAbsent
          ? const Value.absent()
          : Value(dataServidor),
      observacao: observacao == null && nullToAbsent
          ? const Value.absent()
          : Value(observacao),
      sincronizado: Value(sincronizado),
    );
  }

  factory EventoCheckinLocalRegistro.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EventoCheckinLocalRegistro(
      id: serializer.fromJson<String>(json['id']),
      convidadoId: serializer.fromJson<String>(json['convidadoId']),
      usuarioId: serializer.fromJson<String>(json['usuarioId']),
      tipoAcao: serializer.fromJson<String>(json['tipoAcao']),
      estadoResultante: serializer.fromJson<bool>(json['estadoResultante']),
      eventosBaseJson: serializer.fromJson<String>(json['eventosBaseJson']),
      dataDispositivo: serializer.fromJson<DateTime>(json['dataDispositivo']),
      sequenciaDispositivo: serializer.fromJson<int>(
        json['sequenciaDispositivo'],
      ),
      dispositivoId: serializer.fromJson<String>(json['dispositivoId']),
      dataServidor: serializer.fromJson<DateTime?>(json['dataServidor']),
      observacao: serializer.fromJson<String?>(json['observacao']),
      sincronizado: serializer.fromJson<bool>(json['sincronizado']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'convidadoId': serializer.toJson<String>(convidadoId),
      'usuarioId': serializer.toJson<String>(usuarioId),
      'tipoAcao': serializer.toJson<String>(tipoAcao),
      'estadoResultante': serializer.toJson<bool>(estadoResultante),
      'eventosBaseJson': serializer.toJson<String>(eventosBaseJson),
      'dataDispositivo': serializer.toJson<DateTime>(dataDispositivo),
      'sequenciaDispositivo': serializer.toJson<int>(sequenciaDispositivo),
      'dispositivoId': serializer.toJson<String>(dispositivoId),
      'dataServidor': serializer.toJson<DateTime?>(dataServidor),
      'observacao': serializer.toJson<String?>(observacao),
      'sincronizado': serializer.toJson<bool>(sincronizado),
    };
  }

  EventoCheckinLocalRegistro copyWith({
    String? id,
    String? convidadoId,
    String? usuarioId,
    String? tipoAcao,
    bool? estadoResultante,
    String? eventosBaseJson,
    DateTime? dataDispositivo,
    int? sequenciaDispositivo,
    String? dispositivoId,
    Value<DateTime?> dataServidor = const Value.absent(),
    Value<String?> observacao = const Value.absent(),
    bool? sincronizado,
  }) => EventoCheckinLocalRegistro(
    id: id ?? this.id,
    convidadoId: convidadoId ?? this.convidadoId,
    usuarioId: usuarioId ?? this.usuarioId,
    tipoAcao: tipoAcao ?? this.tipoAcao,
    estadoResultante: estadoResultante ?? this.estadoResultante,
    eventosBaseJson: eventosBaseJson ?? this.eventosBaseJson,
    dataDispositivo: dataDispositivo ?? this.dataDispositivo,
    sequenciaDispositivo: sequenciaDispositivo ?? this.sequenciaDispositivo,
    dispositivoId: dispositivoId ?? this.dispositivoId,
    dataServidor: dataServidor.present ? dataServidor.value : this.dataServidor,
    observacao: observacao.present ? observacao.value : this.observacao,
    sincronizado: sincronizado ?? this.sincronizado,
  );
  EventoCheckinLocalRegistro copyWithCompanion(
    EventosCheckinLocaisCompanion data,
  ) {
    return EventoCheckinLocalRegistro(
      id: data.id.present ? data.id.value : this.id,
      convidadoId: data.convidadoId.present
          ? data.convidadoId.value
          : this.convidadoId,
      usuarioId: data.usuarioId.present ? data.usuarioId.value : this.usuarioId,
      tipoAcao: data.tipoAcao.present ? data.tipoAcao.value : this.tipoAcao,
      estadoResultante: data.estadoResultante.present
          ? data.estadoResultante.value
          : this.estadoResultante,
      eventosBaseJson: data.eventosBaseJson.present
          ? data.eventosBaseJson.value
          : this.eventosBaseJson,
      dataDispositivo: data.dataDispositivo.present
          ? data.dataDispositivo.value
          : this.dataDispositivo,
      sequenciaDispositivo: data.sequenciaDispositivo.present
          ? data.sequenciaDispositivo.value
          : this.sequenciaDispositivo,
      dispositivoId: data.dispositivoId.present
          ? data.dispositivoId.value
          : this.dispositivoId,
      dataServidor: data.dataServidor.present
          ? data.dataServidor.value
          : this.dataServidor,
      observacao: data.observacao.present
          ? data.observacao.value
          : this.observacao,
      sincronizado: data.sincronizado.present
          ? data.sincronizado.value
          : this.sincronizado,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EventoCheckinLocalRegistro(')
          ..write('id: $id, ')
          ..write('convidadoId: $convidadoId, ')
          ..write('usuarioId: $usuarioId, ')
          ..write('tipoAcao: $tipoAcao, ')
          ..write('estadoResultante: $estadoResultante, ')
          ..write('eventosBaseJson: $eventosBaseJson, ')
          ..write('dataDispositivo: $dataDispositivo, ')
          ..write('sequenciaDispositivo: $sequenciaDispositivo, ')
          ..write('dispositivoId: $dispositivoId, ')
          ..write('dataServidor: $dataServidor, ')
          ..write('observacao: $observacao, ')
          ..write('sincronizado: $sincronizado')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    convidadoId,
    usuarioId,
    tipoAcao,
    estadoResultante,
    eventosBaseJson,
    dataDispositivo,
    sequenciaDispositivo,
    dispositivoId,
    dataServidor,
    observacao,
    sincronizado,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventoCheckinLocalRegistro &&
          other.id == this.id &&
          other.convidadoId == this.convidadoId &&
          other.usuarioId == this.usuarioId &&
          other.tipoAcao == this.tipoAcao &&
          other.estadoResultante == this.estadoResultante &&
          other.eventosBaseJson == this.eventosBaseJson &&
          other.dataDispositivo == this.dataDispositivo &&
          other.sequenciaDispositivo == this.sequenciaDispositivo &&
          other.dispositivoId == this.dispositivoId &&
          other.dataServidor == this.dataServidor &&
          other.observacao == this.observacao &&
          other.sincronizado == this.sincronizado);
}

class EventosCheckinLocaisCompanion
    extends UpdateCompanion<EventoCheckinLocalRegistro> {
  final Value<String> id;
  final Value<String> convidadoId;
  final Value<String> usuarioId;
  final Value<String> tipoAcao;
  final Value<bool> estadoResultante;
  final Value<String> eventosBaseJson;
  final Value<DateTime> dataDispositivo;
  final Value<int> sequenciaDispositivo;
  final Value<String> dispositivoId;
  final Value<DateTime?> dataServidor;
  final Value<String?> observacao;
  final Value<bool> sincronizado;
  final Value<int> rowid;
  const EventosCheckinLocaisCompanion({
    this.id = const Value.absent(),
    this.convidadoId = const Value.absent(),
    this.usuarioId = const Value.absent(),
    this.tipoAcao = const Value.absent(),
    this.estadoResultante = const Value.absent(),
    this.eventosBaseJson = const Value.absent(),
    this.dataDispositivo = const Value.absent(),
    this.sequenciaDispositivo = const Value.absent(),
    this.dispositivoId = const Value.absent(),
    this.dataServidor = const Value.absent(),
    this.observacao = const Value.absent(),
    this.sincronizado = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EventosCheckinLocaisCompanion.insert({
    required String id,
    required String convidadoId,
    required String usuarioId,
    required String tipoAcao,
    required bool estadoResultante,
    this.eventosBaseJson = const Value.absent(),
    required DateTime dataDispositivo,
    required int sequenciaDispositivo,
    required String dispositivoId,
    this.dataServidor = const Value.absent(),
    this.observacao = const Value.absent(),
    this.sincronizado = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       convidadoId = Value(convidadoId),
       usuarioId = Value(usuarioId),
       tipoAcao = Value(tipoAcao),
       estadoResultante = Value(estadoResultante),
       dataDispositivo = Value(dataDispositivo),
       sequenciaDispositivo = Value(sequenciaDispositivo),
       dispositivoId = Value(dispositivoId);
  static Insertable<EventoCheckinLocalRegistro> custom({
    Expression<String>? id,
    Expression<String>? convidadoId,
    Expression<String>? usuarioId,
    Expression<String>? tipoAcao,
    Expression<bool>? estadoResultante,
    Expression<String>? eventosBaseJson,
    Expression<DateTime>? dataDispositivo,
    Expression<int>? sequenciaDispositivo,
    Expression<String>? dispositivoId,
    Expression<DateTime>? dataServidor,
    Expression<String>? observacao,
    Expression<bool>? sincronizado,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (convidadoId != null) 'convidado_id': convidadoId,
      if (usuarioId != null) 'usuario_id': usuarioId,
      if (tipoAcao != null) 'tipo_acao': tipoAcao,
      if (estadoResultante != null) 'estado_resultante': estadoResultante,
      if (eventosBaseJson != null) 'eventos_base_json': eventosBaseJson,
      if (dataDispositivo != null) 'data_dispositivo': dataDispositivo,
      if (sequenciaDispositivo != null)
        'sequencia_dispositivo': sequenciaDispositivo,
      if (dispositivoId != null) 'dispositivo_id': dispositivoId,
      if (dataServidor != null) 'data_servidor': dataServidor,
      if (observacao != null) 'observacao': observacao,
      if (sincronizado != null) 'sincronizado': sincronizado,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EventosCheckinLocaisCompanion copyWith({
    Value<String>? id,
    Value<String>? convidadoId,
    Value<String>? usuarioId,
    Value<String>? tipoAcao,
    Value<bool>? estadoResultante,
    Value<String>? eventosBaseJson,
    Value<DateTime>? dataDispositivo,
    Value<int>? sequenciaDispositivo,
    Value<String>? dispositivoId,
    Value<DateTime?>? dataServidor,
    Value<String?>? observacao,
    Value<bool>? sincronizado,
    Value<int>? rowid,
  }) {
    return EventosCheckinLocaisCompanion(
      id: id ?? this.id,
      convidadoId: convidadoId ?? this.convidadoId,
      usuarioId: usuarioId ?? this.usuarioId,
      tipoAcao: tipoAcao ?? this.tipoAcao,
      estadoResultante: estadoResultante ?? this.estadoResultante,
      eventosBaseJson: eventosBaseJson ?? this.eventosBaseJson,
      dataDispositivo: dataDispositivo ?? this.dataDispositivo,
      sequenciaDispositivo: sequenciaDispositivo ?? this.sequenciaDispositivo,
      dispositivoId: dispositivoId ?? this.dispositivoId,
      dataServidor: dataServidor ?? this.dataServidor,
      observacao: observacao ?? this.observacao,
      sincronizado: sincronizado ?? this.sincronizado,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (convidadoId.present) {
      map['convidado_id'] = Variable<String>(convidadoId.value);
    }
    if (usuarioId.present) {
      map['usuario_id'] = Variable<String>(usuarioId.value);
    }
    if (tipoAcao.present) {
      map['tipo_acao'] = Variable<String>(tipoAcao.value);
    }
    if (estadoResultante.present) {
      map['estado_resultante'] = Variable<bool>(estadoResultante.value);
    }
    if (eventosBaseJson.present) {
      map['eventos_base_json'] = Variable<String>(eventosBaseJson.value);
    }
    if (dataDispositivo.present) {
      map['data_dispositivo'] = Variable<DateTime>(dataDispositivo.value);
    }
    if (sequenciaDispositivo.present) {
      map['sequencia_dispositivo'] = Variable<int>(sequenciaDispositivo.value);
    }
    if (dispositivoId.present) {
      map['dispositivo_id'] = Variable<String>(dispositivoId.value);
    }
    if (dataServidor.present) {
      map['data_servidor'] = Variable<DateTime>(dataServidor.value);
    }
    if (observacao.present) {
      map['observacao'] = Variable<String>(observacao.value);
    }
    if (sincronizado.present) {
      map['sincronizado'] = Variable<bool>(sincronizado.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventosCheckinLocaisCompanion(')
          ..write('id: $id, ')
          ..write('convidadoId: $convidadoId, ')
          ..write('usuarioId: $usuarioId, ')
          ..write('tipoAcao: $tipoAcao, ')
          ..write('estadoResultante: $estadoResultante, ')
          ..write('eventosBaseJson: $eventosBaseJson, ')
          ..write('dataDispositivo: $dataDispositivo, ')
          ..write('sequenciaDispositivo: $sequenciaDispositivo, ')
          ..write('dispositivoId: $dispositivoId, ')
          ..write('dataServidor: $dataServidor, ')
          ..write('observacao: $observacao, ')
          ..write('sincronizado: $sincronizado, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OperacoesPendentesLocaisTable extends OperacoesPendentesLocais
    with
        TableInfo<
          $OperacoesPendentesLocaisTable,
          OperacaoPendenteLocalRegistro
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OperacoesPendentesLocaisTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entidadeMeta = const VerificationMeta(
    'entidade',
  );
  @override
  late final GeneratedColumn<String> entidade = GeneratedColumn<String>(
    'entidade',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entidadeIdMeta = const VerificationMeta(
    'entidadeId',
  );
  @override
  late final GeneratedColumn<String> entidadeId = GeneratedColumn<String>(
    'entidade_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tipoOperacaoMeta = const VerificationMeta(
    'tipoOperacao',
  );
  @override
  late final GeneratedColumn<String> tipoOperacao = GeneratedColumn<String>(
    'tipo_operacao',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _criadoEmMeta = const VerificationMeta(
    'criadoEm',
  );
  @override
  late final GeneratedColumn<DateTime> criadoEm = GeneratedColumn<DateTime>(
    'criado_em',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tentativasMeta = const VerificationMeta(
    'tentativas',
  );
  @override
  late final GeneratedColumn<int> tentativas = GeneratedColumn<int>(
    'tentativas',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _ultimoErroMeta = const VerificationMeta(
    'ultimoErro',
  );
  @override
  late final GeneratedColumn<String> ultimoErro = GeneratedColumn<String>(
    'ultimo_erro',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pendente'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entidade,
    entidadeId,
    tipoOperacao,
    payloadJson,
    criadoEm,
    tentativas,
    ultimoErro,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'operacoes_pendentes_locais';
  @override
  VerificationContext validateIntegrity(
    Insertable<OperacaoPendenteLocalRegistro> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('entidade')) {
      context.handle(
        _entidadeMeta,
        entidade.isAcceptableOrUnknown(data['entidade']!, _entidadeMeta),
      );
    } else if (isInserting) {
      context.missing(_entidadeMeta);
    }
    if (data.containsKey('entidade_id')) {
      context.handle(
        _entidadeIdMeta,
        entidadeId.isAcceptableOrUnknown(data['entidade_id']!, _entidadeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entidadeIdMeta);
    }
    if (data.containsKey('tipo_operacao')) {
      context.handle(
        _tipoOperacaoMeta,
        tipoOperacao.isAcceptableOrUnknown(
          data['tipo_operacao']!,
          _tipoOperacaoMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tipoOperacaoMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('criado_em')) {
      context.handle(
        _criadoEmMeta,
        criadoEm.isAcceptableOrUnknown(data['criado_em']!, _criadoEmMeta),
      );
    } else if (isInserting) {
      context.missing(_criadoEmMeta);
    }
    if (data.containsKey('tentativas')) {
      context.handle(
        _tentativasMeta,
        tentativas.isAcceptableOrUnknown(data['tentativas']!, _tentativasMeta),
      );
    }
    if (data.containsKey('ultimo_erro')) {
      context.handle(
        _ultimoErroMeta,
        ultimoErro.isAcceptableOrUnknown(data['ultimo_erro']!, _ultimoErroMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OperacaoPendenteLocalRegistro map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OperacaoPendenteLocalRegistro(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      entidade: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entidade'],
      )!,
      entidadeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entidade_id'],
      )!,
      tipoOperacao: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tipo_operacao'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      criadoEm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}criado_em'],
      )!,
      tentativas: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tentativas'],
      )!,
      ultimoErro: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ultimo_erro'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $OperacoesPendentesLocaisTable createAlias(String alias) {
    return $OperacoesPendentesLocaisTable(attachedDatabase, alias);
  }
}

class OperacaoPendenteLocalRegistro extends DataClass
    implements Insertable<OperacaoPendenteLocalRegistro> {
  final String id;

  /// Exemplos:
  ///
  /// mesa
  /// convidado
  /// staff
  /// mensagem_chat
  /// evento_checkin
  final String entidade;
  final String entidadeId;

  /// Exemplos:
  ///
  /// inserir
  /// atualizar
  /// excluir
  final String tipoOperacao;

  /// Dados completos que deverão ser enviados ao Supabase.
  final String payloadJson;
  final DateTime criadoEm;
  final int tentativas;
  final String? ultimoErro;

  /// Valores usados inicialmente:
  ///
  /// pendente
  /// enviando
  /// erro
  final String status;
  const OperacaoPendenteLocalRegistro({
    required this.id,
    required this.entidade,
    required this.entidadeId,
    required this.tipoOperacao,
    required this.payloadJson,
    required this.criadoEm,
    required this.tentativas,
    this.ultimoErro,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['entidade'] = Variable<String>(entidade);
    map['entidade_id'] = Variable<String>(entidadeId);
    map['tipo_operacao'] = Variable<String>(tipoOperacao);
    map['payload_json'] = Variable<String>(payloadJson);
    map['criado_em'] = Variable<DateTime>(criadoEm);
    map['tentativas'] = Variable<int>(tentativas);
    if (!nullToAbsent || ultimoErro != null) {
      map['ultimo_erro'] = Variable<String>(ultimoErro);
    }
    map['status'] = Variable<String>(status);
    return map;
  }

  OperacoesPendentesLocaisCompanion toCompanion(bool nullToAbsent) {
    return OperacoesPendentesLocaisCompanion(
      id: Value(id),
      entidade: Value(entidade),
      entidadeId: Value(entidadeId),
      tipoOperacao: Value(tipoOperacao),
      payloadJson: Value(payloadJson),
      criadoEm: Value(criadoEm),
      tentativas: Value(tentativas),
      ultimoErro: ultimoErro == null && nullToAbsent
          ? const Value.absent()
          : Value(ultimoErro),
      status: Value(status),
    );
  }

  factory OperacaoPendenteLocalRegistro.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OperacaoPendenteLocalRegistro(
      id: serializer.fromJson<String>(json['id']),
      entidade: serializer.fromJson<String>(json['entidade']),
      entidadeId: serializer.fromJson<String>(json['entidadeId']),
      tipoOperacao: serializer.fromJson<String>(json['tipoOperacao']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      criadoEm: serializer.fromJson<DateTime>(json['criadoEm']),
      tentativas: serializer.fromJson<int>(json['tentativas']),
      ultimoErro: serializer.fromJson<String?>(json['ultimoErro']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'entidade': serializer.toJson<String>(entidade),
      'entidadeId': serializer.toJson<String>(entidadeId),
      'tipoOperacao': serializer.toJson<String>(tipoOperacao),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'criadoEm': serializer.toJson<DateTime>(criadoEm),
      'tentativas': serializer.toJson<int>(tentativas),
      'ultimoErro': serializer.toJson<String?>(ultimoErro),
      'status': serializer.toJson<String>(status),
    };
  }

  OperacaoPendenteLocalRegistro copyWith({
    String? id,
    String? entidade,
    String? entidadeId,
    String? tipoOperacao,
    String? payloadJson,
    DateTime? criadoEm,
    int? tentativas,
    Value<String?> ultimoErro = const Value.absent(),
    String? status,
  }) => OperacaoPendenteLocalRegistro(
    id: id ?? this.id,
    entidade: entidade ?? this.entidade,
    entidadeId: entidadeId ?? this.entidadeId,
    tipoOperacao: tipoOperacao ?? this.tipoOperacao,
    payloadJson: payloadJson ?? this.payloadJson,
    criadoEm: criadoEm ?? this.criadoEm,
    tentativas: tentativas ?? this.tentativas,
    ultimoErro: ultimoErro.present ? ultimoErro.value : this.ultimoErro,
    status: status ?? this.status,
  );
  OperacaoPendenteLocalRegistro copyWithCompanion(
    OperacoesPendentesLocaisCompanion data,
  ) {
    return OperacaoPendenteLocalRegistro(
      id: data.id.present ? data.id.value : this.id,
      entidade: data.entidade.present ? data.entidade.value : this.entidade,
      entidadeId: data.entidadeId.present
          ? data.entidadeId.value
          : this.entidadeId,
      tipoOperacao: data.tipoOperacao.present
          ? data.tipoOperacao.value
          : this.tipoOperacao,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      criadoEm: data.criadoEm.present ? data.criadoEm.value : this.criadoEm,
      tentativas: data.tentativas.present
          ? data.tentativas.value
          : this.tentativas,
      ultimoErro: data.ultimoErro.present
          ? data.ultimoErro.value
          : this.ultimoErro,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OperacaoPendenteLocalRegistro(')
          ..write('id: $id, ')
          ..write('entidade: $entidade, ')
          ..write('entidadeId: $entidadeId, ')
          ..write('tipoOperacao: $tipoOperacao, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('criadoEm: $criadoEm, ')
          ..write('tentativas: $tentativas, ')
          ..write('ultimoErro: $ultimoErro, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entidade,
    entidadeId,
    tipoOperacao,
    payloadJson,
    criadoEm,
    tentativas,
    ultimoErro,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OperacaoPendenteLocalRegistro &&
          other.id == this.id &&
          other.entidade == this.entidade &&
          other.entidadeId == this.entidadeId &&
          other.tipoOperacao == this.tipoOperacao &&
          other.payloadJson == this.payloadJson &&
          other.criadoEm == this.criadoEm &&
          other.tentativas == this.tentativas &&
          other.ultimoErro == this.ultimoErro &&
          other.status == this.status);
}

class OperacoesPendentesLocaisCompanion
    extends UpdateCompanion<OperacaoPendenteLocalRegistro> {
  final Value<String> id;
  final Value<String> entidade;
  final Value<String> entidadeId;
  final Value<String> tipoOperacao;
  final Value<String> payloadJson;
  final Value<DateTime> criadoEm;
  final Value<int> tentativas;
  final Value<String?> ultimoErro;
  final Value<String> status;
  final Value<int> rowid;
  const OperacoesPendentesLocaisCompanion({
    this.id = const Value.absent(),
    this.entidade = const Value.absent(),
    this.entidadeId = const Value.absent(),
    this.tipoOperacao = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.criadoEm = const Value.absent(),
    this.tentativas = const Value.absent(),
    this.ultimoErro = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OperacoesPendentesLocaisCompanion.insert({
    required String id,
    required String entidade,
    required String entidadeId,
    required String tipoOperacao,
    required String payloadJson,
    required DateTime criadoEm,
    this.tentativas = const Value.absent(),
    this.ultimoErro = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       entidade = Value(entidade),
       entidadeId = Value(entidadeId),
       tipoOperacao = Value(tipoOperacao),
       payloadJson = Value(payloadJson),
       criadoEm = Value(criadoEm);
  static Insertable<OperacaoPendenteLocalRegistro> custom({
    Expression<String>? id,
    Expression<String>? entidade,
    Expression<String>? entidadeId,
    Expression<String>? tipoOperacao,
    Expression<String>? payloadJson,
    Expression<DateTime>? criadoEm,
    Expression<int>? tentativas,
    Expression<String>? ultimoErro,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entidade != null) 'entidade': entidade,
      if (entidadeId != null) 'entidade_id': entidadeId,
      if (tipoOperacao != null) 'tipo_operacao': tipoOperacao,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (criadoEm != null) 'criado_em': criadoEm,
      if (tentativas != null) 'tentativas': tentativas,
      if (ultimoErro != null) 'ultimo_erro': ultimoErro,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OperacoesPendentesLocaisCompanion copyWith({
    Value<String>? id,
    Value<String>? entidade,
    Value<String>? entidadeId,
    Value<String>? tipoOperacao,
    Value<String>? payloadJson,
    Value<DateTime>? criadoEm,
    Value<int>? tentativas,
    Value<String?>? ultimoErro,
    Value<String>? status,
    Value<int>? rowid,
  }) {
    return OperacoesPendentesLocaisCompanion(
      id: id ?? this.id,
      entidade: entidade ?? this.entidade,
      entidadeId: entidadeId ?? this.entidadeId,
      tipoOperacao: tipoOperacao ?? this.tipoOperacao,
      payloadJson: payloadJson ?? this.payloadJson,
      criadoEm: criadoEm ?? this.criadoEm,
      tentativas: tentativas ?? this.tentativas,
      ultimoErro: ultimoErro ?? this.ultimoErro,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (entidade.present) {
      map['entidade'] = Variable<String>(entidade.value);
    }
    if (entidadeId.present) {
      map['entidade_id'] = Variable<String>(entidadeId.value);
    }
    if (tipoOperacao.present) {
      map['tipo_operacao'] = Variable<String>(tipoOperacao.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (criadoEm.present) {
      map['criado_em'] = Variable<DateTime>(criadoEm.value);
    }
    if (tentativas.present) {
      map['tentativas'] = Variable<int>(tentativas.value);
    }
    if (ultimoErro.present) {
      map['ultimo_erro'] = Variable<String>(ultimoErro.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OperacoesPendentesLocaisCompanion(')
          ..write('id: $id, ')
          ..write('entidade: $entidade, ')
          ..write('entidadeId: $entidadeId, ')
          ..write('tipoOperacao: $tipoOperacao, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('criadoEm: $criadoEm, ')
          ..write('tentativas: $tentativas, ')
          ..write('ultimoErro: $ultimoErro, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConfiguracoesLocaisTable extends ConfiguracoesLocais
    with TableInfo<$ConfiguracoesLocaisTable, ConfiguracaoLocalRegistro> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConfiguracoesLocaisTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _chaveMeta = const VerificationMeta('chave');
  @override
  late final GeneratedColumn<String> chave = GeneratedColumn<String>(
    'chave',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valorMeta = const VerificationMeta('valor');
  @override
  late final GeneratedColumn<String> valor = GeneratedColumn<String>(
    'valor',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atualizadoEmMeta = const VerificationMeta(
    'atualizadoEm',
  );
  @override
  late final GeneratedColumn<DateTime> atualizadoEm = GeneratedColumn<DateTime>(
    'atualizado_em',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [chave, valor, atualizadoEm];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'configuracoes_locais';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConfiguracaoLocalRegistro> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('chave')) {
      context.handle(
        _chaveMeta,
        chave.isAcceptableOrUnknown(data['chave']!, _chaveMeta),
      );
    } else if (isInserting) {
      context.missing(_chaveMeta);
    }
    if (data.containsKey('valor')) {
      context.handle(
        _valorMeta,
        valor.isAcceptableOrUnknown(data['valor']!, _valorMeta),
      );
    } else if (isInserting) {
      context.missing(_valorMeta);
    }
    if (data.containsKey('atualizado_em')) {
      context.handle(
        _atualizadoEmMeta,
        atualizadoEm.isAcceptableOrUnknown(
          data['atualizado_em']!,
          _atualizadoEmMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_atualizadoEmMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {chave};
  @override
  ConfiguracaoLocalRegistro map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConfiguracaoLocalRegistro(
      chave: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chave'],
      )!,
      valor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}valor'],
      )!,
      atualizadoEm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}atualizado_em'],
      )!,
    );
  }

  @override
  $ConfiguracoesLocaisTable createAlias(String alias) {
    return $ConfiguracoesLocaisTable(attachedDatabase, alias);
  }
}

class ConfiguracaoLocalRegistro extends DataClass
    implements Insertable<ConfiguracaoLocalRegistro> {
  final String chave;
  final String valor;
  final DateTime atualizadoEm;
  const ConfiguracaoLocalRegistro({
    required this.chave,
    required this.valor,
    required this.atualizadoEm,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['chave'] = Variable<String>(chave);
    map['valor'] = Variable<String>(valor);
    map['atualizado_em'] = Variable<DateTime>(atualizadoEm);
    return map;
  }

  ConfiguracoesLocaisCompanion toCompanion(bool nullToAbsent) {
    return ConfiguracoesLocaisCompanion(
      chave: Value(chave),
      valor: Value(valor),
      atualizadoEm: Value(atualizadoEm),
    );
  }

  factory ConfiguracaoLocalRegistro.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConfiguracaoLocalRegistro(
      chave: serializer.fromJson<String>(json['chave']),
      valor: serializer.fromJson<String>(json['valor']),
      atualizadoEm: serializer.fromJson<DateTime>(json['atualizadoEm']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'chave': serializer.toJson<String>(chave),
      'valor': serializer.toJson<String>(valor),
      'atualizadoEm': serializer.toJson<DateTime>(atualizadoEm),
    };
  }

  ConfiguracaoLocalRegistro copyWith({
    String? chave,
    String? valor,
    DateTime? atualizadoEm,
  }) => ConfiguracaoLocalRegistro(
    chave: chave ?? this.chave,
    valor: valor ?? this.valor,
    atualizadoEm: atualizadoEm ?? this.atualizadoEm,
  );
  ConfiguracaoLocalRegistro copyWithCompanion(
    ConfiguracoesLocaisCompanion data,
  ) {
    return ConfiguracaoLocalRegistro(
      chave: data.chave.present ? data.chave.value : this.chave,
      valor: data.valor.present ? data.valor.value : this.valor,
      atualizadoEm: data.atualizadoEm.present
          ? data.atualizadoEm.value
          : this.atualizadoEm,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConfiguracaoLocalRegistro(')
          ..write('chave: $chave, ')
          ..write('valor: $valor, ')
          ..write('atualizadoEm: $atualizadoEm')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(chave, valor, atualizadoEm);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConfiguracaoLocalRegistro &&
          other.chave == this.chave &&
          other.valor == this.valor &&
          other.atualizadoEm == this.atualizadoEm);
}

class ConfiguracoesLocaisCompanion
    extends UpdateCompanion<ConfiguracaoLocalRegistro> {
  final Value<String> chave;
  final Value<String> valor;
  final Value<DateTime> atualizadoEm;
  final Value<int> rowid;
  const ConfiguracoesLocaisCompanion({
    this.chave = const Value.absent(),
    this.valor = const Value.absent(),
    this.atualizadoEm = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConfiguracoesLocaisCompanion.insert({
    required String chave,
    required String valor,
    required DateTime atualizadoEm,
    this.rowid = const Value.absent(),
  }) : chave = Value(chave),
       valor = Value(valor),
       atualizadoEm = Value(atualizadoEm);
  static Insertable<ConfiguracaoLocalRegistro> custom({
    Expression<String>? chave,
    Expression<String>? valor,
    Expression<DateTime>? atualizadoEm,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (chave != null) 'chave': chave,
      if (valor != null) 'valor': valor,
      if (atualizadoEm != null) 'atualizado_em': atualizadoEm,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConfiguracoesLocaisCompanion copyWith({
    Value<String>? chave,
    Value<String>? valor,
    Value<DateTime>? atualizadoEm,
    Value<int>? rowid,
  }) {
    return ConfiguracoesLocaisCompanion(
      chave: chave ?? this.chave,
      valor: valor ?? this.valor,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (chave.present) {
      map['chave'] = Variable<String>(chave.value);
    }
    if (valor.present) {
      map['valor'] = Variable<String>(valor.value);
    }
    if (atualizadoEm.present) {
      map['atualizado_em'] = Variable<DateTime>(atualizadoEm.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConfiguracoesLocaisCompanion(')
          ..write('chave: $chave, ')
          ..write('valor: $valor, ')
          ..write('atualizadoEm: $atualizadoEm, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SincronizacoesLocaisTable extends SincronizacoesLocais
    with TableInfo<$SincronizacoesLocaisTable, SincronizacaoLocalRegistro> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SincronizacoesLocaisTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _recursoMeta = const VerificationMeta(
    'recurso',
  );
  @override
  late final GeneratedColumn<String> recurso = GeneratedColumn<String>(
    'recurso',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ultimaSincronizacaoMeta =
      const VerificationMeta('ultimaSincronizacao');
  @override
  late final GeneratedColumn<DateTime> ultimaSincronizacao =
      GeneratedColumn<DateTime>(
        'ultima_sincronizacao',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _cursorServidorMeta = const VerificationMeta(
    'cursorServidor',
  );
  @override
  late final GeneratedColumn<String> cursorServidor = GeneratedColumn<String>(
    'cursor_servidor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _emAndamentoMeta = const VerificationMeta(
    'emAndamento',
  );
  @override
  late final GeneratedColumn<bool> emAndamento = GeneratedColumn<bool>(
    'em_andamento',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("em_andamento" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _ultimoErroMeta = const VerificationMeta(
    'ultimoErro',
  );
  @override
  late final GeneratedColumn<String> ultimoErro = GeneratedColumn<String>(
    'ultimo_erro',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    recurso,
    ultimaSincronizacao,
    cursorServidor,
    emAndamento,
    ultimoErro,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sincronizacoes_locais';
  @override
  VerificationContext validateIntegrity(
    Insertable<SincronizacaoLocalRegistro> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('recurso')) {
      context.handle(
        _recursoMeta,
        recurso.isAcceptableOrUnknown(data['recurso']!, _recursoMeta),
      );
    } else if (isInserting) {
      context.missing(_recursoMeta);
    }
    if (data.containsKey('ultima_sincronizacao')) {
      context.handle(
        _ultimaSincronizacaoMeta,
        ultimaSincronizacao.isAcceptableOrUnknown(
          data['ultima_sincronizacao']!,
          _ultimaSincronizacaoMeta,
        ),
      );
    }
    if (data.containsKey('cursor_servidor')) {
      context.handle(
        _cursorServidorMeta,
        cursorServidor.isAcceptableOrUnknown(
          data['cursor_servidor']!,
          _cursorServidorMeta,
        ),
      );
    }
    if (data.containsKey('em_andamento')) {
      context.handle(
        _emAndamentoMeta,
        emAndamento.isAcceptableOrUnknown(
          data['em_andamento']!,
          _emAndamentoMeta,
        ),
      );
    }
    if (data.containsKey('ultimo_erro')) {
      context.handle(
        _ultimoErroMeta,
        ultimoErro.isAcceptableOrUnknown(data['ultimo_erro']!, _ultimoErroMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {recurso};
  @override
  SincronizacaoLocalRegistro map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SincronizacaoLocalRegistro(
      recurso: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurso'],
      )!,
      ultimaSincronizacao: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ultima_sincronizacao'],
      ),
      cursorServidor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cursor_servidor'],
      ),
      emAndamento: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}em_andamento'],
      )!,
      ultimoErro: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ultimo_erro'],
      ),
    );
  }

  @override
  $SincronizacoesLocaisTable createAlias(String alias) {
    return $SincronizacoesLocaisTable(attachedDatabase, alias);
  }
}

class SincronizacaoLocalRegistro extends DataClass
    implements Insertable<SincronizacaoLocalRegistro> {
  final String recurso;
  final DateTime? ultimaSincronizacao;
  final String? cursorServidor;
  final bool emAndamento;
  final String? ultimoErro;
  const SincronizacaoLocalRegistro({
    required this.recurso,
    this.ultimaSincronizacao,
    this.cursorServidor,
    required this.emAndamento,
    this.ultimoErro,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['recurso'] = Variable<String>(recurso);
    if (!nullToAbsent || ultimaSincronizacao != null) {
      map['ultima_sincronizacao'] = Variable<DateTime>(ultimaSincronizacao);
    }
    if (!nullToAbsent || cursorServidor != null) {
      map['cursor_servidor'] = Variable<String>(cursorServidor);
    }
    map['em_andamento'] = Variable<bool>(emAndamento);
    if (!nullToAbsent || ultimoErro != null) {
      map['ultimo_erro'] = Variable<String>(ultimoErro);
    }
    return map;
  }

  SincronizacoesLocaisCompanion toCompanion(bool nullToAbsent) {
    return SincronizacoesLocaisCompanion(
      recurso: Value(recurso),
      ultimaSincronizacao: ultimaSincronizacao == null && nullToAbsent
          ? const Value.absent()
          : Value(ultimaSincronizacao),
      cursorServidor: cursorServidor == null && nullToAbsent
          ? const Value.absent()
          : Value(cursorServidor),
      emAndamento: Value(emAndamento),
      ultimoErro: ultimoErro == null && nullToAbsent
          ? const Value.absent()
          : Value(ultimoErro),
    );
  }

  factory SincronizacaoLocalRegistro.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SincronizacaoLocalRegistro(
      recurso: serializer.fromJson<String>(json['recurso']),
      ultimaSincronizacao: serializer.fromJson<DateTime?>(
        json['ultimaSincronizacao'],
      ),
      cursorServidor: serializer.fromJson<String?>(json['cursorServidor']),
      emAndamento: serializer.fromJson<bool>(json['emAndamento']),
      ultimoErro: serializer.fromJson<String?>(json['ultimoErro']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'recurso': serializer.toJson<String>(recurso),
      'ultimaSincronizacao': serializer.toJson<DateTime?>(ultimaSincronizacao),
      'cursorServidor': serializer.toJson<String?>(cursorServidor),
      'emAndamento': serializer.toJson<bool>(emAndamento),
      'ultimoErro': serializer.toJson<String?>(ultimoErro),
    };
  }

  SincronizacaoLocalRegistro copyWith({
    String? recurso,
    Value<DateTime?> ultimaSincronizacao = const Value.absent(),
    Value<String?> cursorServidor = const Value.absent(),
    bool? emAndamento,
    Value<String?> ultimoErro = const Value.absent(),
  }) => SincronizacaoLocalRegistro(
    recurso: recurso ?? this.recurso,
    ultimaSincronizacao: ultimaSincronizacao.present
        ? ultimaSincronizacao.value
        : this.ultimaSincronizacao,
    cursorServidor: cursorServidor.present
        ? cursorServidor.value
        : this.cursorServidor,
    emAndamento: emAndamento ?? this.emAndamento,
    ultimoErro: ultimoErro.present ? ultimoErro.value : this.ultimoErro,
  );
  SincronizacaoLocalRegistro copyWithCompanion(
    SincronizacoesLocaisCompanion data,
  ) {
    return SincronizacaoLocalRegistro(
      recurso: data.recurso.present ? data.recurso.value : this.recurso,
      ultimaSincronizacao: data.ultimaSincronizacao.present
          ? data.ultimaSincronizacao.value
          : this.ultimaSincronizacao,
      cursorServidor: data.cursorServidor.present
          ? data.cursorServidor.value
          : this.cursorServidor,
      emAndamento: data.emAndamento.present
          ? data.emAndamento.value
          : this.emAndamento,
      ultimoErro: data.ultimoErro.present
          ? data.ultimoErro.value
          : this.ultimoErro,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SincronizacaoLocalRegistro(')
          ..write('recurso: $recurso, ')
          ..write('ultimaSincronizacao: $ultimaSincronizacao, ')
          ..write('cursorServidor: $cursorServidor, ')
          ..write('emAndamento: $emAndamento, ')
          ..write('ultimoErro: $ultimoErro')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    recurso,
    ultimaSincronizacao,
    cursorServidor,
    emAndamento,
    ultimoErro,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SincronizacaoLocalRegistro &&
          other.recurso == this.recurso &&
          other.ultimaSincronizacao == this.ultimaSincronizacao &&
          other.cursorServidor == this.cursorServidor &&
          other.emAndamento == this.emAndamento &&
          other.ultimoErro == this.ultimoErro);
}

class SincronizacoesLocaisCompanion
    extends UpdateCompanion<SincronizacaoLocalRegistro> {
  final Value<String> recurso;
  final Value<DateTime?> ultimaSincronizacao;
  final Value<String?> cursorServidor;
  final Value<bool> emAndamento;
  final Value<String?> ultimoErro;
  final Value<int> rowid;
  const SincronizacoesLocaisCompanion({
    this.recurso = const Value.absent(),
    this.ultimaSincronizacao = const Value.absent(),
    this.cursorServidor = const Value.absent(),
    this.emAndamento = const Value.absent(),
    this.ultimoErro = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SincronizacoesLocaisCompanion.insert({
    required String recurso,
    this.ultimaSincronizacao = const Value.absent(),
    this.cursorServidor = const Value.absent(),
    this.emAndamento = const Value.absent(),
    this.ultimoErro = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : recurso = Value(recurso);
  static Insertable<SincronizacaoLocalRegistro> custom({
    Expression<String>? recurso,
    Expression<DateTime>? ultimaSincronizacao,
    Expression<String>? cursorServidor,
    Expression<bool>? emAndamento,
    Expression<String>? ultimoErro,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (recurso != null) 'recurso': recurso,
      if (ultimaSincronizacao != null)
        'ultima_sincronizacao': ultimaSincronizacao,
      if (cursorServidor != null) 'cursor_servidor': cursorServidor,
      if (emAndamento != null) 'em_andamento': emAndamento,
      if (ultimoErro != null) 'ultimo_erro': ultimoErro,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SincronizacoesLocaisCompanion copyWith({
    Value<String>? recurso,
    Value<DateTime?>? ultimaSincronizacao,
    Value<String?>? cursorServidor,
    Value<bool>? emAndamento,
    Value<String?>? ultimoErro,
    Value<int>? rowid,
  }) {
    return SincronizacoesLocaisCompanion(
      recurso: recurso ?? this.recurso,
      ultimaSincronizacao: ultimaSincronizacao ?? this.ultimaSincronizacao,
      cursorServidor: cursorServidor ?? this.cursorServidor,
      emAndamento: emAndamento ?? this.emAndamento,
      ultimoErro: ultimoErro ?? this.ultimoErro,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (recurso.present) {
      map['recurso'] = Variable<String>(recurso.value);
    }
    if (ultimaSincronizacao.present) {
      map['ultima_sincronizacao'] = Variable<DateTime>(
        ultimaSincronizacao.value,
      );
    }
    if (cursorServidor.present) {
      map['cursor_servidor'] = Variable<String>(cursorServidor.value);
    }
    if (emAndamento.present) {
      map['em_andamento'] = Variable<bool>(emAndamento.value);
    }
    if (ultimoErro.present) {
      map['ultimo_erro'] = Variable<String>(ultimoErro.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SincronizacoesLocaisCompanion(')
          ..write('recurso: $recurso, ')
          ..write('ultimaSincronizacao: $ultimaSincronizacao, ')
          ..write('cursorServidor: $cursorServidor, ')
          ..write('emAndamento: $emAndamento, ')
          ..write('ultimoErro: $ultimoErro, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$BancoLocal extends GeneratedDatabase {
  _$BancoLocal(QueryExecutor e) : super(e);
  $BancoLocalManager get managers => $BancoLocalManager(this);
  late final $MesasLocaisTable mesasLocais = $MesasLocaisTable(this);
  late final $ConvidadosLocaisTable convidadosLocais = $ConvidadosLocaisTable(
    this,
  );
  late final $UsuariosAppLocaisTable usuariosAppLocais =
      $UsuariosAppLocaisTable(this);
  late final $StaffsLocaisTable staffsLocais = $StaffsLocaisTable(this);
  late final $MensagensChatLocaisTable mensagensChatLocais =
      $MensagensChatLocaisTable(this);
  late final $EventosCheckinLocaisTable eventosCheckinLocais =
      $EventosCheckinLocaisTable(this);
  late final $OperacoesPendentesLocaisTable operacoesPendentesLocais =
      $OperacoesPendentesLocaisTable(this);
  late final $ConfiguracoesLocaisTable configuracoesLocais =
      $ConfiguracoesLocaisTable(this);
  late final $SincronizacoesLocaisTable sincronizacoesLocais =
      $SincronizacoesLocaisTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    mesasLocais,
    convidadosLocais,
    usuariosAppLocais,
    staffsLocais,
    mensagensChatLocais,
    eventosCheckinLocais,
    operacoesPendentesLocais,
    configuracoesLocais,
    sincronizacoesLocais,
  ];
}

typedef $$MesasLocaisTableCreateCompanionBuilder =
    MesasLocaisCompanion Function({
      required String id,
      Value<int> numero,
      Value<String?> detalhe,
      required DateTime criadoEm,
      required DateTime atualizadoEm,
      Value<bool> excluido,
      Value<int> rowid,
    });
typedef $$MesasLocaisTableUpdateCompanionBuilder =
    MesasLocaisCompanion Function({
      Value<String> id,
      Value<int> numero,
      Value<String?> detalhe,
      Value<DateTime> criadoEm,
      Value<DateTime> atualizadoEm,
      Value<bool> excluido,
      Value<int> rowid,
    });

class $$MesasLocaisTableFilterComposer
    extends Composer<_$BancoLocal, $MesasLocaisTable> {
  $$MesasLocaisTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get numero => $composableBuilder(
    column: $table.numero,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detalhe => $composableBuilder(
    column: $table.detalhe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get criadoEm => $composableBuilder(
    column: $table.criadoEm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get excluido => $composableBuilder(
    column: $table.excluido,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MesasLocaisTableOrderingComposer
    extends Composer<_$BancoLocal, $MesasLocaisTable> {
  $$MesasLocaisTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get numero => $composableBuilder(
    column: $table.numero,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detalhe => $composableBuilder(
    column: $table.detalhe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get criadoEm => $composableBuilder(
    column: $table.criadoEm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get excluido => $composableBuilder(
    column: $table.excluido,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MesasLocaisTableAnnotationComposer
    extends Composer<_$BancoLocal, $MesasLocaisTable> {
  $$MesasLocaisTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get numero =>
      $composableBuilder(column: $table.numero, builder: (column) => column);

  GeneratedColumn<String> get detalhe =>
      $composableBuilder(column: $table.detalhe, builder: (column) => column);

  GeneratedColumn<DateTime> get criadoEm =>
      $composableBuilder(column: $table.criadoEm, builder: (column) => column);

  GeneratedColumn<DateTime> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get excluido =>
      $composableBuilder(column: $table.excluido, builder: (column) => column);
}

class $$MesasLocaisTableTableManager
    extends
        RootTableManager<
          _$BancoLocal,
          $MesasLocaisTable,
          MesaLocalRegistro,
          $$MesasLocaisTableFilterComposer,
          $$MesasLocaisTableOrderingComposer,
          $$MesasLocaisTableAnnotationComposer,
          $$MesasLocaisTableCreateCompanionBuilder,
          $$MesasLocaisTableUpdateCompanionBuilder,
          (
            MesaLocalRegistro,
            BaseReferences<_$BancoLocal, $MesasLocaisTable, MesaLocalRegistro>,
          ),
          MesaLocalRegistro,
          PrefetchHooks Function()
        > {
  $$MesasLocaisTableTableManager(_$BancoLocal db, $MesasLocaisTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MesasLocaisTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MesasLocaisTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MesasLocaisTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> numero = const Value.absent(),
                Value<String?> detalhe = const Value.absent(),
                Value<DateTime> criadoEm = const Value.absent(),
                Value<DateTime> atualizadoEm = const Value.absent(),
                Value<bool> excluido = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MesasLocaisCompanion(
                id: id,
                numero: numero,
                detalhe: detalhe,
                criadoEm: criadoEm,
                atualizadoEm: atualizadoEm,
                excluido: excluido,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<int> numero = const Value.absent(),
                Value<String?> detalhe = const Value.absent(),
                required DateTime criadoEm,
                required DateTime atualizadoEm,
                Value<bool> excluido = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MesasLocaisCompanion.insert(
                id: id,
                numero: numero,
                detalhe: detalhe,
                criadoEm: criadoEm,
                atualizadoEm: atualizadoEm,
                excluido: excluido,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MesasLocaisTableProcessedTableManager =
    ProcessedTableManager<
      _$BancoLocal,
      $MesasLocaisTable,
      MesaLocalRegistro,
      $$MesasLocaisTableFilterComposer,
      $$MesasLocaisTableOrderingComposer,
      $$MesasLocaisTableAnnotationComposer,
      $$MesasLocaisTableCreateCompanionBuilder,
      $$MesasLocaisTableUpdateCompanionBuilder,
      (
        MesaLocalRegistro,
        BaseReferences<_$BancoLocal, $MesasLocaisTable, MesaLocalRegistro>,
      ),
      MesaLocalRegistro,
      PrefetchHooks Function()
    >;
typedef $$ConvidadosLocaisTableCreateCompanionBuilder =
    ConvidadosLocaisCompanion Function({
      required String id,
      required String nome,
      Value<String?> mesaId,
      Value<bool> chegou,
      Value<bool> temConflito,
      Value<String> eventosAtuaisJson,
      required DateTime criadoEm,
      required DateTime atualizadoEm,
      Value<bool> excluido,
      Value<int> rowid,
    });
typedef $$ConvidadosLocaisTableUpdateCompanionBuilder =
    ConvidadosLocaisCompanion Function({
      Value<String> id,
      Value<String> nome,
      Value<String?> mesaId,
      Value<bool> chegou,
      Value<bool> temConflito,
      Value<String> eventosAtuaisJson,
      Value<DateTime> criadoEm,
      Value<DateTime> atualizadoEm,
      Value<bool> excluido,
      Value<int> rowid,
    });

class $$ConvidadosLocaisTableFilterComposer
    extends Composer<_$BancoLocal, $ConvidadosLocaisTable> {
  $$ConvidadosLocaisTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nome => $composableBuilder(
    column: $table.nome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mesaId => $composableBuilder(
    column: $table.mesaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get chegou => $composableBuilder(
    column: $table.chegou,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get temConflito => $composableBuilder(
    column: $table.temConflito,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventosAtuaisJson => $composableBuilder(
    column: $table.eventosAtuaisJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get criadoEm => $composableBuilder(
    column: $table.criadoEm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get excluido => $composableBuilder(
    column: $table.excluido,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConvidadosLocaisTableOrderingComposer
    extends Composer<_$BancoLocal, $ConvidadosLocaisTable> {
  $$ConvidadosLocaisTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nome => $composableBuilder(
    column: $table.nome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mesaId => $composableBuilder(
    column: $table.mesaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get chegou => $composableBuilder(
    column: $table.chegou,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get temConflito => $composableBuilder(
    column: $table.temConflito,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventosAtuaisJson => $composableBuilder(
    column: $table.eventosAtuaisJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get criadoEm => $composableBuilder(
    column: $table.criadoEm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get excluido => $composableBuilder(
    column: $table.excluido,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConvidadosLocaisTableAnnotationComposer
    extends Composer<_$BancoLocal, $ConvidadosLocaisTable> {
  $$ConvidadosLocaisTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nome =>
      $composableBuilder(column: $table.nome, builder: (column) => column);

  GeneratedColumn<String> get mesaId =>
      $composableBuilder(column: $table.mesaId, builder: (column) => column);

  GeneratedColumn<bool> get chegou =>
      $composableBuilder(column: $table.chegou, builder: (column) => column);

  GeneratedColumn<bool> get temConflito => $composableBuilder(
    column: $table.temConflito,
    builder: (column) => column,
  );

  GeneratedColumn<String> get eventosAtuaisJson => $composableBuilder(
    column: $table.eventosAtuaisJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get criadoEm =>
      $composableBuilder(column: $table.criadoEm, builder: (column) => column);

  GeneratedColumn<DateTime> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get excluido =>
      $composableBuilder(column: $table.excluido, builder: (column) => column);
}

class $$ConvidadosLocaisTableTableManager
    extends
        RootTableManager<
          _$BancoLocal,
          $ConvidadosLocaisTable,
          ConvidadoLocalRegistro,
          $$ConvidadosLocaisTableFilterComposer,
          $$ConvidadosLocaisTableOrderingComposer,
          $$ConvidadosLocaisTableAnnotationComposer,
          $$ConvidadosLocaisTableCreateCompanionBuilder,
          $$ConvidadosLocaisTableUpdateCompanionBuilder,
          (
            ConvidadoLocalRegistro,
            BaseReferences<
              _$BancoLocal,
              $ConvidadosLocaisTable,
              ConvidadoLocalRegistro
            >,
          ),
          ConvidadoLocalRegistro,
          PrefetchHooks Function()
        > {
  $$ConvidadosLocaisTableTableManager(
    _$BancoLocal db,
    $ConvidadosLocaisTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConvidadosLocaisTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConvidadosLocaisTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConvidadosLocaisTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> nome = const Value.absent(),
                Value<String?> mesaId = const Value.absent(),
                Value<bool> chegou = const Value.absent(),
                Value<bool> temConflito = const Value.absent(),
                Value<String> eventosAtuaisJson = const Value.absent(),
                Value<DateTime> criadoEm = const Value.absent(),
                Value<DateTime> atualizadoEm = const Value.absent(),
                Value<bool> excluido = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConvidadosLocaisCompanion(
                id: id,
                nome: nome,
                mesaId: mesaId,
                chegou: chegou,
                temConflito: temConflito,
                eventosAtuaisJson: eventosAtuaisJson,
                criadoEm: criadoEm,
                atualizadoEm: atualizadoEm,
                excluido: excluido,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String nome,
                Value<String?> mesaId = const Value.absent(),
                Value<bool> chegou = const Value.absent(),
                Value<bool> temConflito = const Value.absent(),
                Value<String> eventosAtuaisJson = const Value.absent(),
                required DateTime criadoEm,
                required DateTime atualizadoEm,
                Value<bool> excluido = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConvidadosLocaisCompanion.insert(
                id: id,
                nome: nome,
                mesaId: mesaId,
                chegou: chegou,
                temConflito: temConflito,
                eventosAtuaisJson: eventosAtuaisJson,
                criadoEm: criadoEm,
                atualizadoEm: atualizadoEm,
                excluido: excluido,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConvidadosLocaisTableProcessedTableManager =
    ProcessedTableManager<
      _$BancoLocal,
      $ConvidadosLocaisTable,
      ConvidadoLocalRegistro,
      $$ConvidadosLocaisTableFilterComposer,
      $$ConvidadosLocaisTableOrderingComposer,
      $$ConvidadosLocaisTableAnnotationComposer,
      $$ConvidadosLocaisTableCreateCompanionBuilder,
      $$ConvidadosLocaisTableUpdateCompanionBuilder,
      (
        ConvidadoLocalRegistro,
        BaseReferences<
          _$BancoLocal,
          $ConvidadosLocaisTable,
          ConvidadoLocalRegistro
        >,
      ),
      ConvidadoLocalRegistro,
      PrefetchHooks Function()
    >;
typedef $$UsuariosAppLocaisTableCreateCompanionBuilder =
    UsuariosAppLocaisCompanion Function({
      required String id,
      required String nome,
      Value<int> ordem,
      Value<bool> ativo,
      required DateTime criadoEm,
      Value<int> rowid,
    });
typedef $$UsuariosAppLocaisTableUpdateCompanionBuilder =
    UsuariosAppLocaisCompanion Function({
      Value<String> id,
      Value<String> nome,
      Value<int> ordem,
      Value<bool> ativo,
      Value<DateTime> criadoEm,
      Value<int> rowid,
    });

class $$UsuariosAppLocaisTableFilterComposer
    extends Composer<_$BancoLocal, $UsuariosAppLocaisTable> {
  $$UsuariosAppLocaisTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nome => $composableBuilder(
    column: $table.nome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ordem => $composableBuilder(
    column: $table.ordem,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get ativo => $composableBuilder(
    column: $table.ativo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get criadoEm => $composableBuilder(
    column: $table.criadoEm,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UsuariosAppLocaisTableOrderingComposer
    extends Composer<_$BancoLocal, $UsuariosAppLocaisTable> {
  $$UsuariosAppLocaisTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nome => $composableBuilder(
    column: $table.nome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ordem => $composableBuilder(
    column: $table.ordem,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get ativo => $composableBuilder(
    column: $table.ativo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get criadoEm => $composableBuilder(
    column: $table.criadoEm,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsuariosAppLocaisTableAnnotationComposer
    extends Composer<_$BancoLocal, $UsuariosAppLocaisTable> {
  $$UsuariosAppLocaisTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nome =>
      $composableBuilder(column: $table.nome, builder: (column) => column);

  GeneratedColumn<int> get ordem =>
      $composableBuilder(column: $table.ordem, builder: (column) => column);

  GeneratedColumn<bool> get ativo =>
      $composableBuilder(column: $table.ativo, builder: (column) => column);

  GeneratedColumn<DateTime> get criadoEm =>
      $composableBuilder(column: $table.criadoEm, builder: (column) => column);
}

class $$UsuariosAppLocaisTableTableManager
    extends
        RootTableManager<
          _$BancoLocal,
          $UsuariosAppLocaisTable,
          UsuarioAppLocalRegistro,
          $$UsuariosAppLocaisTableFilterComposer,
          $$UsuariosAppLocaisTableOrderingComposer,
          $$UsuariosAppLocaisTableAnnotationComposer,
          $$UsuariosAppLocaisTableCreateCompanionBuilder,
          $$UsuariosAppLocaisTableUpdateCompanionBuilder,
          (
            UsuarioAppLocalRegistro,
            BaseReferences<
              _$BancoLocal,
              $UsuariosAppLocaisTable,
              UsuarioAppLocalRegistro
            >,
          ),
          UsuarioAppLocalRegistro,
          PrefetchHooks Function()
        > {
  $$UsuariosAppLocaisTableTableManager(
    _$BancoLocal db,
    $UsuariosAppLocaisTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsuariosAppLocaisTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsuariosAppLocaisTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsuariosAppLocaisTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> nome = const Value.absent(),
                Value<int> ordem = const Value.absent(),
                Value<bool> ativo = const Value.absent(),
                Value<DateTime> criadoEm = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UsuariosAppLocaisCompanion(
                id: id,
                nome: nome,
                ordem: ordem,
                ativo: ativo,
                criadoEm: criadoEm,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String nome,
                Value<int> ordem = const Value.absent(),
                Value<bool> ativo = const Value.absent(),
                required DateTime criadoEm,
                Value<int> rowid = const Value.absent(),
              }) => UsuariosAppLocaisCompanion.insert(
                id: id,
                nome: nome,
                ordem: ordem,
                ativo: ativo,
                criadoEm: criadoEm,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UsuariosAppLocaisTableProcessedTableManager =
    ProcessedTableManager<
      _$BancoLocal,
      $UsuariosAppLocaisTable,
      UsuarioAppLocalRegistro,
      $$UsuariosAppLocaisTableFilterComposer,
      $$UsuariosAppLocaisTableOrderingComposer,
      $$UsuariosAppLocaisTableAnnotationComposer,
      $$UsuariosAppLocaisTableCreateCompanionBuilder,
      $$UsuariosAppLocaisTableUpdateCompanionBuilder,
      (
        UsuarioAppLocalRegistro,
        BaseReferences<
          _$BancoLocal,
          $UsuariosAppLocaisTable,
          UsuarioAppLocalRegistro
        >,
      ),
      UsuarioAppLocalRegistro,
      PrefetchHooks Function()
    >;
typedef $$StaffsLocaisTableCreateCompanionBuilder =
    StaffsLocaisCompanion Function({
      required String id,
      required String nome,
      required String sobrenome,
      required String ocupacao,
      required DateTime criadoEm,
      required DateTime atualizadoEm,
      Value<bool> excluido,
      Value<int> rowid,
    });
typedef $$StaffsLocaisTableUpdateCompanionBuilder =
    StaffsLocaisCompanion Function({
      Value<String> id,
      Value<String> nome,
      Value<String> sobrenome,
      Value<String> ocupacao,
      Value<DateTime> criadoEm,
      Value<DateTime> atualizadoEm,
      Value<bool> excluido,
      Value<int> rowid,
    });

class $$StaffsLocaisTableFilterComposer
    extends Composer<_$BancoLocal, $StaffsLocaisTable> {
  $$StaffsLocaisTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nome => $composableBuilder(
    column: $table.nome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sobrenome => $composableBuilder(
    column: $table.sobrenome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ocupacao => $composableBuilder(
    column: $table.ocupacao,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get criadoEm => $composableBuilder(
    column: $table.criadoEm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get excluido => $composableBuilder(
    column: $table.excluido,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StaffsLocaisTableOrderingComposer
    extends Composer<_$BancoLocal, $StaffsLocaisTable> {
  $$StaffsLocaisTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nome => $composableBuilder(
    column: $table.nome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sobrenome => $composableBuilder(
    column: $table.sobrenome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ocupacao => $composableBuilder(
    column: $table.ocupacao,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get criadoEm => $composableBuilder(
    column: $table.criadoEm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get excluido => $composableBuilder(
    column: $table.excluido,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StaffsLocaisTableAnnotationComposer
    extends Composer<_$BancoLocal, $StaffsLocaisTable> {
  $$StaffsLocaisTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nome =>
      $composableBuilder(column: $table.nome, builder: (column) => column);

  GeneratedColumn<String> get sobrenome =>
      $composableBuilder(column: $table.sobrenome, builder: (column) => column);

  GeneratedColumn<String> get ocupacao =>
      $composableBuilder(column: $table.ocupacao, builder: (column) => column);

  GeneratedColumn<DateTime> get criadoEm =>
      $composableBuilder(column: $table.criadoEm, builder: (column) => column);

  GeneratedColumn<DateTime> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get excluido =>
      $composableBuilder(column: $table.excluido, builder: (column) => column);
}

class $$StaffsLocaisTableTableManager
    extends
        RootTableManager<
          _$BancoLocal,
          $StaffsLocaisTable,
          StaffLocalRegistro,
          $$StaffsLocaisTableFilterComposer,
          $$StaffsLocaisTableOrderingComposer,
          $$StaffsLocaisTableAnnotationComposer,
          $$StaffsLocaisTableCreateCompanionBuilder,
          $$StaffsLocaisTableUpdateCompanionBuilder,
          (
            StaffLocalRegistro,
            BaseReferences<
              _$BancoLocal,
              $StaffsLocaisTable,
              StaffLocalRegistro
            >,
          ),
          StaffLocalRegistro,
          PrefetchHooks Function()
        > {
  $$StaffsLocaisTableTableManager(_$BancoLocal db, $StaffsLocaisTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StaffsLocaisTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StaffsLocaisTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StaffsLocaisTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> nome = const Value.absent(),
                Value<String> sobrenome = const Value.absent(),
                Value<String> ocupacao = const Value.absent(),
                Value<DateTime> criadoEm = const Value.absent(),
                Value<DateTime> atualizadoEm = const Value.absent(),
                Value<bool> excluido = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StaffsLocaisCompanion(
                id: id,
                nome: nome,
                sobrenome: sobrenome,
                ocupacao: ocupacao,
                criadoEm: criadoEm,
                atualizadoEm: atualizadoEm,
                excluido: excluido,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String nome,
                required String sobrenome,
                required String ocupacao,
                required DateTime criadoEm,
                required DateTime atualizadoEm,
                Value<bool> excluido = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StaffsLocaisCompanion.insert(
                id: id,
                nome: nome,
                sobrenome: sobrenome,
                ocupacao: ocupacao,
                criadoEm: criadoEm,
                atualizadoEm: atualizadoEm,
                excluido: excluido,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StaffsLocaisTableProcessedTableManager =
    ProcessedTableManager<
      _$BancoLocal,
      $StaffsLocaisTable,
      StaffLocalRegistro,
      $$StaffsLocaisTableFilterComposer,
      $$StaffsLocaisTableOrderingComposer,
      $$StaffsLocaisTableAnnotationComposer,
      $$StaffsLocaisTableCreateCompanionBuilder,
      $$StaffsLocaisTableUpdateCompanionBuilder,
      (
        StaffLocalRegistro,
        BaseReferences<_$BancoLocal, $StaffsLocaisTable, StaffLocalRegistro>,
      ),
      StaffLocalRegistro,
      PrefetchHooks Function()
    >;
typedef $$MensagensChatLocaisTableCreateCompanionBuilder =
    MensagensChatLocaisCompanion Function({
      required String id,
      required String staffId,
      required String mensagem,
      required DateTime criadoEm,
      Value<DateTime?> dataServidor,
      Value<bool> excluido,
      Value<int> rowid,
    });
typedef $$MensagensChatLocaisTableUpdateCompanionBuilder =
    MensagensChatLocaisCompanion Function({
      Value<String> id,
      Value<String> staffId,
      Value<String> mensagem,
      Value<DateTime> criadoEm,
      Value<DateTime?> dataServidor,
      Value<bool> excluido,
      Value<int> rowid,
    });

class $$MensagensChatLocaisTableFilterComposer
    extends Composer<_$BancoLocal, $MensagensChatLocaisTable> {
  $$MensagensChatLocaisTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get staffId => $composableBuilder(
    column: $table.staffId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mensagem => $composableBuilder(
    column: $table.mensagem,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get criadoEm => $composableBuilder(
    column: $table.criadoEm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dataServidor => $composableBuilder(
    column: $table.dataServidor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get excluido => $composableBuilder(
    column: $table.excluido,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MensagensChatLocaisTableOrderingComposer
    extends Composer<_$BancoLocal, $MensagensChatLocaisTable> {
  $$MensagensChatLocaisTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get staffId => $composableBuilder(
    column: $table.staffId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mensagem => $composableBuilder(
    column: $table.mensagem,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get criadoEm => $composableBuilder(
    column: $table.criadoEm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dataServidor => $composableBuilder(
    column: $table.dataServidor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get excluido => $composableBuilder(
    column: $table.excluido,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MensagensChatLocaisTableAnnotationComposer
    extends Composer<_$BancoLocal, $MensagensChatLocaisTable> {
  $$MensagensChatLocaisTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get staffId =>
      $composableBuilder(column: $table.staffId, builder: (column) => column);

  GeneratedColumn<String> get mensagem =>
      $composableBuilder(column: $table.mensagem, builder: (column) => column);

  GeneratedColumn<DateTime> get criadoEm =>
      $composableBuilder(column: $table.criadoEm, builder: (column) => column);

  GeneratedColumn<DateTime> get dataServidor => $composableBuilder(
    column: $table.dataServidor,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get excluido =>
      $composableBuilder(column: $table.excluido, builder: (column) => column);
}

class $$MensagensChatLocaisTableTableManager
    extends
        RootTableManager<
          _$BancoLocal,
          $MensagensChatLocaisTable,
          MensagemChatLocalRegistro,
          $$MensagensChatLocaisTableFilterComposer,
          $$MensagensChatLocaisTableOrderingComposer,
          $$MensagensChatLocaisTableAnnotationComposer,
          $$MensagensChatLocaisTableCreateCompanionBuilder,
          $$MensagensChatLocaisTableUpdateCompanionBuilder,
          (
            MensagemChatLocalRegistro,
            BaseReferences<
              _$BancoLocal,
              $MensagensChatLocaisTable,
              MensagemChatLocalRegistro
            >,
          ),
          MensagemChatLocalRegistro,
          PrefetchHooks Function()
        > {
  $$MensagensChatLocaisTableTableManager(
    _$BancoLocal db,
    $MensagensChatLocaisTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MensagensChatLocaisTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MensagensChatLocaisTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MensagensChatLocaisTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> staffId = const Value.absent(),
                Value<String> mensagem = const Value.absent(),
                Value<DateTime> criadoEm = const Value.absent(),
                Value<DateTime?> dataServidor = const Value.absent(),
                Value<bool> excluido = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MensagensChatLocaisCompanion(
                id: id,
                staffId: staffId,
                mensagem: mensagem,
                criadoEm: criadoEm,
                dataServidor: dataServidor,
                excluido: excluido,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String staffId,
                required String mensagem,
                required DateTime criadoEm,
                Value<DateTime?> dataServidor = const Value.absent(),
                Value<bool> excluido = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MensagensChatLocaisCompanion.insert(
                id: id,
                staffId: staffId,
                mensagem: mensagem,
                criadoEm: criadoEm,
                dataServidor: dataServidor,
                excluido: excluido,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MensagensChatLocaisTableProcessedTableManager =
    ProcessedTableManager<
      _$BancoLocal,
      $MensagensChatLocaisTable,
      MensagemChatLocalRegistro,
      $$MensagensChatLocaisTableFilterComposer,
      $$MensagensChatLocaisTableOrderingComposer,
      $$MensagensChatLocaisTableAnnotationComposer,
      $$MensagensChatLocaisTableCreateCompanionBuilder,
      $$MensagensChatLocaisTableUpdateCompanionBuilder,
      (
        MensagemChatLocalRegistro,
        BaseReferences<
          _$BancoLocal,
          $MensagensChatLocaisTable,
          MensagemChatLocalRegistro
        >,
      ),
      MensagemChatLocalRegistro,
      PrefetchHooks Function()
    >;
typedef $$EventosCheckinLocaisTableCreateCompanionBuilder =
    EventosCheckinLocaisCompanion Function({
      required String id,
      required String convidadoId,
      required String usuarioId,
      required String tipoAcao,
      required bool estadoResultante,
      Value<String> eventosBaseJson,
      required DateTime dataDispositivo,
      required int sequenciaDispositivo,
      required String dispositivoId,
      Value<DateTime?> dataServidor,
      Value<String?> observacao,
      Value<bool> sincronizado,
      Value<int> rowid,
    });
typedef $$EventosCheckinLocaisTableUpdateCompanionBuilder =
    EventosCheckinLocaisCompanion Function({
      Value<String> id,
      Value<String> convidadoId,
      Value<String> usuarioId,
      Value<String> tipoAcao,
      Value<bool> estadoResultante,
      Value<String> eventosBaseJson,
      Value<DateTime> dataDispositivo,
      Value<int> sequenciaDispositivo,
      Value<String> dispositivoId,
      Value<DateTime?> dataServidor,
      Value<String?> observacao,
      Value<bool> sincronizado,
      Value<int> rowid,
    });

class $$EventosCheckinLocaisTableFilterComposer
    extends Composer<_$BancoLocal, $EventosCheckinLocaisTable> {
  $$EventosCheckinLocaisTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get convidadoId => $composableBuilder(
    column: $table.convidadoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get usuarioId => $composableBuilder(
    column: $table.usuarioId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tipoAcao => $composableBuilder(
    column: $table.tipoAcao,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get estadoResultante => $composableBuilder(
    column: $table.estadoResultante,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventosBaseJson => $composableBuilder(
    column: $table.eventosBaseJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dataDispositivo => $composableBuilder(
    column: $table.dataDispositivo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sequenciaDispositivo => $composableBuilder(
    column: $table.sequenciaDispositivo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dispositivoId => $composableBuilder(
    column: $table.dispositivoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dataServidor => $composableBuilder(
    column: $table.dataServidor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get observacao => $composableBuilder(
    column: $table.observacao,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EventosCheckinLocaisTableOrderingComposer
    extends Composer<_$BancoLocal, $EventosCheckinLocaisTable> {
  $$EventosCheckinLocaisTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get convidadoId => $composableBuilder(
    column: $table.convidadoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get usuarioId => $composableBuilder(
    column: $table.usuarioId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tipoAcao => $composableBuilder(
    column: $table.tipoAcao,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get estadoResultante => $composableBuilder(
    column: $table.estadoResultante,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventosBaseJson => $composableBuilder(
    column: $table.eventosBaseJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dataDispositivo => $composableBuilder(
    column: $table.dataDispositivo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sequenciaDispositivo => $composableBuilder(
    column: $table.sequenciaDispositivo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dispositivoId => $composableBuilder(
    column: $table.dispositivoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dataServidor => $composableBuilder(
    column: $table.dataServidor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get observacao => $composableBuilder(
    column: $table.observacao,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EventosCheckinLocaisTableAnnotationComposer
    extends Composer<_$BancoLocal, $EventosCheckinLocaisTable> {
  $$EventosCheckinLocaisTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get convidadoId => $composableBuilder(
    column: $table.convidadoId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get usuarioId =>
      $composableBuilder(column: $table.usuarioId, builder: (column) => column);

  GeneratedColumn<String> get tipoAcao =>
      $composableBuilder(column: $table.tipoAcao, builder: (column) => column);

  GeneratedColumn<bool> get estadoResultante => $composableBuilder(
    column: $table.estadoResultante,
    builder: (column) => column,
  );

  GeneratedColumn<String> get eventosBaseJson => $composableBuilder(
    column: $table.eventosBaseJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dataDispositivo => $composableBuilder(
    column: $table.dataDispositivo,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sequenciaDispositivo => $composableBuilder(
    column: $table.sequenciaDispositivo,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dispositivoId => $composableBuilder(
    column: $table.dispositivoId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dataServidor => $composableBuilder(
    column: $table.dataServidor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get observacao => $composableBuilder(
    column: $table.observacao,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get sincronizado => $composableBuilder(
    column: $table.sincronizado,
    builder: (column) => column,
  );
}

class $$EventosCheckinLocaisTableTableManager
    extends
        RootTableManager<
          _$BancoLocal,
          $EventosCheckinLocaisTable,
          EventoCheckinLocalRegistro,
          $$EventosCheckinLocaisTableFilterComposer,
          $$EventosCheckinLocaisTableOrderingComposer,
          $$EventosCheckinLocaisTableAnnotationComposer,
          $$EventosCheckinLocaisTableCreateCompanionBuilder,
          $$EventosCheckinLocaisTableUpdateCompanionBuilder,
          (
            EventoCheckinLocalRegistro,
            BaseReferences<
              _$BancoLocal,
              $EventosCheckinLocaisTable,
              EventoCheckinLocalRegistro
            >,
          ),
          EventoCheckinLocalRegistro,
          PrefetchHooks Function()
        > {
  $$EventosCheckinLocaisTableTableManager(
    _$BancoLocal db,
    $EventosCheckinLocaisTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventosCheckinLocaisTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventosCheckinLocaisTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$EventosCheckinLocaisTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> convidadoId = const Value.absent(),
                Value<String> usuarioId = const Value.absent(),
                Value<String> tipoAcao = const Value.absent(),
                Value<bool> estadoResultante = const Value.absent(),
                Value<String> eventosBaseJson = const Value.absent(),
                Value<DateTime> dataDispositivo = const Value.absent(),
                Value<int> sequenciaDispositivo = const Value.absent(),
                Value<String> dispositivoId = const Value.absent(),
                Value<DateTime?> dataServidor = const Value.absent(),
                Value<String?> observacao = const Value.absent(),
                Value<bool> sincronizado = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventosCheckinLocaisCompanion(
                id: id,
                convidadoId: convidadoId,
                usuarioId: usuarioId,
                tipoAcao: tipoAcao,
                estadoResultante: estadoResultante,
                eventosBaseJson: eventosBaseJson,
                dataDispositivo: dataDispositivo,
                sequenciaDispositivo: sequenciaDispositivo,
                dispositivoId: dispositivoId,
                dataServidor: dataServidor,
                observacao: observacao,
                sincronizado: sincronizado,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String convidadoId,
                required String usuarioId,
                required String tipoAcao,
                required bool estadoResultante,
                Value<String> eventosBaseJson = const Value.absent(),
                required DateTime dataDispositivo,
                required int sequenciaDispositivo,
                required String dispositivoId,
                Value<DateTime?> dataServidor = const Value.absent(),
                Value<String?> observacao = const Value.absent(),
                Value<bool> sincronizado = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventosCheckinLocaisCompanion.insert(
                id: id,
                convidadoId: convidadoId,
                usuarioId: usuarioId,
                tipoAcao: tipoAcao,
                estadoResultante: estadoResultante,
                eventosBaseJson: eventosBaseJson,
                dataDispositivo: dataDispositivo,
                sequenciaDispositivo: sequenciaDispositivo,
                dispositivoId: dispositivoId,
                dataServidor: dataServidor,
                observacao: observacao,
                sincronizado: sincronizado,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EventosCheckinLocaisTableProcessedTableManager =
    ProcessedTableManager<
      _$BancoLocal,
      $EventosCheckinLocaisTable,
      EventoCheckinLocalRegistro,
      $$EventosCheckinLocaisTableFilterComposer,
      $$EventosCheckinLocaisTableOrderingComposer,
      $$EventosCheckinLocaisTableAnnotationComposer,
      $$EventosCheckinLocaisTableCreateCompanionBuilder,
      $$EventosCheckinLocaisTableUpdateCompanionBuilder,
      (
        EventoCheckinLocalRegistro,
        BaseReferences<
          _$BancoLocal,
          $EventosCheckinLocaisTable,
          EventoCheckinLocalRegistro
        >,
      ),
      EventoCheckinLocalRegistro,
      PrefetchHooks Function()
    >;
typedef $$OperacoesPendentesLocaisTableCreateCompanionBuilder =
    OperacoesPendentesLocaisCompanion Function({
      required String id,
      required String entidade,
      required String entidadeId,
      required String tipoOperacao,
      required String payloadJson,
      required DateTime criadoEm,
      Value<int> tentativas,
      Value<String?> ultimoErro,
      Value<String> status,
      Value<int> rowid,
    });
typedef $$OperacoesPendentesLocaisTableUpdateCompanionBuilder =
    OperacoesPendentesLocaisCompanion Function({
      Value<String> id,
      Value<String> entidade,
      Value<String> entidadeId,
      Value<String> tipoOperacao,
      Value<String> payloadJson,
      Value<DateTime> criadoEm,
      Value<int> tentativas,
      Value<String?> ultimoErro,
      Value<String> status,
      Value<int> rowid,
    });

class $$OperacoesPendentesLocaisTableFilterComposer
    extends Composer<_$BancoLocal, $OperacoesPendentesLocaisTable> {
  $$OperacoesPendentesLocaisTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entidade => $composableBuilder(
    column: $table.entidade,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entidadeId => $composableBuilder(
    column: $table.entidadeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tipoOperacao => $composableBuilder(
    column: $table.tipoOperacao,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get criadoEm => $composableBuilder(
    column: $table.criadoEm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tentativas => $composableBuilder(
    column: $table.tentativas,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ultimoErro => $composableBuilder(
    column: $table.ultimoErro,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OperacoesPendentesLocaisTableOrderingComposer
    extends Composer<_$BancoLocal, $OperacoesPendentesLocaisTable> {
  $$OperacoesPendentesLocaisTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entidade => $composableBuilder(
    column: $table.entidade,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entidadeId => $composableBuilder(
    column: $table.entidadeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tipoOperacao => $composableBuilder(
    column: $table.tipoOperacao,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get criadoEm => $composableBuilder(
    column: $table.criadoEm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tentativas => $composableBuilder(
    column: $table.tentativas,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ultimoErro => $composableBuilder(
    column: $table.ultimoErro,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OperacoesPendentesLocaisTableAnnotationComposer
    extends Composer<_$BancoLocal, $OperacoesPendentesLocaisTable> {
  $$OperacoesPendentesLocaisTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entidade =>
      $composableBuilder(column: $table.entidade, builder: (column) => column);

  GeneratedColumn<String> get entidadeId => $composableBuilder(
    column: $table.entidadeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tipoOperacao => $composableBuilder(
    column: $table.tipoOperacao,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get criadoEm =>
      $composableBuilder(column: $table.criadoEm, builder: (column) => column);

  GeneratedColumn<int> get tentativas => $composableBuilder(
    column: $table.tentativas,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ultimoErro => $composableBuilder(
    column: $table.ultimoErro,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$OperacoesPendentesLocaisTableTableManager
    extends
        RootTableManager<
          _$BancoLocal,
          $OperacoesPendentesLocaisTable,
          OperacaoPendenteLocalRegistro,
          $$OperacoesPendentesLocaisTableFilterComposer,
          $$OperacoesPendentesLocaisTableOrderingComposer,
          $$OperacoesPendentesLocaisTableAnnotationComposer,
          $$OperacoesPendentesLocaisTableCreateCompanionBuilder,
          $$OperacoesPendentesLocaisTableUpdateCompanionBuilder,
          (
            OperacaoPendenteLocalRegistro,
            BaseReferences<
              _$BancoLocal,
              $OperacoesPendentesLocaisTable,
              OperacaoPendenteLocalRegistro
            >,
          ),
          OperacaoPendenteLocalRegistro,
          PrefetchHooks Function()
        > {
  $$OperacoesPendentesLocaisTableTableManager(
    _$BancoLocal db,
    $OperacoesPendentesLocaisTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OperacoesPendentesLocaisTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$OperacoesPendentesLocaisTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$OperacoesPendentesLocaisTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> entidade = const Value.absent(),
                Value<String> entidadeId = const Value.absent(),
                Value<String> tipoOperacao = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> criadoEm = const Value.absent(),
                Value<int> tentativas = const Value.absent(),
                Value<String?> ultimoErro = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OperacoesPendentesLocaisCompanion(
                id: id,
                entidade: entidade,
                entidadeId: entidadeId,
                tipoOperacao: tipoOperacao,
                payloadJson: payloadJson,
                criadoEm: criadoEm,
                tentativas: tentativas,
                ultimoErro: ultimoErro,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String entidade,
                required String entidadeId,
                required String tipoOperacao,
                required String payloadJson,
                required DateTime criadoEm,
                Value<int> tentativas = const Value.absent(),
                Value<String?> ultimoErro = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OperacoesPendentesLocaisCompanion.insert(
                id: id,
                entidade: entidade,
                entidadeId: entidadeId,
                tipoOperacao: tipoOperacao,
                payloadJson: payloadJson,
                criadoEm: criadoEm,
                tentativas: tentativas,
                ultimoErro: ultimoErro,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OperacoesPendentesLocaisTableProcessedTableManager =
    ProcessedTableManager<
      _$BancoLocal,
      $OperacoesPendentesLocaisTable,
      OperacaoPendenteLocalRegistro,
      $$OperacoesPendentesLocaisTableFilterComposer,
      $$OperacoesPendentesLocaisTableOrderingComposer,
      $$OperacoesPendentesLocaisTableAnnotationComposer,
      $$OperacoesPendentesLocaisTableCreateCompanionBuilder,
      $$OperacoesPendentesLocaisTableUpdateCompanionBuilder,
      (
        OperacaoPendenteLocalRegistro,
        BaseReferences<
          _$BancoLocal,
          $OperacoesPendentesLocaisTable,
          OperacaoPendenteLocalRegistro
        >,
      ),
      OperacaoPendenteLocalRegistro,
      PrefetchHooks Function()
    >;
typedef $$ConfiguracoesLocaisTableCreateCompanionBuilder =
    ConfiguracoesLocaisCompanion Function({
      required String chave,
      required String valor,
      required DateTime atualizadoEm,
      Value<int> rowid,
    });
typedef $$ConfiguracoesLocaisTableUpdateCompanionBuilder =
    ConfiguracoesLocaisCompanion Function({
      Value<String> chave,
      Value<String> valor,
      Value<DateTime> atualizadoEm,
      Value<int> rowid,
    });

class $$ConfiguracoesLocaisTableFilterComposer
    extends Composer<_$BancoLocal, $ConfiguracoesLocaisTable> {
  $$ConfiguracoesLocaisTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get chave => $composableBuilder(
    column: $table.chave,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valor => $composableBuilder(
    column: $table.valor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConfiguracoesLocaisTableOrderingComposer
    extends Composer<_$BancoLocal, $ConfiguracoesLocaisTable> {
  $$ConfiguracoesLocaisTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get chave => $composableBuilder(
    column: $table.chave,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valor => $composableBuilder(
    column: $table.valor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConfiguracoesLocaisTableAnnotationComposer
    extends Composer<_$BancoLocal, $ConfiguracoesLocaisTable> {
  $$ConfiguracoesLocaisTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get chave =>
      $composableBuilder(column: $table.chave, builder: (column) => column);

  GeneratedColumn<String> get valor =>
      $composableBuilder(column: $table.valor, builder: (column) => column);

  GeneratedColumn<DateTime> get atualizadoEm => $composableBuilder(
    column: $table.atualizadoEm,
    builder: (column) => column,
  );
}

class $$ConfiguracoesLocaisTableTableManager
    extends
        RootTableManager<
          _$BancoLocal,
          $ConfiguracoesLocaisTable,
          ConfiguracaoLocalRegistro,
          $$ConfiguracoesLocaisTableFilterComposer,
          $$ConfiguracoesLocaisTableOrderingComposer,
          $$ConfiguracoesLocaisTableAnnotationComposer,
          $$ConfiguracoesLocaisTableCreateCompanionBuilder,
          $$ConfiguracoesLocaisTableUpdateCompanionBuilder,
          (
            ConfiguracaoLocalRegistro,
            BaseReferences<
              _$BancoLocal,
              $ConfiguracoesLocaisTable,
              ConfiguracaoLocalRegistro
            >,
          ),
          ConfiguracaoLocalRegistro,
          PrefetchHooks Function()
        > {
  $$ConfiguracoesLocaisTableTableManager(
    _$BancoLocal db,
    $ConfiguracoesLocaisTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConfiguracoesLocaisTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConfiguracoesLocaisTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ConfiguracoesLocaisTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> chave = const Value.absent(),
                Value<String> valor = const Value.absent(),
                Value<DateTime> atualizadoEm = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConfiguracoesLocaisCompanion(
                chave: chave,
                valor: valor,
                atualizadoEm: atualizadoEm,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String chave,
                required String valor,
                required DateTime atualizadoEm,
                Value<int> rowid = const Value.absent(),
              }) => ConfiguracoesLocaisCompanion.insert(
                chave: chave,
                valor: valor,
                atualizadoEm: atualizadoEm,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConfiguracoesLocaisTableProcessedTableManager =
    ProcessedTableManager<
      _$BancoLocal,
      $ConfiguracoesLocaisTable,
      ConfiguracaoLocalRegistro,
      $$ConfiguracoesLocaisTableFilterComposer,
      $$ConfiguracoesLocaisTableOrderingComposer,
      $$ConfiguracoesLocaisTableAnnotationComposer,
      $$ConfiguracoesLocaisTableCreateCompanionBuilder,
      $$ConfiguracoesLocaisTableUpdateCompanionBuilder,
      (
        ConfiguracaoLocalRegistro,
        BaseReferences<
          _$BancoLocal,
          $ConfiguracoesLocaisTable,
          ConfiguracaoLocalRegistro
        >,
      ),
      ConfiguracaoLocalRegistro,
      PrefetchHooks Function()
    >;
typedef $$SincronizacoesLocaisTableCreateCompanionBuilder =
    SincronizacoesLocaisCompanion Function({
      required String recurso,
      Value<DateTime?> ultimaSincronizacao,
      Value<String?> cursorServidor,
      Value<bool> emAndamento,
      Value<String?> ultimoErro,
      Value<int> rowid,
    });
typedef $$SincronizacoesLocaisTableUpdateCompanionBuilder =
    SincronizacoesLocaisCompanion Function({
      Value<String> recurso,
      Value<DateTime?> ultimaSincronizacao,
      Value<String?> cursorServidor,
      Value<bool> emAndamento,
      Value<String?> ultimoErro,
      Value<int> rowid,
    });

class $$SincronizacoesLocaisTableFilterComposer
    extends Composer<_$BancoLocal, $SincronizacoesLocaisTable> {
  $$SincronizacoesLocaisTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get recurso => $composableBuilder(
    column: $table.recurso,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get ultimaSincronizacao => $composableBuilder(
    column: $table.ultimaSincronizacao,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cursorServidor => $composableBuilder(
    column: $table.cursorServidor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get emAndamento => $composableBuilder(
    column: $table.emAndamento,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ultimoErro => $composableBuilder(
    column: $table.ultimoErro,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SincronizacoesLocaisTableOrderingComposer
    extends Composer<_$BancoLocal, $SincronizacoesLocaisTable> {
  $$SincronizacoesLocaisTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get recurso => $composableBuilder(
    column: $table.recurso,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get ultimaSincronizacao => $composableBuilder(
    column: $table.ultimaSincronizacao,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cursorServidor => $composableBuilder(
    column: $table.cursorServidor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get emAndamento => $composableBuilder(
    column: $table.emAndamento,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ultimoErro => $composableBuilder(
    column: $table.ultimoErro,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SincronizacoesLocaisTableAnnotationComposer
    extends Composer<_$BancoLocal, $SincronizacoesLocaisTable> {
  $$SincronizacoesLocaisTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get recurso =>
      $composableBuilder(column: $table.recurso, builder: (column) => column);

  GeneratedColumn<DateTime> get ultimaSincronizacao => $composableBuilder(
    column: $table.ultimaSincronizacao,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cursorServidor => $composableBuilder(
    column: $table.cursorServidor,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get emAndamento => $composableBuilder(
    column: $table.emAndamento,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ultimoErro => $composableBuilder(
    column: $table.ultimoErro,
    builder: (column) => column,
  );
}

class $$SincronizacoesLocaisTableTableManager
    extends
        RootTableManager<
          _$BancoLocal,
          $SincronizacoesLocaisTable,
          SincronizacaoLocalRegistro,
          $$SincronizacoesLocaisTableFilterComposer,
          $$SincronizacoesLocaisTableOrderingComposer,
          $$SincronizacoesLocaisTableAnnotationComposer,
          $$SincronizacoesLocaisTableCreateCompanionBuilder,
          $$SincronizacoesLocaisTableUpdateCompanionBuilder,
          (
            SincronizacaoLocalRegistro,
            BaseReferences<
              _$BancoLocal,
              $SincronizacoesLocaisTable,
              SincronizacaoLocalRegistro
            >,
          ),
          SincronizacaoLocalRegistro,
          PrefetchHooks Function()
        > {
  $$SincronizacoesLocaisTableTableManager(
    _$BancoLocal db,
    $SincronizacoesLocaisTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SincronizacoesLocaisTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SincronizacoesLocaisTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SincronizacoesLocaisTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> recurso = const Value.absent(),
                Value<DateTime?> ultimaSincronizacao = const Value.absent(),
                Value<String?> cursorServidor = const Value.absent(),
                Value<bool> emAndamento = const Value.absent(),
                Value<String?> ultimoErro = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SincronizacoesLocaisCompanion(
                recurso: recurso,
                ultimaSincronizacao: ultimaSincronizacao,
                cursorServidor: cursorServidor,
                emAndamento: emAndamento,
                ultimoErro: ultimoErro,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String recurso,
                Value<DateTime?> ultimaSincronizacao = const Value.absent(),
                Value<String?> cursorServidor = const Value.absent(),
                Value<bool> emAndamento = const Value.absent(),
                Value<String?> ultimoErro = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SincronizacoesLocaisCompanion.insert(
                recurso: recurso,
                ultimaSincronizacao: ultimaSincronizacao,
                cursorServidor: cursorServidor,
                emAndamento: emAndamento,
                ultimoErro: ultimoErro,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SincronizacoesLocaisTableProcessedTableManager =
    ProcessedTableManager<
      _$BancoLocal,
      $SincronizacoesLocaisTable,
      SincronizacaoLocalRegistro,
      $$SincronizacoesLocaisTableFilterComposer,
      $$SincronizacoesLocaisTableOrderingComposer,
      $$SincronizacoesLocaisTableAnnotationComposer,
      $$SincronizacoesLocaisTableCreateCompanionBuilder,
      $$SincronizacoesLocaisTableUpdateCompanionBuilder,
      (
        SincronizacaoLocalRegistro,
        BaseReferences<
          _$BancoLocal,
          $SincronizacoesLocaisTable,
          SincronizacaoLocalRegistro
        >,
      ),
      SincronizacaoLocalRegistro,
      PrefetchHooks Function()
    >;

class $BancoLocalManager {
  final _$BancoLocal _db;
  $BancoLocalManager(this._db);
  $$MesasLocaisTableTableManager get mesasLocais =>
      $$MesasLocaisTableTableManager(_db, _db.mesasLocais);
  $$ConvidadosLocaisTableTableManager get convidadosLocais =>
      $$ConvidadosLocaisTableTableManager(_db, _db.convidadosLocais);
  $$UsuariosAppLocaisTableTableManager get usuariosAppLocais =>
      $$UsuariosAppLocaisTableTableManager(_db, _db.usuariosAppLocais);
  $$StaffsLocaisTableTableManager get staffsLocais =>
      $$StaffsLocaisTableTableManager(_db, _db.staffsLocais);
  $$MensagensChatLocaisTableTableManager get mensagensChatLocais =>
      $$MensagensChatLocaisTableTableManager(_db, _db.mensagensChatLocais);
  $$EventosCheckinLocaisTableTableManager get eventosCheckinLocais =>
      $$EventosCheckinLocaisTableTableManager(_db, _db.eventosCheckinLocais);
  $$OperacoesPendentesLocaisTableTableManager get operacoesPendentesLocais =>
      $$OperacoesPendentesLocaisTableTableManager(
        _db,
        _db.operacoesPendentesLocais,
      );
  $$ConfiguracoesLocaisTableTableManager get configuracoesLocais =>
      $$ConfiguracoesLocaisTableTableManager(_db, _db.configuracoesLocais);
  $$SincronizacoesLocaisTableTableManager get sincronizacoesLocais =>
      $$SincronizacoesLocaisTableTableManager(_db, _db.sincronizacoesLocais);
}
