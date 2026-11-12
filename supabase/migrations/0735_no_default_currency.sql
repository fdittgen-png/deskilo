-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (two column defaults are dropped; workspace_status is patched at an
--  anchor; no row changes)
--
-- #3658 (i18n I12) -- no currency is ever a default. An amount is in the
-- currency of its own business or of its parent record; the server never
-- supplies one.
--  * payment_intents.currency and licence_plans.currency lose their
--    'EUR' default: both columns are NOT NULL, so a row that names no
--    currency is refused instead of being given one. Every caller already
--    names it (0330 for payment intents; licence plans are written by
--    migrations only).
--  * workspace_status() answers the business's own currency
--    (workspaces.currency_code is NOT NULL, and an unknown business is
--    refused by the admin check before it is read) instead of falling back
--    to 'EUR'.
-- pgTAP 401 states the rule for the whole schema: no column defaults to a
-- currency, every table with amounts and no currency of its own reaches one
-- through its business or a parent, and the lock that keeps a business's
-- currency once money exists is in place.

alter table public.payment_intents alter column currency drop default;
alter table public.licence_plans alter column currency drop default;

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
begin
  if position(p_old in p_def) = 0 then
    return null;
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $migration$
declare
  v_def text;
  -- The old fallback, built rather than written, so this file holds no
  -- currency default (test/lint/migration_currency_default_test.dart).
  v_old text := format('''currency'', coalesce(v_currency, %L),', 'EUR');
begin
  select pg_get_functiondef('public.workspace_status(uuid, text, text)'::regprocedure) into v_def;
  if position(v_old in v_def) > 0 then
    v_def := pg_temp.anchor_replace(v_def, v_old, '''currency'', v_currency,');
    if v_def is null then
      raise exception '0735: workspace_status anchor missing';
    end if;
    execute v_def;
  end if;
end
$migration$;

select public.set_deskilo_schema_version(735);
