-- The Crown MVP: execute once in Supabase SQL Editor.
create extension if not exists pgcrypto;
create table if not exists public.crown_profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 username text not null unique check (char_length(username) between 3 and 30),
 points integer not null default 0 check(points >= 0),
 created_at timestamptz not null default now()
);
create table if not exists public.crown_admins (
 user_id uuid primary key references auth.users(id) on delete cascade
);
create or replace function public.crown_is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.crown_admins where user_id = (select auth.uid()));
$$;
create table if not exists public.crown_challenges (
 id uuid primary key default gen_random_uuid(),
 title text not null check(char_length(title) between 3 and 120),
 description text not null check(char_length(description) between 1 and 3000),
 image_url text,
 reward_points integer not null default 0 check(reward_points between 0 and 100000),
 deadline timestamptz,
 status text not null default 'published' check(status in ('published','closed')),
 created_at timestamptz not null default now()
);
create table if not exists public.crown_entries (
 id uuid primary key default gen_random_uuid(),
 challenge_id uuid not null references public.crown_challenges(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 status text not null default 'accepted' check(status in ('accepted','submitted','approved','rejected')),
 submission text,
 created_at timestamptz not null default now(),
 unique(challenge_id,user_id)
);
alter table public.crown_profiles enable row level security;
alter table public.crown_admins enable row level security;
alter table public.crown_challenges enable row level security;
alter table public.crown_entries enable row level security;
revoke all on public.crown_admins from anon,authenticated;
grant select on public.crown_admins to authenticated;
drop policy if exists crown_admin_self on public.crown_admins;
create policy crown_admin_self on public.crown_admins for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists crown_profiles_read on public.crown_profiles;
create policy crown_profiles_read on public.crown_profiles for select to authenticated using(true);
drop policy if exists crown_profiles_create on public.crown_profiles;
create policy crown_profiles_create on public.crown_profiles for insert to authenticated with check(id=(select auth.uid()) and points=0);
drop policy if exists crown_challenges_read on public.crown_challenges;
create policy crown_challenges_read on public.crown_challenges for select to authenticated using(status='published' or public.crown_is_admin());
drop policy if exists crown_challenges_admin_insert on public.crown_challenges;
create policy crown_challenges_admin_insert on public.crown_challenges for insert to authenticated with check(public.crown_is_admin());
drop policy if exists crown_challenges_admin_update on public.crown_challenges;
create policy crown_challenges_admin_update on public.crown_challenges for update to authenticated using(public.crown_is_admin()) with check(public.crown_is_admin());
drop policy if exists crown_entries_read on public.crown_entries;
create policy crown_entries_read on public.crown_entries for select to authenticated using(user_id=(select auth.uid()) or public.crown_is_admin());
drop policy if exists crown_entries_create on public.crown_entries;
create policy crown_entries_create on public.crown_entries for insert to authenticated
with check(user_id=(select auth.uid()) and status='accepted' and submission is null
 and exists(select 1 from public.crown_challenges c where c.id=challenge_id and c.status='published' and (c.deadline is null or c.deadline>now())));
drop policy if exists crown_entries_submit on public.crown_entries;
-- Submission uses a secure RPC so users cannot approve themselves.
create or replace function public.crown_submit_entry(p_entry uuid,p_submission text)
returns void language plpgsql security definer set search_path = '' as $$
begin
 if char_length(trim(coalesce(p_submission,''))) < 3 or char_length(p_submission)>3000 then
  raise exception 'Descrição inválida';
 end if;
 update public.crown_entries set submission=trim(p_submission),status='submitted'
 where id=p_entry and user_id=auth.uid() and status='accepted';
 if not found then raise exception 'Participação não encontrada ou já enviada'; end if;
end; $$;
create or replace function public.crown_review_entry(p_entry uuid,p_approve boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare v_user uuid;v_reward integer;
begin
 if not public.crown_is_admin() then raise exception 'Sem permissão'; end if;
 select e.user_id,c.reward_points into v_user,v_reward
 from public.crown_entries e join public.crown_challenges c on c.id=e.challenge_id
 where e.id=p_entry and e.status='submitted' for update of e;
 if v_user is null then raise exception 'Envio não encontrado'; end if;
 update public.crown_entries set status=case when p_approve then 'approved' else 'rejected' end where id=p_entry;
 if p_approve then update public.crown_profiles set points=points+v_reward where id=v_user; end if;
end; $$;
revoke all on function public.crown_submit_entry(uuid,text) from public;
revoke all on function public.crown_review_entry(uuid,boolean) from public;
grant execute on function public.crown_submit_entry(uuid,text) to authenticated;
grant execute on function public.crown_review_entry(uuid,boolean) to authenticated;
-- After creating your own account, grant admin only from SQL Editor:
-- insert into public.crown_admins(user_id) values ('YOUR_AUTH_USER_UUID');
