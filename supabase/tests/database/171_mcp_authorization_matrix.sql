-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2391 — the MCP authorization matrix in ONE file: callers × operations
-- × channels, so a later change to the facade cannot reorder a gate
-- unnoticed.
--
-- Callers, all on this installation, all eligible and consented through
-- the same assistant (claude-2391):
--   m1  a plain member whose consent ceiling is `own`
--   m2  a plain member whose consent ceiling is `workspace`
--   ad  an administrator, ceiling `workspace`
--   ou  a person with an approval and a consent row for A but no
--       membership there (a member of the twin T only)
--   the native token (m1 signed in to the app: no client_id)
-- Operations: one read per scope, one write per authority, one native
-- confirmation, both statements, the capability answer with its reasons,
-- and a sweep of every dispatchable operation for the outsider and the
-- native token. Channels: the facade, a direct table read and
-- storage.objects under the delegated token, each beside a positive
-- control under the native token.
--
-- Impersonation is `request.jwt.claims` + `set local role authenticated`:
-- it proves the SQL gates, not OAuth (97_mcp_conformance_journey says
-- what that leaves open). Seeds and read-backs run as postgres.
begin;

create function public.test_google_identity() returns trigger language plpgsql as $g$
begin
  insert into auth.identities (id, provider_id, user_id, identity_data, provider, created_at, updated_at)
  values (gen_random_uuid(), 'google-' || new.id, new.id,
          jsonb_build_object('sub', 'google-' || new.id), 'google', now(), now());
  return new;
end
$g$;
create trigger zz_test_google_identity after insert on auth.users
  for each row execute function public.test_google_identity();
select plan(42);

create function pg_temp.u(p_who text) returns uuid language sql immutable as $$
  select md5('mcp-2391-' || p_who)::uuid;
$$;
create function pg_temp.act_as(p_user uuid, p_client text default null) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_strip_nulls(jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'amr', jsonb_build_array(jsonb_build_object('method', 'oauth')),
    'aal', 'aal2', 'client_id', p_client))::text, true);
  execute 'set local role authenticated';
end;
$$;
-- One facade call as [p_who]; p_client null is the native token.
create function pg_temp.call(p_who text, p_op text, p_args jsonb default '{}', p_ws text default 'a',
                             p_client text default 'claude-2391', p_req uuid default null)
returns jsonb language plpgsql as $$
declare
  r jsonb;
begin
  perform pg_temp.act_as(pg_temp.u(p_who), p_client);
  r := public.mcp_execute_v1(current_setting('t.i')::uuid, current_setting('t.' || p_ws)::uuid, p_op, p_args,
         coalesce(p_req, gen_random_uuid()));
  execute 'reset role';
  return r;
end;
$$;
-- Its outcome word: the refusal code, else the status.
create function pg_temp.says(p_who text, p_op text, p_args jsonb default '{}', p_ws text default 'a',
                             p_client text default 'claude-2391')
returns text language sql as $$
  select coalesce(r->'error'->>'code', r->>'status')
    from (select pg_temp.call(p_who, p_op, p_args, p_ws, p_client) r) q;
$$;
-- A row count as [p_who] through [p_client] (null: the native token).
create function pg_temp.sees(p_who text, p_client text, p_sql text) returns int language plpgsql as $$
declare
  n int;
begin
  perform pg_temp.act_as(pg_temp.u(p_who), p_client);
  execute p_sql into n;
  execute 'reset role';
  return n;
end;
$$;
-- A native statement as [p_who]; its first column as text.
create function pg_temp.native(p_who text, p_sql text) returns text language plpgsql as $$
declare
  v text;
begin
  perform pg_temp.act_as(pg_temp.u(p_who));
  execute p_sql into v;
  execute 'reset role';
  return v;
end;
$$;
-- Every dispatchable operation the catalogue names.
create function pg_temp.ops() returns text[] language sql as $$
  select array_agg(k order by k) from jsonb_each(public.mcp_operation_catalogue()->'operations') e(k, v)
   where (v->>'dispatch')::boolean;
