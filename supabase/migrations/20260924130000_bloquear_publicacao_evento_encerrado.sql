BEGIN;

CREATE OR REPLACE FUNCTION public.impedir_controle_lista_evento_encerrado_v1()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_status text;
BEGIN
  SELECT status
  INTO v_status
  FROM public.casamentos
  WHERE id = NEW.casamento_id;

  IF v_status IN ('finalizado', 'arquivado') THEN
    RAISE EXCEPTION USING
      ERRCODE = '55000',
      MESSAGE = 'EVENTO_ENCERRADO: A lista deste evento não pode ser publicada.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS impedir_controle_lista_evento_encerrado
ON public.controle_lista;

CREATE TRIGGER impedir_controle_lista_evento_encerrado
BEFORE INSERT OR UPDATE ON public.controle_lista
FOR EACH ROW
EXECUTE FUNCTION public.impedir_controle_lista_evento_encerrado_v1();

COMMIT;
