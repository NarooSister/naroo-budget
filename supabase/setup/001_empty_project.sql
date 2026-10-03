-- Naroo: 빈 Supabase 프로젝트용 초기 스키마 (2026-10-02)
-- 새 프로젝트의 SQL Editor에서 postgres 역할로 이 파일 전체를 한 번 실행한다.
-- 20261002090000까지의 migration 3개를 순서대로 포함한다.
-- 기존 프로젝트를 삭제/초기화하지 않는다. Naroo 테이블이 있으면 중단한다.
-- 성공 시 migration 이력도 등록하므로 포함된 migration을 따로 재실행하지 않는다.
-- 원본은 supabase/migrations/이며 이 파일은 새 프로젝트 설치용 스냅샷이다.
--
-- 실행 후:
-- 1. 새 프로젝트의 Google 로그인 설정 및 앱의 Supabase URL/공개 키를 설정한다.
-- 2. 앱에서 Google 로그인 1회 후 Authentication > Users의 사용자 UUID를 확인한다.
-- 3. supabase/bootstrap/001_initial_household_single_user.sql의 user_a_id와
--    ready_to_run을 수정해 실행한다. 가계부 1개와 기본 카테고리 16개를 만든다.
-- 4. supabase/tests/rls_shared_crud.sql로 권한을 검증한다(검증 데이터는 rollback).

begin;

do $naroo_empty_check$
declare table_name text;
begin
  foreach table_name in array array[
    'profiles', 'households', 'household_members',
    'categories', 'transactions', 'monthly_budgets'
  ] loop
    if to_regclass('public.' || table_name) is not null then
      raise exception '빈 프로젝트 전용 SQL입니다. public.% 테이블이 이미 있습니다.', table_name;
    end if;
  end loop;
end;
$naroo_empty_check$;

create schema if not exists supabase_migrations;
create table if not exists supabase_migrations.schema_migrations (
  version text not null primary key,
  statements text[],
  name text
);

do $naroo_history_check$
begin
  if exists (select 1 from supabase_migrations.schema_migrations) then
    raise exception '기존 migration 이력이 있습니다. 빈 프로젝트에서 실행해 주세요.';
  end if;
end;
$naroo_history_check$;

-- BEGIN MIGRATION: 20260928110000_initial_schema.sql
-- Phase 2: Naroo core schema + household-scoped RLS
-- Bootstrap data and default categories are intentionally deferred to Phase 4.

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.household_members (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  display_name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint household_members_household_user_key unique (household_id, user_id),
  -- MVP: one household per login user
  constraint household_members_user_id_key unique (user_id)
);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  type text not null,
  name text not null,
  is_default boolean not null default false,
  is_hidden boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint categories_type_check check (type in ('income', 'expense')),
  constraint categories_name_not_blank check (char_length(trim(name)) > 0)
);

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  member_id uuid not null references public.household_members (id),
  type text not null,
  amount integer not null,
  category_id uuid not null references public.categories (id),
  occurred_on date not null default ((timezone('Asia/Seoul', now()))::date),
  memo text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint transactions_type_check check (type in ('income', 'expense')),
  constraint transactions_amount_positive check (amount > 0)
);

create table public.monthly_budgets (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households (id) on delete cascade,
  year integer not null,
  month integer not null,
  amount integer not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint monthly_budgets_year_check check (year >= 2000 and year <= 2100),
  constraint monthly_budgets_month_check check (month >= 1 and month <= 12),
  constraint monthly_budgets_amount_non_negative check (amount >= 0),
  constraint monthly_budgets_household_year_month_key unique (household_id, year, month)
);

-- True when the current auth user belongs to the given household.
-- SECURITY DEFINER avoids RLS recursion on household_members.
create or replace function public.is_household_member(target_household_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.household_members hm
    where hm.household_id = target_household_id
      and hm.user_id = auth.uid()
  );
$$;

revoke all on function public.is_household_member(uuid) from public;
grant execute on function public.is_household_member(uuid) to authenticated;

-- Keep transaction member/category aligned with household and type.
create or replace function public.validate_transaction_refs()
returns trigger
language plpgsql
as $$
declare
  member_household_id uuid;
  category_household_id uuid;
  category_type text;
begin
  select hm.household_id
    into member_household_id
  from public.household_members hm
  where hm.id = new.member_id;

  if member_household_id is null then
    raise exception 'member_id % does not exist', new.member_id;
  end if;

  if member_household_id <> new.household_id then
    raise exception 'member_id must belong to the same household';
  end if;

  select c.household_id, c.type
    into category_household_id, category_type
  from public.categories c
  where c.id = new.category_id;

  if category_household_id is null then
    raise exception 'category_id % does not exist', new.category_id;
  end if;

  if category_household_id <> new.household_id then
    raise exception 'category_id must belong to the same household';
  end if;

  if category_type <> new.type then
    raise exception 'category type (%) must match transaction type (%)', category_type, new.type;
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------

