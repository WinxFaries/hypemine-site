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
