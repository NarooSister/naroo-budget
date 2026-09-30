-- Phase 4: one-time Household bootstrap
--
-- DO NOT add this file to automatic migrations.
-- Run manually in the Supabase SQL editor (or psql) after both users
-- have signed in at least once with Google.
--
-- Steps:
-- 1. Both users log in once so auth.users + profiles exist.
-- 2. Copy each user's UUID from Authentication → Users (or profiles.id).
-- 3. Replace the two placeholder UUIDs below.
-- 4. Run this script once.

do $$
declare
  -- 1) Replace the two user ids with real auth.users.id values.
  -- 2) Set ready_to_run := true.
  -- 3) Run this script once.
  ready_to_run boolean := false;
  user_a_id uuid := '00000000-0000-0000-0000-0000000000a1';
  user_b_id uuid := '00000000-0000-0000-0000-0000000000b1';

  new_household_id uuid;
  user_a_name text;
  user_b_name text;
begin
  if not ready_to_run then
    raise exception
      'Set ready_to_run := true after replacing user_a_id and user_b_id.';
  end if;

  if user_a_id = user_b_id then
    raise exception 'user_a_id and user_b_id must be different.';
  end if;

  if not exists (select 1 from auth.users where id = user_a_id) then
    raise exception 'user_a_id % does not exist in auth.users', user_a_id;
  end if;

  if not exists (select 1 from auth.users where id = user_b_id) then
    raise exception 'user_b_id % does not exist in auth.users', user_b_id;
  end if;

  if exists (
    select 1
    from public.household_members
    where user_id in (user_a_id, user_b_id)
  ) then
    raise exception
      'One or both users are already linked to a household. Aborting bootstrap.';
  end if;

  select coalesce(nullif(trim(display_name), ''), '사용자 A')
    into user_a_name
  from public.profiles
  where id = user_a_id;

  select coalesce(nullif(trim(display_name), ''), '사용자 B')
    into user_b_name
  from public.profiles
  where id = user_b_id;

  user_a_name := coalesce(user_a_name, '사용자 A');
  user_b_name := coalesce(user_b_name, '사용자 B');

  insert into public.households (name)
  values ('우리 집')
  returning id into new_household_id;

  insert into public.household_members (
    household_id,
    user_id,
    display_name
  )
  values
    (new_household_id, user_a_id, user_a_name),
    (new_household_id, user_b_id, user_b_name);

  insert into public.categories (
    household_id,
    type,
    name,
    is_default,
    is_hidden
  )
  values
    -- expense defaults
    (new_household_id, 'expense', '식비', true, false),
    (new_household_id, 'expense', '카페/간식', true, false),
    (new_household_id, 'expense', '교통', true, false),
    (new_household_id, 'expense', '쇼핑', true, false),
    (new_household_id, 'expense', '생활', true, false),
    (new_household_id, 'expense', '주거', true, false),
    (new_household_id, 'expense', '통신', true, false),
    (new_household_id, 'expense', '의료', true, false),
    (new_household_id, 'expense', '보험', true, false),
    (new_household_id, 'expense', '여가', true, false),
    (new_household_id, 'expense', '기타', true, false),
    -- income defaults
    (new_household_id, 'income', '월급', true, false),
    (new_household_id, 'income', '보너스', true, false),
    (new_household_id, 'income', '용돈', true, false),
    (new_household_id, 'income', '이자', true, false),
    (new_household_id, 'income', '기타', true, false);

  raise notice 'Bootstrap complete. household_id=%', new_household_id;
end;
$$;
