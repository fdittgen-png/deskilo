-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2018 / 0322: no policy outside events/event_decisions calls auth.uid(),
-- auth.jwt() or auth.role() bare (re-evaluated per row); each is wrapped
-- as an InitPlan. What each role may read and write is proved unchanged by
-- every other RLS file in this directory, which runs against the
-- rewritten policies.
begin;
select plan(2);

select is(
  (select count(*)::int from pg_policies
    where schemaname = 'public'
      and tablename not in ('events', 'event_decisions')
      and (regexp_replace(coalesce(qual, '') || ' ' || coalesce(with_check, ''),
             '\( SELECT auth\.(uid|jwt|role)\(\) AS (uid|jwt|role)\)', '', 'g')
           ~ 'auth\.(uid|jwt|role)\(\)')),
  0,
  'no policy re-evaluates a request-constant auth fact per row');

select ok(
  (select count(*) from pg_policies
    where schemaname = 'public'
      and coalesce(qual, '') like '%( SELECT auth.uid() AS uid)%') > 0,
  'the wrapped form is what the policies now carry');

select * from finish();
rollback;
