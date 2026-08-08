-- Convite próprio do ConfirmaAi para evitar que leitores de e-mail/WhatsApp
-- consumam os links de OTP do Supabase antes do usuário tocar neles.
CREATE TABLE IF NOT EXISTS public.convites_funcionario_app (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  casamento_id uuid NOT NULL REFERENCES public.casamentos(id) ON DELETE CASCADE,
  organizacao_id uuid NOT NULL REFERENCES public.organizacoes(id) ON DELETE CASCADE,
  usuario_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  email text NOT NULL,
  token_hash text NOT NULL UNIQUE,
  expira_em timestamptz NOT NULL DEFAULT (now() + interval '30 days'),
  usado_em timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT convites_funcionario_app_casamento_usuario_unico
    UNIQUE (casamento_id, usuario_id)
);

CREATE INDEX IF NOT EXISTS convites_funcionario_app_token_idx
  ON public.convites_funcionario_app(token_hash);

ALTER TABLE public.convites_funcionario_app ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.convites_funcionario_app FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS convites_funcionario_app_updated_at
  ON public.convites_funcionario_app;

CREATE TRIGGER convites_funcionario_app_updated_at
BEFORE UPDATE ON public.convites_funcionario_app
FOR EACH ROW
EXECUTE FUNCTION public.definir_updated_at();
