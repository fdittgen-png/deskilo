-- SPDX-License-Identifier: AGPL-3.0-or-later
-- utc-date-file: the assertions hold with the business's day one day ahead of and one day behind the database's (workspace_today forced to current_date +/- 1 on the dev project, #4384)
-- #3556 (1b, 0805) — My finances answers each invoice's month and, for an
-- invoice an open online payment names, that payment (the one its member
-- may withdraw): never a declared payment's, never a payment no longer
-- open, never another member's.
begin;
select plan(20);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000035561a1';
  u_a uuid := '00000000-0000-4000-8000-0000035561a2';
  u_b uuid := '00000000-0000-4000-8000-0000035561a3';
  ws uuid; m_o uuid; m_a uuid; m_b uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'overview-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_a, u_b]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Overview', 'FR', 'EUR', 'Europe/Paris', u_o, '{"moneyTab": true, "invoicing": true, "onlinePayments": true}'::jsonb)
  returning id into ws;
  delete from public.validation_policies where workspace_id = ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, status, joined_at)
  values (ws, u_o, true, true, 'active', '2026-01-01'), (ws, u_a, false, false, 'active', '2026-01-01'),
         (ws, u_b, false, false, 'active', '2026-01-01');
  select id into m_o from public.members where workspace_id = ws and user_id = u_o;
  select id into m_a from public.members where workspace_id = ws and user_id = u_a;
  select id into m_b from public.members where workspace_id = ws and user_id = u_b;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name, signature, period, issued_at, kind)
  values (ws, m_a, m_o, 'OV-A1', 'A1', '[]'::jsonb, 4000, 'EUR', 'Ada', 'Overview', 'Owner', 'sig', '2026-10', '2026-11-02', 'full'),
         (ws, m_a, m_o, 'OV-A2', 'A2', '[]'::jsonb, 2500, 'EUR', 'Ada', 'Overview', 'Owner', 'sig', '2026-09', '2026-10-01', 'full'),
         (ws, m_a, m_o, 'OV-A3', 'A3', '[]'::jsonb, 1500, 'EUR', 'Ada', 'Overview', 'Owner', 'sig', '2026-08', '2026-09-01', 'full'),
         (ws, m_a, m_o, 'OV-A4', 'A4', '[]'::jsonb, 1100, 'EUR', 'Ada', 'Overview', 'Owner', 'sig', '2026-07', '2026-08-01', 'full'),
         (ws, m_a, m_o, 'OV-A5', 'A5', '[]'::jsonb, 1200, 'EUR', 'Ada', 'Overview', 'Owner', 'sig', '2026-06', '2026-07-01', 'full'),
         (ws, m_a, m_o, 'OV-A6', 'A6', '[]'::jsonb, 1300, 'EUR', 'Ada', 'Overview', 'Owner', 'sig', '2026-05', '2026-06-01', 'full'),
         (ws, m_b, m_o, 'OV-B1', 'B1', '[]'::jsonb, 3000, 'EUR', 'Ben', 'Overview', 'Owner', 'sig', '2026-10', '2026-10-02', 'full');
  perform set_config('t.ws', ws::text, true);
  perform set_config('t.m_a', m_a::text, true);
  perform set_config('t.m_b', m_b::text, true);
end;
$seed$;
select pg_temp.seed();

create or replace function pg_temp.inv(p_number text) returns uuid language sql as
  $$ select id from public.invoices where number = p_number $$;
