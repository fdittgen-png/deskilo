-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2472 (P): the new discussion's directory at the personal home. My
-- workspaces come from verified membership facts in force (#2563 C2) and
-- my local memberships; the people of one of them are the other accounts
-- of THIS home holding the same relationship, filtered by the messaging
-- policy (blocks, reachability, hidden identity); my groups are the ones I
-- am in now. W-A and W-B are foreign installation ids naming the SAME
-- local workspace uuid; facts are seeded as membership_fact_apply would
-- store them (273 proves the apply). Everything rolls back.
begin;
select plan(31);

create function pg_temp.id(p_tail text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-' || p_tail)::uuid $$;
create function pg_temp.u(p_n int) returns uuid language sql as $$
  select pg_temp.id('00002472e' || lpad(p_n::text, 3, '0')) $$;
create function pg_temp.inst(p_c text) returns uuid language sql as $$
  select pg_temp.id('000002472a0' || p_c) $$;
create function pg_temp.ref(p_c text) returns text language sql as $$
  select pg_temp.inst(p_c) || ':' || pg_temp.id('000002472f01') $$;
create function pg_temp.lref() returns text language sql as $$
  select network_id from public.workspaces where id = pg_temp.id('000002472f02') $$;
-- A fact as the apply stores it: fresh (900 s ahead) or lapsed an hour ago.
create function pg_temp.fact(p_u int, p_c text, p_st text, p_fresh boolean default true)
returns void language sql as $$
  insert into public.membership_facts (user_id, network_id, issuer, source_installation_id,
    revision, status, asserted_at, valid_until, enrolment_epoch, event_id)
  select pg_temp.u(p_u), pg_temp.ref(p_c), 'https://p.test/auth/v1', pg_temp.inst(p_c), 1, p_st,
         case when p_fresh then now() else now() - interval '2 hours' end,
         case when p_fresh then now() + interval '900 seconds' else now() - interval '1 hour' end,
         e.enrolled_at, gen_random_uuid()
    from public.enrolled_installations e where e.installation_id = pg_temp.inst(p_c) $$;
-- plpgsql: each call reads what earlier statements wrote.
create function pg_temp.dir(p_section text, p_ref text default null, p_after text default null,
  p_q text default '', p_extra jsonb default '{}') returns jsonb language plpgsql as $$
begin
  perform set_config('request.jwt.claims', (jsonb_build_object('sub', pg_temp.u(1),
    'role', 'authenticated') || p_extra)::text, true);
  return public.my_personal_message_directory_v1(p_section, p_ref, p_after, p_q);
end $$;
-- The keys of a page, by their last three characters, in order.
create function pg_temp.keys(p jsonb) returns text language sql as $$
  select coalesce(string_agg(right(coalesce(e->>'person_id', e->>'group_id'), 3), ','
                  order by o), '') from jsonb_array_elements(p->'items') with ordinality x(e, o) $$;

-- ── fixtures ──────────────────────────────────────────────────────────
select public.operator_set_installation_roles(array['personal_home', 'workspace_host']);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || n || '-2472@deskilo.test', '', now(), now(), now()
  from generate_series(1, 12) n;
update public.profiles p set display_name = v.name
  from (values (1, 'Me Myself'), (2, 'Ada Lovelace'), (3, 'Bruno Ricci'), (4, 'Paused Pia'),
               (5, 'Stale Sam'), (6, 'Blocked Ben'), (7, 'Zed Hidden'), (8, 'Tomb Tim'),
               (9, 'Local Lea'), (10, 'Al_100%'), (11, 'Nora Nobody'), (12, 'Unrelated Uma')) v(n, name)
 where p.id = pg_temp.u(v.n);
do $c$ declare c text; begin
  foreach c in array array['a', 'b'] loop
    perform public.operator_enrol_installation(pg_temp.inst(c), 'https://w-' || c || '.test',
      'sb_publishable_w' || c || '_key_123', array['workspace_host'], array['workspace@1']);
  end loop;
end $c$;
-- Me in W-A and W-B; Ada in W-A, Bruno in W-B (the same workspace uuid);
-- Pia paused, Sam lapsed, Tim tombstoned, Ben blocked, Zed hides his name,
-- Nora is reachable by nobody, Uma holds no relationship.
select pg_temp.fact(1, 'a', 'active');
select pg_temp.fact(1, 'b', 'active');
select pg_temp.fact(2, 'a', 'active');
select pg_temp.fact(6, 'a', 'active');
select pg_temp.fact(7, 'a', 'active');
select pg_temp.fact(10, 'a', 'active');
select pg_temp.fact(11, 'a', 'active');
select pg_temp.fact(3, 'b', 'active');
select pg_temp.fact(4, 'a', 'paused');
select pg_temp.fact(5, 'a', 'active', false);
select pg_temp.fact(8, 'a', 'tombstone');
insert into public.account_blocks (blocker, blocked) values (pg_temp.u(1), pg_temp.u(6));
insert into public.account_field_audience (user_id, field, audience)
values (pg_temp.u(7), 'identity', 'nobody'), (pg_temp.u(11), 'reachability', 'nobody');
-- A workspace this database hosts: Lea and I are its active members.
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, environment)
values (pg_temp.id('000002472f02'), 'Loft P', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'dev');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status)
values (pg_temp.id('000002472c01'), pg_temp.id('000002472f02'), pg_temp.u(1), true, true, 'active'),
       (pg_temp.id('000002472c02'), pg_temp.id('000002472f02'), pg_temp.u(9), false, false, 'active');
