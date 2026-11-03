-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2380 (0659) -- the booking dates of a validated part payment, through the
-- real decision path (respond_to_event). With a rule for payments, L3 pays
-- the first part of I3 (200.00) and L10 the second; each is submitted 40 days
-- ago (the submission time is moved back, the decision itself is real, by a
-- second admin, today). 0101 books the FIRST payment at its submission and the
-- ADDITIONAL one at its confirmation. The 40-days-ago period is then closed.
-- Undoing L10 would restate the match from L3, booked in that closed period:
-- refused (DKB06). Undoing L3, booked in that closed period: refused (DKB06).
-- Nothing changes.
begin;
select plan(5);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000065900a1';
  u_b uuid := '00000000-0000-4000-8000-0000065900a2';
  u_r uuid := '00000000-0000-4000-8000-0000065900a3';
  u_p uuid := '00000000-0000-4000-8000-0000065900a4';
  u_x uuid := '00000000-0000-4000-8000-0000065900a5';
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
  values ('Undo booked payment', 'FR', 'EUR', 'Europe/Paris', u_o,
          '{"moneyTab": true, "invoicing": true, "bankImport": true, "customRoles": true}'::jsonb)
  returning id into ws;
  -- Another space, the flag off.
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Paper undo booked', 'FR', 'EUR', 'Europe/Paris', u_x,
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
  -- Ten invoices of the payer (no period: nothing else constrains them).
  for i in 1..10 loop
    insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                                 total_cents, currency, member_name, workspace_name, issuer_name, signature)
    values (ws, m_p, m_o, 'UM-' || i, 'Invoice ' || i, '[]'::jsonb,
            case i when 2 then 8000 when 3 then 20000 else 10000 end, 'EUR', 'Payer', 'Undo booked payment', 'Owner', 'sig');
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
  for i in 1..10 loop
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
insert into public.validation_policies (workspace_id, event_type) values (pg_temp.v('ws')::uuid, 'invoice_payment');
-- A second admin decides: the one who matched may not validate their own match.
update public.members set is_admin = true
 where workspace_id = pg_temp.v('ws')::uuid and user_id = pg_temp.v('biller')::uuid;

-- The first part: submitted 40 days ago, confirmed today.
select pg_temp.match('l3', 'i3', 'under_accepted', 'first part');
update public.invoice_match_payments set matched_at = now() - interval '40 days' where invoice_id = pg_temp.v('i3')::uuid;
update public.invoice_matches set matched_at = now() - interval '40 days' where invoice_id = pg_temp.v('i3')::uuid;
select pg_temp.as_json('biller', format($s$select jsonb_build_object('r', public.respond_to_event(%L, true)::text)$s$,
  (select event_id from public.invoice_match_payments where invoice_id = pg_temp.v('i3')::uuid)));
select ok((select status = 'confirmed' and matched_at::date = current_date - 40 from public.invoice_matches
            where invoice_id = pg_temp.v('i3')::uuid),
          'positive control: the confirmed first payment keeps its submission date');

-- The second part: submitted 40 days ago, confirmed today.
select pg_temp.match('l10', 'i3', 'under_accepted', 'second part');
update public.invoice_match_payments set matched_at = now() - interval '40 days'
 where payment_ledger_id = (select payment_ledger_id from public.bank_statement_lines where id = pg_temp.v('l10')::uuid);
select pg_temp.as_json('biller', format($s$select jsonb_build_object('r', public.respond_to_event(%L, true)::text)$s$,
  (select event_id from public.invoice_match_payments
    where payment_ledger_id = (select payment_ledger_id from public.bank_statement_lines where id = pg_temp.v('l10')::uuid))));
select ok((select paid_cents = 15000 and matched_at::date = current_date from public.invoice_matches
            where invoice_id = pg_temp.v('i3')::uuid),
          'positive control: the confirmed additional payment dates the match today');

insert into public.book_periods (workspace_id, period_from, period_to, reason)
values (pg_temp.v('ws')::uuid, current_date - 45, current_date - 35, 'owner');

select is(pg_temp.undo('owner', pg_temp.v('l10'), 'wrong', '00000000-0000-4000-8000-0000065900e1') ->> 'refused',
          'DKB06', 'undoing the additional payment would rebook the match on the first, inside the closed period: refused');
select is(pg_temp.undo('owner', pg_temp.v('l3'), 'wrong', '00000000-0000-4000-8000-0000065900e2') ->> 'refused',
          'DKB06', 'the first payment is booked inside the closed period, whenever it was confirmed: refused');
select is((select paid_cents from public.invoice_matches where invoice_id = pg_temp.v('i3')::uuid), 15000,
          'nothing was undone');

select * from finish();
rollback;
