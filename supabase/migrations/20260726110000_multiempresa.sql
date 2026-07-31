-- ETAPA 5A
-- Base multiempresa e multicasamento.
--
-- Esta migração preserva os dados atuais em um casamento legado e prepara
-- o Supabase Auth, as organizações e as políticas de isolamento por empresa.
-- Execute-a apenas junto da versão do aplicativo que usa autenticação.

BEGIN;

-- -------------------------------------------------------------------------
-- CONTAS, ORGANIZAÇÕES E CASAMENTOS
-- -------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.organizacoes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome text NOT NULL CHECK (char_length(btrim(nome)) >= 2),
  slug text NOT NULL UNIQUE,
  ativo boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.casamentos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organizacao_id uuid NOT NULL REFERENCES public.organizacoes(id) ON DELETE CASCADE,
  titulo text NOT NULL CHECK (char_length(btrim(titulo)) >= 2),
  nome_noiva text,
  nome_noivo text,
  data_evento date,
  local_evento text,
  status text NOT NULL DEFAULT 'rascunho'
    CHECK (status IN ('rascunho', 'ativo', 'finalizado', 'arquivado')),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  finalizado_em timestamp with time zone,
  arquivado_em timestamp with time zone
);

CREATE TABLE IF NOT EXISTS public.membros_organizacao (
  organizacao_id uuid NOT NULL REFERENCES public.organizacoes(id) ON DELETE CASCADE,
  usuario_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  papel text NOT NULL CHECK (papel IN ('admin')),
  ativo boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  PRIMARY KEY (organizacao_id, usuario_id)
);

CREATE TABLE IF NOT EXISTS public.membros_casamento (
  casamento_id uuid NOT NULL REFERENCES public.casamentos(id) ON DELETE CASCADE,
  usuario_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  papel text NOT NULL CHECK (papel IN ('admin', 'funcionario')),
  ativo boolean NOT NULL DEFAULT true,
  criado_por_usuario_id uuid REFERENCES auth.users(id),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  PRIMARY KEY (casamento_id, usuario_id)
);

-- Perfis já existentes deixam de exigir nomes únicos. A partir da próxima
-- etapa, o ID de um novo perfil será o mesmo UUID de auth.users.
ALTER TABLE public.usuarios_app
  DROP CONSTRAINT IF EXISTS usuarios_app_nome_key;

ALTER TABLE public.usuarios_app
  ADD COLUMN IF NOT EXISTS email text;

CREATE UNIQUE INDEX IF NOT EXISTS usuarios_app_email_unico
  ON public.usuarios_app (lower(email))
  WHERE email IS NOT NULL;

-- Cria um perfil público sempre que uma conta é cadastrada pelo Supabase Auth.
CREATE OR REPLACE FUNCTION public.criar_perfil_usuario_auth_v1()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_nome_organizacao text;
  v_slug_base text;
  v_indice integer := 1;
  v_organizacao_id uuid;
BEGIN
  INSERT INTO public.usuarios_app (id, nome, email, ordem, ativo, created_at)
  VALUES (
    NEW.id,
    COALESCE(
      NULLIF(btrim(NEW.raw_user_meta_data ->> 'nome'), ''),
      NULLIF(btrim(NEW.raw_user_meta_data ->> 'full_name'), ''),
      split_part(COALESCE(NEW.email, 'Usuário'), '@', 1)
    ),
    NEW.email,
    0,
    true,
    now()
  )
  ON CONFLICT (id) DO UPDATE
  SET email = EXCLUDED.email,
      nome = CASE
        WHEN public.usuarios_app.nome IS NULL OR btrim(public.usuarios_app.nome) = ''
          THEN EXCLUDED.nome
        ELSE public.usuarios_app.nome
      END;

  -- O cadastro público cria uma organização própria. Convites para a equipe
  -- devem ser enviados com criar_organizacao = false e entram somente no
  -- casamento para o qual foram convidados.
  IF COALESCE(NEW.raw_user_meta_data ->> 'criar_organizacao', 'false') = 'true'
     AND NOT EXISTS (
       SELECT 1 FROM public.membros_organizacao
       WHERE usuario_id = NEW.id AND ativo
     ) THEN
    v_nome_organizacao := COALESCE(
      NULLIF(btrim(NEW.raw_user_meta_data ->> 'nome_organizacao'), ''),
      NULLIF(btrim(NEW.raw_user_meta_data ->> 'nome'), ''),
      split_part(COALESCE(NEW.email, 'Minha cerimonial'), '@', 1)
    );
    v_slug_base := regexp_replace(lower(v_nome_organizacao), '[^a-z0-9]+', '-', 'g');
    v_slug_base := trim(both '-' FROM v_slug_base);
    v_slug_base := COALESCE(NULLIF(v_slug_base, ''), 'organizacao');

    LOOP
      BEGIN
        INSERT INTO public.organizacoes (nome, slug)
        VALUES (v_nome_organizacao, v_slug_base || '-' || v_indice)
        RETURNING id INTO v_organizacao_id;
        EXIT;
      EXCEPTION WHEN unique_violation THEN
        v_indice := v_indice + 1;
      END;
    END LOOP;

    INSERT INTO public.membros_organizacao (organizacao_id, usuario_id, papel)
    VALUES (v_organizacao_id, NEW.id, 'admin');
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS ao_criar_usuario_auth_v1 ON auth.users;
CREATE TRIGGER ao_criar_usuario_auth_v1
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.criar_perfil_usuario_auth_v1();

