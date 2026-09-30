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
