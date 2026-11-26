create or replace function public.crown_admin_delete_account(p_target uuid)
returns void language plpgsql security definer set search_path = ''
as $$
begin
  if auth.uid() is null or not exists (select 1 from public.crown_admins where user_id=auth.uid()) then
    raise exception 'Acesso negado.';
  end if;
  if p_target is null or p_target=auth.uid() or exists (select 1 from public.crown_admins where user_id=p_target) then
    raise exception 'Não é permitido excluir administradores.';
  end if;
  if not exists (select 1 from public.crown_profiles where id=p_target) then
    raise exception 'Perfil não encontrado.';
  end if;
  delete from public.crown_penalty_history where user_id=p_target;
  delete from public.crown_suspensions where user_id=p_target;
  delete from auth.users where id=p_target;
  if not found then raise exception 'Conta não encontrada.'; end if;
end;
$$;
revoke all on function public.crown_admin_delete_account(uuid) from public, anon;
grant execute on function public.crown_admin_delete_account(uuid) to authenticated;
