-- Permite que uma nova cerimonialista crie sua conta tanto com e-mail quanto
-- com Google. Convites de funcionários continuam sem criar organização própria.

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

  -- Toda conta nova cria o próprio espaço de trabalho, salvo um convite para
  -- funcionário, que declara criar_organizacao = false.
  IF COALESCE(NEW.raw_user_meta_data ->> 'criar_organizacao', 'true') <> 'false'
     AND NOT EXISTS (
       SELECT 1 FROM public.membros_organizacao
       WHERE usuario_id = NEW.id AND ativo
     ) THEN
    v_nome_organizacao := COALESCE(
      NULLIF(btrim(NEW.raw_user_meta_data ->> 'nome_organizacao'), ''),
      NULLIF(btrim(NEW.raw_user_meta_data ->> 'nome'), ''),
      NULLIF(btrim(NEW.raw_user_meta_data ->> 'full_name'), ''),
      split_part(COALESCE(NEW.email, 'Minha organização'), '@', 1)
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
