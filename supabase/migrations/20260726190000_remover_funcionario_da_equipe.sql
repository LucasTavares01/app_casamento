-- Exclui uma pessoa da equipe permanente e revoga seu acesso a todos os
-- casamentos da cerimonialista, sem apagar a conta dela do aplicativo.
CREATE OR REPLACE FUNCTION public.remover_funcionario_organizacao_v1(
  p_funcionario_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_organizacao_id uuid;
  v_usuario_id uuid;
BEGIN
  SELECT organizacao_id, usuario_id
  INTO v_organizacao_id, v_usuario_id
  FROM public.funcionarios_organizacao
  WHERE id = p_funcionario_id;

  IF v_organizacao_id IS NULL OR NOT EXISTS (
    SELECT 1
    FROM public.membros_organizacao mo
    WHERE mo.organizacao_id = v_organizacao_id
      AND mo.usuario_id = auth.uid()
      AND mo.ativo
      AND mo.papel = 'admin'
  ) THEN
    RAISE EXCEPTION 'SEM_PERMISSAO_PARA_REMOVER_FUNCIONARIO';
  END IF;

  UPDATE public.membros_casamento mc
  SET ativo = false, updated_at = now()
  FROM public.casamentos c
  WHERE c.id = mc.casamento_id
    AND c.organizacao_id = v_organizacao_id
    AND mc.usuario_id = v_usuario_id
    AND mc.papel = 'funcionario'
    AND mc.ativo;

  DELETE FROM public.funcionarios_organizacao
  WHERE id = p_funcionario_id;
END;
$$;

REVOKE ALL ON FUNCTION public.remover_funcionario_organizacao_v1(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.remover_funcionario_organizacao_v1(uuid) TO authenticated;
