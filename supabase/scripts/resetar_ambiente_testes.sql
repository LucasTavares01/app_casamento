-- Reset manual do ambiente de testes.
-- ATENÇÃO: este script apaga todos os dados públicos e todos os usuários do Auth.
-- Execute somente no projeto de desenvolvimento correto.

DO $$
DECLARE
  item record;
BEGIN
  -- As tabelas públicas vêm primeiro porque podem ter referências ao Auth.
  FOR item IN
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = 'public'
  LOOP
    EXECUTE format('TRUNCATE TABLE public.%I CASCADE', item.tablename);
  END LOOP;
END $$;

-- Somente depois das tabelas públicas, removemos as identidades autenticadas.
DELETE FROM auth.users;

SELECT
  (SELECT count(*) FROM auth.users) AS usuarios_auth_restantes,
  (SELECT count(*) FROM public.usuarios_app) AS perfis_restantes,
  (SELECT count(*) FROM public.casamentos) AS eventos_restantes,
  (SELECT count(*) FROM public.convidados) AS convidados_restantes,
  (SELECT count(*) FROM public.mesas) AS mesas_restantes;
