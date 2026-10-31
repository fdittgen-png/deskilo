-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2563 C1 (9999): the personal account names a workspace by its qualified
-- reference (installation id : local id). The legacy UUID writers
-- (set_workspace_favorite, set_visibility, profiles.default_workspace_id)
-- get the reference stamped by the server; a reference to another
-- installation keeps no local id, even when its local UUID equals a
-- workspace hosted here, and authorizes nothing; an unknown local or
-- malformed reference is refused. The readers answer for the caller only:
-- my_personal_workspace_refs_v1 (status as the membership row says it,
-- local vs unavailable freshness, a label only where the caller may read
-- one, no role), my_visibility_network_v1 (choices by reference, legacy
-- my_visibility unchanged for local ones) and export_my_personal_data_v1
-- (no workspace needed, no workspace records). anon holds no EXECUTE and
-- a call without a session is refused.
--
-- One database holds one installation (installation_identity is a
-- singleton): the other installation is a foreign id in a reference, as
-- in the topology tests; nothing here proves a cross-installation fact
-- (#2563 C2).
begin;
select plan(46);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated')::text, true);
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.nobody() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', '', true);
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.sqlstate_of(p_sql text) returns text language plpgsql as $$
begin
  execute p_sql;
  return '';
exception when others then
  return sqlstate;
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00002563a' || lpad(n::text, 3, '0'))::uuid;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.w(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00002563c' || lpad(n::text, 3, '0'))::uuid;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
-- A reference on this installation, and one on another installation.
create function pg_temp.here(n int) returns text language sql as $$
  select public.installation_id()::text || ':' || pg_temp.w(n)::text;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.away(n int) returns text language sql as $$
  select '00000000-0000-4000-8000-0000025630ff:' || pg_temp.w(n)::text;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;
-- The caller's reference to [p_ref], from the reader.
create function pg_temp.ref_of(p jsonb, p_ref text) returns jsonb language sql as $$
  select e from jsonb_array_elements(p -> 'refs') e where e ->> 'network_id' = p_ref;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- ── fixtures, by direct insert ───────────────────────────────────────────
-- u1: the caller, active in One, exited from Two. u2: active in One.
-- u3: a member of nothing. Listed is in the public directory; Hidden is not.
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(i), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || i || '@personal-refs.test', '', now(), now(), now()
  from generate_series(1, 3) i;
insert into public.profiles (id, display_name)
select pg_temp.u(i), 'Person ' || i from generate_series(1, 3) i
on conflict (id) do nothing;

insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, environment, booking_rules, feature_flags) values
 (pg_temp.w(1), 'One', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'dev', '{}', '{}'),
 (pg_temp.w(2), 'Two', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(2), 'dev', '{}', '{}'),
 (pg_temp.w(3), 'Listed', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(2), 'dev', '{}', '{}'),
 (pg_temp.w(4), 'Hidden', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(2), 'dev', '{}', '{}');
update public.workspaces set visibility_set_at = now() where id = pg_temp.w(3);
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
 ('00000000-0000-4000-8000-00002563d001', pg_temp.w(1), pg_temp.u(1), true, true, 'active'),
 ('00000000-0000-4000-8000-00002563d002', pg_temp.w(2), pg_temp.u(1), false, false, 'exited'),
 ('00000000-0000-4000-8000-00002563d003', pg_temp.w(1), pg_temp.u(2), false, false, 'active'),
 ('00000000-0000-4000-8000-00002563d004', pg_temp.w(2), pg_temp.u(2), true, true, 'active');

-- ── the columns and the grants ───────────────────────────────────────────
select has_column('public', 'profiles', 'default_workspace_network_id', 'the default workspace has a reference');
select has_column('public', 'workspace_favorites', 'workspace_network_id', 'a favourite has a reference');
select has_column('public', 'account_field_audience_spaces', 'workspace_network_id', 'a chosen space has a reference');
select ok(not has_function_privilege('anon', 'public.my_personal_workspace_refs_v1()', 'execute')
          and not has_function_privilege('anon', 'public.my_visibility_network_v1()', 'execute')
          and not has_function_privilege('anon', 'public.export_my_personal_data_v1()', 'execute'),
          'anon may call none of the three readers');
select ok(has_function_privilege('authenticated', 'public.my_personal_workspace_refs_v1()', 'execute')
          and has_function_privilege('authenticated', 'public.my_visibility_network_v1()', 'execute')
          and has_function_privilege('authenticated', 'public.export_my_personal_data_v1()', 'execute'),
          'a signed-in person may call the three readers');
select ok(not has_function_privilege('authenticated', 'public.local_workspace_of_ref(text)', 'execute')
          and not has_function_privilege('authenticated', 'public.personal_home_descriptor()', 'execute'),
          'the helpers are the server''s');
select ok(not has_table_privilege('authenticated', 'public.workspace_favorites', 'insert')
          and not has_table_privilege('anon', 'public.workspace_favorites', 'select'),
          'favourites are still written only through the RPC and never read anonymously');

