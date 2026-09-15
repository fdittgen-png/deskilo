-- SPDX-License-Identifier: 0BSD
--
-- #1335 — a feature the client treats as OFF must be off on the server.
--
-- The client decides in two steps: stored JSON booleans over the registry
-- defaults, then every `requires` parent must be on (effectiveFeatures).
-- A child stays stored `true` under a parent switched off — that is the
-- design (#800) — so a server gate that reads only the child flag lets
-- through what the app shows as switched off. #1332 found five such
-- gates, and a configuration import that replaces the flag map without
-- validating it.
--
-- The assertions inside the TODO block are the red-first proofs of
-- #1332: they fail today, pg_prove reports them as TODO rather than as a
-- failure, and the pull request that fixes #1332 removes the TODO so they
-- become ordinary regressions. The two controls outside it pin the gates
-- that already work, so the file cannot pass by testing nothing.
begin;
select plan(8);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_owner uuid := '00000000-0000-4000-8000-0000000000e1';
  u_admin uuid := '00000000-0000-4000-8000-0000000000e2';
  u_member uuid := '00000000-0000-4000-8000-0000000000e3';
  ws uuid;
  m_member uuid;
begin
  -- The profile comes from the trigger on `auth.users`; never insert it.
  insert into auth.users (id, instance_id, aud, role, email,
                          encrypted_password, email_confirmed_at,
                          created_at, updated_at)
  values (u_owner, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'gates-owner@deskilo.test', '', now(), now(), now()),
         (u_admin, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'gates-admin@deskilo.test', '', now(), now(), now()),
         (u_member, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'gates-member@deskilo.test', '', now(), now(), now());

  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Gates', 'FR', 'EUR', 'Europe/Paris', u_owner) returning id into ws;

  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_owner, true, true), (ws, u_admin, false, true);
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_member, false, false) returning id into m_member;

  perform set_config('deskilo.gates.ws', ws::text, true);
  perform set_config('deskilo.gates.owner', u_owner::text, true);
  perform set_config('deskilo.gates.admin', u_admin::text, true);
  perform set_config('deskilo.gates.member_id', m_member::text, true);
end
$seed$;

-- Real JWT claims and the `authenticated` role: an authorization answer
-- given to `postgres` proves nothing.
create or replace function pg_temp.act_as(p_who text) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('deskilo.gates.' || p_who), 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', current_setting('deskilo.gates.' || p_who), true);
  execute 'set local role authenticated';
end
$act$;

-- The flag map, written as the server stores it.
create or replace function pg_temp.flags(p_flags jsonb) returns void language sql as $flags$
  update public.workspaces set feature_flags = p_flags
   where id = current_setting('deskilo.gates.ws')::uuid;
$flags$;

select pg_temp.seed();

-- ------------------------------------------------------------ controls
select pg_temp.flags('{"moneyTab": true, "scheduledExpenses": false}');
select pg_temp.act_as('owner');
select throws_matching(
  $$select public.create_expense_schedule(current_setting('deskilo.gates.ws')::uuid,
      'Cleaning', 100, current_date, 'month', 1, null, null, null)$$,
  'disabled',
  'control: a scheduled expense is refused while its own flag is off');
select throws_matching(
  $$select public.set_feature_flags(current_setting('deskilo.gates.ws')::uuid,
      '{"kioskMode": "yes"}'::jsonb)$$,
  'true or false',
  'control: set_feature_flags refuses a non-boolean value');
reset role;

-- ------------------------------------------------------------ #1332, red first
select todo_start('#1332 — server gates follow the requires chain; import validates the flag map');

select pg_temp.flags('{"moneyTab": false, "scheduledExpenses": true}');
select pg_temp.act_as('owner');
select throws_matching(
  $$select public.create_expense_schedule(current_setting('deskilo.gates.ws')::uuid,
      'Cleaning', 100, current_date, 'month', 1, null, null, null)$$,
  'disabled',
  'a scheduled expense is refused while Money, its parent, is off');
reset role;

select pg_temp.flags('{"moneyTab": false, "priceNegotiations": true}');
select pg_temp.act_as('owner');
select throws_matching(
  $$select public.propose_price_negotiation(current_setting('deskilo.gates.member_id')::uuid,
      100, null, null, null, current_date, null, null)$$,
  'off in this workspace',
  'a price negotiation is refused while Money, its parent, is off');
reset role;

select pg_temp.flags('{"moneyTab": true, "invoicing": false, "invoiceSettlement": true}');
select pg_temp.act_as('owner');
select throws_matching(
  $$select public.settle_invoices(current_setting('deskilo.gates.ws')::uuid,
      current_setting('deskilo.gates.member_id')::uuid,
      array[gen_random_uuid(), gen_random_uuid()], null)$$,
  'not enabled',
  'settling invoices is refused while Invoicing, its parent, is off');
reset role;

select pg_temp.flags('{"moneyTab": true, "invoicing": false, "adminInvoicing": true}');
select pg_temp.act_as('admin');
select is(
  public.has_permission(current_setting('deskilo.gates.ws')::uuid, 'issueInvoices'),
  false,
  'adminInvoicing grants admins nothing while Invoicing, its parent, is off');
reset role;

select pg_temp.flags('{"moneyTab": true, "kioskMode": false}');
select pg_temp.act_as('owner');
select public.import_workspace_configuration(current_setting('deskilo.gates.ws')::uuid,
  '{"workspace": {"feature_flags": {"moneyTab": true}}}'::jsonb);
reset role;
select is(
  (select feature_flags -> 'kioskMode' from public.workspaces
    where id = current_setting('deskilo.gates.ws')::uuid),
  'false'::jsonb,
  'a partial imported flag map leaves a default-on platform feature off');

select pg_temp.act_as('owner');
select throws_matching(
  $$select public.import_workspace_configuration(current_setting('deskilo.gates.ws')::uuid,
      '{"workspace": {"feature_flags": {"kioskMode": "yes"}}}'::jsonb)$$,
  'true or false',
  'an imported non-boolean flag value is refused');
reset role;

select todo_end();

select * from finish();
rollback;
