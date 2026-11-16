-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3556 (1a): a payment names the invoices it pays (its claim). With a claim
-- the amount is what they still owe; another member's invoice, an unknown id
-- and another business's invoice get one answer; one month per payment; an
-- invoice in an open claim cannot enter a second one. At settlement the
-- claim is applied oldest first through the rule a person's match follows:
-- approved at once without a validation policy, pending with one; an
-- invoice paid otherwise meanwhile leaves the money the payer's credit; the
-- owner's approval of a declared payment applies exactly its claim, a
-- refusal changes nothing; a withdrawn claim frees its invoices; a callback
-- delivered twice applies once; without a claim nothing changes. Rolled back.
begin;
select plan(43);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000035560a1';
  u_a uuid := '00000000-0000-4000-8000-0000035560a2';
  u_b uuid := '00000000-0000-4000-8000-0000035560a3';
  ws uuid; ws2 uuid; wsp uuid; m_o uuid; m_o2 uuid; m_a uuid; m_b uuid; m_a2 uuid; m_op uuid; m_ap uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'claims-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_a, u_b]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Claims', 'FR', 'EUR', 'Europe/Paris', u_o, '{"moneyTab": true, "invoicing": true, "onlinePayments": true}'::jsonb)
  returning id into ws;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Elsewhere', 'FR', 'EUR', 'Europe/Paris', u_o, '{"moneyTab": true, "invoicing": true, "onlinePayments": true}'::jsonb)
  returning id into ws2;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Four eyes', 'FR', 'EUR', 'Europe/Paris', u_o, '{"moneyTab": true, "invoicing": true, "onlinePayments": true}'::jsonb)
  returning id into wsp;
  delete from public.validation_policies where workspace_id in (ws, ws2);
  insert into public.members (workspace_id, user_id, is_owner, is_admin, status, joined_at)
  values (ws, u_o, true, true, 'active', '2026-01-01'), (ws, u_a, false, false, 'active', '2026-01-01'),
         (ws, u_b, false, false, 'active', '2026-01-01'),
         (ws2, u_o, true, true, 'active', '2026-01-01'), (ws2, u_a, false, false, 'active', '2026-01-01'),
         (wsp, u_o, true, true, 'active', '2026-01-01'), (wsp, u_a, false, false, 'active', '2026-01-01');
  select id into m_o from public.members where workspace_id = ws and user_id = u_o;
  select id into m_a from public.members where workspace_id = ws and user_id = u_a;
  select id into m_b from public.members where workspace_id = ws and user_id = u_b;
  select id into m_a2 from public.members where workspace_id = ws2 and user_id = u_a;
  select id into m_o2 from public.members where workspace_id = ws2 and user_id = u_o;
  select id into m_op from public.members where workspace_id = wsp and user_id = u_o;
  select id into m_ap from public.members where workspace_id = wsp and user_id = u_a;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name, signature, period, issued_at, kind)
  values (ws, m_a, m_o, 'CL-A1', 'A1', '[]'::jsonb, 5000, 'EUR', 'Ada', 'Claims', 'Owner', 'sig', '2026-10', '2026-10-01', 'full'),
         (ws, m_a, m_o, 'CL-A2', 'A2', '[]'::jsonb, 3000, 'EUR', 'Ada', 'Claims', 'Owner', 'sig', '2026-10', '2026-10-02', 'subscription'),
         (ws, m_a, m_o, 'CL-A3', 'A3', '[]'::jsonb, 2000, 'EUR', 'Ada', 'Claims', 'Owner', 'sig', '2026-09', '2026-09-01', 'full'),
         (ws, m_a, m_o, 'CL-A4', 'A4', '[]'::jsonb, 1000, 'EUR', 'Ada', 'Claims', 'Owner', 'sig', '2026-10', '2026-10-03', 'usage'),
         (ws, m_a, m_o, 'CL-A5', 'A5', '[]'::jsonb, 1500, 'EUR', 'Ada', 'Claims', 'Owner', 'sig', '2026-10', '2026-10-04', 'settlement'),
         (ws, m_a, m_o, 'CL-A6', 'A6', '[]'::jsonb, 1200, 'EUR', 'Ada', 'Claims', 'Owner', 'sig', '2026-11', '2026-11-01', 'full'),
         (ws, m_a, m_o, 'CL-V1', 'V1', '[]'::jsonb, 900, 'EUR', 'Ada', 'Claims', 'Owner', 'sig', '2026-08', '2026-08-01', 'full'),
         (ws, m_b, m_o, 'CL-B1', 'B1', '[]'::jsonb, 4000, 'EUR', 'Ben', 'Claims', 'Owner', 'sig', '2026-10', '2026-10-01', 'full'),
         (ws2, m_a2, m_o2, 'EL-W1', 'W1', '[]'::jsonb, 4000, 'EUR', 'Ada', 'Elsewhere', 'Owner', 'sig', '2026-10', '2026-10-01', 'full'),
         (wsp, m_ap, m_op, 'FE-P1', 'P1', '[]'::jsonb, 2500, 'EUR', 'Ada', 'Four eyes', 'Owner', 'sig', '2026-10', '2026-10-01', 'full');
  update public.invoices set voided_at = now() where number = 'CL-V1';
  perform set_config('t.ws', ws::text, true);
  perform set_config('t.wsp', wsp::text, true);
  perform set_config('t.m_a', m_a::text, true);
  perform set_config('t.m_ap', m_ap::text, true);
  -- Read here: as Ada, Ben's invoice is not even visible.
  perform set_config('t.b1', (select id::text from public.invoices where number = 'CL-B1'), true);
