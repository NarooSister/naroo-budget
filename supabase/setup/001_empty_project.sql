-- Naroo: 빈 Supabase 프로젝트용 초기 스키마 (2026-10-03)
-- 새 프로젝트의 SQL Editor에서 postgres 역할로 이 파일 전체를 한 번 실행한다.
-- 20261003130000까지의 migration 8개를 순서대로 포함한다.
-- 기존 프로젝트를 삭제/초기화하지 않는다. Naroo 테이블이 있으면 중단한다.
-- 성공 시 migration 이력도 등록하므로 포함된 migration을 따로 재실행하지 않는다.
-- 원본은 supabase/migrations/이며 이 파일은 새 프로젝트 설치용 스냅샷이다.
--
-- 실행 후:
-- 1. 새 프로젝트의 Google 로그인 설정 및 앱의 Supabase URL/공개 키를 설정한다.
-- 2. 앱에서 Google 로그인 1회 후 Authentication > Users의 사용자 UUID를 확인한다.
-- 3. supabase/bootstrap/001_initial_household_single_user.sql의 user_a_id와
--    ready_to_run을 수정해 실행한다. 가계부 1개와 추천 카테고리 16개와 미분류 2개를 만든다.
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

-- BEGIN MIGRATION: 20261003090000_category_management.sql
-- Household-owned categories: editable initial suggestions, no category hiding.
-- Existing category IDs and transaction references are preserved by this upgrade.
do $$
begin
  if exists (
    select 1 from public.transactions t
    join public.categories c on c.id = t.category_id
    where t.household_id <> c.household_id or t.type <> c.type
  ) then
    raise exception 'Fix existing transaction/category household or type mismatches before migrating';
  end if;
end;
$$;

alter table public.categories
  add column is_uncategorized boolean not null default false,
  drop column is_default,
  drop column is_hidden;

create unique index categories_uncategorized_household_type_key
  on public.categories (household_id, type) where is_uncategorized;

insert into public.categories (household_id, type, name, is_uncategorized)
select h.id, t.type, '미분류', true
from public.households h cross join (values ('income'), ('expense')) t(type);

-- Every future household gets both destinations, including manual bootstrap.
create function public.create_household_uncategorized_categories()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.categories (household_id, type, name, is_uncategorized)
  values (new.id, 'income', '미분류', true), (new.id, 'expense', '미분류', true);
  return new;
end;
$$;
revoke all on function public.create_household_uncategorized_categories() from public, anon, authenticated;
create trigger households_create_uncategorized_categories
  after insert on public.households
  for each row execute function public.create_household_uncategorized_categories();

create function public.protect_category_identity()
returns trigger language plpgsql set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    -- Household deletion can still cascade its entire data set.
    if old.is_uncategorized and exists (
      select 1 from public.households where id = old.household_id
    ) then
      raise exception using errcode = '23514', message = 'Uncategorized category cannot be deleted';
    end if;
    return old;
  end if;
  if new.id is distinct from old.id
    or new.household_id is distinct from old.household_id
    or new.type is distinct from old.type
    or new.is_uncategorized is distinct from old.is_uncategorized then
    raise exception using errcode = '23514', message = 'Category identity cannot be changed';
  end if;
  if old.is_uncategorized and new.name is distinct from old.name then
    raise exception using errcode = '23514', message = 'Uncategorized category cannot be renamed';
  end if;
  return new;
end;
$$;
create trigger categories_protect_identity
  before update or delete on public.categories
  for each row execute function public.protect_category_identity();

-- Ordinary clients may only create their own categories and rename them.
-- Column grants prevent forging system categories or changing tenant/type/IDs.
revoke insert, update, delete on public.categories from public, anon, authenticated;
grant insert (household_id, type, name) on public.categories to authenticated;
grant update (name) on public.categories to authenticated;
drop policy categories_delete_member on public.categories;