select set_config('t.a1', pg_temp.inv('OV-A1')::text, true);
select set_config('t.a2', pg_temp.inv('OV-A2')::text, true);
select set_config('t.a3', pg_temp.inv('OV-A3')::text, true);
select set_config('t.b1', pg_temp.inv('OV-B1')::text, true);
select set_config('t.a4', pg_temp.inv('OV-A4')::text, true);
select set_config('t.a5', pg_temp.inv('OV-A5')::text, true);
select set_config('t.a6', pg_temp.inv('OV-A6')::text, true);
create or replace function pg_temp.act(p_user text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', '00000000-0000-4000-8000-0000035561' || p_user, 'role', 'authenticated')::text, true);
end $$;
-- What the overview answers about one invoice, as Ada.
create or replace function pg_temp.row_of(p_invoice text) returns jsonb language sql as $$
  select x from jsonb_array_elements(public.my_finance_overview() -> 'invoices') x
   where x ->> 'id' = p_invoice
$$;
grant execute on all functions in schema pg_temp to authenticated;

select pg_temp.act('a2');
set local role authenticated;
select is(pg_temp.row_of(current_setting('t.a1')) ->> 'period', '2026-10',
  'an invoice answers its month, not the month it was issued in');
select ok(pg_temp.row_of(current_setting('t.a1')) ? 'claim_payment_id'
          and pg_temp.row_of(current_setting('t.a1')) -> 'claim_payment_id' = 'null'::jsonb,
  'an invoice no payment names answers no payment');
select set_config('t.p1', (select id::text from public.open_payment_intent(current_setting('t.ws')::uuid,
  current_setting('t.m_a')::uuid, 'stripe', '2026-10', 4000, 'EUR', null, array[current_setting('t.a1')::uuid])), true);
select is(pg_temp.row_of(current_setting('t.a1')) ->> 'claim_payment_id', current_setting('t.p1'),
  'an invoice an open online payment names answers that payment');
select is((pg_temp.row_of(current_setting('t.a1')) ->> 'in_payment')::boolean, true,
  'and is in payment');
select lives_ok(format($$select public.record_payment(%L, %L, 2500, '', 'transfer', null, '2026-09', array[%L]::uuid[])$$,
  current_setting('t.ws'), current_setting('t.m_a'), current_setting('t.a2')),
  'a declared payment names A2');
select is(pg_temp.row_of(current_setting('t.a2')) ->> 'in_payment' || ':'
          || coalesce(pg_temp.row_of(current_setting('t.a2')) ->> 'claim_payment_id', 'none'),
  'true:none', 'a declared payment''s invoice is in payment with no payment to withdraw: it waits for the business');
select lives_ok($$select public.withdraw_payment_claim(current_setting('t.p1')::uuid)$$,
  'Ada withdraws the online payment');
select is(coalesce(pg_temp.row_of(current_setting('t.a1')) ->> 'claim_payment_id', 'none'), 'none',
  'once withdrawn, the invoice answers no payment');
reset role;

-- ── another member's payment is never named ─────────────────────────────
select pg_temp.act('a3');
set local role authenticated;
select set_config('t.pb', (select id::text from public.open_payment_intent(current_setting('t.ws')::uuid,
  current_setting('t.m_b')::uuid, 'stripe', '2026-10', 3000, 'EUR', null, array[current_setting('t.b1')::uuid])), true);
reset role;
select pg_temp.act('a2');
set local role authenticated;
select is((select count(*)::int from jsonb_array_elements(public.my_finance_overview() -> 'invoices') x
            where x ->> 'claim_payment_id' = current_setting('t.pb') or x ->> 'id' = current_setting('t.b1')),
  0, 'Ben''s payment of his own invoice is never named in Ada''s finances');

-- ── since when, and whether it may still be confirmed ───────────────────
select set_config('t.p4', (select id::text from public.open_payment_intent(current_setting('t.ws')::uuid,
  current_setting('t.m_a')::uuid, 'stripe', '2026-07', 1100, 'EUR', null, array[current_setting('t.a4')::uuid])), true);
reset role;
update public.payment_intents set handed_at = now() - interval '2 minutes' where id = current_setting('t.p4')::uuid;
select pg_temp.act('a2');
set local role authenticated;
select is((pg_temp.row_of(current_setting('t.a4')) ->> 'claim_handed_at') is not null
          and (pg_temp.row_of(current_setting('t.a4')) ->> 'claim_settling')::boolean,
  true, 'a payment handed two minutes ago answers since when, and that it may still be confirmed');
reset role;
update public.payment_intents set handed_at = now() - public.payment_read_after('stripe') - interval '1 minute'
 where id = current_setting('t.p4')::uuid;
select pg_temp.act('a2');
set local role authenticated;
select is((pg_temp.row_of(current_setting('t.a4')) ->> 'claim_settling')::boolean, false,
  'past the provider''s read age it is no longer said to be settling');

-- ── money that arrived unapplied holds its invoice, whatever the reason ──
-- (a) the claim was withdrawn, then the capture landed
select lives_ok($$select public.withdraw_payment_claim(current_setting('t.p4')::uuid)$$, 'A4''s claim withdrawn');
reset role;
select lives_ok($$select public.settle_online_payment('stripe', (select order_id from public.payment_intents where id = current_setting('t.p4')::uuid), 'cap-p4', 1100)$$,
  'the provider captures it afterwards');
select pg_temp.act('a2');
set local role authenticated;
select is((pg_temp.row_of(current_setting('t.a4')) ->> 'payable') || ':' || (pg_temp.row_of(current_setting('t.a4')) ->> 'payment_received'),
  'false:true', 'withdrawn, then captured: the money waits to be matched and the invoice is not offered again');
-- (b) the claim lapsed (never handed, past the window), then the capture landed
select set_config('t.p5', (select id::text from public.open_payment_intent(current_setting('t.ws')::uuid,
  current_setting('t.m_a')::uuid, 'stripe', '2026-06', 1200, 'EUR', null, array[current_setting('t.a5')::uuid])), true);
reset role;
update public.payment_intents set created_at = now() - public.payment_resend_window('stripe') - interval '1 minute'
 where id = current_setting('t.p5')::uuid;
select lives_ok($$select public.settle_online_payment('stripe', (select order_id from public.payment_intents where id = current_setting('t.p5')::uuid), 'cap-p5', 1200)$$,
  'a lapsed claim''s payment is captured');
select pg_temp.act('a2');
set local role authenticated;
select is((pg_temp.row_of(current_setting('t.a5')) ->> 'payable') || ':' || (pg_temp.row_of(current_setting('t.a5')) ->> 'payment_received'),
  'false:true', 'lapsed, then captured: the invoice is held too');
-- (c) the application failed (the books closed today), then the capture
select set_config('t.p6', (select id::text from public.open_payment_intent(current_setting('t.ws')::uuid,
  current_setting('t.m_a')::uuid, 'stripe', '2026-05', 1300, 'EUR', null, array[current_setting('t.a6')::uuid])), true);
reset role;
insert into public.book_periods (workspace_id, period_from, period_to, reason)
values (current_setting('t.ws')::uuid, current_date - 1, current_date + 1, 'owner');
select lives_ok($$select public.settle_online_payment('stripe', (select order_id from public.payment_intents where id = current_setting('t.p6')::uuid), 'cap-p6', 1300)$$,
  'captured while no match can be booked');
select pg_temp.act('a2');
set local role authenticated;
select is((pg_temp.row_of(current_setting('t.a6')) ->> 'payable') || ':' || (pg_temp.row_of(current_setting('t.a6')) ->> 'payment_received'),
  'false:true', 'an application that failed: the invoice is held');
reset role;
-- free again once that money is matched elsewhere, or reversed
delete from public.book_periods where workspace_id = current_setting('t.ws')::uuid and reason = 'owner';
update public.payment_intents set status = 'reversed', reversed_at = now(), reversal_reason = 'refund'
 where id = current_setting('t.p5')::uuid;
select pg_temp.act('a1');
set local role authenticated;
select lives_ok(format($$select public.match_invoice(%L, (select ledger_entry_id from public.payment_intents where id = %L), 'exact')$$,
  current_setting('t.a6'), current_setting('t.p6')), 'the business matches the waiting money to A6');
reset role;
select pg_temp.act('a2');
set local role authenticated;
select is((pg_temp.row_of(current_setting('t.a5')) ->> 'payment_received')
          || ':' || (pg_temp.row_of(current_setting('t.a6')) ->> 'payment_received'),
  'false:false', 'reversed or matched, the money no longer holds its invoice');
reset role;

select * from finish();
rollback;
