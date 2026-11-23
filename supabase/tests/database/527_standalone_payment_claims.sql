-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4165 B1: a standalone selection is paid through its own adapters under the explicit allocation mode. Online: the
-- intent names the subject's standalone invoices at what they still owe, replays under its request id, refuses a mixed,
-- foreign, other-currency or wrongly summed selection, and its capture posts an explicit credit dated by the capture in
-- the business's calendar and settles the claim. Declared: the declaration replays under its request id, its approval
-- posts an explicit credit in the month of paid_on and applies its claim; a receipt naming no invoice stays an explicit
-- unapplied credit. The monthly path refuses a standalone invoice by its code. Rolled back.
begin;
select plan(34);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000041650a1';
  u_a uuid := '00000000-0000-4000-8000-0000041650a2';
  u_b uuid := '00000000-0000-4000-8000-0000041650a3';
  ws uuid; m_o uuid; m_a uuid; m_b uuid;
  d date;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'standalone-pay-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_a, u_b]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Standalone pay', 'FR', 'EUR', 'Europe/Paris', u_o,
          '{"moneyTab": true, "invoicing": true, "onlinePayments": true, "standaloneInvoicing": true}'::jsonb)
  returning id into ws;
  delete from public.validation_policies where workspace_id = ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, status, joined_at)
  values (ws, u_o, true, true, 'active', '2026-01-01'), (ws, u_a, false, false, 'active', '2026-01-01'),
         (ws, u_b, false, false, 'active', '2026-01-01');
  select id into m_o from public.members where workspace_id = ws and user_id = u_o;
  select id into m_a from public.members where workspace_id = ws and user_id = u_a;
  select id into m_b from public.members where workspace_id = ws and user_id = u_b;
  d := public.workspace_today(ws);
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines, total_cents, currency,
                               member_name, workspace_name, issuer_name, signature, period, issued_at, kind,
                               source, service_date, due_on)
  values (ws, m_a, m_o, 'SP-S1', 'S1', '[]'::jsonb, 3000, 'EUR', 'Ada', 'Standalone pay', 'Owner', 'sig', null, d - 70, 'full', 'standalone', d - 70, d + 10),
         (ws, m_a, m_o, 'SP-S2', 'S2', '[]'::jsonb, 2000, 'EUR', 'Ada', 'Standalone pay', 'Owner', 'sig', null, d - 5, 'full', 'standalone', d - 5, d + 10),
         (ws, m_a, m_o, 'SP-S3', 'S3', '[]'::jsonb, 1000, 'EUR', 'Ada', 'Standalone pay', 'Owner', 'sig', null, d - 5, 'full', 'standalone', d - 5, d + 10),
         (ws, m_a, m_o, 'SP-S4', 'S4', '[]'::jsonb, 1100, 'EUR', 'Ada', 'Standalone pay', 'Owner', 'sig', null, d - 5, 'full', 'standalone', d - 5, d + 10),
         (ws, m_a, m_o, 'SP-S5', 'S5', '[]'::jsonb, 600, 'EUR', 'Ada', 'Standalone pay', 'Owner', 'sig', null, d - 5, 'full', 'standalone', d - 5, d + 10),
         (ws, m_a, m_o, 'SP-SC', 'SC', '[]'::jsonb, 900, 'CHF', 'Ada', 'Standalone pay', 'Owner', 'sig', null, d - 5, 'full', 'standalone', d - 5, d + 10),
         (ws, m_b, m_o, 'SP-SB', 'SB', '[]'::jsonb, 4000, 'EUR', 'Ben', 'Standalone pay', 'Owner', 'sig', null, d - 5, 'full', 'standalone', d - 5, d + 10),
         (ws, m_a, m_o, 'SP-M1', 'M1', '[]'::jsonb, 1200, 'EUR', 'Ada', 'Standalone pay', 'Owner', 'sig', '2026-10', '2026-10-01', 'full', 'monthly', null, null);
  perform set_config('t.ws', ws::text, true);
  perform set_config('t.m_a', m_a::text, true);
  perform set_config('t.m_b', m_b::text, true);
  perform set_config('t.today', d::text, true);
  perform set_config('t.sb', (select id::text from public.invoices where number = 'SP-SB'), true);
