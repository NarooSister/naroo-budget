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