-- Cada nova administradora cria a própria organização por este RPC. O uso de
-- uma função única impede organizações sem administradora por corrida de rede.
CREATE OR REPLACE FUNCTION public.criar_organizacao_com_admin_v1(
  p_nome text
)
RETURNS public.organizacoes
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_usuario_id uuid := auth.uid();
  v_organizacao public.organizacoes;
  v_slug_base text;
  v_indice integer := 1;
BEGIN
  IF v_usuario_id IS NULL THEN
    RAISE EXCEPTION 'AUTENTICACAO_NECESSARIA';
  END IF;

  IF btrim(COALESCE(p_nome, '')) = '' THEN
    RAISE EXCEPTION 'NOME_ORGANIZACAO_INVALIDO';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.membros_organizacao
    WHERE usuario_id = v_usuario_id AND ativo
  ) THEN
    RAISE EXCEPTION 'USUARIO_JA_POSSUI_ORGANIZACAO';
  END IF;

  v_slug_base := regexp_replace(lower(btrim(p_nome)), '[^a-z0-9]+', '-', 'g');
  v_slug_base := trim(both '-' FROM v_slug_base);
  v_slug_base := COALESCE(NULLIF(v_slug_base, ''), 'organizacao');

  LOOP
    BEGIN
      INSERT INTO public.organizacoes (nome, slug)
      VALUES (btrim(p_nome), v_slug_base || '-' || v_indice)
      RETURNING * INTO v_organizacao;
      EXIT;
    EXCEPTION WHEN unique_violation THEN
      v_indice := v_indice + 1;
    END;
  END LOOP;

  INSERT INTO public.membros_organizacao (organizacao_id, usuario_id, papel)
  VALUES (v_organizacao.id, v_usuario_id, 'admin');

  RETURN v_organizacao;
END;
$$;

-- -------------------------------------------------------------------------
-- MIGRAÇÃO DOS DADOS ATUAIS PARA UM CASAMENTO LEGADO
-- -------------------------------------------------------------------------

INSERT INTO public.organizacoes (nome, slug)
VALUES ('Dados legados - definir proprietária', 'dados-legados')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.casamentos (organizacao_id, titulo, status)
SELECT id, 'Casamento legado', 'finalizado'
FROM public.organizacoes
WHERE slug = 'dados-legados'
  AND NOT EXISTS (
    SELECT 1 FROM public.casamentos
    WHERE organizacao_id = public.organizacoes.id
      AND titulo = 'Casamento legado'
  );

ALTER TABLE public.mesas ADD COLUMN IF NOT EXISTS casamento_id uuid;
ALTER TABLE public.convidados ADD COLUMN IF NOT EXISTS casamento_id uuid;
ALTER TABLE public.staff ADD COLUMN IF NOT EXISTS casamento_id uuid;
ALTER TABLE public.chat ADD COLUMN IF NOT EXISTS casamento_id uuid;
ALTER TABLE public.eventos_checkin ADD COLUMN IF NOT EXISTS casamento_id uuid;
ALTER TABLE public.conflitos_sincronizacao ADD COLUMN IF NOT EXISTS casamento_id uuid;
ALTER TABLE public.operacoes_aplicadas_app ADD COLUMN IF NOT EXISTS casamento_id uuid;
ALTER TABLE public.controle_lista ADD COLUMN IF NOT EXISTS casamento_id uuid;
ALTER TABLE public.sessoes_usuarios_app ADD COLUMN IF NOT EXISTS casamento_id uuid;

