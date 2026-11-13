-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3838 (0750, L1 of #3787): the match history. The statement of a past day
-- reads a match as it stood then: a day between a match's creation and its
-- approval says "awaiting approval" with the full amount still due, the day
-- after says paid; a released and an undone match are seen as such before
-- and after. Today's state read from the history equals today's rows,
-- across every business. The history is never edited, and nobody reads it
-- directly. Rolled back.
begin;
select plan(9);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000038380a1';
  u_1 uuid := '00000000-0000-4000-8000-0000038380a2';
  ws uuid; m_o uuid; m_1 uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'history-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_1]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('History', 'FR', 'EUR', 'Europe/Paris', u_o, '{"moneyTab": true, "invoicing": true}'::jsonb)
  returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, status, joined_at)
  values (ws, u_o, true, true, 'active', '2026-01-01'), (ws, u_1, false, false, 'active', '2026-01-01');
  select id into m_o from public.members where workspace_id = ws and user_id = u_o;
  select id into m_1 from public.members where workspace_id = ws and user_id = u_1;
  -- A: approved later; B: released; C: matched, then undone.
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name, signature)
  select ws, m_1, m_o, 'HI-' || n, 'One', '[]'::jsonb, 1000, 'EUR', 'One', 'History', 'Owner', 'sig'
    from unnest(array['A', 'B', 'C']) n;
  insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period)
  select ws, m_1, 'credit', 'payment', 1000, 'P' || n, '2026-09' from unnest(array['A', 'B', 'C']) n;
  perform set_config('hi.ws', ws::text, false);
  perform set_config('hi.m1', m_1::text, false);
  perform set_config('hi.owner', u_o::text, false);
end
$seed$;
select pg_temp.seed();
select set_config('TimeZone', 'Europe/Paris', true);

create or replace function pg_temp.id(p_kind text, p_name text) returns uuid language sql as $f$
  select case p_kind
    when 'inv' then (select id from public.invoices where workspace_id = current_setting('hi.ws')::uuid and number = p_name)
    else (select id from public.ledger_entries where workspace_id = current_setting('hi.ws')::uuid and description = p_name) end;
$f$;
create or replace function pg_temp.as_owner(p_sql text) returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('hi.owner'), 'role', 'authenticated')::text, true);
  set local role authenticated;
  execute p_sql into v;
  reset role;
  return v;
exception when others then
  reset role;
  return 'ERROR ' || sqlstate;
end
$f$;
-- One invoice's line of the statement as of a day: its state and still due,
-- or "settled" when it is not on the statement.
create or replace function pg_temp.line(p_number text, p_as_of date) returns text language sql as $f$
  select coalesce((
    select i ->> 'state' || ' ' || (i ->> 'still_due_cents')
      from jsonb_array_elements(pg_temp.as_owner(format('select public.customer_statement_v1(%L, %L, %L)::text',
             current_setting('hi.ws'), current_setting('hi.m1'), p_as_of))::jsonb -> 'currencies') c,
           jsonb_array_elements(c -> 'invoices') i
     where i ->> 'number' = p_number), 'settled');
$f$;
grant execute on all functions in schema pg_temp to authenticated;

-- Each payment is matched whole to its invoice, and each match waits for
-- an approval (the space has no policy of its own, so the wait is set
-- here, with the triggers on: the history records it as it would).
select pg_temp.as_owner(format('select public.match_invoice(%L, %L, ''exact'', ''a part'', 1000)::text',
  pg_temp.id('inv', 'HI-' || n), pg_temp.id('pay', 'P' || n)))
  from unnest(array['A', 'B', 'C']) n;
update public.invoice_matches set status = 'pending' where workspace_id = current_setting('hi.ws')::uuid;
update public.events set status = 'pending'
 where id in (select event_id from public.invoice_match_payments where workspace_id = current_setting('hi.ws')::uuid);
