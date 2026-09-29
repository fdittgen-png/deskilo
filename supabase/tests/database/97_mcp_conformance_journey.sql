-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1632 — the assembled MCP journey on ONE installation (D1), and proof
-- that its checks can fail.
--
-- WHAT THIS PROVES, AND WHAT IT DOES NOT. Callers are impersonated by
-- setting `request.jwt.claims` and `set local role authenticated`: that
-- proves the SQL logic of every gate in isolation, under real RLS and the
-- real definer functions. It proves NOTHING about OIDC, OAuth, PKCE, a
-- provider-issued token, PostgREST or a second database. A second
-- installation (D2) cannot exist inside one database: D2 appears here only
-- as a foreign installation id and a foreign epoch that D1 must refuse,
-- carrying D1's own workspace, seat and request UUIDs. Two real disposable
-- installations remain an open item of #1632.
--
-- The fixture: one human (H) with different roles in workspaces A (member;
-- booking and own reads) and B (administrator; reads only); C has MCP
-- switched off; U carries A's display name and is never consented; E is
-- joined later; her own statement and invoices are read in A and refused
-- in B. Two D1 database administrators (X1, X2) and a D2-only one
-- (Y). Two validators (V1, V2) decide one A event: one person counts once
-- across clients and paths, and the effect applies once. Outputs carry no
-- name, contact or label canary. Scoped revoke and eligibility revoke end
-- exactly their own scope.
--
-- The last section injects, one at a time, the faults #1632 names —
-- installation check, eligibility check, consent check, workspace check
-- and distinct-person rule removed — into the function where each lives,
-- inside this rolled-back transaction, asserts the probe now sees the
-- defect, and restores the original body. No fault switch is deployed.
-- Seeds and read-backs run as postgres.
begin;
select plan(79);