end;
$seed$;
select pg_temp.seed();

create or replace function pg_temp.inv(p_number text) returns uuid language sql as
  $$ select id from public.invoices where number = p_number $$;
create or replace function pg_temp.act(p_user text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', '00000000-0000-4000-8000-0000035560' || p_user, 'role', 'authenticated')::text, true);
end $$;
create or replace function pg_temp.open_intent(p_ids uuid[], p_amount int, p_period text, p_request uuid default null)
returns uuid language sql as $$
  select id from public.open_payment_intent(current_setting('t.ws')::uuid, current_setting('t.m_a')::uuid,
    'stripe', p_period, p_amount, 'EUR', p_request, p_ids)
$$;
create or replace function pg_temp.refusal(p_sql text) returns text language plpgsql as $$
begin execute p_sql; return null; exception when others then return sqlerrm; end $$;
create or replace function pg_temp.refusal_code(p_sql text) returns text language plpgsql as $$
begin execute p_sql; return null; exception when others then return sqlstate; end $$;
grant execute on all functions in schema pg_temp to authenticated;

-- ── Opening a claim, as Ada ─────────────────────────────────────────────
select pg_temp.act('a2');
set local role authenticated;
select lives_ok($$select pg_temp.open_intent(array[pg_temp.inv('CL-A2'), pg_temp.inv('CL-A1')], 8000, '2026-10', '00000000-0000-4000-8000-000003556f01')$$,
  'a payment of two invoices of one month, at what they still owe');
select is(pg_temp.refusal($$select pg_temp.open_intent(array[pg_temp.inv('CL-A5')], 1400, '2026-10')$$),
  'a payment of these invoices is what they still owe (1500 in minor units), not 1400',
  'condition 1: another amount with a claim is refused in words');
select is(pg_temp.refusal($$select pg_temp.open_intent(array[pg_temp.inv('CL-A5'), current_setting('t.b1')::uuid], 5500, '2026-10')$$),
  'an invoice of this payment is not one of yours to pay', 'condition 4: another member''s invoice');
select is(pg_temp.refusal_code($$select pg_temp.open_intent(array[pg_temp.inv('CL-A5'), current_setting('t.b1')::uuid], 5500, '2026-10')$$),
  'DKC02', 'and the app reads it by its code');
select is(pg_temp.refusal_code($$select pg_temp.open_intent(array[pg_temp.inv('CL-A5')], 1400, '2026-10')$$),
  'DKC07', 'the amount refusal has its code');
select is(pg_temp.refusal($$select pg_temp.open_intent(array[pg_temp.inv('CL-A5'), '00000000-0000-4000-8000-00000355dead'::uuid], 1500, '2026-10')$$),
  'an invoice of this payment is not one of yours to pay', 'condition 4: an unknown id, the same answer');
select is(pg_temp.refusal($$select pg_temp.open_intent(array[pg_temp.inv('CL-A5'), pg_temp.inv('EL-W1')], 5500, '2026-10')$$),
  'an invoice of this payment is not one of yours to pay', 'condition 4: another business''s invoice, the same answer');
select is(pg_temp.refusal($$select pg_temp.open_intent(array[pg_temp.inv('CL-A5'), pg_temp.inv('CL-A3')], 3500, '2026-10')$$),
  'a payment settles invoices of one month: this selection spans 2026-09, 2026-10', 'condition 6: the months are named');
select is(pg_temp.refusal($$select pg_temp.open_intent(array[pg_temp.inv('CL-A2')], 3000, '2026-10')$$),
  'CL-A2 is already in a payment being processed', 'condition 2: an invoice in an open online claim, named, and why');
select is(pg_temp.refusal($$select pg_temp.open_intent(array[pg_temp.inv('CL-A5')], 8000, '2026-10', '00000000-0000-4000-8000-000003556f01')$$),
  'payment request conflict: this request id was opened with another payment', 'a retry with another selection is a conflict');
select is(pg_temp.open_intent(array[pg_temp.inv('CL-A1'), pg_temp.inv('CL-A2')], 8000, '2026-10', '00000000-0000-4000-8000-000003556f01'),
  (select id from public.payment_intents where request_id = '00000000-0000-4000-8000-000003556f01'),
  'the same selection, in any order, is the same payment');
select lives_ok($$select pg_temp.open_intent(null, 1234, '2026-10')$$, 'without a claim, a payment opens as before');
select lives_ok(format('select public.record_payment(%L, %L, 1000, %L, %L, null, null, array[%L]::uuid[])',
  current_setting('t.ws'), current_setting('t.m_a'), '', 'transfer', pg_temp.inv('CL-A4')),
  'a declared payment of one invoice');
select is(pg_temp.refusal(format('select public.record_payment(%L, %L, 1000, %L, %L, null, null, array[%L]::uuid[])',
  current_setting('t.ws'), current_setting('t.m_a'), '', 'transfer', pg_temp.inv('CL-A4'))),
  'CL-A4 is already in a declared payment awaiting approval', 'condition 2: an invoice in a declared payment awaiting approval');
reset role;
select is((select payload -> 'claim' -> 0 ->> 'number' from public.events where type = 'payment' and subject_member_id = current_setting('t.m_a')::uuid and status = 'pending' and payload ? 'claim'),
  'CL-A4', 'condition 5: the owner reads the claimed invoice by its number');

-- ── The provider's capture applies the claim ────────────────────────────
select lives_ok($$select public.settle_online_payment('stripe', (select order_id from public.payment_intents where request_id = '00000000-0000-4000-8000-000003556f01'), 'cap-1', 8000)$$,
  'the capture of the claimed payment');
select is((select string_agg(i.number || '=' || m.status || ':' || m.paid_cents, ',' order by i.number)
             from public.invoice_matches m join public.invoices i on i.id = m.invoice_id where i.number in ('CL-A1', 'CL-A2')),
  'CL-A1=confirmed:5000,CL-A2=confirmed:3000', 'without a validation policy both invoices are settled, each at what it owed');
select is((select count(*)::int from public.events e where e.type = 'invoice_payment'
             and e.actor_member_id = current_setting('t.m_a')::uuid
             and e.payload ->> 'claim_source' = (select id::text from public.payment_intents where request_id = '00000000-0000-4000-8000-000003556f01')),
  2, 'each part is the payer''s and names its claim');
select lives_ok($$select public.settle_online_payment('stripe', (select order_id from public.payment_intents where request_id = '00000000-0000-4000-8000-000003556f01'), 'cap-1', 8000)$$,
  'the same capture delivered twice');
select is((select count(*)::int from public.invoice_match_payments p join public.invoices i on i.id = p.invoice_id where i.number in ('CL-A1', 'CL-A2')),
  2, 'and applied once');
select is((select count(*)::int from public.open_claim_invoices(current_setting('t.ws')::uuid) o where o.invoice_id in (pg_temp.inv('CL-A1'), pg_temp.inv('CL-A2'))),
  0, 'a captured payment frees its invoices');

-- ── Paid otherwise meanwhile (condition 3) ──────────────────────────────
select pg_temp.act('a2');
set local role authenticated;
select lives_ok($$select pg_temp.open_intent(array[pg_temp.inv('CL-A5')], 1500, '2026-10', '00000000-0000-4000-8000-000003556f02')$$,
  'a claim of A5');
reset role;
insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period)
values (current_setting('t.ws')::uuid, current_setting('t.m_a')::uuid, 'credit', 'payment', 1500, 'cash', '2026-10');
select pg_temp.act('a1');
set local role authenticated;
select lives_ok(format('select public.match_invoice(%L, %L, %L)', pg_temp.inv('CL-A5'),
  (select id from public.ledger_entries where description = 'cash' and member_id = current_setting('t.m_a')::uuid), 'exact'),
  'the owner settles A5 with cash meanwhile');
