-- Execute in Supabase SQL Editor after deploying the matching frontend.
-- Bootstrap OWNER once using the commented command at the bottom.
create table if not exists public.crown_owners (
 user_id uuid primary key references auth.users(id) on delete cascade
);
alter table public.crown_owners enable row level security;
revoke all on public.crown_owners from anon, authenticated;
create or replace function public.crown_is_owner()
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.crown_owners where user_id=(select auth.uid()));
$$;
revoke all on function public.crown_is_owner() from public;
grant execute on function public.crown_is_owner() to authenticated;
create table if not exists public.crown_point_audit (
 id bigint generated always as identity primary key,
 actor_id uuid not null references auth.users(id),
 target_id uuid not null references auth.users(id),
 delta integer not null check(delta<>0),
 reason text not null check(char_length(reason) between 5 and 300),
 created_at timestamptz not null default now()
);
alter table public.crown_point_audit enable row level security;
revoke all on public.crown_point_audit from anon,authenticated;
grant select on public.crown_point_audit to authenticated;
drop policy if exists crown_point_audit_admin_read on public.crown_point_audit;
create policy crown_point_audit_admin_read on public.crown_point_audit
for select to authenticated using(public.crown_is_admin());
create or replace function public.crown_adjust_points(p_target uuid,p_delta integer,p_reason text)
returns void language plpgsql security definer set search_path='' as $$
declare v_points integer;
begin
 if not public.crown_is_admin() then raise exception 'Acesso negado'; end if;
 if p_delta is null or p_delta=0 or p_delta < -100000 or p_delta > 100000 then
  raise exception 'Ajuste deve estar entre -100000 e 100000 e ser diferente de zero';
 end if;
 if char_length(trim(coalesce(p_reason,''))) not between 5 and 300 then raise exception 'Informe um motivo (5 a 300 caracteres)'; end if;
 select points into v_points from public.crown_profiles where id=p_target for update;
 if not found then raise exception 'Jogador não encontrado'; end if;
 if v_points::bigint+p_delta < 0 or v_points::bigint+p_delta > 2147483647 then raise exception 'Saldo inválido'; end if;
 update public.crown_profiles set points=points+p_delta where id=p_target;
 insert into public.crown_point_audit(actor_id,target_id,delta,reason)
 values(auth.uid(),p_target,p_delta,trim(p_reason));
end; $$;
create or replace function public.crown_set_admin(p_target uuid,p_enable boolean)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.crown_is_owner() then raise exception 'Somente o proprietário pode gerenciar administradores'; end if;
 if p_target is null or p_enable is null then raise exception 'Dados inválidos'; end if;
 if not exists(select 1 from public.crown_profiles where id=p_target) then raise exception 'Perfil não encontrado'; end if;
 if p_enable then
  insert into public.crown_admins(user_id) values(p_target) on conflict do nothing;
 else
  if exists(select 1 from public.crown_owners where user_id=p_target) then raise exception 'Não é permitido remover o proprietário'; end if;
  delete from public.crown_admins where user_id=p_target;
 end if;
end; $$;
revoke all on function public.crown_adjust_points(uuid,integer,text) from public;
revoke all on function public.crown_set_admin(uuid,boolean) from public;
grant execute on function public.crown_adjust_points(uuid,integer,text) to authenticated;
grant execute on function public.crown_set_admin(uuid,boolean) to authenticated;
-- ONE-TIME BOOTSTRAP: replace with your UUID from Authentication > Users.
-- insert into public.crown_owners(user_id) values ('YOUR_USER_UUID') on conflict do nothing;
-- insert into public.crown_admins(user_id) values ('YOUR_USER_UUID') on conflict do nothing;
