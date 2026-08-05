-- Convites online por convidado.
-- Esta migration é aditiva: não altera os gatilhos atuais nem o histórico
-- de check-in. Os novos campos são opcionais para manter compatibilidade com
-- as versões do aplicativo que já estão em produção.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

ALTER TABLE public.convidados
  ADD COLUMN IF NOT EXISTS email text,
  ADD COLUMN IF NOT EXISTS whatsapp text;

CREATE TABLE IF NOT EXISTS public.convites_online (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  casamento_id uuid NOT NULL,
  convidado_id uuid NOT NULL,
  token_hash text NOT NULL,
  status text NOT NULL DEFAULT 'nao_enviado'
    CHECK (status = ANY (ARRAY[
      'nao_enviado'::text,
      'enviado'::text,
      'aberto'::text,
      'confirmado'::text,
      'recusado'::text
    ])),
  canais_enviados text[] NOT NULL DEFAULT ARRAY[]::text[],
  ultimo_canal text,
  enviado_em timestamp with time zone,
  aberto_em timestamp with time zone,
  respondido_em timestamp with time zone,
  resposta text CHECK (resposta IS NULL OR resposta = ANY (ARRAY[
    'confirmado'::text,
    'recusado'::text
  ])),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT convites_online_pkey PRIMARY KEY (id),
  CONSTRAINT convites_online_casamento_fkey
    FOREIGN KEY (casamento_id) REFERENCES public.casamentos(id) ON DELETE CASCADE,
  CONSTRAINT convites_online_convidado_fkey
    FOREIGN KEY (convidado_id) REFERENCES public.convidados(id) ON DELETE CASCADE,
  CONSTRAINT convites_online_token_unico UNIQUE (token_hash),
  CONSTRAINT convites_online_convidado_unico UNIQUE (casamento_id, convidado_id)
);

CREATE INDEX IF NOT EXISTS convites_online_casamento_status_idx
  ON public.convites_online (casamento_id, status);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'convites_online'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.convites_online;
  END IF;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.convites_online_definir_updated_at_v1()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS convites_online_definir_updated_at
  ON public.convites_online;

CREATE TRIGGER convites_online_definir_updated_at
BEFORE UPDATE ON public.convites_online
FOR EACH ROW
EXECUTE FUNCTION public.convites_online_definir_updated_at_v1();

ALTER TABLE public.convites_online ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS convites_online_leitura_membros
  ON public.convites_online;

CREATE POLICY convites_online_leitura_membros
ON public.convites_online
FOR SELECT
TO authenticated
USING (public.pode_acessar_casamento_v1(casamento_id));

REVOKE ALL ON TABLE public.convites_online FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.convites_online TO authenticated;