create function public.delete_category(target_category_id uuid)
returns void language plpgsql security definer set search_path = ''
as $$
declare
  source public.categories;
  destination_id uuid;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'Login required';
  end if;
  select * into source from public.categories
  where id = target_category_id and public.is_household_member(household_id)
  for update;
  if not found then
    raise exception using errcode = '42501', message = 'Category access denied';
  end if;
  if source.is_uncategorized then
    raise exception using errcode = '23514', message = 'Uncategorized category cannot be deleted';
  end if;
  select id into destination_id from public.categories
  where household_id = source.household_id and type = source.type and is_uncategorized;
  if destination_id is null then
    raise exception using errcode = '23514', message = 'Uncategorized category is missing';
  end if;

  -- The source row lock + FK serialize references with deletion. Concurrent
  -- stale writes either finish before reassignment or fail; no orphan can commit.
  update public.transactions set category_id = destination_id
  where household_id = source.household_id and category_id = source.id;
  delete from public.categories where id = source.id;
end;
$$;
revoke all on function public.delete_category(uuid) from public, anon;
grant execute on function public.delete_category(uuid) to authenticated;

-- Keep SECURITY DEFINER helpers consistent; references are fully qualified.
alter function public.is_household_member(uuid) set search_path = '';
-- END MIGRATION: 20261003090000_category_management.sql

-- BEGIN MIGRATION: 20261003100000_subcategories.sql
-- Optional two-level categories. transactions.category_id always stays top-level.
alter table public.categories
  add column parent_id uuid references public.categories (id) on delete cascade;
alter table public.transactions
  add column subcategory_id uuid references public.categories (id);

create index categories_parent_id_idx on public.categories (parent_id);
create index transactions_subcategory_id_idx on public.transactions (subcategory_id);

create or replace function public.validate_category_parent()
returns trigger language plpgsql set search_path = ''
as $$
declare parent public.categories;
begin
  -- parent_id is immutable after insert, so checking new rows prevents cycles.
  if new.parent_id is null then
    return new;
  end if;
  if new.is_uncategorized then
    raise exception using errcode = '23514', message = 'Uncategorized category cannot be a subcategory';
  end if;
  select * into parent from public.categories where id = new.parent_id;
  if not found or parent.household_id <> new.household_id or parent.type <> new.type then
    raise exception using errcode = '23514', message = 'Parent must share household and type';
  end if;
  if parent.parent_id is not null then
    raise exception using errcode = '23514', message = 'Categories are limited to two levels';
  end if;
  if parent.is_uncategorized then
    raise exception using errcode = '23514', message = 'Uncategorized category cannot have subcategories';
  end if;
  return new;
end;
$$;
create trigger categories_validate_parent
  before insert on public.categories
  for each row execute function public.validate_category_parent();

create or replace function public.protect_category_identity()
returns trigger language plpgsql set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    -- Household deletion can still cascade its entire data set.
    if old.is_uncategorized and exists (
      select 1 from public.households where id = old.household_id
    ) then
      raise exception using errcode = '23514', message = 'Uncategorized category cannot be deleted';
    end if;
    return old;
  end if;
  if new.id is distinct from old.id
    or new.household_id is distinct from old.household_id
    or new.type is distinct from old.type
    or new.parent_id is distinct from old.parent_id
    or new.is_uncategorized is distinct from old.is_uncategorized then
    raise exception using errcode = '23514', message = 'Category identity cannot be changed';
  end if;
  if old.is_uncategorized and new.name is distinct from old.name then
    raise exception using errcode = '23514', message = 'Uncategorized category cannot be renamed';
  end if;
  return new;
end;
$$;

grant insert (parent_id) on public.categories to authenticated;

