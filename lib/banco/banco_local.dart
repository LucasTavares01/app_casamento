import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'banco_local.g.dart';

/// Cópia local das mesas existentes no Supabase.
///
/// Quando uma mesa for criada ou alterada offline, ela será salva primeiro
/// nesta tabela. Depois, uma operação será adicionada à fila de sincronização.
@DataClassName('MesaLocalRegistro')
class MesasLocais extends Table {
  TextColumn get id => text()();

  IntColumn get numero => integer().withDefault(const Constant(0))();

  TextColumn get detalhe => text().nullable()();

  DateTimeColumn get criadoEm => dateTime()();

  DateTimeColumn get atualizadoEm => dateTime()();

  /// Exclusões offline serão inicialmente mantidas como exclusão lógica.
  ///
  /// Isso evita que o registro desapareça antes de o Supabase receber
  /// a solicitação de exclusão.
  BoolColumn get excluido => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cópia local dos convidados.
///
/// O campo [chegou] representa o estado atual calculado pelo aplicativo.
/// O histórico completo continuará armazenado em EventosCheckinLocais.
@DataClassName('ConvidadoLocalRegistro')
class ConvidadosLocais extends Table {
  TextColumn get id => text()();

  TextColumn get nome => text()();

  /// Contatos opcionais usados pelos convites online.
  TextColumn get email => text().nullable()();

  TextColumn get whatsapp => text().nullable()();

  TextColumn get mesaId => text().nullable()();

  BoolColumn get chegou => boolean().withDefault(const Constant(false))();

  /// Indica que existem ações simultâneas e contraditórias.
  BoolColumn get temConflito => boolean().withDefault(const Constant(false))();

  /// Lista em formato JSON dos eventos que formam o estado atual.
  ///
  /// Exemplo:
  /// ["id-evento-william", "id-evento-joice"]
  TextColumn get eventosAtuaisJson =>
      text().withDefault(const Constant('[]'))();

  DateTimeColumn get criadoEm => dateTime()();

  DateTimeColumn get atualizadoEm => dateTime()();

  BoolColumn get excluido => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Usuários disponíveis no login do aplicativo.
///
/// As senhas não ficam nesta tabela. Elas permanecerão definidas no
/// aplicativo durante esta fase de protótipo.
@DataClassName('UsuarioAppLocalRegistro')
class UsuariosAppLocais extends Table {
  TextColumn get id => text()();

  TextColumn get nome => text()();

  IntColumn get ordem => integer().withDefault(const Constant(0))();

  BoolColumn get ativo => boolean().withDefault(const Constant(true))();

  DateTimeColumn get criadoEm => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cópia local da tabela staff já existente no Supabase.
///
/// Ela será mantida separada dos usuários do login para não apagar nem
/// modificar a estrutura atual do chat.
@DataClassName('StaffLocalRegistro')
class StaffsLocais extends Table {
  TextColumn get id => text()();

  TextColumn get nome => text()();

  TextColumn get sobrenome => text()();

  TextColumn get ocupacao => text()();

  DateTimeColumn get criadoEm => dateTime()();

  DateTimeColumn get atualizadoEm => dateTime()();

  BoolColumn get excluido => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Mensagens do chat armazenadas no celular.
///
/// Uma mensagem poderá aparecer imediatamente no chat mesmo que o aparelho
/// esteja offline. Depois ela será enviada ao Supabase.
@DataClassName('MensagemChatLocalRegistro')
class MensagensChatLocais extends Table {
  TextColumn get id => text()();

  TextColumn get staffId => text()();

  TextColumn get mensagem => text()();

  DateTimeColumn get criadoEm => dateTime()();

  DateTimeColumn get dataServidor => dateTime().nullable()();

  BoolColumn get excluido => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Histórico completo das confirmações e remoções de chegada.
///
/// Cada toque no botão de check-in cria um evento novo. Um evento nunca
/// substitui silenciosamente outro evento.
@DataClassName('EventoCheckinLocalRegistro')
class EventosCheckinLocais extends Table {
  TextColumn get id => text()();

  TextColumn get convidadoId => text()();

  TextColumn get usuarioId => text()();

