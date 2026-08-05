-- Preserva e publica os contatos reconhecidos na importação por IA.
-- A alteração é aditiva e mantém a lista antiga intacta até a confirmação.

BEGIN;

ALTER TABLE public.convidados
  ADD COLUMN IF NOT EXISTS email text,
  ADD COLUMN IF NOT EXISTS whatsapp text;

CREATE OR REPLACE FUNCTION public.publicar_lista_casamento_v2(
  p_usuario_id uuid,
  p_casamento_id uuid,
  p_resultado jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_usuario_nome text;
  v_mesa jsonb;
  v_convidado jsonb;
  v_numero integer;
  v_mesa_id uuid;
  v_nome_convidado text;
  v_email_convidado text;
  v_whatsapp_convidado text;
  v_quantidade_mesas integer := 0;
  v_quantidade_convidados integer := 0;
  v_convidados_sem_mesa integer := 0;
  v_nova_versao bigint;
BEGIN
  IF p_usuario_id IS NULL OR p_casamento_id IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '28000', MESSAGE = 'AUTENTICACAO_NECESSARIA';
  END IF;

  SELECT u.nome
  INTO v_usuario_nome
  FROM public.usuarios_app u
  WHERE u.id = p_usuario_id
    AND u.ativo = true
    AND (
      EXISTS (
        SELECT 1
        FROM public.casamentos c
        JOIN public.membros_organizacao mo
          ON mo.organizacao_id = c.organizacao_id
        WHERE c.id = p_casamento_id
          AND mo.usuario_id = p_usuario_id
          AND mo.papel = 'admin'
          AND mo.ativo
      )
      OR EXISTS (
        SELECT 1
        FROM public.membros_casamento mc
        WHERE mc.casamento_id = p_casamento_id
          AND mc.usuario_id = p_usuario_id
          AND mc.papel = 'admin'
          AND mc.ativo
      )
    );

  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = '28000', MESSAGE = 'SEM_PERMISSAO_ADMIN';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(p_casamento_id::text, 0));

  IF p_resultado IS NULL OR jsonb_typeof(p_resultado) <> 'object' THEN
    RAISE EXCEPTION 'IMPORTACAO_INVALIDA: A prévia da lista está vazia.';
  END IF;
  IF jsonb_typeof(COALESCE(p_resultado -> 'mesas', '[]'::jsonb)) <> 'array' THEN
    RAISE EXCEPTION 'IMPORTACAO_INVALIDA: A relação de mesas é inválida.';
  END IF;
  IF jsonb_typeof(COALESCE(p_resultado -> 'convidados_sem_mesa', '[]'::jsonb)) <> 'array' THEN
    RAISE EXCEPTION 'IMPORTACAO_INVALIDA: A relação de convidados sem mesa é inválida.';
  END IF;
  IF jsonb_array_length(COALESCE(p_resultado -> 'mesas', '[]'::jsonb)) > 500 THEN
    RAISE EXCEPTION 'IMPORTACAO_INVALIDA: A lista ultrapassa 500 mesas.';
  END IF;

  CREATE TEMP TABLE _mesas_importacao_5b (
    numero integer PRIMARY KEY,
    id uuid NOT NULL,
    detalhe text
  ) ON COMMIT DROP;

  FOR v_mesa IN
    SELECT value FROM jsonb_array_elements(COALESCE(p_resultado -> 'mesas', '[]'::jsonb))
  LOOP
    IF jsonb_typeof(v_mesa) <> 'object' THEN
      RAISE EXCEPTION 'IMPORTACAO_INVALIDA: Uma das mesas possui formato inválido.';
    END IF;
    BEGIN
      v_numero := NULLIF(v_mesa ->> 'numero', '')::integer;
    EXCEPTION WHEN invalid_text_representation THEN
      RAISE EXCEPTION 'IMPORTACAO_INVALIDA: Existe uma mesa sem número válido.';
    END;
    IF v_numero IS NULL OR v_numero < 0 THEN
      RAISE EXCEPTION 'IMPORTACAO_INVALIDA: Todas as mesas precisam ter número válido.';
    END IF;
    IF EXISTS (SELECT 1 FROM _mesas_importacao_5b WHERE numero = v_numero) THEN
      RAISE EXCEPTION 'IMPORTACAO_INVALIDA: O número da Mesa % aparece mais de uma vez.', v_numero;
    END IF;
    IF jsonb_typeof(COALESCE(v_mesa -> 'convidados', '[]'::jsonb)) <> 'array' THEN
      RAISE EXCEPTION 'IMPORTACAO_INVALIDA: A lista de convidados da Mesa % é inválida.', v_numero;
    END IF;

    v_mesa_id := gen_random_uuid();
    INSERT INTO _mesas_importacao_5b (numero, id, detalhe)
    VALUES (v_numero, v_mesa_id, public.detalhe_mesa_importacao_v1(v_mesa));

    FOR v_convidado IN
      SELECT value FROM jsonb_array_elements(COALESCE(v_mesa -> 'convidados', '[]'::jsonb))
    LOOP
      v_nome_convidado := public.nome_convidado_importacao_v1(v_convidado);
      IF v_nome_convidado = '' THEN
        RAISE EXCEPTION 'IMPORTACAO_INVALIDA: A Mesa % contém um convidado sem nome.', v_numero;
      END IF;
      v_quantidade_convidados := v_quantidade_convidados + 1;
    END LOOP;
  END LOOP;

  FOR v_convidado IN
    SELECT value FROM jsonb_array_elements(COALESCE(p_resultado -> 'convidados_sem_mesa', '[]'::jsonb))
  LOOP
    v_nome_convidado := public.nome_convidado_importacao_v1(v_convidado);
    IF v_nome_convidado = '' THEN
      RAISE EXCEPTION 'IMPORTACAO_INVALIDA: Existe um convidado sem nome.';
    END IF;
    v_quantidade_convidados := v_quantidade_convidados + 1;
    v_convidados_sem_mesa := v_convidados_sem_mesa + 1;
  END LOOP;

  IF v_quantidade_convidados = 0 THEN
    RAISE EXCEPTION 'IMPORTACAO_INVALIDA: Nenhum convidado foi identificado.';
  END IF;
  IF v_quantidade_convidados > 10000 THEN
    RAISE EXCEPTION 'IMPORTACAO_INVALIDA: A lista ultrapassa 10000 convidados.';
  END IF;

  INSERT INTO public.controle_lista (casamento_id, id, versao, updated_at)
  VALUES (p_casamento_id, 1, 1, now())
  ON CONFLICT (casamento_id) DO NOTHING;

  UPDATE public.controle_lista
  SET versao = versao + 1, updated_at = now()
  WHERE casamento_id = p_casamento_id
  RETURNING versao INTO v_nova_versao;

  DELETE FROM public.chat WHERE casamento_id = p_casamento_id;
  DELETE FROM public.eventos_checkin WHERE casamento_id = p_casamento_id;
  DELETE FROM public.conflitos_sincronizacao WHERE casamento_id = p_casamento_id;
  DELETE FROM public.operacoes_aplicadas_app WHERE casamento_id = p_casamento_id;
  DELETE FROM public.convidados WHERE casamento_id = p_casamento_id;
  DELETE FROM public.staff WHERE casamento_id = p_casamento_id;
  DELETE FROM public.mesas WHERE casamento_id = p_casamento_id;

  INSERT INTO public.mesas (id, casamento_id, numero, detalhe, modificado_por_usuario_id)
  SELECT id, p_casamento_id, numero, detalhe, p_usuario_id
  FROM _mesas_importacao_5b
  ORDER BY numero;

  v_quantidade_mesas := (SELECT count(*) FROM _mesas_importacao_5b);
  v_quantidade_convidados := 0;

  FOR v_mesa IN
    SELECT value FROM jsonb_array_elements(COALESCE(p_resultado -> 'mesas', '[]'::jsonb))
  LOOP
    v_numero := (v_mesa ->> 'numero')::integer;
    SELECT id INTO v_mesa_id FROM _mesas_importacao_5b WHERE numero = v_numero;
    FOR v_convidado IN
      SELECT value FROM jsonb_array_elements(COALESCE(v_mesa -> 'convidados', '[]'::jsonb))
    LOOP
      v_nome_convidado := public.nome_convidado_importacao_v1(v_convidado);
      v_email_convidado := NULLIF(lower(btrim(v_convidado ->> 'email')), '');
      v_whatsapp_convidado := NULLIF(btrim(v_convidado ->> 'whatsapp'), '');
      INSERT INTO public.convidados (
        casamento_id, nome, email, whatsapp, mesa_id, chegou, tem_conflito,
        eventos_atuais, modificado_por_usuario_id
      ) VALUES (
        p_casamento_id, v_nome_convidado, v_email_convidado, v_whatsapp_convidado,
        v_mesa_id, false, false, ARRAY[]::uuid[], p_usuario_id
      );
      v_quantidade_convidados := v_quantidade_convidados + 1;
    END LOOP;
  END LOOP;

  v_convidados_sem_mesa := 0;
  FOR v_convidado IN
    SELECT value FROM jsonb_array_elements(COALESCE(p_resultado -> 'convidados_sem_mesa', '[]'::jsonb))
  LOOP
    v_nome_convidado := public.nome_convidado_importacao_v1(v_convidado);
    v_email_convidado := NULLIF(lower(btrim(v_convidado ->> 'email')), '');
    v_whatsapp_convidado := NULLIF(btrim(v_convidado ->> 'whatsapp'), '');
    INSERT INTO public.convidados (
      casamento_id, nome, email, whatsapp, mesa_id, chegou, tem_conflito,
      eventos_atuais, modificado_por_usuario_id
    ) VALUES (
      p_casamento_id, v_nome_convidado, v_email_convidado, v_whatsapp_convidado,
      NULL, false, false, ARRAY[]::uuid[], p_usuario_id
    );
    v_quantidade_convidados := v_quantidade_convidados + 1;
    v_convidados_sem_mesa := v_convidados_sem_mesa + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'versao', v_nova_versao,
    'mesas', v_quantidade_mesas,
    'convidados', v_quantidade_convidados,
    'convidados_sem_mesa', v_convidados_sem_mesa,
    'publicado_por', v_usuario_nome
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.publicar_lista_casamento_v2(uuid, uuid, jsonb)
TO service_role;

COMMIT;

NOTIFY pgrst, 'reload schema';
