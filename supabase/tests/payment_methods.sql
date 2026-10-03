-- Run as postgres after all migrations. Isolated fixtures; always roll back.
begin;
create temporary table payment_test_ids as
select gen_random_uuid() as u1, gen_random_uuid() as u2, gen_random_uuid() as h1,
       gen_random_uuid() as food, gen_random_uuid() as salary, gen_random_uuid() as tx;
grant select on payment_test_ids to authenticated;
insert into auth.users (id) select u1 from payment_test_ids union all select u2 from payment_test_ids;
insert into public.profiles (id, display_name)
select u1, 'A' from payment_test_ids union all select u2, 'B' from payment_test_ids;
insert into public.households (id, name) select h1, 'Payment test' from payment_test_ids;
insert into public.household_members (household_id, user_id, display_name)
select h1, u1, 'A' from payment_test_ids union all select h1, u2, 'B' from payment_test_ids;
insert into public.categories (id, household_id, type, name)
select food, h1, 'expense', '식비' from payment_test_ids union all
select salary, h1, 'income', '월급' from payment_test_ids;

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
select set_config('request.jwt.claim.sub', u1::text, true) from payment_test_ids;
do $$
declare i record; member_id uuid; saved public.transactions;
begin
  select * into i from payment_test_ids;
  select id into member_id from public.household_members where user_id = i.u1;

  -- Defaults are per user and start with debit card.
  if (select default_payment_method from public.profiles where id = i.u1) <> 'debit_card' then
    raise exception 'Default payment method must start as debit card';
  end if;
  update public.profiles set default_payment_method = 'cash' where id = i.u1;
  if not found then raise exception 'Own default must be writable'; end if;
  update public.profiles set default_payment_method = 'cash' where id = i.u2;
  if found then raise exception 'Other user default must not be writable'; end if;
  perform pg_temp.expect_rejected(format('update public.profiles set default_payment_method=''card'' where id=%L', i.u1), array['23514']);
  perform pg_temp.expect_rejected(format('update public.profiles set default_payment_method=null where id=%L', i.u1), array['23502']);

  -- Expenses may be unspecified or one of three methods; income never has one.
  insert into public.transactions (id, household_id, member_id, type, amount, category_id)
  values (i.tx, i.h1, member_id, 'expense', 1000, i.food) returning * into saved;
  if saved.payment_method is not null then raise exception 'Unspecified must stay null'; end if;
  update public.transactions set payment_method = 'credit_card' where id = i.tx;
  perform pg_temp.expect_rejected(format('update public.transactions set payment_method=''card'' where id=%L', i.tx), array['23514']);
  perform pg_temp.expect_rejected(format('insert into public.transactions (household_id,member_id,type,amount,category_id,payment_method) values (%L,%L,''income'',1,%L,''cash'')', i.h1, member_id, i.salary), array['23514']);
  perform pg_temp.expect_rejected(format('update public.transactions set type=''income'', category_id=%L where id=%L', i.salary, i.tx), array['23514']);
  update public.transactions set type = 'income', category_id = i.salary, payment_method = null where id = i.tx;
  if not found then raise exception 'Income switch with cleared method must succeed'; end if;
end;
$$;
reset role;

do $$
declare i record;
begin
  select * into i from payment_test_ids;
  if (select default_payment_method from public.profiles where id = i.u1) <> 'cash'
    or (select default_payment_method from public.profiles where id = i.u2) <> 'debit_card' then
    raise exception 'Defaults must be stored per user';
  end if;
end;
$$;
rollback;
select 'PASS: payment method values, income exclusion and per-user defaults.' as result;