-- Groups: d01 without a message, d02 announcement-only (I am no admin),
-- d03 I left, d04 I was never in.
insert into public.account_groups (id, title, announce_only, created_by)
select pg_temp.id('000002472d0' || n), 'Group ' || n, n = 2, pg_temp.u(2) from generate_series(1, 4) n;
insert into public.account_group_members (group_id, user_id, is_admin, left_at)
values (pg_temp.id('000002472d01'), pg_temp.u(1), false, null),
       (pg_temp.id('000002472d02'), pg_temp.u(1), false, null),
       (pg_temp.id('000002472d03'), pg_temp.u(1), false, now()),
       (pg_temp.id('000002472d04'), pg_temp.u(2), true, null);

-- ── the door ──────────────────────────────────────────────────────────
select is(has_function_privilege('anon', 'public.my_personal_message_directory_v1(text,text,text,text)', 'EXECUTE')::text
          || ' ' || has_function_privilege('authenticated', 'public.my_personal_message_directory_v1(text,text,text,text)', 'EXECUTE')::text,
  'false true', 'authenticated alone executes the directory');
select is_empty($$select r from unnest(array['anon', 'authenticated', 'service_role']) r
  where has_function_privilege(r, 'public.personal_directory_relationships(uuid)', 'EXECUTE')$$,
  'no API role executes the relationship helper');

-- ── workspaces ────────────────────────────────────────────────────────
select is((select string_agg(coalesce(e->>'permitted_name', '-'), ',' order by e->>'permitted_name')
             from jsonb_array_elements(pg_temp.dir('workspaces')->'items') e),
  'Loft P,-,-', 'the local workspace by name and both remote ones, never a copied name');
select is((select count(*)::int from jsonb_array_elements(pg_temp.dir('workspaces')->'items') e
            where e->>'network_id' in (pg_temp.ref('a'), pg_temp.ref('b'))
              and e->>'installation_id' = split_part(e->>'network_id', ':', 1)), 2,
  'the same workspace uuid on two installations is two network references');
select is(pg_temp.dir('workspaces')->>'relationship_status', 'ready', 'every fact in force: ready');
select is((select string_agg(k, ',' order by k) from jsonb_object_keys(pg_temp.dir('groups')) k),
  'has_more,items,next_key,relationship_status,schema_version,section', 'no hidden total in the envelope');

-- ── people ────────────────────────────────────────────────────────────
select is(pg_temp.keys(pg_temp.dir('people', pg_temp.ref('a'))), '002,007,010',
  'W-A: Ada, Zed and Al; not me, paused, lapsed, tombstoned, blocked, unreachable or unrelated');
select is(pg_temp.keys(pg_temp.dir('people', pg_temp.ref('b'))), '003',
  'W-B lists Bruno alone, though its workspace uuid is W-A''s');
select is(pg_temp.keys(pg_temp.dir('people', pg_temp.lref())), '009',
  'a workspace hosted here lists its local members');
select is((select e->>'personal_home_id' || ' ' || (e->>'context_workspace_ref' = pg_temp.ref('a'))::text
             from jsonb_array_elements(pg_temp.dir('people', pg_temp.ref('a'))->'items') e limit 1),
  public.installation_id()::text || ' true', 'a person is an account of this home, in the asked workspace');
select is((select string_agg(coalesce(e->'view'->'identity'->>'name', '-'), ',' order by e->>'person_id')
             from jsonb_array_elements(pg_temp.dir('people', pg_temp.ref('a'))->'items') e),
  'Ada Lovelace,-,Al_100%', 'a hidden name is not returned');
select is(pg_temp.keys(pg_temp.dir('people', pg_temp.ref('a'), p_q => 'zed')), '',
  'nor found by searching it');
select is(pg_temp.keys(pg_temp.dir('people', pg_temp.ref('a'), p_q => 'A')), '002,010',
  'one character, any case');
select is(pg_temp.keys(pg_temp.dir('people', pg_temp.ref('a'), p_q => '%')) || ' '
          || pg_temp.keys(pg_temp.dir('people', pg_temp.ref('a'), p_q => '_')), '010 010',
  '% and _ are literal');

