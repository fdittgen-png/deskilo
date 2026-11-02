-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2483 (S4): the 90-day values left three SQL functions — the MCP notice
-- read-state purge (mark_instance_notice_read, instance_notify_operators) and
-- the VIES evidence freshness (member_vies_verified) now read registry
-- settings (0476). That migration rewrites each body in place with
-- pg_temp.patch_function, so the text of the last `create function` in the
-- migration FILES still shows the old literal: a count over files measures
-- history, not the function that runs. This file measures the function that
-- runs, as the database holds it after the whole replay.
--
--   A the effective definitions hold no day-interval literal
--   B the matcher sees every spelling of one (case, spacing, `::interval`)
--   C the control: a literal written into an EFFECTIVE body is counted, so
--     the check in A can fail (the transaction is rolled back)
begin;
select plan(6);

-- Day-interval literals in a definition: `interval '90 days'` in any case and
-- spacing, and the cast form `'90 days'::interval`.
create function pg_temp.day_literals(def text) returns int language sql immutable as $f$
  select (select count(*)::int from regexp_matches(
            def, 'interval\s*''\s*\d+\s+days?\s*''', 'gi'))
       + (select count(*)::int from regexp_matches(
            def, '''\s*\d+\s+days?\s*''\s*::\s*interval', 'gi'));
$f$;

-- A — a missing function or signature fails the ::regprocedure cast.
select is(pg_temp.day_literals(pg_get_functiondef(
    'public.mark_instance_notice_read(uuid)'::regprocedure)), 0,
  'A1 mark_instance_notice_read: no day-interval literal in the effective body');
select is(pg_temp.day_literals(pg_get_functiondef(
    'public.instance_notify_operators(text,text,jsonb,uuid)'::regprocedure)), 0,
  'A2 instance_notify_operators: no day-interval literal in the effective body');
select is(pg_temp.day_literals(pg_get_functiondef(
    'public.member_vies_verified(uuid,text)'::regprocedure)), 0,
  'A3 member_vies_verified: no day-interval literal in the effective body');

-- B — four spellings in one scratch function.
create function pg_temp.spellings() returns void language sql as $p$
  select interval '90 days', INTERVAL  ' 1 day ', '30 days'::interval, '7 DAYS' :: interval;
$p$;
select is(pg_temp.day_literals(pg_get_functiondef('pg_temp.spellings()'::regprocedure)), 4,
  'B1 the matcher counts interval literals in any case and spacing, and the cast form');

-- C — write a literal into the EFFECTIVE body of a real function (inside this
-- transaction) and count it again. The control would pass on the stale file
-- text just the same; it is the function the database runs that is changed.
select ok(pg_get_functiondef('public.mark_instance_notice_read(uuid)'::regprocedure) ~* '\mbegin\M',
  'C1 the effective body has a begin to write the control literal after');

do $control$
declare
  def text := pg_get_functiondef('public.mark_instance_notice_read(uuid)'::regprocedure);
begin
  execute regexp_replace(def, '(\mbegin\M)', E'\\1\n  perform interval ''90 days'';', 'i');
end;
$control$;

select is(pg_temp.day_literals(pg_get_functiondef(
    'public.mark_instance_notice_read(uuid)'::regprocedure)), 1,
  'C2 a literal written into the effective body is counted: A1 would fail');

select * from finish();
rollback;
