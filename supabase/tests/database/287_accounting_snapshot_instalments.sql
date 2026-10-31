-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2365 / 9999: an accounting export reads its input from ONE response.
-- The fiscal source of 2026 carries the instalments of its invoices (two of
-- A's, not D's from 2025) with their totals, and the match of the 2027
-- settlement S that regroups the 2026 invoice E beside E's own invoice, so
-- the accountant's view is built without a second read. The figures are
-- worked out by hand from the seeded rows, not by the function under test.
begin;
select plan(9);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  uo uuid := '00000000-0000-4000-8000-000000236591';
  up uuid := '00000000-0000-4000-8000-000000236592';
  ws uuid; mo uuid; mp uuid;
  ia uuid; ie uuid; isx uuid; id_ uuid;
  l1 uuid; l2 uuid; l3 uuid;
begin
  insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
   values (uo,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','owner@ins2365.test','',now(),now(),now()),
          (up,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','plain@ins2365.test','',now(),now(),now());
  insert into public.workspaces(name,country_code,currency_code,timezone,created_by)
   values ('Instalments 2365','FR','EUR','Europe/Paris',uo) returning id into ws;
  insert into public.members(workspace_id,user_id,is_owner,is_admin) values (ws,uo,true,true) returning id into mo;
  insert into public.members(workspace_id,user_id) values (ws,up) returning id into mp;

  -- 2026: A and E. Out: S (the 2027 settlement of E), D (2025).
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines, total_cents, currency, member_name, workspace_name, issuer_name, signature, issued_at, kind)
   values (ws, mp, mo, 'S', 'S', '[]'::jsonb, 5000, 'EUR', 'M', 'W', 'O', 's', '2027-01-05 10:00+00', 'settlement') returning id into isx;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines, total_cents, currency, member_name, workspace_name, issuer_name, signature, issued_at)
   values (ws, mp, mo, 'A', 'A', '[]'::jsonb, 12000, 'EUR', 'M', 'W', 'O', 's', '2026-03-10 10:00+00') returning id into ia;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines, total_cents, currency, member_name, workspace_name, issuer_name, signature, issued_at, settled_by_invoice_id)
   values (ws, mp, mo, 'E', 'E', '[]'::jsonb, 5000, 'EUR', 'M', 'W', 'O', 's', '2026-12-20 10:00+00', isx) returning id into ie;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines, total_cents, currency, member_name, workspace_name, issuer_name, signature, issued_at)
   values (ws, mp, mo, 'D', 'D', '[]'::jsonb, 900, 'EUR', 'M', 'W', 'O', 's', '2025-06-10 10:00+00') returning id into id_;

  insert into public.invoice_matches (workspace_id, invoice_id, paid_cents, resolution)
   values (ws, ia, 12000, 'exact'), (ws, isx, 5000, 'exact'), (ws, id_, 900, 'exact');

  -- A paid in two instalments of 7000 and 5000; D once, in 2025.
  insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period, occurred_on, created_at)
   values (ws, mp, 'credit', 'payment', 7000, 'first', '2026-03', '2026-03-12', '2026-03-12 08:00+00') returning id into l1;
  insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period, occurred_on, created_at)
   values (ws, mp, 'credit', 'payment', 5000, 'second', '2026-04', '2026-04-02', '2026-04-02 08:00+00') returning id into l2;
  insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period, occurred_on, created_at)
   values (ws, mp, 'credit', 'payment', 900, 'old', '2025-06', '2025-06-12', '2025-06-12 08:00+00') returning id into l3;
  insert into public.invoice_match_payments (workspace_id, invoice_id, payment_ledger_id, amount_cents, resolution, matched_at)
   values (ws, ia, l1, 7000, 'under_accepted', '2026-03-12 09:00+00'),
          (ws, ia, l2, 5000, 'exact', '2026-04-02 09:00+00'),
          (ws, id_, l3, 900, 'exact', '2025-06-12 09:00+00');

  perform set_config('sn.ws', ws::text, false);
  perform set_config('sn.uo', uo::text, false);
  perform set_config('sn.ia', ia::text, false);
  perform set_config('sn.is', isx::text, false);
end;
$seed$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select pg_temp.seed();
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('sn.uo'), 'role', 'authenticated')::text, true);
set local role authenticated;
select set_config('t.src', public.accounting_source_snapshot_v1(
  current_setting('sn.ws')::uuid, date '2026-01-01', date '2026-12-31')::text, true);

select is(current_setting('t.src')::jsonb ->> 'status', 'ok', 'the source answers');
select is(jsonb_array_length(current_setting('t.src')::jsonb -> 'instalments'), 2,
  'the two instalments of A, not the 2025 one of D');
select is((select string_agg(e ->> 'amount_cents', ',' order by (e ->> 'amount_cents')::int)
             from jsonb_array_elements(current_setting('t.src')::jsonb -> 'instalments') e),
  '5000,7000', 'at their amounts');
select ok((select bool_and(e ->> 'invoice_id' = current_setting('sn.ia')
                           and e ? 'matched_at' and e ? 'id')
             from jsonb_array_elements(current_setting('t.src')::jsonb -> 'instalments') e),
  'each names its invoice, its id and the day it was matched');
select is(current_setting('t.src')::jsonb -> 'totals' -> 'instalments',
  '{"count": 2, "amount_cents": 12000}'::jsonb,
  'the instalment totals are the rows: two, 70.00 + 50.00');
select ok((select bool_or(e ->> 'invoice_id' = current_setting('sn.is'))
             from jsonb_array_elements(current_setting('t.src')::jsonb -> 'matches') e),
  'the match of the 2027 settlement that regroups the 2026 invoice E is delivered');
select is(current_setting('t.src')::jsonb -> 'totals' -> 'matches',
  '{"count": 2, "paid_cents": 17000}'::jsonb,
  'the match totals are the rows: A''s and the settlement''s, not D''s');
select is(jsonb_array_length(current_setting('t.src')::jsonb -> 'invoices'), 2,
  'the invoices are still the period''s alone (A and E), not the settlement');
select ok(current_setting('t.src')::jsonb ? 'purchases' and current_setting('t.src')::jsonb ? 'revisions'
          and current_setting('t.src')::jsonb ? 'book_profiles',
  'every key version 1 had is still there');

reset role;
select * from finish();
rollback;
