-- Equipe permanente da cerimonialista, separada dos convites de cada evento.
CREATE TABLE IF NOT EXISTS public.funcionarios_organizacao (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organizacao_id uuid NOT NULL REFERENCES public.organizacoes(id) ON DELETE CASCADE,
  usuario_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  nome text NOT NULL CHECK (char_length(btrim(nome)) >= 2),
  email text NOT NULL,
  ativo boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  UNIQUE (organizacao_id, usuario_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS funcionarios_organizacao_email_unico
  ON public.funcionarios_organizacao (organizacao_id, lower(email));

-- Preserva os funcionários que já haviam sido convidados para eventos.
INSERT INTO public.funcionarios_organizacao (organizacao_id, usuario_id, nome, email)
SELECT DISTINCT ON (c.organizacao_id, mc.usuario_id)
  c.organizacao_id,
  mc.usuario_id,
  COALESCE(NULLIF(btrim(u.nome), ''), split_part(COALESCE(u.email, 'Funcionário'), '@', 1)),
  COALESCE(u.email, mc.usuario_id::text || '@sem-email.local')
FROM public.membros_casamento mc
JOIN public.casamentos c ON c.id = mc.casamento_id
JOIN public.usuarios_app u ON u.id = mc.usuario_id
WHERE mc.papel = 'funcionario'
ON CONFLICT (organizacao_id, usuario_id) DO NOTHING;

ALTER TABLE public.funcionarios_organizacao ENABLE ROW LEVEL SECURITY;

CREATE POLICY funcionarios_organizacao_leitura ON public.funcionarios_organizacao
  FOR SELECT TO authenticated
  USING (
    organizacao_id IN (
      SELECT mo.organizacao_id
      FROM public.membros_organizacao mo
      WHERE mo.usuario_id = auth.uid() AND mo.ativo AND mo.papel = 'admin'
    )
  );

CREATE POLICY funcionarios_organizacao_gerenciamento ON public.funcionarios_organizacao
  FOR ALL TO authenticated
  USING (
    organizacao_id IN (
      SELECT mo.organizacao_id
      FROM public.membros_organizacao mo
      WHERE mo.usuario_id = auth.uid() AND mo.ativo AND mo.papel = 'admin'
    )
  )
  WITH CHECK (
    organizacao_id IN (
      SELECT mo.organizacao_id
      FROM public.membros_organizacao mo
      WHERE mo.usuario_id = auth.uid() AND mo.ativo AND mo.papel = 'admin'
    )
  );

ALTER TABLE public.funcionarios_organizacao REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'funcionarios_organizacao'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.funcionarios_organizacao;
  END IF;
END;
$$;

-- Ao encerrar um evento, as administradoras conservam o histórico, mas os
-- funcionários deixam de ter acesso imediatamente.
CREATE OR REPLACE FUNCTION public.finalizar_casamento_v1(p_casamento_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_organizacao_id uuid;
BEGIN
  SELECT organizacao_id INTO v_organizacao_id
  FROM public.casamentos
  WHERE id = p_casamento_id;

  IF v_organizacao_id IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.membros_organizacao mo
    WHERE mo.organizacao_id = v_organizacao_id
      AND mo.usuario_id = auth.uid()
      AND mo.ativo AND mo.papel = 'admin'
  ) THEN
    RAISE EXCEPTION 'SEM_PERMISSAO_PARA_ENCERRAR_CASAMENTO';
  END IF;

  UPDATE public.casamentos
  SET status = 'finalizado', finalizado_em = COALESCE(finalizado_em, now()), updated_at = now()
  WHERE id = p_casamento_id;

  UPDATE public.membros_casamento
  SET ativo = false, updated_at = now()
  WHERE casamento_id = p_casamento_id AND papel = 'funcionario' AND ativo;
END;
$$;

REVOKE ALL ON FUNCTION public.finalizar_casamento_v1(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.finalizar_casamento_v1(uuid) TO authenticated;
