-- Run as postgres after all migrations. Isolated fixtures; always roll back.
begin;
create temporary table subcategory_test_ids as
select gen_random_uuid() as u1, gen_random_uuid() as u2,
       gen_random_uuid() as h1, gen_random_uuid() as h2,
       gen_random_uuid() as food, gen_random_uuid() as groceries,
       gen_random_uuid() as cafe, gen_random_uuid() as salary, gen_random_uuid() as other_food,
       gen_random_uuid() as tx1, gen_random_uuid() as tx2;
grant select on subcategory_test_ids to authenticated;
insert into auth.users (id) select u1 from subcategory_test_ids union all select u2 from subcategory_test_ids;
insert into public.households (id, name)
select h1, 'Subcategory test 1' from subcategory_test_ids union all select h2, 'Subcategory test 2' from subcategory_test_ids;
insert into public.household_members (household_id, user_id, display_name)
select h1, u1, 'A' from subcategory_test_ids union all select h2, u2, 'B' from subcategory_test_ids;
insert into public.categories (id, household_id, type, name)
select food, h1, 'expense', '식비' from subcategory_test_ids union all
select cafe, h1, 'expense', '카페' from subcategory_test_ids union all
select salary, h1, 'income', '월급' from subcategory_test_ids union all
select other_food, h2, 'expense', '식비' from subcategory_test_ids;

create function pg_temp.expect_rejected(command text, expected_codes text[])
returns void language plpgsql as $$
begin
  execute command;
  raise exception using errcode = 'XX000', message = 'Unexpected success: ' || command;
exception when others then
  if not (sqlstate = any(expected_codes)) then raise; end if;
end;
$$;

-- Hierarchy rules apply even to trusted SQL writes.
do $$
declare i record; unc uuid; nested uuid := gen_random_uuid();
begin
  select * into i from subcategory_test_ids;
  select id into unc from public.categories where household_id = i.h1 and type = 'expense' and is_uncategorized;
  insert into public.categories (id, household_id, type, name, parent_id)
  values (i.groceries, i.h1, 'expense', '장보기', i.food);
  perform pg_temp.expect_rejected(format('insert into public.categories (household_id,type,name,parent_id) values (%L,''expense'',''3단계'',%L)', i.h1, i.groceries), array['23514']);
  perform pg_temp.expect_rejected(format('insert into public.categories (id,household_id,type,name,parent_id) values (%L,%L,''expense'',''자기 참조'',%L)', nested, i.h1, nested), array['23514']);
  perform pg_temp.expect_rejected(format('insert into public.categories (household_id,type,name,parent_id) values (%L,''expense'',''미분류 하위'',%L)', i.h1, unc), array['23514']);
  perform pg_temp.expect_rejected(format('insert into public.categories (household_id,type,name,parent_id,is_uncategorized) values (%L,''expense'',''미분류'',%L,true)', i.h1, i.food), array['23514']);
  perform pg_temp.expect_rejected(format('update public.categories set parent_id=%L where id=%L', i.cafe, i.groceries), array['23514']);
  perform pg_temp.expect_rejected(format('update public.categories set parent_id=%L where id=%L', i.food, i.cafe), array['23514']);
end;
$$;

