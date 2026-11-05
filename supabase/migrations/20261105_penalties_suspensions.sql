-- The Crown: suspensões e penalidades com auditoria
create table if not exists public.crown_suspensions (
 user_id uuid primary key references auth.users(id) on delete cascade,
 reason text not null check (length(trim(reason)) between 5 and 500),
 suspended_at timestamptz not null default now(),
 suspended_by uuid not null references auth.users(id),
 expires_at timestamptz,
 lifted_at timestamptz,
 lifted_by uuid references auth.users(id),
 constraint crown_suspension_dates check (expires_at is null or expires_at > suspended_at)
);
create table if not exists public.crown_penalty_history (
 id bigint generated always as identity primary key,
 user_id uuid not null references auth.users(id),
 admin_id uuid not null references auth.users(id),
 action text not null check (action in ('suspend','reinstate','disqualify')),
 reason text not null,
 challenge_id uuid,
 created_at timestamptz not null default now()
);
alter table public.crown_suspensions enable row level security;
alter table public.crown_penalty_history enable row level security;
revoke all on public.crown_suspensions, public.crown_penalty_history from anon, authenticated;
grant select on public.crown_suspensions to authenticated;
grant select on public.crown_penalty_history to authenticated;
drop policy if exists crown_suspensions_view on public.crown_suspensions;
create policy crown_suspensions_view on public.crown_suspensions for select to authenticated using (true);
drop policy if exists crown_penalties_view on public.crown_penalty_history;
create policy crown_penalties_view on public.crown_penalty_history for select to authenticated using (user_id = (select auth.uid()) or (select public.crown_is_admin()));

create or replace function public.crown_is_suspended(p_user uuid)
returns boolean language sql stable security definer set search_path = '' as $$
 select exists (select 1 from public.crown_suspensions s where s.user_id = p_user and s.lifted_at is null and (s.expires_at is null or s.expires_at > now()));
$$;
revoke all on function public.crown_is_suspended(uuid) from public;
grant execute on function public.crown_is_suspended(uuid) to authenticated;

create or replace function public.crown_manage_suspension(p_target uuid,p_suspend boolean,p_reason text,p_days integer default null)
returns void language plpgsql security definer set search_path = '' as $$
declare v_admin uuid := auth.uid();
begin
 if v_admin is null or not public.crown_is_admin() then raise exception 'Apenas administradores podem aplicar penalidades'; end if;
 if p_target is null or not exists(select 1 from public.crown_profiles where id=p_target) then raise exception 'Jogador não encontrado'; end if;
 if length(trim(coalesce(p_reason,''))) < 5 then raise exception 'Informe um motivo com ao menos 5 caracteres'; end if;
 if p_days is not null and (p_days < 1 or p_days > 365) then raise exception 'Duração deve ser entre 1 e 365 dias'; end if;
 if p_suspend then
  if exists(select 1 from public.crown_admins where user_id=p_target) then raise exception 'Não é permitido suspender administradores'; end if;
  insert into public.crown_suspensions(user_id,reason,suspended_by,expires_at,lifted_at,lifted_by)
  values(p_target,trim(p_reason),v_admin,case when p_days is null then null else now()+make_interval(days=>p_days) end,null,null)
  on conflict(user_id) do update set reason=excluded.reason,suspended_by=excluded.suspended_by,suspended_at=now(),expires_at=excluded.expires_at,lifted_at=null,lifted_by=null;
 else
  update public.crown_suspensions set lifted_at=now(),lifted_by=v_admin where user_id=p_target and lifted_at is null;
  if not found then raise exception 'Jogador não possui suspensão ativa'; end if;
 end if;
 insert into public.crown_penalty_history(user_id,admin_id,action,reason) values(p_target,v_admin,case when p_suspend then 'suspend' else 'reinstate' end,trim(p_reason));
end; $$;
revoke all on function public.crown_manage_suspension(uuid,boolean,text,integer) from public;
grant execute on function public.crown_manage_suspension(uuid,boolean,text,integer) to authenticated;

-- Defesa no banco: bloqueia novos ingressos e submissões enquanto suspenso.
create or replace function public.crown_reject_suspended_entry()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if public.crown_is_suspended(new.user_id) and (tg_op='INSERT' or new.status is distinct from old.status or new.submission is distinct from old.submission) then
  raise exception 'Conta suspensa: participação indisponível';
 end if;
 return new;
end; $$;
drop trigger if exists crown_reject_suspended_entry on public.crown_entries;
create trigger crown_reject_suspended_entry before insert or update on public.crown_entries
for each row execute function public.crown_reject_suspended_entry();

create or replace function public.crown_reject_suspended_contestant()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if public.crown_is_suspended(new.user_id) then raise exception 'Conta suspensa: participação indisponível'; end if;
 return new;
end; $$;
drop trigger if exists crown_reject_suspended_contestant on public.crown_challenge_contestants;
create trigger crown_reject_suspended_contestant before insert on public.crown_challenge_contestants
for each row execute function public.crown_reject_suspended_contestant();

create or replace function public.crown_disqualify_entry(p_entry uuid,p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
declare v_entry public.crown_entries%rowtype;
begin
 if auth.uid() is null or not public.crown_is_admin() then raise exception 'Apenas administradores'; end if;
 if length(trim(coalesce(p_reason,''))) < 5 then raise exception 'Informe o motivo'; end if;
 select * into v_entry from public.crown_entries where id=p_entry for update;
 if not found then raise exception 'Participação não encontrada'; end if;
 if exists(select 1 from public.crown_challenge_results where challenge_id=v_entry.challenge_id) then raise exception 'Desafio já finalizado: resultado não pode ser alterado'; end if;
 delete from public.crown_challenge_contestants where challenge_id=v_entry.challenge_id and user_id=v_entry.user_id;
 update public.crown_entries set status='rejected' where id=p_entry;
 insert into public.crown_penalty_history(user_id,admin_id,action,reason,challenge_id)
 values(v_entry.user_id,auth.uid(),'disqualify',trim(p_reason),v_entry.challenge_id);
end; $$;
revoke all on function public.crown_disqualify_entry(uuid,text) from public;
grant execute on function public.crown_disqualify_entry(uuid,text) to authenticated;
