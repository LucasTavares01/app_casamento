-- Permite guardar o número opcional usado para compartilhar convites pelo WhatsApp.
ALTER TABLE public.funcionarios_organizacao
  ADD COLUMN IF NOT EXISTS telefone text;
