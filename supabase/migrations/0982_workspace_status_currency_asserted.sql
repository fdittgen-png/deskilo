-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- apps: additive
-- (one function body, and only where 0735 left its fallback in place; nothing on a replay)
--
-- #4492 (row 6) -- `workspace_status` answers the business's own currency and nothing in its place, asserted.
-- 0735 took the fallback currency out of `workspace_status(uuid, text, text)` by replacing one line of the live
-- body, inside `if position(old in def) > 0`: where the line was not found as written, the file completed, the
-- fallback stayed and nothing was said (`scripts/upgrade_equivalence_check.sh` found it: of 938 bodies rewritten
-- in place by a migration, the one patch that says nothing without its anchor). On a replay the line is there
-- and 0735 applied, so this file changes nothing there; on an installation whose body was written otherwise it
-- now either takes the fallback out or stops the upgrade and says why.
--   * the fallback as 0735 knew it, whatever its spacing, is replaced by the currency itself;
--   * then the body is read again: a `coalesce` of the currency with ANYTHING is a fallback, and raises.
-- An app of any release reads the same answer as before: the business's currency, as 0735 intended.
do $migration$
declare
  c_fn constant regprocedure := 'public.workspace_status(uuid, text, text)'::regprocedure;
  v_def text := pg_get_functiondef(c_fn);
  -- built, not written: this file holds no currency default (test/lint/migration_currency_default_test.dart)
  v_old text := format('coalesce\(\s*v_currency\s*,\s*%L\s*\)', 'EUR');
begin
  if v_def ~ v_old then
    execute regexp_replace(v_def, v_old, 'v_currency', 'g');
  end if;
  if pg_get_functiondef(c_fn) ~* 'coalesce\s*\(\s*v_currency\M' then
    raise exception '0982: workspace_status still answers a currency of its own where the business has none; its body is not the one the migrations build (0167, 0351, 0735, 0745): restate it before upgrading';
  end if;
end
$migration$;

select public.set_deskilo_schema_version(982);
