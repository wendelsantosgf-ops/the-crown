-- The Crown: somente o autor edita/apaga seu comentário.
-- Exclusão lógica preserva respostas e relações entre comentários.
BEGIN;
ALTER TABLE public.crown_challenge_comments
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz;

-- Edição e exclusão só podem ocorrer por funções que verificam auth.uid().
REVOKE UPDATE, DELETE ON public.crown_challenge_comments FROM authenticated, anon;
DROP POLICY IF EXISTS crown_comments_delete ON public.crown_challenge_comments;
DROP POLICY IF EXISTS crown_comments_update ON public.crown_challenge_comments;

CREATE OR REPLACE FUNCTION public.crown_edit_comment(p_comment uuid, p_content text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Autenticação obrigatória'; END IF;
  IF p_content IS NULL OR length(btrim(p_content)) NOT BETWEEN 1 AND 1000 THEN
    RAISE EXCEPTION 'Comentário deve ter de 1 a 1000 caracteres';
  END IF;
  UPDATE public.crown_challenge_comments
  SET content = btrim(p_content)
  WHERE id = p_comment AND author_id = auth.uid() AND deleted_at IS NULL;
  IF NOT FOUND THEN RAISE EXCEPTION 'Comentário não encontrado ou sem permissão'; END IF;
END; $$;

CREATE OR REPLACE FUNCTION public.crown_delete_comment(p_comment uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Autenticação obrigatória'; END IF;
  UPDATE public.crown_challenge_comments
  SET content = '[Comentário apagado]', deleted_at = now()
  WHERE id = p_comment AND author_id = auth.uid() AND deleted_at IS NULL;
  IF NOT FOUND THEN RAISE EXCEPTION 'Comentário não encontrado ou sem permissão'; END IF;
END; $$;

REVOKE ALL ON FUNCTION public.crown_edit_comment(uuid,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.crown_delete_comment(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.crown_edit_comment(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.crown_delete_comment(uuid) TO authenticated;
COMMIT;
