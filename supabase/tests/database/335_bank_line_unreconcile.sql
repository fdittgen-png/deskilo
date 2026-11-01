-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2380 (0645) -- a reconciliation of money out is undone once, by a
-- person with the right that reconciles, with a reason, on the record. The
-- owner reconciles L1 (money out, 50.00) with P1, the wrong one of two
-- reimbursements of that amount. A plain member, a biller (issueInvoices
-- alone), the owner of another space, an assistant's token and an unknown
-- line are refused (42501); the other space, whose flag is off, is refused
-- for its own owner (0A000); no reason and a request id reused for another
-- line are refused (22023); money in is refused (DKB02). Undone: L1 is
-- open again and names no payment, its bank facts are untouched; P1 is
-- reported again with no bank days and what was reported unchanged; one
-- record keeps the line, the payment, who reconciled and when, the bank
-- days P1 had taken, the reason and who undid it. The same request again
-- answers the same and adds nothing; a second undoing is refused as
-- decided meanwhile (DKB01). L1 then reconciles P2, the right one, and
-- nothing moves P2 back while L1 names it. The record is read by the
-- statements' readers only, written by nobody, and the command is not
-- anon's. Positive cases beside every refusal.
begin;
select plan(30);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000064500a1';
  u_m uuid := '00000000-0000-4000-8000-0000064500a2';
  u_b uuid := '00000000-0000-4000-8000-0000064500a3';
  u_x uuid := '00000000-0000-4000-8000-0000064500a4';
  ws uuid; ws2 uuid; m_o uuid; m_m uuid; m_b uuid; m_x uuid; r_b uuid; st uuid; st2 uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'unrec-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_m, u_b, u_x]) u;
  -- The flag and every parent on (moneyTab > invoicing > bankImport).
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Undo books', 'CH', 'CHF', 'Europe/Zurich', u_o,
          '{"moneyTab": true, "invoicing": true, "bankImport": true, "customRoles": true}'::jsonb)
  returning id into ws;
  -- Another space, the flag off.
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Paper undo', 'CH', 'CHF', 'Europe/Zurich', u_x,
          '{"moneyTab": true, "invoicing": true, "bankImport": false}'::jsonb)
  returning id into ws2;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, status, joined_at)
  values (ws, u_o, true, true, 'active', '2026-01-01'), (ws, u_m, false, false, 'active', '2026-01-01'),
         (ws, u_b, false, false, 'active', '2026-01-01'), (ws2, u_x, true, true, 'active', '2026-01-01');
  select id into m_o from public.members where workspace_id = ws and user_id = u_o;
  select id into m_m from public.members where workspace_id = ws and user_id = u_m;
  select id into m_b from public.members where workspace_id = ws and user_id = u_b;
  select id into m_x from public.members where workspace_id = ws2 and user_id = u_x;
  insert into public.workspace_roles (workspace_id, key, permissions)
  values (ws, 'biller', array['issueInvoices']) returning id into r_b;
  insert into public.workspace_role_members (workspace_id, role_id, member_id) values (ws, r_b, m_b);
  -- Two reimbursements of the same amount, reported as made.
  insert into public.outgoing_payments (workspace_id, payee_kind, payee_member_id, currency, amount_cents,
                                        method, reported_paid_on, reference, state, actor_member_id, request_id)
  values (ws, 'member', m_m, 'CHF', 5000, 'bank_transfer', date '2026-10-19', 'R-1', 'reported', m_o,
          '00000000-0000-4000-8000-0000064500f1'),
         (ws, 'member', m_m, 'CHF', 5000, 'bank_transfer', date '2026-10-19', 'R-2', 'reported', m_o,
          '00000000-0000-4000-8000-0000064500f2');
  insert into public.bank_statements (workspace_id, format, account, currency, source_sha256, period_from, period_to)
  values (ws, 'camt053', 'CH9300762011623852957', 'CHF', repeat('c', 64), '2026-10-01', '2026-10-31')
  returning id into st;
  insert into public.bank_statements (workspace_id, format, account, currency, source_sha256, period_from, period_to)
  values (ws2, 'camt053', 'CH9300762011623852957', 'CHF', repeat('d', 64), '2026-10-01', '2026-10-31')
  returning id into st2;
  insert into public.bank_statement_lines (statement_id, workspace_id, account, position, booking_date, value_date,
                                           amount_cents, currency, transaction_id, reference, line_hash)
  values (st, ws, 'CH9300762011623852957', 1, '2026-10-20', '2026-10-21', -5000, 'CHF', 'T1', 'RF18OUT1', repeat('1', 64)),
         (st, ws, 'CH9300762011623852957', 2, '2026-10-20', '2026-10-21', 3000, 'CHF', 'T2', '', repeat('2', 64)),
         (st, ws, 'CH9300762011623852957', 3, '2026-10-22', '2026-10-22', -5000, 'CHF', 'T3', '', repeat('3', 64)),
         (st2, ws2, 'CH9300762011623852957', 1, '2026-10-20', '2026-10-21', -5000, 'CHF', 'T1', '', repeat('4', 64));
  perform set_config('un.ws', ws::text, false);
  perform set_config('un.m_o', m_o::text, false);
  perform set_config('un.l1', (select id from public.bank_statement_lines where workspace_id = ws and position = 1)::text, false);
  perform set_config('un.l2', (select id from public.bank_statement_lines where workspace_id = ws and position = 2)::text, false);
  perform set_config('un.l3', (select id from public.bank_statement_lines where workspace_id = ws and position = 3)::text, false);
  perform set_config('un.lx', (select id from public.bank_statement_lines where workspace_id = ws2)::text, false);
  perform set_config('un.p1', (select id from public.outgoing_payments where reference = 'R-1')::text, false);
  perform set_config('un.p2', (select id from public.outgoing_payments where reference = 'R-2')::text, false);
  perform set_config('un.owner', u_o::text, false);
  perform set_config('un.member', u_m::text, false);
  perform set_config('un.biller', u_b::text, false);
  perform set_config('un.stranger', u_x::text, false);
