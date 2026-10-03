-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2010 / 0320: a level reorder is one command. The owner saves a whole
-- permutation or changes nothing: a stale expected order is a conflict, a
-- duplicate / foreign / missing id is refused, a member and an admin
-- without manageSites are refused (0363 gave the arrangement to that
-- permission; 148 proves the holders), and a failure half-way through
-- leaves every original value.
-- Callers run as `authenticated`; seeds run as postgres.
begin;
select plan(14);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;

create function pg_temp.order_of(p_ws uuid) returns text language sql as $$
  select string_agg(name, ',' order by sort_order, id) from public.levels where workspace_id = p_ws;
$$;

create function pg_temp.ids(p_names text[]) returns uuid[] language sql as $$
  select array_agg(l.id order by n.ord)
    from unnest(p_names) with ordinality n(name, ord)
    join public.levels l on l.name = n.name and l.workspace_id = current_setting('t.ws')::uuid;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000002010a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner-2010@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000002010a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'admin-2010@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000002010a3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'member-2010@deskilo.test', '', now(), now(), now());

select pg_temp.act_as('00000000-0000-4000-8000-0000002010a1');
select set_config('t.ws', public.create_workspace('Level Order', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select set_config('t.other', public.create_workspace('Other Order', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
insert into public.members (workspace_id, user_id, status, is_admin) values
 (current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000002010a2', 'active', true),
 (current_setting('t.ws')::uuid, '00000000-0000-4000-8000-0000002010a3', 'active', false);
-- The Administrator's row of the matrix without manageSites (#2137/0363).
update public.workspaces set role_permissions = '{"admin": ["manageMembers"]}'::jsonb
 where id = current_setting('t.ws')::uuid;
delete from public.levels where workspace_id in (current_setting('t.ws')::uuid, current_setting('t.other')::uuid);
insert into public.levels (workspace_id, name, sort_order) values
 (current_setting('t.ws')::uuid, 'A', 0), (current_setting('t.ws')::uuid, 'B', 1), (current_setting('t.ws')::uuid, 'C', 2),
 (current_setting('t.other')::uuid, 'X', 0);

-- ── the owner saves a whole permutation in one command ──────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000002010a1');
select is(public.reorder_levels(current_setting('t.ws')::uuid, pg_temp.ids('{C,A,B}'), pg_temp.ids('{A,B,C}'))->>'status',
  'saved', 'C/A/B from A/B/C is saved');
select is(pg_temp.order_of(current_setting('t.ws')::uuid), 'C,A,B', 'exactly C=0, A=1, B=2');

-- ── a stale expected order is a conflict, and writes nothing ────────
select is(public.reorder_levels(current_setting('t.ws')::uuid, pg_temp.ids('{B,C,A}'), pg_temp.ids('{A,B,C}'))->>'status',
  'conflict', 'a second editor saving from the old order conflicts');
select is(pg_temp.order_of(current_setting('t.ws')::uuid), 'C,A,B', 'the conflicting save changed nothing');
select is(jsonb_array_length(public.reorder_levels(current_setting('t.ws')::uuid, pg_temp.ids('{B,C,A}'), pg_temp.ids('{A,B,C}'))->'current'),
  3, 'the conflict names the current order');

-- ── not a permutation: refused, nothing written ─────────────────────
select is(public.reorder_levels(current_setting('t.ws')::uuid, pg_temp.ids('{C,C,A}'), pg_temp.ids('{C,A,B}'))->>'reason',
  'not_a_permutation', 'a duplicate id is refused');
select is(public.reorder_levels(current_setting('t.ws')::uuid, pg_temp.ids('{C,A}'), pg_temp.ids('{C,A,B}'))->>'reason',
  'not_a_permutation', 'a missing level is refused');
select is(public.reorder_levels(current_setting('t.ws')::uuid,
    pg_temp.ids('{C,A}') || (select id from public.levels where name = 'X' and workspace_id = current_setting('t.other')::uuid),
    pg_temp.ids('{C,A,B}'))->>'reason',
  'not_a_permutation', 'a foreign workspace''s level is refused');
select is(public.reorder_levels(current_setting('t.ws')::uuid, '{}', pg_temp.ids('{C,A,B}'))->>'reason',
  'not_a_permutation', 'an empty order is refused');
select is(pg_temp.order_of(current_setting('t.ws')::uuid), 'C,A,B', 'no refusal wrote anything');

-- ── nobody but the owner arranges the levels ────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000002010a2');
select throws_ok($$select public.reorder_levels(current_setting('t.ws')::uuid, pg_temp.ids('{A,B,C}'), pg_temp.ids('{C,A,B}'))$$,
  'P0001', 'only the owner arranges the levels', 'an admin without manageSites is refused, like levels_write');
select pg_temp.act_as('00000000-0000-4000-8000-0000002010a3');
select throws_ok($$select public.reorder_levels(current_setting('t.ws')::uuid, pg_temp.ids('{A,B,C}'), pg_temp.ids('{C,A,B}'))$$,
  'P0001', 'only the owner arranges the levels', 'a member is refused');

-- ── a failure half-way leaves every original value ──────────────────
reset role;
create function pg_temp.fail_on_b() returns trigger language plpgsql as $$
begin
  if new.name = 'B' then raise exception 'injected failure on B'; end if;
  return new;
end;
$$;
create trigger zz_fail_on_b before update on public.levels for each row execute function pg_temp.fail_on_b();
select pg_temp.act_as('00000000-0000-4000-8000-0000002010a1');
select throws_ok($$select public.reorder_levels(current_setting('t.ws')::uuid, pg_temp.ids('{A,B,C}'), pg_temp.ids('{C,A,B}'))$$,
  'P0001', 'injected failure on B', 'the injected failure on the second level surfaces');
reset role;
drop trigger zz_fail_on_b on public.levels;
select is(pg_temp.order_of(current_setting('t.ws')::uuid), 'C,A,B', 'after the failure every original value persists');

select * from finish();
rollback;
