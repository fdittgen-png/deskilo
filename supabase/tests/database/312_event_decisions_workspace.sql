-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- 0612 (#3099 slice B) — a decision carries the workspace of its event,
-- and a member of workspace A reads none of workspace B's decisions.
--
-- Real JWT claims and `set local role authenticated`: as `postgres` every
-- policy is bypassed and the isolation assertions would prove nothing.
-- All rows are seeded BEFORE the first role switch.
begin;
select plan(7);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_a uuid := '00000000-0000-4000-8000-0000000003a1';
  u_b uuid := '00000000-0000-4000-8000-0000000003b1';
  ws_a uuid; ws_b uuid; m_a uuid; m_b uuid; ev_a uuid; ev_b uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email,
                          encrypted_password, email_confirmed_at,
                          created_at, updated_at)
  values (u_a, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'decisions-a@deskilo.test', '', now(), now(), now()),
         (u_b, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'decisions-b@deskilo.test', '', now(), now(), now());

  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Decisions A', 'FR', 'EUR', 'Europe/Paris', u_a) returning id into ws_a;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Decisions B', 'FR', 'EUR', 'Europe/Paris', u_b) returning id into ws_b;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws_a, u_a, true, true) returning id into m_a;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws_b, u_b, true, true) returning id into m_b;

  insert into public.events (workspace_id, type, action, actor_member_id, subject_member_id, status)
  values (ws_a, 'payment', 'created', m_a, m_a, 'applied') returning id into ev_a;
  insert into public.events (workspace_id, type, action, actor_member_id, subject_member_id, status)
  values (ws_b, 'payment', 'created', m_b, m_b, 'applied') returning id into ev_b;

  -- Writers never pass workspace_id: the trigger reads it from the event.
  insert into public.event_decisions (event_id, member_id, decision)
  values (ev_a, m_a, 'accept'), (ev_b, m_b, 'accept');

  perform set_config('t.ws_a', ws_a::text, true);
  perform set_config('t.ws_b', ws_b::text, true);
  perform set_config('t.u_a', u_a::text, true);
  perform set_config('t.u_b', u_b::text, true);
end;
$seed$;

select pg_temp.seed();

select has_trigger('public', 'event_decisions', 'event_decisions_fill_workspace',
  'the trigger that fills workspace_id exists');
select col_not_null('public', 'event_decisions', 'workspace_id',
  'every decision has a workspace');
select is(
  (select array_agg(d.workspace_id = e.workspace_id) from public.event_decisions d
     join public.events e on e.id = d.event_id
    where e.workspace_id in (current_setting('t.ws_a')::uuid, current_setting('t.ws_b')::uuid)),
  array[true, true],
  'each decision carries the workspace of its event');

-- ── as the owner of A ──────────────────────────────────────────────────
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('t.u_a'), 'role', 'authenticated')::text, true);
set local role authenticated;
select is((select count(*)::int from public.event_decisions
            where workspace_id = current_setting('t.ws_b')::uuid), 0,
  'a member of A reads 0 decisions of B');
select is((select count(*)::int from public.event_decisions
            where workspace_id = current_setting('t.ws_a')::uuid), 1,
  'and reads the decision of A');
reset role;

-- ── as the owner of B ──────────────────────────────────────────────────
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('t.u_b'), 'role', 'authenticated')::text, true);
set local role authenticated;
select is((select count(*)::int from public.event_decisions
            where workspace_id = current_setting('t.ws_a')::uuid), 0,
  'a member of B reads 0 decisions of A');
select is((select count(*)::int from public.event_decisions
            where workspace_id = current_setting('t.ws_b')::uuid), 1,
  'and reads the decision of B');
reset role;

select * from finish();
rollback;
