-- SPDX-License-Identifier: 0BSD
--
-- #1229 — the ledger is append-only, and the one exception is narrow.
--
-- `Σ debits = Σ credits` is not expressible against this schema: it is a
-- running member account, one row per movement, with no pairing column
-- and no journal id. ADR 0022 records why, and what invariant replaced
-- it:
--
--   a posted amount never changes, and a row leaves only by the one
--   route that was always meant to remove it.
--
-- The exception is a PROVISIONAL payment credit — one booked while a
-- payment match waits for validation, recognisable because
-- `invoice_matches` or `invoice_match_payments` still points at it. The
-- moment the match is gone, so is the licence to delete it.
begin;
select plan(6);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u uuid := '00000000-0000-4000-8000-0000000000d0';
  ws uuid; m uuid; charge uuid; inv uuid; provisional uuid; settled uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'ledger@deskilo.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Ledger', 'FR', 'EUR', 'Europe/Paris', u) returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u, true, true) returning id into m;

  insert into public.ledger_entries (workspace_id, member_id, kind, category,
                                     amount_cents, description, period)
  values (ws, m, 'charge', 'subscription', 10000, 'September', '2026-09')
  returning id into charge;

  insert into public.invoices (workspace_id, member_id, issuer_member_id, number,
                               title, lines, total_cents, currency, member_name,
                               workspace_name, issuer_name, signature)
  values (ws, m, m, 'L-1', 'September', '[]'::jsonb, 10000, 'EUR', 'Member',
          'Ledger', 'Member', 'sig') returning id into inv;

  -- provisional: a match still points at it
  insert into public.ledger_entries (workspace_id, member_id, kind, category,
                                     amount_cents, description, period)
  values (ws, m, 'credit', 'payment', 10000, 'awaiting validation', '2026-09')
  returning id into provisional;
  insert into public.invoice_matches (workspace_id, invoice_id, paid_cents,
                                      resolution, credit_ledger_id)
  values (ws, inv, 10000, 'exact', provisional);

  -- settled: nothing points at it any more
  insert into public.ledger_entries (workspace_id, member_id, kind, category,
                                     amount_cents, description, period)
  values (ws, m, 'credit', 'payment', 10000, 'settled', '2026-09')
  returning id into settled;

  perform set_config('deskilo.ledger.ws', ws::text, false);
  perform set_config('deskilo.ledger.charge', charge::text, false);
  perform set_config('deskilo.ledger.provisional', provisional::text, false);
  perform set_config('deskilo.ledger.settled', settled::text, false);
  perform set_config('request.jwt.claims',
    json_build_object('sub', u::text, 'role', 'authenticated')::text, false);
end;
$seed$;

select pg_temp.seed();

select throws_ok(
  format($$ update public.ledger_entries set amount_cents = 1 where id = %L $$,
         current_setting('deskilo.ledger.charge')),
  'a ledger entry is never edited: post a new one',
  'a posted amount cannot be edited');

select throws_ok(
  format($$ update public.ledger_entries set description = 'reworded' where id = %L $$,
         current_setting('deskilo.ledger.charge')),
  'a ledger entry is never edited: post a new one',
  'nor the reason it was posted for');

select throws_ok(
  format($$ delete from public.ledger_entries where id = %L $$,
         current_setting('deskilo.ledger.charge')),
  'a ledger entry is never deleted: only a payment credit still awaiting '
  'validation may be released',
  'a subscription charge cannot be deleted');

select throws_ok(
  format($$ delete from public.ledger_entries where id = %L $$,
         current_setting('deskilo.ledger.settled')),
  'a ledger entry is never deleted: only a payment credit still awaiting '
  'validation may be released',
  'nor a payment credit that nothing is waiting on');

select lives_ok(
  format($$ delete from public.ledger_entries where id = %L $$,
         current_setting('deskilo.ledger.provisional')),
  'but a payment credit a match still points at CAN be released');

-- The reset is the one operation allowed to empty the ledger, and it
-- says so. Anything else that tries the same DELETE is refused above.
select lives_ok(
  format($$ select public.reset_workspace(%L) $$,
         current_setting('deskilo.ledger.ws')),
  'reset_workspace still empties the ledger it is there to empty');

select * from finish();
rollback;