end
$seed$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create or replace function pg_temp.v(p_key text) returns text language sql as $v$
  select current_setting('un.' || p_key)
$v$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- p_sql's jsonb answer as p_who, or {"refused": sqlstate}.
create or replace function pg_temp.as_json(p_who text, p_sql text, p_delegated boolean default false)
returns jsonb language plpgsql as $j$
declare v jsonb;
begin
  perform set_config('request.jwt.claims',
    (jsonb_build_object('sub', current_setting('un.' || p_who), 'role', 'authenticated')
     || case when p_delegated then '{"client_id": "assistant"}'::jsonb else '{}'::jsonb end)::text, true);
  execute p_sql into v;
  return v;
exception when others then
  return jsonb_build_object('refused', sqlstate, 'message', sqlerrm);
end
$j$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- p_sql's first value as p_who under the authenticated role (grants, RLS).
create or replace function pg_temp.as_role(p_who text, p_sql text) returns text
language plpgsql as $j$
declare v text;
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('un.' || p_who), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  execute p_sql into v;
  reset role;
  return v;
exception when others then
  reset role;
  return sqlstate;
end
$j$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- Undoing p_line as p_who with p_reason under request p_request.
create or replace function pg_temp.undo(p_who text, p_line text, p_reason text, p_request text,
                                        p_delegated boolean default false) returns jsonb
language sql as $u$
  select pg_temp.as_json(p_who, format('select public.unreconcile_bank_line_out_v1(%L, %L, %L)',
    p_line, p_reason, p_request), p_delegated)
$u$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select pg_temp.seed();

-- The wrong link: L1 reconciles P1.
select is(pg_temp.as_json('owner', format('select public.reconcile_bank_line_out_v1(%L, %L)',
            pg_temp.v('l1'), pg_temp.v('p1'))) ->> 'status', 'reconciled',
          'positive control: the owner reconciles L1 with P1');
select is((select state || '/' || booking_date || '/' || value_date from public.outgoing_payments
            where id = pg_temp.v('p1')::uuid), 'reconciled/2026-10-20/2026-10-21',
          'P1 took the bank''s booking and value days');

-- Who may not.
select is(pg_temp.undo('member', pg_temp.v('l1'), 'wrong one', '00000000-0000-4000-8000-0000064500e1') ->> 'refused',
          '42501', 'a plain member may not undo a reconciliation');
select is(pg_temp.undo('biller', pg_temp.v('l1'), 'wrong one', '00000000-0000-4000-8000-0000064500e1') ->> 'refused',
          '42501', 'a biller (issueInvoices alone) may not either: undoing needs the right that reconciles');
select is(pg_temp.undo('stranger', pg_temp.v('l1'), 'wrong one', '00000000-0000-4000-8000-0000064500e1') ->> 'refused',
          '42501', 'the owner of another space may not');
select is(pg_temp.undo('owner', pg_temp.v('l1'), 'wrong one', '00000000-0000-4000-8000-0000064500e1', true) ->> 'refused',
          '42501', 'an assistant''s delegated token may not');
select is(pg_temp.undo('owner', gen_random_uuid()::text, 'wrong one', '00000000-0000-4000-8000-0000064500e1') ->> 'refused',
          '42501', 'an unknown line reads as a refusal');
select is(pg_temp.undo('stranger', pg_temp.v('lx'), 'wrong one', '00000000-0000-4000-8000-0000064500e9') ->> 'refused',
          '0A000', 'in a space with bank statements off, even its owner is refused');
select is(pg_temp.undo('owner', pg_temp.v('l1'), '   ', '00000000-0000-4000-8000-0000064500e1') ->> 'refused',
          '22023', 'a reconciliation is not undone without a reason');
select is(pg_temp.undo('owner', pg_temp.v('l2'), 'wrong one', '00000000-0000-4000-8000-0000064500e2') ->> 'refused',
          'DKB02', 'money in is not undone here');
