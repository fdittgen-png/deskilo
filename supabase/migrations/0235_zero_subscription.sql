-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0235 (#1279 S1) — a member may have no subscription, and that can never
-- mean booking for free.
--
-- A spontaneous visitor who buys a carnet has no monthly subscription. The
-- column allowed 1..100, so "no subscription" did not exist.
--
-- ## The trap this closes first
--
-- Widening the range alone would let `subscription_pct = 0` combine with
-- `overage_policy = 'payg'`: `assert_member_quota` returns early for payg,
-- and `member_statement` finds no fee band for 0 %, so its overage rate
-- stays 0 — unlimited bookings at 0 €. So the widening ships WITH a check
-- that forbids that pair, and a trigger that refuses it in a sentence a
-- person can read instead of a constraint name.
--
-- ## Every reader at 0 %, audited against the live bodies
--
--   * assert_member_quota — included = ceil(open_days × 2 × 0 / 100) = 0;
--     a blocked member is refused with the existing message, byte for byte;
--     a package member books against the extensions they bought;
--   * member_statement, default_tariff_of — no band has from_pct < 0, so
--     fee 0 and overage rate 0 (and payg cannot reach here);
--   * invoice_lines_for — writes a subscription line only when fee_cents
--     > 0: a member without a subscription gets NO line, not a zero line;
--   * workspace_status — reports 0;
--   * set_billing_rule(new_member_defaults) keeps 1..100: making "no
--     subscription" a default is #1294's decision, not this one.

alter table public.members drop constraint if exists members_subscription_pct_check;
alter table public.members
  add constraint members_subscription_pct_check
  check (subscription_pct >= 0 and subscription_pct <= 100);

alter table public.members
  add constraint members_no_subscription_payg
  check (not (subscription_pct = 0 and overage_policy = 'payg'));

create or replace function public.members_zero_subscription_guard()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.subscription_pct = 0 and new.overage_policy = 'payg' then
    raise exception 'a member without a subscription cannot pay as they go — choose blocked or a package first'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

revoke execute on function public.members_zero_subscription_guard() from public, anon, authenticated;

drop trigger if exists members_zero_subscription_guard on public.members;
create trigger members_zero_subscription_guard
  before insert or update of subscription_pct, overage_policy on public.members
  for each row execute function public.members_zero_subscription_guard();

select public.set_deskilo_schema_version(235);
