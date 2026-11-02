-- The Crown: player avatars (execute in Supabase SQL Editor)
alter table public.crown_profiles add column if not exists avatar_path text;
grant update (avatar_path) on public.crown_profiles to authenticated;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('crown-avatars','crown-avatars',true,8388608,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=true,file_size_limit=8388608,allowed_mime_types=array['image/jpeg','image/png','image/webp'];
drop policy if exists crown_avatar_upload on storage.objects;
create policy crown_avatar_upload on storage.objects for insert to authenticated
with check (bucket_id='crown-avatars' and (storage.foldername(name))[1]=(select auth.uid())::text);
drop policy if exists crown_avatar_read on storage.objects;
create policy crown_avatar_read on storage.objects for select to public using(bucket_id='crown-avatars');
