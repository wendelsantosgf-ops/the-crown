-- The Crown: public files and administrator-managed live embeds
create table if not exists public.crown_files (
 id uuid primary key default gen_random_uuid(),
 author_id uuid not null references auth.users(id) on delete cascade,
 title text not null check (char_length(title) between 1 and 120),
 description text not null default '',
 storage_path text not null unique,
 file_name text not null,
 mime_type text not null,
 size_bytes bigint not null check (size_bytes > 0 and size_bytes <= 10485760),
 created_at timestamptz not null default now()
);
create table if not exists public.crown_live (
 id integer primary key default 1 check (id=1),
 url text not null default '',
 title text not null default '',
 updated_at timestamptz not null default now()
);
insert into public.crown_live(id) values(1) on conflict do nothing;
alter table public.crown_files enable row level security;
alter table public.crown_live enable row level security;
drop policy if exists crown_files_read on public.crown_files;
create policy crown_files_read on public.crown_files for select to authenticated using (true);
drop policy if exists crown_files_insert on public.crown_files;
create policy crown_files_insert on public.crown_files for insert to authenticated
 with check (author_id=auth.uid() and exists(select 1 from public.crown_profiles p where p.id=auth.uid() and (p.account_type='player' or public.crown_is_admin())));
drop policy if exists crown_files_delete on public.crown_files;
create policy crown_files_delete on public.crown_files for delete to authenticated
 using (author_id=auth.uid() or public.crown_is_admin());
drop policy if exists crown_live_read on public.crown_live;
create policy crown_live_read on public.crown_live for select to authenticated using (true);
drop policy if exists crown_live_update on public.crown_live;
create policy crown_live_update on public.crown_live for update to authenticated
 using (public.crown_is_admin()) with check (public.crown_is_admin());
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('crown-files','crown-files',false,10485760,null)
on conflict(id) do update set public=false,file_size_limit=10485760;
drop policy if exists crown_files_storage_read on storage.objects;
create policy crown_files_storage_read on storage.objects for select to authenticated
 using(bucket_id='crown-files' and exists(select 1 from public.crown_files f where f.storage_path=name));
drop policy if exists crown_files_storage_upload on storage.objects;
create policy crown_files_storage_upload on storage.objects for insert to authenticated
 with check(bucket_id='crown-files' and split_part(name,'/',1)=auth.uid()::text
 and exists(select 1 from public.crown_profiles p where p.id=auth.uid() and (p.account_type='player' or public.crown_is_admin())));
drop policy if exists crown_files_storage_delete on storage.objects;
create policy crown_files_storage_delete on storage.objects for delete to authenticated
 using(bucket_id='crown-files' and (split_part(name,'/',1)=auth.uid()::text or public.crown_is_admin()));
grant select,insert,delete on public.crown_files to authenticated;
grant select,update on public.crown_live to authenticated;