DO $$
DECLARE
  v_casamento_legado uuid;
BEGIN
  SELECT c.id INTO v_casamento_legado
  FROM public.casamentos c
  JOIN public.organizacoes o ON o.id = c.organizacao_id
  WHERE o.slug = 'dados-legados' AND c.titulo = 'Casamento legado';

  UPDATE public.mesas SET casamento_id = v_casamento_legado WHERE casamento_id IS NULL;
  UPDATE public.convidados SET casamento_id = v_casamento_legado WHERE casamento_id IS NULL;
  UPDATE public.staff SET casamento_id = v_casamento_legado WHERE casamento_id IS NULL;
  UPDATE public.chat SET casamento_id = v_casamento_legado WHERE casamento_id IS NULL;
  UPDATE public.eventos_checkin SET casamento_id = v_casamento_legado WHERE casamento_id IS NULL;
  UPDATE public.conflitos_sincronizacao SET casamento_id = v_casamento_legado WHERE casamento_id IS NULL;
  UPDATE public.operacoes_aplicadas_app SET casamento_id = v_casamento_legado WHERE casamento_id IS NULL;
  UPDATE public.controle_lista SET casamento_id = v_casamento_legado WHERE casamento_id IS NULL;
  UPDATE public.sessoes_usuarios_app SET casamento_id = v_casamento_legado WHERE casamento_id IS NULL;
END;
$$;

ALTER TABLE public.mesas ALTER COLUMN casamento_id SET NOT NULL;
ALTER TABLE public.convidados ALTER COLUMN casamento_id SET NOT NULL;
ALTER TABLE public.staff ALTER COLUMN casamento_id SET NOT NULL;
ALTER TABLE public.chat ALTER COLUMN casamento_id SET NOT NULL;
ALTER TABLE public.eventos_checkin ALTER COLUMN casamento_id SET NOT NULL;
ALTER TABLE public.conflitos_sincronizacao ALTER COLUMN casamento_id SET NOT NULL;
ALTER TABLE public.operacoes_aplicadas_app ALTER COLUMN casamento_id SET NOT NULL;
ALTER TABLE public.controle_lista ALTER COLUMN casamento_id SET NOT NULL;
ALTER TABLE public.sessoes_usuarios_app ALTER COLUMN casamento_id SET NOT NULL;

ALTER TABLE public.mesas DROP CONSTRAINT IF EXISTS mesas_casamento_id_fkey;
ALTER TABLE public.convidados DROP CONSTRAINT IF EXISTS convidados_casamento_id_fkey;
ALTER TABLE public.staff DROP CONSTRAINT IF EXISTS staff_casamento_id_fkey;
ALTER TABLE public.chat DROP CONSTRAINT IF EXISTS chat_casamento_id_fkey;
ALTER TABLE public.eventos_checkin DROP CONSTRAINT IF EXISTS eventos_checkin_casamento_id_fkey;
ALTER TABLE public.conflitos_sincronizacao DROP CONSTRAINT IF EXISTS conflitos_sincronizacao_casamento_id_fkey;
ALTER TABLE public.operacoes_aplicadas_app DROP CONSTRAINT IF EXISTS operacoes_aplicadas_app_casamento_id_fkey;
ALTER TABLE public.controle_lista DROP CONSTRAINT IF EXISTS controle_lista_casamento_id_fkey;
ALTER TABLE public.sessoes_usuarios_app DROP CONSTRAINT IF EXISTS sessoes_usuarios_app_casamento_id_fkey;

