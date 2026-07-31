import 'package:app_casamento/servicos/casamento_atual_servico.dart';
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
}
