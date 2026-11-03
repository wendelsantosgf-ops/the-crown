-- Public nicknames separate from the private registered name (username).
alter table public.crown_profiles add column if not exists nickname text;
-- Existing accounts receive neutral nicknames so their registered names are not disclosed.
update public.crown_profiles set nickname='player_'||replace(left(id::text,8),'-','') where nickname is null;
alter table public.crown_profiles alter column nickname set not null;
alter table public.crown_profiles add constraint crown_nickname_format check (nickname ~ '^[A-Za-z0-9_]{3,30}$');
create unique index if not exists crown_profiles_nickname_unique on public.crown_profiles(lower(nickname));
create or replace function public.crown_profile_nickname_default()
returns trigger language plpgsql set search_path='' as $$
begin
 if new.nickname is null or btrim(new.nickname)='' then
   new.nickname := 'player_'||replace(left(new.id::text,8),'-','');
 end if;
 return new;
end; $$;
drop trigger if exists crown_profile_nickname_default_trigger on public.crown_profiles;
create trigger crown_profile_nickname_default_trigger before insert on public.crown_profiles
for each row execute function public.crown_profile_nickname_default();

-- Public-facing leaderboard view exposes no registered names.
create or replace view public.crown_public_leaderboard
with (security_invoker=true) as
select id,nickname,points,created_at,avatar_path from public.crown_profiles;
grant select on public.crown_public_leaderboard to authenticated;

-- NOTE: Existing table-wide RLS SELECT policies may still expose username via direct API.
-- Public data consumers must use the view; full privacy needs an RLS/grants audit.
