-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4492 (0735, asserted by 0982): the finance overview answers the business's own currency and puts nothing in
-- its place. Read from the live definition: no `coalesce` of the currency is left in it, and the answer names
-- the currency the business keeps. (That a later file takes the fallback out by itself where 0735 did nothing is
-- executed by scripts/upgrade_equivalence_check.sh, on the body as it stood before 0735.) Rolled back.
begin;
select plan(2);

select is(
  pg_get_functiondef('public.workspace_status(uuid, text, text)'::regprocedure) ~* 'coalesce\s*\(\s*v_currency\M',
  false,
  'workspace_status puts no currency in the place of the business''s own');
select is(
  pg_get_functiondef('public.workspace_status(uuid, text, text)'::regprocedure) ~ '''currency'', v_currency,',
  true,
  'and answers the currency it read');

select * from finish();
rollback;
