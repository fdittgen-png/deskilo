-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #1789 — the fixture `scripts/db_race_check.sh` races on. Seeded as
-- postgres in ONE transaction the script commits, because the two racing
-- sessions are other connections and can only see committed rows. Every
-- id is the run's own (psql variables from the script), so a second run
-- on the same database builds a second fixture beside the first.
--
-- The MCP half follows supabase/tests/database/82_mcp_workflow_matrices.sql:
-- identity authority, client, runtime, bindings, eligibility, policy,
-- connection and scopes. The three MCP intents that need their human are
-- asked and confirmed HERE, so the race itself is only the run.
--
-- Prints KEY=value lines the script reads back.
\set ON_ERROR_STOP 1
begin;

create function pg_temp.act_as(p_user uuid, p_client text default null) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_strip_nulls(jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2', 'client_id', p_client))::text, true);
  execute 'set local role authenticated';
end;
$$;
create function pg_temp.connect(p_user uuid, p_ops text[]) returns void language plpgsql as $$
begin
  insert into public.mcp_eligibility_grants (installation_id, binding_id, local_user_id, decision_id, decision, status, decided_by, expires_at)
  select public.installation_id(), id, local_user_id, gen_random_uuid(), 'approved', 'active', local_user_id, now() + interval '30 days'
    from public.identity_bindings where local_user_id = p_user and status = 'active';
  insert into public.mcp_connections (installation_id, local_user_id, binding_id, client_id)
  select public.installation_id(), local_user_id, id, 'claude-test' from public.identity_bindings
   where local_user_id = p_user and status = 'active';
  insert into public.mcp_connection_scopes (connection_id, workspace_id, operations, target_ceiling)
  select id, current_setting('race.ws')::uuid, p_ops, 'workspace' from public.mcp_connections
   where local_user_id = p_user and client_id = 'claude-test';
end;
$$;
-- Ask through MCP, then confirm in the app: the retry under the same
-- request id is what the two sessions will race.
create function pg_temp.ask_and_confirm(p_user uuid, p_op text, p_args jsonb, p_request uuid) returns text language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.act_as(p_user, 'claude-test');
  v := public.mcp_execute_v1(current_setting('race.i')::uuid, current_setting('race.ws')::uuid, p_op, p_args, p_request);
  if v->>'status' is distinct from 'requires_confirmation' then
    raise exception '% did not ask its human first: %', p_op, v;
  end if;
  perform pg_temp.act_as(p_user);
  return public.mcp_confirm_action((v->'data'->>'confirmation_id')::uuid, true)::text;
end;
$$;

select set_config('race.i', public.installation_id()::text, false);
-- #1631 — member d's own booking operations, for the revoke races (5–7).
select set_config('race.ops', 'request_invoice_void,request_subscription_change,respond_to_validation,create_reservation,list_my_reservations', false);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select u.id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       u.tag || '-' || :'run' || '@race.deskilo.test', '', now(), now(), now()
  from (values (:'o'::uuid, 'owner'), (:'b'::uuid, 'admin-b'), (:'c'::uuid, 'admin-c'),
               (:'d'::uuid, 'member-d'), (:'r'::uuid, 'member-r')) u(id, tag);
-- 0340 — assistants act only for Google accounts.
insert into auth.identities (id, provider_id, user_id, identity_data, provider, created_at, updated_at)
select gen_random_uuid(), 'google-' || u.id, u.id, jsonb_build_object('sub', 'google-' || u.id), 'google', now(), now()
  from (values (:'o'::uuid), (:'b'::uuid), (:'c'::uuid), (:'d'::uuid), (:'r'::uuid)) u(id);
insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1')
on conflict (singleton) do update set kind = excluded.kind, issuer = excluded.issuer, oidc_provider = null;
insert into public.mcp_clients (client_id, name) values ('claude-test', 'Test assistant') on conflict do nothing;
update public.mcp_runtime set enabled = true;

select pg_temp.act_as(:'o');
select public.finalize_identity_binding();
select set_config('race.ws', public.create_workspace('Race ' || :'run', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, false);
select public.apply_workspace_template(current_setting('race.ws')::uuid, (select id from public.workspace_templates where key = 'tiny'));
select pg_temp.act_as(:'b');
select public.finalize_identity_binding();
-- #1631 — d binds too: the revoke races act for d's assistant.
select pg_temp.act_as(:'d');
select public.finalize_identity_binding();
reset role;

update public.workspaces set street = '1 Fixture Street', city = 'Fixtureville', feature_flags = coalesce(feature_flags, '{}'::jsonb)
  || '{"mcpAccess": true, "invoicing": true, "moneyTab": true, "adminInvoicing": true}',
  booking_rules = booking_rules || '{"open_weekdays":[1,2,3,4,5,6,7],"granularity":"half_day","work_start_minutes":480,"half_boundary_minutes":720,"work_end_minutes":1080}'
 where id = current_setting('race.ws')::uuid;
insert into public.members (workspace_id, user_id, status, is_admin, subscription_pct)
values (current_setting('race.ws')::uuid, :'b', 'active', true, 100),
       (current_setting('race.ws')::uuid, :'c', 'active', true, 100),
       (current_setting('race.ws')::uuid, :'d', 'active', false, 100),
       (current_setting('race.ws')::uuid, :'r', 'active', false, 100);
select set_config('race.m_' || u.tag, m.id::text, false)
  from (values (:'o'::uuid, 'o'), (:'b'::uuid, 'b'), (:'c'::uuid, 'c'), (:'d'::uuid, 'd'), (:'r'::uuid, 'r')) u(id, tag)
  join public.members m on m.user_id = u.id and m.workspace_id = current_setting('race.ws')::uuid;
-- Two admins must agree, so every request below stays pending: the race
-- is about how many requests exist, not about their effect.
insert into public.validation_policies (workspace_id, event_type, required_count, admins_may_validate, validator_scope)
values (current_setting('race.ws')::uuid, 'invoice_void', 2, true, 'admins'),
       (current_setting('race.ws')::uuid, 'subscription_change', 2, true, 'admins');
insert into public.workspace_mcp_policies (workspace_id, installation_id, revision, enabled, operations, target_ceiling)
values (current_setting('race.ws')::uuid, public.installation_id(), 1, true,
        string_to_array(current_setting('race.ops'), ','), 'workspace');
select pg_temp.connect(:'o', string_to_array(current_setting('race.ops'), ','));
select pg_temp.connect(:'b', string_to_array(current_setting('race.ops'), ','));
select pg_temp.connect(:'d', string_to_array(current_setting('race.ops'), ','));

-- Case 2's invoice, and case 4's event: the owner asks, in the app, for
-- member d's share to halve.
select pg_temp.act_as(:'o');
select set_config('race.inv', public.request_invoice_issue(current_setting('race.ws')::uuid, current_setting('race.m_d')::uuid,
  to_char(now(), 'YYYY-MM'), 'full', false, true)->>'invoice_id', false);
select set_config('race.ev', public.request_subscription_change(current_setting('race.m_d')::uuid, 50)->>'event_id', false);
reset role;

-- The three MCP intents, asked and confirmed before the race.
select pg_temp.ask_and_confirm(:'o', 'request_invoice_void',
  jsonb_build_object('invoice_id', current_setting('race.inv'), 'reason', 'duplicate'), :'rq2');
select pg_temp.ask_and_confirm(:'o', 'request_subscription_change',
  jsonb_build_object('member_id', current_setting('race.m_r'), 'pct', 60), :'rq3');
select pg_temp.ask_and_confirm(:'b', 'respond_to_validation',
  jsonb_build_object('event_id', current_setting('race.ev'), 'accept', true), :'rq4');
reset role;

-- A bookable seat, two days out, morning and afternoon.
select set_config('race.seat', (select id::text from public.seats where workspace_id = current_setting('race.ws')::uuid
  order by name limit 1), false);
select set_config('race.day', ((now() at time zone 'Europe/Paris')::date + 2)::text, false);

select 'I=' || current_setting('race.i');
select 'WS=' || current_setting('race.ws');
select 'SEAT=' || coalesce(current_setting('race.seat'), '');
select 'INV=' || coalesce(current_setting('race.inv'), '');
select 'EV=' || coalesce(current_setting('race.ev'), '');
select 'M_' || upper(u) || '=' || current_setting('race.m_' || u) from unnest(array['b', 'c', 'd', 'r']) u;
select 'AM_S=' || ((current_setting('race.day') || ' 08:00')::timestamp at time zone 'Europe/Paris');
select 'AM_E=' || ((current_setting('race.day') || ' 12:00')::timestamp at time zone 'Europe/Paris');
select 'PM_S=' || ((current_setting('race.day') || ' 12:00')::timestamp at time zone 'Europe/Paris');
select 'PM_E=' || ((current_setting('race.day') || ' 18:00')::timestamp at time zone 'Europe/Paris');
-- #1631 — the day after, for the revoke races: a morning that gets booked
-- through MCP (5, replayed in 7) and an afternoon that must not (6). As
-- ISO instants with a Z: mcp_time_arg refuses an offset without minutes.
select 'MCP_S=' || to_char((((current_setting('race.day')::date + 1) || ' 08:00')::timestamp at time zone 'Europe/Paris') at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"');
select 'MCP_E=' || to_char((((current_setting('race.day')::date + 1) || ' 12:00')::timestamp at time zone 'Europe/Paris') at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"');
select 'BLK_S=' || to_char((((current_setting('race.day')::date + 1) || ' 12:00')::timestamp at time zone 'Europe/Paris') at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"');
select 'BLK_E=' || to_char((((current_setting('race.day')::date + 1) || ' 18:00')::timestamp at time zone 'Europe/Paris') at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"');
commit;
