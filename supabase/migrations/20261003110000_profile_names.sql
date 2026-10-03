-- User-confirmed profile names. Existing Google names stay unconfirmed until the
-- user checks them once; existing member names are not rewritten by this migration.
alter table public.profiles
  add column name_confirmed_at timestamptz,
  add constraint profiles_confirmed_name_check check (
    name_confirmed_at is null or (
      display_name is not null
      and char_length(display_name) between 1 and 30
      and display_name !~ '^[[:space:]]|[[:space:]]$'
    )
  );

-- Profiles are created on first login; names change only through set_profile_name.
revoke insert, update, delete on public.profiles from public, anon, authenticated;
grant insert (id, display_name) on public.profiles to authenticated;

create function public.set_profile_name(profile_name text)
returns public.profiles
language plpgsql security definer set search_path = ''
as $$
declare
  trimmed text := regexp_replace(coalesce(profile_name, ''), '^[[:space:]]+|[[:space:]]+$', '', 'g');
  result public.profiles;
begin
  if auth.uid() is null then
    raise exception using errcode = '42501', message = 'Login required';
  end if;
  if char_length(trimmed) not between 1 and 30 then
    raise exception using errcode = '23514', message = 'Profile name must be 1-30 characters';
  end if;
  insert into public.profiles (id, display_name, name_confirmed_at)
  values (auth.uid(), trimmed, now())
  on conflict (id) do update
    set display_name = excluded.display_name, name_confirmed_at = excluded.name_confirmed_at
  returning * into result;
  -- Only the caller's linked member follows the profile; accountless members are untouched.
  update public.household_members set display_name = trimmed where user_id = auth.uid();
  return result;
end;
$$;
revoke all on function public.set_profile_name(text) from public, anon;
grant execute on function public.set_profile_name(text) to authenticated;

-- A member linked after the user confirmed a name shows that name.
create function public.sync_linked_member_name()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare confirmed_name text;
begin
  if new.user_id is not null then
    select display_name into confirmed_name from public.profiles
    where id = new.user_id and name_confirmed_at is not null;
    if confirmed_name is not null then
      new.display_name := confirmed_name;
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.sync_linked_member_name() from public, anon, authenticated;
create trigger household_members_sync_linked_name
  before insert or update of user_id on public.household_members
  for each row execute function public.sync_linked_member_name();
