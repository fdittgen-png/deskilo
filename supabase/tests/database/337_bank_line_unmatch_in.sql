-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2380 (0650) -- a confirmed match of money in is undone once, by a person
-- with the right that matches, with a reason, on the record, and only the
-- match: the bank payment credit stays and a new match reuses it.
-- The owner matches L1 (+100.00) to I1, the wrong invoice. A plain member, a
-- reader of the finances (viewFinances alone), the owner of another space, an
-- assistant's token and an unknown line are refused (42501); the other space,
-- whose flag is off, is refused for its own owner (0A000); no reason and a
-- request id reused for another line are refused (22023); money out is
-- refused (DKB02), a movement that settles nothing and a match still
-- awaiting its validation are refused (DKB01). The slice is refused outside
-- its edges, each with its own code: a credit note minted (DKB04), a match
-- that belongs to a settlement (DKB04), a second payment on the invoice
-- (DKB05), a match dated inside a closed period of the books (DKB06), which
-- the books' guard also refuses on a plain DELETE.
-- Undone: I1 is open again (no match rows), L1 keeps its payment credit and
-- reads 'recorded', no ledger row is added or removed, the original payment
-- event stays, one record keeps what the match was and why it is undone, one
-- invoice_payment_reversed event is linked to both. The same request again
-- answers the same and adds nothing. L1 then matches again and reuses the
-- same credit. Other matches stay. The record is read by the statements'
-- readers only and written by nobody; the command is not anon's.
begin;
select plan(50);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000065000a1';
  u_b uuid := '00000000-0000-4000-8000-0000065000a2';
  u_r uuid := '00000000-0000-4000-8000-0000065000a3';
  u_p uuid := '00000000-0000-4000-8000-0000065000a4';
  u_x uuid := '00000000-0000-4000-8000-0000065000a5';
  ws uuid; ws2 uuid; m_o uuid; m_b uuid; m_r uuid; m_p uuid; m_x uuid;
  r_b uuid; r_r uuid; st uuid; st2 uuid; i int;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'unmatch-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_b, u_r, u_p, u_x]) u;
  -- The flag and every parent on (moneyTab > invoicing > bankImport).
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Undo money in', 'FR', 'EUR', 'Europe/Paris', u_o,
          '{"moneyTab": true, "invoicing": true, "bankImport": true, "customRoles": true}'::jsonb)
  returning id into ws;
  -- Another space, the flag off.
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Paper undo in', 'FR', 'EUR', 'Europe/Paris', u_x,
          '{"moneyTab": true, "invoicing": true, "bankImport": false}'::jsonb)
  returning id into ws2;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, status, joined_at)
  values (ws, u_o, true, true, 'active', '2026-01-01'), (ws, u_b, false, false, 'active', '2026-01-01'),
         (ws, u_r, false, false, 'active', '2026-01-01'), (ws, u_p, false, false, 'active', '2026-01-01'),
         (ws2, u_x, true, true, 'active', '2026-01-01');
  select id into m_o from public.members where workspace_id = ws and user_id = u_o;
  select id into m_b from public.members where workspace_id = ws and user_id = u_b;
  select id into m_r from public.members where workspace_id = ws and user_id = u_r;
  select id into m_p from public.members where workspace_id = ws and user_id = u_p;
  select id into m_x from public.members where workspace_id = ws2 and user_id = u_x;
  insert into public.workspace_roles (workspace_id, key, permissions)
  values (ws, 'biller', array['issueInvoices']) returning id into r_b;
  insert into public.workspace_role_members (workspace_id, role_id, member_id) values (ws, r_b, m_b);
  insert into public.workspace_roles (workspace_id, key, permissions)
  values (ws, 'reader', array['viewFinances']) returning id into r_r;
  insert into public.workspace_role_members (workspace_id, role_id, member_id) values (ws, r_r, m_r);
  -- Eight invoices of the payer (no period: nothing else constrains them).
  for i in 1..8 loop
    insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                                 total_cents, currency, member_name, workspace_name, issuer_name, signature)
    values (ws, m_p, m_o, 'UM-' || i, 'Invoice ' || i, '[]'::jsonb,
            case i when 2 then 8000 when 3 then 20000 else 10000 end, 'EUR', 'Payer', 'Undo money in', 'Owner', 'sig');
  end loop;
  insert into public.bank_statements (workspace_id, format, account, currency, source_sha256, period_from, period_to)
  values (ws, 'camt053', 'FR7630006000011234567890189', 'EUR', repeat('e', 64), '2026-10-01', '2026-10-31')
  returning id into st;
  insert into public.bank_statements (workspace_id, format, account, currency, source_sha256, period_from, period_to)
  values (ws2, 'camt053', 'FR7630006000011234567890189', 'EUR', repeat('f', 64), '2026-10-01', '2026-10-31')
  returning id into st2;
  -- L1..L7 money in, L8 open money in, L9 money out; position = the number.
  insert into public.bank_statement_lines (statement_id, workspace_id, account, position, booking_date, value_date,
                                           amount_cents, currency, transaction_id, reference, line_hash)
  select st, ws, 'FR7630006000011234567890189', n, '2026-10-20', '2026-10-21',
         case n when 3 then 10000 when 9 then -5000 when 10 then 5000 else 10000 end, 'EUR',
         'TI' || n, 'RF' || n, lpad(n::text, 64, '1')
    from generate_series(1, 10) n;
  insert into public.bank_statement_lines (statement_id, workspace_id, account, position, booking_date, value_date,
                                           amount_cents, currency, transaction_id, reference, line_hash)
  values (st2, ws2, 'FR7630006000011234567890189', 1, '2026-10-20', '2026-10-21', 10000, 'EUR', 'TX1', '', repeat('9', 64));
  perform set_config('um.ws', ws::text, false);
  perform set_config('um.m_o', m_o::text, false);
  perform set_config('um.m_p', m_p::text, false);
  for i in 1..10 loop
    perform set_config('um.l' || i, (select id from public.bank_statement_lines where workspace_id = ws and position = i)::text, false);
  end loop;
  for i in 1..8 loop
    perform set_config('um.i' || i, (select id from public.invoices where workspace_id = ws and number = 'UM-' || i)::text, false);
  end loop;
  perform set_config('um.lx', (select id from public.bank_statement_lines where workspace_id = ws2)::text, false);
  perform set_config('um.owner', u_o::text, false);
  perform set_config('um.biller', u_b::text, false);
  perform set_config('um.reader', u_r::text, false);
  perform set_config('um.payer', u_p::text, false);
  perform set_config('um.stranger', u_x::text, false);
