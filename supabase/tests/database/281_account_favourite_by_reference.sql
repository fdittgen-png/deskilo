-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2554 (9999): set_workspace_favorite_ref_v1 sets or clears the caller's
-- favourite by qualified reference. A workspace here may be marked when
-- the caller may already mark it (a member, or a listed one); another
-- installation's only while the caller holds a membership fact in force
-- for it (active/paused/pending, its source enrolled under the fact's
-- epoch, inside its deadline). A lapsed, exited, revoked or missing fact,
-- another person's fact, an unlisted foreign workspace, an unknown local
-- or a malformed reference is refused and writes nothing; a favourite the
-- caller holds can always be cleared. my_personal_workspace_refs_v1 then
-- reads it as is_favorite. W-A..W-E are foreign installation ids naming
-- the same workspace uuid; facts are seeded as membership_fact_apply
-- stores them (278 proves the apply). Writes and checks are separate
-- statements: each call's answer (or SQLSTATE) is kept in a temp table.
-- Everything rolls back.
begin;
select plan(27);

create function pg_temp.id(p_tail text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-' || p_tail)::uuid $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.u(p_n int) returns uuid language sql as $$
  select pg_temp.id('0000281e' || lpad(p_n::text, 4, '0')) $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.inst(p_c text) returns uuid language sql as $$
  select pg_temp.id('0000281a000' || p_c) $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.ref(p_c text) returns text language sql as $$
  select pg_temp.inst(p_c) || ':' || pg_temp.id('0000281f0001') $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.w(p_n int) returns uuid language sql as $$
  select pg_temp.id('0000281f000' || (p_n + 1)) $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create function pg_temp.here(p_n int) returns text language sql as $$
  select network_id from public.workspaces where id = pg_temp.w(p_n) $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
-- A fact as the apply stores it, under the source's epoch.
create function pg_temp.fact(p_u int, p_c text, p_status text) returns void language sql as $$
  insert into public.membership_facts (user_id, network_id, issuer, source_installation_id,
    revision, status, asserted_at, valid_until, enrolment_epoch, event_id)
  select pg_temp.u(p_u), pg_temp.ref(p_c), 'https://p281.test/auth/v1', pg_temp.inst(p_c), 1,
         p_status, now(), now() + interval '900 seconds', e.enrolled_at, gen_random_uuid()
    from public.enrolled_installations e where e.installation_id = pg_temp.inst(p_c) $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
-- One call as u(p_n): 'true'/'false' (is_favorite after it) or the SQLSTATE.
create function pg_temp.fav(p_n int, p_ref text, p_on boolean) returns text language plpgsql as $$
begin
  if p_n is null then
    perform set_config('request.jwt.claims', '', true);
  else
    perform set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.u(p_n),
      'role', 'authenticated')::text, true);
  end if;
  return public.set_workspace_favorite_ref_v1(p_ref, p_on) ->> 'is_favorite';
exception when others then
  return sqlstate;
end $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
-- u(p_n)'s favourites: a local one by its workspace name, a foreign one by
-- the last character of its installation; '-' when none.
create function pg_temp.favs(p_n int) returns text language sql as $$
  select coalesce(string_agg(coalesce(w.name, right(split_part(f.workspace_network_id, ':', 1), 1)),
                             ',' order by coalesce(w.name, right(split_part(f.workspace_network_id, ':', 1), 1)) collate "C"), '-')
    from public.workspace_favorites f left join public.workspaces w on w.id = f.workspace_id
   where f.user_id = pg_temp.u(p_n) $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
-- What u(p_n)'s reference list says of p_ref: is_favorite, or 'none'.
create function pg_temp.listed(p_n int, p_ref text) returns text language plpgsql as $$
declare v jsonb;
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.u(p_n),
    'role', 'authenticated')::text, true);
  select e into v from jsonb_array_elements(public.my_personal_workspace_refs_v1() -> 'refs') e
   where e ->> 'network_id' = p_ref;
  return coalesce(v ->> 'is_favorite', 'none');
end $$;
grant execute on all functions in schema pg_temp to authenticated, anon;
create temp table r (k text primary key, v text);

-- ── fixtures ──────────────────────────────────────────────────────────
select public.operator_set_installation_roles(array['personal_home', 'workspace_host']);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || n || '-281@deskilo.test', '', now(), now(), now()
  from generate_series(1, 2) n;
