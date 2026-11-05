-- The Crown: corrigir leitura de participacoes sem expor envios privados.
-- Execute no SQL Editor do Supabase (projeto The Crown).
ALTER TABLE public.crown_entries ENABLE ROW LEVEL SECURITY;

GRANT SELECT ON TABLE public.crown_entries TO authenticated;

DROP POLICY IF EXISTS crown_entries_read_self_or_admin ON public.crown_entries;
CREATE POLICY crown_entries_read_self_or_admin
ON public.crown_entries FOR SELECT TO authenticated
USING (user_id = (SELECT auth.uid()) OR (SELECT public.crown_is_admin()));

-- Inscricoes continuam exclusivamente pela RPC SECURITY DEFINER crown_join_challenge.
-- Nao conceder INSERT/UPDATE/DELETE diretos a jogadores.
