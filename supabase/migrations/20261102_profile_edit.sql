-- Run once in Supabase SQL Editor before using Editar perfil.
-- Allow each authenticated user to change only their own username.
grant update (username) on public.crown_profiles to authenticated;
drop policy if exists crown_profiles_update_own on public.crown_profiles;
create policy crown_profiles_update_own on public.crown_profiles
for update to authenticated
using (id = (select auth.uid()))
with check (id = (select auth.uid()));