reset role;
select lives_ok($$select public.settle_online_payment('stripe', (select order_id from public.payment_intents where request_id = '00000000-0000-4000-8000-000003556f02'), 'cap-2', 1500)$$,
  'the claimed payment arrives after');
select is((select l.amount_cents - public.payment_used_cents(l.id) from public.ledger_entries l
            join public.payment_intents pi on pi.ledger_entry_id = l.id
           where pi.request_id = '00000000-0000-4000-8000-000003556f02'),
  1500::bigint, 'condition 3: the money stays the payer''s credit, applied to nothing else');

-- ── A declared payment: the owner decides its claim (condition 5) ───────
select pg_temp.act('a1');
set local role authenticated;
select lives_ok(format('select public.respond_to_event(%L, true)',
  (select id from public.events where type = 'payment' and status = 'pending' and payload -> 'claim' -> 0 ->> 'number' = 'CL-A4')),
  'the owner approves the declared payment');
reset role;
select is((select m.status || ':' || m.paid_cents from public.invoice_matches m where m.invoice_id = pg_temp.inv('CL-A4')),
  'confirmed:1000', 'approving applies exactly its claim');
insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period, event_id)
select workspace_id, subject_member_id, 'credit', 'payment', 1000, 'replay', '2026-10', id
  from public.events where type = 'payment' and payload -> 'claim' -> 0 ->> 'number' = 'CL-A4';