create function pg_temp.act_as(p_user uuid, p_client text default null) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_strip_nulls(jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2', 'client_id', p_client))::text, true);
  execute 'set local role authenticated';
end;
$$;
create function pg_temp.u(p_who text) returns uuid language sql immutable as $$
  select ('00000000-0000-4000-8000-0000001632' || p_who)::uuid;
$$;
-- Every envelope any caller received, for the canary sweep.
create temp table outputs (label text, body jsonb);
-- One dispatcher call as a delegated token of [p_who] through [p_client].
create function pg_temp.call(p_who text, p_client text, p_ws uuid, p_op text, p_args jsonb,
                             p_req uuid default null, p_installation uuid default null)
returns jsonb language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.act_as(pg_temp.u(p_who), p_client);
  r := public.mcp_execute_v1(coalesce(p_installation, current_setting('t.i')::uuid), p_ws, p_op, p_args, p_req);
  execute 'reset role';
  insert into outputs values (p_who || ':' || p_op, r);
  return r;
end;
$$;
-- The outcome word of a call: its status, or its refusal code.
create function pg_temp.says(p_who text, p_client text, p_ws text, p_op text default 'get_capabilities')
returns text language plpgsql as $$
declare
  r jsonb := pg_temp.call(p_who, p_client, nullif(current_setting('t.' || p_ws), '')::uuid, p_op,
               case when p_op = 'get_availability'
                    then jsonb_build_object('starts_at', current_setting('t.am_s'), 'ends_at', current_setting('t.pm_e'))
                    else '{}'::jsonb end);
begin
  return coalesce(r->'error'->>'code', r->>'status');
end;
$$;
create function pg_temp.book(p_req text, p_ws text default 'a', p_half text default 'am') returns jsonb language sql as $$
  select pg_temp.call('a2', 'claude-1632', current_setting('t.' || p_ws)::uuid, 'create_reservation',
    jsonb_build_object('seat_id', current_setting('t.seat'),
                       'starts_at', current_setting('t.' || p_half || '_s'),
                       'ends_at', current_setting('t.' || p_half || '_e')),
    pg_temp.u(p_req));
$$;
create function pg_temp.bookings() returns int language sql as $$
  select count(*)::int from public.reservations r join public.members m on m.id = r.member_id
   where m.user_id = pg_temp.u('a2');
$$;
-- The native consent flow for [p_scopes], as [p_who].
create function pg_temp.consent(p_who text, p_client text, p_authz text, p_scopes jsonb) returns text language plpgsql as $$
declare
  v text;
begin
  perform pg_temp.act_as(pg_temp.u(p_who));
  perform public.mcp_prepare_connection(p_client, p_authz, p_scopes);
  v := public.mcp_finalize_connection(p_authz)->>'status';
  execute 'reset role';
  return v;
end;
$$;
-- The error a native statement raises for [p_who], or 'no error'.
create function pg_temp.err(p_who text, p_sql text) returns text language plpgsql as $$
begin
  perform pg_temp.act_as(pg_temp.u(p_who));
  begin
    execute p_sql;
  exception when others then
    execute 'reset role';
    return sqlerrm;
  end;
  execute 'reset role';
  return 'no error';
end;
$$;
-- A native call returning jsonb, as [p_who].
create function pg_temp.native(p_who text, p_sql text) returns jsonb language plpgsql as $$
declare
  v jsonb;
begin
  perform pg_temp.act_as(pg_temp.u(p_who));
  execute p_sql into v;
  execute 'reset role';
  return v;
end;
$$;
-- A respond_to_validation through MCP, confirmed natively when asked.
create function pg_temp.validate(p_who text, p_client text, p_event text, p_req text) returns jsonb language plpgsql as $$
declare
  v jsonb;
  args jsonb := jsonb_build_object('event_id', current_setting('t.' || p_event), 'accept', true);
begin
  v := pg_temp.call(p_who, p_client, current_setting('t.a')::uuid, 'respond_to_validation', args, pg_temp.u(p_req));
  if v->>'status' <> 'requires_confirmation' then return v; end if;
  perform pg_temp.act_as(pg_temp.u(p_who));
  perform public.mcp_confirm_action((v->'data'->>'confirmation_id')::uuid, true);
  execute 'reset role';
  return pg_temp.call(p_who, p_client, current_setting('t.a')::uuid, 'respond_to_validation', args, pg_temp.u(p_req));
end;
$$;
-- Fault injection: replace the ONE occurrence of [p_anchor] in [p_fn],
-- keeping the original body to restore. Anything but exactly one
-- occurrence refuses, so a moved check cannot make a fault a no-op.
create function pg_temp.inject(p_fn regprocedure, p_anchor text, p_with text) returns text language plpgsql as $$
declare
  v_def text := pg_get_functiondef(p_fn);
  n int := (length(v_def) - length(replace(v_def, p_anchor, ''))) / length(p_anchor);
begin
  if n <> 1 then return format('the anchor occurs %s times', n); end if;
  perform set_config('t.saved', v_def, true);
  execute replace(v_def, p_anchor, p_with);
  return 'injected';
end;
$$;
create function pg_temp.restore() returns void language plpgsql as $$
begin
  execute current_setting('t.saved');
end;
$$;

-- ── seed ─────────────────────────────────────────────────────────────
-- a1 owner · a2 H · a3 V1 · a4 V2 · a5 X1 · a6 X2 · a7 Y (D2-only
-- administrator) · a8 N (never approved) · a9 S (subject of the change)
select set_config('t.i', public.installation_id()::text, true);
select set_config('t.d2', 'dddddddd-0000-4000-8000-000000001632', true);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(s), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       s || '-1632@deskilo.test', '', now(), now(), now()
  from unnest(array['a1', 'a2', 'a3', 'a4', 'a5', 'a6', 'a7', 'a8', 'a9']) s;
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1');
insert into public.mcp_clients (client_id, name) values ('claude-1632', 'First assistant'), ('other-1632', 'Second assistant')
  on conflict (client_id) do update set status = 'active';
update public.mcp_runtime set enabled = true;
update public.mcp_limits set calls_per_minute = 1000, mutations_per_minute = 100;
select pg_temp.act_as(pg_temp.u('a1'));
select public.finalize_identity_binding();
select set_config('t.a', public.create_workspace('Shared name', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select public.apply_workspace_template(current_setting('t.a')::uuid, (select id from public.workspace_templates where key = 'tiny'));
select set_config('t.u', public.create_workspace('Shared name', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select set_config('t.b', public.create_workspace('Reads only', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select set_config('t.c', public.create_workspace('Switched off', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select set_config('t.e', public.create_workspace('Joined later', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select set_config('t.none', '', true);
reset role;
select pg_temp.native(s, 'select public.finalize_identity_binding()')
  from unnest(array['a2', 'a3', 'a4', 'a5', 'a6', 'a7', 'a8', 'a9']) s;
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"mcpAccess": true}',
  booking_rules = booking_rules || '{"open_weekdays":[1,2,3,4,5,6,7],"granularity":"half_day","work_start_minutes":480,"half_boundary_minutes":720,"work_end_minutes":1080}'
 where id in (current_setting('t.a')::uuid, current_setting('t.b')::uuid, current_setting('t.u')::uuid,
              current_setting('t.e')::uuid);
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"mcpAccess": false}'
 where id = current_setting('t.c')::uuid;
insert into public.members (workspace_id, user_id, status, is_admin, subscription_pct)
select current_setting('t.' || w)::uuid, pg_temp.u(p), 'active', adm, 100
  from (values ('a', 'a2', false), ('b', 'a2', true), ('c', 'a2', false), ('u', 'a2', false),
               ('a', 'a3', true), ('b', 'a3', true), ('a', 'a4', true), ('b', 'a4', true),
               ('a', 'a8', false), ('a', 'a9', false), ('b', 'a9', false)) f(w, p, adm);
insert into public.validation_policies (workspace_id, event_type, required_count, admins_may_validate, validator_scope)
values (current_setting('t.a')::uuid, 'subscription_change', 2, true, 'admins'),
       (current_setting('t.b')::uuid, 'subscription_change', 2, true, 'admins')
on conflict do nothing;
select set_config('t.ma', (select id::text from public.members where workspace_id = current_setting('t.a')::uuid
  and user_id = pg_temp.u('a2')), true);
select set_config('t.mv', (select id::text from public.members where workspace_id = current_setting('t.a')::uuid
  and user_id = pg_temp.u('a3')), true);
-- The canaries: names, contacts and a person in a seat label.
update public.profiles set display_name = 'CANARY Hilde Human', first_name = 'CANARY-first', last_name = 'CANARY-last',
       phone = '+33 6 99 99 16 32', address = 'CANARY 1 rue du Test', email = 'canary-1632@example.org'
 where id in (pg_temp.u('a2'), pg_temp.u('a3'), pg_temp.u('a9'));
select set_config('t.seat', (select id::text from public.seats where workspace_id = current_setting('t.a')::uuid order by name limit 1), true);
update public.seats set name = 'CANARY desk of Hilde <canary-1632@example.org>' where id = current_setting('t.seat')::uuid;
select set_config('t.day', ((now() at time zone 'Europe/Paris')::date + 2)::text, true);
select set_config('t.am_s', to_jsonb((current_setting('t.day') || ' 08:00')::timestamp at time zone 'Europe/Paris')->>0, true);
select set_config('t.am_e', to_jsonb((current_setting('t.day') || ' 12:00')::timestamp at time zone 'Europe/Paris')->>0, true);
select set_config('t.pm_s', to_jsonb((current_setting('t.day') || ' 12:00')::timestamp at time zone 'Europe/Paris')->>0, true);
select set_config('t.pm_e', to_jsonb((current_setting('t.day') || ' 18:00')::timestamp at time zone 'Europe/Paris')->>0, true);
-- Two D1 administrators; Y administers D2 only, so nothing here.
select public.operator_grant_database_admin(pg_temp.u('a5'), true);
select public.operator_grant_database_admin(pg_temp.u('a6'), false);
-- B's owner sets its policy BEFORE anybody is eligible; A's comes after.
select pg_temp.native('a1', format($q$select public.save_mcp_policy(%L, 0, %L, true,
  array['get_capabilities', 'get_availability', 'list_my_reservations'], 'workspace')$q$,
  current_setting('t.b'), pg_temp.u('f1')));
select pg_temp.native('a1', format($q$select public.save_mcp_policy(%L, 0, %L, true, array['get_capabilities'], 'own')$q$,
  current_setting('t.u'), pg_temp.u('f2')));
select pg_temp.native('a1', format($q$select public.save_mcp_policy(%L, 0, %L, true,
  array['get_capabilities', 'create_reservation'], 'own')$q$, current_setting('t.e'), pg_temp.u('f3')));
insert into public.workspace_mcp_policies (workspace_id, installation_id, revision, enabled, operations, target_ceiling)
values (current_setting('t.c')::uuid, public.installation_id(), 1, true, array['get_capabilities'], 'own');

-- ── 1. registered is not enrolled ────────────────────────────────────
select is(pg_temp.native('a2', 'select public.my_database_capabilities()')->>'mcp_eligibility', 'not_requested',
  'a registered human starts with no MCP eligibility');
select is(pg_temp.err('a2', format($q$select public.mcp_prepare_connection('claude-1632', 'authz-1632-x',
  '[{"workspace_id":"%s","operations":["get_capabilities"]}]')$q$, current_setting('t.b'))),
  'this database has not approved MCP for you yet', 'no consent before the database approves');
select pg_temp.native('a2', 'select public.request_mcp_eligibility()');
select is(pg_temp.native('a2', 'select public.my_database_capabilities()')->>'mcp_eligibility', 'requested',
  'the request waits for an administrator');
select is(pg_temp.err('a2', format($q$select public.mcp_prepare_connection('claude-1632', 'authz-1632-x',
  '[{"workspace_id":"%s","operations":["get_capabilities"]}]')$q$, current_setting('t.b'))),
  'this database has not approved MCP for you yet', 'pending is still refused');

-- ── 2. database authority: local, several, never foreign ─────────────
select is(pg_temp.err('a7', format($q$select public.decide_mcp_eligibility(%L, %L, true)$q$,
  pg_temp.u('a2'), pg_temp.u('d7'))), 'not a database administrator here',
  'the D2 administrator decides nothing on D1');
select is(pg_temp.err('a1', format($q$select public.decide_mcp_eligibility(%L, %L, true)$q$,
  pg_temp.u('a2'), pg_temp.u('d1'))), 'not a database administrator here',
  'owning every workspace here is not database administration');
select is(pg_temp.native('a5', format($q$select public.decide_mcp_eligibility(%L, %L, true, 1)$q$,
  pg_temp.u('a2'), pg_temp.u('d2')))->>'status', 'decided', 'X1 approves the request it saw');
select is(pg_temp.native('a6', format($q$select public.decide_mcp_eligibility(%L, %L, true, 1)$q$,
  pg_temp.u('a2'), pg_temp.u('d3')))->>'reason', 'request_changed',
  'X2 deciding the same revision is a conflict, not a second grant');
select is((select count(*)::int from public.mcp_eligibility_grants where local_user_id = pg_temp.u('a2') and status = 'active'),
  1, 'one active approval for H');
select pg_temp.native('a6', format($q$select public.decide_mcp_eligibility(%L, %L, true)$q$, pg_temp.u(p), pg_temp.u('e' || right(p, 1))))
  from unnest(array['a3', 'a4']) p;
select is(pg_temp.says('a2', 'claude-1632', 'b'), 'no_connection', 'approval is not consent');

-- ── 3. owner policy after eligibility; explicit consent ──────────────
select is(pg_temp.native('a1', format($q$select public.save_mcp_policy(%L, 0, %L, true,
  array['get_capabilities', 'get_availability', 'list_my_reservations', 'get_my_statement', 'list_my_invoices',
        'create_reservation', 'respond_to_validation'],
  'workspace')$q$, current_setting('t.a'), pg_temp.u('f4')))->>'status', 'saved',
  'A is configured after H became eligible');
select is(pg_temp.err('a2', format($q$select public.mcp_prepare_connection('claude-1632', 'authz-1632-bad',
  '[{"workspace_id":"%s","operations":["create_reservation"]}]')$q$, current_setting('t.b'))),
  'operation create_reservation is not available there', 'consent cannot exceed B''s reads-only exposure');
select is(pg_temp.consent('a2', 'claude-1632', 'authz-1632-h1', jsonb_build_array(
  jsonb_build_object('workspace_id', current_setting('t.a'),
    'operations', '["get_capabilities","get_availability","list_my_reservations","get_my_statement","list_my_invoices","create_reservation"]'::jsonb),
  jsonb_build_object('workspace_id', current_setting('t.b'),
    'operations', '["get_capabilities","get_availability","list_my_reservations"]'::jsonb))),
  'finalized', 'H consents to A and B, and to nothing else');

-- ── 4. A books once; B, C, U and the unnamed workspace refuse ────────
select set_config('t.r1', pg_temp.book('c1')::text, true);
select is(current_setting('t.r1')::jsonb->>'status', 'completed', 'A books');
select is(pg_temp.book('c1')->'data'->>'reservation_id', current_setting('t.r1')::jsonb->'data'->>'reservation_id',
  'the same request id answers the same reservation');
select is(pg_temp.bookings(), 1, 'and one reservation exists');
select is(pg_temp.book('c2', 'b')->'error'->>'code', 'not_exposed', 'the same tool in B is refused');
select is(pg_temp.says('a2', 'claude-1632', 'a', 'get_availability'), 'completed', 'A answers availability');
select is(pg_temp.says('a2', 'claude-1632', 'b', 'get_availability'), 'completed', 'B answers its reads');
select is(pg_temp.call('a2', 'claude-1632', current_setting('t.a')::uuid, 'get_my_statement',
  jsonb_build_object('member_id', current_setting('t.ma'), 'period', to_char(now(), 'YYYY-MM')))->>'status', 'completed',
  'H reads her own A statement');
select is(pg_temp.call('a2', 'claude-1632', current_setting('t.a')::uuid, 'get_my_statement',
  jsonb_build_object('member_id', current_setting('t.mv'), 'period', to_char(now(), 'YYYY-MM')))->'error'->>'code', 'not_found',
  'another member''s statement does not exist for her');
select is(pg_temp.call('a2', 'claude-1632', current_setting('t.a')::uuid, 'list_my_invoices', '{}')->>'status', 'completed',
  'H lists her own A invoices');
select is(pg_temp.call('a2', 'claude-1632', current_setting('t.b')::uuid, 'list_my_invoices', '{}')->'error'->>'code',
  'not_exposed', 'B does not expose invoices');
select is(pg_temp.says('a2', 'claude-1632', 'c'), 'not_exposed', 'C has MCP off: refused whatever its policy row says');
select is(pg_temp.says('a2', 'claude-1632', 'u'), 'no_consent', 'U, same name as A, was never consented');
select is(pg_temp.says('a2', 'claude-1632', 'none'), 'not_exposed', 'no workspace named: no default is chosen');

-- ── 5. the other installation: same UUIDs, another id and epoch ──────
select is((pg_temp.call('a2', 'claude-1632', current_setting('t.a')::uuid, 'create_reservation',
  jsonb_build_object('seat_id', current_setting('t.seat'), 'starts_at', current_setting('t.pm_s'),
                     'ends_at', current_setting('t.pm_e')),
  pg_temp.u('c3'), current_setting('t.d2')::uuid))->'error'->>'code', 'wrong_installation',
  'D2''s id with A''s workspace and seat UUIDs is refused');
select is(pg_temp.bookings(), 1, 'and books nothing');
select is(pg_temp.call('a2', 'claude-1632', current_setting('t.a')::uuid, 'create_reservation', '{}'::jsonb,
  pg_temp.u('c1'), current_setting('t.d2')::uuid)->'error'->>'code', 'wrong_installation',
  'nor replays D1''s stored answer under D2''s id');
select set_config('t.epoch', (select epoch::text from public.mcp_runtime), true);
select pg_temp.act_as(pg_temp.u('a2'), 'claude-1632');
select set_config('request.method', 'POST', true);
select set_config('request.path', '/rpc/mcp_execute_v1', true);
select set_config('request.headers', jsonb_build_object('x-deskilo-mcp-epoch',
  (current_setting('t.epoch')::int + 1)::text)::text, true);
select throws_ok($$select public.mcp_pre_request()$$, 'PGRST', null, 'an endpoint deployed for another epoch is refused');
select set_config('request.headers', jsonb_build_object('x-deskilo-mcp-epoch', current_setting('t.epoch'))::text, true);
select lives_ok($$select public.mcp_pre_request()$$, 'this installation''s epoch passes');
reset role;
select set_config('request.headers', '', true);

-- ── 6. interleaving: a dropped A answer, B in between, the retry ─────
select set_config('t.x1', pg_temp.call('a2', 'claude-1632', current_setting('t.a')::uuid, 'get_capabilities', '{}', pg_temp.u('b1'))::text, true);
select set_config('t.x2', pg_temp.call('a2', 'claude-1632', current_setting('t.b')::uuid, 'get_capabilities', '{}', pg_temp.u('b2'))::text, true);
select set_config('t.r2', pg_temp.book('c4', 'a', 'pm')::text, true);  -- this answer is "lost"
select set_config('t.x3', pg_temp.call('a2', 'claude-1632', current_setting('t.b')::uuid, 'get_availability',
  jsonb_build_object('starts_at', current_setting('t.am_s'), 'ends_at', current_setting('t.pm_e')), pg_temp.u('b3'))::text, true);
select set_config('t.r2b', pg_temp.book('c4', 'a', 'pm')::text, true);  -- the retry, in A's own context
select ok(current_setting('t.x1')::jsonb->>'workspace_id' = current_setting('t.a')
          and current_setting('t.x1')::jsonb->>'request_id' = pg_temp.u('b1')::text
          and current_setting('t.x2')::jsonb->>'workspace_id' = current_setting('t.b')
          and current_setting('t.x2')::jsonb->>'request_id' = pg_temp.u('b2')::text
          and current_setting('t.x3')::jsonb->>'workspace_id' = current_setting('t.b'),
  'every interleaved answer names its own workspace and request id');
select is(current_setting('t.r2b')::jsonb->'data'->>'reservation_id', current_setting('t.r2')::jsonb->'data'->>'reservation_id',
  'the retry after the switch answers the lost booking');
select ok(current_setting('t.r2b')::jsonb->>'workspace_id' = current_setting('t.a')
          and current_setting('t.r2b')::jsonb->>'request_id' = pg_temp.u('c4')::text,
  'and is labelled A with its original request id');
select is(pg_temp.bookings(), 2, 'two intents, two reservations: nothing doubled, nothing in B');

-- ── 7. another membership: identity and approval reused, consent not ─
insert into public.members (workspace_id, user_id, status) values (current_setting('t.e')::uuid, pg_temp.u('a2'), 'active');
select is(pg_temp.native('a2', 'select public.my_database_capabilities()')->>'mcp_eligibility', 'eligible',
  'joining E asks for no new approval');
select ok(pg_temp.native('a2', 'select public.mcp_consent_options()')->'workspaces'
          @> jsonb_build_array(jsonb_build_object('workspace_id', current_setting('t.e'))),
  'E is offered for consent');
select is(pg_temp.says('a2', 'claude-1632', 'e'), 'no_consent', 'and is not joined to the existing consent');
select is(pg_temp.consent('a2', 'claude-1632', 'authz-1632-h2', jsonb_build_array(
  jsonb_build_object('workspace_id', current_setting('t.e'), 'operations', '["get_capabilities","create_reservation"]'::jsonb))),
  'finalized', 'E is consented explicitly');
select is(pg_temp.says('a2', 'claude-1632', 'e'), 'completed', 'then E answers');
select is(pg_temp.says('a2', 'claude-1632', 'a'), 'completed', 'and A is unchanged');
select is(pg_temp.book('c1', 'e')->'error'->>'code', 'request_id_reused',
  'A''s request id sent to E, where booking is exposed and consented, is a conflict, never E''s booking');

-- ── 8. two distinct humans, one effect ───────────────────────────────
select is(pg_temp.consent(p, c, 'authz-1632-' || p || c, jsonb_build_array(
  jsonb_build_object('workspace_id', current_setting('t.a'), 'operations', '["get_capabilities","respond_to_validation"]'::jsonb))),
  'finalized', p || ' consents through ' || c)
  from (values ('a3', 'claude-1632'), ('a3', 'other-1632'), ('a4', 'claude-1632')) v(p, c);
select set_config('t.ev', pg_temp.native('a1', format('select public.request_subscription_change(%L, 50)',
  (select id from public.members where workspace_id = current_setting('t.a')::uuid and user_id = pg_temp.u('a9'))))->>'event_id', true);
select set_config('t.evb', pg_temp.native('a1', format('select public.request_subscription_change(%L, 50)',
  (select id from public.members where workspace_id = current_setting('t.b')::uuid and user_id = pg_temp.u('a9'))))->>'event_id', true);
select set_config('t.v1', pg_temp.validate('a3', 'claude-1632', 'ev', 'b4')::text, true);
select is(current_setting('t.v1')::jsonb->>'status', 'pending_validation', 'V1 through MCP: recorded, still pending');
select is(current_setting('t.v1')::jsonb->'data'->>'effect_applied', 'false', 'and says the effect has not happened');
select is(pg_temp.validate('a3', 'other-1632', 'ev', 'b5')->>'status', 'conflict',
  'V1 again through another assistant does not count');
select is(pg_temp.err('a3', format('select public.respond_to_event(%L, true)', current_setting('t.ev'))),
  'you already decided this event', 'nor natively');
select is((select count(*)::int from public.event_decisions where event_id = current_setting('t.ev')::uuid), 1,
  'one decision on A''s event');
select is((select count(*)::int from public.event_decisions where event_id = current_setting('t.evb')::uuid), 0,
  'none on B''s event of the same type: authority stays in its workspace');
select is(pg_temp.err('a4', format('select public.respond_to_event(%L, true)', current_setting('t.ev'))),
  'no error', 'V2 decides in the app');
select ok((select status from public.events where id = current_setting('t.ev')::uuid) in ('applied', 'confirmed'),
  'two distinct people complete A''s quorum');
select is((select subscription_pct from public.members where workspace_id = current_setting('t.a')::uuid
            and user_id = pg_temp.u('a9')), 50, 'the change applies in A');
select is((select subscription_pct from public.members where workspace_id = current_setting('t.b')::uuid
            and user_id = pg_temp.u('a9')), 100, 'and nowhere else');
select is(pg_temp.validate('a4', 'claude-1632', 'ev', 'b6')->>'status', 'conflict', 'a decided event takes no more votes');

-- ── 9. minimized outputs ─────────────────────────────────────────────
select ok((select count(*) from outputs where body->>'status' = 'completed') >= 8, 'the sweep covers real answers');
select is((select count(*)::int from outputs where body::text ~* 'canary|example\.org|\+33|rue du'), 0,
  'no name, contact or seat label canary in any answer');
select ok(exists (select 1 from outputs, jsonb_array_elements(body->'data'->'items') i
                   where label = 'a2:get_availability' and i->>'seat_id' = current_setting('t.seat')),
  'the seat is still there, by reference');

-- ── 10. fault sensitivity: each check removed must be seen ───────────
reset role;
select is(pg_temp.inject('public.mcp_execute_v1(uuid, uuid, text, jsonb, uuid)'::regprocedure,
  'if p_installation_id is distinct from public.installation_id() then', 'if false then'),
  'injected', 'fault: the installation check removed');
select isnt(coalesce(pg_temp.call('a2', 'claude-1632', current_setting('t.a')::uuid, 'get_capabilities', '{}', null,
  current_setting('t.d2')::uuid)->'error'->>'code', 'served'), 'wrong_installation', 'the D2 probe sees it');
select pg_temp.restore();
select is(pg_temp.inject('public.mcp_execute_v1(uuid, uuid, text, jsonb, uuid)'::regprocedure,
  'if v_grant.id is null then', 'if false then'), 'injected', 'fault: the eligibility check removed');
insert into public.mcp_connections (installation_id, local_user_id, binding_id, client_id)
select public.installation_id(), local_user_id, id, 'claude-1632' from public.identity_bindings
 where local_user_id = pg_temp.u('a8') and status = 'active';
insert into public.mcp_connection_scopes (connection_id, workspace_id, operations, target_ceiling)
select id, current_setting('t.a')::uuid, array['get_capabilities'], 'own'
  from public.mcp_connections where local_user_id = pg_temp.u('a8');
select isnt(pg_temp.says('a8', 'claude-1632', 'a'), 'not_eligible', 'the never-approved probe sees it');
select pg_temp.restore();
select is(pg_temp.says('a8', 'claude-1632', 'a'), 'not_eligible', 'restored: never approved is refused');
select is(pg_temp.inject('public.mcp_execute_v1(uuid, uuid, text, jsonb, uuid)'::regprocedure,
  'if v_scope.connection_id is null or not (p_operation = any (v_scope.operations)) then', 'if false then'),
  'injected', 'fault: the consent check removed');
select isnt(pg_temp.says('a2', 'claude-1632', 'u'), 'no_consent', 'the unconsented probe sees it');
select pg_temp.restore();
select is(pg_temp.inject('public.mcp_execute_v1(uuid, uuid, text, jsonb, uuid)'::regprocedure,
  'where connection_id = v_connection.id and workspace_id = p_workspace_id and revoked_at is null',
  'where connection_id = v_connection.id and revoked_at is null'),
  'injected', 'fault: the consent''s workspace check dropped');
select isnt(pg_temp.says('a2', 'claude-1632', 'u'), 'no_consent', 'the unconsented probe sees it');
select pg_temp.restore();
select is(pg_temp.says('a2', 'claude-1632', 'u'), 'no_consent', 'restored: U is refused again');
select set_config('t.ev2', pg_temp.native('a1', format('select public.request_subscription_change(%L, 70)',
  (select id from public.members where workspace_id = current_setting('t.a')::uuid and user_id = pg_temp.u('a8'))))->>'event_id', true);
select is(pg_temp.inject('public.respond_to_event(uuid, boolean)'::regprocedure,
  'where d.event_id = p_event_id and d.member_id = v_caller.id) then', 'where false) then'),
  'injected', 'fault: one human may count twice');
drop index public.event_decisions_one_per_member;
select pg_temp.err('a3', format('select public.respond_to_event(%L, true)', current_setting('t.ev2')));
select pg_temp.err('a3', format('select public.respond_to_event(%L, true)', current_setting('t.ev2')));
select isnt((select status from public.events where id = current_setting('t.ev2')::uuid), 'pending',
  'the one-human quorum probe sees it');
select pg_temp.restore();
delete from public.event_decisions where event_id = current_setting('t.ev2')::uuid;
create unique index event_decisions_one_per_member on public.event_decisions (event_id, member_id) where member_id is not null;

-- ── 11. scoped revoke, then eligibility revoke ───────────────────────
select pg_temp.native('a2', format($q$select public.revoke_mcp_workspace_scope('claude-1632', %L)$q$, current_setting('t.a')));
select is(pg_temp.says('a2', 'claude-1632', 'a'), 'no_consent', 'A''s scope revoked: A refuses');
select is(pg_temp.says('a2', 'claude-1632', 'b'), 'completed', 'B, same assistant, still answers');
select is(pg_temp.book('c1')->'error'->>'code', 'no_consent', 'the old request id is re-authorised, not replayed');
select pg_temp.native('a6', format($q$select public.revoke_mcp_eligibility(%L, 'conformance')$q$, pg_temp.u('a2')));
select is(pg_temp.says('a2', 'claude-1632', 'b'), 'not_eligible', 'eligibility revoked: B refuses');
select is(pg_temp.says('a2', 'claude-1632', 'e'), 'not_eligible', 'and E');
select is(pg_temp.says('a4', 'claude-1632', 'a'), 'completed', 'V2 is untouched');
select is(pg_temp.bookings(), 2, 'no revocation removed or added a booking');
select is((select count(*)::int from public.mcp_eligibility_grants where installation_id <> public.installation_id())
        + (select count(*)::int from public.mcp_idempotency where installation_id <> public.installation_id())
        + (select count(*)::int from public.database_authority_audit where installation_id <> public.installation_id()),
  0, 'nothing on D1 was written for D2: its own database decides for D');

select * from finish();
rollback;
