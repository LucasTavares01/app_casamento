-- Confirmação consolidada de presença: resposta online ou marcação manual.
-- Esta migration deve ser executada manualmente no SQL Editor do Supabase.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

CREATE TABLE IF NOT EXISTS public.confirmacoes_convidados (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  casamento_id uuid NOT NULL,
  convidado_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'aguardando'
    CHECK (status = ANY (ARRAY[
      'aguardando'::text,
      'confirmado'::text,
      'recusado'::text
    ])),
  origem text NOT NULL DEFAULT 'manual'
    CHECK (origem = ANY (ARRAY[
      'manual'::text,
      'online'::text
    ])),
  confirmado_em timestamp with time zone,
  atualizado_por_usuario_id uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT confirmacoes_convidados_pkey PRIMARY KEY (id),
  CONSTRAINT confirmacoes_convidados_casamento_fkey
    FOREIGN KEY (casamento_id) REFERENCES public.casamentos(id) ON DELETE CASCADE,
  CONSTRAINT confirmacoes_convidados_convidado_fkey
    FOREIGN KEY (convidado_id) REFERENCES public.convidados(id) ON DELETE CASCADE,
  CONSTRAINT confirmacoes_convidados_unico
    UNIQUE (casamento_id, convidado_id)
);

CREATE INDEX IF NOT EXISTS confirmacoes_convidados_casamento_status_idx
  ON public.confirmacoes_convidados (casamento_id, status);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'confirmacoes_convidados'
  ) THEN
    ALTER PUBLICATION supabase_realtime
      ADD TABLE public.confirmacoes_convidados;
  END IF;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.confirmacoes_convidados_definir_updated_at_v1()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS confirmacoes_convidados_definir_updated_at
  ON public.confirmacoes_convidados;

CREATE TRIGGER confirmacoes_convidados_definir_updated_at
BEFORE UPDATE ON public.confirmacoes_convidados
FOR EACH ROW
EXECUTE FUNCTION public.confirmacoes_convidados_definir_updated_at_v1();

ALTER TABLE public.confirmacoes_convidados ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS confirmacoes_convidados_leitura_membros
  ON public.confirmacoes_convidados;

CREATE POLICY confirmacoes_convidados_leitura_membros
ON public.confirmacoes_convidados
FOR SELECT
TO authenticated
USING (public.pode_acessar_casamento_v1(casamento_id));

REVOKE ALL ON TABLE public.confirmacoes_convidados
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.confirmacoes_convidados TO authenticated;

CREATE OR REPLACE FUNCTION public.marcar_confirmacao_convidado_v1(
  p_casamento_id uuid,
  p_convidado_id uuid,
  p_status text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_confirmacao public.confirmacoes_convidados;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION USING
      ERRCODE = '28000',
      MESSAGE = 'AUTENTICACAO_NECESSARIA';
  END IF;

  IF p_status NOT IN ('aguardando', 'confirmado') THEN
    RAISE EXCEPTION USING
      ERRCODE = '22023',
      MESSAGE = 'STATUS_DE_CONFIRMACAO_INVALIDO';
  END IF;

  IF NOT public.e_admin_casamento_v1(p_casamento_id)
     OR NOT public.casamento_aberto_para_edicao_v1(p_casamento_id) THEN
    RAISE EXCEPTION USING
      ERRCODE = '42501',
      MESSAGE = 'SEM_PERMISSAO_OU_EVENTO_FINALIZADO';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.convidados
    WHERE id = p_convidado_id
      AND casamento_id = p_casamento_id
      AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION USING
      ERRCODE = '22023',
      MESSAGE = 'CONVIDADO_NAO_ENCONTRADO';
  END IF;

  INSERT INTO public.confirmacoes_convidados (
    casamento_id,
    convidado_id,
    status,
    origem,
    confirmado_em,
    atualizado_por_usuario_id
  )
  VALUES (
    p_casamento_id,
    p_convidado_id,
    p_status,
    'manual',
    CASE WHEN p_status = 'confirmado' THEN now() ELSE NULL END,
    auth.uid()
  )
  ON CONFLICT (casamento_id, convidado_id)
  DO UPDATE SET
    status = EXCLUDED.status,
    origem = 'manual',
    confirmado_em = EXCLUDED.confirmado_em,
    atualizado_por_usuario_id = auth.uid(),
    updated_at = now()
  RETURNING * INTO v_confirmacao;

  RETURN jsonb_build_object(
    'id', v_confirmacao.id,
    'casamento_id', v_confirmacao.casamento_id,
    'convidado_id', v_confirmacao.convidado_id,
    'status', v_confirmacao.status,
    'origem', v_confirmacao.origem,
    'confirmado_em', v_confirmacao.confirmado_em
  );
END;
$$;

REVOKE ALL ON FUNCTION public.marcar_confirmacao_convidado_v1(uuid, uuid, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.marcar_confirmacao_convidado_v1(uuid, uuid, text)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.responder_convite_online_v1(
  p_token text,
  p_resposta text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_convite public.convites_online;
BEGIN
  IF p_resposta NOT IN ('confirmado', 'recusado') THEN
    RAISE EXCEPTION USING
      ERRCODE = '22023',
      MESSAGE = 'RESPOSTA_INVALIDA';
  END IF;

  SELECT *
  INTO v_convite
  FROM public.convites_online
  WHERE token_hash = encode(
    digest(btrim(COALESCE(p_token, '')), 'sha256'),
    'hex'
  );

  IF NOT FOUND THEN
    RAISE EXCEPTION USING
      ERRCODE = '22023',
      MESSAGE = 'CONVITE_INVALIDO';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.casamentos
    WHERE id = v_convite.casamento_id
      AND status NOT IN ('finalizado', 'arquivado')
  ) THEN
    RAISE EXCEPTION USING
      ERRCODE = '22023',
      MESSAGE = 'CONVITE_INDISPONIVEL';
  END IF;

  UPDATE public.convites_online
  SET resposta = p_resposta,
      respondido_em = now(),
      status = p_resposta
  WHERE id = v_convite.id
  RETURNING * INTO v_convite;

  INSERT INTO public.confirmacoes_convidados (
    casamento_id,
    convidado_id,
    status,
    origem,
    confirmado_em,
    atualizado_por_usuario_id
  )
  VALUES (
    v_convite.casamento_id,
    v_convite.convidado_id,
    p_resposta,
    'online',
    CASE WHEN p_resposta = 'confirmado' THEN now() ELSE NULL END,
    NULL
  )
  ON CONFLICT (casamento_id, convidado_id)
  DO UPDATE SET
    status = EXCLUDED.status,
    origem = 'online',
    confirmado_em = EXCLUDED.confirmado_em,
    atualizado_por_usuario_id = NULL,
    updated_at = now();

  RETURN jsonb_build_object(
    'id', v_convite.id,
    'status', v_convite.status,
    'resposta', v_convite.resposta,
    'respondido_em', v_convite.respondido_em
  );
END;
$$;

REVOKE ALL ON FUNCTION public.responder_convite_online_v1(text, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.responder_convite_online_v1(text, text)
  TO anon, authenticated;

COMMIT;

NOTIFY pgrst, 'reload schema';
