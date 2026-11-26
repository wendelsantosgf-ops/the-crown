create or replace function public.crown_admin_delete_account(p_target uuid)
returns void language plpgsql security definer set search_path = ''
as $$
declare w record;
begin
  if auth.uid() is null or not public.crown_is_admin() then
    raise exception 'Acesso negado.';
  end if;
  if p_target is null or p_target=auth.uid()
    or exists(select 1 from public.crown_admins where user_id=p_target)
    or exists(select 1 from public.crown_owners where user_id=p_target) then
    raise exception 'Conta protegida.';
  end if;
  lock table public.crown_challenges in share row exclusive mode;
  lock table public.crown_wagers in share row exclusive mode;
  if not exists(select 1 from public.crown_profiles where id=p_target) then
    raise exception 'Perfil não encontrado.';
  end if;
  if exists(select 1 from public.crown_challenge_results where settled_by=p_target)
    or exists(select 1 from public.crown_point_audit where actor_id=p_target)
    or exists(select 1 from public.crown_penalty_history where admin_id=p_target)
    or exists(select 1 from public.crown_suspensions where suspended_by=p_target or lifted_by=p_target) then
    raise exception 'Conta possui histórico administrativo protegido.';
  end if;
  for w in select * from public.crown_wagers
    where contestant_id=p_target and bettor_id<>p_target and status='pending'
    for update
  loop
    update public.crown_profiles set coins=coins+w.amount where id=w.bettor_id;
    if not found then raise exception 'Apostador não encontrado.'; end if;
    insert into public.crown_coin_ledger(user_id,challenge_id,wager_id,delta,reason)
    values(w.bettor_id,w.challenge_id,null,w.amount,'refund');
  end loop;
  update public.crown_coin_ledger set wager_id=null
    where wager_id in(select id from public.crown_wagers where bettor_id=p_target or contestant_id=p_target)
    and user_id<>p_target;
  delete from public.crown_coin_ledger where user_id=p_target;
  delete from public.crown_wagers where bettor_id=p_target or contestant_id=p_target;
  update public.crown_challenge_results set winner_id=null where winner_id=p_target;
  delete from public.crown_challenge_contestants where user_id=p_target;
  delete from public.crown_challenge_comments where author_id=p_target;
  delete from public.crown_point_audit where target_id=p_target;
  delete from public.crown_penalty_history where user_id=p_target;
  delete from public.crown_suspensions where user_id=p_target;
  delete from auth.users where id=p_target;
  if not found then raise exception 'Conta não encontrada.'; end if;
end;
$$;
revoke all on function public.crown_admin_delete_account(uuid) from public, anon;
grant execute on function public.crown_admin_delete_account(uuid) to authenticated;