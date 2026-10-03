-- Run as postgres after all migrations. Isolated fixtures; always roll back.
begin;
create temporary table profile_test_ids as
select gen_random_uuid() as u1, gen_random_uuid() as u2, gen_random_uuid() as u3,
       gen_random_uuid() as h1, gen_random_uuid() as h2;
grant select on profile_test_ids to authenticated;
insert into auth.users (id)
select u1 from profile_test_ids union all select u2 from profile_test_ids union all select u3 from profile_test_ids;
insert into public.profiles (id, display_name)
select u1, 'Google 이름' from profile_test_ids union all select u2, 'B' from profile_test_ids;
insert into public.households (id, name)
select h1, 'Profile test 1' from profile_test_ids union all select h2, 'Profile test 2' from profile_test_ids;
insert into public.household_members (household_id, user_id, display_name)
select h1, u1, '기존 A' from profile_test_ids union all
select h1, null, '임의 구성원' from profile_test_ids union all
select h2, u2, '기존 B' from profile_test_ids;

create function pg_temp.expect_rejected(command text, expected_codes text[])
returns void language plpgsql as $$
begin
  execute command;
  raise exception using errcode = 'XX000', message = 'Unexpected success: ' || command;
exception when others then
  if not (sqlstate = any(expected_codes)) then raise; end if;
end;
$$;

-- Existing names stay unconfirmed; a confirmed name must be valid even for trusted SQL.
do $$
declare i record;
begin
  select * into i from profile_test_ids;
  if exists (select 1 from public.profiles where id in (i.u1, i.u2) and name_confirmed_at is not null) then
    raise exception 'Existing profiles must start unconfirmed';
  end if;
  perform pg_temp.expect_rejected(format('update public.profiles set name_confirmed_at=now(), display_name=null where id=%L', i.u2), array['23514']);
  perform pg_temp.expect_rejected(format('update public.profiles set name_confirmed_at=now(), display_name='' B'' where id=%L', i.u2), array['23514']);
  perform pg_temp.expect_rejected(format('update public.profiles set name_confirmed_at=now(), display_name=%L where id=%L', repeat('가', 31), i.u2), array['23514']);
end;
$$;

set local role authenticated;
select set_config('request.jwt.claim.sub', u1::text, true) from profile_test_ids;
do $$
declare i record; saved public.profiles;
begin
  select * into i from profile_test_ids;
  perform pg_temp.expect_rejected('select public.set_profile_name(null)', array['23514']);
  perform pg_temp.expect_rejected('select public.set_profile_name(''   '')', array['23514']);
  perform pg_temp.expect_rejected(format('select public.set_profile_name(%L)', repeat('가', 31)), array['23514']);
  perform pg_temp.expect_rejected(format('update public.profiles set display_name=''우회'' where id=%L', i.u1), array['42501']);
  perform pg_temp.expect_rejected(format('update public.profiles set name_confirmed_at=now() where id=%L', i.u1), array['42501']);
  perform pg_temp.expect_rejected(format('insert into public.profiles (id,display_name,name_confirmed_at) values (%L,''x'',now())', i.u3), array['42501']);

  saved := public.set_profile_name(E'\t ' || repeat('가', 29) || E'나 \n');
  if saved.id <> i.u1 or saved.display_name <> repeat('가', 29) || '나' or saved.name_confirmed_at is null then
    raise exception 'Name must be trimmed, limited by characters and confirmed';
  end if;
  saved := public.set_profile_name('나루');
  if (select display_name from public.household_members where user_id = i.u1) <> '나루' then
    raise exception 'Linked member name must follow the profile';
  end if;
  if not exists (select 1 from public.household_members where household_id = i.h1 and user_id is null and display_name = '임의 구성원') then
    raise exception 'Accountless members must not change';
  end if;
end;
$$;

-- Users without a profile row or household membership can still save a name.
select set_config('request.jwt.claim.sub', u3::text, true) from profile_test_ids;
do $$
declare i record; saved public.profiles;
begin
  select * into i from profile_test_ids;
  saved := public.set_profile_name('새 사용자');
  if saved.id <> i.u3 or saved.name_confirmed_at is null then raise exception 'Profile upsert failed'; end if;
end;
$$;
reset role;

-- Linking after confirmation shows the confirmed name; other users are unaffected.
do $$
declare i record;
begin
  select * into i from profile_test_ids;
  insert into public.household_members (household_id, user_id, display_name) values (i.h1, i.u3, '관리자 입력');
  if (select display_name from public.household_members where user_id = i.u3) <> '새 사용자' then
    raise exception 'Linked member must use the confirmed name';
  end if;
  if (select display_name from public.household_members where user_id = i.u2) <> '기존 B'
    or (select display_name from public.profiles where id = i.u2) <> 'B' then
    raise exception 'Other users must not change';
  end if;
end;
$$;

set local role anon;
select pg_temp.expect_rejected('select public.set_profile_name(''anon'')', array['42501']);
reset role;
rollback;
select 'PASS: profile name confirmation, limits, member sync and write protection.' as result;
