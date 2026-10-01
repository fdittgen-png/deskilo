-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0321 (#2018) -- request-constant auth facts are evaluated once per
-- statement, not once per row.
--
-- A policy that calls `auth.uid()`, `auth.jwt()` or `auth.role()` bare is
-- re-evaluated for every row it filters (Supabase advisor
-- auth_rls_initplan). Wrapped in a scalar subquery, Postgres evaluates it
-- once as an InitPlan. The value is the same — the claims do not change
-- within a statement — so what each role may see and write is unchanged.
--
-- Every policy outside `events` / `event_decisions` (#1909 owns those) is
-- rewritten from its OWN deparsed expression: bare calls are wrapped;
-- calls already wrapped are left as they are; nothing else in the
-- expression moves. Permissive/restrictive, roles and commands are not
-- touched (ALTER POLICY changes only USING / WITH CHECK).

create function pg_temp.initplan(p_expr text) returns text language plpgsql immutable as $$
declare
  v text := p_expr;
  f text;
begin
  if v is null then return null; end if;
  foreach f in array array['uid', 'jwt', 'role'] loop
    -- Park the already-wrapped form, wrap the bare one, restore.
    v := replace(v, format('( SELECT auth.%s() AS %s)', f, f), format('@@%s@@', f));
    v := replace(v, format('auth.%s()', f), format('( SELECT auth.%s() AS %s)', f, f));
    v := replace(v, format('@@%s@@', f), format('( SELECT auth.%s() AS %s)', f, f));
  end loop;
  return v;
end;
$$;

do $rewrite$
declare
  p record;
  v_using text;
  v_check text;
  v_sql text;
begin
  for p in
    select schemaname, tablename, policyname, qual, with_check
      from pg_policies
     where schemaname = 'public'
       and tablename not in ('events', 'event_decisions')
       and (coalesce(qual, '') ~ 'auth\.(uid|jwt|role)\(\)'
            or coalesce(with_check, '') ~ 'auth\.(uid|jwt|role)\(\)')
  loop
    v_using := pg_temp.initplan(p.qual);
    v_check := pg_temp.initplan(p.with_check);
    if v_using is not distinct from p.qual and v_check is not distinct from p.with_check then
      continue;
    end if;
    v_sql := format('alter policy %I on %I.%I', p.policyname, p.schemaname, p.tablename);
    if v_using is not null then v_sql := v_sql || format(' using (%s)', v_using); end if;
    if v_check is not null then v_sql := v_sql || format(' with check (%s)', v_check); end if;
    execute v_sql;
  end loop;
end;
$rewrite$;

select public.set_deskilo_schema_version(321);
