-- Data API auto-exposure is disabled on the hosted project.
-- Grant table access explicitly; RLS still restricts rows by auth.uid().
revoke all privileges on table
  public.profiles, public.households, public.household_members,
  public.categories, public.transactions, public.monthly_budgets
from anon, authenticated;

grant usage on schema public to authenticated;
grant select, insert, update on table public.profiles to authenticated;
grant select on table public.households, public.household_members to authenticated;
grant select, insert, update on table public.categories to authenticated;
grant select, insert, update, delete on table
  public.transactions, public.monthly_budgets
to authenticated;
