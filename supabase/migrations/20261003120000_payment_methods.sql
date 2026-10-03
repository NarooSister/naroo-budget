-- Expense payment methods. Existing records stay unspecified; income has none.
alter table public.transactions
  add column payment_method text,
  add constraint transactions_payment_method_check check (
    payment_method is null
    or (type = 'expense' and payment_method in ('debit_card', 'credit_card', 'cash'))
  );

-- Per-user default for new expenses; it is also shown first in the picker.
alter table public.profiles
  add column default_payment_method text not null default 'debit_card',
  add constraint profiles_default_payment_method_check check (
    default_payment_method in ('debit_card', 'credit_card', 'cash')
  );
grant update (default_payment_method) on public.profiles to authenticated;