CREATE OR REPLACE FUNCTION public.criar_convite_online_v1(
  p_casamento_id uuid,
  p_convidado_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_token text;
  v_token_hash text;
  v_convite public.convites_online;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '28000', MESSAGE = 'AUTENTICACAO_NECESSARIA';
  END IF;

  IF NOT public.e_admin_casamento_v1(p_casamento_id)
     OR NOT public.casamento_aberto_para_edicao_v1(p_casamento_id) THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'SEM_PERMISSAO_OU_EVENTO_FINALIZADO';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.convidados g
    WHERE g.id = p_convidado_id
      AND g.casamento_id = p_casamento_id
      AND g.deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'CONVIDADO_NAO_ENCONTRADO';
  END IF;

  v_token := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
  v_token_hash := encode(digest(v_token, 'sha256'), 'hex');

  INSERT INTO public.convites_online (
    casamento_id,
    convidado_id,
    token_hash
  )
  VALUES (
    p_casamento_id,
    p_convidado_id,
    v_token_hash
  )
  ON CONFLICT (casamento_id, convidado_id)
  DO UPDATE SET
    token_hash = EXCLUDED.token_hash,
    updated_at = now();

  SELECT *
  INTO v_convite
  FROM public.convites_online
  WHERE casamento_id = p_casamento_id
    AND convidado_id = p_convidado_id;

  RETURN jsonb_build_object(
    'id', v_convite.id,
    'token', v_token,
    'casamento_id', v_convite.casamento_id,
    'convidado_id', v_convite.convidado_id,
    'status', v_convite.status
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.registrar_envio_convite_online_v1(
  p_convite_id uuid,
  p_canal text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_convite public.convites_online;
  v_canais text[];
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '28000', MESSAGE = 'AUTENTICACAO_NECESSARIA';
  END IF;

  IF p_canal NOT IN ('whatsapp', 'email') THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'CANAL_INVALIDO';
  END IF;

  SELECT *
  INTO v_convite
  FROM public.convites_online
  WHERE id = p_convite_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'CONVITE_NAO_ENCONTRADO';
  END IF;

  IF NOT public.e_admin_casamento_v1(v_convite.casamento_id)
     OR NOT public.casamento_aberto_para_edicao_v1(v_convite.casamento_id) THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'SEM_PERMISSAO_OU_EVENTO_FINALIZADO';
  END IF;

  v_canais := v_convite.canais_enviados;
  IF NOT (p_canal = ANY (v_canais)) THEN
    v_canais := array_append(v_canais, p_canal);
  END IF;

  UPDATE public.convites_online
  SET canais_enviados = v_canais,
      ultimo_canal = p_canal,
      enviado_em = COALESCE(enviado_em, now()),
      status = CASE
        WHEN status IN ('confirmado', 'recusado') THEN status
        ELSE 'enviado'
      END
  WHERE id = p_convite_id
  RETURNING * INTO v_convite;

  RETURN jsonb_build_object(
    'id', v_convite.id,
    'status', v_convite.status,
    'canais_enviados', to_jsonb(v_convite.canais_enviados),
    'enviado_em', v_convite.enviado_em
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.obter_convite_online_v1(p_token text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  v_convite public.convites_online;
  v_evento public.casamentos;
  v_convidado public.convidados;
BEGIN
  IF p_token IS NULL OR length(btrim(p_token)) < 32 THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'CONVITE_INVALIDO';
  END IF;

  SELECT *
  INTO v_convite
  FROM public.convites_online
  WHERE token_hash = encode(digest(btrim(p_token), 'sha256'), 'hex');

  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'CONVITE_INVALIDO';
  END IF;

  SELECT * INTO v_evento
  FROM public.casamentos
  WHERE id = v_convite.casamento_id;

  SELECT * INTO v_convidado
  FROM public.convidados
  WHERE id = v_convite.convidado_id
    AND deleted_at IS NULL;

  IF v_evento.id IS NULL OR v_convidado.id IS NULL
     OR v_evento.status IN ('finalizado', 'arquivado') THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'CONVITE_INDISPONIVEL';
  END IF;

  UPDATE public.convites_online
  SET aberto_em = COALESCE(aberto_em, now()),
      status = CASE WHEN status = 'nao_enviado' THEN 'aberto' ELSE status END
  WHERE id = v_convite.id;

  RETURN jsonb_build_object(
    'id', v_convite.id,
    'casamento_id', v_evento.id,
    'titulo', v_evento.titulo,
    'tipo_evento', v_evento.tipo_evento,
    'data_evento', v_evento.data_evento,
    'hora_evento', v_evento.hora_evento,
    'local_evento', v_evento.local_evento,
    'convidado_nome', v_convidado.nome,
    'status', v_convite.status,
    'resposta', v_convite.resposta
  );
END;
$$;

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
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'RESPOSTA_INVALIDA';
  END IF;

  SELECT *
  INTO v_convite
  FROM public.convites_online
  WHERE token_hash = encode(digest(btrim(COALESCE(p_token, '')), 'sha256'), 'hex');

  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'CONVITE_INVALIDO';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.casamentos
    WHERE id = v_convite.casamento_id
      AND status NOT IN ('finalizado', 'arquivado')
  ) THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'CONVITE_INDISPONIVEL';
  END IF;

  UPDATE public.convites_online
  SET resposta = p_resposta,
      respondido_em = now(),
      status = p_resposta
  WHERE id = v_convite.id
  RETURNING * INTO v_convite;

  RETURN jsonb_build_object(
    'id', v_convite.id,
    'status', v_convite.status,
    'resposta', v_convite.resposta,
    'respondido_em', v_convite.respondido_em
  );
END;
$$;

REVOKE ALL ON FUNCTION public.criar_convite_online_v1(uuid, uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.registrar_envio_convite_online_v1(uuid, text)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.obter_convite_online_v1(text)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.responder_convite_online_v1(text, text)
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.criar_convite_online_v1(uuid, uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.registrar_envio_convite_online_v1(uuid, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.obter_convite_online_v1(text)
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.responder_convite_online_v1(text, text)
  TO anon, authenticated;

COMMIT;

NOTIFY pgrst, 'reload schema';
