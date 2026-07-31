-- ETAPA 4C
-- Publicação transacional da lista revisada pelo aplicativo.
--
-- A função:
-- - valida a sessão do aplicativo;
-- - valida toda a lista antes de apagar qualquer dado;
-- - cria uma nova versão oficial;
-- - limpa os dados do casamento;
-- - insere todas as mesas e todos os convidados;
-- - preserva usuarios_app e sessoes_usuarios_app;
-- - executa tudo na mesma transação.

BEGIN;

CREATE OR REPLACE FUNCTION public.nome_convidado_importacao_v1(
  p_convidado jsonb
)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public
AS $$
DECLARE
  v_nome text;
  v_descricao text;
  v_categoria text;
BEGIN
  v_nome := btrim(COALESCE(p_convidado ->> 'nome', ''));
  v_descricao := btrim(COALESCE(p_convidado ->> 'descricao', ''));
  v_categoria := btrim(COALESCE(p_convidado ->> 'categoria', 'normal'));

  IF v_nome = '' THEN
    RETURN '';
  END IF;

  IF v_descricao = '' THEN
    v_descricao := CASE v_categoria
      WHEN 'bebe' THEN 'bebê'
      WHEN 'nao_pagante_com_lugar' THEN 'não pagante com lugar'
      WHEN 'pagante_50' THEN 'pagante 50%'
      ELSE ''
    END;
  END IF;

  IF v_descricao <> ''
     AND position(lower(v_descricao) IN lower(v_nome)) = 0 THEN
    v_nome := v_nome || ' (' || v_descricao || ')';
  END IF;

  RETURN v_nome;
END;
$$;

CREATE OR REPLACE FUNCTION public.detalhe_mesa_importacao_v1(
  p_mesa jsonb
)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public
AS $$
DECLARE
  v_numero integer;
  v_capacidade integer;
  v_detalhe text;
  v_nome_exibicao text;
