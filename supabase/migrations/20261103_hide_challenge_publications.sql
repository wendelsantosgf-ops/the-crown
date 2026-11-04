-- The Crown: ocultação segura de publicações de desafios.
-- Não apaga apostas, pagamentos, resultados ou histórico financeiro.
BEGIN;
ALTER TABLE public.crown_challenges ADD COLUMN IF NOT EXISTS hidden_at timestamptz;
CREATE OR REPLACE FUNCTION public.crown_hide_challenge(p_challenge uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT public.crown_is_admin() THEN
    RAISE EXCEPTION 'Apenas administradores podem remover publicações';
  END IF;
  PERFORM 1 FROM public.crown_challenges WHERE id = p_challenge FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Desafio não encontrado'; END IF;
  IF EXISTS (
    SELECT 1 FROM public.crown_wagers
    WHERE challenge_id = p_challenge AND status = 'pending'
  ) THEN
    RAISE EXCEPTION 'Este desafio tem apostas pendentes. Finalize o resultado antes de removê-lo.';
  END IF;
  UPDATE public.crown_challenges SET hidden_at = now()
  WHERE id = p_challenge AND hidden_at IS NULL;
END; $$;
REVOKE ALL ON FUNCTION public.crown_hide_challenge(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.crown_hide_challenge(uuid) TO authenticated;
COMMIT;
