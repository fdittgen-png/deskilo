-- SPDX-License-Identifier: AGPL-3.0-or-later
-- utc-date-file: the assertions hold with the business's day one day ahead of and one day behind the database's (workspace_today forced to current_date +/- 1 on the dev project, #4384)
-- #4140 (0808) — My finances answers, for an invoice a declared payment
-- names while the business has not decided it, that declaration (the one
-- its member may take back): never an online payment's, never another
-- member's, never once taken back. Money moved off a payment credit to
-- another member's account no longer holds the invoice it did not pay.
begin;
select plan(14);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000041401a1';
  u_a uuid := '00000000-0000-4000-8000-0000041401a2';
  u_b uuid := '00000000-0000-4000-8000-0000041401a3';
  ws uuid; m_o uuid; m_a uuid; m_b uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'takeback-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_a, u_b]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Take back', 'FR', 'EUR', 'Europe/Paris', u_o,
          '{"moneyTab": true, "invoicing": true, "onlinePayments": true, "bankImport": true}'::jsonb)
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
  values (ws, m_a, m_o, 'TB-A1', 'A1', '[]'::jsonb, 4000, 'EUR', 'Ada', 'Take back', 'Owner', 'sig', '2026-10', '2026-11-02', 'full'),
         (ws, m_a, m_o, 'TB-A2', 'A2', '[]'::jsonb, 2500, 'EUR', 'Ada', 'Take back', 'Owner', 'sig', '2026-09', '2026-10-01', 'full'),
         (ws, m_a, m_o, 'TB-A3', 'A3', '[]'::jsonb, 1500, 'EUR', 'Ada', 'Take back', 'Owner', 'sig', '2026-08', '2026-09-01', 'full'),
         (ws, m_a, m_o, 'TB-A4', 'A4', '[]'::jsonb, 1100, 'EUR', 'Ada', 'Take back', 'Owner', 'sig', '2026-07', '2026-08-01', 'full'),
         (ws, m_b, m_o, 'TB-B1', 'B1', '[]'::jsonb, 3000, 'EUR', 'Ben', 'Take back', 'Owner', 'sig', '2026-10', '2026-10-02', 'full');
  perform set_config('t.ws', ws::text, true);
  perform set_config('t.m_a', m_a::text, true);
  perform set_config('t.m_b', m_b::text, true);
end;
$seed$;
select pg_temp.seed();

create or replace function pg_temp.inv(p_number text) returns uuid language sql as
  $$ select id from public.invoices where number = p_number $$;
