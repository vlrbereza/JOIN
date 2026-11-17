-- Join: схема бази даних для Supabase.
-- Відкрийте Supabase → SQL Editor → New query, вставте цей файл повністю і натисніть Run.

-- Профілі (ім'я, яке бачать інші учасники)
create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  name text check (char_length(name) <= 60),
  updated_at timestamptz default now()
);

-- Подорожі
create table if not exists public.trips (
  id text primary key check (id ~ '^[a-z0-9]{6,20}$'),
  owner_id uuid not null default auth.uid() references auth.users on delete cascade,
  members uuid[] not null default '{}',
  data jsonb not null default '{}',
  chosen_hotel jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Розділи подорожі: hotels, logistics, plan, food, shops, tips
create table if not exists public.trip_parts (
  trip_id text references public.trips on delete cascade,
  name text,
  data jsonb not null default '{}',
  updated_at timestamptz default now(),
  primary key (trip_id, name)
);

-- Закладки (❤️) кожного учасника
create table if not exists public.trip_votes (
  trip_id text references public.trips on delete cascade,
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  data jsonb not null default '{}',
  primary key (trip_id, user_id)
);

-- Пропозиції учасників
create table if not exists public.trip_notes (
  id uuid primary key default gen_random_uuid(),
  trip_id text references public.trips on delete cascade,
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  section text,
  text text check (char_length(text) <= 1000),
  created_at timestamptz default now()
);
create index if not exists trip_notes_trip on public.trip_notes(trip_id);

-- Чи є поточний користувач учасником подорожі
create or replace function public.is_member(tid text) returns boolean
language sql security definer stable set search_path = public as $$
  select exists (select 1 from trips where id = tid and auth.uid() = any(members));
$$;

-- Приєднатися за кодом
create or replace function public.join_trip(code text) returns boolean
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  update trips set members = array_append(members, auth.uid())
   where id = code and not (auth.uid() = any(members));
  return exists (select 1 from trips where id = code);
end $$;

-- Вийти з подорожі
create or replace function public.leave_trip(code text) returns void
language plpgsql security definer set search_path = public as $$
begin
  update trips set members = array_remove(members, auth.uid()) where id = code and owner_id <> auth.uid();
end $$;

-- Короткий опис подорожі для запрошеного (до приєднання)
create or replace function public.trip_preview(code text) returns jsonb
language sql security definer stable set search_path = public as $$
  select data || jsonb_build_object('id', id, 'members_count', cardinality(members))
    from trips where id = code and auth.uid() is not null;
$$;

-- Захист даних (Row Level Security)
alter table public.profiles   enable row level security;
alter table public.trips      enable row level security;
alter table public.trip_parts enable row level security;
alter table public.trip_votes enable row level security;
alter table public.trip_notes enable row level security;

drop policy if exists "profiles read" on public.profiles;
drop policy if exists "profiles insert own" on public.profiles;
drop policy if exists "profiles update own" on public.profiles;
create policy "profiles read" on public.profiles for select to authenticated using (true);
create policy "profiles insert own" on public.profiles for insert to authenticated with check (id = auth.uid());
create policy "profiles update own" on public.profiles for update to authenticated using (id = auth.uid());

drop policy if exists "trips read" on public.trips;
drop policy if exists "trips create" on public.trips;
drop policy if exists "trips update" on public.trips;
drop policy if exists "trips delete" on public.trips;
create policy "trips read" on public.trips for select to authenticated using (auth.uid() = any(members));
create policy "trips create" on public.trips for insert to authenticated
  with check (owner_id = auth.uid() and auth.uid() = any(members));
create policy "trips update" on public.trips for update to authenticated
  using (auth.uid() = any(members)) with check (auth.uid() = any(members));
create policy "trips delete" on public.trips for delete to authenticated using (owner_id = auth.uid());

drop policy if exists "parts all" on public.trip_parts;
create policy "parts all" on public.trip_parts for all to authenticated
  using (public.is_member(trip_id)) with check (public.is_member(trip_id));

drop policy if exists "votes read" on public.trip_votes;
drop policy if exists "votes write own" on public.trip_votes;
drop policy if exists "votes update own" on public.trip_votes;
drop policy if exists "votes delete own" on public.trip_votes;
create policy "votes read" on public.trip_votes for select to authenticated using (public.is_member(trip_id));
create policy "votes write own" on public.trip_votes for insert to authenticated
  with check (user_id = auth.uid() and public.is_member(trip_id));
create policy "votes update own" on public.trip_votes for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid() and public.is_member(trip_id));
create policy "votes delete own" on public.trip_votes for delete to authenticated using (user_id = auth.uid());

drop policy if exists "notes read" on public.trip_notes;
drop policy if exists "notes create" on public.trip_notes;
drop policy if exists "notes delete own" on public.trip_notes;
create policy "notes read" on public.trip_notes for select to authenticated using (public.is_member(trip_id));
create policy "notes create" on public.trip_notes for insert to authenticated
  with check (user_id = auth.uid() and public.is_member(trip_id));
create policy "notes delete own" on public.trip_notes for delete to authenticated using (user_id = auth.uid());

-- Оновлення в реальному часі (щоб усі учасники бачили зміни одразу)
do $$
declare t text;
begin
  foreach t in array array['trips','trip_parts','trip_votes','trip_notes'] loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then null;
    end;
  end loop;
end $$;
