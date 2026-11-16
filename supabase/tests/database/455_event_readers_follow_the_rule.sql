-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4143 (0803): the assistant's validation reads, the personal export and the
-- admission desk follow each event type's reading rule, and a validator's
-- rule is read as the decision reads it -- the type's own rule, else the
-- general one. Each case below fails without the rule it names.
begin;
select plan(30);

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00004143' || lpad(n::text, 4, '0'))::uuid;
$$;
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'readers' || n || '@example.test', '', now(), now(), now()
  from generate_series(1, 7) n;
-- administrators hold the bookings and nothing of money or members by their role
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions)
values (pg_temp.u(101), 'Readers 4143', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{"customRoles": true}',
        '{"member": ["makeReservations"], "admin": ["manageReservations","makeReservations"]}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at)
values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active', '2026-01-01'),
       (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, true, 'active', '2026-01-01'),
       (pg_temp.u(203), pg_temp.u(101), pg_temp.u(3), false, true, 'active', '2026-01-01'),
       (pg_temp.u(204), pg_temp.u(101), pg_temp.u(4), false, false, 'active', '2026-01-01'),
       (pg_temp.u(205), pg_temp.u(101), pg_temp.u(5), false, false, 'pending', '2026-01-01'),
       (pg_temp.u(206), pg_temp.u(101), pg_temp.u(6), false, false, 'active', '2026-01-01'),
       (pg_temp.u(207), pg_temp.u(101), pg_temp.u(7), false, false, 'pending', '2026-01-01');
-- 203 holds the money and the members through a role of the business
insert into public.workspace_roles (id, workspace_id, key, permissions, names)
values (pg_temp.u(501), pg_temp.u(101), 'office', array['viewFinances', 'manageMembers'], '{"en": "Office"}');
insert into public.workspace_role_members (workspace_id, role_id, member_id)
values (pg_temp.u(101), pg_temp.u(501), pg_temp.u(203));
-- the business decides joins by its administrators (the default scope)
delete from public.validation_policies where workspace_id = pg_temp.u(101);
insert into public.validation_policies (workspace_id, event_type, validator_scope)
values (pg_temp.u(101), 'member_join', 'admins');
-- 206's declared payment; 205's and 207's requests to join; incidents told to
-- 203 (who does not hold the privacy right) and to the owner; a pending one
-- of 203's
insert into public.events (id, workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
values (pg_temp.u(301), pg_temp.u(101), 'payment', 'submitted', pg_temp.u(206), pg_temp.u(206), '{"amount_cents": 500}', 'pending'),
       (pg_temp.u(302), pg_temp.u(101), 'member_join', 'submitted', pg_temp.u(205), pg_temp.u(205), '{}', 'pending'),
       (pg_temp.u(303), pg_temp.u(101), 'privacy_incident', 'created', pg_temp.u(201), pg_temp.u(203), '{"kind": "other", "note": "n"}', 'applied'),
       (pg_temp.u(304), pg_temp.u(101), 'privacy_incident', 'created', pg_temp.u(201), pg_temp.u(201), '{"kind": "other", "note": "n"}', 'applied'),
       (pg_temp.u(305), pg_temp.u(101), 'member_join', 'submitted', pg_temp.u(207), pg_temp.u(207), '{}', 'pending'),
       (pg_temp.u(306), pg_temp.u(101), 'privacy_incident', 'created', pg_temp.u(203), pg_temp.u(203), '{"kind": "other", "note": "n"}', 'pending');
insert into public.workspace_applications (event_id, workspace_id, applicant_user_id)
values (pg_temp.u(302), pg_temp.u(101), pg_temp.u(5)), (pg_temp.u(305), pg_temp.u(101), pg_temp.u(7))
on conflict do nothing;

-- [p_sql] as user [n]: its answer as text, or 'ERR <sqlstate>'.
create function pg_temp.as_user(n int, p_sql text) returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(n), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  execute p_sql into v;
  execute 'reset role';
  return coalesce(v, 'null');
exception when others then
  execute 'reset role';
  return 'ERR ' || sqlstate;
end $f$;
-- The assistant's read [p_op] for member [n], in their session or under a
-- delegated token.
create function pg_temp.assistant(n int, p_op text, p_args jsonb, p_delegated boolean default false) returns jsonb language plpgsql as $f$
declare v_member public.members;
begin
  perform set_config('request.jwt.claims',
    (json_build_object('sub', pg_temp.u(n), 'role', 'authenticated')::jsonb
       || case when p_delegated then '{"client_id": "delegated"}'::jsonb else '{}'::jsonb end)::text, true);
  select * into v_member from public.members where id = pg_temp.u(200 + n);
  return public.mcp_read_v1(pg_temp.u(101), v_member, p_op, p_args);
end $f$;
create function pg_temp.pending_types(n int, p_wide boolean, p_delegated boolean default false) returns text[] language sql as $$
  select coalesce(array_agg(distinct i ->> 'type' order by i ->> 'type'), '{}')
    from jsonb_array_elements(pg_temp.assistant(n, 'list_pending_validations',
           jsonb_build_object('_ceiling', case when p_wide then 'workspace' else 'self' end), p_delegated) -> 'items') i;
$$;
create function pg_temp.one(n int, p_event int) returns text language sql as $$
  select coalesce(r ->> 'type', r ->> 'refused')
    from pg_temp.assistant(n, 'get_validation', jsonb_build_object('event_id', pg_temp.u(p_event))) r;
$$;
create function pg_temp.exported(n int, p_type text) returns int language sql as $$
  select pg_temp.as_user(n, format($q$select (select count(*) from jsonb_array_elements(public.export_my_data(%L) -> 'events') e
                                              where e ->> 'type' = %L)::text$q$, pg_temp.u(101), p_type))::int;
$$;
create function pg_temp.discusses(n int, p_event int default 302) returns text language sql as $$
  select pg_temp.as_user(n, format('select public.can_discuss_workspace_application(%L)::text', pg_temp.u(p_event)));
$$;
create function pg_temp.lists_application(n int, p_event int default 302) returns text language sql as $$
  select pg_temp.as_user(n, format($q$select (select count(*) from jsonb_array_elements(public.my_workspace_applications(null, null)) a
                                              where a ->> 'id' = %L)::text$q$, pg_temp.u(p_event)));
$$;
create function pg_temp.reads_event(n int, p_event int) returns text language sql as $$
  select pg_temp.as_user(n, format('select count(*)::text from public.events where id = %L', pg_temp.u(p_event)));
$$;

-- ── the assistant's validation reads ──
select is(pg_temp.pending_types(2, true), '{}'::text[],
  'an administrator whose role does not read payments or requests to join lists none of them');
select is(pg_temp.pending_types(2, true, true), '{}'::text[], 'nor under a delegated token');
select is(pg_temp.one(2, 301), 'not_found', 'nor reads one of them');
select is(pg_temp.pending_types(3, true), array['member_join', 'payment'],
  'an administrator who holds the rights lists them');
select is(pg_temp.one(3, 301), 'payment', 'and reads one');
select is(pg_temp.pending_types(6, false), array['payment'], 'a member''s own request still comes');
select is(pg_temp.pending_types(3, false), '{}'::text[],
  'an own event of a type with a restrictive rule comes only to who holds its right');
select is(pg_temp.one(3, 306), 'not_found', 'nor is it read');

-- ── the personal export ──
select is(pg_temp.exported(3, 'privacy_incident'), 0,
  'a member who does not hold the privacy right does not export the incidents told to them');
select is(pg_temp.exported(1, 'privacy_incident'), 2, 'the owner, who holds it, exports the one told to her and the one she recorded');

-- ── the admission desk, under the administrators' rule ──
select is(pg_temp.discusses(2), 'false', 'an administrator without the right to manage the members does not discuss an application');
select is(pg_temp.lists_application(2), '0', 'nor finds it among the applications');
select is(pg_temp.as_user(2, format('select public.send_workspace_application_message(%L, %L)::text', pg_temp.u(302), 'hello')),
  'ERR P0001', 'nor writes in it');
select is(pg_temp.as_user(2, format('select public.respond_to_event(%L, true)::text', pg_temp.u(302))),
  'ERR DKN01', 'nor decides it');
select is(pg_temp.as_user(2, format('select public.decide_workspace_application(%L, true)::text', pg_temp.u(205))),
  'ERR DKN01', 'nor through the admission desk');
select is(pg_temp.discusses(3) || ' ' || pg_temp.lists_application(3), 'true 1',
  'an administrator with the right reads it');
select is(pg_temp.discusses(5), 'true', 'and the applicant');

-- ── a general rule beside the type's own ──
-- the members decide in general; requests to join are decided by 204 alone
insert into public.validation_policies (workspace_id, event_type, validator_scope)
values (pg_temp.u(101), null, 'members');
update public.validation_policies set validator_scope = 'listed', eligible_admin_ids = array[pg_temp.u(204)]
 where workspace_id = pg_temp.u(101) and event_type = 'member_join';
select is(pg_temp.discusses(6, 305) || ' ' || pg_temp.lists_application(6, 305), 'false 0',
  'a member the request-to-join rule does not name neither discusses nor finds the application, whatever the general rule');
select is(pg_temp.as_user(6, format('select public.send_workspace_application_message(%L, %L)::text', pg_temp.u(305), 'hello')),
  'ERR P0001', 'nor writes in it');
select is(pg_temp.reads_event(6, 305), '0', 'nor reads the request through the events');
select is(pg_temp.pending_types(6, true), array['payment'],
  'nor through the assistant, where the general rule shows the payment');
select is(pg_temp.discusses(4, 305) || ' ' || pg_temp.lists_application(4, 305) || ' ' || pg_temp.reads_event(4, 305), 'true 1 1',
  'the member the rule names discusses, finds and reads it');
select is(pg_temp.as_user(4, format('select public.send_workspace_application_message(%L, %L)::text', pg_temp.u(305), 'welcome')),
  '', 'writes in it');
select is(pg_temp.as_user(4, format('select public.decide_workspace_application(%L, true)::text', pg_temp.u(207))),
  '', 'and decides it');
select is((select status from public.events where id = pg_temp.u(305)) || ' '
          || (select status from public.members where id = pg_temp.u(207)),
  'confirmed active', 'the request is confirmed and the applicant a member');
-- ── a validator's rule reads what waits for a decision ──
select is((select coalesce(string_agg(t, ', ' order by t), '') from (
             select distinct (regexp_matches(pg_get_constraintdef(c.oid), '''([a-z_]+)''', 'g'))[1] as t
               from pg_constraint c where c.conname = 'events_type_check' and c.conrelid = 'public.events'::regclass) x
            where public.event_type_waits_for_decision(t) is null), '',
  'every event type is classified: it waits for a decision, or it is a notice');
-- the owner's notices, and an expense of 204 waiting
insert into public.events (id, workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
values (pg_temp.u(311), pg_temp.u(101), 'credential_change', 'modified', pg_temp.u(201), pg_temp.u(201), '{}', 'applied'),
       (pg_temp.u(312), pg_temp.u(101), 'invoice_issued', 'created', pg_temp.u(201), pg_temp.u(201), '{}', 'applied'),
       (pg_temp.u(313), pg_temp.u(101), 'settlement_review', 'created', pg_temp.u(201), pg_temp.u(201), '{}', 'applied'),
       (pg_temp.u(314), pg_temp.u(101), 'expense', 'submitted', pg_temp.u(204), pg_temp.u(204), '{"amount_cents": 100}', 'pending');
create function pg_temp.types_read(n int) returns text language sql as $$
  select pg_temp.as_user(n, format(
    $q$select coalesce(string_agg(type, ',' order by type), '') from public.events
         where workspace_id = %L and id in (%L, %L, %L, %L)$q$,
    pg_temp.u(101), pg_temp.u(311), pg_temp.u(312), pg_temp.u(313), pg_temp.u(314)));
$$;
-- the general rule is still "the members decide"
select is(pg_temp.types_read(6), 'expense',
  'under a general rule the members decide, a member reads the expense waiting for them, none of the notices');
update public.validation_policies set validator_scope = 'admins', eligible_admin_ids = array[pg_temp.u(202)]
 where workspace_id = pg_temp.u(101) and event_type is null;
select is(pg_temp.types_read(2), 'expense',
  'an administrator a general rule names reads the expense, none of the notices');
select is(pg_temp.types_read(6), '', 'and a member that rule does not name reads none of them');

select ok(not has_function_privilege('authenticated', 'public.effective_validation_policy(uuid, text)', 'execute')
          and not has_function_privilege('authenticated', 'public.event_readable(uuid, text, uuid, uuid)', 'execute'),
  'no client asks the rule in force or the reading rule directly');

select * from finish();
rollback;