select is((select count(*)::int from public.invoice_match_payments p where p.invoice_id = pg_temp.inv('CL-A4')),
  1, 'a second credit naming the approved payment applies nothing more');
select pg_temp.act('a2');
set local role authenticated;
select is(pg_temp.refusal(format('insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period) values (%L, %L, %L, %L, 1, %L, %L)',
  current_setting('t.ws'), current_setting('t.m_a'), 'credit', 'payment', 'forged', '2026-10')) is not null,
  true, 'a client cannot write a ledger row to reach the claim');
reset role;

-- ── match_invoice: the permission first (accepted order) ────────────────
-- Read here: as Ben, Ada's invoices are not even visible.
select set_config('t.v1', pg_temp.inv('CL-V1')::text, true), set_config('t.a1', pg_temp.inv('CL-A1')::text, true),
       set_config('t.a6', pg_temp.inv('CL-A6')::text, true);
select pg_temp.act('a3');
set local role authenticated;
select is(pg_temp.refusal(format('select public.match_invoice(%L, %L, %L)', current_setting('t.v1'), gen_random_uuid(), 'exact')),
  'admins may not issue invoices here', 'without the right to issue: a voided invoice gets the permission refusal');
select is(pg_temp.refusal(format('select public.match_invoice(%L, %L, %L)', current_setting('t.a1'), gen_random_uuid(), 'exact')),
  'admins may not issue invoices here', 'the same for a matched invoice');
