-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2137 — a money permission given through a role works.
--
-- The matrix for the three money doors 0362 opened: a member holding the
-- permission only through one of the workspace's own roles acts for
-- another member; the Administrator still does; a member without it is
-- refused, though they still act for themselves; the owner still does.
begin;
select plan(13);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_owner uuid := '00000000-0000-4000-8000-0000000006e1';
  u_role  uuid := '00000000-0000-4000-8000-0000000006e2';
  u_plain uuid := '00000000-0000-4000-8000-0000000006e3';
  u_admin uuid := '00000000-0000-4000-8000-0000000006e4';
  ws uuid; r uuid; m_role uuid; m_plain uuid; svc uuid; rec uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select v.u, '00000000-0000-0000-0000-000000000000', 'authenticated',
         'authenticated', 'pay-' || v.nm || '@deskilo.test', '', now(), now(), now()
    from (values (u_owner, 'owner'), (u_role, 'role'), (u_plain, 'plain'),
                 (u_admin, 'admin')) v(u, nm);
  insert into public.workspaces (name, country_code, currency_code, timezone,
                                 created_by, feature_flags)
  values ('Payment permissions', 'FR', 'EUR', 'Europe/Paris', u_owner,
          '{"customRoles": true}'::jsonb)
  returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_owner, true, true), (ws, u_admin, false, true);
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_role, false, false) returning id into m_role;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_plain, false, false) returning id into m_plain;
  insert into public.workspace_roles (workspace_id, key, permissions, names)
  values (ws, 'tresorier', array['issueInvoices', 'manageServices'],
          '{"en": "Treasurer"}'::jsonb)
  returning id into r;
  insert into public.workspace_role_members (workspace_id, role_id, member_id)
  values (ws, r, m_role);
  insert into public.services (workspace_id, name, price_cents)
  values (ws, 'Coffee', 100) returning id into svc;
  insert into public.usage_records (workspace_id, member_id, period,
    reserved_from, reserved_to, counted_minutes, reserved_minutes)
  values (ws, m_plain, '2031-01', '2031-01-06 09:00+01', '2031-01-06 12:00+01',
          180, 180)
  returning id into rec;

  perform set_config('deskilo.pay.ws', ws::text, false);
  perform set_config('deskilo.pay.svc', svc::text, false);
  perform set_config('deskilo.pay.rec', rec::text, false);
  perform set_config('deskilo.pay.m_role', m_role::text, false);
  perform set_config('deskilo.pay.m_plain', m_plain::text, false);
  perform set_config('deskilo.pay.owner', u_owner::text, false);
  perform set_config('deskilo.pay.role', u_role::text, false);
  perform set_config('deskilo.pay.plain', u_plain::text, false);
  perform set_config('deskilo.pay.admin', u_admin::text, false);
end
$seed$;

create or replace function pg_temp.act_as(p_who text) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('deskilo.pay.' || p_who),
                      'role', 'authenticated')::text, true);
end
$act$;

create or replace function pg_temp.s(p_key text) returns text language sql as $$
  select current_setting('deskilo.pay.' || p_key);
$$;

select pg_temp.seed();

select pg_temp.act_as('role');
select lives_ok(format($$ select public.record_payment(%L, %L, 1000) $$, pg_temp.s('ws'), pg_temp.s('m_plain')),
  'a member holding issueInvoices through a role records a payment for another member');
select lives_ok(format($$ select public.record_service_charge(%L, %L, %L, 1) $$, pg_temp.s('ws'), pg_temp.s('m_plain'), pg_temp.s('svc')),
  'a member holding manageServices through a role adds a service to another member');
select lives_ok(format($$ select public.request_usage_record_delete(%L, 'wrong day') $$, pg_temp.s('rec')),
  'and asks to delete a usage record');

select pg_temp.act_as('plain');
select throws_matching(format($$ select public.record_payment(%L, %L, 1000) $$, pg_temp.s('ws'), pg_temp.s('m_role')),
  'only admins record payments for others', 'a plain member records no payment for another');
select throws_matching(format($$ select public.record_service_charge(%L, %L, %L, 1) $$, pg_temp.s('ws'), pg_temp.s('m_role'), pg_temp.s('svc')),
  'only admins may add services', 'nor adds a service to another');
select throws_matching(format($$ select public.request_usage_record_delete(%L) $$, pg_temp.s('rec')),
  'not allowed', 'nor asks to delete a usage record');
select lives_ok(format($$ select public.record_payment(%L, %L, 1000) $$, pg_temp.s('ws'), pg_temp.s('m_plain')),
  'but still records their own payment');
select lives_ok(format($$ select public.record_service_charge(%L, %L, %L, 1) $$, pg_temp.s('ws'), pg_temp.s('m_plain'), pg_temp.s('svc')),
  'and adds a service to their own account');

select pg_temp.act_as('admin');
select lives_ok(format($$ select public.record_payment(%L, %L, 1000) $$, pg_temp.s('ws'), pg_temp.s('m_plain')),
  'the Administrator still records a payment for another member');
select lives_ok(format($$ select public.record_service_charge(%L, %L, %L, 1) $$, pg_temp.s('ws'), pg_temp.s('m_plain'), pg_temp.s('svc')),
  'and adds a service');

select pg_temp.act_as('owner');
select lives_ok(format($$ select public.record_payment(%L, %L, 1000) $$, pg_temp.s('ws'), pg_temp.s('m_role')),
  'the owner still records a payment for another member');
select lives_ok(format($$ select public.record_service_charge(%L, %L, %L, 1) $$, pg_temp.s('ws'), pg_temp.s('m_role'), pg_temp.s('svc')),
  'and adds a service');

select is(
  (select count(*)::int from public.events
    where workspace_id = pg_temp.s('ws')::uuid
      and type in ('payment', 'service_charge') and status = 'pending'),
  8, 'every act for another member waits for validation, as before');

select * from finish();
rollback;