-- ── the legacy writers get the reference stamped ─────────────────────────
select pg_temp.act_as(pg_temp.u(1));
select public.set_workspace_favorite(pg_temp.w(1), true);
select is((select workspace_network_id from public.workspace_favorites
            where user_id = pg_temp.u(1) and workspace_id = pg_temp.w(1)),
          (select network_id from public.workspaces where id = pg_temp.w(1)),
          'set_workspace_favorite stores the workspace''s own network id');
select public.set_workspace_favorite(pg_temp.w(1), true);
select is((select count(*)::int from public.workspace_favorites where user_id = pg_temp.u(1)), 1,
          'favouriting twice keeps one row (the local arbiter still holds)');
select public.set_visibility('identity', 'chosen_spaces', array[pg_temp.w(1)]);
select is((select workspace_network_id from public.account_field_audience_spaces
            where user_id = pg_temp.u(1) and field = 'identity'),
          pg_temp.here(1), 'set_visibility stores the chosen space by reference');

-- A client value is replaced by the workspace's own record.
select pg_temp.nobody();
update public.workspace_favorites set workspace_network_id = pg_temp.away(9)
 where user_id = pg_temp.u(1) and workspace_id = pg_temp.w(1);
select is((select workspace_network_id from public.workspace_favorites
            where user_id = pg_temp.u(1) and workspace_id = pg_temp.w(1)),
          pg_temp.here(1), 'a local favourite cannot be pointed at another reference');

