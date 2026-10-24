-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2472 (P): the new discussion's directory names a workspace of another
-- installation by the caller's own membership fact, under 0574's rule:
-- only the person the fact is about, only a live (active) fact, only while
-- its source is enrolled under the epoch the fact arrived under. A local
-- workspace keeps its own name. W-A..W-E are foreign installation ids
-- naming the same workspace uuid; facts are seeded as membership_fact_apply
-- would store them (278 proves the apply). Everything rolls back.
begin;
select plan(16);

create function pg_temp.id(p_tail text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-' || p_tail)::uuid $$;
create function pg_temp.u(p_n int) returns uuid language sql as $$
  select pg_temp.id('0000279e' || lpad(p_n::text, 4, '0')) $$;
create function pg_temp.inst(p_c text) returns uuid language sql as $$
  select pg_temp.id('0000279a000' || p_c) $$;
create function pg_temp.ref(p_c text) returns text language sql as $$
  select pg_temp.inst(p_c) || ':' || pg_temp.id('0000279f0001') $$;
-- A fresh fact as the apply stores it, named or not, under the source's epoch.
create function pg_temp.fact(p_u int, p_c text, p_name text default null)
returns void language sql as $$
  insert into public.membership_facts (user_id, network_id, issuer, source_installation_id,
    revision, status, asserted_at, valid_until, enrolment_epoch, event_id, workspace_name)
  select pg_temp.u(p_u), pg_temp.ref(p_c), 'https://p279.test/auth/v1', pg_temp.inst(p_c), 1,
         'active', now(), now() + interval '900 seconds', e.enrolled_at, gen_random_uuid(), p_name
    from public.enrolled_installations e where e.installation_id = pg_temp.inst(p_c) $$;
-- u(p_n)'s workspaces page. plpgsql: each call reads what earlier statements wrote.
create function pg_temp.ws(p_n int, p_q text default '') returns jsonb language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', pg_temp.u(p_n),
    'role', 'authenticated')::text, true);
  return public.my_personal_message_directory_v1('workspaces', null, null, p_q);
end $$;
-- The name u(p_n)'s page gives W-p_c ('none': not listed, '-': unnamed).
create function pg_temp.wname(p_n int, p_c text) returns text language plpgsql as $$
declare v jsonb;
begin
  select e into v from jsonb_array_elements(pg_temp.ws(p_n)->'items') e
   where e->>'network_id' = pg_temp.ref(p_c);
  return case when v is null then 'none' else coalesce(v->>'permitted_name', '-') end;
end $$;
-- The helper's row for W-p_c as name/fresh ('none': no row).
create function pg_temp.rel(p_n int, p_c text) returns text language plpgsql as $$
declare v text;
begin
  select coalesce(r.permitted_name, '-') || '/' || r.fresh::text into v
    from public.personal_directory_relationships(pg_temp.u(p_n)) r
   where r.network_id = pg_temp.ref(p_c);
  return coalesce(v, 'none');
end $$;
-- The last character of each installation listed by a search, in order.
create function pg_temp.found(p_n int, p_q text) returns text language sql as $$
  select coalesce(string_agg(right(split_part(e->>'network_id', ':', 1), 1), ',' order by o), '')
    from jsonb_array_elements(pg_temp.ws(p_n, p_q)->'items') with ordinality x(e, o) $$;

-- ── fixtures ──────────────────────────────────────────────────────────
select public.operator_set_installation_roles(array['personal_home', 'workspace_host']);
insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || n || '-279@deskilo.test', '', now(), now(), now()
  from generate_series(1, 2) n;
do $c$ declare c text; begin
  foreach c in array array['a', 'b', 'c', 'd', 'e'] loop
    perform public.operator_enrol_installation(pg_temp.inst(c), 'https://w279-' || c || '.test',
      'sb_publishable_w' || c || '_key_279', array['workspace_host'], array['workspace@1']);
  end loop;
end $c$;
-- Me: W-A named, W-B named (its source is revoked below), W-C named then
-- tombstoned, W-D named under an earlier epoch, W-E unnamed. u2 names W-E.
select pg_temp.fact(1, 'a', 'Atelier Nord');
select pg_temp.fact(1, 'b', 'Studio Sud');
select pg_temp.fact(1, 'c', 'Cave Est');
update public.membership_facts set revision = 2, status = 'tombstone', workspace_name = null,
       asserted_at = now() + interval '1 second'
 where user_id = pg_temp.u(1) and network_id = pg_temp.ref('c');