create index household_members_household_id_idx
  on public.household_members (household_id);

create index categories_household_id_idx
  on public.categories (household_id);

create index categories_household_id_type_idx
  on public.categories (household_id, type);

create index transactions_household_id_occurred_on_idx
  on public.transactions (household_id, occurred_on desc);

create index transactions_household_id_type_idx
  on public.transactions (household_id, type);

create index transactions_member_id_idx
  on public.transactions (member_id);

create index transactions_category_id_idx
  on public.transactions (category_id);

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

create trigger households_set_updated_at
  before update on public.households
  for each row execute function public.set_updated_at();

create trigger household_members_set_updated_at
  before update on public.household_members
  for each row execute function public.set_updated_at();

create trigger categories_set_updated_at
  before update on public.categories
  for each row execute function public.set_updated_at();

create trigger transactions_set_updated_at
  before update on public.transactions
  for each row execute function public.set_updated_at();

create trigger monthly_budgets_set_updated_at
  before update on public.monthly_budgets
  for each row execute function public.set_updated_at();

create trigger transactions_validate_refs
  before insert or update on public.transactions
  for each row execute function public.validate_transaction_refs();

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;
alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.categories enable row level security;
alter table public.transactions enable row level security;
alter table public.monthly_budgets enable row level security;

-- profiles: own row only (created on first login in Phase 3)
create policy profiles_select_own
  on public.profiles
  for select
  to authenticated
  using (id = auth.uid());

create policy profiles_insert_own
  on public.profiles
  for insert
  to authenticated
  with check (id = auth.uid());

create policy profiles_update_own
  on public.profiles
  for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- households: members can read; create/update via service role / bootstrap SQL
create policy households_select_member
  on public.households
  for select
  to authenticated
  using (public.is_household_member(id));

-- household_members: members can read their household roster
create policy household_members_select_member
  on public.household_members
  for select
  to authenticated
  using (public.is_household_member(household_id));

-- categories: full CRUD inside own household
create policy categories_select_member
  on public.categories
  for select
  to authenticated
  using (public.is_household_member(household_id));

create policy categories_insert_member
  on public.categories
  for insert
  to authenticated
  with check (public.is_household_member(household_id));

create policy categories_update_member
  on public.categories
  for update
  to authenticated
  using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));

create policy categories_delete_member
  on public.categories
  for delete
  to authenticated
  using (public.is_household_member(household_id));

-- transactions: full CRUD inside own household
create policy transactions_select_member
  on public.transactions
  for select
  to authenticated
  using (public.is_household_member(household_id));

create policy transactions_insert_member
  on public.transactions
  for insert
  to authenticated
  with check (public.is_household_member(household_id));

create policy transactions_update_member
  on public.transactions
  for update
  to authenticated
  using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));

create policy transactions_delete_member
  on public.transactions
  for delete
  to authenticated
  using (public.is_household_member(household_id));

-- monthly_budgets: full CRUD inside own household
create policy monthly_budgets_select_member
  on public.monthly_budgets
  for select
  to authenticated
  using (public.is_household_member(household_id));

create policy monthly_budgets_insert_member
  on public.monthly_budgets
  for insert
  to authenticated
  with check (public.is_household_member(household_id));

create policy monthly_budgets_update_member
  on public.monthly_budgets
  for update
  to authenticated
  using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));

create policy monthly_budgets_delete_member
  on public.monthly_budgets
  for delete
  to authenticated
  using (public.is_household_member(household_id));
-- END MIGRATION: 20260928110000_initial_schema.sql

-- BEGIN MIGRATION: 20260929060000_explicit_api_grants.sql
-- Data API auto-exposure is disabled on the hosted project.
-- Grant table access explicitly; RLS still restricts rows by auth.uid().
revoke all privileges on table
  public.profiles, public.households, public.household_members,
  public.categories, public.transactions, public.monthly_budgets
from anon, authenticated;

grant usage on schema public to authenticated;
grant select, insert, update on table public.profiles to authenticated;
grant select on table public.households, public.household_members to authenticated;
grant select, insert, update on table public.categories to authenticated;
grant select, insert, update, delete on table
  public.transactions, public.monthly_budgets
to authenticated;
-- END MIGRATION: 20260929060000_explicit_api_grants.sql