end;
$seed$;
select pg_temp.seed();

create or replace function pg_temp.inv(p_number text) returns uuid language sql as
  $$ select id from public.invoices where number = p_number $$;
create or replace function pg_temp.act(p_user text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', '00000000-0000-4000-8000-0000041650' || p_user, 'role', 'authenticated')::text, true);
end $$;
create or replace function pg_temp.open_sp(p_ids uuid[], p_amount int, p_request uuid, p_subject text default 't.m_a')
returns boolean language sql as $$
  select reused from public.open_standalone_payment_intent_v1(current_setting('t.ws')::uuid,
    current_setting(p_subject)::uuid, 'stripe', p_amount, 'EUR', p_request, p_ids)
$$;
create or replace function pg_temp.declare_sp(p_ids uuid[], p_amount int, p_paid_on date, p_request uuid, p_subject text default 't.m_a')
returns uuid language sql as $$
  select public.record_standalone_payment_v1(current_setting('t.ws')::uuid, current_setting(p_subject)::uuid,
    p_amount, 'transfer', 'bank_transfer', p_paid_on, p_ids, p_request)
$$;
create or replace function pg_temp.refusal(p_sql text) returns text language plpgsql as $$
begin execute p_sql; return null; exception when others then return sqlerrm; end $$;
create or replace function pg_temp.refusal_code(p_sql text) returns text language plpgsql as $$
begin execute p_sql; return null; exception when others then return sqlstate; end $$;
grant execute on all functions in schema pg_temp to authenticated;

-- ── Online, as Ada ───────────────────────────────────────────────────────
select pg_temp.act('a2');
set local role authenticated;
select is(pg_temp.open_sp(array[pg_temp.inv('SP-S2'), pg_temp.inv('SP-S1')], 5000, '00000000-0000-4000-8000-00000416f001'),
  false, 'two standalone invoices of different issue months are one payment, at what they still owe');
select is(pg_temp.open_sp(array[pg_temp.inv('SP-S1'), pg_temp.inv('SP-S2')], 5000, '00000000-0000-4000-8000-00000416f001'),
  true, 'the same request again answers the payment it opened');
select is(pg_temp.refusal($$select pg_temp.open_sp(array[pg_temp.inv('SP-S1'), pg_temp.inv('SP-S2')], 4000, '00000000-0000-4000-8000-00000416f001')$$),
  'payment request conflict: this request id was opened with another payment', 'the same request id with another amount is a conflict');
select is(pg_temp.refusal($$select pg_temp.open_sp(array[pg_temp.inv('SP-S3'), pg_temp.inv('SP-M1')], 2200, '00000000-0000-4000-8000-00000416f002')$$),
  'monthly and standalone invoices are paid separately: pay SP-M1 with its month', 'a mixed selection is refused, naming the monthly invoice');
select is(pg_temp.refusal_code($$select pg_temp.open_sp(array[pg_temp.inv('SP-S3'), pg_temp.inv('SP-M1')], 2200, '00000000-0000-4000-8000-00000416f002')$$),
  'DKC16', 'with its code');
select is(pg_temp.refusal_code(format($$select public.open_payment_intent(%L, %L, 'stripe', '2026-10', 2200, 'EUR', null, array[%L, %L]::uuid[])$$,
    current_setting('t.ws'), current_setting('t.m_a'), pg_temp.inv('SP-S3'), pg_temp.inv('SP-M1'))),
  'DKC14', 'the monthly path refuses the same mixed selection by its own code');
select is(pg_temp.refusal_code($$select pg_temp.open_sp(array[current_setting('t.sb')::uuid], 4000, '00000000-0000-4000-8000-00000416f003')$$),
  'DKC02', 'another member''s standalone invoice is not Ada''s to pay');
select is(pg_temp.refusal($$select pg_temp.open_sp(array[pg_temp.inv('SP-S3')], 1000, '00000000-0000-4000-8000-00000416f004', 't.m_b')$$),
  'a payment is opened for yourself, or by whoever issues the invoices', 'Ada cannot open a payment for Ben');
select is(pg_temp.refusal_code($$select pg_temp.open_sp(array[pg_temp.inv('SP-SC')], 900, '00000000-0000-4000-8000-00000416f005')$$),
  'DKC11', 'an invoice in another currency is refused');
select is(pg_temp.refusal_code($$select pg_temp.open_sp(array[pg_temp.inv('SP-S3')], 900, '00000000-0000-4000-8000-00000416f006')$$),
  'DKC07', 'another amount than what is still owed is refused');
select is(pg_temp.refusal($$select pg_temp.open_sp(array[pg_temp.inv('SP-S3')], 1000, null)$$),
  'a standalone payment names its request id', 'a standalone payment needs a request id');
select is(pg_temp.refusal_code($$select pg_temp.open_sp(array[pg_temp.inv('SP-S1')], 3000, '00000000-0000-4000-8000-00000416f007')$$),
  'DKC06', 'an invoice already in an open payment is not claimed twice');
reset role;
select is((select allocation_mode || ':' || period from public.payment_intents where request_id = '00000000-0000-4000-8000-00000416f001'),
  'explicit:' || to_char(current_setting('t.today')::date, 'YYYY-MM'),
  'the intent is explicit; its period is the month it was opened in');

-- ── The capture ──────────────────────────────────────────────────────────
select lives_ok($$select public.settle_online_payment('stripe', (select order_id from public.payment_intents where request_id = '00000000-0000-4000-8000-00000416f001'), 'cap-sp-1', 5000)$$,
  'the provider captures the payment');
select is((select l.allocation_mode || ':' || l.period || ':' || l.occurred_on from public.ledger_entries l
             join public.payment_intents pi on pi.ledger_entry_id = l.id
            where pi.request_id = '00000000-0000-4000-8000-00000416f001'),
  'explicit:' || to_char(current_setting('t.today')::date, 'YYYY-MM') || ':' || current_setting('t.today')::date,
  'its credit is explicit and posted on the capture day, in the business''s calendar');
select is((select public.invoice_still_due_cents(pg_temp.inv('SP-S1')) + public.invoice_still_due_cents(pg_temp.inv('SP-S2'))),
  0::bigint, 'the capture settles both claimed invoices');
select is((select period from public.invoices where number = 'SP-S1'), null, 'a standalone invoice keeps no month');

-- ── Declared, as Ada; approved by the owner ──────────────────────────────
select pg_temp.act('a2');
set local role authenticated;
select isnt(pg_temp.declare_sp(array[pg_temp.inv('SP-S3')], 1000, current_setting('t.today')::date - 40, '00000000-0000-4000-8000-00000416f101'),
  null, 'Ada declares a transfer for a standalone invoice, paid 40 days ago');
select is(pg_temp.declare_sp(array[pg_temp.inv('SP-S3')], 1000, current_setting('t.today')::date - 40, '00000000-0000-4000-8000-00000416f101'),
  (select id from public.events where payload ->> 'request_id' = '00000000-0000-4000-8000-00000416f101'),
  'the same declaration again answers the first');
select is(pg_temp.refusal_code($$select pg_temp.declare_sp(array[pg_temp.inv('SP-S3')], 900, current_setting('t.today')::date - 40, '00000000-0000-4000-8000-00000416f101')$$),
  'DKC15', 'the same request id with another amount is refused');
select is(pg_temp.refusal_code($$select pg_temp.declare_sp(array[pg_temp.inv('SP-S3'), pg_temp.inv('SP-M1')], 2200, null, '00000000-0000-4000-8000-00000416f102')$$),
  'DKC16', 'a mixed declaration is refused');
select is(pg_temp.refusal($$select pg_temp.declare_sp(null, 500, null, '00000000-0000-4000-8000-00000416f103', 't.m_b')$$),
  'only admins record payments for others', 'Ada cannot declare a payment for Ben');
select pg_temp.act('a1');
select lives_ok(format('select public.respond_to_event(%L, true)',
  (select id from public.events where payload ->> 'request_id' = '00000000-0000-4000-8000-00000416f101')),
  'the owner approves the declared payment');
reset role;
select is((select l.allocation_mode || ':' || l.period from public.ledger_entries l
             join public.events e on e.id = l.event_id
            where e.payload ->> 'request_id' = '00000000-0000-4000-8000-00000416f101'),
  'explicit:' || to_char(current_setting('t.today')::date - 40, 'YYYY-MM'),
  'the approved credit is explicit and posted in the month it was paid in');
select is(public.invoice_still_due_cents(pg_temp.inv('SP-S3')), 0::bigint, 'and the approval applies its claim');

-- ── A receipt before any invoice, declared by Ada, approved by the owner ─
select pg_temp.act('a2');
select isnt(pg_temp.declare_sp(null, 700, null, '00000000-0000-4000-8000-00000416f201'),
  null, 'Ada declares 7.00 paid for no invoice yet');
select pg_temp.act('a1');
select lives_ok(format('select public.respond_to_event(%L, true)',
  (select id from public.events where payload ->> 'request_id' = '00000000-0000-4000-8000-00000416f201')),
  'the owner approves it');
reset role;
select is((select l.allocation_mode || ':' || (l.amount_cents - public.payment_used_cents(l.id)) from public.ledger_entries l
             join public.events e on e.id = l.event_id
            where e.payload ->> 'request_id' = '00000000-0000-4000-8000-00000416f201'),
  'explicit:700', 'it stays an explicit credit, unapplied until an allocation');

-- ── A withdrawn claim, then a late capture ───────────────────────────────
select pg_temp.act('a2');
set local role authenticated;
select is(pg_temp.open_sp(array[pg_temp.inv('SP-S4')], 1100, '00000000-0000-4000-8000-00000416f301'), false, 'Ada pays S4 online');
select lives_ok($$select public.withdraw_payment_claim((select id from public.payment_intents where request_id = '00000000-0000-4000-8000-00000416f301'))$$,
  'and withdraws its claim before the capture');
select is(pg_temp.refusal_code($$select pg_temp.open_sp(array[pg_temp.inv('SP-S4')], 1100, '00000000-0000-4000-8000-00000416f301')$$),
  'DKC12', 'the withdrawn payment is not sent again');
reset role;
select public.settle_online_payment('stripe', (select order_id from public.payment_intents where request_id = '00000000-0000-4000-8000-00000416f301'), 'cap-sp-2', 1100);
select is((select l.allocation_mode || ':' || (l.amount_cents - public.payment_used_cents(l.id)) || ':' || public.invoice_still_due_cents(pg_temp.inv('SP-S4'))
             from public.ledger_entries l join public.payment_intents pi on pi.ledger_entry_id = l.id
            where pi.request_id = '00000000-0000-4000-8000-00000416f301'),
  'explicit:1100:1100', 'the late capture is Ada''s explicit credit, applied to nothing; S4 still owes');

-- ── Whoever issues the invoices opens one for Ada; online payments off ──
select pg_temp.act('a1');
set local role authenticated;
select is(pg_temp.open_sp(array[pg_temp.inv('SP-S5')], 600, '00000000-0000-4000-8000-00000416f401'), false,
  'the owner opens a standalone payment for Ada');
reset role;
update public.workspaces set feature_flags = feature_flags || '{"onlinePayments": false}'::jsonb where id = current_setting('t.ws')::uuid;
select pg_temp.act('a2');
set local role authenticated;
select is(pg_temp.refusal($$select pg_temp.open_sp(array[pg_temp.inv('SP-S5')], 600, '00000000-0000-4000-8000-00000416f402')$$),
  'online payments are off in this workspace', 'with online payments off no standalone payment is opened');
reset role;

select * from finish();
rollback;
