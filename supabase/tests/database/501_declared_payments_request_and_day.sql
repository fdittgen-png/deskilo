-- SPDX-License-Identifier: AGPL-3.0-or-later
-- 0861: a declared payment takes its date and month from the business's own day, west and east of
-- UTC; a date after the business's today is refused and its today accepted; the credit note of a
-- match takes the business's month. record_payment takes an optional request id: a repeat of the same
-- content, with or without invoices, is the first declaration; the same id with other content is
-- refused with DKC15; one declaration per id is held by a unique index; without an id nothing changes.
-- withdraw_payment_claim reads the right before it locks; payment_resend_window is never null (a setting without a value is clamped to its minimum).
-- The clock cannot be fixed in a rolled-back test, so each expectation is computed from the clock
-- in the business's own zone; Pacific/Pago_Pago (UTC-11) and Pacific/Kiritimati (UTC+14) are never both
-- on the UTC date. Rolled back.
begin;
select plan(30);

create or replace function pg_temp.run_as(p_user uuid, p_sql text)
returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims',
    jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  set local role authenticated;
  begin
    execute p_sql into v;
  exception when others then
    v := 'ERR ' || sqlstate;
  end;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return v;
end
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000050000a1';
  u_a uuid := '00000000-0000-4000-8000-0000050000a2';
  u_x uuid := '00000000-0000-4000-8000-0000050000a3';
  w uuid; e uuid; m_ow uuid; m_aw uuid; m_oe uuid; m_ae uuid; m_o uuid; m_a uuid; m_x uuid; ws uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'dp-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_a, u_x]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('West', 'US', 'EUR', 'Pacific/Pago_Pago', u_o, '{"moneyTab": true, "invoicing": true}'::jsonb) returning id into w;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('East', 'US', 'EUR', 'Pacific/Kiritimati', u_o, '{"moneyTab": true, "invoicing": true}'::jsonb) returning id into e;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Main', 'FR', 'EUR', 'Europe/Paris', u_o, '{"moneyTab": true, "invoicing": true, "onlinePayments": true}'::jsonb) returning id into ws;
  delete from public.validation_policies where workspace_id in (w, e, ws);
  insert into public.members (workspace_id, user_id, is_owner, is_admin, status, joined_at)
  values (w, u_o, true, true, 'active', '2026-01-01'), (w, u_a, false, false, 'active', '2026-01-01'),
         (e, u_o, true, true, 'active', '2026-01-01'), (e, u_a, false, false, 'active', '2026-01-01'),
         (ws, u_o, true, true, 'active', '2026-01-01'), (ws, u_a, false, false, 'active', '2026-01-01');
  select id into m_ow from public.members where workspace_id = w and user_id = u_o;
  select id into m_aw from public.members where workspace_id = w and user_id = u_a;
  select id into m_oe from public.members where workspace_id = e and user_id = u_o;
  select id into m_ae from public.members where workspace_id = e and user_id = u_a;
  select id into m_o from public.members where workspace_id = ws and user_id = u_o;
  select id into m_a from public.members where workspace_id = ws and user_id = u_a;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name, signature, period, issued_at, kind)
  values (ws, m_a, m_o, 'DP-1', 'One', '[]'::jsonb, 5000, 'EUR', 'Ada', 'Main', 'Owner', 'sig', '2026-10', '2026-10-01', 'full'),
         (ws, m_a, m_o, 'DP-2', 'Two', '[]'::jsonb, 3000, 'EUR', 'Ada', 'Main', 'Owner', 'sig', '2026-10', '2026-10-02', 'subscription'),
         (ws, m_a, m_o, 'DP-3', 'Three', '[]'::jsonb, 2000, 'EUR', 'Ada', 'Main', 'Owner', 'sig', '2026-10', '2026-10-03', 'usage'),
         (ws, m_a, m_o, 'DP-4', 'Four', '[]'::jsonb, 5000, 'EUR', 'Ada', 'Main', 'Owner', 'sig', '2026-08', '2026-08-01', 'full');
  insert into public.payment_intents (id, workspace_id, member_id, provider, order_id, period, amount_cents, currency, reference, claimed_invoice_ids)
  values ('00000000-0000-4000-8000-0000050000b1', ws, m_a, 'stripe', 'pending:b1', '2026-10', 2000, 'EUR', 'DP-REF', array[(select id from public.invoices where number = 'DP-3')]);
  perform set_config('dp.w', w::text, false);
  perform set_config('dp.e', e::text, false);
  perform set_config('dp.ws', ws::text, false);
  perform set_config('dp.m_aw', m_aw::text, false);
  perform set_config('dp.m_ae', m_ae::text, false);
  perform set_config('dp.m_a', m_a::text, false);
  perform set_config('dp.uo', u_o::text, false);
  perform set_config('dp.ua', u_a::text, false);
  perform set_config('dp.ux', u_x::text, false);
  perform set_config('dp.i1', (select id::text from public.invoices where number = 'DP-1'), false);
  perform set_config('dp.i2', (select id::text from public.invoices where number = 'DP-2'), false);
  perform set_config('dp.i4', (select id::text from public.invoices where number = 'DP-4'), false);
