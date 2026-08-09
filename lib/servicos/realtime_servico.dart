import 'package:supabase_flutter/supabase_flutter.dart';

import 'sincronizacao_automatica_servico.dart';
import 'sincronizacao_servico.dart';

/// Escuta alterações feitas no Supabase por outros celulares.
///
/// O conteúdo do evento não é aplicado diretamente no SQLite. Quando qualquer
/// tabela importante muda, uma sincronização completa e segura é agendada.
/// Dessa forma, inclusões, alterações, exclusões lógicas e exclusões feitas
/// diretamente no Supabase são reconciliadas com o banco local.
class RealtimeServico {
  RealtimeServico._();

  static final RealtimeServico instance = RealtimeServico._();

  final SupabaseClient _supabase = Supabase.instance.client;

  RealtimeChannel? _canal;
  bool _inicializado = false;

  Future<void> inicializar() async {
    if (_inicializado) {
      return;
    }

    _inicializado = true;

    _canal = _supabase
        .channel('app-casamento-sincronizacao')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'controle_lista',
          callback: (_) => _aoReceberAlteracao(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'mesas',
          callback: (_) => _aoReceberAlteracao(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'convidados',
          callback: (_) => _aoReceberAlteracao(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'eventos_checkin',
          callback: (_) => _aoReceberAlteracao(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'usuarios_app',
          callback: (_) => _aoReceberAlteracao(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'casamentos',
          callback: (_) => _aoReceberAlteracao(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'membros_casamento',
          callback: (_) => _aoReceberAlteracao(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'membros_organizacao',
          callback: (_) => _aoReceberAlteracao(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'funcionarios_organizacao',
          callback: (_) => _aoReceberAlteracao(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conflitos_sincronizacao',
          callback: (_) => _aoReceberAlteracao(),
        )
        .subscribe();
  }

  void _aoReceberAlteracao() {
    // Alterações enviadas pelo próprio aparelho também retornam pelo Realtime.
    // Durante uma sincronização completa elas já serão baixadas no mesmo ciclo,
    // então iniciar outra sincronização imediatamente só cria repetições.
    if (SincronizacaoServico.instance.emAndamento ||
        SincronizacaoAutomaticaServico.instance.executando) {
      return;
    }

    SincronizacaoAutomaticaServico.instance.agendar(
      atraso: const Duration(milliseconds: 250),
    );
  }

  Future<void> encerrar() async {
    final canalAtual = _canal;

    if (canalAtual != null) {
      await _supabase.removeChannel(canalAtual);
    }

    _canal = null;
    _inicializado = false;
  }
}
