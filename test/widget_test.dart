import 'package:app_casamento/servicos/casamento_atual_servico.dart';
import 'package:app_casamento/servicos/recepcao_confirmacoes_servico.dart';
import 'package:app_casamento/servicos/sessao_servico.dart';
import 'package:app_casamento/telas/tela_convites_online.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('casamento mostra os nomes do casal quando disponíveis', () {
    const casamento = CasamentoAtual(
      id: 'casamento-1',
      organizacaoId: 'organizacao-1',
      titulo: 'Casamento de maio',
      nomePessoa1: 'Marina',
      nomePessoa2: 'João',
      dataEvento: null,
      horarioEvento: null,
      localEvento: null,
      status: 'rascunho',
      papel: PapelNoCasamento.admin,
    );

    expect(casamento.descricao, 'Marina e João');
    expect(casamento.ehAdmin, isTrue);
  });

  test('troca de sessão é bloqueada quando há alterações offline', () {
    expect(
      () => validarTrocaSessaoSemPendencias(2),
      throwsA(
        isA<AlteracoesPendentesSessaoException>()
            .having((erro) => erro.quantidade, 'quantidade', 2)
            .having(
              (erro) => erro.mensagem,
              'mensagem',
              contains('Sincronize antes de sair'),
            ),
      ),
    );

    expect(() => validarTrocaSessaoSemPendencias(0), returnsNormally);
  });

  test('normaliza corretamente telefone nacional com DDD 55', () {
    expect(normalizarTelefoneWhatsApp('55 91234-5678'), '5555912345678');
    expect(normalizarTelefoneWhatsApp('+55 (55) 91234-5678'), '5555912345678');
    expect(normalizarTelefoneWhatsApp('11912345678'), '5511912345678');
    expect(normalizarTelefoneWhatsApp('123'), isNull);
  });

  test('rollback otimista remove somente a confirmação da própria chamada', () {
    final registros = [
      {'id': 'otimista-a-1', 'convidado_id': 'a', 'status': 'confirmado'},
      {'id': 'otimista-b-1', 'convidado_id': 'b', 'status': 'confirmado'},
    ];

    expect(removerConfirmacaoOtimista(registros, 'otimista-a-1'), [
      {'id': 'otimista-b-1', 'convidado_id': 'b', 'status': 'confirmado'},
    ]);
  });
}
