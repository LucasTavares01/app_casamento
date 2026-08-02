BEGIN;

-- hora_evento é do tipo time, portanto não pode passar por btrim(text).
-- A obrigatoriedade é garantida pelo tipo e pelo teste de NULL.
CREATE OR REPLACE FUNCTION public.validar_evento_completo_v1()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.evento_completo
     AND (NEW.data_evento IS NULL OR NEW.hora_evento IS NULL)
  THEN
    RAISE EXCEPTION 'Data e horário são obrigatórios para criar um evento.';
  END IF;

  RETURN NEW;
END;
$$;

COMMIT;