end
$seed$;
select pg_temp.seed();

create or replace function pg_temp.today(p_tz text) returns date language sql as
  $$ select (now() at time zone p_tz)::date $$;

-- ── the business's day ──
select set_config('dp.pw', pg_temp.run_as(current_setting('dp.uo')::uuid, format(
  $q$select public.record_payment(%L, %L, 1000, '', '', null, null)::text$q$, current_setting('dp.w'), current_setting('dp.m_aw'))), false);
select is((select (payload ->> 'paid_on')::date from public.events where id = current_setting('dp.pw')::uuid),
  pg_temp.today('Pacific/Pago_Pago'), 'west of UTC: a declaration without a date is the business''s today');
select is((select payload ->> 'period' from public.events where id = current_setting('dp.pw')::uuid),
  to_char(pg_temp.today('Pacific/Pago_Pago'), 'YYYY-MM'), 'and its month is the business''s month');
select set_config('dp.pe', pg_temp.run_as(current_setting('dp.uo')::uuid, format(
  $q$select public.record_payment(%L, %L, 1000, '', '', null, null)::text$q$, current_setting('dp.e'), current_setting('dp.m_ae'))), false);
select is((select (payload ->> 'paid_on')::date from public.events where id = current_setting('dp.pe')::uuid),
  pg_temp.today('Pacific/Kiritimati'), 'east of UTC: the same');
select is((select payload ->> 'period' from public.events where id = current_setting('dp.pe')::uuid),
  to_char(pg_temp.today('Pacific/Kiritimati'), 'YYYY-MM'), 'and its month');
select is(pg_temp.run_as(current_setting('dp.uo')::uuid, format(
  $q$select public.record_payment(%L, %L, 1000, '', '', %L, null)::text$q$, current_setting('dp.w'), current_setting('dp.m_aw'),
  pg_temp.today('Pacific/Pago_Pago'))) like 'ERR%', false, 'west: the business''s today is accepted');
select is(pg_temp.run_as(current_setting('dp.uo')::uuid, format(
  $q$select public.record_payment(%L, %L, 1000, '', '', %L, null)::text$q$, current_setting('dp.w'), current_setting('dp.m_aw'),
  pg_temp.today('Pacific/Pago_Pago') + 1)), 'ERR P0001', 'west: a date after it is refused');
select is(pg_temp.run_as(current_setting('dp.uo')::uuid, format(
  $q$select public.record_payment(%L, %L, 1000, '', '', %L, null)::text$q$, current_setting('dp.e'), current_setting('dp.m_ae'),
  pg_temp.today('Pacific/Kiritimati'))) like 'ERR%', false, 'east: the business''s today is accepted');
select is(pg_temp.run_as(current_setting('dp.uo')::uuid, format(
  $q$select public.record_payment(%L, %L, 1000, '', '', %L, null)::text$q$, current_setting('dp.e'), current_setting('dp.m_ae'),
  pg_temp.today('Pacific/Kiritimati') + 1)), 'ERR P0001', 'east: a date after it is refused, with no day of slack');