ALTER TABLE public.mesas ADD CONSTRAINT mesas_casamento_id_fkey FOREIGN KEY (casamento_id) REFERENCES public.casamentos(id);
ALTER TABLE public.convidados ADD CONSTRAINT convidados_casamento_id_fkey FOREIGN KEY (casamento_id) REFERENCES public.casamentos(id);
ALTER TABLE public.staff ADD CONSTRAINT staff_casamento_id_fkey FOREIGN KEY (casamento_id) REFERENCES public.casamentos(id);
ALTER TABLE public.chat ADD CONSTRAINT chat_casamento_id_fkey FOREIGN KEY (casamento_id) REFERENCES public.casamentos(id);
ALTER TABLE public.eventos_checkin ADD CONSTRAINT eventos_checkin_casamento_id_fkey FOREIGN KEY (casamento_id) REFERENCES public.casamentos(id);
ALTER TABLE public.conflitos_sincronizacao ADD CONSTRAINT conflitos_sincronizacao_casamento_id_fkey FOREIGN KEY (casamento_id) REFERENCES public.casamentos(id);
ALTER TABLE public.operacoes_aplicadas_app ADD CONSTRAINT operacoes_aplicadas_app_casamento_id_fkey FOREIGN KEY (casamento_id) REFERENCES public.casamentos(id);
ALTER TABLE public.controle_lista ADD CONSTRAINT controle_lista_casamento_id_fkey FOREIGN KEY (casamento_id) REFERENCES public.casamentos(id);
ALTER TABLE public.sessoes_usuarios_app ADD CONSTRAINT sessoes_usuarios_app_casamento_id_fkey FOREIGN KEY (casamento_id) REFERENCES public.casamentos(id);

-- Uma versão de lista e uma sessão passam a existir por casamento.
ALTER TABLE public.controle_lista DROP CONSTRAINT IF EXISTS controle_lista_pkey;
ALTER TABLE public.controle_lista ADD CONSTRAINT controle_lista_pkey PRIMARY KEY (casamento_id);
ALTER TABLE public.sessoes_usuarios_app DROP CONSTRAINT IF EXISTS sessoes_usuarios_app_pkey;
ALTER TABLE public.sessoes_usuarios_app ADD CONSTRAINT sessoes_usuarios_app_pkey
  PRIMARY KEY (usuario_id, dispositivo_id, casamento_id);

CREATE INDEX IF NOT EXISTS mesas_casamento_id_idx ON public.mesas (casamento_id);
CREATE INDEX IF NOT EXISTS convidados_casamento_id_idx ON public.convidados (casamento_id);
CREATE INDEX IF NOT EXISTS staff_casamento_id_idx ON public.staff (casamento_id);
CREATE INDEX IF NOT EXISTS chat_casamento_id_idx ON public.chat (casamento_id);
CREATE INDEX IF NOT EXISTS eventos_checkin_casamento_id_idx ON public.eventos_checkin (casamento_id);
CREATE INDEX IF NOT EXISTS conflitos_casamento_id_idx ON public.conflitos_sincronizacao (casamento_id);
CREATE INDEX IF NOT EXISTS membros_casamento_usuario_id_idx ON public.membros_casamento (usuario_id);
CREATE INDEX IF NOT EXISTS casamentos_organizacao_status_idx ON public.casamentos (organizacao_id, status, data_evento DESC);

-- -------------------------------------------------------------------------
-- FUNÇÕES DE AUTORIZAÇÃO E POLÍTICAS RLS
-- -------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.pode_acessar_casamento_v1(p_casamento_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.casamentos c
    JOIN public.membros_organizacao mo ON mo.organizacao_id = c.organizacao_id
    WHERE c.id = p_casamento_id
      AND mo.usuario_id = auth.uid()
      AND mo.ativo
  ) OR EXISTS (
    SELECT 1
    FROM public.membros_casamento mc
    WHERE mc.casamento_id = p_casamento_id
      AND mc.usuario_id = auth.uid()
      AND mc.ativo
  );
$$;

CREATE OR REPLACE FUNCTION public.e_admin_casamento_v1(p_casamento_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.casamentos c
    JOIN public.membros_organizacao mo ON mo.organizacao_id = c.organizacao_id
    WHERE c.id = p_casamento_id
      AND mo.usuario_id = auth.uid()
      AND mo.ativo
      AND mo.papel = 'admin'
  ) OR EXISTS (
    SELECT 1
    FROM public.membros_casamento mc
    WHERE mc.casamento_id = p_casamento_id
      AND mc.usuario_id = auth.uid()
      AND mc.ativo
      AND mc.papel = 'admin'
  );