-- ── references to another installation ───────────────────────────────────
-- Saved as a personal home saves them (the checked writer is #2558's).
insert into public.workspace_favorites (user_id, workspace_network_id) values (pg_temp.u(1), pg_temp.away(1));
insert into public.account_field_audience_spaces (user_id, field, workspace_network_id)
values (pg_temp.u(1), 'identity', pg_temp.away(1));
select is((select workspace_id from public.workspace_favorites
            where user_id = pg_temp.u(1) and workspace_network_id = pg_temp.away(1)),
          null::uuid, 'a foreign reference keeps no local id, even with the local UUID of One');
select is((select count(*)::int from public.workspace_favorites where user_id = pg_temp.u(1)), 2,
          'One here and One''s UUID elsewhere are two favourites');
select is(pg_temp.sqlstate_of(format(
            'insert into public.workspace_favorites (user_id, workspace_network_id) values (%L, %L)',
            pg_temp.u(1), public.installation_id()::text || ':' || pg_temp.w(77)::text)),
          '22023', 'an unknown reference on this installation is refused, never guessed');
select is(pg_temp.sqlstate_of(format(
            'insert into public.workspace_favorites (user_id, workspace_network_id) values (%L, %L)',
            pg_temp.u(1), 'not-a-reference')),
          '22023', 'a malformed reference is refused');
select is(pg_temp.sqlstate_of(format(
            'insert into public.workspace_favorites (user_id, workspace_network_id) values (%L, %L)',
            pg_temp.u(1), pg_temp.here(4))),
          '', 'a reference to a workspace hosted here maps to it');
select is((select workspace_id from public.workspace_favorites
            where user_id = pg_temp.u(1) and workspace_network_id = pg_temp.here(4)),
          pg_temp.w(4), 'the deterministic local mapping');
select ok(not public.account_field_visible_to(pg_temp.u(1), 'identity', pg_temp.u(3)),
          'a chosen space on another installation authorizes nobody here');
select ok(public.account_field_visible_to(pg_temp.u(1), 'identity', pg_temp.u(2)),
          'the local chosen space still does (pre-split policy unchanged)');

-- ── the default workspace ────────────────────────────────────────────────
update public.profiles set default_workspace_id = pg_temp.w(1) where id = pg_temp.u(1);
select is((select default_workspace_network_id from public.profiles where id = pg_temp.u(1)),
          pg_temp.here(1), 'the legacy default gets its reference');
update public.profiles set default_workspace_network_id = pg_temp.away(1) where id = pg_temp.u(1);
select is((select default_workspace_id from public.profiles where id = pg_temp.u(1)),
          null::uuid, 'a foreign default keeps no local id');
update public.profiles set default_workspace_network_id = pg_temp.here(2) where id = pg_temp.u(1);
select is((select default_workspace_id from public.profiles where id = pg_temp.u(1)),
          pg_temp.w(2), 'a default named by a local reference maps to the local id');
update public.profiles set default_workspace_id = null where id = pg_temp.u(1);
select is((select default_workspace_network_id from public.profiles where id = pg_temp.u(1)),
          null::text, 'clearing the legacy default clears the reference');
select is(pg_temp.sqlstate_of(format(
            'update public.profiles set default_workspace_network_id = %L where id = %L',
            public.installation_id()::text || ':' || pg_temp.w(77)::text, pg_temp.u(1))),
          '22023', 'an unknown local default is refused');
update public.profiles set default_workspace_network_id = pg_temp.away(1) where id = pg_temp.u(1);

-- ── my_personal_workspace_refs_v1 ────────────────────────────────────────
select pg_temp.act_as(pg_temp.u(1));
create temp table refs_u1 as select public.my_personal_workspace_refs_v1() as r;
select is((select r -> 'home' ->> 'installation_id' from refs_u1), public.installation_id()::text,
          'the reader names the home that answers');
select is((select jsonb_array_length(r -> 'refs') from refs_u1), 4,
          'One, Two (exited), Hidden (favourite) and One''s UUID elsewhere');
select is((select pg_temp.ref_of(r, pg_temp.here(1)) ->> 'status' from refs_u1), 'active',
          'One: the membership status as the row says it');
select is((select pg_temp.ref_of(r, pg_temp.here(1)) ->> 'freshness' from refs_u1), 'local',
          'One: read from this installation''s own membership');
select is((select pg_temp.ref_of(r, pg_temp.here(1)) ->> 'label' from refs_u1), 'One',
          'One: a member reads the name');
select is((select pg_temp.ref_of(r, pg_temp.here(2)) ->> 'status' from refs_u1), 'exited',
          'Two: the original status, not dropped and not widened');
select is((select pg_temp.ref_of(r, pg_temp.here(4)) ->> 'label' from refs_u1), null,
          'Hidden: no membership and not listed, so no label');
select is((select pg_temp.ref_of(r, pg_temp.away(1)) -> 'freshness' from refs_u1), '"unavailable"'::jsonb,
          'elsewhere: relationship verification unavailable (C2 brings facts)');
select is((select (pg_temp.ref_of(r, pg_temp.away(1)) ->> 'status') is null
                  and (pg_temp.ref_of(r, pg_temp.away(1)) ->> 'label') is null
                  and (pg_temp.ref_of(r, pg_temp.away(1)) ->> 'is_default')::boolean
                  and (pg_temp.ref_of(r, pg_temp.away(1)) ->> 'is_favorite')::boolean
             from refs_u1), true,
          'elsewhere: no status, no label, saved as default and favourite');
select is((select pg_temp.ref_of(r, pg_temp.away(1)) -> 'audience_fields' from refs_u1), '["identity"]'::jsonb,
          'elsewhere: the audience fields that name it');
select ok((select not exists (select 1 from jsonb_array_elements(r -> 'refs') e
                               where e ?| array['is_owner', 'is_admin', 'role', 'permissions'])
             from refs_u1), 'no role and no permission in a reference');
select pg_temp.act_as(pg_temp.u(2));
select ok(pg_temp.ref_of(public.my_personal_workspace_refs_v1(), pg_temp.away(1)) is null,
          'another person never sees my saved references');
select pg_temp.act_as(pg_temp.u(3));
select is(public.my_personal_workspace_refs_v1() -> 'refs', '[]'::jsonb,
          'a person related to nothing gets an empty list, not an error');

-- ── my_visibility_network_v1 beside my_visibility ────────────────────────
select pg_temp.act_as(pg_temp.u(1));
select is(public.my_visibility() -> 'fields' -> 'identity' -> 'workspaces',
          jsonb_build_array(pg_temp.w(1)), 'my_visibility lists only the local space');
select is(public.my_visibility_network_v1() -> 'fields' -> 'identity' -> 'workspace_refs',
          (select jsonb_agg(x order by x) from unnest(array[pg_temp.here(1), pg_temp.away(1)]) x),
          'my_visibility_network_v1 lists both by reference');
select is(public.my_visibility_network_v1() -> 'fields' -> 'identity' ->> 'audience', 'chosen_spaces',
          'the audience word is unchanged');

-- ── export_my_personal_data_v1 ───────────────────────────────────────────
select pg_temp.act_as(pg_temp.u(3));
select is(public.export_my_personal_data_v1() ->> 'format', 'deskilo.personal-export',
          'a person with no workspace exports their personal data');
select pg_temp.act_as(pg_temp.u(1));
create temp table export_u1 as select public.export_my_personal_data_v1() as e;
select is((select jsonb_array_length(e -> 'workspace_favorites') from export_u1), 3,
          'the export carries every favourite, foreign ones included');
select ok((select not (e ?| array['member', 'reservations', 'invoices', 'ledger'])
                  and not (e -> 'profile' ? 'pin_hash') from export_u1),
          'no workspace record and no PIN hash');
select is((select e -> 'workspace_refs' from export_u1), (select r -> 'refs' from refs_u1),
          'the export''s references are the reader''s');

-- ── refused without a first-party session ────────────────────────────────
select pg_temp.nobody();
select isnt(pg_temp.sqlstate_of('select public.my_personal_workspace_refs_v1()'), '',
            'no session, no references');
select isnt(pg_temp.sqlstate_of('select public.export_my_personal_data_v1()'), '',
            'no session, no export');

select * from finish();
rollback;
