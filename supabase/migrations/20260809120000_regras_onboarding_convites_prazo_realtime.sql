-- Regras de negócio do onboarding, convites sem e-mail e prazo de resposta.
-- Esta migration é segura para reaplicação no projeto remoto.

BEGIN;

ALTER TABLE public.casamentos
  ADD COLUMN IF NOT EXISTS data_limite_confirmacao date;

ALTER TABLE public.funcionarios_organizacao
  ALTER COLUMN email DROP NOT NULL;

ALTER TABLE public.convites_funcionario_app
  ALTER COLUMN email DROP NOT NULL;

-- O Google usado apenas na tela inicial não deve deixar uma conta Auth órfã
-- que bloqueie posteriormente o cadastro por e-mail e senha.
CREATE OR REPLACE FUNCTION public.cancelar_login_google_sem_conta_v1()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_usuario_id uuid := auth.uid();
BEGIN
  IF v_usuario_id IS NULL THEN
    RETURN;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.membros_organizacao
    WHERE usuario_id = v_usuario_id
  ) OR EXISTS (
    SELECT 1 FROM public.membros_casamento
    WHERE usuario_id = v_usuario_id
  ) OR EXISTS (
    SELECT 1 FROM public.funcionarios_organizacao
    WHERE usuario_id = v_usuario_id
  ) OR EXISTS (
    SELECT 1 FROM public.convites_funcionario_app
    WHERE usuario_id = v_usuario_id
      AND usado_em IS NULL
      AND expira_em > now()
  ) THEN
    RAISE EXCEPTION 'CONTA_COM_VINCULO_ATIVO';
  END IF;

  DELETE FROM public.usuarios_app WHERE id = v_usuario_id;
  DELETE FROM auth.users WHERE id = v_usuario_id;
END;
$$;

REVOKE ALL ON FUNCTION public.cancelar_login_google_sem_conta_v1()
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cancelar_login_google_sem_conta_v1()
  TO authenticated;

-- Realtime precisa entregar exclusões e encerramentos aos aparelhos dos
-- funcionários, inclusive quando a exclusão vem de outro celular.
DO $$
DECLARE
  v_tabela text;
BEGIN
  FOREACH v_tabela IN ARRAY ARRAY[
    'casamentos',
    'membros_casamento',
    'membros_organizacao',
    'funcionarios_organizacao'
  ] LOOP
    IF NOT EXISTS (
      SELECT 1
      FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime'
        AND schemaname = 'public'
        AND tablename = v_tabela
    ) THEN
      EXECUTE format(
        'ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',
        v_tabela
      );
    END IF;
  END LOOP;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END;
$$;

-- O link e o e-mail podem exibir o prazo sem depender de uma nova consulta
-- pública ao evento.
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

  SELECT * INTO v_convite
  FROM public.convites_online
  WHERE token_hash = encode(digest(btrim(p_token), 'sha256'), 'hex');

  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'CONVITE_INVALIDO';
  END IF;

  SELECT * INTO v_evento FROM public.casamentos WHERE id = v_convite.casamento_id;
  SELECT * INTO v_convidado FROM public.convidados
  WHERE id = v_convite.convidado_id AND deleted_at IS NULL;

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
    'data_limite_confirmacao', v_evento.data_limite_confirmacao,
    'convidado_nome', v_convidado.nome,
    'status', v_convite.status,
    'resposta', v_convite.resposta
  );
END;
$$;

REVOKE ALL ON FUNCTION public.obter_convite_online_v1(text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.obter_convite_online_v1(text)
  TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
