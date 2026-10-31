-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2558 C2 (9998): set_visibility_if_unchanged_network_v1 changes one field
-- of the caller's saved privacy policy only if it is still what the caller
-- read; a stale expected value is `visibility_conflict` (PT409) and writes
-- nothing. Chosen spaces are network references: one hosted here needs an
-- active or paused membership, one on another installation a membership
-- fact in force (0569); a stale or missing fact, an unqualified id and an
-- unknown local reference add nothing; a kept saved space is not
-- re-verified. Every writer (the checked one, set_visibility,
-- set_contact_availability) takes the per-account advisory lock, so a
-- legacy write is serialized with a checked one and the checked one then
-- conflicts. Two real sessions are scripts/db_race_check.sh case 8.
--
-- One database holds one installation: W-A, W-B and W-C are foreign ids in
-- references, and their facts are inserted as 0569 would have applied them.
begin;
select plan(37);

create function pg_temp.id(p_tail text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-' || p_tail)::uuid $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.u(p_n int) returns uuid language sql as $$
  select pg_temp.id('00002558c' || lpad(p_n::text, 3, '0')) $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.w(p_n int) returns uuid language sql as $$
  select pg_temp.id('00002558d' || lpad(p_n::text, 3, '0')) $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.inst(p_c text) returns uuid language sql as $$
  select pg_temp.id('000002558a0' || p_c) $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
-- A space hosted here, and W-x's space with the SAME local UUID as One.
create function pg_temp.here(p_n int) returns text language sql as $$
  select network_id from public.workspaces where id = pg_temp.w(p_n) $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.ref(p_c text) returns text language sql as $$
  select pg_temp.inst(p_c) || ':' || pg_temp.w(1) $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.act_as(p_n int) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    jsonb_build_object('sub', pg_temp.u(p_n), 'role', 'authenticated')::text, true);
end $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.exp(p_audience text, p_refs text[] default '{}') returns jsonb
language sql as $$
  select jsonb_build_object('audience', p_audience, 'workspace_refs', to_jsonb(p_refs)) $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
-- The checked write as user [p_n]: 'ok' or the SQLSTATE it raised.
create function pg_temp.cas(p_n int, p_field text, p_audience text, p_refs text[],
  p_expected jsonb) returns text language plpgsql as $$
begin
  perform pg_temp.act_as(p_n);
  perform public.set_visibility_if_unchanged_network_v1(p_field, p_audience, p_refs, p_expected);
  return 'ok';
exception when others then
  return sqlstate;
end $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
-- What user [p_n] has saved for [p_field], read in its own statement.
create function pg_temp.saved(p_n int, p_field text) returns jsonb language plpgsql as $$
begin
  return public.account_visibility_saved_field(pg_temp.u(p_n), p_field);
end $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
-- Whether [p_sql], run as user [p_n], left the account lock held: the
-- lock before and after, as 'false true' when the call took it.
create function pg_temp.locks(p_n int, p_sql text) returns text language plpgsql as $$
declare
  v_key bigint := hashtextextended('account-visibility:' || pg_temp.u(p_n)::text, 0);
  v_before boolean;
begin
  v_before := exists (select 1 from pg_locks l where l.locktype = 'advisory'
    and l.pid = pg_backend_pid() and l.granted and l.objsubid = 1
    and ((l.classid::bigint << 32) | l.objid::bigint) = v_key);
  perform pg_temp.act_as(p_n);
  execute p_sql;
  return v_before::text || ' ' || exists (select 1 from pg_locks l where l.locktype = 'advisory'
    and l.pid = pg_backend_pid() and l.granted and l.objsubid = 1
    and ((l.classid::bigint << 32) | l.objid::bigint) = v_key)::text;
