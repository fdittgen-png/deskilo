-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2588 C2: the real-database half of the definer checks the text scan cannot
-- make. A SECURITY DEFINER function runs with its owner's rights, so what it
-- resolves by name must not be something a caller could plant:
--   A every definer function in public pins its search_path
--   B the pinned path names only schemas nobody but the owner can create in
--   C no signed-in, anonymous or public role may create objects in them
--   D the overloads of one definer name are exposed alike to authenticated: a
--     revoke written for one signature must not leave a sibling callable
begin;
select plan(6);

select is((select count(*)::int
             from pg_proc p
            where p.pronamespace = 'public'::regnamespace and p.prosecdef
              and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c
                               where c like 'search_path=%')),
  0, 'A: every SECURITY DEFINER function in public pins its search_path');

select is((select count(*)::int
             from pg_proc p, unnest(p.proconfig) c,
                  unnest(string_to_array(regexp_replace(substr(c, 13), '\s', '', 'g'), ',')) s
            where p.pronamespace = 'public'::regnamespace and p.prosecdef
              and c like 'search_path=%'
              and s not in ('public', 'auth', 'vault', 'pg_catalog', '""', '')),
  0, 'B: a pinned search_path names only public, auth, vault and pg_catalog');

select is((select count(*)::int
             from unnest(array['public', 'auth', 'vault', 'pg_catalog']) s
            where to_regnamespace(s) is not null and s <> 'pg_catalog'
              and (has_schema_privilege('authenticated', s, 'CREATE')
                   or has_schema_privilege('anon', s, 'CREATE'))),
  0, 'C: authenticated and anon cannot create objects in the schemas a definer path names');

select ok(not has_schema_privilege('authenticated', 'pg_catalog', 'CREATE'),
  'C: nor in pg_catalog, which is always searched first');

select is((select count(*)::int
             from (select p.proname
                     from pg_proc p
                    where p.pronamespace = 'public'::regnamespace and p.prosecdef
                    group by p.proname
                   having count(*) > 1
                      and count(distinct has_function_privilege('authenticated', p.oid, 'execute')) > 1) x),
  0, 'D: the overloads of one definer name are exposed alike to authenticated');

select cmp_ok((select count(*)::int from pg_proc p where p.pronamespace = 'public'::regnamespace and p.prosecdef),
  '>', 500, 'the checks looked at the definer functions (not an empty set)');

select * from finish();
rollback;
