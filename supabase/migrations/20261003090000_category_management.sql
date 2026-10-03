-- Household-owned categories: editable initial suggestions, no category hiding.
-- Existing category IDs and transaction references are preserved by this upgrade.
do $$
begin
  if exists (
    select 1 from public.transactions t
    join public.categories c on c.id = t.category_id
    where t.household_id <> c.household_id or t.type <> c.type
  ) then
    raise exception 'Fix existing transaction/category household or type mismatches before migrating';
  end if;
end;
$$;

alter table public.categories
  add column is_uncategorized boolean not null default false,
  drop column is_default,
  drop column is_hidden;

create unique index categories_uncategorized_household_type_key
  on public.categories (household_id, type) where is_uncategorized;

insert into public.categories (household_id, type, name, is_uncategorized)
select h.id, t.type, '미분류', true
from public.households h cross join (values ('income'), ('expense')) t(type);

-- Every future household gets both destinations, including manual bootstrap.
create function public.create_household_uncategorized_categories()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.categories (household_id, type, name, is_uncategorized)
  values (new.id, 'income', '미분류', true), (new.id, 'expense', '미분류', true);
  return new;
end;
$$;
revoke all on function public.create_household_uncategorized_categories() from public, anon, authenticated;
create trigger households_create_uncategorized_categories
  after insert on public.households
  for each row execute function public.create_household_uncategorized_categories();

create function public.protect_category_identity()
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
    or new.is_uncategorized is distinct from old.is_uncategorized then
    raise exception using errcode = '23514', message = 'Category identity cannot be changed';
  end if;
  if old.is_uncategorized and new.name is distinct from old.name then
    raise exception using errcode = '23514', message = 'Uncategorized category cannot be renamed';
  end if;
  return new;
end;
$$;
create trigger categories_protect_identity
  before update or delete on public.categories
  for each row execute function public.protect_category_identity();

-- Ordinary clients may only create their own categories and rename them.
-- Column grants prevent forging system categories or changing tenant/type/IDs.
revoke insert, update, delete on public.categories from public, anon, authenticated;
grant insert (household_id, type, name) on public.categories to authenticated;
grant update (name) on public.categories to authenticated;
drop policy categories_delete_member on public.categories;

create function public.delete_category(target_category_id uuid)
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
  select id into destination_id from public.categories
  where household_id = source.household_id and type = source.type and is_uncategorized;
  if destination_id is null then
    raise exception using errcode = '23514', message = 'Uncategorized category is missing';
  end if;

  -- The source row lock + FK serialize references with deletion. Concurrent
  -- stale writes either finish before reassignment or fail; no orphan can commit.
  update public.transactions set category_id = destination_id
  where household_id = source.household_id and category_id = source.id;
  delete from public.categories where id = source.id;
end;
$$;
revoke all on function public.delete_category(uuid) from public, anon;
grant execute on function public.delete_category(uuid) to authenticated;

-- Keep SECURITY DEFINER helpers consistent; references are fully qualified.
alter function public.is_household_member(uuid) set search_path = '';
