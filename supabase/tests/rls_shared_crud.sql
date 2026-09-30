-- Run as postgres in SQL Editor after both migrations.
-- Fixtures are isolated and rolled back; no real user IDs are required.
begin;
create temporary table naroo_test_ids as
select gen_random_uuid() as a, gen_random_uuid() as b, gen_random_uuid() as c,
       gen_random_uuid() as h1, gen_random_uuid() as h2,
       gen_random_uuid() as m1, gen_random_uuid() as m2, gen_random_uuid() as m3,
       gen_random_uuid() as cat1, gen_random_uuid() as cat2;
grant select on naroo_test_ids to authenticated;
insert into auth.users (id)
select a from naroo_test_ids union all select b from naroo_test_ids union all select c from naroo_test_ids;
insert into public.households (id, name)
select h1, 'Isolated test 1' from naroo_test_ids union all select h2, 'Isolated test 2' from naroo_test_ids;
insert into public.household_members (id, household_id, user_id, display_name)
select m1, h1, a, 'A' from naroo_test_ids union all
select m2, h1, b, 'B' from naroo_test_ids union all
select m3, h2, c, 'C' from naroo_test_ids;
insert into public.categories (id, household_id, type, name)
select cat1, h1, 'expense', 'Test 1' from naroo_test_ids union all
select cat2, h2, 'expense', 'Test 2' from naroo_test_ids;

do $$
declare t text;
begin
  foreach t in array array['profiles','households','household_members','categories','transactions','monthly_budgets'] loop
    if not (select relrowsecurity from pg_class where oid = ('public.' || t)::regclass) then
      raise exception 'RLS disabled: %', t;
    end if;
    if has_table_privilege('anon', 'public.' || t, 'SELECT,INSERT,UPDATE,DELETE') then
      raise exception 'Unexpected anon access: %', t;
    end if;
  end loop;
end $$;

set local role authenticated;
select set_config('request.jwt.claim.sub', a::text, true) from naroo_test_ids;
do $$
declare i record;
begin
  select * into i from naroo_test_ids;
  insert into public.profiles (id, display_name) values (i.a, 'A');
  if (select count(*) from public.household_members) <> 2
     or (select count(*) from public.categories) <> 1
     or (select count(*) from public.households) <> 1 then
    raise exception 'Household read isolation failed';
  end if;
  insert into public.transactions (household_id, member_id, type, amount, category_id, occurred_on)
  values (i.h1, i.m2, 'expense', 12000, i.cat1, date '2026-12-31');
  update public.categories set name = 'Renamed', is_hidden = true where id = i.cat1;
  if not found then raise exception 'Category update failed'; end if;
  begin
    insert into public.transactions (household_id, member_id, type, amount, category_id)
    values (i.h1, i.m1, 'expense', 0, i.cat1);
    raise exception 'Zero amount accepted';
  exception when check_violation then null;
  end;
  begin
    insert into public.categories (household_id, type, name) values (i.h2, 'expense', 'Denied');
    raise exception 'Cross-household category insert allowed';
  exception when insufficient_privilege then null;
  end;
end $$;

select set_config('request.jwt.claim.sub', c::text, true) from naroo_test_ids;
do $$
declare i record;
begin
  select * into i from naroo_test_ids;
  if exists(select 1 from public.transactions where household_id = i.h1) then
    raise exception 'Cross-household read allowed';
  end if;
  update public.transactions set amount = 1 where household_id = i.h1;
  if found then raise exception 'Cross-household update allowed'; end if;
  delete from public.transactions where household_id = i.h1;
  if found then raise exception 'Cross-household delete allowed'; end if;
  begin
    insert into public.transactions (household_id, member_id, type, amount, category_id)
    values (i.h1, i.m3, 'expense', 1, i.cat2);
    raise exception using errcode = 'XX000', message = 'Cross-household insert allowed';
  exception when insufficient_privilege or raise_exception then null;
  end;
end $$;

select set_config('request.jwt.claim.sub', b::text, true) from naroo_test_ids;
do $$
begin
  if exists(select 1 from public.profiles) then raise exception 'Other profile visible'; end if;
  insert into public.profiles (id, display_name) select b, 'B' from naroo_test_ids;
  update public.transactions set amount = 15000;
  if not found then raise exception 'Shared update failed'; end if;
  if (select sum(amount) from public.transactions
      where occurred_on >= date '2026-12-01' and occurred_on < date '2027-01-01') <> 15000 then
    raise exception 'Month query failed';
  end if;
  delete from public.transactions;
  if not found then raise exception 'Shared delete failed'; end if;
end $$;

reset role;
rollback;
select 'PASS: RLS, grants, shared CRUD, categories, amount and month query. Test fixtures rolled back.' as result;
