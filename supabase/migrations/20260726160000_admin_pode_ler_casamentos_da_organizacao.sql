-- O INSERT usa RETURNING no app. Para que o PostgreSQL possa devolver o
-- casamento recém-criado, a administradora da organização também precisa
-- conseguir ler imediatamente os casamentos daquele espaço de trabalho.
DROP POLICY IF EXISTS casamentos_leitura ON public.casamentos;

CREATE POLICY casamentos_leitura ON public.casamentos
  FOR SELECT TO authenticated
  USING (
    public.pode_acessar_casamento_v1(id)
    OR organizacao_id IN (
      SELECT mo.organizacao_id
      FROM public.membros_organizacao AS mo
      WHERE mo.usuario_id = auth.uid()
        AND mo.ativo = true
        AND mo.papel = 'admin'
    )
  );