do $c$ declare c text; begin
  foreach c in array array['a', 'b', 'c', 'd', 'e', 'f'] loop
    perform public.operator_enrol_installation(pg_temp.inst(c), 'https://w281-' || c || '.test',
      'sb_publishable_w' || c || '_key_281', array['workspace_host'], array['workspace@1']);
  end loop;
end $c$;
-- Me: W-A active, W-B paused, W-C lapsed, W-D exited, W-F pending. W-E:
-- only u2 holds a fact.
select pg_temp.fact(1, 'a', 'active');
select pg_temp.fact(1, 'b', 'paused');
insert into public.membership_facts (user_id, network_id, issuer, source_installation_id,
  revision, status, asserted_at, valid_until, enrolment_epoch, event_id)
select pg_temp.u(1), pg_temp.ref('c'), 'https://p281.test/auth/v1', pg_temp.inst('c'), 1,
       'active', now() - interval '2 days', now() - interval '1 day', e.enrolled_at, gen_random_uuid()
  from public.enrolled_installations e where e.installation_id = pg_temp.inst('c');
select pg_temp.fact(1, 'd', 'exited');
select pg_temp.fact(1, 'f', 'pending');
select pg_temp.fact(2, 'e', 'active');
-- Here: Mine (I am active in it), Listed (public directory), Hidden.
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, environment)
values (pg_temp.w(1), 'Mine', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(2), 'dev'),
       (pg_temp.w(2), 'Listed', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(2), 'dev'),
       (pg_temp.w(3), 'Hidden', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(2), 'dev');
update public.workspaces set visibility_set_at = now() where id = pg_temp.w(2);
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status)
values (pg_temp.id('0000281c0001'), pg_temp.w(1), pg_temp.u(1), false, false, 'active');

-- ── the door ──────────────────────────────────────────────────────────
select is(has_function_privilege('anon', 'public.set_workspace_favorite_ref_v1(text,boolean)', 'EXECUTE')::text
          || ' ' || has_function_privilege('authenticated', 'public.set_workspace_favorite_ref_v1(text,boolean)', 'EXECUTE')::text,
  'false true', 'authenticated alone executes the writer');
select is_empty($$select 1 from pg_proc p where p.oid = 'public.set_workspace_favorite_ref_v1(text,boolean)'::regprocedure
  and not (p.prosecdef and exists (select 1 from unnest(p.proconfig) c where c like 'search_path=%'))$$,
  'the writer is a definer with its own search_path');

-- ── the writes ────────────────────────────────────────────────────────
insert into r select 'nobody', pg_temp.fav(null, pg_temp.ref('a'), true);
insert into r select 'a_on', pg_temp.fav(1, pg_temp.ref('a'), true);
insert into r select 'a_again', pg_temp.fav(1, pg_temp.ref('a'), true);
insert into r select 'b_on', pg_temp.fav(1, pg_temp.ref('b'), true);
insert into r select 'f_on', pg_temp.fav(1, pg_temp.ref('f'), true);
insert into r select 'c_on', pg_temp.fav(1, pg_temp.ref('c'), true);
insert into r select 'd_on', pg_temp.fav(1, pg_temp.ref('d'), true);
insert into r select 'e_on', pg_temp.fav(1, pg_temp.ref('e'), true);
insert into r select 'mine_on', pg_temp.fav(1, pg_temp.here(1), true);
insert into r select 'listed_on', pg_temp.fav(1, pg_temp.here(2), true);
insert into r select 'hidden_on', pg_temp.fav(1, pg_temp.here(3), true);
insert into r select 'unknown_here', pg_temp.fav(1, public.installation_id()::text || ':' || pg_temp.id('0000281f0099'), true);
insert into r select 'malformed', pg_temp.fav(1, 'not-a-reference', true);
insert into r select 'null_ref', pg_temp.fav(1, null, true);

select is((select v from r where k = 'nobody'), 'P0001', 'a call without a session is refused');
select is((select v from r where k = 'a_on') || ' ' || (select v from r where k = 'a_again'), 'true true',
  'an active fact in force lets me mark W-A, and again without a second row');
