-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3877 + #3878 (0755): Me's overview answers the server's own figures.
--
-- (a) a first partial of 40 on an invoice of 100 waits for approval: 40 is
--     being validated, 60 is still due;
-- (b) a confirmed partial of 40 and a further 60 waiting: nothing is still
--     due, 60 is being validated;
-- and every document still owed is answered however old, the settled ones
-- by their newest page, with a flag when older settled ones were left out.
-- Rolled back.
begin;
select plan(7);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000038770a1';
  u_1 uuid := '00000000-0000-4000-8000-0000038770a2';
  ws uuid; m_o uuid; m_1 uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'truth-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_1]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Truth', 'FR', 'EUR', 'Europe/Paris', u_o, '{"moneyTab": true, "invoicing": true}'::jsonb)
  returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, status, joined_at)
  values (ws, u_o, true, true, 'active', '2026-01-01'), (ws, u_1, false, false, 'active', '2026-01-01');
  select id into m_o from public.members where workspace_id = ws and user_id = u_o;
  select id into m_1 from public.members where workspace_id = ws and user_id = u_1;
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name, signature)
  select ws, m_1, m_o, n, 'One', '[]'::jsonb, 10000, 'EUR', 'One', 'Truth', 'Owner', 'sig'
    from unnest(array['TR-A', 'TR-B', 'TR-OLD']) n;
  insert into public.ledger_entries (workspace_id, member_id, kind, category, amount_cents, description, period)
  values (ws, m_1, 'credit', 'payment', 4000, 'PA', '2026-11'),
         (ws, m_1, 'credit', 'payment', 4000, 'PB1', '2026-11'),
         (ws, m_1, 'credit', 'payment', 6000, 'PB2', '2026-11');
  -- 301 settled documents, newer than the open one: one more than a page.
  insert into public.invoices (workspace_id, member_id, issuer_member_id, number, title, lines,
                               total_cents, currency, member_name, workspace_name, issuer_name, signature)
  select ws, m_1, m_o, 'TR-S' || g, 'Settled', '[]'::jsonb, 1000, 'EUR', 'One', 'Truth', 'Owner', 'sig'
    from generate_series(1, 301) g;
  insert into public.invoice_matches (workspace_id, invoice_id, paid_cents, resolution, status)
  select ws, i.id, 1000, 'exact', 'confirmed'
    from public.invoices i where i.workspace_id = ws and i.number like 'TR-S%';
  -- An issued invoice is immutable: its day is set with the guards off.
  set local session_replication_role = replica;
  update public.invoices set issued_at = now() - (substr(number, 5)::int || ' days')::interval
   where workspace_id = ws and number like 'TR-S%';
  update public.invoices set issued_at = now() - interval '5 years'
   where workspace_id = ws and number = 'TR-OLD';
  set local session_replication_role = origin;
  perform set_config('tr.ws', ws::text, false);
  perform set_config('tr.owner', u_o::text, false);
  perform set_config('tr.member', u_1::text, false);
end
$seed$;
select pg_temp.seed();

create or replace function pg_temp.id(p_kind text, p_name text) returns uuid language sql as $f$
  select case p_kind
    when 'inv' then (select id from public.invoices where workspace_id = current_setting('tr.ws')::uuid and number = p_name)
    else (select id from public.ledger_entries where workspace_id = current_setting('tr.ws')::uuid and description = p_name) end;
$f$;
create or replace function pg_temp.as_user(p_user text, p_sql text) returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting(p_user), 'role', 'authenticated')::text, true);
  set local role authenticated;
  execute p_sql into v;
  reset role;
  return v;
end
$f$;
grant execute on all functions in schema pg_temp to authenticated;

-- (b)'s first part stands before the business asks for approvals.
select pg_temp.as_user('tr.owner', format(
  'select public.match_invoice(%L, %L, ''under_accepted'', ''a part'', 4000)::text',
  pg_temp.id('inv', 'TR-B'), pg_temp.id('pay', 'PB1')));
insert into public.validation_policies (workspace_id, event_type, required_count)
values (current_setting('tr.ws')::uuid, 'invoice_payment', 1);
-- (a) a first partial, (b) a further part: both wait.
select pg_temp.as_user('tr.owner', format(
  'select public.match_invoice(%L, %L, ''under_accepted'', ''a part'', 4000)::text',
  pg_temp.id('inv', 'TR-A'), pg_temp.id('pay', 'PA')));
select pg_temp.as_user('tr.owner', format(
  'select public.match_invoice(%L, %L, ''exact'', ''the rest'', 6000)::text',
  pg_temp.id('inv', 'TR-B'), pg_temp.id('pay', 'PB2')));

create temporary table truth on commit drop as
  select pg_temp.as_user('tr.member', 'select public.my_finance_overview()::text')::jsonb as v;
create or replace function pg_temp.row(p_number text) returns jsonb language sql as $f$
  select e from truth, jsonb_array_elements(v -> 'invoices') e where e ->> 'number' = p_number;
$f$;

select is((select r ->> 'state' || ' ' || (r ->> 'still_due_cents') || ' ' || (r ->> 'awaiting_cents')
             from pg_temp.row('TR-A') r),
  'awaiting_validation 6000 4000',
  '(a) a first partial of 40 awaiting approval: 60 still due, 40 being validated');
select is((select r ->> 'state' || ' ' || (r ->> 'still_due_cents') || ' ' || (r ->> 'awaiting_cents')
             from pg_temp.row('TR-B') r),
  'partially_paid 0 6000',
  '(b) a confirmed 40 and a further 60 awaiting approval: nothing still due, 60 being validated');
select ok(pg_temp.row('TR-OLD') is not null,
  'an open invoice older than three hundred settled ones is answered');
select is((select count(*)::int from truth, jsonb_array_elements(v -> 'invoices') e
            where e ->> 'state' in ('open', 'awaiting_validation', 'partially_paid')), 3,
  'every document still owed is answered');
select is((select count(*)::int from truth, jsonb_array_elements(v -> 'invoices') e
            where e ->> 'state' = 'paid'), 300,
  'the settled ones come by their newest page');
select is((select (v ->> 'settled_cut')::boolean from truth), true,
  'the answer says older settled documents were left out');
select ok(pg_temp.row('TR-S301') is null and pg_temp.row('TR-S1') is not null,
  'the one left out is the oldest settled one');

select * from finish();
rollback;
