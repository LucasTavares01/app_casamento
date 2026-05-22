import 'package:supabase_flutter/supabase_flutter.dart';
import '../modelos/modelos.dart';

class SupabaseServico {
  final _supabase = Supabase.instance.client;

  // --- MÉTODOS PARA MESAS ---
  Future<void> adicionarMesa(int numero, String? detalhe) async {
    await _supabase.from('mesas').insert({
      'numero': numero,
      'detalhe': detalhe,
    });
  }

  Future<void> editarMesa(String id, int numero, String? detalhe) async {
    await _supabase
        .from('mesas')
        .update({'numero': numero, 'detalhe': detalhe})
        .eq('id', id);
  }

  Future<void> excluirMesa(String id) async {
    await _supabase.from('mesas').delete().eq('id', id);
  }

  Stream<List<Mesa>> listarMesas() {
    return _supabase
        .from('mesas')
        .stream(primaryKey: ['id'])
        .order('numero', ascending: true)
        .map((dados) => dados.map((m) => Mesa.fromMap(m)).toList());
  }

  // --- MÉTODOS PARA CONVIDADOS ---
  Future<void> adicionarConvidado(String nome, String? mesaId) async {
    await _supabase.from('convidados').insert({
      'nome': nome,
      'mesa_id': mesaId,
    });
  }

  Future<void> editarConvidado(String id, String nome, String? mesaId) async {
    await _supabase
        .from('convidados')
        .update({'nome': nome, 'mesa_id': mesaId})
        .eq('id', id);
  }

  Future<void> excluirConvidado(String id) async {
    await _supabase.from('convidados').delete().eq('id', id);
  }

  Stream<List<Convidado>> listarConvidados() {
    return _supabase
        .from('convidados')
        .stream(primaryKey: ['id'])
        .map((dados) => dados.map((c) => Convidado.fromMap(c)).toList());
  }

  Future<void> confirmarChegada(String id) async {
    await _supabase.from('convidados').update({'chegou': true}).eq('id', id);
  }

  Future<void> removerChegada(String id) async {
    await _supabase.from('convidados').update({'chegou': false}).eq('id', id);
  }

  // --- MÉTODOS PARA STAFF E CHAT ---
  Future<void> adicionarStaff(
    String nome,
    String sobrenome,
    String ocupacao,
  ) async {
    await _supabase.from('staff').insert({
      'nome': nome,
      'sobrenome': sobrenome,
      'ocupacao': ocupacao,
    });
  }

  Stream<List<Staff>> listarStaff() {
    return _supabase
        .from('staff')
        .stream(primaryKey: ['id'])
        .map((dados) => dados.map((s) => Staff.fromMap(s)).toList());
  }

  Future<void> enviarMensagem(String staffId, String mensagem) async {
    await _supabase.from('chat').insert({
      'staff_id': staffId,
      'mensagem': mensagem,
    });
  }

  Stream<List<MensagemChat>> listarMensagens() {
    return _supabase
        .from('chat')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map((dados) => dados.map((m) => MensagemChat.fromMap(m)).toList());
  }
}