$$;

CREATE OR REPLACE FUNCTION public.e_admin_organizacao_v1(p_organizacao_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.membros_organizacao mo
    WHERE mo.organizacao_id = p_organizacao_id
      AND mo.usuario_id = auth.uid()
      AND mo.ativo
      AND mo.papel = 'admin'
  );
$$;

ALTER TABLE public.organizacoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.casamentos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usuarios_app ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.membros_organizacao ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.membros_casamento ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mesas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.convidados ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.eventos_checkin ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conflitos_sincronizacao ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.operacoes_aplicadas_app ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.controle_lista ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sessoes_usuarios_app ENABLE ROW LEVEL SECURITY;

-- Estas políticas substituem integralmente as políticas existentes das tabelas
-- que agora pertencem a um casamento. Isso evita uma política antiga liberar
-- dados de outra cerimonialista.
DO $$
DECLARE
  v_tabela text;
  v_politica record;
BEGIN
  FOREACH v_tabela IN ARRAY ARRAY[
    'organizacoes', 'casamentos', 'usuarios_app', 'membros_organizacao', 'membros_casamento',
    'mesas', 'convidados', 'staff', 'chat', 'eventos_checkin',
    'conflitos_sincronizacao', 'operacoes_aplicadas_app', 'controle_lista',
    'sessoes_usuarios_app'
  ] LOOP
    FOR v_politica IN
      SELECT policyname FROM pg_policies
      WHERE schemaname = 'public' AND tablename = v_tabela
    LOOP
      EXECUTE format('DROP POLICY %I ON public.%I', v_politica.policyname, v_tabela);
    END LOOP;
  END LOOP;
END;
$$;

CREATE POLICY organizacoes_leitura ON public.organizacoes
  FOR SELECT TO authenticated
  USING (public.e_admin_organizacao_v1(id));
CREATE POLICY organizacoes_atualizacao ON public.organizacoes
  FOR UPDATE TO authenticated
  USING (public.e_admin_organizacao_v1(id))
  WITH CHECK (public.e_admin_organizacao_v1(id));

CREATE POLICY casamentos_leitura ON public.casamentos
  FOR SELECT TO authenticated
  USING (public.pode_acessar_casamento_v1(id));
CREATE POLICY casamentos_criacao ON public.casamentos
  FOR INSERT TO authenticated
  WITH CHECK (public.e_admin_organizacao_v1(organizacao_id));
CREATE POLICY casamentos_atualizacao ON public.casamentos
  FOR UPDATE TO authenticated
  USING (public.e_admin_casamento_v1(id))
  WITH CHECK (public.e_admin_casamento_v1(id));

CREATE POLICY usuarios_app_leitura ON public.usuarios_app
  FOR SELECT TO authenticated
  USING (
    id = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM public.membros_casamento mc
      WHERE mc.usuario_id = public.usuarios_app.id
        AND public.pode_acessar_casamento_v1(mc.casamento_id)
    )
  );
CREATE POLICY usuarios_app_atualizacao_propria ON public.usuarios_app
  FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

CREATE POLICY membros_organizacao_leitura ON public.membros_organizacao
  FOR SELECT TO authenticated
  USING (usuario_id = auth.uid() OR public.e_admin_organizacao_v1(organizacao_id));
CREATE POLICY membros_organizacao_gerenciamento ON public.membros_organizacao
  FOR ALL TO authenticated
  USING (public.e_admin_organizacao_v1(organizacao_id))
  WITH CHECK (public.e_admin_organizacao_v1(organizacao_id));

CREATE POLICY membros_casamento_leitura ON public.membros_casamento
  FOR SELECT TO authenticated
  USING (public.pode_acessar_casamento_v1(casamento_id));
CREATE POLICY membros_casamento_gerenciamento ON public.membros_casamento
  FOR ALL TO authenticated
  USING (public.e_admin_casamento_v1(casamento_id))
  WITH CHECK (public.e_admin_casamento_v1(casamento_id));

CREATE POLICY mesas_leitura ON public.mesas FOR SELECT TO authenticated
  USING (public.pode_acessar_casamento_v1(casamento_id));