create or replace function public.validate_transaction_refs()
returns trigger language plpgsql set search_path = ''
as $$
declare
  member_household_id uuid;
  member_hidden boolean;
  category public.categories;
  subcategory_parent_id uuid;
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

  select * into category from public.categories c where c.id = new.category_id;
  if not found or category.household_id <> new.household_id then
    raise exception using errcode = '23514', message = 'Category must belong to the same household';
  end if;
  if category.type <> new.type then
    raise exception using errcode = '23514', message = 'Category type must match transaction type';
  end if;
  if category.parent_id is not null then
    raise exception using errcode = '23514', message = 'Transaction category must be top-level';
  end if;
  -- Only delete_category (SECURITY DEFINER) may move records into uncategorized.
  if category.is_uncategorized and current_user in ('authenticated', 'anon')
    and (tg_op = 'INSERT' or old.category_id is distinct from new.category_id) then
    raise exception using errcode = '23514', message = 'Uncategorized category cannot be selected';
  end if;

  if new.subcategory_id is not null then
    select c.parent_id into subcategory_parent_id
    from public.categories c where c.id = new.subcategory_id;
    if subcategory_parent_id is distinct from new.category_id then
      raise exception using errcode = '23514', message = 'Subcategory must belong to the category';
    end if;
  end if;
  return new;
end;
$$;

-- Deleting a top-level category also deletes its subcategories and moves records
-- to uncategorized. Deleting a subcategory keeps records in its parent.
create or replace function public.delete_category(target_category_id uuid)
returns void language plpgsql security definer set search_path = ''
as $$
declare
  source public.categories;
  destination_id uuid;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'Login required';
  end if;
  select * into source from public.categories
  where id = target_category_id and public.is_household_member(household_id)
  for update;
  if not found then
    raise exception using errcode = '42501', message = 'Category access denied';
  end if;
  if source.is_uncategorized then
    raise exception using errcode = '23514', message = 'Uncategorized category cannot be deleted';
  end if;

  -- The source row lock + FKs serialize references with deletion. Concurrent
  -- stale writes either finish before reassignment or fail; no orphan can commit.
  if source.parent_id is not null then
    update public.transactions set subcategory_id = null
    where household_id = source.household_id and subcategory_id = source.id;
    delete from public.categories where id = source.id;
    return;
  end if;

  select id into destination_id from public.categories
  where household_id = source.household_id and type = source.type and is_uncategorized;
  if destination_id is null then
    raise exception using errcode = '23514', message = 'Uncategorized category is missing';
  end if;
  update public.transactions set category_id = destination_id, subcategory_id = null
  where household_id = source.household_id and category_id = source.id;
  delete from public.categories where parent_id = source.id;
  delete from public.categories where id = source.id;
end;
$$;
-- END MIGRATION: 20261003100000_subcategories.sql

-- BEGIN MIGRATION: 20261003110000_profile_names.sql
-- User-confirmed profile names. Existing Google names stay unconfirmed until the
-- user checks them once; existing member names are not rewritten by this migration.
alter table public.profiles
  add column name_confirmed_at timestamptz,
  add constraint profiles_confirmed_name_check check (
    name_confirmed_at is null or (
      display_name is not null
      and char_length(display_name) between 1 and 30
      and display_name !~ '^[[:space:]]|[[:space:]]$'
    )
  );

-- Profiles are created on first login; names change only through set_profile_name.
revoke insert, update, delete on public.profiles from public, anon, authenticated;
grant insert (id, display_name) on public.profiles to authenticated;

create function public.set_profile_name(profile_name text)
returns public.profiles
language plpgsql security definer set search_path = ''
as $$
declare
  trimmed text := regexp_replace(coalesce(profile_name, ''), '^[[:space:]]+|[[:space:]]+$', '', 'g');
  result public.profiles;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'Login required';
  end if;
  if char_length(trimmed) not between 1 and 30 then
    raise exception using errcode = '23514', message = 'Profile name must be 1-30 characters';
  end if;
  insert into public.profiles (id, display_name, name_confirmed_at)
  values (auth.uid(), trimmed, now())
  on conflict (id) do update
    set display_name = excluded.display_name, name_confirmed_at = excluded.name_confirmed_at
  returning * into result;
  -- Only the caller's linked member follows the profile; accountless members are untouched.
  update public.household_members set display_name = trimmed where user_id = auth.uid();
  return result;