select set_config('t.a1', pg_temp.inv('TB-A1')::text, true);
select set_config('t.a2', pg_temp.inv('TB-A2')::text, true);
select set_config('t.a3', pg_temp.inv('TB-A3')::text, true);
select set_config('t.a4', pg_temp.inv('TB-A4')::text, true);
select set_config('t.b1', pg_temp.inv('TB-B1')::text, true);
create or replace function pg_temp.act(p_user text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', '00000000-0000-4000-8000-0000041401' || p_user, 'role', 'authenticated')::text, true);
end $$;
-- What the overview answers about one invoice, as Ada.
create or replace function pg_temp.row_of(p_invoice text) returns jsonb language sql as $$
  select x from jsonb_array_elements(public.my_finance_overview() -> 'invoices') x
   where x ->> 'id' = p_invoice
$$;
-- The two payment ids an invoice answers, as "event:payment" ("none" for null).
create or replace function pg_temp.ids(p_invoice text) returns text language sql as $$
  select coalesce(pg_temp.row_of(p_invoice) ->> 'claim_event_id', 'none') || ':'
         || coalesce(pg_temp.row_of(p_invoice) ->> 'claim_payment_id', 'none')
$$;
create or replace function pg_temp.held(p_invoice text) returns text language sql as $$
  select (pg_temp.row_of(p_invoice) ->> 'payable') || ':' || (pg_temp.row_of(p_invoice) ->> 'payment_received')
$$;
grant execute on all functions in schema pg_temp to authenticated;

-- ── a declared payment answers its declaration, an online one its payment ──
select pg_temp.act('a2');
set local role authenticated;
select lives_ok(format($$select public.record_payment(%L, %L, 4000, '', 'transfer', null, '2026-10', array[%L]::uuid[])$$,
  current_setting('t.ws'), current_setting('t.m_a'), current_setting('t.a1')),
  'Ada declares A1 paid');
select set_config('t.e1', (select id::text from public.events where type = 'payment' and status = 'pending'
  and payload -> 'claim' @> jsonb_build_array(jsonb_build_object('invoice_id', current_setting('t.a1')))), true);
select is(pg_temp.ids(current_setting('t.a1')), current_setting('t.e1') || ':none',
  'a declared payment''s invoice answers that declaration and no online payment');
select set_config('t.p2', (select id::text from public.open_payment_intent(current_setting('t.ws')::uuid,
  current_setting('t.m_a')::uuid, 'stripe', '2026-09', 2500, 'EUR', null, array[current_setting('t.a2')::uuid])), true);
select is(pg_temp.ids(current_setting('t.a2')), 'none:' || current_setting('t.p2'),
  'an online payment''s invoice answers that payment and no declaration');
reset role;

-- ── another member's declaration is never named ──────────────────────────
select pg_temp.act('a3');
set local role authenticated;
select lives_ok(format($$select public.record_payment(%L, %L, 3000, '', 'transfer', null, '2026-10', array[%L]::uuid[])$$,
  current_setting('t.ws'), current_setting('t.m_b'), current_setting('t.b1')),
  'Ben declares his own invoice paid');
reset role;
select pg_temp.act('a2');
set local role authenticated;
select is((select count(*)::int from jsonb_array_elements(public.my_finance_overview() -> 'invoices') x
            where x ->> 'id' = current_setting('t.b1')
               or x ->> 'claim_event_id' in (select id::text from public.events
                                              where subject_member_id = current_setting('t.m_b')::uuid)),
  0, 'Ben''s declaration is never named in Ada''s finances');

-- ── taken back, the invoice answers neither and may be paid again ────────
select lives_ok(format('select public.withdraw_payment_declaration(%L)', current_setting('t.e1')),
  'Ada takes the declaration back');
select is(pg_temp.ids(current_setting('t.a1')) || ':' || (pg_temp.row_of(current_setting('t.a1')) ->> 'in_payment')
          || ':' || (pg_temp.row_of(current_setting('t.a1')) ->> 'payable'),
  'none:none:false:true', 'taken back: no declaration, not in payment, payable again');
reset role;

-- ── money moved to another member no longer holds the invoice ────────────
-- (a) an online payment withdrawn, then captured: its money waits unapplied
select pg_temp.act('a2');
set local role authenticated;
select set_config('t.p3', (select id::text from public.open_payment_intent(current_setting('t.ws')::uuid,
  current_setting('t.m_a')::uuid, 'stripe', '2026-08', 1500, 'EUR', null, array[current_setting('t.a3')::uuid])), true);
select lives_ok($$select public.withdraw_payment_claim(current_setting('t.p3')::uuid)$$, 'A3''s claim withdrawn');
reset role;
select lives_ok($$select public.settle_online_payment('stripe', (select order_id from public.payment_intents where id = current_setting('t.p3')::uuid), 'cap-p3', 1500)$$,
  'the provider captures it afterwards');
-- (b) a declared payment approved while no match can be booked
select pg_temp.act('a2');
set local role authenticated;
select lives_ok(format($$select public.record_payment(%L, %L, 1100, '', 'transfer', null, '2026-07', array[%L]::uuid[])$$,
  current_setting('t.ws'), current_setting('t.m_a'), current_setting('t.a4')),
  'Ada declares A4 paid');
reset role;
insert into public.book_periods (workspace_id, period_from, period_to, reason)
values (current_setting('t.ws')::uuid, current_date - 1, current_date + 1, 'owner');
select pg_temp.act('a1');
set local role authenticated;
select lives_ok(format('select public.respond_to_event(%L, true)',
  (select id from public.events where type = 'payment' and status = 'pending'
     and payload -> 'claim' @> jsonb_build_array(jsonb_build_object('invoice_id', current_setting('t.a4'))))),
  'the owner approves it while the books are closed: nothing is applied');
reset role;
delete from public.book_periods where workspace_id = current_setting('t.ws')::uuid and reason = 'owner';
select pg_temp.act('a2');
set local role authenticated;
select is(pg_temp.held(current_setting('t.a3')) || ' ' || pg_temp.held(current_setting('t.a4')),
  'false:true false:true', 'both invoices are held while the money is Ada''s and unapplied');
reset role;
-- neither credit can be moved to another member while its invoice holds
select pg_temp.act('a1');
set local role authenticated;
select throws_ok(format($$select public.move_payment_credit_v1(%L, %L, 'paid for Ben', gen_random_uuid())$$,
  (select ledger_entry_id from public.payment_intents where id = current_setting('t.p3')::uuid), current_setting('t.m_b')),
  'this month is already invoiced to the member: correct that invoice first',
  'the online payment''s money cannot be moved off a held invoice''s month: '
           'were this allowed, invoice_payment_received would have to net the move');
select throws_ok(format($$select public.move_payment_credit_v1(%L, %L, 'paid for Ben', gen_random_uuid())$$,
  (select l.id from public.ledger_entries l join public.events e on e.id = l.event_id
    where l.kind = 'credit' and l.category = 'payment'
      and e.payload -> 'claim' @> jsonb_build_array(jsonb_build_object('invoice_id', current_setting('t.a4')))),
  current_setting('t.m_b')),
  'this month is already invoiced to the member: correct that invoice first',
  'nor the declared payment''s');
reset role;

select * from finish();
rollback;