set local role authenticated;
select set_config('request.jwt.claim.sub', u1::text, true) from subcategory_test_ids;
do $$
declare i record; unc uuid; member_id uuid; eating_out uuid; kept public.transactions;
begin
  select * into i from subcategory_test_ids;
  select id into unc from public.categories where household_id = i.h1 and type = 'expense' and is_uncategorized;
  select id into member_id from public.household_members where household_id = i.h1;

  -- Same names are allowed, including a child with its parent's name.
  insert into public.categories (household_id, type, name, parent_id)
  values (i.h1, 'expense', '식비', i.food) returning id into eating_out;
  insert into public.categories (household_id, type, name, parent_id) values (i.h1, 'expense', '장보기', i.cafe);

  perform pg_temp.expect_rejected(format('insert into public.categories (household_id,type,name,parent_id) values (%L,''expense'',''3단계'',%L)', i.h1, i.groceries), array['23514']);
  perform pg_temp.expect_rejected(format('insert into public.categories (household_id,type,name,parent_id) values (%L,''income'',''유형 불일치'',%L)', i.h1, i.food), array['23514']);
  perform pg_temp.expect_rejected(format('insert into public.categories (household_id,type,name,parent_id) values (%L,''expense'',''다른 집'',%L)', i.h1, i.other_food), array['23514']);
  perform pg_temp.expect_rejected(format('insert into public.categories (household_id,type,name,parent_id) values (%L,''expense'',''미분류 하위'',%L)', i.h1, unc), array['23514']);
  perform pg_temp.expect_rejected(format('update public.categories set parent_id=%L where id=%L', i.cafe, i.groceries), array['42501']);

  -- Records keep category_id at the top level; subcategory is optional and must match.
  insert into public.transactions (id, household_id, member_id, type, amount, category_id, subcategory_id)
  values (i.tx1, i.h1, member_id, 'expense', 1000, i.food, i.groceries);
  insert into public.transactions (id, household_id, member_id, type, amount, category_id)
  values (i.tx2, i.h1, member_id, 'expense', 2000, i.food);
  perform pg_temp.expect_rejected(format('insert into public.transactions (household_id,member_id,type,amount,category_id) values (%L,%L,''expense'',1,%L)', i.h1, member_id, i.groceries), array['23514']);
  perform pg_temp.expect_rejected(format('insert into public.transactions (household_id,member_id,type,amount,category_id,subcategory_id) values (%L,%L,''expense'',1,%L,%L)', i.h1, member_id, i.cafe, i.groceries), array['23514']);
  perform pg_temp.expect_rejected(format('update public.transactions set category_id=%L where id=%L', i.cafe, i.tx1), array['23514']);

  -- Users cannot choose uncategorized, but may edit a record already in it.
  perform pg_temp.expect_rejected(format('insert into public.transactions (household_id,member_id,type,amount,category_id) values (%L,%L,''expense'',1,%L)', i.h1, member_id, unc), array['23514']);
  perform pg_temp.expect_rejected(format('update public.transactions set category_id=%L, subcategory_id=null where id=%L', unc, i.tx2), array['23514']);

  -- Deleting a subcategory keeps the record in its parent.
  perform public.delete_category(i.groceries);
  select * into kept from public.transactions where id = i.tx1;
  if kept.category_id <> i.food or kept.subcategory_id is not null or kept.amount <> 1000 then
    raise exception 'Subcategory delete must keep the parent category';
  end if;
  if exists (select 1 from public.categories where id = i.groceries) then raise exception 'Subcategory not deleted'; end if;

  update public.transactions set subcategory_id = eating_out where id = i.tx1;
  -- Deleting a parent deletes its children and moves all its records to uncategorized.
  perform public.delete_category(i.food);
  if exists (select 1 from public.categories where id in (i.food, eating_out)) then
    raise exception 'Parent delete must delete subcategories';
  end if;
  if exists (select 1 from public.transactions where id in (i.tx1, i.tx2)
      and (category_id <> unc or subcategory_id is not null)) then
    raise exception 'Parent delete must move records to uncategorized';
  end if;
  if (select sum(amount) from public.transactions where household_id = i.h1) <> 3000 then
    raise exception 'Totals changed after category deletion';
  end if;
  update public.transactions set amount = 2500, memo = '미분류 유지' where id = i.tx2;
  if not found then raise exception 'Uncategorized record must stay editable'; end if;
end;
$$;

select set_config('request.jwt.claim.sub', u2::text, true) from subcategory_test_ids;
do $$
declare i record;
begin
  select * into i from subcategory_test_ids;
  perform pg_temp.expect_rejected(format('insert into public.categories (household_id,type,name,parent_id) values (%L,''expense'',''침범'',%L)', i.h2, i.cafe), array['23514']);
  perform pg_temp.expect_rejected(format('select public.delete_category(%L)', i.cafe), array['42501']);
end;
$$;
reset role;
rollback;
select 'PASS: subcategory hierarchy, uncategorized selection, delete rules and household isolation.' as result;
