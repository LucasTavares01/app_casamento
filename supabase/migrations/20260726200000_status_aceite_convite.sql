-- O convite passa a ser aceito quando o funcionário abre aquele casamento.
ALTER TABLE public.membros_casamento
  ADD COLUMN IF NOT EXISTS convite_aceito_em timestamp with time zone;

CREATE OR REPLACE FUNCTION public.aceitar_convite_casamento_v1(
  p_casamento_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.membros_casamento
  SET convite_aceito_em = COALESCE(convite_aceito_em, now()),
      updated_at = now()
  WHERE casamento_id = p_casamento_id
    AND usuario_id = auth.uid()
    AND papel = 'funcionario'
    AND ativo;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'CONVITE_ATIVO_NAO_ENCONTRADO';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.aceitar_convite_casamento_v1(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.aceitar_convite_casamento_v1(uuid) TO authenticated;
