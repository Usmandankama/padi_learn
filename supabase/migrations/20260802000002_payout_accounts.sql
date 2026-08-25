-- Where a teacher's money should go.
--
-- Deliberately NOT columns on `profiles`: that table is readable by every
-- signed-in user (safe today only because of column-level grants), and a bank
-- account number should not depend on those grants staying correct forever.
-- Its own table means the default posture is "nobody but the owner".

create table if not exists public.payout_accounts (
  id uuid primary key default gen_random_uuid(),

  -- One payout destination per teacher.
  user_id uuid not null unique references auth.users(id) on delete cascade,

  bank_code text not null,
  bank_name text not null,

  -- 10-digit NUBAN.
  account_number text not null,

  -- Resolved through Paystack rather than typed. Nigerian transfers are
  -- irreversible, so the name comes from the bank, never from the user.
  account_name text not null,

  -- Set when Paystack confirmed the number resolves to `account_name`.
  verified_at timestamptz,

  -- Paystack transfer recipient code, for when payouts are automated.
  recipient_code text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint payout_accounts_account_number_check
    check (account_number ~ '^[0-9]{10}$')
);

alter table public.payout_accounts enable row level security;

-- A teacher can read and remove their own account.
drop policy if exists "Owners can read their payout account" on public.payout_accounts;
create policy "Owners can read their payout account"
  on public.payout_accounts for select to authenticated
  using (user_id = auth.uid());

drop policy if exists "Owners can remove their payout account" on public.payout_accounts;
create policy "Owners can remove their payout account"
  on public.payout_accounts for delete to authenticated
  using (user_id = auth.uid());

-- Writes happen only through the `save-payout-account` edge function, which
-- resolves the account against Paystack first. That is what makes the stored
-- `account_name` trustworthy: a client cannot type a name that does not match
-- the number, nor forge `verified_at` / `recipient_code`.
--
-- Column-level REVOKE cannot narrow a table-level grant, so the table grants
-- are dropped outright rather than trimmed.
revoke insert, update, truncate on public.payout_accounts from anon, authenticated;
