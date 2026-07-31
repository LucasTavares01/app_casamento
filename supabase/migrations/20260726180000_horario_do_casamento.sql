ALTER TABLE public.casamentos
  ADD COLUMN IF NOT EXISTS hora_evento time without time zone;
