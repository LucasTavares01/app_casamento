-- Permite que um funcionário que já participou de um evento consulte o seu
-- histórico depois que o administrador o finaliza, sem devolver permissão de
-- alteração. A política de escrita continua bloqueada pelo status finalizado.

CREATE OR REPLACE FUNCTION public.pode_acessar_casamento_v1(
  p_casamento_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.casamentos c
    JOIN public.membros_organizacao mo
      ON mo.organizacao_id = c.organizacao_id
    WHERE c.id = p_casamento_id
      AND mo.usuario_id = auth.uid()
      AND mo.ativo
  ) OR EXISTS (
    SELECT 1
    FROM public.membros_casamento mc
    JOIN public.casamentos c ON c.id = mc.casamento_id
    WHERE mc.casamento_id = p_casamento_id
      AND mc.usuario_id = auth.uid()
      AND (
        mc.ativo
        OR c.status IN ('finalizado', 'arquivado')
      )
  );
$$;

REVOKE ALL ON FUNCTION public.pode_acessar_casamento_v1(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.pode_acessar_casamento_v1(uuid)
  TO authenticated;