-- ── the credit note of a match ──
insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period)
values (current_setting('dp.ws')::uuid, current_setting('dp.m_a')::uuid, 'credit', 'payment', 6000, 'P-over', '2026-09');
select public.match_invoice_part((select m from public.members m where m.id = (select id from public.members where workspace_id = current_setting('dp.ws')::uuid and user_id = current_setting('dp.uo')::uuid)),
  current_setting('dp.i4')::uuid, (select id from public.ledger_entries where description = 'P-over'), 'over_credit_note', 'x');
select is((select period from public.ledger_entries where description like 'Credit note DP-4%'),
  to_char(pg_temp.today('Europe/Paris'), 'YYYY-MM'), 'the credit note of a match takes the business''s month');

-- ── a request id ──
select set_config('dp.r1', gen_random_uuid()::text, false);
select set_config('dp.d1', pg_temp.run_as(current_setting('dp.ua')::uuid, format(
  $q$select public.record_payment(%L, %L, 7700, 'cash', 'cash', null, null, null, %L)::text$q$, current_setting('dp.ws'), current_setting('dp.m_a'), current_setting('dp.r1'))), false);
select is(pg_temp.run_as(current_setting('dp.ua')::uuid, format(
  $q$select public.record_payment(%L, %L, 7700, 'cash', 'cash', null, null, null, %L)::text$q$, current_setting('dp.ws'), current_setting('dp.m_a'), current_setting('dp.r1'))),
  current_setting('dp.d1'), 'without invoices a repeat after a lost answer is the first declaration');
select is((select count(*)::int from public.events where type = 'payment' and payload ->> 'request_id' = current_setting('dp.r1')), 1, 'one event');
select is(pg_temp.run_as(current_setting('dp.ua')::uuid, format(
  $q$select public.record_payment(%L, %L, 7800, 'cash', 'cash', null, null, null, %L)::text$q$, current_setting('dp.ws'), current_setting('dp.m_a'), current_setting('dp.r1'))),
  'ERR DKC15', 'the same id with another amount is refused with its own code');
select is(pg_temp.run_as(current_setting('dp.ua')::uuid, format(
  $q$select public.record_payment(%L, %L, 7700, 'other note', 'cash', null, null, null, %L)::text$q$, current_setting('dp.ws'), current_setting('dp.m_a'), current_setting('dp.r1'))),
  'ERR DKC15', 'and with another note');
select is((select count(*)::int from public.events where type = 'payment' and payload ->> 'request_id' = current_setting('dp.r1')), 1, 'still one event');

-- the digest of a request tells apart what a joined string cannot
select set_config('dp.r3', gen_random_uuid()::text, false);
select pg_temp.run_as(current_setting('dp.ua')::uuid, format(
  $q$select public.record_payment(%L, %L, 910, 'a|b', 'c', null, null, null, %L)::text$q$, current_setting('dp.ws'), current_setting('dp.m_a'), current_setting('dp.r3')));
select is(pg_temp.run_as(current_setting('dp.ua')::uuid, format(
  $q$select public.record_payment(%L, %L, 910, 'a', 'b|c', null, null, null, %L)::text$q$, current_setting('dp.ws'), current_setting('dp.m_a'), current_setting('dp.r3'))),
  'ERR DKC15', 'a note holding the separator is not the note and method it resembles');
select set_config('dp.r4', gen_random_uuid()::text, false);
select pg_temp.run_as(current_setting('dp.ua')::uuid, format(
  $q$select public.record_payment(%L, %L, 920, 'cash', null, null, null, null, %L)::text$q$, current_setting('dp.ws'), current_setting('dp.m_a'), current_setting('dp.r4')));
select is(pg_temp.run_as(current_setting('dp.ua')::uuid, format(
  $q$select public.record_payment(%L, %L, 920, null, 'cash', null, null, null, %L)::text$q$, current_setting('dp.ws'), current_setting('dp.m_a'), current_setting('dp.r4'))),
  'ERR DKC15', 'a NULL note and a NULL method are not each other');

select set_config('dp.r2', gen_random_uuid()::text, false);
select set_config('dp.d2', pg_temp.run_as(current_setting('dp.ua')::uuid, format(
  $q$select public.record_payment(%L, %L, 8000, '', '', null, null, array[%L, %L]::uuid[], %L)::text$q$, current_setting('dp.ws'), current_setting('dp.m_a'),
  current_setting('dp.i1'), current_setting('dp.i2'), current_setting('dp.r2'))), false);