end;
$$;
revoke all on function public.set_profile_name(text) from public, anon;
grant execute on function public.set_profile_name(text) to authenticated;

-- A member linked after the user confirmed a name shows that name.
create function public.sync_linked_member_name()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare confirmed_name text;
begin
  if new.user_id is not null then
    select display_name into confirmed_name from public.profiles
    where id = new.user_id and name_confirmed_at is not null;
    if confirmed_name is not null then
      new.display_name := confirmed_name;
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.sync_linked_member_name() from public, anon, authenticated;
create trigger household_members_sync_linked_name
  before insert or update of user_id on public.household_members
  for each row execute function public.sync_linked_member_name();
-- END MIGRATION: 20261003110000_profile_names.sql

-- BEGIN MIGRATION: 20261003120000_payment_methods.sql
-- Expense payment methods. Existing records stay unspecified; income has none.
alter table public.transactions
  add column payment_method text,
  add constraint transactions_payment_method_check check (
    payment_method is null
    or (type = 'expense' and payment_method in ('debit_card', 'credit_card', 'cash'))
  );

-- Per-user default for new expenses; it is also shown first in the picker.
alter table public.profiles
  add column default_payment_method text not null default 'debit_card',
  add constraint profiles_default_payment_method_check check (
    default_payment_method in ('debit_card', 'credit_card', 'cash')
  );
grant update (default_payment_method) on public.profiles to authenticated;
-- END MIGRATION: 20261003120000_payment_methods.sql

-- BEGIN MIGRATION: 20261003130000_budget_allocations.sql
-- Monthly budgets are independent per month. A budget may allocate part of its
-- total to expense top-level categories; the rest is unallocated.
-- revision changes on every save so a stale editor is detected, even after a
-- reset and re-create of the same month.
alter table public.monthly_budgets
  add column revision uuid not null default gen_random_uuid();

create table public.budget_allocations (
  budget_id uuid not null references public.monthly_budgets (id) on delete cascade,
  -- Deleting a category only removes its allocation, which becomes unallocated.
  category_id uuid not null references public.categories (id) on delete cascade,
  amount integer not null,
  primary key (budget_id, category_id),
  constraint budget_allocations_amount_non_negative check (amount >= 0)
);
create index budget_allocations_category_id_idx on public.budget_allocations (category_id);

create function public.validate_budget_allocation()
returns trigger language plpgsql set search_path = ''
as $$
declare
  budget_household_id uuid;
  category public.categories;
begin
  select household_id into budget_household_id from public.monthly_budgets where id = new.budget_id;
  select * into category from public.categories where id = new.category_id;
  if category.household_id is distinct from budget_household_id
    or category.type <> 'expense'
    or category.parent_id is not null
    or category.is_uncategorized then
    raise exception using errcode = '23514',
      message = 'Allocations must use an expense top-level category of the same household';
  end if;
  return new;
end;
$$;
revoke all on function public.validate_budget_allocation() from public, anon, authenticated;
create trigger budget_allocations_validate
  before insert or update on public.budget_allocations
  for each row execute function public.validate_budget_allocation();

alter table public.budget_allocations enable row level security;
create policy budget_allocations_select_member
  on public.budget_allocations
  for select
  to authenticated
  using (exists (
    select 1 from public.monthly_budgets b
    where b.id = budget_id and public.is_household_member(b.household_id)
  ));

-- Budgets change only through the RPCs below so the total, allocations and the
-- version check stay atomic.
drop policy monthly_budgets_insert_member on public.monthly_budgets;
drop policy monthly_budgets_update_member on public.monthly_budgets;
drop policy monthly_budgets_delete_member on public.monthly_budgets;
revoke insert, update, delete on public.monthly_budgets from public, anon, authenticated;
revoke all on public.budget_allocations from public, anon, authenticated;
grant select on public.budget_allocations to authenticated;

