-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2380 (0688) -- a payment credit booked on the wrong member is moved to
-- the right one as a correcting entry: the original is never edited; a
-- reversal on the wrong member and a new credit on the right one, both in
-- the credit's month, linked in ledger_credit_moves; the bank line now names
-- the new credit; neither the moved credit nor its reversal is an invoice
-- line; the wrong member's month nets to what it was. Refused in words: no
-- right, a matched credit, a non-payment entry, the same member, a member who
-- left, an invoiced month, a second move, a reused request id; a retry
-- answers the same move.
begin;
select plan(19);

create or replace function pg_temp.u(p text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000002380' || p)::uuid
$$;
create or replace function pg_temp.ws() returns uuid language sql as $$
  select current_setting('deskilo.mv.ws')::uuid
$$;
create or replace function pg_temp.m(p text) returns uuid language sql as $$
  select id from public.members where workspace_id = pg_temp.ws() and user_id = pg_temp.u(p)
$$;
create or replace function pg_temp.act_as(p text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(p), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end;
$$;
create or replace function pg_temp.mv(p_credit uuid, p_to text, p_req text, p_reason text default 'paid by the colleague')
returns jsonb language sql as $$
  select public.move_payment_credit_v1(p_credit, pg_temp.m(p_to), p_reason, md5(p_req)::uuid)
$$;
-- A member's month, read as the owner (member_statement answers its
-- member or the space's staff, never an anonymous caller).
create or replace function pg_temp.stmt(p_member uuid, p_period text) returns jsonb language plpgsql as $$
declare v jsonb; v_prev text := current_setting('request.jwt.claims', true);
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.u('a1'), 'role', 'authenticated')::text, true);
  v := public.member_statement(p_member, p_period);
  perform set_config('request.jwt.claims', coalesce(v_prev, ''), true);
  return v;
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(s), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       s || '@move-credit.test', '', now(), now(), now()
  from unnest(array['a1', 'a2', 'a3', 'a4', 'a5']) s;
-- a1 owner, a2 the wrong payer, a3 the right one, a4 a plain member, a5 left.
with w as (
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Move a credit', 'FR', 'EUR', 'Europe/Paris', pg_temp.u('a1'),
          '{"moneyTab": true, "invoicing": true, "bankImport": true}'::jsonb)
  returning id)
select set_config('deskilo.mv.ws', (select id from w)::text, true);
insert into public.members (workspace_id, user_id, is_owner, is_admin, status, joined_at)
values (pg_temp.ws(), pg_temp.u('a1'), true, true, 'active', '2026-01-01'),
       (pg_temp.ws(), pg_temp.u('a2'), false, false, 'active', '2026-01-01'),
       (pg_temp.ws(), pg_temp.u('a3'), false, false, 'active', '2026-01-01'),
       (pg_temp.ws(), pg_temp.u('a4'), false, false, 'active', '2026-01-01'),
       (pg_temp.ws(), pg_temp.u('a5'), false, false, 'exited', '2026-01-01');
-- The money that arrived from a3, booked on a2; a second credit, matched; a charge.
insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period, occurred_on)
values (pg_temp.ws(), pg_temp.m('a2'), 'credit', 'payment', 4200, 'Bank transfer', '2026-03', '2026-03-10');
select set_config('deskilo.mv.c1', (select id from public.ledger_entries where member_id = pg_temp.m('a2') and amount_cents = 4200)::text, true);
insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period, occurred_on)
values (pg_temp.ws(), pg_temp.m('a2'), 'charge', 'service', 900, 'Coffee', '2026-03', '2026-03-11');
select set_config('deskilo.mv.charge', (select id from public.ledger_entries where member_id = pg_temp.m('a2') and amount_cents = 900)::text, true);
-- The bank line that brought it.
with st as (
  insert into public.bank_statements (workspace_id, format, account, currency, source_sha256, period_from, period_to)
  values (pg_temp.ws(), 'camt053', 'FR76', 'EUR', repeat('a', 64), '2026-03-01', '2026-03-31') returning id)
insert into public.bank_statement_lines (workspace_id, statement_id, account, position, booking_date, value_date,
                                         amount_cents, currency, line_hash, payment_ledger_id)
select pg_temp.ws(), st.id, 'FR76', 1, '2026-03-10', '2026-03-10', 4200, 'EUR', repeat('b', 64),
       current_setting('deskilo.mv.c1')::uuid from st;
select set_config('deskilo.mv.before', pg_temp.stmt(pg_temp.m('a2'), '2026-03') ->> 'credits_cents', true);

-- 1-2. who may
select pg_temp.act_as('a4');
select throws_ok($$ select pg_temp.mv(current_setting('deskilo.mv.c1')::uuid, 'a3', 'r0') $$,
  '42501', null, 'a plain member cannot move a credit');
reset role;
select pg_temp.act_as('a1');
select throws_ok($$ select pg_temp.mv(current_setting('deskilo.mv.c1')::uuid, 'a3', 'r1', '  ') $$,
  '22023', 'a reason is required', 'a move needs its reason');

-- 3-6. the refusals that name the problem
select throws_ok($$ select pg_temp.mv(current_setting('deskilo.mv.charge')::uuid, 'a3', 'r2') $$,
  '22023', 'only a payment credit is moved', 'a charge is not moved');
select throws_ok($$ select pg_temp.mv(current_setting('deskilo.mv.c1')::uuid, 'a2', 'r3') $$,
  '22023', 'the credit is already on this member', 'not onto the same member');
