-- SPDX-License-Identifier: 0BSD
--
-- #1226/#1227 — two workspaces, and neither can see the other.
--
-- `docs/security/SUPABASE_RLS_MATRIX.md` carried one evidence line:
-- "Audited with the Supabase security advisors (clean, 2026-07-07)".
-- An advisor reports that a policy EXISTS. It does not evaluate one.
-- This file evaluates them, as a signed-in member of one workspace
-- looking at the rows of another.
--
-- The impersonation is the project's own harness idiom: set the JWT
-- claims PostgREST would set, then `set local role authenticated` so
-- that RLS applies at all. As `postgres` every policy is bypassed and
-- every assertion below would pass while proving nothing — which is
-- exactly the trap a first RLS test falls into.
begin;
select plan(12);

-- ---------------------------------------------------------------- seed
create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_a uuid := '00000000-0000-4000-8000-0000000000aa';
  u_b uuid := '00000000-0000-4000-8000-0000000000bb';
  ws_a uuid; ws_b uuid; m_a uuid; m_b uuid;
begin
  -- `auth.users` carries a trigger that creates the profile, so the
  -- profile is NOT inserted here — inserting it fails on the primary
  -- key, which is how we learned the trigger is real.
  insert into auth.users (id, instance_id, aud, role, email,
                          encrypted_password, email_confirmed_at,
                          created_at, updated_at)
  values (u_a, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'a@deskilo.test', '', now(), now(), now()),
         (u_b, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'b@deskilo.test', '', now(), now(), now());

  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Space A', 'FR', 'EUR', 'Europe/Paris', u_a) returning id into ws_a;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Space B', 'FR', 'EUR', 'Europe/Paris', u_b) returning id into ws_b;

  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws_a, u_a, true, true) returning id into m_a;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws_b, u_b, true, true) returning id into m_b;

  -- One row of each money table in EACH workspace, so "sees nothing"
  -- is distinguishable from "there was nothing to see" — the failure
  -- mode that makes a tenancy test worthless.
  insert into public.ledger_entries (workspace_id, member_id, kind, category,
                                     amount_cents, description, period)
  values (ws_a, m_a, 'charge', 'subscription', 10000, 'A subscription', '2026-09'),
         (ws_b, m_b, 'charge', 'subscription', 20000, 'B subscription', '2026-09');

  insert into public.invoices (workspace_id, member_id, issuer_member_id, number,
                               title, lines, total_cents, currency, member_name,
                               workspace_name, issuer_name, signature)
  values (ws_a, m_a, m_a, 'A-1', 'A', '[]'::jsonb, 10000, 'EUR', 'A', 'Space A', 'A', 'sig'),
         (ws_b, m_b, m_b, 'B-1', 'B', '[]'::jsonb, 20000, 'EUR', 'B', 'Space B', 'B', 'sig');

  perform set_config('deskilo.test.ws_a', ws_a::text, false);
  perform set_config('deskilo.test.ws_b', ws_b::text, false);
  perform set_config('deskilo.test.u_a', u_a::text, false);
  perform set_config('deskilo.test.u_b', u_b::text, false);
  perform set_config('deskilo.test.m_a', m_a::text, false);
  perform set_config('deskilo.test.m_b', m_b::text, false);
end;
$seed$;

select pg_temp.seed();

-- Become a signed-in member of Space A. `set role` is what makes RLS
-- apply; the claims are what `auth.uid()` reads.
create or replace function pg_temp.be(p_user text) returns void
language plpgsql as $be$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('deskilo.test.' || p_user),
                      'role', 'authenticated')::text, false);
end;
$be$;

select pg_temp.be('u_a');
set local role authenticated;

-- ------------------------------------------------------------- reading
select is(
  (select count(*) from public.workspaces
    where id = current_setting('deskilo.test.ws_b')::uuid)::int,
  0, 'a member of A cannot read the other workspace');

select is(
  (select count(*) from public.workspaces
    where id = current_setting('deskilo.test.ws_a')::uuid)::int,
  1, 'and CAN read their own — so the query itself works');

select is(
  (select count(*) from public.members
    where workspace_id = current_setting('deskilo.test.ws_b')::uuid)::int,
  0, 'a member of A cannot read the other workspace''s members');

select is(
  (select count(*) from public.members
    where workspace_id = current_setting('deskilo.test.ws_a')::uuid)::int,
  1, 'and CAN read their own');

select is(
  (select count(*) from public.ledger_entries
    where workspace_id = current_setting('deskilo.test.ws_b')::uuid)::int,
  0, 'a member of A cannot read the other workspace''s ledger');

select is(
  (select count(*) from public.ledger_entries
    where workspace_id = current_setting('deskilo.test.ws_a')::uuid)::int,
  1, 'and CAN read their own ledger');

select is(
  (select count(*) from public.invoices
    where workspace_id = current_setting('deskilo.test.ws_b')::uuid)::int,
  0, 'a member of A cannot read the other workspace''s invoices');

select is(
  (select count(*) from public.invoices
    where workspace_id = current_setting('deskilo.test.ws_a')::uuid)::int,
  1, 'and CAN read their own invoices');

-- ------------------------------------------------------------- writing
-- Reading nothing is half the property. A tenant that cannot SEE a
-- workspace but can WRITE into it is the more dangerous half.
select throws_ok(
  format($$ insert into public.ledger_entries
              (workspace_id, member_id, kind, category, amount_cents,
               description, period)
            values (%L, %L, 'credit', 'adjustment', 99999, 'gift', '2026-09') $$,
         current_setting('deskilo.test.ws_b'),
         current_setting('deskilo.test.m_b')),
  '42501',
  null,
  'a member of A cannot write a ledger entry into the other workspace');

-- An UPDATE is the quiet one: RLS does not raise, it simply matches no
-- rows. So the assertion cannot be about the error — it has to be about
-- the row, read back with RLS out of the way.
select lives_ok(
  format($$ update public.members set managed_name = 'renamed' where id = %L $$,
         current_setting('deskilo.test.m_b')),
  'an UPDATE against the other workspace raises nothing…');

reset role;
select is(
  (select managed_name from public.members
    where id = current_setting('deskilo.test.m_b')::uuid),
  '',
  '…and changes nothing: RLS matched no rows at all');
set local role authenticated;

-- ------------------------------------------------- the other direction
-- Symmetry matters: a policy written as `workspace_id = my_workspace()`
-- with the wrong side of the comparison passes one direction and fails
-- the other.
reset role;
select pg_temp.be('u_b');
set local role authenticated;

select is(
  (select count(*) from public.invoices
    where workspace_id = current_setting('deskilo.test.ws_a')::uuid)::int,
  0, 'and B cannot read A either — the isolation is symmetric');

reset role;
select * from finish();
rollback;
