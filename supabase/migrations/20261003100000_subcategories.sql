-- Optional two-level categories. transactions.category_id always stays top-level.
alter table public.categories
  add column parent_id uuid references public.categories (id) on delete cascade;
alter table public.transactions
  add column subcategory_id uuid references public.categories (id);

create index categories_parent_id_idx on public.categories (parent_id);
create index transactions_subcategory_id_idx on public.transactions (subcategory_id);

create or replace function public.validate_category_parent()
returns trigger language plpgsql set search_path = ''
as $$
declare parent public.categories;
begin
  -- parent_id is immutable after insert, so checking new rows prevents cycles.
  if new.parent_id is null then
    return new;
  end if;
  if new.is_uncategorized then
    raise exception using errcode = '23514', message = 'Uncategorized category cannot be a subcategory';
  end if;
  select * into parent from public.categories where id = new.parent_id;
  if not found or parent.household_id <> new.household_id or parent.type <> new.type then
    raise exception using errcode = '23514', message = 'Parent must share household and type';
  end if;
  if parent.parent_id is not null then
    raise exception using errcode = '23514', message = 'Categories are limited to two levels';
  end if;
  if parent.is_uncategorized then
    raise exception using errcode = '23514', message = 'Uncategorized category cannot have subcategories';
  end if;
  return new;
end;
$$;
create trigger categories_validate_parent
  before insert on public.categories
  for each row execute function public.validate_category_parent();

create or replace function public.protect_category_identity()
returns trigger language plpgsql set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    -- Household deletion can still cascade its entire data set.
    if old.is_uncategorized and exists (
      select 1 from public.households where id = old.household_id
    ) then
      raise exception using errcode = '23514', message = 'Uncategorized category cannot be deleted';
    end if;
    return old;
  end if;
  if new.id is distinct from old.id
    or new.household_id is distinct from old.household_id
    or new.type is distinct from old.type
    or new.parent_id is distinct from old.parent_id
    or new.is_uncategorized is distinct from old.is_uncategorized then
    raise exception using errcode = '23514', message = 'Category identity cannot be changed';
  end if;
  if old.is_uncategorized and new.name is distinct from old.name then
    raise exception using errcode = '23514', message = 'Uncategorized category cannot be renamed';
  end if;
  return new;
end;
$$;

grant insert (parent_id) on public.categories to authenticated;

create or replace function public.validate_transaction_refs()
returns trigger language plpgsql set search_path = ''
as $$
declare
  member_household_id uuid;
  member_hidden boolean;
  category public.categories;
  subcategory_parent_id uuid;
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

  select * into category from public.categories c where c.id = new.category_id;
  if not found or category.household_id <> new.household_id then
    raise exception using errcode = '23514', message = 'Category must belong to the same household';
  end if;
  if category.type <> new.type then
    raise exception using errcode = '23514', message = 'Category type must match transaction type';
  end if;
  if category.parent_id is not null then
    raise exception using errcode = '23514', message = 'Transaction category must be top-level';
  end if;
  -- Only delete_category (SECURITY DEFINER) may move records into uncategorized.
  if category.is_uncategorized and current_user in ('authenticated', 'anon')
    and (tg_op = 'INSERT' or old.category_id is distinct from new.category_id) then
    raise exception using errcode = '23514', message = 'Uncategorized category cannot be selected';
  end if;

  if new.subcategory_id is not null then
    select c.parent_id into subcategory_parent_id
    from public.categories c where c.id = new.subcategory_id;
    if subcategory_parent_id is distinct from new.category_id then
      raise exception using errcode = '23514', message = 'Subcategory must belong to the category';
    end if;
  end if;
  return new;
end;
$$;

-- Deleting a top-level category also deletes its subcategories and moves records
-- to uncategorized. Deleting a subcategory keeps records in its parent.
create or replace function public.delete_category(target_category_id uuid)
returns void language plpgsql security definer set search_path = ''
as $$
declare
  source public.categories;
  destination_id uuid;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'Login required';
  end if;
  select * into source from public.categories
  where id = target_category_id and public.is_household_member(household_id)
  for update;
  if not found then
    raise exception using errcode = '42501', message = 'Category access denied';
  end if;
  if source.is_uncategorized then
    raise exception using errcode = '23514', message = 'Uncategorized category cannot be deleted';
  end if;

  -- The source row lock + FKs serialize references with deletion. Concurrent
  -- stale writes either finish before reassignment or fail; no orphan can commit.
  if source.parent_id is not null then
    update public.transactions set subcategory_id = null
    where household_id = source.household_id and subcategory_id = source.id;
    delete from public.categories where id = source.id;
    return;
  end if;

  select id into destination_id from public.categories
  where household_id = source.household_id and type = source.type and is_uncategorized;
  if destination_id is null then
    raise exception using errcode = '23514', message = 'Uncategorized category is missing';
  end if;
  update public.transactions set category_id = destination_id, subcategory_id = null
  where household_id = source.household_id and category_id = source.id;
  delete from public.categories where parent_id = source.id;
  delete from public.categories where id = source.id;
end;
$$;