-- Everything so far happened ten days ago.
set local session_replication_role = replica;
update public.invoices set issued_at = now() - interval '10 days' where workspace_id = current_setting('hi.ws')::uuid;
update public.ledger_entries set created_at = now() - interval '10 days' where workspace_id = current_setting('hi.ws')::uuid;
update public.invoice_match_history set at = at - interval '10 days' where workspace_id = current_setting('hi.ws')::uuid;
set local session_replication_role = origin;

select is(pg_temp.line('HI-A', current_date - 5), 'awaiting_approval 1000',
  'the three matches were created pending ten days ago');

-- Today: A is approved, B released, C (approved) undone, each as its writer does it.
update public.events set status = 'confirmed'
 where id in (select event_id from public.invoice_match_payments where invoice_id in (pg_temp.id('inv', 'HI-A'), pg_temp.id('inv', 'HI-C')));
update public.invoice_matches set status = 'confirmed'
 where invoice_id in (pg_temp.id('inv', 'HI-A'), pg_temp.id('inv', 'HI-C'));
select public.release_invoice_payment((select event_id from public.invoice_match_payments
                                        where invoice_id = pg_temp.id('inv', 'HI-B')));
delete from public.invoice_match_payments where invoice_id = pg_temp.id('inv', 'HI-C');
delete from public.invoice_matches where invoice_id = pg_temp.id('inv', 'HI-C');

select is(pg_temp.line('HI-A', current_date - 1), 'awaiting_approval 1000',
  'a day between the match''s creation and its approval: awaiting approval, the full amount still due');
select is(pg_temp.line('HI-A', current_date), 'settled', 'the day of its approval: paid');
select is(pg_temp.line('HI-B', current_date - 1) || ' / ' || pg_temp.line('HI-B', current_date),
  'awaiting_approval 1000 / open 1000', 'a released match: awaiting before, open again after');
select is(pg_temp.line('HI-C', current_date - 1) || ' / ' || pg_temp.line('HI-C', current_date),
  'awaiting_approval 1000 / open 1000', 'an undone match: as it stood before, open again after');

-- Today's state from the history is today's rows, in every business.
select is((select count(*) from (
            (select to_jsonb(m) from public.invoice_matches m
              except select to_jsonb(x) from public.workspaces w, public.invoice_matches_at(w.id, now() + interval '1 day') x)
            union all
            (select to_jsonb(x) from public.workspaces w, public.invoice_matches_at(w.id, now() + interval '1 day') x
              except select to_jsonb(m) from public.invoice_matches m)
            union all
            (select to_jsonb(p) from public.invoice_match_payments p
              except select to_jsonb(x) from public.workspaces w, public.invoice_match_payments_at(w.id, now() + interval '1 day') x)
            union all
            (select to_jsonb(x) from public.workspaces w, public.invoice_match_payments_at(w.id, now() + interval '1 day') x
              except select to_jsonb(p) from public.invoice_match_payments p)) d)::int,
  0, 'read from the history, today''s matches and parts are today''s rows, in every business');

select ok(pg_temp.as_owner(format('select public.customer_statement_v1(%L, %L, current_date)::text',
            current_setting('hi.ws'), current_setting('hi.m1')))::jsonb ->> 'history_from' is not null,
  'the statement says from when its history is exact');

-- The history is never edited, and nobody reads it directly.
create or replace function pg_temp.refusal(p_sql text) returns text language plpgsql as $f$
begin
  execute p_sql;
  return 'no refusal';
exception when others then
  return sqlstate;
end
$f$;
select is(pg_temp.refusal(format('update public.invoice_match_history set at = now() where workspace_id = %L', current_setting('hi.ws')))
          || ' ' || pg_temp.refusal(format('delete from public.invoice_match_history where workspace_id = %L', current_setting('hi.ws'))),
  '55000 55000', 'the history can be neither edited nor deleted');
select is(pg_temp.as_owner(format('select count(*)::text from public.invoice_match_history where workspace_id = %L',
            current_setting('hi.ws'))),
  'ERROR 42501', 'not even the owner reads the history directly: the statement reads it');

select * from finish();
rollback;
