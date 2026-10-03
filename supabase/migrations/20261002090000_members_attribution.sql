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
