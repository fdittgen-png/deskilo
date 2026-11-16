-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4146 (0804): a decision on an event needs the right to read it, for every
-- event type; the owner always decides; the eligible validators counted are
-- those who may read. Under "listed validators" and "the members decide",
-- the validator's rule is itself a way to read. member_has_permission (and
-- member_permission_raw) answer as has_permission (has_permission_raw) does,
-- for every right of the catalogue and every state of a member.
begin;
select plan(18);

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00004146' || lpad(n::text, 4, '0'))::uuid;
$$;
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'decide' || n || '@example.test', '', now(), now(), now()
  from generate_series(1, 20) n;

-- ── the twin answers as has_permission ──
-- 101: custom roles and the administrators' invoicing on, a matrix for every
-- role; 102: neither, no matrix (the defaults)
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions)
values (pg_temp.u(101), 'Rights 4146 a', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
        '{"customRoles": true, "adminInvoicing": true}',
        '{"admin": ["viewFinances", "manageReservations"], "member": ["makeReservations"], "co_owner": ["manageMembers"]}'),
       (pg_temp.u(102), 'Rights 4146 b', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), '{}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, co_owner, status, joined_at)
select pg_temp.u(200 + w * 10 + k), pg_temp.u(100 + w), pg_temp.u(k), k = 1, k in (3, 6), case when k = 2 then 'active' else 'none' end,
       case when k = 6 then 'exited' else 'active' end, '2026-01-01'
  from generate_series(1, 2) w, generate_series(1, 6) k;
-- 4: a member; 5: a member given a role of the business
insert into public.workspace_roles (id, workspace_id, key, permissions, names)
values (pg_temp.u(501), pg_temp.u(101), 'lease', array['manageLease', 'viewFinances'], '{"en": "Lease"}'),
       (pg_temp.u(502), pg_temp.u(102), 'lease', array['manageLease', 'viewFinances'], '{"en": "Lease"}');
insert into public.workspace_role_members (workspace_id, role_id, member_id)
values (pg_temp.u(101), pg_temp.u(501), pg_temp.u(215)), (pg_temp.u(102), pg_temp.u(502), pg_temp.u(225));

create function pg_temp.differences() returns text language plpgsql as $f$
declare r record; v_perm text; a boolean; b boolean; c boolean; d boolean; v_out text := '';
begin
  for r in select m.id, m.user_id, m.workspace_id from public.members m
            where m.workspace_id in (pg_temp.u(101), pg_temp.u(102)) loop
    perform set_config('request.jwt.claims', json_build_object('sub', r.user_id, 'role', 'authenticated')::text, true);
    foreach v_perm in array public.role_permission_catalog() || array['deployToProd', 'issueInvoices', 'unknownRight'] loop
      a := public.has_permission_raw(r.workspace_id, v_perm);
      b := public.member_permission_raw(r.id, v_perm);
      c := public.has_permission(r.workspace_id, v_perm);
      d := public.member_has_permission(r.id, v_perm);
      if a is distinct from b or c is distinct from d then
        v_out := v_out || r.id || ':' || v_perm || ' ';
      end if;
    end loop;
  end loop;
  return nullif(v_out, '');
end $f$;
select is(pg_temp.differences(), null,
  'for every right and every state of a member, the member''s rights answer as has_permission does');
select ok(public.member_has_permission(pg_temp.u(223), 'paymentTermsEdit')
          and public.member_has_permission(pg_temp.u(213), 'issueInvoices')
          and not public.member_has_permission(pg_temp.u(223), 'issueInvoices'),
  'an administrator holds the default rights, and issues invoices where the business lets its administrators');

