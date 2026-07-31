-- Corrige a regressão introduzida pela migration 20260726150000, que removeu
-- a unicidade de e-mail de usuarios_app. Os registros duplicados existentes
-- não são apagados automaticamente. Remova-os antes de aplicar esta migration;
-- ela falha de forma explícita em vez de deixar o banco parcialmente protegido.

BEGIN;

CREATE OR REPLACE FUNCTION public.validar_email_unico_usuario_app_v1()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email text;
BEGIN
  IF NEW.email IS NULL THEN
    RETURN NEW;
  END IF;

  v_email := lower(btrim(NEW.email));
  IF v_email = '' THEN
    NEW.email := NULL;
    RETURN NEW;
  END IF;

  -- Serializa gravações do mesmo e-mail para impedir uma corrida entre dois
  -- cadastros simultâneos mesmo quando ainda há duplicatas antigas no banco.
  PERFORM pg_advisory_xact_lock(hashtextextended(v_email, 0));

  IF EXISTS (
    SELECT 1
    FROM public.usuarios_app AS existente
    WHERE lower(btrim(existente.email)) = v_email
      AND existente.id <> NEW.id
  ) THEN
    RAISE EXCEPTION USING
      ERRCODE = '23505',
      MESSAGE = 'EMAIL_JA_CADASTRADO',
      CONSTRAINT = 'usuarios_app_email_unico';
  END IF;

  NEW.email := v_email;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS validar_email_unico_usuario_app_v1
  ON public.usuarios_app;

CREATE TRIGGER validar_email_unico_usuario_app_v1
  BEFORE INSERT OR UPDATE OF email ON public.usuarios_app
  FOR EACH ROW
  EXECUTE FUNCTION public.validar_email_unico_usuario_app_v1();

-- Não conclui a migration enquanto houver duplicatas antigas. Assim, quando
-- ela constar como aplicada, o índice único abaixo estará garantidamente ativo.
DO $$
DECLARE
  v_email_duplicado text;
BEGIN
  SELECT lower(btrim(email))
  INTO v_email_duplicado
  FROM public.usuarios_app
  WHERE email IS NOT NULL AND btrim(email) <> ''
  GROUP BY lower(btrim(email))
  HAVING count(*) > 1
  ORDER BY lower(btrim(email))
  LIMIT 1;

  IF v_email_duplicado IS NOT NULL THEN
    RAISE EXCEPTION USING
      ERRCODE = '23505',
      MESSAGE = format(
        'EMAIL_DUPLICADO_EXISTENTE: remova as contas duplicadas de %s antes de aplicar esta migration',
        v_email_duplicado
      ),
      CONSTRAINT = 'usuarios_app_email_unico';
  END IF;
END;
$$;

CREATE UNIQUE INDEX IF NOT EXISTS usuarios_app_email_unico
  ON public.usuarios_app (lower(btrim(email)))
  WHERE email IS NOT NULL AND btrim(email) <> '';

-- Lookup exclusivo do backend. Evita comparação case-sensitive no convite e
-- não expõe a existência de contas aos clientes autenticados comuns.
CREATE OR REPLACE FUNCTION public.buscar_usuarios_app_por_email_v1(
  p_email text
)
RETURNS TABLE (id uuid)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT usuario.id
  FROM public.usuarios_app AS usuario
  WHERE lower(btrim(usuario.email)) = lower(btrim(p_email))
  ORDER BY usuario.created_at, usuario.id
  LIMIT 2;
$$;

REVOKE ALL ON FUNCTION public.buscar_usuarios_app_por_email_v1(text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.buscar_usuarios_app_por_email_v1(text)
  TO service_role;

COMMIT;