end
$seed$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create or replace function pg_temp.v(p_key text) returns text language sql as $v$
  select current_setting('um.' || p_key)
$v$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- p_sql's jsonb answer as p_who, or {"refused": sqlstate}.
create or replace function pg_temp.as_json(p_who text, p_sql text, p_delegated boolean default false)
returns jsonb language plpgsql as $j$
declare v jsonb;
begin
  perform set_config('request.jwt.claims',
    (jsonb_build_object('sub', current_setting('um.' || p_who), 'role', 'authenticated')
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
    json_build_object('sub', current_setting('um.' || p_who), 'role', 'authenticated')::text, true);
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

-- The owner matches line p_line to invoice p_invoice.
create or replace function pg_temp.match(p_line text, p_invoice text, p_resolution text default 'exact',
                                         p_note text default '') returns jsonb
language sql as $m$
  select pg_temp.as_json('owner', format('select public.match_bank_line_v1(%L, %L, %L, %L)',
    pg_temp.v(p_line), pg_temp.v(p_invoice), p_resolution, p_note))
$m$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- Undoing p_line as p_who with p_reason under request p_request.
create or replace function pg_temp.undo(p_who text, p_line text, p_reason text, p_request text,
                                        p_delegated boolean default false) returns jsonb
language sql as $u$
  select pg_temp.as_json(p_who, format('select public.unmatch_bank_line_in_v1(%L, %L, %L)',
    p_line, p_reason, p_request), p_delegated)
$u$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select pg_temp.seed();

-- The matches: L1->I1 (the wrong one), L2->I2 as a credit note, L3->I3 and
-- L10->I3 (two payments of a part-paid invoice), L4->I4, L6->I6, L7->I7.
select is(pg_temp.match('l1', 'i1') ->> 'status', 'matched', 'positive control: L1 is matched to I1');
select is(pg_temp.match('l2', 'i2', 'over_credit_note', 'credit note') ->> 'status', 'matched',
          'L2 is matched to I2 with a credit note minted');
select pg_temp.match('l3', 'i3', 'under_accepted', 'first part');
select pg_temp.match('l10', 'i3', 'under_accepted', 'second part');
select pg_temp.match('l4', 'i4');
select pg_temp.match('l6', 'i6');
select pg_temp.match('l7', 'i7');
-- I6 was regrouped into I7 (a settlement): the invoice rows are immutable but for
-- this link, written past the guard as the settlement does.
alter table public.invoices disable trigger user;
update public.invoices set settled_by_invoice_id = pg_temp.v('i7')::uuid where id = pg_temp.v('i6')::uuid;
alter table public.invoices enable trigger user;

select set_config('um.ledger_before', (select count(*)::text from public.ledger_entries
                                         where workspace_id = pg_temp.v('ws')::uuid), true);
select set_config('um.credit_l1', (select payment_ledger_id::text from public.bank_statement_lines
                                    where id = pg_temp.v('l1')::uuid), true);

-- Who may not.
select is(pg_temp.as_json('payer', format('select public.unmatch_bank_line_in_v1(%L, %L, %L)',
            pg_temp.v('l1'), 'wrong invoice', '00000000-0000-4000-8000-0000065000e1')) ->> 'refused',
          '42501', 'a plain member may not undo a match');
select is(pg_temp.as_json('reader', format('select public.unmatch_bank_line_in_v1(%L, %L, %L)',
            pg_temp.v('l1'), 'wrong invoice', '00000000-0000-4000-8000-0000065000e1')) ->> 'refused',
          '42501', 'a reader of the finances (viewFinances alone) may not: undoing needs the right that matches');
select is(pg_temp.as_json('stranger', format('select public.unmatch_bank_line_in_v1(%L, %L, %L)',
            pg_temp.v('l1'), 'wrong invoice', '00000000-0000-4000-8000-0000065000e1')) ->> 'refused',
          '42501', 'the owner of another space may not');
select is(pg_temp.as_json('owner', format('select public.unmatch_bank_line_in_v1(%L, %L, %L)',
            pg_temp.v('l1'), 'wrong invoice', '00000000-0000-4000-8000-0000065000e1'), true) ->> 'refused',
          '42501', 'an assistant''s delegated token may not');
select is(pg_temp.undo('owner', gen_random_uuid()::text, 'wrong invoice', '00000000-0000-4000-8000-0000065000e1') ->> 'refused',
          '42501', 'an unknown line reads as a refusal');
select is(pg_temp.undo('stranger', pg_temp.v('lx'), 'wrong invoice', '00000000-0000-4000-8000-0000065000e9') ->> 'refused',
          '0A000', 'in a space with bank statements off, even its owner is refused');
select is(pg_temp.undo('owner', pg_temp.v('l1'), '   ', '00000000-0000-4000-8000-0000065000e1') ->> 'refused',
          '22023', 'a match is not undone without a reason');
select is(pg_temp.undo('owner', pg_temp.v('l9'), 'wrong', '00000000-0000-4000-8000-0000065000e2') ->> 'refused',
          'DKB02', 'money out is not undone here');
select is(pg_temp.undo('owner', pg_temp.v('l8'), 'wrong', '00000000-0000-4000-8000-0000065000e3') ->> 'refused',
          'DKB01', 'a movement that settles no invoice has nothing to undo');
select is((select count(*)::int from public.bank_line_unmatches), 0, 'after every refusal nothing is on record');

-- The edges of the slice.
select is(pg_temp.undo('owner', pg_temp.v('l2'), 'wrong', '00000000-0000-4000-8000-0000065000e4') ->> 'refused',
          'DKB04', 'a match that minted a credit note is refused');
select is(pg_temp.undo('owner', pg_temp.v('l6'), 'wrong', '00000000-0000-4000-8000-0000065000e5') ->> 'refused',
          'DKB04', 'a match that belongs to a settlement is refused');
select is(pg_temp.undo('owner', pg_temp.v('l3'), 'wrong', '00000000-0000-4000-8000-0000065000e6') ->> 'refused',
          'DKB05', 'a payment of an invoice that has another is refused');
select is((select count(*)::int from public.invoice_match_payments
            where invoice_id = pg_temp.v('i3')::uuid), 2, 'the part-paid invoice keeps both payments');
select is((select resolution || '/' || (credit_ledger_id is not null) from public.invoice_matches
            where invoice_id = pg_temp.v('i2')::uuid), 'over_credit_note/true',
          'and the credit note is still there');

-- Undone.
select set_config('um.r1', pg_temp.undo('owner', pg_temp.v('l1'), '  The wrong invoice: it was I2  ',
                                        '00000000-0000-4000-8000-0000065000e7')::text, true);
select is(current_setting('um.r1')::jsonb ->> 'status', 'recorded',
          'the owner undoes it: L1 reads recorded, the money is still there');
select is(current_setting('um.r1')::jsonb ->> 'payment_ledger_id', current_setting('um.credit_l1'),
          'the answer names the payment credit, which L1 keeps');
select is((select count(*)::int from public.invoice_matches where invoice_id = pg_temp.v('i1')::uuid)
          + (select count(*)::int from public.invoice_match_payments where invoice_id = pg_temp.v('i1')::uuid),
          0, 'I1 has no match rows any more: it reads open again');
select is((select coalesce(payment_ledger_id::text, '-') || '/' || coalesce(invoice_id::text, '-') || '/'
                  || coalesce(matched_by_member_id::text, '-') || '/' || state || '/' || reference
             from public.bank_statement_lines where id = pg_temp.v('l1')::uuid),
          current_setting('um.credit_l1') || '/-/-/open/RF1',
          'L1 keeps its credit, names no invoice and nobody matched it; its bank facts are kept');
select is((select count(*)::text from public.ledger_entries where workspace_id = pg_temp.v('ws')::uuid),
          current_setting('um.ledger_before'), 'no ledger row was added or removed');
select is((select count(*)::int from public.events
            where type = 'invoice_payment' and payload ->> 'invoice_id' = pg_temp.v('i1')
              and status = 'confirmed'), 1, 'the original payment event stays, confirmed');
select is((select count(*)::int from public.events
            where type = 'invoice_payment' and workspace_id = pg_temp.v('ws')::uuid), 7,
          'and the undoing added no payment event (seven matches, seven events)');
select is((select line_id::text || '/' || invoice_id || '/' || payment_ledger_id || '/' || amount_cents || '/'
                  || resolution || '/' || matched_by_member_id || '/' || (matched_at is not null) || '/'
                  || reason || '/' || actor_member_id || '/' || (id::text = current_setting('um.r1')::jsonb ->> 'unmatch_id')
             from public.bank_line_unmatches),
          pg_temp.v('l1') || '/' || pg_temp.v('i1') || '/' || current_setting('um.credit_l1') || '/10000/exact/'
            || pg_temp.v('m_o') || '/true/The wrong invoice: it was I2/' || pg_temp.v('m_o') || '/true',
          'one record keeps what the match was, why it was undone and who undid it');
select is((select e.status || '/' || (e.payload ->> 'unmatch_id' = u.id::text) || '/'
                  || (e.payload ->> 'original_event_id' = u.original_event_id::text) || '/'
                  || (u.reversal_event_id = e.id) || '/' || e.subject_member_id::text
             from public.bank_line_unmatches u join public.events e on e.id = u.reversal_event_id
            where e.type = 'invoice_payment_reversed'),
          'applied/true/true/true/' || pg_temp.v('m_p'),
          'one applied invoice_payment_reversed event is linked to the original event and the record');

-- Exactly once.
select is(pg_temp.undo('owner', pg_temp.v('l1'), 'again', '00000000-0000-4000-8000-0000065000e7') ->> 'unmatch_id',
          current_setting('um.r1')::jsonb ->> 'unmatch_id', 'the same request answers what it answered');
select is(pg_temp.undo('owner', pg_temp.v('l1'), 'again', '00000000-0000-4000-8000-0000065000e8') ->> 'refused',
          'DKB01', 'a second undoing is refused: the movement settles nothing any more');
select is(pg_temp.undo('owner', pg_temp.v('l4'), 'other', '00000000-0000-4000-8000-0000065000e7') ->> 'refused',
          '22023', 'a request id already used for another line is refused');
select is((select count(*)::int from public.bank_line_unmatches)
          + (select count(*)::int from public.events where type = 'invoice_payment_reversed'),
          2, 'still exactly one record and one event');

-- A new match reuses the credit.
select is(pg_temp.match('l1', 'i1') ->> 'status', 'matched', 'L1 matches I1 again');
select is((select payment_ledger_id::text from public.bank_statement_lines where id = pg_temp.v('l1')::uuid),
          current_setting('um.credit_l1'), 'with the SAME payment credit');
select is((select count(*)::text from public.ledger_entries where workspace_id = pg_temp.v('ws')::uuid),
          current_setting('um.ledger_before'), 'and no second credit was minted');
select is((select count(*)::int from public.invoice_matches where invoice_id = any(array[
            pg_temp.v('i2')::uuid, pg_temp.v('i3')::uuid, pg_temp.v('i4')::uuid, pg_temp.v('i7')::uuid])), 4,
          'the other matches were not touched');

-- The record and the event type.
select is(pg_temp.as_role('owner', 'select count(*)::text from public.bank_line_unmatches'), '1',
          'the owner reads the record');
select is(pg_temp.as_role('reader', 'select count(*)::text from public.bank_line_unmatches'), '1',
          'a reader of the finances reads it');
select is(pg_temp.as_role('payer', 'select count(*)::text from public.bank_line_unmatches'), '0',
          'the payer, a plain member, reads none');
select is(pg_temp.as_role('stranger', 'select count(*)::text from public.bank_line_unmatches'), '0',
          'the owner of another space reads none');
select is(pg_temp.as_role('owner', 'with d as (delete from public.bank_line_unmatches returning 1) select count(*)::text from d'),
          '42501', 'the owner may not delete the record');
select is(pg_temp.as_role('owner', $s$with u as (update public.bank_line_unmatches set reason = 'x' returning 1) select count(*)::text from u$s$),
          '42501', 'nor change it');
select ok(not has_function_privilege('anon', 'public.unmatch_bank_line_in_v1(uuid, text, uuid)', 'execute'),
          'the command is not anon''s');
select is(public.event_type_view_permissions('invoice_payment_reversed'), array['viewFinances', 'issueInvoices'],
          'the undoing is read by whoever reads the payment');
select throws_ok(format($t$insert into public.validation_policies (workspace_id, event_type) values (%L, 'invoice_payment_reversed')$t$,
          pg_temp.v('ws')), '23514', null, 'the undoing is a record: it can have no validation policy');

-- The locks and the recheck: the line, then the invoice, then its links.
select ok(prosrc ~ ('bank_statement_lines where id = p_line_id for update[\s\S]*'
                  || 'from public.invoices\s+where id = v_line.invoice_id and workspace_id = v_ws for update[\s\S]*'
                  || 'from public.invoice_matches where invoice_id = v_invoice.id for update[\s\S]*'
                  || 'from public.invoice_match_payments\s+where invoice_id = v_invoice.id'
                  || ' and payment_ledger_id = v_line.payment_ledger_id for update'),
          'the line is locked first, then the invoice, then its links, and the state is read again under them')
  from pg_proc where oid = 'public.unmatch_bank_line_in_v1(uuid, text, uuid)'::regprocedure;
-- A match decided between the read and the lock reads as one that is gone.
delete from public.invoice_match_payments where invoice_id = pg_temp.v('i7')::uuid;
select is(pg_temp.undo('owner', pg_temp.v('l7'), 'gone meanwhile', '00000000-0000-4000-8000-0000065000ea') ->> 'refused',
          'DKB01', 'a match that went before the lock is refused as decided meanwhile');

-- A match still awaiting its validation is rejected there, not undone here.
insert into public.validation_policies (workspace_id, event_type) values (pg_temp.v('ws')::uuid, 'invoice_payment');
select is(pg_temp.match('l8', 'i8') ->> 'status', 'pending', 'with a rule for payments, L8 is matched pending');
select is(pg_temp.undo('owner', pg_temp.v('l8'), 'wrong', '00000000-0000-4000-8000-0000065000eb') ->> 'refused',
          'DKB01', 'a pending match is refused: reject it in the validations');

-- A closed period of the books: refused by the command and by the guard itself.
insert into public.book_periods (workspace_id, period_from, period_to, reason)
values (pg_temp.v('ws')::uuid, current_date - 5, current_date + 5, 'owner');
select is(pg_temp.undo('owner', pg_temp.v('l4'), 'wrong', '00000000-0000-4000-8000-0000065000ec') ->> 'refused',
          'DKB06', 'a match dated inside a closed period is refused');
select throws_ok(format($t$delete from public.invoice_matches where invoice_id = %L$t$, pg_temp.v('i4')),
          'P0001', null, 'the books'' guard refuses a plain DELETE of a confirmed match in a closed period');
select lives_ok(format($t$delete from public.invoice_matches where invoice_id = %L$t$, pg_temp.v('i8')),
          'a PENDING match is still removed by the rejection path, closed period or not');

select * from finish();
rollback;
