-- Enable challenge creation for authenticated administrators only.
-- RLS protects direct API access; a UI-only check is not sufficient.
alter table public.crown_challenges enable row level security;
grant select on public.crown_challenges to authenticated;
grant insert on public.crown_challenges to authenticated;

drop policy if exists crown_challenges_admin_create on public.crown_challenges;
create policy crown_challenges_admin_create
on public.crown_challenges for insert to authenticated
with check (public.crown_is_admin());

-- Ensure admin can read their newly published challenge, and all signed-in
-- users can see published challenges. Admin can also see drafts.
drop policy if exists crown_challenges_authenticated_read on public.crown_challenges;
create policy crown_challenges_authenticated_read
on public.crown_challenges for select to authenticated
using (status = 'published' or public.crown_is_admin());