select is(pg_temp.refusal(format('select public.match_invoice(%L, %L, %L)', current_setting('t.a6'), gen_random_uuid(), 'exact')),
  'admins may not issue invoices here', 'and for an open one');
reset role;

-- ── Withdrawn: the invoices are free ───────────────────────────────────
select pg_temp.act('a2');
set local role authenticated;
select lives_ok($$select public.withdraw_payment_claim(pg_temp.open_intent(array[pg_temp.inv('CL-A3')], 2000, '2026-09'))$$,
  'a member withdraws a claim not yet captured');
select lives_ok($$select pg_temp.open_intent(array[pg_temp.inv('CL-A3')], 2000, '2026-09')$$,
  'its invoice can enter another payment');
reset role;

-- ── A business with a second pair of eyes on matching ───────────────────
insert into public.validation_policies (workspace_id, event_type)
values (current_setting('t.wsp')::uuid, 'invoice_payment')
on conflict do nothing;
select pg_temp.act('a2');
set local role authenticated;
select lives_ok(format('select public.open_payment_intent(%L, %L, %L, %L, 2500, %L, %L, array[%L]::uuid[])',
  current_setting('t.wsp'), current_setting('t.m_ap'), 'stripe', '2026-10', 'EUR', '00000000-0000-4000-8000-000003556f03', pg_temp.inv('FE-P1')),
  'a claim where matches are validated');
reset role;
select lives_ok($$select public.settle_online_payment('stripe', (select order_id from public.payment_intents where request_id = '00000000-0000-4000-8000-000003556f03'), 'cap-3', 2500)$$,
  'its capture');
select is((select m.status from public.invoice_matches m where m.invoice_id = pg_temp.inv('FE-P1')),
  'pending', 'with a validation policy the part waits for its validators');
select is((select l.amount_cents - public.payment_used_cents(l.id) from public.ledger_entries l
            join public.payment_intents pi on pi.ledger_entry_id = l.id
           where pi.request_id = '00000000-0000-4000-8000-000003556f03'),
  0::bigint, 'the money is reserved for that part while it waits');
select pg_temp.act('a1');
set local role authenticated;
select lives_ok(format('select public.respond_to_event(%L, false)',
  (select e.id from public.events e where e.type = 'invoice_payment' and e.payload ->> 'invoice_id' = pg_temp.inv('FE-P1')::text)),
  'a validator refuses the part');
reset role;
select is((select l.amount_cents - public.payment_used_cents(l.id) from public.ledger_entries l
            join public.payment_intents pi on pi.ledger_entry_id = l.id
           where pi.request_id = '00000000-0000-4000-8000-000003556f03'),
  2500::bigint, 'the refused part leaves the money the payer''s credit');

-- ── A declared payment refused changes nothing (condition 5) ────────────
select pg_temp.act('a2');
set local role authenticated;
select lives_ok(format('select public.record_payment(%L, %L, 1200, %L, %L, null, null, array[%L]::uuid[])',
  current_setting('t.ws'), current_setting('t.m_a'), '', 'transfer', pg_temp.inv('CL-A6')),
  'a declared payment of A6');
reset role;
select pg_temp.act('a1');
set local role authenticated;
select lives_ok(format('select public.respond_to_event(%L, false)',
  (select id from public.events where type = 'payment' and status = 'pending' and payload -> 'claim' -> 0 ->> 'number' = 'CL-A6')),
  'the owner refuses it');
reset role;
select is((select count(*)::int from public.invoice_matches m where m.invoice_id = pg_temp.inv('CL-A6'))
          + (select count(*)::int from public.open_claim_invoices(current_setting('t.ws')::uuid) o where o.invoice_id = pg_temp.inv('CL-A6')),
  0, 'nothing is applied and A6 is free again');

select * from finish();
rollback;