$$;
-- get_capabilities' refusals as {operation: reason}.
create function pg_temp.refused(p_body jsonb) returns jsonb language sql as $$
  select coalesce(jsonb_object_agg(r->>'operation', r->>'reason'), '{}')
    from jsonb_array_elements(p_body->'data'->'refused') r;
$$;
create function pg_temp.event_ids(p_body jsonb) returns text[] language sql as $$
  select coalesce(array_agg(i->>'event_id' order by i->>'event_id'), '{}')
    from jsonb_array_elements(p_body->'data'->'items') i;
$$;

-- ── seed ─────────────────────────────────────────────────────────────
select set_config('t.i', public.installation_id()::text, true);
-- o1 owner of A and T · m1 · m2 · ad · ou (T only) · t1 (T only) · x1
-- database administrator
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(s), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       s || '-2391@deskilo.test', '', now(), now(), now()
  from unnest(array['o1', 'm1', 'm2', 'ad', 'ou', 't1', 'x1']) s;
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1');
insert into public.mcp_clients (client_id, name) values ('claude-2391', 'Matrix assistant')
  on conflict (client_id) do update set status = 'active';
update public.mcp_runtime set enabled = true;
update public.mcp_limits set calls_per_minute = 10000, mutations_per_minute = 1000;
select pg_temp.native('o1', 'select public.finalize_identity_binding()');
select set_config('t.a', pg_temp.native('o1', $q$select public.create_workspace('Matrix A', 'FR', 'EUR',
  'Europe/Paris', 'dev', false, null)$q$), true);
select set_config('t.t', pg_temp.native('o1', $q$select public.create_workspace('Matrix twin', 'FR', 'EUR',
  'Europe/Paris', 'dev', false, null)$q$), true);
select pg_temp.native('o1', format($q$select public.apply_workspace_template(%L,
  (select id from public.workspace_templates where key = 'tiny'))$q$, current_setting('t.a')));
select pg_temp.native(s, 'select public.finalize_identity_binding()')
  from unnest(array['m1', 'm2', 'ad', 'ou', 't1', 'x1']) s;
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb)
    || '{"mcpAccess": true, "invoicing": true, "moneyTab": true, "placeFeedback": true, "levelBooking": true, "adminInvoicing": true}',
  booking_rules = booking_rules || '{"open_weekdays":[1,2,3,4,5,6,7],"granularity":"half_day","work_start_minutes":480,"half_boundary_minutes":720,"work_end_minutes":1080}'
 where id in (current_setting('t.a')::uuid, current_setting('t.t')::uuid);
insert into public.members (workspace_id, user_id, status, is_admin, subscription_pct)
select current_setting('t.' || w)::uuid, pg_temp.u(p), 'active', adm, 100
  from (values ('a', 'm1', false), ('a', 'm2', false), ('a', 'ad', true),
               ('t', 'ou', false), ('t', 't1', false)) f(w, p, adm);
insert into public.validation_policies (workspace_id, event_type, required_count, admins_may_validate, validator_scope)
values (current_setting('t.a')::uuid, 'subscription_change', 1, true, 'admins')
on conflict do nothing;
select set_config('t.' || p, (select id::text from public.members
  where user_id = pg_temp.u(p) and workspace_id = current_setting('t.' || w)::uuid), true)
  from (values ('m1', 'a'), ('m2', 'a'), ('ad', 'a'), ('t1', 't')) f(p, w);
-- One whole desk, office and level beside the template's seats.
update public.desks set bookable_as_whole = true
 where id = (select id from public.desks where workspace_id = current_setting('t.a')::uuid order by id limit 1);
update public.offices set bookable_as_whole = true
 where id = (select id from public.offices where workspace_id = current_setting('t.a')::uuid order by id limit 1);
