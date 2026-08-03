-- Exclusão definitiva da conta autenticada.
--
-- A operação precisa acontecer no servidor, em uma única transação. Assim,
-- uma conta de cerimonialista remove sua organização e seus eventos, enquanto
-- uma conta somente de funcionário remove apenas os próprios vínculos e
-- registros de atividade, preservando os eventos dos respectivos donos.

CREATE OR REPLACE FUNCTION public.excluir_conta_atual_v1(
  p_email_confirmacao text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_usuario_id uuid := auth.uid();
  v_email_auth text;
BEGIN
  IF v_usuario_id IS NULL THEN
    RAISE EXCEPTION 'AUTENTICACAO_NECESSARIA';
  END IF;

  SELECT lower(btrim(u.email))
  INTO v_email_auth
  FROM auth.users u
  WHERE u.id = v_usuario_id;

  IF v_email_auth IS NULL
     OR lower(btrim(COALESCE(p_email_confirmacao, ''))) <> v_email_auth THEN
    RAISE EXCEPTION 'EMAIL_DE_CONFIRMACAO_INVALIDO';
  END IF;

  -- Organizações nas quais a conta é administradora são propriedade dela.
  -- A tabela temporária permite manter exatamente o mesmo conjunto de IDs
  -- durante toda a transação, sem depender de chamadas separadas do aplicativo.
  CREATE TEMP TABLE conta_exclusao_organizacoes (
    id uuid PRIMARY KEY
  ) ON COMMIT DROP;

  INSERT INTO conta_exclusao_organizacoes (id)
  SELECT DISTINCT mo.organizacao_id
  FROM public.membros_organizacao mo
  WHERE mo.usuario_id = v_usuario_id
    AND mo.ativo
    AND mo.papel = 'admin';

  CREATE TEMP TABLE conta_exclusao_casamentos (
    id uuid PRIMARY KEY
  ) ON COMMIT DROP;

  INSERT INTO conta_exclusao_casamentos (id)
  SELECT c.id
  FROM public.casamentos c
  JOIN conta_exclusao_organizacoes o ON o.id = c.organizacao_id;

  -- Estas tabelas possuem chaves para casamentos sem ON DELETE CASCADE.
  -- Apagá-las explicitamente evita falha parcial e remove também o histórico
  -- operacional, a equipe, o chat e as sessões dos participantes.
  DELETE FROM public.chat
  WHERE casamento_id IN (SELECT id FROM conta_exclusao_casamentos);

  DELETE FROM public.eventos_checkin
  WHERE casamento_id IN (SELECT id FROM conta_exclusao_casamentos);

  DELETE FROM public.conflitos_sincronizacao
  WHERE casamento_id IN (SELECT id FROM conta_exclusao_casamentos);

  DELETE FROM public.operacoes_aplicadas_app
  WHERE casamento_id IN (SELECT id FROM conta_exclusao_casamentos);

  DELETE FROM public.controle_lista
  WHERE casamento_id IN (SELECT id FROM conta_exclusao_casamentos);

  DELETE FROM public.sessoes_usuarios_app
  WHERE casamento_id IN (SELECT id FROM conta_exclusao_casamentos);

  DELETE FROM public.convidados
  WHERE casamento_id IN (SELECT id FROM conta_exclusao_casamentos);

  DELETE FROM public.staff
  WHERE casamento_id IN (SELECT id FROM conta_exclusao_casamentos);

  DELETE FROM public.mesas
  WHERE casamento_id IN (SELECT id FROM conta_exclusao_casamentos);

  DELETE FROM public.membros_casamento
  WHERE casamento_id IN (SELECT id FROM conta_exclusao_casamentos);

  DELETE FROM public.casamentos
  WHERE id IN (SELECT id FROM conta_exclusao_casamentos);

  -- A organização é apagada depois dos eventos. Seus membros e sua equipe
  -- permanente são removidos pelo ON DELETE CASCADE da organização.
  DELETE FROM public.organizacoes
  WHERE id IN (SELECT id FROM conta_exclusao_organizacoes);

  -- Mesmo em eventos que pertencem a outra cerimonialista, os registros
  -- produzidos pela conta excluída não devem permanecer identificáveis.
  DELETE FROM public.eventos_checkin
  WHERE usuario_id = v_usuario_id;

  UPDATE public.mesas
  SET modificado_por_usuario_id = NULL
  WHERE modificado_por_usuario_id = v_usuario_id;

  UPDATE public.convidados
  SET modificado_por_usuario_id = NULL
  WHERE modificado_por_usuario_id = v_usuario_id;

  UPDATE public.membros_casamento
  SET criado_por_usuario_id = NULL
  WHERE criado_por_usuario_id = v_usuario_id;

  -- Revoga imediatamente o acesso do funcionário a eventos de terceiros e
  -- remove qualquer sessão persistida no servidor.
  DELETE FROM public.membros_casamento
  WHERE usuario_id = v_usuario_id;

  DELETE FROM public.funcionarios_organizacao
  WHERE usuario_id = v_usuario_id;

  DELETE FROM public.membros_organizacao
  WHERE usuario_id = v_usuario_id;

  DELETE FROM public.sessoes_usuarios_app
  WHERE usuario_id = v_usuario_id;

  DELETE FROM public.usuarios_app
  WHERE id = v_usuario_id;

  -- A identidade é removida por último. Os vínculos que possuem FK para
  -- auth.users já foram tratados acima, evitando erro de integridade.
  DELETE FROM auth.users
  WHERE id = v_usuario_id;
END;
$$;

REVOKE ALL ON FUNCTION public.excluir_conta_atual_v1(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.excluir_conta_atual_v1(text) TO authenticated;