-- expected_revision is the revision the caller loaded (null when the month had
-- no budget). A different current revision means someone else saved first.
create function public.save_monthly_budget(
  target_household_id uuid,
  target_year integer,
  target_month integer,
  total_amount integer,
  allocations jsonb,
  expected_revision uuid
)
returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  budget public.monthly_budgets;
  allocated bigint;
begin
  if auth.uid() is null or not public.is_household_member(target_household_id) then
    raise exception using errcode = '42501', message = 'Household membership required';
  end if;
  if total_amount is null or jsonb_typeof(coalesce(allocations, 'null'::jsonb)) <> 'array' then
    raise exception using errcode = '22023', message = 'Total and allocation array are required';
  end if;

  perform pg_advisory_xact_lock(hashtextextended('monthly_budget:' || target_household_id::text, 0));
  select * into budget from public.monthly_budgets
  where household_id = target_household_id and year = target_year and month = target_month
  for update;
  if budget.revision is distinct from expected_revision then
    raise exception using errcode = 'PT409', message = 'Budget was changed by someone else';
  end if;

  select coalesce(sum((a ->> 'amount')::integer), 0) into allocated
  from jsonb_array_elements(allocations) a;
  if allocated > total_amount then
    raise exception using errcode = '23514', message = 'Allocations exceed the total budget';
  end if;

  insert into public.monthly_budgets (household_id, year, month, amount)
  values (target_household_id, target_year, target_month, total_amount)
  on conflict (household_id, year, month) do update set amount = excluded.amount, revision = gen_random_uuid()
  returning * into budget;

  delete from public.budget_allocations where budget_id = budget.id;
  insert into public.budget_allocations (budget_id, category_id, amount)
  select budget.id, (a ->> 'category_id')::uuid, (a ->> 'amount')::integer
  from jsonb_array_elements(allocations) a;
  return budget.revision;
end;
$$;
revoke all on function public.save_monthly_budget(uuid, integer, integer, integer, jsonb, uuid)
  from public, anon;
grant execute on function public.save_monthly_budget(uuid, integer, integer, integer, jsonb, uuid)
  to authenticated;

-- Returns the month to the unset state. An already unset month succeeds.
create function public.reset_monthly_budget(
  target_household_id uuid,
  target_year integer,
  target_month integer,
  expected_revision uuid
)
returns void
language plpgsql security definer set search_path = ''
as $$
declare budget public.monthly_budgets;
begin
  if auth.uid() is null or not public.is_household_member(target_household_id) then
    raise exception using errcode = '42501', message = 'Household membership required';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('monthly_budget:' || target_household_id::text, 0));
  select * into budget from public.monthly_budgets
  where household_id = target_household_id and year = target_year and month = target_month
  for update;
  if not found then
    return;
  end if;
  if budget.revision is distinct from expected_revision then
    raise exception using errcode = 'PT409', message = 'Budget was changed by someone else';
  end if;
  delete from public.monthly_budgets where id = budget.id;
end;
$$;
revoke all on function public.reset_monthly_budget(uuid, integer, integer, uuid)
  from public, anon;
grant execute on function public.reset_monthly_budget(uuid, integer, integer, uuid)
  to authenticated;
-- END MIGRATION: 20261003130000_budget_allocations.sql

-- 원본 SQL은 supabase/migrations/에 보관한다. 실행 완료된 버전만 기록한다.
insert into supabase_migrations.schema_migrations (version, name) values
  ('20260928110000', 'initial_schema'),
  ('20260929060000', 'explicit_api_grants'),
  ('20261002090000', 'members_attribution'),
  ('20261003090000', 'category_management'),
  ('20261003100000', 'subcategories'),
  ('20261003110000', 'profile_names'),
  ('20261003120000', 'payment_methods'),
  ('20261003130000', 'budget_allocations');

notify pgrst, 'reload schema';
commit;

select '초기 스키마 적용 완료. Google 로그인 후 1인 가계부 연결 SQL을 실행해 주세요.' as result;