BEGIN
  v_numero := NULLIF(p_mesa ->> 'numero', '')::integer;
  v_capacidade := NULLIF(p_mesa ->> 'capacidade', '')::integer;
  v_detalhe := btrim(COALESCE(p_mesa ->> 'detalhe', ''));
  v_nome_exibicao := btrim(COALESCE(p_mesa ->> 'nome_exibicao', ''));

  IF v_detalhe <> '' THEN
    RETURN v_detalhe;
  END IF;

  IF v_capacidade IS NOT NULL AND v_capacidade >= 0 THEN
    IF v_numero = 0 AND lower(v_nome_exibicao) LIKE '%fam%lia%' THEN
      RETURN 'Mesa Família - ' || v_capacidade || ' lugares';
    END IF;
    RETURN v_capacidade || ' lugares';
  END IF;

  IF v_nome_exibicao <> ''
     AND lower(v_nome_exibicao) !~ '^mesa[[:space:]]+[0-9]+$' THEN
    RETURN v_nome_exibicao;
  END IF;

  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.publicar_lista_casamento_v1(
  p_usuario_id uuid,
  p_dispositivo_id uuid,
  p_sessao_id uuid,
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
  v_quantidade_mesas integer := 0;
  v_quantidade_convidados integer := 0;
  v_convidados_sem_mesa integer := 0;
  v_nova_versao bigint;
BEGIN
  -- Impede duas substituições simultâneas.
  PERFORM pg_advisory_xact_lock(
    hashtextextended('publicar_lista_casamento_v1', 0)
  );

  SELECT u.nome
  INTO v_usuario_nome
  FROM public.sessoes_usuarios_app s
  JOIN public.usuarios_app u
    ON u.id = s.usuario_id
  WHERE s.usuario_id = p_usuario_id
    AND s.dispositivo_id = p_dispositivo_id
    AND s.sessao_id = p_sessao_id
    AND s.expira_em > now()
    AND u.ativo = true
  FOR UPDATE OF s;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING
      ERRCODE = '28000',
      MESSAGE = 'SESSAO_INVALIDA';
  END IF;

  IF p_resultado IS NULL OR jsonb_typeof(p_resultado) <> 'object' THEN
    RAISE EXCEPTION 'IMPORTACAO_INVALIDA: A prévia da lista está vazia.';
  END IF;

  IF jsonb_typeof(COALESCE(p_resultado -> 'mesas', '[]'::jsonb)) <> 'array' THEN
    RAISE EXCEPTION 'IMPORTACAO_INVALIDA: A relação de mesas é inválida.';
  END IF;

  IF jsonb_typeof(
    COALESCE(p_resultado -> 'convidados_sem_mesa', '[]'::jsonb)
  ) <> 'array' THEN
    RAISE EXCEPTION 'IMPORTACAO_INVALIDA: A relação de convidados sem mesa é inválida.';
  END IF;

  IF jsonb_array_length(COALESCE(p_resultado -> 'mesas', '[]'::jsonb)) > 500 THEN
    RAISE EXCEPTION 'IMPORTACAO_INVALIDA: A lista ultrapassa 500 mesas.';
  END IF;

  CREATE TEMP TABLE _mesas_importacao_4c (
    numero integer PRIMARY KEY,
    id uuid NOT NULL,
    detalhe text
  ) ON COMMIT DROP;

  -- Valida todas as mesas e convidados antes de limpar o banco.
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
      SELECT 1 FROM _mesas_importacao_4c WHERE numero = v_numero
    ) THEN
      RAISE EXCEPTION
        'IMPORTACAO_INVALIDA: O número da Mesa % aparece mais de uma vez.',
        v_numero;
    END IF;

    IF jsonb_typeof(COALESCE(v_mesa -> 'convidados', '[]'::jsonb)) <> 'array' THEN
      RAISE EXCEPTION
        'IMPORTACAO_INVALIDA: A lista de convidados da Mesa % é inválida.',
        v_numero;
    END IF;

    v_mesa_id := gen_random_uuid();
    INSERT INTO _mesas_importacao_4c (numero, id, detalhe)
    VALUES (
      v_numero,
      v_mesa_id,
      public.detalhe_mesa_importacao_v1(v_mesa)
    );

    FOR v_convidado IN
      SELECT value
      FROM jsonb_array_elements(COALESCE(v_mesa -> 'convidados', '[]'::jsonb))
    LOOP
      v_nome_convidado := public.nome_convidado_importacao_v1(v_convidado);
      IF v_nome_convidado = '' THEN
        RAISE EXCEPTION
          'IMPORTACAO_INVALIDA: A Mesa % contém um convidado sem nome.',
          v_numero;
      END IF;
      v_quantidade_convidados := v_quantidade_convidados + 1;
    END LOOP;
  END LOOP;

  FOR v_convidado IN
    SELECT value
    FROM jsonb_array_elements(
      COALESCE(p_resultado -> 'convidados_sem_mesa', '[]'::jsonb)
    )
  LOOP
    v_nome_convidado := public.nome_convidado_importacao_v1(v_convidado);
    IF v_nome_convidado = '' THEN
      RAISE EXCEPTION
        'IMPORTACAO_INVALIDA: Existe um convidado sem nome.';
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

  -- A versão é incrementada dentro da mesma transação. Os celulares recebem
  -- este evento antes de processar os demais eventos da substituição e, ao
  -- detectar a nova versão, descartam as filas locais da lista anterior.
  INSERT INTO public.controle_lista (id, versao, updated_at)
  VALUES (1, 1, now())
  ON CONFLICT (id) DO NOTHING;

  UPDATE public.controle_lista
  SET versao = versao + 1,
      updated_at = now()
  WHERE id = 1
  RETURNING versao INTO v_nova_versao;

  -- Limpa tudo que pertence ao casamento, preservando usuários e sessões.
  DELETE FROM public.chat;
  DELETE FROM public.eventos_checkin;
  DELETE FROM public.conflitos_sincronizacao;
  DELETE FROM public.operacoes_aplicadas_app;
  DELETE FROM public.convidados;
  DELETE FROM public.staff;
  DELETE FROM public.mesas;

  INSERT INTO public.mesas (
    id,
    numero,
    detalhe,
    modificado_por_usuario_id
  )
  SELECT
    id,
    numero,
    detalhe,
    p_usuario_id
  FROM _mesas_importacao_4c
  ORDER BY numero;

  v_quantidade_mesas := (SELECT count(*) FROM _mesas_importacao_4c);
  v_quantidade_convidados := 0;

  FOR v_mesa IN
    SELECT value
    FROM jsonb_array_elements(COALESCE(p_resultado -> 'mesas', '[]'::jsonb))
  LOOP
    v_numero := (v_mesa ->> 'numero')::integer;
    SELECT id INTO v_mesa_id
    FROM _mesas_importacao_4c
    WHERE numero = v_numero;

    FOR v_convidado IN
      SELECT value
      FROM jsonb_array_elements(COALESCE(v_mesa -> 'convidados', '[]'::jsonb))
    LOOP
      v_nome_convidado := public.nome_convidado_importacao_v1(v_convidado);

      INSERT INTO public.convidados (
        nome,
        mesa_id,
        chegou,
        tem_conflito,
        eventos_atuais,
        modificado_por_usuario_id
      ) VALUES (
        v_nome_convidado,
        v_mesa_id,
        false,
        false,
        ARRAY[]::uuid[],
        p_usuario_id
      );

      v_quantidade_convidados := v_quantidade_convidados + 1;
    END LOOP;
  END LOOP;

  v_convidados_sem_mesa := 0;
  FOR v_convidado IN
    SELECT value
    FROM jsonb_array_elements(
      COALESCE(p_resultado -> 'convidados_sem_mesa', '[]'::jsonb)
    )
  LOOP
    v_nome_convidado := public.nome_convidado_importacao_v1(v_convidado);

    INSERT INTO public.convidados (
      nome,
      mesa_id,
      chegou,
      tem_conflito,
      eventos_atuais,
      modificado_por_usuario_id
    ) VALUES (
      v_nome_convidado,
      NULL,
      false,
      false,
      ARRAY[]::uuid[],
      p_usuario_id
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

REVOKE ALL ON FUNCTION public.nome_convidado_importacao_v1(jsonb)
FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.detalhe_mesa_importacao_v1(jsonb)
FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.publicar_lista_casamento_v1(
  uuid,
  uuid,
  uuid,
  jsonb
) FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.publicar_lista_casamento_v1(
  uuid,
  uuid,
  uuid,
  jsonb
) TO service_role;

COMMIT;

NOTIFY pgrst, 'reload schema';

SELECT
  'ETAPA_4C_INSTALADA' AS status,
  public.obter_versao_lista_v1() AS versao_atual;
