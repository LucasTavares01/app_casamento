-- Modos seguros para importar uma lista de convidados.
--
-- carregar_nova: substitui mesas e convidados e zera confirmações, check-ins
-- e conflitos, mantendo o evento e a equipe.
-- atualizar_existente: atualiza os dados identificados, adiciona registros
-- novos e preserva confirmações, check-ins e histórico.

BEGIN;

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
  v_modo text;
  v_mesa jsonb;
  v_convidado jsonb;
  v_numero integer;
  v_mesa_id uuid;
  v_detalhe_mesa text;
  v_nome_convidado text;
  v_email_convidado text;
  v_whatsapp_convidado text;
  v_convidado_id uuid;
  v_quantidade_mesas integer := 0;
  v_quantidade_convidados integer := 0;
  v_convidados_sem_mesa integer := 0;
  v_adicionados integer := 0;
  v_atualizados integer := 0;
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

  v_modo := COALESCE(
    NULLIF(lower(btrim(p_resultado ->> 'modo_importacao')), ''),
    'atualizar_existente'
  );

  IF v_modo NOT IN ('carregar_nova', 'atualizar_existente') THEN
    RAISE EXCEPTION 'IMPORTACAO_INVALIDA: O modo de importação é inválido.';
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

  CREATE TEMP TABLE _mesas_importacao_segura (
    numero integer PRIMARY KEY,
    detalhe text
  ) ON COMMIT DROP;

  CREATE TEMP TABLE _convidados_importacao_processados (
    id uuid PRIMARY KEY
  ) ON COMMIT DROP;

  CREATE TEMP TABLE _contadores_importacao (
    adicionados integer NOT NULL DEFAULT 0,
    atualizados integer NOT NULL DEFAULT 0
  ) ON COMMIT DROP;
  INSERT INTO _contadores_importacao DEFAULT VALUES;

  -- Toda a prévia é validada antes de qualquer alteração persistente.
  FOR v_mesa IN
    SELECT value
    FROM jsonb_array_elements(COALESCE(p_resultado -> 'mesas', '[]'::jsonb))
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
    IF EXISTS (
      SELECT 1 FROM _mesas_importacao_segura WHERE numero = v_numero
    ) THEN
      RAISE EXCEPTION 'IMPORTACAO_INVALIDA: O número da Mesa % aparece mais de uma vez.', v_numero;
    END IF;
    IF jsonb_typeof(COALESCE(v_mesa -> 'convidados', '[]'::jsonb)) <> 'array' THEN
      RAISE EXCEPTION 'IMPORTACAO_INVALIDA: A lista de convidados da Mesa % é inválida.', v_numero;
    END IF;

    INSERT INTO _mesas_importacao_segura (numero, detalhe)
    VALUES (v_numero, public.detalhe_mesa_importacao_v1(v_mesa));

    FOR v_convidado IN
      SELECT value
      FROM jsonb_array_elements(COALESCE(v_mesa -> 'convidados', '[]'::jsonb))
    LOOP
      v_nome_convidado := public.nome_convidado_importacao_v1(v_convidado);
      IF v_nome_convidado = '' THEN
        RAISE EXCEPTION 'IMPORTACAO_INVALIDA: A Mesa % contém um convidado sem nome.', v_numero;
      END IF;
    END LOOP;
  END LOOP;

  FOR v_convidado IN
    SELECT value
    FROM jsonb_array_elements(COALESCE(p_resultado -> 'convidados_sem_mesa', '[]'::jsonb))
  LOOP
    v_nome_convidado := public.nome_convidado_importacao_v1(v_convidado);
    IF v_nome_convidado = '' THEN
      RAISE EXCEPTION 'IMPORTACAO_INVALIDA: Existe um convidado sem nome.';
    END IF;
  END LOOP;

  IF (
    jsonb_array_length(COALESCE(p_resultado -> 'convidados_sem_mesa', '[]'::jsonb))
    + COALESCE((
      SELECT sum(jsonb_array_length(COALESCE(item -> 'convidados', '[]'::jsonb)))
      FROM jsonb_array_elements(COALESCE(p_resultado -> 'mesas', '[]'::jsonb)) item
    ), 0)
  ) = 0 THEN
    RAISE EXCEPTION 'IMPORTACAO_INVALIDA: Nenhum convidado foi identificado.';
  END IF;

  IF (
    jsonb_array_length(COALESCE(p_resultado -> 'convidados_sem_mesa', '[]'::jsonb))
    + COALESCE((
      SELECT sum(jsonb_array_length(COALESCE(item -> 'convidados', '[]'::jsonb)))
      FROM jsonb_array_elements(COALESCE(p_resultado -> 'mesas', '[]'::jsonb)) item
    ), 0)
  ) > 10000 THEN
    RAISE EXCEPTION 'IMPORTACAO_INVALIDA: A lista ultrapassa 10000 convidados.';
  END IF;

  INSERT INTO public.controle_lista (casamento_id, id, versao, updated_at)
  VALUES (p_casamento_id, 1, 1, now())
  ON CONFLICT (casamento_id) DO NOTHING;

  UPDATE public.controle_lista
  SET versao = versao + 1, updated_at = now()
  WHERE casamento_id = p_casamento_id
  RETURNING versao INTO v_nova_versao;

  IF v_modo = 'carregar_nova' THEN
    -- A nova lista começa do zero, mas o evento e a equipe permanecem.
    DELETE FROM public.eventos_checkin
    WHERE casamento_id = p_casamento_id;
    DELETE FROM public.conflitos_sincronizacao
    WHERE casamento_id = p_casamento_id;
    DELETE FROM public.operacoes_aplicadas_app
    WHERE casamento_id = p_casamento_id;
    DELETE FROM public.convidados
    WHERE casamento_id = p_casamento_id;
    DELETE FROM public.mesas
    WHERE casamento_id = p_casamento_id;
  END IF;

  -- Mesas são reaproveitadas pelo número. No modo de atualização, o detalhe
  -- da mesa também é atualizado quando veio preenchido no arquivo.
  FOR v_mesa IN
    SELECT value
    FROM jsonb_array_elements(COALESCE(p_resultado -> 'mesas', '[]'::jsonb))
  LOOP
    v_numero := (v_mesa ->> 'numero')::integer;
    SELECT detalhe
    INTO v_detalhe_mesa
    FROM _mesas_importacao_segura
    WHERE numero = v_numero;

    SELECT id
    INTO v_mesa_id
    FROM public.mesas
    WHERE casamento_id = p_casamento_id
      AND numero = v_numero
    ORDER BY updated_at DESC NULLS LAST
    LIMIT 1;

    IF FOUND THEN
      IF v_modo = 'atualizar_existente' AND NULLIF(btrim(v_detalhe_mesa), '') IS NOT NULL THEN
        UPDATE public.mesas
        SET detalhe = v_detalhe_mesa,
            updated_at = now(),
            modificado_por_usuario_id = p_usuario_id
        WHERE id = v_mesa_id;
      END IF;
    ELSE
      v_mesa_id := gen_random_uuid();
      INSERT INTO public.mesas (
        id, casamento_id, numero, detalhe, modificado_por_usuario_id
      )
      VALUES (
        v_mesa_id, p_casamento_id, v_numero, v_detalhe_mesa, p_usuario_id
      );
      UPDATE _contadores_importacao
      SET adicionados = adicionados + 1
      WHERE true;
    END IF;

    FOR v_convidado IN
      SELECT value
      FROM jsonb_array_elements(COALESCE(v_mesa -> 'convidados', '[]'::jsonb))
    LOOP
      PERFORM public.processar_convidado_importacao_v1(
        p_casamento_id,
        p_usuario_id,
        v_mesa_id,
        v_convidado,
        v_modo
      );
    END LOOP;
  END LOOP;

  FOR v_convidado IN
    SELECT value
    FROM jsonb_array_elements(COALESCE(p_resultado -> 'convidados_sem_mesa', '[]'::jsonb))
  LOOP
    PERFORM public.processar_convidado_importacao_v1(
      p_casamento_id,
      p_usuario_id,
      NULL,
      v_convidado,
      v_modo
    );
    v_convidados_sem_mesa := v_convidados_sem_mesa + 1;
  END LOOP;

  SELECT adicionados, atualizados
  INTO v_adicionados, v_atualizados
  FROM _contadores_importacao;

  SELECT count(*)
  INTO v_quantidade_mesas
  FROM public.mesas
  WHERE casamento_id = p_casamento_id
    AND deleted_at IS NULL;

  SELECT count(*)
  INTO v_quantidade_convidados
  FROM public.convidados
  WHERE casamento_id = p_casamento_id
    AND deleted_at IS NULL;

  SELECT count(*)
  INTO v_convidados_sem_mesa
  FROM public.convidados
  WHERE casamento_id = p_casamento_id
    AND deleted_at IS NULL
    AND mesa_id IS NULL;

  RETURN jsonb_build_object(
    'versao', v_nova_versao,
    'mesas', v_quantidade_mesas,
    'convidados', v_quantidade_convidados,
    'convidados_sem_mesa', v_convidados_sem_mesa,
    'adicionados', v_adicionados,
    'atualizados', v_atualizados,
    'publicado_por', v_usuario_nome
  );