select is((select v from r where k = 'b_on') || ' ' || (select v from r where k = 'f_on'), 'true true',
  'a paused or a pending fact in force does too');
select is((select v from r where k = 'c_on'), '42501', 'a lapsed fact is refused');
select is((select v from r where k = 'd_on'), '42501', 'an exited fact is refused');
select is((select v from r where k = 'e_on'), '42501', 'another person''s fact is refused');
select is((select v from r where k = 'mine_on') || ' ' || (select v from r where k = 'listed_on'), 'true true',
  'a space here I belong to, or a listed one, may be marked');
select is((select v from r where k = 'hidden_on'), '42501', 'an unlisted space here I do not belong to is refused');
select is((select v from r where k = 'unknown_here'), '22023', 'an unknown reference to this installation is refused');
select is((select v from r where k = 'malformed') || ' ' || (select v from r where k = 'null_ref'), '22023 22023',
  'a malformed or missing reference is refused');
select is(pg_temp.favs(1), 'Listed,Mine,a,b,f', 'only the allowed marks were written, once each');
select is(pg_temp.favs(2), '-', 'nobody else got a mark');
select is((select count(*)::int from public.workspace_favorites
            where user_id = pg_temp.u(1) and workspace_id is null
              and split_part(workspace_network_id, ':', 1) <> public.installation_id()::text), 3,
  'a foreign reference is kept without a local id');
select is((select workspace_network_id from public.workspace_favorites
            where user_id = pg_temp.u(1) and workspace_id = pg_temp.w(1)), pg_temp.here(1),
  'a space here is kept by its id with its own network id');

-- ── the reader ────────────────────────────────────────────────────────
select is(pg_temp.listed(1, pg_temp.ref('a')) || ' ' || pg_temp.listed(1, pg_temp.here(1)), 'true true',
  'my reference list reads both marks as favourites');
select is(pg_temp.listed(1, pg_temp.ref('d')), 'false', 'a refused mark stays off the list''s favourites');
select is((select (public.workspace_feedback_summary(pg_temp.w(1)) ->> 'favorite')), 'true',
  'the legacy summary agrees for a space here');

-- ── clearing ──────────────────────────────────────────────────────────
select public.operator_revoke_installation(pg_temp.inst('b'));
insert into r select 'b_again', pg_temp.fav(1, pg_temp.ref('b'), true);
insert into r select 'b_off', pg_temp.fav(1, pg_temp.ref('b'), false);
insert into r select 'a_off', pg_temp.fav(1, pg_temp.ref('a'), false);
insert into r select 'mine_off', pg_temp.fav(1, pg_temp.here(1), false);
insert into r select 'e_off', pg_temp.fav(1, pg_temp.ref('e'), false);
insert into r select 'hidden_off', pg_temp.fav(1, pg_temp.here(3), false);

select is((select v from r where k = 'b_again'), '42501', 'once its source is revoked, W-B cannot be marked');
select is((select v from r where k = 'b_off'), 'false', 'but a mark I hold can always be cleared');
select is((select v from r where k = 'a_off') || ' ' || (select v from r where k = 'mine_off'), 'false false',
  'clearing a mark answers false');
select is((select v from r where k = 'e_off') || ' ' || (select v from r where k = 'hidden_off'), '42501 42501',
  'clearing a reference I have no relationship with and hold no mark for is refused');
select is(pg_temp.favs(1), 'Listed,f', 'the cleared marks are gone, the rest untouched');
select is(pg_temp.listed(1, pg_temp.ref('a')), 'false', 'and my reference list no longer reads W-A as a favourite');

-- ── as the API roles ──────────────────────────────────────────────────
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000281e0001","role":"authenticated"}', true);
set local role authenticated;
select public.set_workspace_favorite_ref_v1('00000000-0000-4000-8000-0000281a000a:00000000-0000-4000-8000-0000281f0001', true);
reset role;
select is(pg_temp.favs(1), 'Listed,a,f', 'the signed-in person marks W-A through the API role');
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok($$select public.set_workspace_favorite_ref_v1('00000000-0000-4000-8000-0000281a000a:00000000-0000-4000-8000-0000281f0001', true)$$,
  '42501', null, 'an anonymous caller marks nothing');
reset role;
select set_config('request.jwt.claims', '', true);

select * from finish();
rollback;
