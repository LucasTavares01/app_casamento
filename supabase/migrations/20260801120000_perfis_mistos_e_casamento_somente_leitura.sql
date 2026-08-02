BEGIN;

-- -------------------------------------------------------------------------
-- Perfis mistos e atualização centralizada do cadastro
-- -------------------------------------------------------------------------

DROP FUNCTION IF EXISTS public.email_cadastrado_v1(text);
CREATE OR REPLACE FUNCTION public.email_cadastrado_v1(p_email text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM auth.users u
    WHERE lower(u.email) = lower(btrim(p_email))
  );
$$;

DROP FUNCTION IF EXISTS public.obter_papeis_conta_atual_v1();
CREATE OR REPLACE FUNCTION public.obter_papeis_conta_atual_v1()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'cerimonialista', EXISTS (
      SELECT 1
      FROM public.membros_organizacao mo
      WHERE mo.usuario_id = auth.uid()
        AND mo.ativo
        AND mo.papel = 'admin'
    ),
    'funcionario', EXISTS (
      SELECT 1
      FROM public.funcionarios_organizacao fo
      WHERE fo.usuario_id = auth.uid()
        AND fo.ativo
    ) OR EXISTS (
      SELECT 1
      FROM public.membros_casamento mc
      WHERE mc.usuario_id = auth.uid()
        AND mc.ativo
        AND mc.papel = 'funcionario'
    )
  );
$$;

DROP FUNCTION IF EXISTS public.habilitar_perfil_cerimonialista_v1(text);
CREATE OR REPLACE FUNCTION public.habilitar_perfil_cerimonialista_v1(
  p_nome text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_usuario_id uuid := auth.uid();
  v_nome text := btrim(COALESCE(p_nome, ''));
  v_organizacao_id uuid;
  v_slug_base text;
  v_indice integer := 1;
BEGIN
  IF v_usuario_id IS NULL THEN
    RAISE EXCEPTION 'AUTENTICACAO_NECESSARIA';
  END IF;

  IF char_length(v_nome) < 2 THEN
    RAISE EXCEPTION 'NOME_INVALIDO';
  END IF;

  SELECT mo.organizacao_id
  INTO v_organizacao_id
  FROM public.membros_organizacao mo
  WHERE mo.usuario_id = v_usuario_id
    AND mo.ativo
    AND mo.papel = 'admin'
  ORDER BY mo.created_at
  LIMIT 1;

  IF v_organizacao_id IS NULL THEN
    v_slug_base := regexp_replace(lower(v_nome), '[^a-z0-9]+', '-', 'g');
    v_slug_base := trim(both '-' FROM v_slug_base);
    v_slug_base := COALESCE(NULLIF(v_slug_base, ''), 'organizacao');

    LOOP
      BEGIN
        INSERT INTO public.organizacoes (nome, slug)
        VALUES (v_nome, v_slug_base || '-' || v_indice)
        RETURNING id INTO v_organizacao_id;
        EXIT;
      EXCEPTION WHEN unique_violation THEN
        v_indice := v_indice + 1;
      END;
    END LOOP;

    INSERT INTO public.membros_organizacao (organizacao_id, usuario_id, papel)
    VALUES (v_organizacao_id, v_usuario_id, 'admin')
    ON CONFLICT (organizacao_id, usuario_id) DO UPDATE
      SET ativo = true, papel = 'admin';
  END IF;

  UPDATE public.usuarios_app
  SET nome = v_nome, email = COALESCE(email, (SELECT email FROM auth.users WHERE id = v_usuario_id))
  WHERE id = v_usuario_id;

  UPDATE public.funcionarios_organizacao
  SET nome = v_nome, updated_at = now()
  WHERE usuario_id = v_usuario_id;

  UPDATE auth.users
  SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb)
      || jsonb_build_object('nome', v_nome),
      updated_at = now()
  WHERE id = v_usuario_id;

  RETURN v_organizacao_id;
END;
$$;

DROP FUNCTION IF EXISTS public.atualizar_perfil_usuario_v1(text);
CREATE OR REPLACE FUNCTION public.atualizar_perfil_usuario_v1(p_nome text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_usuario_id uuid := auth.uid();
  v_nome text := btrim(COALESCE(p_nome, ''));
BEGIN
  IF v_usuario_id IS NULL THEN
    RAISE EXCEPTION 'AUTENTICACAO_NECESSARIA';
  END IF;

  IF char_length(v_nome) < 2 THEN
    RAISE EXCEPTION 'NOME_INVALIDO';
  END IF;

  UPDATE public.usuarios_app
  SET nome = v_nome
  WHERE id = v_usuario_id;

  UPDATE public.funcionarios_organizacao
  SET nome = v_nome, updated_at = now()
  WHERE usuario_id = v_usuario_id;

  UPDATE auth.users
  SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb)
      || jsonb_build_object('nome', v_nome),
      updated_at = now()
  WHERE id = v_usuario_id;