select is(pg_temp.run_as(current_setting('dp.ua')::uuid, format(
  $q$select public.record_payment(%L, %L, 8000, '', '', null, null, array[%L, %L]::uuid[], %L)::text$q$, current_setting('dp.ws'), current_setting('dp.m_a'),
  current_setting('dp.i1'), current_setting('dp.i2'), current_setting('dp.r2'))),
  current_setting('dp.d2'), 'with invoices a repeat is the first declaration, not a refusal of its own invoices');
select is(pg_temp.run_as(current_setting('dp.ua')::uuid, format(
  $q$select public.record_payment(%L, %L, 8000, '', '', null, null, array[%L]::uuid[], %L)::text$q$, current_setting('dp.ws'), current_setting('dp.m_a'),
  current_setting('dp.i1'), current_setting('dp.r2'))), 'ERR DKC15', 'the same id naming other invoices is refused with its own code');
select is((select count(*)::int from public.events where type = 'payment' and payload ->> 'request_id' = current_setting('dp.r2')), 1, 'one event for the invoices');
select is(pg_temp.run_as(current_setting('dp.ua')::uuid, format(
  $q$select public.record_payment(%L, %L, 8000, '', '', null, null, array[%L, %L]::uuid[])::text$q$, current_setting('dp.ws'), current_setting('dp.m_a'),
  current_setting('dp.i1'), current_setting('dp.i2'))), 'ERR DKC06', 'without an id the invoices of a declaration are still held (as before)');
select is(pg_temp.run_as(current_setting('dp.ux')::uuid, format(
  $q$select public.record_payment(%L, %L, 7700, 'cash', 'cash', null, null, null, %L)::text$q$, current_setting('dp.ws'), current_setting('dp.m_a'), current_setting('dp.r1'))),
  'ERR P0001', 'a stranger with the same id reads nothing of it');
select throws_ok(format($q$insert into public.events (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
  select workspace_id, type, action, actor_member_id, subject_member_id, payload, status from public.events where id = %L$q$, current_setting('dp.d1')),
  '23505', null, 'the index holds one declaration per request id, whatever the callers');
select pg_temp.run_as(current_setting('dp.ua')::uuid, format(
  $q$select public.record_payment(%L, %L, 1500, '', '', null, null)::text$q$, current_setting('dp.ws'), current_setting('dp.m_a')));
select is(pg_temp.run_as(current_setting('dp.ua')::uuid, format(
  $q$select (count(*))::text from public.events where type = 'payment' and payload ->> 'amount_cents' = '1500'$q$)), '1', 'without an id each call is its own declaration');

-- ── withdraw_payment_claim: the right before the lock ──
select is((select position('for update' in lower(prosrc)) > position('dkc08' in lower(prosrc)) from pg_proc where proname = 'withdraw_payment_claim'), true,
  'the right is read before the intent row is locked');
select is(pg_temp.run_as(current_setting('dp.ux')::uuid, $q$select public.withdraw_payment_claim('00000000-0000-4000-8000-0000050000b1')::text$q$), 'ERR DKC08',
  'a stranger is refused');
select is(pg_temp.run_as(current_setting('dp.ua')::uuid, $q$select public.withdraw_payment_claim('00000000-0000-4000-8000-0000050000b1')::text$q$), '',
  'the payer withdraws their own');

-- ── payment_resend_window ──
select is(public.payment_resend_window('mollie'), interval '50 minutes', 'a provider''s window is its setting');
select is(public.payment_resend_window('nobody'), interval '0', 'a provider without a window has none');
alter table public.setting_definitions drop constraint setting_definitions_default_valid;
update public.setting_definitions set default_value = 'null'::jsonb where key = 'payments.resend_window_stripe_minutes';
delete from public.setting_values where key = 'payments.resend_window_stripe_minutes';
select is(public.payment_resend_window('stripe'), interval '1 minute',
  'a setting with no value is clamped to its minimum bound by setting_value: the window is never null');
delete from public.setting_definitions where key = 'payments.resend_window_paypal_minutes';
select throws_ok($q$select public.payment_resend_window('paypal')$q$, 'P0001', null, 'a setting that does not exist refuses');

select * from finish();
rollback;