CREATE POLICY mesas_gerenciamento ON public.mesas FOR ALL TO authenticated
  USING (public.e_admin_casamento_v1(casamento_id))
  WITH CHECK (public.e_admin_casamento_v1(casamento_id));

CREATE POLICY convidados_leitura ON public.convidados FOR SELECT TO authenticated
  USING (public.pode_acessar_casamento_v1(casamento_id));
CREATE POLICY convidados_gerenciamento ON public.convidados FOR ALL TO authenticated
  USING (public.e_admin_casamento_v1(casamento_id))
  WITH CHECK (public.e_admin_casamento_v1(casamento_id));

CREATE POLICY staff_leitura ON public.staff FOR SELECT TO authenticated
  USING (public.pode_acessar_casamento_v1(casamento_id));
CREATE POLICY staff_gerenciamento ON public.staff FOR ALL TO authenticated
  USING (public.e_admin_casamento_v1(casamento_id))
  WITH CHECK (public.e_admin_casamento_v1(casamento_id));

CREATE POLICY chat_leitura ON public.chat FOR SELECT TO authenticated
  USING (public.pode_acessar_casamento_v1(casamento_id));
CREATE POLICY chat_criacao ON public.chat FOR INSERT TO authenticated
  WITH CHECK (public.pode_acessar_casamento_v1(casamento_id));
CREATE POLICY chat_gerenciamento ON public.chat FOR UPDATE TO authenticated
  USING (public.e_admin_casamento_v1(casamento_id))
  WITH CHECK (public.e_admin_casamento_v1(casamento_id));

CREATE POLICY eventos_checkin_leitura ON public.eventos_checkin FOR SELECT TO authenticated
  USING (public.pode_acessar_casamento_v1(casamento_id));
CREATE POLICY eventos_checkin_criacao ON public.eventos_checkin FOR INSERT TO authenticated
  WITH CHECK (
    public.pode_acessar_casamento_v1(casamento_id)
    AND usuario_id = auth.uid()
  );
CREATE POLICY eventos_checkin_gerenciamento ON public.eventos_checkin FOR UPDATE TO authenticated
  USING (public.e_admin_casamento_v1(casamento_id))
  WITH CHECK (public.e_admin_casamento_v1(casamento_id));

CREATE POLICY conflitos_leitura ON public.conflitos_sincronizacao FOR SELECT TO authenticated
  USING (public.pode_acessar_casamento_v1(casamento_id));
CREATE POLICY conflitos_gerenciamento ON public.conflitos_sincronizacao FOR ALL TO authenticated
  USING (public.e_admin_casamento_v1(casamento_id))
  WITH CHECK (public.e_admin_casamento_v1(casamento_id));

CREATE POLICY operacoes_leitura ON public.operacoes_aplicadas_app FOR SELECT TO authenticated
  USING (public.pode_acessar_casamento_v1(casamento_id));
CREATE POLICY operacoes_gerenciamento ON public.operacoes_aplicadas_app FOR ALL TO authenticated
  USING (public.e_admin_casamento_v1(casamento_id))
  WITH CHECK (public.e_admin_casamento_v1(casamento_id));

CREATE POLICY controle_lista_leitura ON public.controle_lista FOR SELECT TO authenticated
  USING (public.pode_acessar_casamento_v1(casamento_id));
CREATE POLICY controle_lista_gerenciamento ON public.controle_lista FOR ALL TO authenticated
  USING (public.e_admin_casamento_v1(casamento_id))
  WITH CHECK (public.e_admin_casamento_v1(casamento_id));

CREATE POLICY sessoes_leitura ON public.sessoes_usuarios_app FOR SELECT TO authenticated
  USING (usuario_id = auth.uid());
CREATE POLICY sessoes_gerenciamento ON public.sessoes_usuarios_app FOR ALL TO authenticated
  USING (usuario_id = auth.uid())
  WITH CHECK (usuario_id = auth.uid());

REVOKE ALL ON FUNCTION public.criar_organizacao_com_admin_v1(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.criar_organizacao_com_admin_v1(text) TO authenticated;

COMMIT;

-- Depois do primeiro login da proprietária, associe o casamento legado a ela
-- pelo painel ou por uma migração assistida. Ele não é exibido a nenhuma conta
-- enquanto não existir um vínculo em membros_organizacao/membros_casamento.