END;
$$;

REVOKE ALL ON FUNCTION public.email_cadastrado_v1(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.email_cadastrado_v1(text) TO anon, authenticated;
REVOKE ALL ON FUNCTION public.obter_papeis_conta_atual_v1() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.obter_papeis_conta_atual_v1() TO authenticated;
REVOKE ALL ON FUNCTION public.habilitar_perfil_cerimonialista_v1(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.habilitar_perfil_cerimonialista_v1(text) TO authenticated;
REVOKE ALL ON FUNCTION public.atualizar_perfil_usuario_v1(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.atualizar_perfil_usuario_v1(text) TO authenticated;

-- -------------------------------------------------------------------------
-- Casamento encerrado: acesso de leitura, sem alterações de conteúdo
-- -------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.casamento_aberto_para_edicao_v1(
  p_casamento_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.casamentos c
    WHERE c.id = p_casamento_id
      AND c.status NOT IN ('finalizado', 'arquivado')
  );
$$;

-- A associação do funcionário permanece ativa para que o evento continue
-- aparecendo na aba Arquivados e possa ser aberto em modo somente leitura.
CREATE OR REPLACE FUNCTION public.finalizar_casamento_v1(p_casamento_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_organizacao_id uuid;
BEGIN
  SELECT organizacao_id INTO v_organizacao_id
  FROM public.casamentos
  WHERE id = p_casamento_id;

  IF v_organizacao_id IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.membros_organizacao mo
    WHERE mo.organizacao_id = v_organizacao_id
      AND mo.usuario_id = auth.uid()
      AND mo.ativo AND mo.papel = 'admin'
  ) THEN
    RAISE EXCEPTION 'SEM_PERMISSAO_PARA_ENCERRAR_CASAMENTO';
  END IF;

  UPDATE public.casamentos
  SET status = 'finalizado',
      finalizado_em = COALESCE(finalizado_em, now()),
      updated_at = now()
  WHERE id = p_casamento_id;
END;
$$;

REVOKE ALL ON FUNCTION public.finalizar_casamento_v1(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.finalizar_casamento_v1(uuid) TO authenticated;

DROP POLICY IF EXISTS casamentos_atualizacao ON public.casamentos;
CREATE POLICY casamentos_atualizacao ON public.casamentos
  FOR UPDATE TO authenticated
  USING (
    public.e_admin_casamento_v1(id)
    AND public.casamento_aberto_para_edicao_v1(id)
  )
  WITH CHECK (
    public.e_admin_casamento_v1(id)
    AND public.casamento_aberto_para_edicao_v1(id)
  );

DROP POLICY IF EXISTS membros_casamento_gerenciamento ON public.membros_casamento;
CREATE POLICY membros_casamento_gerenciamento ON public.membros_casamento
  FOR ALL TO authenticated
  USING (
    public.e_admin_casamento_v1(casamento_id)
    AND public.casamento_aberto_para_edicao_v1(casamento_id)
  )
  WITH CHECK (
    public.e_admin_casamento_v1(casamento_id)
    AND public.casamento_aberto_para_edicao_v1(casamento_id)
  );

DROP POLICY IF EXISTS mesas_gerenciamento ON public.mesas;
CREATE POLICY mesas_gerenciamento ON public.mesas FOR ALL TO authenticated
  USING (
    public.e_admin_casamento_v1(casamento_id)
    AND public.casamento_aberto_para_edicao_v1(casamento_id)
  )
  WITH CHECK (
    public.e_admin_casamento_v1(casamento_id)
    AND public.casamento_aberto_para_edicao_v1(casamento_id)
  );

DROP POLICY IF EXISTS convidados_gerenciamento ON public.convidados;
CREATE POLICY convidados_gerenciamento ON public.convidados FOR ALL TO authenticated
  USING (
    public.e_admin_casamento_v1(casamento_id)
    AND public.casamento_aberto_para_edicao_v1(casamento_id)
  )
  WITH CHECK (
    public.e_admin_casamento_v1(casamento_id)
    AND public.casamento_aberto_para_edicao_v1(casamento_id)
  );

DROP POLICY IF EXISTS staff_gerenciamento ON public.staff;
CREATE POLICY staff_gerenciamento ON public.staff FOR ALL TO authenticated
  USING (
    public.e_admin_casamento_v1(casamento_id)
    AND public.casamento_aberto_para_edicao_v1(casamento_id)
  )
  WITH CHECK (
    public.e_admin_casamento_v1(casamento_id)
    AND public.casamento_aberto_para_edicao_v1(casamento_id)
  );

DROP POLICY IF EXISTS chat_criacao ON public.chat;
CREATE POLICY chat_criacao ON public.chat FOR INSERT TO authenticated
  WITH CHECK (
    public.pode_acessar_casamento_v1(casamento_id)
    AND public.casamento_aberto_para_edicao_v1(casamento_id)
  );

DROP POLICY IF EXISTS chat_gerenciamento ON public.chat;
CREATE POLICY chat_gerenciamento ON public.chat FOR UPDATE TO authenticated
  USING (
    public.e_admin_casamento_v1(casamento_id)
    AND public.casamento_aberto_para_edicao_v1(casamento_id)
  )
  WITH CHECK (
    public.e_admin_casamento_v1(casamento_id)
    AND public.casamento_aberto_para_edicao_v1(casamento_id)
  );

DROP POLICY IF EXISTS eventos_checkin_criacao ON public.eventos_checkin;
CREATE POLICY eventos_checkin_criacao ON public.eventos_checkin
  FOR INSERT TO authenticated
  WITH CHECK (
    public.pode_acessar_casamento_v1(casamento_id)
    AND public.casamento_aberto_para_edicao_v1(casamento_id)
    AND usuario_id = auth.uid()
  );

DROP POLICY IF EXISTS eventos_checkin_gerenciamento ON public.eventos_checkin;
CREATE POLICY eventos_checkin_gerenciamento ON public.eventos_checkin
  FOR UPDATE TO authenticated
  USING (
    public.e_admin_casamento_v1(casamento_id)
    AND public.casamento_aberto_para_edicao_v1(casamento_id)
  )
  WITH CHECK (
    public.e_admin_casamento_v1(casamento_id)
    AND public.casamento_aberto_para_edicao_v1(casamento_id)
  );

DROP POLICY IF EXISTS conflitos_gerenciamento ON public.conflitos_sincronizacao;
CREATE POLICY conflitos_gerenciamento ON public.conflitos_sincronizacao FOR ALL TO authenticated
  USING (
    public.e_admin_casamento_v1(casamento_id)
    AND public.casamento_aberto_para_edicao_v1(casamento_id)
  )
  WITH CHECK (
    public.e_admin_casamento_v1(casamento_id)
    AND public.casamento_aberto_para_edicao_v1(casamento_id)
  );

DROP POLICY IF EXISTS operacoes_gerenciamento ON public.operacoes_aplicadas_app;
CREATE POLICY operacoes_gerenciamento ON public.operacoes_aplicadas_app FOR ALL TO authenticated
  USING (
    public.e_admin_casamento_v1(casamento_id)
    AND public.casamento_aberto_para_edicao_v1(casamento_id)
  )
  WITH CHECK (
    public.e_admin_casamento_v1(casamento_id)
    AND public.casamento_aberto_para_edicao_v1(casamento_id)
  );

DROP POLICY IF EXISTS controle_lista_gerenciamento ON public.controle_lista;
CREATE POLICY controle_lista_gerenciamento ON public.controle_lista FOR ALL TO authenticated
  USING (
    public.e_admin_casamento_v1(casamento_id)
    AND public.casamento_aberto_para_edicao_v1(casamento_id)
  )
  WITH CHECK (
    public.e_admin_casamento_v1(casamento_id)
    AND public.casamento_aberto_para_edicao_v1(casamento_id)
  );

DROP POLICY IF EXISTS sessoes_gerenciamento ON public.sessoes_usuarios_app;
CREATE POLICY sessoes_gerenciamento ON public.sessoes_usuarios_app FOR ALL TO authenticated
  USING (
    usuario_id = auth.uid()
    AND public.casamento_aberto_para_edicao_v1(casamento_id)
  )
  WITH CHECK (
    usuario_id = auth.uid()
    AND public.casamento_aberto_para_edicao_v1(casamento_id)
  );

COMMIT;