  /// Valores possíveis:
  ///
  /// confirmou_chegada
  /// removeu_chegada
  /// resolveu_como_presente
  /// resolveu_como_ausente
  TextColumn get tipoAcao => text()();

  BoolColumn get estadoResultante => boolean()();

  /// Eventos que o aparelho conhecia no momento da nova ação.
  ///
  /// A lista é armazenada como JSON porque o SQLite não utiliza diretamente
  /// o tipo uuid[] existente no PostgreSQL.
  TextColumn get eventosBaseJson => text().withDefault(const Constant('[]'))();

  DateTimeColumn get dataDispositivo => dateTime()();

  IntColumn get sequenciaDispositivo => integer()();

  TextColumn get dispositivoId => text()();

  DateTimeColumn get dataServidor => dateTime().nullable()();

  TextColumn get observacao => text().nullable()();

  BoolColumn get sincronizado => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};

  /// Impede que um mesmo aparelho grave duas ações com a mesma sequência.
  @override
  List<Set<Column>> get uniqueKeys => [
    {dispositivoId, sequenciaDispositivo},
  ];
}

/// Fila de tudo que ainda precisa ser enviado ao Supabase.
///
/// Uma alteração offline será salva nesta tabela. Quando a internet voltar,
/// o sincronizador processará as operações pendentes na ordem em que foram
/// criadas.
@DataClassName('OperacaoPendenteLocalRegistro')
class OperacoesPendentesLocais extends Table {
  TextColumn get id => text()();

  /// Exemplos:
  ///
  /// mesa
  /// convidado
  /// staff
  /// mensagem_chat
  /// evento_checkin
  TextColumn get entidade => text()();

  TextColumn get entidadeId => text()();

  /// Exemplos:
  ///
  /// inserir
  /// atualizar
  /// excluir
  TextColumn get tipoOperacao => text()();

  /// Dados completos que deverão ser enviados ao Supabase.
  TextColumn get payloadJson => text()();

  DateTimeColumn get criadoEm => dateTime()();

  IntColumn get tentativas => integer().withDefault(const Constant(0))();

  TextColumn get ultimoErro => text().nullable()();

  /// Valores usados inicialmente:
  ///
  /// pendente
  /// enviando
  /// erro
  TextColumn get status => text().withDefault(const Constant('pendente'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Configurações persistentes do aplicativo.
///
/// Aqui serão guardados, por exemplo:
///
/// - ID único do aparelho;
/// - usuário selecionado no login;
/// - sequência atual das ações offline.
@DataClassName('ConfiguracaoLocalRegistro')
class ConfiguracoesLocais extends Table {
  TextColumn get chave => text()();

  TextColumn get valor => text()();

  DateTimeColumn get atualizadoEm => dateTime()();

  @override
  Set<Column> get primaryKey => {chave};
}

/// Informações sobre a última sincronização de cada recurso.
@DataClassName('SincronizacaoLocalRegistro')
class SincronizacoesLocais extends Table {
  TextColumn get recurso => text()();

  DateTimeColumn get ultimaSincronizacao => dateTime().nullable()();

  TextColumn get cursorServidor => text().nullable()();

  BoolColumn get emAndamento => boolean().withDefault(const Constant(false))();

  TextColumn get ultimoErro => text().nullable()();

  @override
  Set<Column> get primaryKey => {recurso};
}

/// Banco SQLite utilizado pelo aplicativo.
///
/// A primeira versão contém todas as tabelas básicas necessárias para
/// armazenar os dados e a fila de sincronização.
@DriftDatabase(
  tables: [
    MesasLocais,
    ConvidadosLocais,
    UsuariosAppLocais,
    StaffsLocais,
    MensagensChatLocais,
    EventosCheckinLocais,
    OperacoesPendentesLocais,
    ConfiguracoesLocais,
    SincronizacoesLocais,
  ],
)
class BancoLocal extends _$BancoLocal {
  BancoLocal() : super(driftDatabase(name: 'app_casamento_offline'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator migrator) => migrator.createAll(),
    onUpgrade: (Migrator migrator, int from, int to) async {
      if (from < 2) {
        await migrator.addColumn(convidadosLocais, convidadosLocais.email);
        await migrator.addColumn(convidadosLocais, convidadosLocais.whatsapp);
      }
    },
  );
}