END;
$$;

-- A procedure auxiliar é criada separadamente para manter a operação
-- transacional e concentrar a identificação por e-mail, WhatsApp ou nome.
CREATE OR REPLACE FUNCTION public.processar_convidado_importacao_v1(
  p_casamento_id uuid,
  p_usuario_id uuid,
  p_mesa_id uuid,
  p_convidado jsonb,
  p_modo text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_nome text;
  v_email text;
  v_whatsapp text;
  v_observacao text;
  v_whatsapp_digitos text;
  v_id uuid;
BEGIN
  v_nome := public.nome_convidado_importacao_v1(p_convidado);
  v_email := NULLIF(lower(btrim(p_convidado ->> 'email')), '');
  v_whatsapp := NULLIF(btrim(p_convidado ->> 'whatsapp'), '');
  v_observacao := NULLIF(
    btrim(COALESCE(p_convidado ->> 'observacao', p_convidado ->> 'descricao', '')),
    ''
  );
  v_whatsapp_digitos := NULLIF(regexp_replace(COALESCE(v_whatsapp, ''), '[^0-9]', '', 'g'), '');

  IF v_email IS NOT NULL THEN
    SELECT c.id
    INTO v_id
    FROM public.convidados c
    WHERE c.casamento_id = p_casamento_id
      AND c.deleted_at IS NULL
      AND lower(btrim(COALESCE(c.email, ''))) = v_email
      AND NOT EXISTS (
        SELECT 1
        FROM _convidados_importacao_processados p
        WHERE p.id = c.id
      )
    ORDER BY c.updated_at DESC NULLS LAST
    LIMIT 1;
  END IF;

  IF v_id IS NULL AND v_whatsapp_digitos IS NOT NULL THEN
    SELECT c.id
    INTO v_id
    FROM public.convidados c
    WHERE c.casamento_id = p_casamento_id
      AND c.deleted_at IS NULL
      AND regexp_replace(COALESCE(c.whatsapp, ''), '[^0-9]', '', 'g') = v_whatsapp_digitos
      AND NOT EXISTS (
        SELECT 1
        FROM _convidados_importacao_processados p
        WHERE p.id = c.id
      )
    ORDER BY c.updated_at DESC NULLS LAST
    LIMIT 1;
  END IF;

  -- Nome só é usado quando há exatamente um candidato com o mesmo nome,
  -- evitando atualizar a pessoa errada em casos de homônimos.
  IF v_id IS NULL THEN
    SELECT c.id
    INTO v_id
    FROM public.convidados c
    WHERE c.casamento_id = p_casamento_id
      AND c.deleted_at IS NULL
      AND lower(regexp_replace(btrim(c.nome), '\s+', ' ', 'g')) =
          lower(regexp_replace(btrim(v_nome), '\s+', ' ', 'g'))
      AND NOT EXISTS (
        SELECT 1
        FROM _convidados_importacao_processados p
        WHERE p.id = c.id
      )
      AND 1 = (
        SELECT count(*)
        FROM public.convidados c2
        WHERE c2.casamento_id = p_casamento_id
          AND c2.deleted_at IS NULL
          AND lower(regexp_replace(btrim(c2.nome), '\s+', ' ', 'g')) =
              lower(regexp_replace(btrim(v_nome), '\s+', ' ', 'g'))
          AND NOT EXISTS (
            SELECT 1
            FROM _convidados_importacao_processados p2
            WHERE p2.id = c2.id
          )
      )
    LIMIT 1;
  END IF;

  IF v_id IS NOT NULL THEN
    IF p_modo = 'atualizar_existente' THEN
      UPDATE public.convidados
      SET nome = v_nome,
          email = COALESCE(v_email, email),
          whatsapp = COALESCE(v_whatsapp, whatsapp),
          observacao = COALESCE(v_observacao, observacao),
          mesa_id = COALESCE(p_mesa_id, mesa_id),
          updated_at = now(),
          modificado_por_usuario_id = p_usuario_id
      WHERE id = v_id;
      UPDATE _contadores_importacao
      SET atualizados = atualizados + 1
      WHERE true;
    END IF;
    INSERT INTO _convidados_importacao_processados (id)
    VALUES (v_id)
    ON CONFLICT DO NOTHING;
    RETURN;
  END IF;

  v_id := gen_random_uuid();
  INSERT INTO public.convidados (
    id, casamento_id, nome, email, whatsapp, observacao, mesa_id, chegou,
    tem_conflito, eventos_atuais, modificado_por_usuario_id
  )
  VALUES (
    v_id, p_casamento_id, v_nome, v_email, v_whatsapp, v_observacao, p_mesa_id,
    false, false, ARRAY[]::uuid[], p_usuario_id
  );
  INSERT INTO _convidados_importacao_processados (id)
  VALUES (v_id)
  ON CONFLICT DO NOTHING;
  UPDATE _contadores_importacao
  SET adicionados = adicionados + 1
  WHERE true;
END;
$$;

REVOKE ALL ON FUNCTION public.publicar_lista_casamento_v2(uuid, uuid, jsonb)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.publicar_lista_casamento_v2(uuid, uuid, jsonb)
TO service_role;

REVOKE ALL ON FUNCTION public.processar_convidado_importacao_v1(
  uuid, uuid, uuid, jsonb, text
)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.processar_convidado_importacao_v1(
  uuid, uuid, uuid, jsonb, text
)
TO service_role;

COMMIT;

NOTIFY pgrst, 'reload schema';