-- ── keyset paging after the filters ───────────────────────────────────
update public.setting_definitions set default_value = '2'::jsonb
 where key = 'personal.message_directory_page_size';
select is(pg_temp.keys(pg_temp.dir('people', pg_temp.ref('a'))) || ' '
          || (pg_temp.dir('people', pg_temp.ref('a'))->>'has_more') || ' '
          || right(pg_temp.dir('people', pg_temp.ref('a'))->>'next_key', 3),
  '002,007 true 007', 'a page of two eligible people, more after');
select is(pg_temp.keys(pg_temp.dir('people', pg_temp.ref('a'), pg_temp.u(7)::text)) || ' '
          || (pg_temp.dir('people', pg_temp.ref('a'), pg_temp.u(7)::text)->>'has_more') || ' '
          || coalesce(pg_temp.dir('people', pg_temp.ref('a'), pg_temp.u(7)::text)->>'next_key', 'null'),
  '010 false null', 'the next page from the cursor ends the list');
update public.setting_definitions set default_value = '50'::jsonb
 where key = 'personal.message_directory_page_size';

-- ── groups ────────────────────────────────────────────────────────────
select is(pg_temp.keys(pg_temp.dir('groups')), 'd01,d02',
  'the groups I am in, with or without a message; not one I left or never joined');
select is((select string_agg((e->>'can_write') || '/' || (e->>'announce_only'), ',' order by e->>'group_id')
             from jsonb_array_elements(pg_temp.dir('groups')->'items') e),
  'true/false,false/true', 'an announcement-only group I do not administer reads, not writes');

-- ── refusals ──────────────────────────────────────────────────────────
select throws_ok($$select pg_temp.dir('everyone')$$, '22023', null, 'an unknown section');
select throws_ok($$select pg_temp.dir('people')$$, '22023', null, 'people without a workspace');
select throws_ok($$select pg_temp.dir('groups', pg_temp.ref('a'))$$, '22023', null,
  'a workspace on another section');
select throws_ok($$select pg_temp.dir('people', pg_temp.ref('a'), 'abc')$$, '22023', null,
  'a cursor of another shape');
select throws_ok($$select pg_temp.dir('people', pg_temp.ref('a'), p_q => repeat('a', 121))$$, '22023', null,
  'a search longer than the setting');
select throws_ok($$select pg_temp.dir('people', pg_temp.inst('c') || ':' || pg_temp.id('000002472f01'))$$,
  '42501', null, 'a workspace I hold no relationship with is refused, not answered empty');
select throws_ok($$select pg_temp.dir('workspaces', p_extra => '{"client_id": "00000000-0000-4000-8000-000002472c99"}')$$,
  'P0001', 'connections are managed in the Deskilo app', 'a delegated assistant token reads no directory');
select throws_ok($$select pg_temp.dir('workspaces', p_extra => '{"role": "deskilo_identity"}')$$,
  'P0001', 'identity_session_refused', 'nor an upstream identity token');

-- ── a lapsed source is not "nobody" ───────────────────────────────────
delete from public.membership_facts where user_id = pg_temp.u(1) and network_id = pg_temp.ref('b');
select pg_temp.fact(1, 'b', 'active', false);
select is((pg_temp.dir('workspaces')->>'relationship_status') || ' '
          || jsonb_array_length(pg_temp.dir('workspaces')->'items'), 'partial 2',
  'my W-B fact lapsed: the workspaces say partial and leave it out');
select is((pg_temp.dir('people', pg_temp.ref('b'))->>'relationship_status') || ' '
          || jsonb_array_length(pg_temp.dir('people', pg_temp.ref('b'))->'items'), 'unavailable 0',
  'its people read unavailable, not an empty space');

-- ── the personal home copies no workspace ─────────────────────────────
select is((select count(*)::int from public.workspaces where network_id in (pg_temp.ref('a'), pg_temp.ref('b')))
          + (select count(*)::int from public.members where user_id in (pg_temp.u(2), pg_temp.u(3))), 0,
  'no remote workspace or member row exists here');

-- ── as the API roles ──────────────────────────────────────────────────
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-00002472e001","role":"authenticated"}', true);
set local role authenticated;
select is(jsonb_array_length(public.my_personal_message_directory_v1('people', '00000000-0000-4000-8000-000002472a0a:00000000-0000-4000-8000-000002472f01')->'items'),
  3, 'the signed-in person reads the directory');
reset role;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
select throws_ok($$select public.my_personal_message_directory_v1('groups')$$, '42501', null,
  'an anonymous caller reads nothing');
reset role;
select set_config('request.jwt.claims', '', true);

select * from finish();
rollback;
