-- The Crown: site-wide appearance editor (run once in Supabase SQL Editor).
create table if not exists public.crown_site_settings (
 id integer primary key default 1 check(id=1),
 primary_color text not null default '#8c383f',
 accent_color text not null default '#d6ad79',
 background_color text not null default '#0c0909',
 menu_order text[] not null default array['Início','Desafios','Ranking','Apostas','Audiência','Mensagens','Arquivos','Regras'],
 hidden_menu text[] not null default array[]::text[],
 updated_at timestamptz not null default now()
);
insert into public.crown_site_settings(id) values(1) on conflict do nothing;
alter table public.crown_site_settings enable row level security;
revoke all on public.crown_site_settings from anon,authenticated;
grant select on public.crown_site_settings to anon,authenticated;
drop policy if exists crown_settings_public_read on public.crown_site_settings;
create policy crown_settings_public_read on public.crown_site_settings for select to anon,authenticated using(true);
create or replace function public.crown_save_site_settings(
 p_primary text,p_accent text,p_background text,p_order text[],p_hidden text[]
) returns void language plpgsql security definer set search_path='' as $$
declare v_allowed text[]:=array['Início','Desafios','Ranking','Apostas','Audiência','Mensagens','Arquivos','Regras'];
begin
 if not public.crown_is_owner() then raise exception 'Somente o proprietário pode alterar o visual'; end if;
 if p_primary !~ '^#[0-9a-fA-F]{6}$' or p_accent !~ '^#[0-9a-fA-F]{6}$' or p_background !~ '^#[0-9a-fA-F]{6}$'
 then raise exception 'Cor hexadecimal inválida'; end if;
 if p_order is null or cardinality(p_order)<>8
  or (select count(distinct x) from unnest(p_order) x)<>8
  or exists(select 1 from unnest(p_order) x where not (x=any(v_allowed)))
 then raise exception 'Ordem de abas inválida'; end if;
 if p_hidden is null or exists(select 1 from unnest(p_hidden) x where not (x=any(v_allowed)))
 then raise exception 'Abas ocultas inválidas'; end if;
 update public.crown_site_settings set primary_color=p_primary,accent_color=p_accent,background_color=p_background,
 menu_order=p_order,hidden_menu=p_hidden,updated_at=now() where id=1;
end; $$;
revoke all on function public.crown_save_site_settings(text,text,text,text[],text[]) from public;
grant execute on function public.crown_save_site_settings(text,text,text,text[],text[]) to authenticated;
