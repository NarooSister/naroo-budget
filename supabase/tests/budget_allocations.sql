-- Run as postgres after all migrations. Isolated fixtures; always roll back.
begin;
create temporary table budget_test_ids as
select gen_random_uuid() as u1, gen_random_uuid() as u2, gen_random_uuid() as h1,
       gen_random_uuid() as h2, gen_random_uuid() as food, gen_random_uuid() as bus,
       gen_random_uuid() as grocery, gen_random_uuid() as salary, gen_random_uuid() as other;
grant select on budget_test_ids to authenticated;
insert into auth.users (id) select u1 from budget_test_ids union all select u2 from budget_test_ids;
insert into public.profiles (id, display_name)
select u1, 'A' from budget_test_ids union all select u2, 'B' from budget_test_ids;
insert into public.households (id, name)
select h1, 'Budget test' from budget_test_ids union all select h2, 'Other' from budget_test_ids;
insert into public.household_members (household_id, user_id, display_name)
select h1, u1, 'A' from budget_test_ids union all select h2, u2, 'B' from budget_test_ids;
insert into public.categories (id, household_id, type, name)
select food, h1, 'expense', '식비' from budget_test_ids union all
select bus, h1, 'expense', '교통' from budget_test_ids union all
select salary, h1, 'income', '월급' from budget_test_ids union all
select other, h2, 'expense', '다른 식비' from budget_test_ids;
insert into public.categories (id, household_id, type, name, parent_id)
select grocery, h1, 'expense', '장보기', food from budget_test_ids;

create function pg_temp.expect_rejected(command text, expected_codes text[])
returns void language plpgsql as $$
begin
  execute command;
  raise exception using errcode = 'XX000', message = 'Unexpected success: ' || command;
exception when others then
  if not (sqlstate = any(expected_codes)) then raise; end if;
end;
$$;

set local role authenticated;
select set_config('request.jwt.claim.sub', u1::text, true) from budget_test_ids;
do $$
declare
  i record;
  unc uuid;
  r1 uuid;
  r2 uuid;
  allocations jsonb;
