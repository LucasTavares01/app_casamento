import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'casamento_atual_servico.dart';

class MembroEquipe {
  final String funcionarioId;
  final String usuarioId;
  final String nome;
  final String? email;
  final String? telefone;
  final bool convidadoParaEsteCasamento;
  final bool conviteAceito;

  const MembroEquipe({
    required this.funcionarioId,
    required this.usuarioId,
    required this.nome,
    required this.email,
    required this.telefone,
    required this.convidadoParaEsteCasamento,
    required this.conviteAceito,
  });
}

class ResultadoConviteFuncionario {
  const ResultadoConviteFuncionario({
    required this.conviteEnviado,
    required this.notificacaoEnviada,
    required this.contaJaExistia,
    required this.contaMista,
    this.linkWhatsApp,
    this.telefoneWhatsApp,
    this.mensagemNotificacao,
  });

  final bool conviteEnviado;
  final bool notificacaoEnviada;
  final bool contaJaExistia;
  final bool contaMista;
  final String? linkWhatsApp;
  final String? telefoneWhatsApp;
  final String? mensagemNotificacao;
}

class EquipeServico {
  EquipeServico._();
  static final EquipeServico instance = EquipeServico._();

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<MembroEquipe>> listar() async {
    final casamento = CasamentoAtualServico.instance.casamento;
    if (casamento == null) return const [];

    final resultados = await Future.wait([
      _supabase
          .from('funcionarios_organizacao')
          .select('id, usuario_id, nome, email, telefone')
          .eq('organizacao_id', casamento.organizacaoId)
          .eq('ativo', true)
          .order('nome'),
      _supabase
          .from('membros_casamento')
          .select('usuario_id, convite_aceito_em')
          .eq('casamento_id', casamento.id)
          .eq('papel', 'funcionario')
          .eq('ativo', true),
    ]);
    final convitesPorUsuario = <String, bool>{
      for (final item in resultados[1] as List)
        (item as Map)['usuario_id'].toString():
            item['convite_aceito_em'] != null,
    };
    final membros = (resultados[0] as List).map((item) {
      final registro = Map<String, dynamic>.from(item as Map);
      return MembroEquipe(
        funcionarioId: registro['id'].toString(),
        usuarioId: registro['usuario_id'].toString(),
        nome: registro['nome'].toString(),
        email: registro['email']?.toString(),
        telefone: registro['telefone']?.toString(),
        convidadoParaEsteCasamento: convitesPorUsuario.containsKey(
          registro['usuario_id'].toString(),
        ),
        conviteAceito:
            convitesPorUsuario[registro['usuario_id'].toString()] ?? false,
      );
    }).toList();
    return membros;
  }

  /// Mantém a equipe visível sempre atualizada, inclusive quando outra
  /// administradora convida ou remove alguém em outro aparelho.
  Stream<List<MembroEquipe>> listarEmTempoReal() async* {
    final casamento = CasamentoAtualServico.instance.casamento;
    if (casamento == null) {
      yield const [];
      return;
    }

    final atualizacoes = StreamController<void>();
    final assinaturas = <StreamSubscription<dynamic>>[];

    void atualizar() {
      if (!atualizacoes.isClosed) atualizacoes.add(null);
    }

    void observar(Stream<dynamic> stream) {
      assinaturas.add(
        stream.listen((_) => atualizar(), onError: atualizacoes.addError),
      );
    }

    observar(
      _supabase
          .from('funcionarios_organizacao')
          .stream(primaryKey: ['id'])
          .eq('organizacao_id', casamento.organizacaoId),
    );
    observar(
      _supabase
          .from('membros_casamento')
          .stream(primaryKey: ['casamento_id', 'usuario_id'])
          .eq('casamento_id', casamento.id),
    );
    observar(
      _supabase
          .from('membros_organizacao')
          .stream(primaryKey: ['organizacao_id', 'usuario_id'])
          .eq('organizacao_id', casamento.organizacaoId),
    );
    atualizar();

    try {
      await for (final _ in atualizacoes.stream) {
        yield await listar();
      }
    } finally {
      await Future.wait(assinaturas.map((assinatura) => assinatura.cancel()));
      await atualizacoes.close();
    }
  }

