-- Run as postgres after all migrations. Isolated fixtures; always roll back.
begin;
create temporary table category_test_ids as
select gen_random_uuid() as u1, gen_random_uuid() as u2,
       gen_random_uuid() as h1, gen_random_uuid() as h2,
       gen_random_uuid() as c1, gen_random_uuid() as c2,
       gen_random_uuid() as income, gen_random_uuid() as tx;
grant select on category_test_ids to authenticated;
insert into auth.users (id) select u1 from category_test_ids union all select u2 from category_test_ids;
insert into public.households (id, name)
select h1, 'Category test 1' from category_test_ids union all select h2, 'Category test 2' from category_test_ids;
insert into public.household_members (household_id, user_id, display_name)
select h1, u1, 'A' from category_test_ids union all select h2, u2, 'B' from category_test_ids;
insert into public.categories (id, household_id, type, name)
select c1, h1, 'expense', '식비' from category_test_ids union all
select c2, h2, 'expense', '다른 집' from category_test_ids union all
select income, h1, 'income', '월급' from category_test_ids;

create function pg_temp.expect_rejected(command text, expected_codes text[])
returns void language plpgsql as $$
begin
  execute command;
  raise exception using errcode = 'XX000', message = 'Unexpected success: ' || command;
exception when others then
  if not (sqlstate = any(expected_codes)) then raise; end if;
end;
$$;

-- System uniqueness and identity protection apply even to trusted SQL writes.
do $$
declare i record; unc uuid;
begin
  select * into i from category_test_ids;
  if (select count(*) from public.categories where household_id = i.h1 and is_uncategorized) <> 2 then
    raise exception 'Both uncategorized categories must be seeded';
  end if;
  select id into unc from public.categories where household_id = i.h1 and type = 'expense' and is_uncategorized;
  perform pg_temp.expect_rejected(format('insert into public.categories (household_id,type,name,is_uncategorized) values (%L,''expense'',''미분류'',true)', i.h1), array['23505']);
  perform pg_temp.expect_rejected(format('update public.categories set type=''income'' where id=%L', i.c1), array['23514']);
  perform pg_temp.expect_rejected(format('update public.categories set household_id=%L where id=%L', i.h2,i.c1), array['23514']);
  perform pg_temp.expect_rejected(format('update public.categories set name=''변경'' where id=%L', unc), array['23514']);
  perform pg_temp.expect_rejected(format('delete from public.categories where id=%L', unc), array['23514']);
end;
$$;

