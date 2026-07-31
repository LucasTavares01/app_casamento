-- Campos neutros para qualquer composição de casal, sem interromper versões
-- antigas do aplicativo que ainda leem nome_noiva e nome_noivo.
ALTER TABLE public.casamentos
  ADD COLUMN IF NOT EXISTS nome_pessoa_1 text,
  ADD COLUMN IF NOT EXISTS nome_pessoa_2 text;

UPDATE public.casamentos
SET
  nome_pessoa_1 = COALESCE(nome_pessoa_1, nome_noiva),
  nome_pessoa_2 = COALESCE(nome_pessoa_2, nome_noivo)
WHERE nome_pessoa_1 IS NULL OR nome_pessoa_2 IS NULL;

-- A tela de casamentos e os vínculos de acesso recebem mudanças de imediato.
ALTER TABLE public.casamentos REPLICA IDENTITY FULL;
ALTER TABLE public.membros_organizacao REPLICA IDENTITY FULL;
ALTER TABLE public.membros_casamento REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'casamentos'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.casamentos;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'membros_organizacao'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.membros_organizacao;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'membros_casamento'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.membros_casamento;
  END IF;
END;
$$;
