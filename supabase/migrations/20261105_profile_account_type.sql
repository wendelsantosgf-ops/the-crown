-- The Crown: troca de tipo de conta pelo proprio titular
CREATE OR REPLACE FUNCTION public.crown_change_account_type(p_account_type text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Faça login para alterar seu tipo de conta';
  END IF;
  IF p_account_type IS NULL OR p_account_type NOT IN ('player','observer') THEN
    RAISE EXCEPTION 'Tipo de conta inválido';
  END IF;
  IF p_account_type = 'observer' AND EXISTS (
    SELECT 1 FROM public.crown_entries WHERE user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Contas com participações em desafios não podem virar observadoras';
  END IF;
  UPDATE public.crown_profiles SET account_type = p_account_type WHERE id = auth.uid();
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Perfil não encontrado';
  END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.crown_change_account_type(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.crown_change_account_type(text) TO authenticated;