set local role authenticated;
select set_config('request.jwt.claim.sub', u1::text, true) from category_test_ids;
do $$
declare i record; unc uuid; custom public.household_members; before_row public.transactions; after_row public.transactions;
begin
  select * into i from category_test_ids;
  select id into unc from public.categories where household_id=i.h1 and type='expense' and is_uncategorized;
  perform pg_temp.expect_rejected(format('select public.delete_category(%L)',i.c2),array['42501']);
  perform pg_temp.expect_rejected(format('select public.delete_category(%L)',unc),array['23514']);
  perform pg_temp.expect_rejected(format('delete from public.categories where id=%L',i.c1),array['42501']);
  perform pg_temp.expect_rejected(format('update public.categories set type=''income'' where id=%L',i.c1),array['42501']);
  perform pg_temp.expect_rejected(format('update public.categories set is_uncategorized=true where id=%L',i.c1),array['42501']);
  perform pg_temp.expect_rejected(format('insert into public.categories (household_id,type,name,is_uncategorized) values (%L,''income'',''偽'',true)',i.h1),array['42501']);
  perform pg_temp.expect_rejected(format('insert into public.categories (household_id,type,name) values (%L,''income'',''Denied'')',i.h2),array['42501']);
  update public.categories set name='먹거리' where id=i.c1;
  if not found then raise exception 'Initial category rename failed'; end if;

  custom := public.create_custom_member(i.h1,'임의 구성원');
  insert into public.transactions (id,household_id,member_id,type,amount,category_id,occurred_on,memo)
  values(i.tx,i.h1,custom.id,'expense',12345,i.c1,date '2026-01-31','보존') returning * into before_row;
  perform public.set_custom_member_hidden(custom.id,true);
  perform public.delete_category(i.c1);
  select * into after_row from public.transactions where id=i.tx;
  if not found or (to_jsonb(before_row)-'category_id'-'updated_at') is distinct from
                  (to_jsonb(after_row)-'category_id'-'updated_at') or after_row.category_id <> unc then
    raise exception 'Deletion must preserve transaction fields and hidden member attribution';
  end if;
  if exists(select 1 from public.categories where id=i.c1) then raise exception 'Category not deleted'; end if;
  perform pg_temp.expect_rejected(format('select public.delete_category(%L)',i.c1),array['42501']);
  -- Income destinations must not be mixed with expenses; shared records remain shared.
  insert into public.transactions (household_id,member_id,attribution_kind,type,amount,category_id)
  values(i.h1,null,'shared','income',100,i.income);
  perform public.delete_category(i.income);
  if not exists(select 1 from public.transactions t join public.categories c on c.id=t.category_id
      where t.household_id=i.h1 and t.type='income' and t.attribution_kind='shared'
        and t.member_id is null and c.is_uncategorized and c.type='income') then
    raise exception 'Income/shared reassignment failed';
  end if;

  -- Budgets are written through the save RPC with tenant protection.
  perform public.save_monthly_budget(i.h1,2026,1,0,'[]'::jsonb,null);
  perform public.save_monthly_budget(i.h1,2026,1,2147483647,'[]'::jsonb,
    (select revision from public.monthly_budgets where household_id=i.h1 and year=2026 and month=1));
  perform pg_temp.expect_rejected(format('select public.save_monthly_budget(%L,2026,1,1,''[]''::jsonb,null)',i.h1),array['PT409']);
  perform pg_temp.expect_rejected(format('select public.save_monthly_budget(%L,2026,2,1,''[]''::jsonb,null)',i.h2),array['42501']);
  perform pg_temp.expect_rejected(format('select public.save_monthly_budget(%L,2026,3,-1,''[]''::jsonb,null)',i.h1),array['23514']);
end;
$$;

-- Force a failure after reassignment to prove the whole RPC rolls back.
reset role;
insert into public.categories(id,household_id,type,name) select c1,h1,'expense','Rollback' from category_test_ids;
update public.transactions set category_id=i.c1 from category_test_ids i where public.transactions.id=i.tx;
create function pg_temp.fail_category_delete() returns trigger language plpgsql as $$
begin raise exception using errcode='23514', message='Injected delete failure'; end;
$$;
create trigger category_test_failure before delete on public.categories
  for each row execute function pg_temp.fail_category_delete();
set local role authenticated;
do $$
declare i record;
begin
  select * into i from category_test_ids;
  perform pg_temp.expect_rejected(format('select public.delete_category(%L)',i.c1),array['23514']);
  if not exists(select 1 from public.categories where id=i.c1)
    or (select category_id from public.transactions where id=i.tx) <> i.c1 then
    raise exception 'RPC failure did not roll back all changes';
  end if;
end;
$$;
select set_config('request.jwt.claim.sub', u2::text, true) from category_test_ids;
do $$
declare i record;
begin
  select * into i from category_test_ids;
  if exists(select 1 from public.monthly_budgets where household_id=i.h1) then raise exception 'Other budget visible'; end if;
  perform pg_temp.expect_rejected(format('update public.monthly_budgets set amount=1 where household_id=%L',i.h1),array['42501']);
  perform pg_temp.expect_rejected(format('delete from public.monthly_budgets where household_id=%L',i.h1),array['42501']);
  perform pg_temp.expect_rejected(format('select public.reset_monthly_budget(%L,2026,1,null)',i.h1),array['42501']);
end;
$$;
reset role;
set local role anon;
select pg_temp.expect_rejected('select public.delete_category(null)',array['42501']);
reset role;
rollback;
select 'PASS: category ownership, uncategorized protection, reassignment, rollback and budget isolation.' as result;