update public.levels set bookable_as_whole = true
 where id = (select id from public.levels where workspace_id = current_setting('t.a')::uuid order by id limit 1);
select set_config('t.seat', (select id::text from public.seats where workspace_id = current_setting('t.a')::uuid
  order by id limit 1), true);
select set_config('t.day', ((now() at time zone 'Europe/Paris')::date + 3)::text, true);
select set_config('t.am_s', to_char((current_setting('t.day') || ' 08:00')::timestamp at time zone 'Europe/Paris' at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), true);
select set_config('t.am_e', to_char((current_setting('t.day') || ' 12:00')::timestamp at time zone 'Europe/Paris' at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), true);
select set_config('t.pm_s', to_char((current_setting('t.day') || ' 12:00')::timestamp at time zone 'Europe/Paris' at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), true);
select set_config('t.pm_e', to_char((current_setting('t.day') || ' 18:00')::timestamp at time zone 'Europe/Paris' at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), true);
select set_config('t.month', to_char(now() at time zone 'Europe/Paris', 'YYYY-MM'), true);
-- Two pending requests: m1's own, and one about m2 made by ad.
insert into public.events (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
values (current_setting('t.a')::uuid, 'subscription_change', 'submitted', current_setting('t.m1')::uuid,
        current_setting('t.m1')::uuid, '{"pct": 50}', 'pending'),
       (current_setting('t.a')::uuid, 'subscription_change', 'submitted', current_setting('t.ad')::uuid,
        current_setting('t.m2')::uuid, '{"pct": 60}', 'pending');
select set_config('t.e_m1', (select id::text from public.events where actor_member_id = current_setting('t.m1')::uuid), true);
select set_config('t.e_m2', (select id::text from public.events where subject_member_id = current_setting('t.m2')::uuid), true);
-- An avatar of m1, for the storage channel.
insert into storage.objects (bucket_id, name) values ('avatars', pg_temp.u('m1') || '/matrix-2391.png');

-- Approval by the database administrator; A exposes everything but
-- request_refund; T exposes its capabilities.
select public.operator_grant_database_admin(pg_temp.u('x1'), true);
select pg_temp.native(p, 'select public.request_mcp_eligibility()')
  from unnest(array['m1', 'm2', 'ad', 'ou']) p;
select pg_temp.native('x1', format($q$select public.decide_mcp_eligibility(%L, %L, true)$q$,
  pg_temp.u(p), gen_random_uuid())) from unnest(array['m1', 'm2', 'ad', 'ou']) p;
select pg_temp.native('o1', format($q$select public.save_mcp_policy(%L, 0, %L, true, array['get_capabilities'], 'workspace')$q$,
  current_setting('t.' || w), gen_random_uuid())) from unnest(array['a', 't']) w;
update public.workspace_mcp_policies set operations = array_remove(pg_temp.ops(), 'request_refund'),
  target_ceiling = 'workspace'
 where workspace_id = current_setting('t.a')::uuid;
-- Consent through the app, then the scope widened as postgres: m1 keeps
-- `own` and never consented to rate_place; the outsider's consent for T
-- is copied to A, where he is no member.
select pg_temp.native(p, format($q$select public.mcp_prepare_connection('claude-2391', %L,
  jsonb_build_array(jsonb_build_object('workspace_id', %L, 'operations', '["get_capabilities"]'::jsonb)))$q$,
  'authz-2391-' || p, current_setting('t.' || w)))
  from (values ('m1', 'a'), ('m2', 'a'), ('ad', 'a'), ('ou', 't')) f(p, w);
select pg_temp.native(p, format($q$select public.mcp_finalize_connection(%L)$q$, 'authz-2391-' || p))
  from unnest(array['m1', 'm2', 'ad', 'ou']) p;
update public.mcp_connection_scopes s set operations = array_remove(array_remove(pg_temp.ops(), 'request_refund'), 'rate_place'),
  target_ceiling = 'own'
  from public.mcp_connections c where c.id = s.connection_id and c.local_user_id = pg_temp.u('m1');
update public.mcp_connection_scopes s set operations = pg_temp.ops(), target_ceiling = 'workspace'
  from public.mcp_connections c where c.id = s.connection_id and c.local_user_id in (pg_temp.u('m2'), pg_temp.u('ad'));
insert into public.mcp_connection_scopes (connection_id, workspace_id, operations, target_ceiling)
select c.id, current_setting('t.a')::uuid, pg_temp.ops(), 'workspace'
  from public.mcp_connections c where c.local_user_id = pg_temp.u('ou') and c.status = 'active';

select set_config('t.r_m1', pg_temp.call('m1', 'create_reservation', jsonb_build_object('seat_id', current_setting('t.seat'),
  'starts_at', current_setting('t.am_s'), 'ends_at', current_setting('t.am_e')))::text, true);
select set_config('t.r_m2', pg_temp.call('m2', 'create_reservation', jsonb_build_object('seat_id', current_setting('t.seat'),
  'starts_at', current_setting('t.pm_s'), 'ends_at', current_setting('t.pm_e')))::text, true);

-- ── 1. m1, ceiling own ───────────────────────────────────────────────
select is(current_setting('t.r_m1')::jsonb->>'status', 'completed', 'm1 books for herself (self write)');
select is(current_setting('t.r_m2')::jsonb->>'status', 'completed', 'm2 books for himself');
select is((select array_agg(i->>'reservation_id') from jsonb_array_elements(pg_temp.call('m1', 'list_my_reservations',
  jsonb_build_object('from', current_setting('t.am_s'), 'to', current_setting('t.pm_e')))->'data'->'items') i),
  array[current_setting('t.r_m1')::jsonb->'data'->>'reservation_id'],
  'm1 lists exactly her own reservation, not m2''s');
select is(pg_temp.says('m1', 'get_my_statement', jsonb_build_object('period', current_setting('t.month'))),
  'completed', 'm1 reads her own statement');
select is(pg_temp.says('m1', 'get_availability', jsonb_build_object('starts_at', current_setting('t.am_s'),
  'ends_at', current_setting('t.pm_e'))), 'target_ceiling', 'a workspace read stops at the own ceiling');
select is(pg_temp.event_ids(pg_temp.call('m1', 'list_pending_validations')), array[current_setting('t.e_m1')],
  'm1 sees her own pending request under the own ceiling, and only that');
select is(pg_temp.says('m1', 'get_validation', jsonb_build_object('event_id', current_setting('t.e_m1'))),
  'completed', 'm1 reads her own request');
select is(pg_temp.says('m1', 'get_validation', jsonb_build_object('event_id', current_setting('t.e_m2'))),
  'not_found', 'another member''s request does not exist for m1');
select is(pg_temp.says('m1', 'respond_to_validation', jsonb_build_object('event_id', current_setting('t.e_m1'),
  'accept', true)), 'target_ceiling', 'a decision is workspace-wide: refused under the own ceiling');
select is(pg_temp.says('m1', 'request_member_status_change', jsonb_build_object('member_id', current_setting('t.m2'),
  'status', 'paused')), 'forbidden', 'no manageMembers: forbidden');
select is(pg_temp.says('m1', 'request_invoice_issue', jsonb_build_object('member_id', current_setting('t.m1'),
  'period', current_setting('t.month'))), 'forbidden', 'no issueInvoices: forbidden');
select is(pg_temp.says('m1', 'get_member_statement', jsonb_build_object('member_id', current_setting('t.m2'),
  'period', current_setting('t.month'))), 'forbidden', 'no viewFinances: another statement is forbidden');

-- ── 2. get_capabilities says why not ────────────────────────────────
select set_config('t.cap', pg_temp.call('m1', 'get_capabilities')::text, true);
select set_config('t.why', pg_temp.refused(current_setting('t.cap')::jsonb)::text, true);
select is(current_setting('t.why')::jsonb->>'request_refund', 'not_exposed',
  'not in the workspace policy: not_exposed');
select is(current_setting('t.why')::jsonb->>'rate_place', 'no_consent',
  'exposed but never consented: no_consent');
select is(current_setting('t.why')::jsonb->>'request_invoice_issue', 'forbidden',
  'a permission she lacks: forbidden');
select is(current_setting('t.why')::jsonb->>'get_availability', 'target_ceiling',
  'a workspace read under her own ceiling: target_ceiling');
select ok(not (current_setting('t.cap')::jsonb->'data'->'operations' ? 'get_availability')
          and current_setting('t.cap')::jsonb->'data'->'operations' ? 'list_pending_validations'
          and not (current_setting('t.why')::jsonb ? 'list_my_reservations'),
  'what she may do is listed, never refused, and the reverse');

-- ── 3. m2, ceiling workspace, no permission ──────────────────────────
select is((select count(distinct i->>'kind')::int from jsonb_array_elements(pg_temp.call('m2', 'get_availability',
  jsonb_build_object('starts_at', current_setting('t.am_s'), 'ends_at', current_setting('t.pm_e'), 'limit', 100))
  ->'data'->'items') i), 4, 'availability lists seats, desks, offices and levels');
select is((select (count(*) filter (where i->>'kind' = 'desk' and i->>'desk_id' is not null and i->>'seat_id' is null)
                     - count(*) filter (where i->>'kind' <> 'desk'))::int
             from jsonb_array_elements(pg_temp.call('m2', 'get_availability',
  jsonb_build_object('starts_at', current_setting('t.am_s'), 'ends_at', current_setting('t.pm_e'), 'kind', 'desk'))
  ->'data'->'items') i),
  (select count(*)::int from public.desks where workspace_id = current_setting('t.a')::uuid and bookable_as_whole),
  'kind filters to the desks booked as a whole, each named by its desk_id');
select is(pg_temp.event_ids(pg_temp.call('m2', 'list_pending_validations')), array[current_setting('t.e_m2')],
  'm2 sees the request about him, not m1''s');
select is(pg_temp.says('m2', 'get_member_statement', jsonb_build_object('member_id', current_setting('t.m1'),
  'period', current_setting('t.month'))), 'forbidden', 'the workspace ceiling is no permission');

-- ── 4. the administrator ─────────────────────────────────────────────
select is(pg_temp.event_ids(pg_temp.call('ad', 'list_pending_validations')),
  (select array_agg(e order by e) from unnest(array[current_setting('t.e_m1'), current_setting('t.e_m2')]) e),
  'the administrator sees every pending request he may decide');
select is(pg_temp.says('ad', 'get_member_statement', jsonb_build_object('member_id', current_setting('t.m1'),
  'period', current_setting('t.month'))), 'completed', 'viewFinances reads a member''s statement');
select is(pg_temp.says('ad', 'get_member_statement', jsonb_build_object('member_id', current_setting('t.t1'),
  'period', current_setting('t.month'))), 'not_found', 'a member of another workspace does not exist here');
select is(pg_temp.says('ad', 'request_member_status_change', jsonb_build_object('member_id', current_setting('t.t1'),
  'status', 'paused')), 'not_found', 'a foreign target is not_found, never invalid_arguments');
select is(pg_temp.says('ad', 'request_subscription_change', jsonb_build_object('member_id', current_setting('t.t1'),
  'pct', 50)), 'not_found', 'nor a foreign subscription target');
select is(pg_temp.says('ad', 'request_invoice_issue', jsonb_build_object('member_id', current_setting('t.m1'),
  'period', current_setting('t.month'))), 'requires_confirmation', 'a native-confirmation request stops for the app');
select is(pg_temp.says('ad', 'get_availability', jsonb_build_object('starts_at', current_setting('t.am_s'),
  'ends_at', current_setting('t.pm_e'))), 'completed', 'the workspace read under the workspace ceiling');
select is(pg_temp.refused(pg_temp.call('ad', 'get_capabilities')), '{"request_refund": "not_exposed"}'::jsonb,
  'the administrator is refused only what the workspace does not expose');

-- ── 5. the outsider and the native token, every operation ───────────
select is(pg_temp.says('ou', 'get_capabilities'), 'not_a_member', 'the outsider: not_a_member');
select is((select array_agg(op order by op) from unnest(pg_temp.ops()) op
            where pg_temp.says('ou', op, '{}') <> 'not_a_member'), array['request_refund'],
  'every dispatchable operation refuses the outsider as not_a_member (what A does not expose stops earlier)');
select is((select array_agg(op order by op) from unnest(pg_temp.ops()) op
            where pg_temp.says('m1', op, '{}', 'a', null) <> 'no_client'), null,
  'every dispatchable operation refuses the native token as no_client');
-- The operations the sweeps above walk, by name (the coverage gate reads
-- this file as each one's denial evidence): get_capabilities,
-- get_availability, list_my_reservations, get_place, list_my_favorites,
-- get_my_statement, get_member_statement, list_my_invoices,
-- create_reservation, update_reservation, check_in, check_out,
-- cancel_reservation, set_favorite, rate_place,
-- request_reservation_deletion, request_invoice_issue,
-- request_invoice_void, request_refund, request_member_status_change,
-- request_subscription_change, list_pending_validations, get_validation,
-- respond_to_validation.
select ok(pg_temp.ops() @> array['get_capabilities', 'get_availability', 'list_my_reservations', 'get_place',
  'list_my_favorites', 'get_my_statement', 'get_member_statement', 'list_my_invoices', 'create_reservation',
  'update_reservation', 'check_in', 'check_out', 'cancel_reservation', 'set_favorite', 'rate_place',
  'request_reservation_deletion', 'request_invoice_issue', 'request_invoice_void', 'request_refund',
  'request_member_status_change', 'request_subscription_change', 'list_pending_validations', 'get_validation',
  'respond_to_validation'], 'the sweeps walk every operation named above');

-- ── 6. the other channels under the delegated token ─────────────────
select ok(pg_temp.sees('m1', null, 'select count(*)::int from public.reservations') >= 1,
  'positive control: the app reads m1''s reservations');
select is(pg_temp.sees('m1', 'claude-2391', 'select count(*)::int from public.reservations'), 0,
  'the delegated token reads no reservation directly');
select ok(pg_temp.sees('ad', null, 'select count(*)::int from public.members') >= 3,
  'positive control: the app reads the members');
select is(pg_temp.sees('ad', 'claude-2391', 'select count(*)::int from public.members'), 0,
  'the administrator''s delegated token reads no member directly');
select is(pg_temp.sees('ad', 'claude-2391', 'select count(*)::int from public.events'), 0,
  'nor an event');
select is(pg_temp.sees('m1', 'claude-2391', 'select count(*)::int from public.invoices'), 0,
  'nor an invoice');
select is(pg_temp.sees('m1', null, $q$select count(*)::int from storage.objects where name like '%matrix-2391%'$q$), 1,
  'positive control: the app reads m1''s avatar');
select is(pg_temp.sees('m1', 'claude-2391', $q$select count(*)::int from storage.objects where name like '%matrix-2391%'$q$), 0,
  'the delegated token reads no stored object');
select ok((select count(*) from pg_tables t where t.schemaname = 'public' and t.rowsecurity
             and not exists (select 1 from pg_policies p where p.schemaname = 'public' and p.tablename = t.tablename
                               and p.policyname = 'mcp_delegated_deny' and p.permissive = 'RESTRICTIVE')) = 0,
  'every RLS table in public carries the restrictive mcp_delegated_deny');

select * from finish();
rollback;
