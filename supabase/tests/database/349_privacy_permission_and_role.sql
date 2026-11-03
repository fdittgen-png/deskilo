-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #3278 (0665) -- the permission and the role of whoever handles the members'
-- personal data.
--   * `managePrivacy` is in the catalogue; an owner and a co-owner hold it by
--     default; an admin and a plain member do not;
--   * a member holds it through the permission matrix, or through the seeded
--     "Personal Data Admin" custom role while customRoles is on (and not when
--     it is off);
--   * `rights_controller` is true for an owner, for viewPersonalData (an admin,
--     as before) and for managePrivacy, false for everyone else;
--   * the role is seeded in a new workspace, once (the function is idempotent),
--     holds only managePrivacy, is not built in, and has its five names.
begin;
select plan(16);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  execute 'set local role authenticated';
end;
$$;
create function pg_temp.u(p text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000003278' || p)::uuid
$$;
create function pg_temp.ws() returns uuid language sql as $$
  select current_setting('deskilo.pv.ws')::uuid
$$;
create function pg_temp.holds(p_user text) returns boolean language plpgsql as $$
declare v boolean;
begin
  perform pg_temp.act_as(pg_temp.u(p_user));
  v := public.has_permission(pg_temp.ws(), 'managePrivacy');
  reset role;
  return v;
end $$;
create function pg_temp.controller(p_user text) returns boolean language plpgsql as $$
declare v boolean;
begin
  perform pg_temp.act_as(pg_temp.u(p_user));
  v := public.rights_controller(pg_temp.ws());
  reset role;
  return v;
end $$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
select pg_temp.u(s), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       s || '@privacy-role.test', '', now(), now(), now()
  from unnest(array['b1', 'b2', 'b3', 'b4', 'b5']) s;
-- b1 owner, b2 plain member, b3 admin, b4 co-owner, b5 member with the role.

select pg_temp.act_as(pg_temp.u('b1'));
select set_config('deskilo.pv.ws', public.create_workspace(
  'Privacy role', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
update public.workspaces set feature_flags = feature_flags || '{"customRoles":true}'
 where id = pg_temp.ws();
insert into public.members (workspace_id, user_id, status, is_admin, co_owner) values
  (pg_temp.ws(), pg_temp.u('b2'), 'active', false, 'none'),
  (pg_temp.ws(), pg_temp.u('b3'), 'active', true, 'none'),
  (pg_temp.ws(), pg_temp.u('b4'), 'active', false, 'active'),
  (pg_temp.ws(), pg_temp.u('b5'), 'active', false, 'none');
insert into public.workspace_role_members (workspace_id, role_id, member_id)
select pg_temp.ws(), r.id, m.id
  from public.workspace_roles r, public.members m
 where r.workspace_id = pg_temp.ws() and r.key = 'personal_data_admin'
   and m.workspace_id = pg_temp.ws() and m.user_id = pg_temp.u('b5');
-- END FIXTURE

select ok(public.role_permission_catalog() @> array['managePrivacy'],
  'the permission catalogue carries managePrivacy');
select ok(pg_temp.holds('b1'), 'the founding owner holds managePrivacy');
select ok(pg_temp.holds('b4'), 'a co-owner holds it by default');
select ok(not pg_temp.holds('b3'), 'an admin does not by default');
select ok(not pg_temp.holds('b2'), 'a plain member does not');
select ok(pg_temp.holds('b5'), 'a member with the Personal Data Admin role holds it (customRoles on)');

update public.workspaces set feature_flags = feature_flags || '{"customRoles":false}'
 where id = pg_temp.ws();
select ok(not pg_temp.holds('b5'), 'the role grants nothing while customRoles is off');
update public.workspaces set feature_flags = feature_flags || '{"customRoles":true}'
 where id = pg_temp.ws();

update public.workspaces set role_permissions = role_permissions || '{"admin":["viewPersonalData","managePrivacy"]}'
 where id = pg_temp.ws();
select ok(pg_temp.holds('b3'), 'the owner can give it to the admin row of the matrix');
update public.workspaces set role_permissions = role_permissions - 'admin'
 where id = pg_temp.ws();

select ok(pg_temp.controller('b1'), 'rights_controller: the owner');
select ok(pg_temp.controller('b5'), 'rights_controller: a managePrivacy holder through the role (red before 0665)');
select ok(pg_temp.controller('b3'), 'rights_controller: an admin still, through viewPersonalData');
select ok(not pg_temp.controller('b2'), 'rights_controller: not a plain member');

select is((select count(*)::int from public.workspace_roles
            where workspace_id = pg_temp.ws() and key = 'personal_data_admin'
              and not builtin and permissions = array['managePrivacy']::text[]), 1,
  'the Personal Data Admin role is seeded in a new workspace, not built in, with managePrivacy only');
select is((select array(select jsonb_object_keys(names) order by 1)
             from public.workspace_roles where workspace_id = pg_temp.ws() and key = 'personal_data_admin'),
  array['de', 'en', 'es', 'fr', 'it'], 'with its five names');

-- An existing workspace (the backfill) and a repeat: one row, the same one.
delete from public.workspace_role_members where workspace_id = pg_temp.ws();
delete from public.workspace_roles where workspace_id = pg_temp.ws() and key = 'personal_data_admin';
select ok(public.ensure_personal_data_admin_role(pg_temp.ws())
          = public.ensure_personal_data_admin_role(pg_temp.ws()),
  'ensure_personal_data_admin_role is idempotent');
select is((select count(*)::int from public.workspace_roles
            where workspace_id = pg_temp.ws() and key = 'personal_data_admin'), 1,
  'and leaves exactly one role per workspace');

select * from finish();
rollback;