-- ── the business that decides ──
-- administrators hold the bookings only; 303 also holds the money through a
-- role; 304 records, 305 is named by a rule, 306 a member
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, role_permissions)
values (pg_temp.u(103), 'Decide 4146', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(11), '{"customRoles": true}',
        '{"member": ["makeReservations"], "admin": ["manageReservations", "makeReservations"]}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, joined_at)
values (pg_temp.u(301), pg_temp.u(103), pg_temp.u(11), true, true, 'active', '2026-01-01'),
       (pg_temp.u(302), pg_temp.u(103), pg_temp.u(12), false, true, 'active', '2026-01-01'),
       (pg_temp.u(303), pg_temp.u(103), pg_temp.u(13), false, true, 'active', '2026-01-01'),
       (pg_temp.u(304), pg_temp.u(103), pg_temp.u(14), false, false, 'active', '2026-01-01'),
       (pg_temp.u(305), pg_temp.u(103), pg_temp.u(15), false, false, 'active', '2026-01-01'),
       (pg_temp.u(306), pg_temp.u(103), pg_temp.u(16), false, false, 'active', '2026-01-01');
insert into public.workspace_roles (id, workspace_id, key, permissions, names)
values (pg_temp.u(503), pg_temp.u(103), 'money', array['viewFinances', 'approveExpenses'], '{"en": "Money"}');
insert into public.workspace_role_members (workspace_id, role_id, member_id)
values (pg_temp.u(103), pg_temp.u(503), pg_temp.u(303));
delete from public.validation_policies where workspace_id = pg_temp.u(103);

-- An expense [n] recorded by 304 (for [p_subject]), waiting.
create function pg_temp.expense(n int, p_subject int default 304) returns uuid language sql as $$
  insert into public.events (id, workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
  values (pg_temp.u(400 + n), pg_temp.u(103), 'expense', 'submitted', pg_temp.u(304), pg_temp.u(p_subject),
          '{"amount_cents": 1000, "category": "supplies"}', 'pending')
  returning id;
$$;
create function pg_temp.rule(p_scope text, p_count int default 1, p_listed int[] default '{}') returns void language sql as $$
  delete from public.validation_policies where workspace_id = pg_temp.u(103);
  insert into public.validation_policies (workspace_id, event_type, validator_scope, required_count, eligible_admin_ids)
  values (pg_temp.u(103), 'expense', p_scope, p_count, array(select pg_temp.u(x) from unnest(p_listed) x));
$$;
-- user [n] decides event [p_event]: '' or 'ERR <sqlstate>'
create function pg_temp.decide(n int, p_event uuid, p_accept boolean default true) returns text language plpgsql as $f$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(n), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  perform public.respond_to_event(p_event, p_accept);
  execute 'reset role';
  return '';
exception when others then
  execute 'reset role';
  return 'ERR ' || sqlstate;
end $f$;
create function pg_temp.status(n int) returns text language sql as $$
  select status from public.events where id = pg_temp.u(400 + n);
$$;

-- the administrators decide (the default rule)
select pg_temp.rule('admins');
select pg_temp.expense(1);
select is(pg_temp.decide(12, pg_temp.u(401)), 'ERR DKN01',
  'administrators decide: one whose role does not read expenses is refused');
select is(pg_temp.decide(13, pg_temp.u(401)) || pg_temp.status(1), 'confirmed', 'one who reads them decides');
-- listed validators
select pg_temp.rule('listed', 1, array[305]);
select pg_temp.expense(2);
select is(pg_temp.decide(12, pg_temp.u(402)), 'ERR DKN01', 'listed validators: an administrator not listed is refused');
select is(pg_temp.decide(15, pg_temp.u(402)) || pg_temp.status(2), 'confirmed',
  'the listed member decides: the rule that names them is a way to read');
-- the members decide
select pg_temp.rule('members');
select pg_temp.expense(3);
select is(pg_temp.decide(16, pg_temp.u(403)) || pg_temp.status(3), 'confirmed', 'the members decide: a member decides');
-- the owner always decides, and completes a quorum
select pg_temp.rule('admins', 2);
select pg_temp.expense(4);
select is(pg_temp.decide(13, pg_temp.u(404)) || pg_temp.status(4), 'pending', 'two validations asked: one is not enough');
select is(pg_temp.decide(11, pg_temp.u(404)) || pg_temp.status(4), 'confirmed', 'the owner decides the second');
-- the pool counts those who may read: an expense the owner records for 303,
-- an administrator who reads expenses; besides them only 302, an
-- administrator who does not
select pg_temp.rule('admins');
insert into public.events (id, workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
values (pg_temp.u(405), pg_temp.u(103), 'expense', 'submitted', pg_temp.u(301), pg_temp.u(303),
        '{"amount_cents": 1000, "category": "supplies"}', 'pending');
select is(pg_temp.decide(13, pg_temp.u(405)) || pg_temp.status(5), 'confirmed',
  'with no other validator who may read it, the administrator it is for decides it');
-- 302 now reads the money too
insert into public.workspace_role_members (workspace_id, role_id, member_id)
values (pg_temp.u(103), pg_temp.u(503), pg_temp.u(302));
insert into public.events (id, workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
values (pg_temp.u(406), pg_temp.u(103), 'expense', 'submitted', pg_temp.u(301), pg_temp.u(303),
        '{"amount_cents": 1000, "category": "supplies"}', 'pending');
select is(pg_temp.decide(13, pg_temp.u(406)), 'ERR P0001',
  'with another validator who may read it, the administrator it is for waits for them');
-- the rule in force: in general the members decide; expenses by 305 alone
delete from public.workspace_role_members where member_id = pg_temp.u(302);
delete from public.validation_policies where workspace_id = pg_temp.u(103);
insert into public.validation_policies (workspace_id, event_type, validator_scope, eligible_admin_ids)
values (pg_temp.u(103), null, 'members', '{}'),
       (pg_temp.u(103), 'expense', 'listed', array[pg_temp.u(305)]);
select pg_temp.expense(7);
select is(pg_temp.decide(16, pg_temp.u(407)), 'ERR DKN01',
  'a member the expense rule does not name is refused, whatever the general rule');
select is(pg_temp.decide(15, pg_temp.u(407)) || pg_temp.status(7), 'confirmed', 'the member it names decides');
-- the assistant's target of a validation: an event the caller may not read
-- is answered as one not found
select pg_temp.expense(8);
create function pg_temp.target(n int, p_event uuid) returns text language plpgsql as $f$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', pg_temp.u(n), 'role', 'authenticated')::text, true);
  return coalesce(public.mcp_target(pg_temp.u(103), 'respond_to_validation',
                    jsonb_build_object('event_id', p_event, 'accept', 'true')) ->> 'type', 'none');
end $f$;
select is(pg_temp.target(12, pg_temp.u(408)) || ' ' || pg_temp.target(12, gen_random_uuid()), 'none none',
  'the assistant answers an event its caller may not read as one not found');
select is(pg_temp.target(15, pg_temp.u(408)), 'expense', 'and gives the target to who may read it');

-- every door: the admission desk and the assistant decide through respond_to_event
select ok(pg_get_functiondef('public.respond_to_event(uuid, boolean)'::regprocedure)
            like '%public.event_readable_by(v_caller.id%'
          and pg_get_functiondef('public.decide_workspace_application(uuid, boolean, text, uuid)'::regprocedure)
            like '%public.respond_to_event(%'
          and pg_get_functiondef('public.mcp_op_respond_to_validation(public.mcp_call_context, jsonb)'::regprocedure)
            like '%public.respond_to_event(%',
  'the app, the admission desk and the assistant decide through the one check');
select ok(public.event_readable_by(pg_temp.u(302), pg_temp.u(103), 'member_join', null, null) is not null
          and public.event_readable_by(pg_temp.u(306), pg_temp.u(103), 'payment', null, null) is not null,
  'the rule answers yes or no, never unknown, when an event names nobody');
select ok(not has_function_privilege('authenticated', 'public.event_readable_by(uuid, uuid, text, uuid, uuid)', 'execute')
          and not has_function_privilege('authenticated', 'public.member_permission_raw(uuid, text)', 'execute')
          and not has_function_privilege('authenticated', 'public.member_has_permission(uuid, text)', 'execute')
          and has_function_privilege('service_role', 'public.member_has_permission(uuid, text)', 'execute'),
  'no client asks another member''s rights or reading');

select * from finish();
rollback;