begin
  select * into i from budget_test_ids;
  select id into unc from public.categories
  where household_id = i.h1 and type = 'expense' and is_uncategorized;

  -- Direct writes are closed; only the RPCs change budgets.
  perform pg_temp.expect_rejected(format(
    'insert into public.monthly_budgets (household_id, year, month, amount) values (%L, 2026, 8, 1)', i.h1),
    array['42501']);

  -- First save of an empty month expects no revision.
  r1 := public.save_monthly_budget(i.h1, 2026, 8, 1000,
    jsonb_build_array(jsonb_build_object('category_id', i.food, 'amount', 600)), null);
  perform pg_temp.expect_rejected(format(
    'insert into public.budget_allocations (budget_id, category_id, amount) select id, %L, 1 from public.monthly_budgets where household_id = %L',
    i.bus, i.h1), array['42501']);
  perform pg_temp.expect_rejected(format(
    'update public.monthly_budgets set amount = 1 where household_id = %L', i.h1), array['42501']);
  perform pg_temp.expect_rejected(format(
    'delete from public.monthly_budgets where household_id = %L', i.h1), array['42501']);

  -- A second editor that still thinks the month is empty loses.
  perform pg_temp.expect_rejected(format(
    'select public.save_monthly_budget(%L, 2026, 8, 2000, ''[]''::jsonb, null)', i.h1), array['PT409']);

  -- Allocation total must not exceed the total budget.
  perform pg_temp.expect_rejected(format(
    'select public.save_monthly_budget(%L, 2026, 8, 1000, %L::jsonb, %L)', i.h1,
    jsonb_build_array(jsonb_build_object('category_id', i.food, 'amount', 600),
                      jsonb_build_object('category_id', i.bus, 'amount', 401)), r1),
    array['23514']);
  -- Only expense top-level, non-uncategorized categories of the same household.
  perform pg_temp.expect_rejected(format(
    'select public.save_monthly_budget(%L, 2026, 8, 1000, %L::jsonb, %L)', i.h1,
    jsonb_build_array(jsonb_build_object('category_id', bad, 'amount', 1)), r1),
    array['23514'])
  from unnest(array[i.grocery, unc, i.salary, i.other]) bad;
  perform pg_temp.expect_rejected(format(
    'select public.save_monthly_budget(%L, 2026, 8, 1000, %L::jsonb, %L)', i.h1,
    jsonb_build_array(jsonb_build_object('category_id', i.food, 'amount', -1)), r1),
    array['23514']);
  perform pg_temp.expect_rejected(format(
    'select public.save_monthly_budget(%L, 2026, 8, 1000, %L::jsonb, %L)', i.h1,
    jsonb_build_array(jsonb_build_object('category_id', i.food, 'amount', 1),
                      jsonb_build_object('category_id', i.food, 'amount', 1)), r1),
    array['23505']);
  -- Failed saves keep the stored budget.
  if (select amount from public.monthly_budgets where household_id = i.h1 and year = 2026 and month = 8) <> 1000
    or (select count(*) from public.budget_allocations) <> 1 then
    raise exception 'Rejected saves must not change the budget';
  end if;

  -- Saving replaces the whole allocation set and renews the revision.
  r2 := public.save_monthly_budget(i.h1, 2026, 8, 500,
    jsonb_build_array(jsonb_build_object('category_id', i.bus, 'amount', 0)), r1);
  if r2 = r1 then raise exception 'Revision must change on save'; end if;
  select jsonb_agg(jsonb_build_object('category_id', category_id, 'amount', amount)) into allocations
  from public.budget_allocations a join public.monthly_budgets b on b.id = a.budget_id
  where b.household_id = i.h1 and b.year = 2026 and b.month = 8;
  if allocations <> jsonb_build_array(jsonb_build_object('category_id', i.bus, 'amount', 0)) then
    raise exception 'Allocations must be replaced, got %', allocations;
  end if;
  perform pg_temp.expect_rejected(format(
    'select public.save_monthly_budget(%L, 2026, 8, 700, ''[]''::jsonb, %L)', i.h1, r1), array['PT409']);

  -- Months are independent, including year boundaries and the maximum amount.
  perform public.save_monthly_budget(i.h1, 2026, 12, 2147483647, '[]'::jsonb, null);
  perform public.save_monthly_budget(i.h1, 2027, 1, 0, '[]'::jsonb, null);
  if (select amount from public.monthly_budgets where household_id = i.h1 and year = 2026 and month = 8) <> 500 then
    raise exception 'Other months must not change August';
  end if;

  -- Other households are invisible and not writable.
  perform pg_temp.expect_rejected(format(
    'select public.save_monthly_budget(%L, 2026, 8, 1, ''[]''::jsonb, null)', i.h2), array['42501']);

  -- Reset requires the current revision and returns the month to unset.
  perform pg_temp.expect_rejected(format(
    'select public.reset_monthly_budget(%L, 2026, 8, %L)', i.h1, r1), array['PT409']);
  perform public.reset_monthly_budget(i.h1, 2026, 8, r2);
  if exists (select 1 from public.monthly_budgets where household_id = i.h1 and year = 2026 and month = 8) then
    raise exception 'Reset must delete the month';
  end if;
  perform public.reset_monthly_budget(i.h1, 2026, 8, r2);
  -- After reset and re-create, the old revision is still stale.
  r1 := public.save_monthly_budget(i.h1, 2026, 8, 300, '[]'::jsonb, null);
  perform pg_temp.expect_rejected(format(
    'select public.save_monthly_budget(%L, 2026, 8, 1, ''[]''::jsonb, %L)', i.h1, r2), array['PT409']);

  -- Deleting an allocated category leaves the amount unallocated.
  perform public.save_monthly_budget(i.h1, 2026, 9, 1000,
    jsonb_build_array(jsonb_build_object('category_id', i.food, 'amount', 400)), null);
  perform public.delete_category(i.food);
  if (select amount from public.monthly_budgets where household_id = i.h1 and year = 2026 and month = 9) <> 1000
    or exists (select 1 from public.budget_allocations where category_id = i.food) then
    raise exception 'Category delete must only remove its allocation';
  end if;
end;
$$;

select set_config('request.jwt.claim.sub', u2::text, true) from budget_test_ids;
do $$
declare i record;
begin
  select * into i from budget_test_ids;
  if exists (select 1 from public.monthly_budgets where household_id = i.h1)
    or exists (select 1 from public.budget_allocations) then
    raise exception 'Another household must not read budgets';
  end if;
  perform pg_temp.expect_rejected(format(
    'select public.reset_monthly_budget(%L, 2026, 12, null)', i.h1), array['42501']);
end;
$$;
reset role;
rollback;
select 'PASS: budget allocations, revision checks, reset and category delete.' as result;