select pg_temp.fact(1, 'd', 'Dock Ouest');
update public.membership_facts set enrolment_epoch = enrolment_epoch - interval '1 day',
       revision = 2
 where user_id = pg_temp.u(1) and network_id = pg_temp.ref('d');
select pg_temp.fact(1, 'e');
select pg_temp.fact(2, 'e', 'Their Name');
-- A workspace this database hosts, with me as an active member.
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, environment)
values (pg_temp.id('0000279f0002'), 'Loft Q', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1), 'dev');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status)
values (pg_temp.id('0000279c0001'), pg_temp.id('0000279f0002'), pg_temp.u(1), true, true, 'active');

-- ── the door, unchanged ───────────────────────────────────────────────
select is(has_function_privilege('anon', 'public.my_personal_message_directory_v1(text,text,text,text)', 'EXECUTE')::text
          || ' ' || has_function_privilege('authenticated', 'public.my_personal_message_directory_v1(text,text,text,text)', 'EXECUTE')::text,
  'false true', 'authenticated alone executes the directory');
select is_empty($$select r from unnest(array['anon', 'authenticated', 'service_role']) r
  where has_function_privilege(r, 'public.personal_directory_relationships(uuid)', 'EXECUTE')$$,
  'no API role executes the relationship helper');

-- ── a named remote workspace ──────────────────────────────────────────
select is(pg_temp.wname(1, 'a'), 'Atelier Nord', 'my own live fact names its workspace');
select is(pg_temp.found(1, 'atelier'), 'a', 'and the search finds it by that name');
select is((select string_agg(e->>'permitted_name', ',' order by e->>'permitted_name')
             from jsonb_array_elements(pg_temp.ws(1)->'items') e
            where split_part(e->>'network_id', ':', 1) = public.installation_id()::text),
  'Loft Q', 'a workspace hosted here keeps its own name');

-- ── a tombstoned fact ─────────────────────────────────────────────────
select is(pg_temp.wname(1, 'c') || ' ' || pg_temp.rel(1, 'c'), 'none none',
  'a tombstone is no relationship and names nothing');
select is(pg_temp.found(1, 'cave'), '', 'nor is it found by its former name');

-- ── an enrolment revoked, or an earlier epoch ─────────────────────────
select is(pg_temp.wname(1, 'b'), 'Studio Sud', 'while its source is enrolled, W-B is named');
select public.operator_revoke_installation(pg_temp.inst('b'));
select is(pg_temp.rel(1, 'b'), '-/false', 'once its source is revoked, the fact names nothing');
select is(pg_temp.wname(1, 'b') || ' ' || (pg_temp.ws(1)->>'relationship_status'), 'none partial',
  'and the page leaves it out as partial');
select is(pg_temp.found(1, 'studio'), '', 'nor is it found by the name');
select is(pg_temp.rel(1, 'd'), '-/false', 'a fact from an earlier enrolment epoch names nothing');

-- ── another person's fact ─────────────────────────────────────────────
select is(pg_temp.wname(1, 'e') || ' ' || pg_temp.rel(1, 'e'), '- -/true',
  'my unnamed fact stays unnamed though another person''s names the workspace');
select is(pg_temp.found(1, 'their'), '', 'nor do I find it by that name');
select is(pg_temp.wname(2, 'e'), 'Their Name', 'the person the named fact is about sees the name');

-- ── as the API role ───────────────────────────────────────────────────
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000279e0001","role":"authenticated"}', true);
set local role authenticated;
select is((select string_agg(coalesce(e->>'permitted_name', '-'), ',' order by e->>'network_id' collate "C")
             from jsonb_array_elements(public.my_personal_message_directory_v1('workspaces')->'items') e
            where e->>'network_id' like '00000000-0000-4000-8000-0000279a%'),
  'Atelier Nord,-', 'the signed-in person reads W-A named and W-E unnamed');
reset role;
select set_config('request.jwt.claims', '', true);

select * from finish();
rollback;