  Future<ResultadoConviteFuncionario> convidarFuncionario({
    required String nome,
    String? email,
    String? telefone,
  }) async {
    final casamento = CasamentoAtualServico.instance.casamento;
    if (casamento == null || !casamento.ehAdmin) {
      throw StateError('Somente administradoras podem convidar funcionários.');
    }
    final resposta = await _supabase.functions.invoke(
      'convidar-funcionario',
      body: {
        'casamento_id': casamento.id,
        'nome': nome.trim(),
        'email': email?.trim(),
        'telefone': telefone?.trim(),
      },
    );
    final dados = Map<String, dynamic>.from(resposta.data as Map);
    return ResultadoConviteFuncionario(
      conviteEnviado: dados['convite_enviado'] != false,
      notificacaoEnviada: dados['notificacao_enviada'] == true,
      contaJaExistia: dados['conta_ja_existia'] == true,
      contaMista: dados['conta_mista'] == true,
      linkWhatsApp: dados['link_whatsapp']?.toString(),
      telefoneWhatsApp: dados['telefone_whatsapp']?.toString(),
      mensagemNotificacao: dados['mensagem_notificacao']?.toString(),
    );
  }

  Future<ResultadoConviteFuncionario> convidarParaEsteCasamento(
    MembroEquipe membro,
  ) async {
    final casamento = CasamentoAtualServico.instance.casamento;
    if (casamento == null || !casamento.ehAdmin) {
      throw StateError('Somente administradoras podem convidar funcionários.');
    }
    final resposta = await _supabase.functions.invoke(
      'convidar-funcionario',
      body: {
        'casamento_id': casamento.id,
        'funcionario_id': membro.funcionarioId,
      },
    );
    final dados = Map<String, dynamic>.from(resposta.data as Map);
    return ResultadoConviteFuncionario(
      conviteEnviado: dados['convite_enviado'] == true,
      notificacaoEnviada: dados['notificacao_enviada'] == true,
      contaJaExistia: dados['conta_ja_existia'] == true,
      contaMista: dados['conta_mista'] == true,
      linkWhatsApp: dados['link_whatsapp']?.toString(),
      telefoneWhatsApp: dados['telefone_whatsapp']?.toString(),
      mensagemNotificacao: dados['mensagem_notificacao']?.toString(),
    );
  }

  Future<void> desativar(MembroEquipe membro) async {
    final casamento = CasamentoAtualServico.instance.casamento;
    if (casamento == null || !membro.convidadoParaEsteCasamento) return;
    await _supabase
        .from('membros_casamento')
        .update({
          'ativo': false,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('casamento_id', casamento.id)
        .eq('usuario_id', membro.usuarioId);
  }

  Future<void> atualizarDadosFuncionario({
    required MembroEquipe membro,
    required String nome,
    String? email,
    String? telefone,
  }) async {
    final casamento = CasamentoAtualServico.instance.casamento;
    if (casamento == null || !casamento.ehAdmin) {
      throw StateError('Somente administradoras podem editar funcionários.');
    }

    final nomeNormalizado = nome.trim();
    if (nomeNormalizado.length < 2) {
      throw const FormatException('Informe um nome válido.');
    }
    final emailNormalizado = email?.trim().toLowerCase();
    if (emailNormalizado != null &&
        emailNormalizado.isNotEmpty &&
        !emailNormalizado.contains('@')) {
      throw const FormatException('Informe um e-mail válido.');
    }

    final telefoneNormalizado = telefone?.trim();
    await _supabase
        .from('funcionarios_organizacao')
        .update({
          'nome': nomeNormalizado,
          'email': emailNormalizado == null || emailNormalizado.isEmpty
              ? null
              : emailNormalizado,
          'telefone': telefoneNormalizado == null || telefoneNormalizado.isEmpty
              ? null
              : telefoneNormalizado,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', membro.funcionarioId)
        .eq('organizacao_id', casamento.organizacaoId);
  }

  Future<void> removerDaEquipe(MembroEquipe membro) async {
    final casamento = CasamentoAtualServico.instance.casamento;
    if (casamento == null || !casamento.ehAdmin) {
      throw StateError('Somente administradoras podem remover funcionários.');
    }
    await _supabase.rpc(
      'remover_funcionario_organizacao_v1',
      params: {'p_funcionario_id': membro.funcionarioId},
    );
  }
}
