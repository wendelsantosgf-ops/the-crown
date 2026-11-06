-- Perfis públicos do The Crown: somente dados explicitamente públicos.
alter table public.crown_profiles add column if not exists bio text not null default '';
alter table public.crown_profiles drop constraint if exists crown_profiles_bio_length;
alter table public.crown_profiles add constraint crown_profiles_bio_length check (char_length(bio) <= 160);

create or replace view public.crown_public_player_cards as
select id, nickname, avatar_path, bio, points
from public.crown_profiles
where account_type = 'player';
grant select on public.crown_public_player_cards to authenticated;
