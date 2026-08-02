BEGIN;

-- Mantemos a tabela e os nomes técnicos atuais para preservar compatibilidade
-- com o aplicativo, mas passamos a representar qualquer tipo de ocasião.
ALTER TABLE public.casamentos
  ADD COLUMN IF NOT EXISTS tipo_evento text NOT NULL DEFAULT 'casamento',
  ADD COLUMN IF NOT EXISTS rotulo_pessoas text,
  ADD COLUMN IF NOT EXISTS detalhes_evento jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS evento_completo boolean NOT NULL DEFAULT false;

UPDATE public.casamentos
SET evento_completo = data_evento IS NOT NULL AND hora_evento IS NOT NULL
WHERE evento_completo = false;

ALTER TABLE public.casamentos
  DROP CONSTRAINT IF EXISTS casamentos_tipo_evento_check;

ALTER TABLE public.casamentos
  ADD CONSTRAINT casamentos_tipo_evento_check
  CHECK (tipo_evento IN (
    'casamento', 'aniversario', 'formatura', 'festa_infantil',
    'cha_de_bebe', 'bodas', 'corporativo', 'confraternizacao', 'outro'
  ));

ALTER TABLE public.casamentos
  DROP CONSTRAINT IF EXISTS casamentos_evento_completo_check;

ALTER TABLE public.casamentos
  ADD CONSTRAINT casamentos_evento_completo_check
  CHECK (
    NOT evento_completo
    OR (data_evento IS NOT NULL AND hora_evento IS NOT NULL)
  );

CREATE OR REPLACE FUNCTION public.validar_evento_completo_v1()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.evento_completo
     AND (NEW.data_evento IS NULL OR NULLIF(btrim(NEW.hora_evento), '') IS NULL)
  THEN
    RAISE EXCEPTION 'Data e horário são obrigatórios para criar um evento.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS validar_evento_completo_v1 ON public.casamentos;
CREATE TRIGGER validar_evento_completo_v1
BEFORE INSERT OR UPDATE ON public.casamentos
FOR EACH ROW
EXECUTE FUNCTION public.validar_evento_completo_v1();

COMMIT;
