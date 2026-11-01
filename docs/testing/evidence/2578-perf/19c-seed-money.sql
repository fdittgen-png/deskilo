-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2578 performance evidence, split for the ~100 s Management API limit.
-- See README.md in this folder for the run order. File: 19c-seed-money.sql
--
-- COMMITTED. Invoices 10001..14400 of 14,400 = 400 members x 36 months (invoice n:
-- member (n-1) mod 400, data month ((n-1) div 400) mod 36, so no two invoices
-- share (member, month) and invoices_member_period_kind_uniq holds). Each is paid once: a credit ledger row (the
-- payment), its invoice_match and its invoice_match_payment, matched
-- inside the invoice's own month at a spread instant. The collected figure
-- and the payments read sum exactly those rows. Every statement skips rows
-- that already exist, so a rerun after a cut adds nothing twice.
-- WARNING: invoices are immutable (invoices_no_mutation). Once committed
-- they can only be removed by 99-cleanup-90-OWNER-GATE (see README).
-- Expected: 4,400 rows in each of four tables, under 60 s.

-- ---------------------------------------------------------------- prelude
-- The marker workspace, by its marker name only: exactly one, or stop.
create or replace function pg_temp.ws() returns uuid language plpgsql stable as $$
declare v_n int; v_id uuid;
begin
  select count(*), min(id::text)::uuid into v_n, v_id
    from public.workspaces where name ~ '^perf-2578-[0-9]{8}$';
  if v_n <> 1 then
    raise exception 'expected exactly one perf-2578 marker workspace, found %', v_n;
  end if;
  return v_id;
end;
$$;
-- The first month of the data, local date (setup set analytics_history.since to it).
create or replace function pg_temp.m0() returns date language sql stable as $$
  select (a.since at time zone 'Europe/Paris')::date
    from public.analytics_history a where a.workspace_id = pg_temp.ws();
$$;
-- Synthetic account i (0 owner, 1 analyst, 2..401 booking members), by its marker email.
create or replace function pg_temp.uid(i int) returns uuid language sql stable as $$
  select u.id from auth.users u where u.email = 'u' || lpad(i::text, 4, '0') || '@perf-2578.deskilo.test';
$$;

set statement_timeout = '20s';
create temp table if not exists perf_inv (n int primary key, number text not null, member_id uuid not null,
                                          month_start date not null, amount int not null,
                                          matched_at timestamptz not null);
truncate perf_inv;
with mem as (
    select (substring(u.email from '^u([0-9]+)@')::int - 2) as idx, m.id
      from public.members m join auth.users u on u.id = m.user_id
     where m.workspace_id = pg_temp.ws()
       and u.email like 'u%@perf-2578.deskilo.test'
       and substring(u.email from '^u([0-9]+)@')::int >= 2)
insert into perf_inv
select n, 'PERF-' || lpad(n::text, 5, '0'), mem.id, x.ms, 20000 + (n * 137) % 30000,
       (x.ms + make_interval(mins => (n * 7919) % (((x.ms + interval '1 month')::date - x.ms) * 1440)))::timestamp
         at time zone 'Europe/Paris'
-- mapping: injective (member, month); the old month=(n-1)%36 repeated them from n=3601 (lcm(400,36)=3600) -> 23505 on invoices_member_period_kind_uniq
  from generate_series(10001, 14400) n
  cross join lateral (select (pg_temp.m0() + make_interval(months => ((n - 1) / 400) % 36))::date as ms) x
  join mem on mem.idx = (n - 1) % 400;

insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                             total_cents, currency, member_name, workspace_name, issuer_name,
                             signature, period, kind)
select pg_temp.ws(), p.member_id,
       (select id from public.members where workspace_id = pg_temp.ws() and is_owner limit 1),
       p.number, 'Subscription ' || to_char(p.month_start, 'YYYY-MM'),
       jsonb_build_array(jsonb_build_object('label', 'Subscription', 'amount_cents', p.amount)),
       p.amount, 'EUR', 'Perf member', 'perf-2578', 'Perf owner', 's',
       to_char(p.month_start, 'YYYY-MM'), 'full'
  from perf_inv p
on conflict (workspace_id, number) do nothing;

insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents,
                                   description, period, occurred_on)
select pg_temp.ws(), p.member_id, 'credit', 'payment', p.amount, 'PERF payment ' || p.number,
       to_char(p.month_start, 'YYYY-MM'), (p.matched_at at time zone 'Europe/Paris')::date
  from perf_inv p
 where not exists (select 1 from public.ledger_entries le
                    where le.workspace_id = pg_temp.ws() and le.description = 'PERF payment ' || p.number);

insert into public.invoice_matches (workspace_id, invoice_id, paid_cents, resolution, matched_at,
                                    payment_ledger_id)
select i.workspace_id, i.id, p.amount, 'exact', p.matched_at, le.id
  from perf_inv p
  join public.invoices i on i.workspace_id = pg_temp.ws() and i.number = p.number
  join public.ledger_entries le on le.workspace_id = i.workspace_id and le.description = 'PERF payment ' || p.number
on conflict (invoice_id) do nothing;

insert into public.invoice_match_payments (workspace_id, invoice_id, payment_ledger_id, amount_cents,
                                           resolution, matched_at)
select i.workspace_id, i.id, le.id, p.amount, 'exact', p.matched_at
  from perf_inv p
  join public.invoices i on i.workspace_id = pg_temp.ws() and i.number = p.number
  join public.ledger_entries le on le.workspace_id = i.workspace_id and le.description = 'PERF payment ' || p.number
on conflict (payment_ledger_id) do nothing;

-- Counts (totals so far for the marker workspace).
select (select count(*) from public.invoices where workspace_id = pg_temp.ws()) as invoices,
       (select count(*) from public.ledger_entries where workspace_id = pg_temp.ws()) as ledger_entries,
       (select count(*) from public.invoice_matches where workspace_id = pg_temp.ws()) as invoice_matches,
       (select count(*) from public.invoice_match_payments where workspace_id = pg_temp.ws()) as invoice_match_payments,
       (select min(period) || ' .. ' || max(period) from public.invoices where workspace_id = pg_temp.ws()) as periods;