select throws_ok($$ select pg_temp.mv(current_setting('deskilo.mv.c1')::uuid, 'a5', 'r4') $$,
  '22023', 'unknown or departed member', 'not onto a member who left');
reset role;

-- 7-15. the move
select pg_temp.act_as('a1');
select set_config('deskilo.mv.r', pg_temp.mv(current_setting('deskilo.mv.c1')::uuid, 'a3', 'r5')::text, true);
reset role;
select ok((select kind = 'credit' and category = 'payment' and amount_cents = 4200 and member_id = pg_temp.m('a2')
             from public.ledger_entries where id = current_setting('deskilo.mv.c1')::uuid),
  'the original credit is untouched');
select ok((select kind = 'charge' and category = 'adjustment' and amount_cents = 4200 and member_id = pg_temp.m('a2')
                  and period = '2026-03' and occurred_on = '2026-03-10'
             from public.ledger_entries where id = (current_setting('deskilo.mv.r')::jsonb ->> 'reversal_id')::uuid),
  'the wrong member gets a reversal of the same amount, in the credit''s month and day');
select ok((select kind = 'credit' and category = 'payment' and amount_cents = 4200 and member_id = pg_temp.m('a3')
                  and period = '2026-03' and occurred_on = '2026-03-10'
             from public.ledger_entries where id = (current_setting('deskilo.mv.r')::jsonb ->> 'credit_id')::uuid),
  'the right member gets the credit, same month and day');
select ok((select from_credit_id = current_setting('deskilo.mv.c1')::uuid and from_member_id = pg_temp.m('a2')
                  and to_member_id = pg_temp.m('a3') and actor_member_id = pg_temp.m('a1') and reason = 'paid by the colleague'
             from public.ledger_credit_moves where id = (current_setting('deskilo.mv.r')::jsonb ->> 'id')::uuid),
  'the move is recorded: both credits, both members, who and why');
select is((select payment_ledger_id from public.bank_statement_lines where workspace_id = pg_temp.ws()),
  (current_setting('deskilo.mv.r')::jsonb ->> 'credit_id')::uuid, 'the bank line now names the right member''s credit');
select is(pg_temp.stmt(pg_temp.m('a2'), '2026-03') ->> 'credits_cents',
  ((current_setting('deskilo.mv.before'))::int - 4200)::text, 'the wrong member''s month loses the credit');
select is((pg_temp.stmt(pg_temp.m('a3'), '2026-03') ->> 'credits_cents')::int, 4200,
  'and the right member''s month has it');
select ok(not exists (select 1 from jsonb_array_elements(public.invoice_lines_for(pg_temp.m('a2'), '2026-03')) l
                       where (l ->> 'amount_cents')::int in (4200, -4200)),
  'neither the moved credit nor its reversal is a line of the wrong member''s invoice');
select ok(exists (select 1 from jsonb_array_elements(public.invoice_lines_for(pg_temp.m('a3'), '2026-03')) l
                   where (l ->> 'amount_cents')::int = -4200 and l ->> 'kind' = 'payment'),
  'the right member''s invoice carries the payment');

-- 16-18. exactly once
select pg_temp.act_as('a1');
select is(pg_temp.mv(current_setting('deskilo.mv.c1')::uuid, 'a3', 'r5') ->> 'id',
  current_setting('deskilo.mv.r')::jsonb ->> 'id', 'a retry answers the same move');
select throws_ok($$ select pg_temp.mv(current_setting('deskilo.mv.c1')::uuid, 'a4', 'r6') $$,
  '22023', 'this credit was already moved', 'a moved credit is not moved again');
select throws_ok($$ select pg_temp.mv(current_setting('deskilo.mv.c1')::uuid, 'a4', 'r5') $$,
  '22023', 'this request id was already used for a different request', 'a request id names one move');
reset role;

-- 19-20. a matched credit and an invoiced month
insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period, occurred_on)
values (pg_temp.ws(), pg_temp.m('a4'), 'credit', 'payment', 1500, 'Cash', '2026-04', '2026-04-02');
select set_config('deskilo.mv.c2', (select id from public.ledger_entries where member_id = pg_temp.m('a4') and amount_cents = 1500)::text, true);
insert into public.invoices (workspace_id, member_id, issuer_member_id, number, period, title, lines, total_cents,
                             currency, member_name, workspace_name, issuer_name, signature, kind)
values (pg_temp.ws(), pg_temp.m('a4'), pg_temp.m('a1'), 'T-1', '2026-04', '2026-04', '[]', 0, 'EUR', 'A4', 'W', 'O', repeat('s', 64), 'full');
select pg_temp.act_as('a1');
select throws_ok($$ select pg_temp.mv(current_setting('deskilo.mv.c2')::uuid, 'a3', 'r7') $$,
  '22023', 'this month is already invoiced to the member: correct that invoice first', 'an invoiced month is not reopened by a move');
reset role;
insert into public.invoice_matches (workspace_id, invoice_id, paid_cents, resolution, status, payment_ledger_id)
select pg_temp.ws(), id, 1500, 'exact', 'confirmed', current_setting('deskilo.mv.c2')::uuid
  from public.invoices where number = 'T-1';
select pg_temp.act_as('a1');
select throws_ok($$ select pg_temp.mv(current_setting('deskilo.mv.c2')::uuid, 'a3', 'r8') $$,
  '22023', 'this credit pays an invoice: undo the match first', 'a credit that pays an invoice is unmatched first');
reset role;

select * from finish();
rollback;
