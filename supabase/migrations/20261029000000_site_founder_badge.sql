-- HypeMine first-account verified badge
-- Run once in Supabase Dashboard > SQL Editor.
-- The oldest existing auth account is preserved as the founder; future signups
-- can never claim the badge because the auth trigger uses a one-row unique key.

create table if not exists public.site_founder_badge (
  singleton boolean primary key default true check (singleton = true),
  user_id uuid not null unique,
  created_at timestamptz not null default now()
);

alter table public.site_founder_badge enable row level security;
revoke all on table public.site_founder_badge from anon, authenticated;

insert into public.site_founder_badge (singleton, user_id)
select true, id
from auth.users
order by created_at asc, id asc
limit 1
on conflict (singleton) do nothing;

create or replace function public.capture_first_site_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.site_founder_badge (singleton, user_id)
  values (true, new.id)
  on conflict (singleton) do nothing;
  return new;
end;
$$;

drop trigger if exists capture_first_site_user on auth.users;
create trigger capture_first_site_user
after insert on auth.users
for each row execute function public.capture_first_site_user();

create or replace function public.is_site_founder()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.site_founder_badge
    where singleton = true
      and user_id = auth.uid()
  );
$$;

revoke all on function public.is_site_founder() from public, anon;
grant execute on function public.is_site_founder() to authenticated;

-- Public optimized profile photos. Upload is restricted to the signed-in user's
-- own folder (auth.uid()); the public bucket allows rendering avatar URLs.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('hm-avatars', 'hm-avatars', true, 10485760, array['image/webp','image/jpeg','image/png','image/gif','image/avif','image/apng','video/mp4'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "HypeMine avatars upload own folder" on storage.objects;
create policy "HypeMine avatars upload own folder"
on storage.objects for insert to authenticated
with check (bucket_id = 'hm-avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "HypeMine avatars read own folder" on storage.objects;
create policy "HypeMine avatars read own folder"
on storage.objects for select to authenticated
using (bucket_id = 'hm-avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "HypeMine avatars update own folder" on storage.objects;
create policy "HypeMine avatars update own folder"
on storage.objects for update to authenticated
using (bucket_id = 'hm-avatars' and (storage.foldername(name))[1] = (select auth.uid())::text)
with check (bucket_id = 'hm-avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);

drop policy if exists "HypeMine avatars delete own folder" on storage.objects;
create policy "HypeMine avatars delete own folder"
on storage.objects for delete to authenticated
using (bucket_id = 'hm-avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
