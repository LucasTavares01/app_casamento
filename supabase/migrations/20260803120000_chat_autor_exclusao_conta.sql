-- Registra o autor das novas mensagens para que a exclusão da conta remova
-- somente as mensagens daquela pessoa em eventos de terceiros.

ALTER TABLE public.chat
  ADD COLUMN IF NOT EXISTS usuario_id uuid
  REFERENCES auth.users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS chat_usuario_id_idx
  ON public.chat (usuario_id);

CREATE OR REPLACE FUNCTION public.limpar_chat_da_conta_excluida_v1()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM public.chat
  WHERE usuario_id = OLD.id;
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS ao_excluir_conta_limpar_chat_v1 ON auth.users;
CREATE TRIGGER ao_excluir_conta_limpar_chat_v1
  BEFORE DELETE ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.limpar_chat_da_conta_excluida_v1();

REVOKE ALL ON FUNCTION public.limpar_chat_da_conta_excluida_v1() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.limpar_chat_da_conta_excluida_v1() TO authenticated;
