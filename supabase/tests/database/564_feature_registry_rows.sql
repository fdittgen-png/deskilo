-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4396 (0949): the feature registry is rows read by `feature_registry()`. The function answers one entry per row
-- in the shape the gates read; every parent is a feature of its own; the function and every reader of it are `stable`,
-- not `immutable`; the rows are readable by a signed-in role and not writable by one; and a new feature is ONE row: the
-- function and `feature_effective` see it at once, and a deleted row is gone. Rolled back.
begin;
select plan(15);

create function pg_temp.as_auth(p_sql text) returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', '00000000-0000-4000-8000-000000436401', 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  begin
    execute p_sql into v;
  exception when others then
    v := 'ERR ' || sqlstate;
  end;
  execute 'reset role';
  return coalesce(v, 'null');
end $f$;
grant execute on function pg_temp.as_auth(text) to authenticated;

select is((select count(*)::int from jsonb_object_keys(public.feature_registry())),
          (select count(*)::int from public.feature_registry_entries), 'one entry per row');
select is((select count(*)::int from public.feature_registry_entries e
            where e.parent is not null and not exists (select 1 from public.feature_registry_entries p where p.feature_key = e.parent)),
          0, 'every parent is a feature of its own');
select is(public.feature_registry() -> 'moneyTab', '{"parent": null, "default": true, "core": true}'::jsonb,
  'a feature offered everywhere carries no countries');
select is(public.feature_registry() -> 'mtdSubmission' -> 'countries', '["GB"]'::jsonb, 'a country-gated feature carries its list');
select is((select string_agg(p.proname || ':' || p.provolatile::text, ',' order by p.proname) from pg_proc p
            where p.pronamespace = 'public'::regnamespace
              and p.proname in ('feature_registry', 'feature_raw', 'feature_effective_in', 'resolved_feature_flags', 'imported_feature_flags')),
  'feature_effective_in:s,feature_raw:s,feature_registry:s,imported_feature_flags:s,resolved_feature_flags:s',
  'the registry and its immutable readers are stable');
select is((select count(*)::int from pg_proc p where p.pronamespace = 'public'::regnamespace and p.provolatile = 'i'
              and p.prosrc ~ '\mfeature_registry\('), 0, 'no immutable function reads the registry');

-- ── who reads and who writes ──
select is((select string_agg(policyname, ',' order by policyname) from pg_policies where schemaname = 'public' and tablename = 'feature_registry_entries'),
  'feature_registry_entries_select,mcp_delegated_deny,personal_native_session', 'the table carries its select policy and the two restrictive ones (a personal surface, 0564)');
select is(pg_temp.as_auth('select count(*)::text from public.feature_registry_entries'), (select count(*)::text from public.feature_registry_entries),
  'a signed-in role reads the rows');
select is(pg_temp.as_auth($$update public.feature_registry_entries set default_on = not default_on where feature_key = 'moneyTab'$$), 'ERR 42501',
  'and does not write them');
select is(pg_temp.as_auth($$select (public.feature_registry() ? 'moneyTab')::text$$), 'true', 'a signed-in role calls the function');
select is((select has_function_privilege('anon', 'public.feature_registry()', 'execute')), false, 'an anonymous caller does not');

-- ── a new feature is one row ──
insert into public.feature_registry_entries (feature_key, parent, default_on, core)
values ('rowOnlyProbe', 'moneyTab', true, true);
select is(public.feature_registry() -> 'rowOnlyProbe', '{"parent": "moneyTab", "default": true, "core": true}'::jsonb,
  'the function answers the new row at once');
-- an unchosen core feature follows its default (0437), under its parent
select is(public.feature_effective_in('{}'::jsonb, 'rowOnlyProbe'), true, 'and a gate reads its default');
select is(public.feature_effective_in('{"moneyTab": false}'::jsonb, 'rowOnlyProbe'), false, 'under its parent');
delete from public.feature_registry_entries where feature_key = 'rowOnlyProbe';
select is(public.feature_registry() ? 'rowOnlyProbe', false, 'a deleted row is gone');

select * from finish();
rollback;