select is((select outgoing_payment_id::text from public.bank_statement_lines where id = pg_temp.v('l1')::uuid),
          pg_temp.v('p1'), 'after every refusal L1 still names P1');
select is((select count(*)::int from public.bank_line_unreconciliations), 0, 'and nothing is on record');

-- Undone.
select set_config('un.r1', pg_temp.undo('owner', pg_temp.v('l1'), '  Two reimbursements of 50: the wrong one  ',
                                        '00000000-0000-4000-8000-0000064500e1')::text, true);
select is(current_setting('un.r1')::jsonb ->> 'status', 'open', 'the owner undoes it: L1 is open again');
select is(current_setting('un.r1')::jsonb ->> 'outgoing_payment_id', pg_temp.v('p1'), 'the answer names the payment let go');
select is((select coalesce(outgoing_payment_id::text, '-') || '/' || coalesce(matched_by_member_id::text, '-') || '/'
                  || coalesce(matched_at::text, '-') || '/' || state || '/' || value_date || '/' || reference
             from public.bank_statement_lines where id = pg_temp.v('l1')::uuid),
          '-/-/-/open/2026-10-21/RF18OUT1', 'L1 names no payment and nobody matched it; its bank facts are kept');
select is((select state || '/' || coalesce(booking_date::text, '-') || '/' || coalesce(value_date::text, '-') || '/'
                  || reported_paid_on || '/' || amount_cents || '/' || reference
             from public.outgoing_payments where id = pg_temp.v('p1')::uuid),
          'reported/-/-/2026-10-19/5000/R-1', 'P1 is reported again with no bank days; what was reported is unchanged');
select is((select line_id::text || '/' || outgoing_payment_id || '/' || reconciled_by_member_id || '/'
                  || (reconciled_at is not null) || '/' || booking_date || '/' || value_date || '/' || reason || '/'
                  || actor_member_id || '/' || (id::text = current_setting('un.r1')::jsonb ->> 'unreconciliation_id')
             from public.bank_line_unreconciliations),
          pg_temp.v('l1') || '/' || pg_temp.v('p1') || '/' || pg_temp.v('m_o') || '/true/2026-10-20/2026-10-21/'
            || 'Two reimbursements of 50: the wrong one/' || pg_temp.v('m_o') || '/true',
          'one record keeps what the reconciliation was, why it was undone and who undid it');

-- Exactly once.
select is(pg_temp.undo('owner', pg_temp.v('l1'), 'again', '00000000-0000-4000-8000-0000064500e1') ->> 'unreconciliation_id',
          current_setting('un.r1')::jsonb ->> 'unreconciliation_id', 'the same request answers what it answered');
select is(pg_temp.undo('owner', pg_temp.v('l1'), 'again', '00000000-0000-4000-8000-0000064500e3') ->> 'refused',
          'DKB01', 'a second undoing is refused: the movement reconciles nothing any more');
select is(pg_temp.undo('owner', pg_temp.v('l3'), 'other', '00000000-0000-4000-8000-0000064500e1') ->> 'refused',
          '22023', 'a request id already used for another line is refused');
select is((select count(*)::int from public.bank_line_unreconciliations), 1, 'still exactly one record');

-- The right link, and it holds.
select is(pg_temp.as_json('owner', format('select public.reconcile_bank_line_out_v1(%L, %L)',
            pg_temp.v('l1'), pg_temp.v('p2'))) ->> 'status', 'reconciled',
          'L1 reconciles P2, the right one');
select is((select string_agg(reference || ':' || state, ',' order by reference) from public.outgoing_payments
            where workspace_id = pg_temp.v('ws')::uuid), 'R-1:reported,R-2:reconciled',
          'P1 stays reported, P2 is reconciled');
select throws_ok(format($t$update public.outgoing_payments set state = 'reported' where id = %L$t$, pg_temp.v('p2')),
          'P0001', null, 'nothing moves P2 back to reported while L1 names it');

-- Who reads the record, and nobody writes it.
select is(pg_temp.as_role('owner', 'select count(*)::text from public.bank_line_unreconciliations'), '1',
          'the owner reads the record');
select is(pg_temp.as_role('member', 'select count(*)::text from public.bank_line_unreconciliations'), '0',
          'a plain member reads none');
select is(pg_temp.as_role('stranger', 'select count(*)::text from public.bank_line_unreconciliations'), '0',
          'the owner of another space reads none');
select is(pg_temp.as_role('owner', 'with d as (delete from public.bank_line_unreconciliations returning 1) select count(*)::text from d'),
          '42501', 'the owner may not delete the record');
select is(pg_temp.as_role('owner', $s$with u as (update public.bank_line_unreconciliations set reason = 'x' returning 1) select count(*)::text from u$s$),
          '42501', 'nor change it');
select ok(not has_function_privilege('anon', 'public.unreconcile_bank_line_out_v1(uuid, text, uuid)', 'execute'),
          'the command is not anon''s');

select * from finish();
rollback;
