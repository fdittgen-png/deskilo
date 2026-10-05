-- SPDX-License-Identifier: AGPL-3.0-or-later
-- 0377: one mandatory base role; other roles add and never take away.
begin;
select plan(6);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000000298a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'br-own@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000000298a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'br-mem@deskilo.test', '', now(), now(), now());
delete from public.identity_authority;
insert into public.identity_authority (kind, issuer) values ('native', 'https://auth.deskilo.test/auth/v1');

select pg_temp.act_as('00000000-0000-4000-8000-0000000298a1');
select public.finalize_identity_binding();
select set_config('t.a', public.create_workspace('BR', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select pg_temp.act_as('00000000-0000-4000-8000-0000000298a2');
select public.finalize_identity_binding();
reset role;
update public.workspaces set role_permissions = '{"member":["makeReservations"]}'::jsonb,
  feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"customRoles": true}' where id = current_setting('t.a')::uuid;
insert into public.members (workspace_id, user_id, status) values
 (current_setting('t.a')::uuid, '00000000-0000-4000-8000-0000000298a2', 'active');
select set_config('t.m', (select id::text from public.members where user_id = '00000000-0000-4000-8000-0000000298a2' and workspace_id = current_setting('t.a')::uuid), true);
select set_config('t.o', (select id::text from public.members where user_id = '00000000-0000-4000-8000-0000000298a1' and workspace_id = current_setting('t.a')::uuid), true);
insert into public.workspace_roles (workspace_id, key, permissions, names)
values (current_setting('t.a')::uuid, 'treso', array['viewFinances'], '{"en":"Treasurer"}');
insert into public.workspace_role_members (workspace_id, role_id, member_id)
select current_setting('t.a')::uuid, r.id, current_setting('t.m')::uuid from public.workspace_roles r
 where r.workspace_id = current_setting('t.a')::uuid and r.key = 'treso';

select pg_temp.act_as('00000000-0000-4000-8000-0000000298a2');
select set_config('t.base_user', public.member_base_role(current_setting('t.m')::uuid), true);
select set_config('t.cum_a', public.has_permission(current_setting('t.a')::uuid, 'makeReservations')::text, true);
select set_config('t.cum_b', public.has_permission(current_setting('t.a')::uuid, 'viewFinances')::text, true);
select set_config('t.cum_c', public.has_permission(current_setting('t.a')::uuid, 'manageRoles')::text, true);
reset role;
select pg_temp.act_as('00000000-0000-4000-8000-0000000298a1');
select set_config('t.base_owner', public.member_base_role(current_setting('t.o')::uuid), true);
reset role;

select is(current_setting('t.base_user'), 'user', 'a member with no flag holds the User base role');
select is(current_setting('t.base_owner'), 'owner', 'the owner holds the Owner base role');
select is(current_setting('t.cum_a'), 'true', 'the base role keeps its own permissions');
select is(current_setting('t.cum_b'), 'true', 'another role adds its own on top');
select is(current_setting('t.cum_c'), 'false', 'and grants nothing it does not name');
select throws_ok(format($q$update public.members set co_owner = 'active' where id = %L$q$, current_setting('t.o')),
  '23514', null, 'a member cannot be the owner and a co-owner at once');

select * from finish();
rollback;
