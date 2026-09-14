-- Lexora v1.0 - authentication and cloud progress
-- Run this once in Supabase SQL Editor.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  username text unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.saved_words (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  word text not null,
  language text not null,
  note text not null default '',
  level smallint not null default 0 check (level between 0 and 5),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, word, language)
);

create table if not exists public.user_progress (
  user_id uuid primary key references auth.users(id) on delete cascade,
  xp integer not null default 0,
  streak integer not null default 0,
  words_explored integer not null default 0,
  dark_mode boolean not null default false,
  updated_at timestamptz not null default now()
);

create index if not exists saved_words_user_id_idx on public.saved_words(user_id);
create index if not exists saved_words_user_word_idx on public.saved_words(user_id, word);

alter table public.profiles enable row level security;
alter table public.saved_words enable row level security;
alter table public.user_progress enable row level security;

revoke all on table public.profiles from anon, authenticated;
revoke all on table public.saved_words from anon, authenticated;
revoke all on table public.user_progress from anon, authenticated;

grant select, insert, update on table public.profiles to authenticated;
grant select, insert, update, delete on table public.saved_words to authenticated;
grant select, insert, update on table public.user_progress to authenticated;

drop policy if exists "Users can view own profile" on public.profiles;
drop policy if exists "Users can insert own profile" on public.profiles;
drop policy if exists "Users can update own profile" on public.profiles;
drop policy if exists "Users can view own words" on public.saved_words;
drop policy if exists "Users can insert own words" on public.saved_words;
drop policy if exists "Users can update own words" on public.saved_words;
drop policy if exists "Users can delete own words" on public.saved_words;
drop policy if exists "Users can view own progress" on public.user_progress;
drop policy if exists "Users can insert own progress" on public.user_progress;
drop policy if exists "Users can update own progress" on public.user_progress;

create policy "Users can view own profile" on public.profiles for select to authenticated using ((select auth.uid()) = id);
create policy "Users can insert own profile" on public.profiles for insert to authenticated with check ((select auth.uid()) = id);
create policy "Users can update own profile" on public.profiles for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

create policy "Users can view own words" on public.saved_words for select to authenticated using ((select auth.uid()) = user_id);
create policy "Users can insert own words" on public.saved_words for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Users can update own words" on public.saved_words for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Users can delete own words" on public.saved_words for delete to authenticated using ((select auth.uid()) = user_id);

create policy "Users can view own progress" on public.user_progress for select to authenticated using ((select auth.uid()) = user_id);
create policy "Users can insert own progress" on public.user_progress for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Users can update own progress" on public.user_progress for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create or replace function public.handle_new_lexora_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, display_name, username)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', split_part(new.email, '@', 1)),
    null
  )
  on conflict (id) do nothing;

  insert into public.user_progress (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created_lexora on auth.users;
create trigger on_auth_user_created_lexora
after insert on auth.users
for each row execute procedure public.handle_new_lexora_user();

create or replace function public.set_lexora_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles for each row execute procedure public.set_lexora_updated_at();

drop trigger if exists saved_words_set_updated_at on public.saved_words;
create trigger saved_words_set_updated_at before update on public.saved_words for each row execute procedure public.set_lexora_updated_at();

drop trigger if exists progress_set_updated_at on public.user_progress;
create trigger progress_set_updated_at before update on public.user_progress for each row execute procedure public.set_lexora_updated_at();