end $$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- ── fixtures, by direct insert ───────────────────────────────────────────
-- u1: the caller, active in One, exited from Two; u2: active in One;
-- u3..u5: one per writer, for the lock.
insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || n || '-2558c2@deskilo.test', '', now(), now(), now()
  from generate_series(1, 5) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by,
                               environment, booking_rules, feature_flags) values
 (pg_temp.w(1), 'One', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'dev', '{}', '{}'),
 (pg_temp.w(2), 'Two', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(2), 'dev', '{}', '{}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
 (pg_temp.id('00002558e001'), pg_temp.w(1), pg_temp.u(1), true, true, 'active'),
 (pg_temp.id('00002558e002'), pg_temp.w(2), pg_temp.u(1), false, false, 'exited'),
 (pg_temp.id('00002558e003'), pg_temp.w(1), pg_temp.u(2), false, false, 'active'),
 (pg_temp.id('00002558e004'), pg_temp.w(2), pg_temp.u(2), true, true, 'active');
select public.operator_set_installation_roles(array['personal_home', 'workspace_host']);
do $e$ declare c text; begin
  foreach c in array array['a', 'b'] loop
    perform public.operator_enrol_installation(pg_temp.inst(c), 'https://w-' || c || '-2558.test',
      'sb_publishable_w' || c || '_key_2558', array['workspace_host'], array['workspace@1']);
  end loop;
end $e$;
-- u1: a fact in force at W-A, a lapsed one at W-B, none at W-C.
insert into public.membership_facts (user_id, network_id, issuer, source_installation_id,
  revision, status, asserted_at, valid_until, enrolment_epoch, event_id)
select pg_temp.u(1), pg_temp.ref(c), 'https://p.test/auth/v1', pg_temp.inst(c), 1, 'active',
       now() - interval '2 hours' + d, now() - interval '1 hour' + d,
       (select enrolled_at from public.enrolled_installations where installation_id = pg_temp.inst(c)),
       gen_random_uuid()
  from (values ('a', interval '2 hours'), ('b', interval '0')) v(c, d);

-- ── the doors ────────────────────────────────────────────────────────────
select ok(not has_function_privilege('anon',
            'public.set_visibility_if_unchanged_network_v1(text, text, text[], jsonb)', 'execute')
          and has_function_privilege('authenticated',
            'public.set_visibility_if_unchanged_network_v1(text, text, text[], jsonb)', 'execute'),
          'a signed-in person may call the checked writer; anon may not');
select is_empty($$select p.proname || ' ' || r from pg_proc p
  cross join unnest(array['anon', 'authenticated', 'service_role']) r
  where p.pronamespace = 'public'::regnamespace
    and p.proname in ('account_visibility_lock', 'write_account_audience_refs',
      'write_account_audience', 'account_visibility_saved_field', 'account_space_eligible')
    and has_function_privilege(r, p.oid, 'EXECUTE')$$,
  'no API role executes the lock, the writers or the helpers');
select ok((select prosecdef and proconfig @> array['search_path=public'] from pg_proc
            where oid = 'public.set_visibility_if_unchanged_network_v1(text, text, text[], jsonb)'::regprocedure),
          'a definer with a fixed search path');

-- ── success, and the answer from the same transaction ───────────────────
select is(pg_temp.cas(1, 'contact_channels', 'chosen_spaces', array[pg_temp.here(1)],
            pg_temp.exp('nobody')), 'ok', 'chosen spaces with a space I am active in');
select is(pg_temp.saved(1, 'contact_channels'),
          pg_temp.exp('chosen_spaces', array[pg_temp.here(1)]), 'saved by reference');
select pg_temp.act_as(1);
select is(public.set_visibility_if_unchanged_network_v1('identity', 'nobody', null,
            pg_temp.exp('my_spaces')) #>> '{visibility,fields,identity,audience}',
          'nobody', 'the answer is the saved view after the write');
select is(public.set_visibility_if_unchanged_network_v1('identity', 'my_spaces', null,
            pg_temp.exp('nobody')) ->> 'schema_version', '1', 'schema_version 1');

-- ── compare-and-set ─────────────────────────────────────────────────────
select is(pg_temp.cas(1, 'presence', 'my_spaces', null, pg_temp.exp('nobody')), 'ok',
          'the first of two writers that read the same value wins');
select is(pg_temp.cas(1, 'presence', 'chosen_spaces', array[pg_temp.here(1)], pg_temp.exp('nobody')),
          'PT409', 'the second is visibility_conflict');
select is(pg_temp.saved(1, 'presence'), pg_temp.exp('my_spaces'), 'and wrote nothing');
select is(pg_temp.cas(1, 'about', 'my_spaces', null, pg_temp.exp('nobody')), 'ok',
          'another field read before the first write: no false conflict');
select is(pg_temp.cas(1, 'about', 'nobody', null, pg_temp.exp('my_spaces', array[pg_temp.here(1)])),
          '22023', 'refs with an audience that has none: malformed, not a conflict');
select is(pg_temp.cas(1, 'contact_channels', 'nobody', null,
            pg_temp.exp('chosen_spaces', array[pg_temp.here(1), pg_temp.here(1)])), 'ok',
          'the expected references are compared as a set');
-- A legacy writer first: the checked one then conflicts.
select pg_temp.act_as(1);
select public.set_visibility('reachability', 'nobody', null);
select is(pg_temp.cas(1, 'reachability', 'signed_in', null, pg_temp.exp('my_spaces')), 'PT409',
          'after a legacy write the old expected value conflicts');
select is(pg_temp.cas(1, 'reachability', 'signed_in', null, pg_temp.exp('nobody')), 'ok',
          'the value read after it succeeds');
select is((select available::text from public.account_contact_settings where user_id = pg_temp.u(1)),
          'true', 'reachability still keeps the legacy switch in step');

-- ── refusals ─────────────────────────────────────────────────────────────
select is(pg_temp.cas(1, 'contact_channels', 'signed_in', null, pg_temp.exp('nobody')), '22023',
          'contact details never go to everyone signed in');
select is(pg_temp.cas(1, 'presence', 'everyone', null, pg_temp.exp('my_spaces')), '22023',
          'an unknown audience');
select is(pg_temp.cas(1, 'presence', 'nobody', null,
            pg_temp.exp('my_spaces') || '{"revision": 1}'), '22023', 'an expected value with another key');
select is(pg_temp.cas(1, 'presence', 'chosen_spaces', array[pg_temp.w(1)::text], pg_temp.exp('my_spaces')),
          '22023', 'an unqualified local id is never read as a reference');
select is(pg_temp.cas(1, 'presence', 'chosen_spaces', '{}', pg_temp.exp('my_spaces')), '22023',
          'chosen spaces with none chosen');
select is(pg_temp.cas(1, 'presence', 'chosen_spaces', array[pg_temp.here(2)], pg_temp.exp('my_spaces'))
          || ' ' || pg_temp.cas(1, 'presence', 'chosen_spaces',
            array[public.installation_id()::text || ':' || pg_temp.id('00002558d999')], pg_temp.exp('my_spaces')),
          'P0001 P0001', 'a space I left, and an unknown space here, add nothing');
select is(pg_temp.saved(1, 'presence'), pg_temp.exp('my_spaces'), 'nothing written by a refusal');

-- ── spaces on another installation ──────────────────────────────────────
select is(pg_temp.cas(1, 'about', 'chosen_spaces', array[pg_temp.ref('a')], pg_temp.exp('my_spaces')),
          'ok', 'a space elsewhere with a fact in force can be chosen');
select is(pg_temp.saved(1, 'about'), pg_temp.exp('chosen_spaces', array[pg_temp.ref('a')]),
          'saved by its reference, the same local UUID as One kept apart');
select is((select count(*)::int from public.workspaces
            where network_id in (pg_temp.ref('a'), pg_temp.ref('b')))
          + (select count(*)::int from public.account_field_audience_spaces
              where user_id = pg_temp.u(1) and field = 'about' and workspace_id is not null), 0,
          'no local workspace row is needed or made for it');
select is(pg_temp.cas(1, 'about', 'chosen_spaces', array[pg_temp.ref('a'), pg_temp.ref('b')],
            pg_temp.exp('chosen_spaces', array[pg_temp.ref('a')])) || ' ' ||
          pg_temp.cas(1, 'about', 'chosen_spaces', array[pg_temp.ref('a'), pg_temp.ref('c')],
            pg_temp.exp('chosen_spaces', array[pg_temp.ref('a')])),
          'P0001 P0001', 'a lapsed fact and no fact widen nothing');
-- A stale space already saved is kept on a narrowing, never re-added.
insert into public.account_field_audience_spaces (user_id, field, workspace_network_id)
values (pg_temp.u(1), 'about', pg_temp.ref('b'));
select is(pg_temp.cas(1, 'about', 'chosen_spaces', array[pg_temp.ref('b')],
            pg_temp.exp('chosen_spaces', array[pg_temp.ref('b'), pg_temp.ref('a')])), 'ok',
          'removing a space keeps a saved stale one: narrowing is not widening');
select is(pg_temp.cas(1, 'about', 'nobody', null, pg_temp.exp('chosen_spaces', array[pg_temp.ref('b')])),
          'ok', 'and it can be dropped');
select is(pg_temp.cas(1, 'about', 'chosen_spaces', array[pg_temp.ref('b')], pg_temp.exp('nobody')),
          'P0001', 'but not added back from stale evidence');

-- ── one lock for every writer ───────────────────────────────────────────
select is(pg_temp.locks(3, $$select public.set_visibility_if_unchanged_network_v1('identity',
            'nobody', null, '{"audience": "my_spaces", "workspace_refs": []}')$$),
          'false true', 'the checked writer takes the account lock');
select is(pg_temp.locks(4, $$select public.set_visibility('identity', 'nobody', null)$$),
          'false true', 'set_visibility takes the same lock');
select is(pg_temp.locks(5, $$select public.set_contact_availability(true)$$),
          'false true', 'set_contact_availability takes the same lock');
select is(pg_temp.saved(5, 'reachability'), pg_temp.exp('signed_in'),
          'and the legacy writers still write');

-- ── who may call ─────────────────────────────────────────────────────────
select set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.u(2),
  'role', 'authenticated', 'client_id', 'claude-test')::text, true);
select throws_ok($$select public.set_visibility_if_unchanged_network_v1('identity', 'nobody', null,
  '{"audience": "my_spaces", "workspace_refs": []}')$$, 'P0001', null,
  'a delegated (MCP) session is refused');
select is(pg_temp.saved(2, 'identity'), pg_temp.exp('my_spaces'), 'and wrote nothing');
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok($$select public.set_visibility_if_unchanged_network_v1('identity', 'nobody', null,
  '{"audience": "my_spaces", "workspace_refs": []}')$$, '42501', null, 'anon cannot call it');
reset role;
select set_config('request.jwt.claims', '', true);

select * from finish();
rollback;
