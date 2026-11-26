create or replace function public.crown_admin_grant_role(p_target uuid)
returns void language plpgsql security definer set search_path = ''
as $$
begin
  if auth.uid() is null or not exists (select 1 from public.crown_admins where user_id=auth.uid()) then
    raise exception 'Somente administradores.';
  end if;
  if not exists (select 1 from public.crown_profiles where id=p_target) then
    raise exception 'Perfil não encontrado.';
  end if;
  insert into public.crown_admins(user_id) values(p_target) on conflict do nothing;
end;
$$;
revoke all on function public.crown_admin_grant_role(uuid) from public, anon;
grant execute on function public.crown_admin_grant_role(uuid) to authenticated;