-- BEGIN MIGRATION: 20261002090000_members_attribution.sql
-- Accountless members never confer login access. Existing attribution is kept.
alter table public.household_members
  alter column user_id drop not null,
  add column is_hidden boolean not null default false,
  add constraint household_members_linked_visible check (user_id is null or not is_hidden);

alter table public.transactions
  alter column member_id drop not null,
  add column attribution_kind text not null default 'member',
  add constraint transactions_attribution_check check (
    (attribution_kind = 'member' and member_id is not null)
    or (attribution_kind = 'shared' and member_id is null)
  );

revoke insert, update, delete on public.household_members from public, anon, authenticated;

create function public.create_custom_member(target_household_id uuid, member_name text)
returns public.household_members
language plpgsql security definer set search_path = ''
as $$
declare result public.household_members;
begin
  if auth.uid() is null or not public.is_household_member(target_household_id) then
    raise exception using errcode = '42501', message = 'Household access denied';
  end if;
  if member_name is null or member_name !~ '[^[:space:]]' then
    raise exception using errcode = '23514', message = 'Member name is required';
  end if;
  insert into public.household_members (household_id, user_id, display_name)
  values (target_household_id, null, btrim(member_name)) returning * into result;
  return result;
end;
$$;

create function public.rename_custom_member(target_member_id uuid, member_name text)
returns public.household_members
language plpgsql security definer set search_path = ''
as $$
declare result public.household_members;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'Login required';
  end if;
  if member_name is null or member_name !~ '[^[:space:]]' then
    raise exception using errcode = '23514', message = 'Member name is required';
  end if;
  update public.household_members
  set display_name = btrim(member_name)
  where id = target_member_id and user_id is null
    and public.is_household_member(household_id)
  returning * into result;
  if not found then
    raise exception using errcode = '42501', message = 'Custom member access denied';
  end if;
  return result;
end;
$$;

create function public.set_custom_member_hidden(target_member_id uuid, hidden boolean)
returns public.household_members
language plpgsql security definer set search_path = ''
as $$
declare result public.household_members;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'Login required';
  end if;
  update public.household_members
  set is_hidden = hidden
  where id = target_member_id and user_id is null
    and public.is_household_member(household_id)
  returning * into result;
  if not found then
    raise exception using errcode = '42501', message = 'Custom member access denied';
  end if;
  return result;
end;
$$;

revoke all on function public.create_custom_member(uuid, text) from public, anon;
revoke all on function public.rename_custom_member(uuid, text) from public, anon;
revoke all on function public.set_custom_member_hidden(uuid, boolean) from public, anon;
grant execute on function public.create_custom_member(uuid, text) to authenticated;
grant execute on function public.rename_custom_member(uuid, text) to authenticated;
grant execute on function public.set_custom_member_hidden(uuid, boolean) to authenticated;

create or replace function public.validate_transaction_refs()
returns trigger language plpgsql set search_path = ''
as $$
declare
  member_household_id uuid;
  member_hidden boolean;
  category_household_id uuid;
  category_type text;
begin
  if new.member_id is not null then
    select hm.household_id, hm.is_hidden into member_household_id, member_hidden
    from public.household_members hm where hm.id = new.member_id;
    if member_household_id is null or member_household_id <> new.household_id then
      raise exception using errcode = '23514', message = 'Member must belong to the same household';
    end if;
    if member_hidden then
      if tg_op = 'INSERT' then
        raise exception using errcode = '23514', message = 'Hidden member cannot be selected';
      elsif old.member_id is distinct from new.member_id then
        raise exception using errcode = '23514', message = 'Hidden member cannot be selected';
      end if;
    end if;
  end if;

  select c.household_id, c.type into category_household_id, category_type
  from public.categories c where c.id = new.category_id;
  if category_household_id is null or category_household_id <> new.household_id then
    raise exception using errcode = '23514', message = 'Category must belong to the same household';
  end if;
  if category_type <> new.type then
    raise exception using errcode = '23514', message = 'Category type must match transaction type';
  end if;
  return new;
end;
$$;
-- END MIGRATION: 20261002090000_members_attribution.sql

-- 원본 SQL은 supabase/migrations/에 보관한다. 실행 완료된 버전만 기록한다.
insert into supabase_migrations.schema_migrations (version, name) values
  ('20260928110000', 'initial_schema'),
  ('20260929060000', 'explicit_api_grants'),
  ('20261002090000', 'members_attribution');

notify pgrst, 'reload schema';
commit;

select '초기 스키마 적용 완료. Google 로그인 후 1인 가계부 연결 SQL을 실행해 주세요.' as result;
