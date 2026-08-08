-- Permite reenviar individualmente um convite que já foi respondido.
-- O aplicativo não inclui esses convites no envio em massa; o administrador
-- precisa acionar o botão individual e confirmar o reenvio.

BEGIN;

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
      enviado_em = now(),
      status = 'enviado',
      resposta = NULL,
      respondido_em = NULL
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

COMMIT;
