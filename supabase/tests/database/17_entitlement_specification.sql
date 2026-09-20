-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #1274 — the field report, executed.
--
-- The association's report lists, for fifteen months, how many half-days
-- a subscription includes. Those numbers are `weekdays(month) − public
-- holidays`, and for a 50 % member `included_half_days` is exactly that
-- count (open days × 2 × 50 %). So the report is not a description of
-- the app: it is an assertion about it, and this file makes it one.
--
-- Red first, and measurably so. Without the holidays nine of these
-- fifteen months are wrong — November 2026 reads 21 instead of 20 —
-- which is the defect the association actually reported.
begin;
select plan(16);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_owner uuid := '00000000-0000-4000-8000-0000000000e7';
  u_member uuid := '00000000-0000-4000-8000-0000000000e8';
  ws uuid; m_owner uuid; m_member uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u_owner, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'spec-owner@deskilo.test', '', now(), now(), now()),
         (u_member, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'spec-member@deskilo.test', '', now(), now(), now());

  -- Monday to Friday, which is what the report's arithmetic assumes.
  insert into public.workspaces (name, country_code, currency_code, timezone,
                                 created_by, booking_rules)
  values ('Spec', 'FR', 'EUR', 'Europe/Paris', u_owner,
          '{"open_weekdays": [1,2,3,4,5]}'::jsonb)
  returning id into ws;

  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_owner, true, true) returning id into m_owner;
  insert into public.members (workspace_id, user_id, is_owner, is_admin,
                              subscription_pct)
  values (ws, u_member, false, false, 50) returning id into m_member;

  -- `create_workspace` seeds its own bands and (workspace_id, from_pct)
  -- is unique, so these REPLACE them rather than sit beside them.
  delete from public.fee_bands where workspace_id = ws;
  insert into public.fee_bands (workspace_id, from_pct, to_pct, fee_cents,
                                overage_fee_cents)
  values (ws, 0, 50, 5000, 0), (ws, 50, 100, 10000, 0);

  perform set_config('deskilo.spec.ws', ws::text, false);
  perform set_config('deskilo.spec.member', m_member::text, false);
  perform set_config('request.jwt.claims',
    json_build_object('sub', u_owner::text, 'role', 'authenticated')::text, false);
end
$seed$;

create or replace function pg_temp.included(p_period text)
returns int language sql as $$
  select (public.member_statement(current_setting('deskilo.spec.member')::uuid,
                                  p_period) ->> 'included_half_days')::int;
$$;

select pg_temp.seed();

-- ------------------------------------------------------------ red first
-- The month the association noticed. Stated before the fix so the file
-- records what was wrong, not only what is right.
select is(pg_temp.included('2026-11'), 21,
  'BEFORE: November 2026 includes 21 half-days — the reported defect, '
  'because Armistice is still a working day');

select public.generate_closure_days(
  current_setting('deskilo.spec.ws')::uuid, 'FR', 2026, true);
select public.generate_closure_days(
  current_setting('deskilo.spec.ws')::uuid, 'FR', 2027, true);

-- ------------------------------------------- the report, month by month
select is(pg_temp.included('2026-10'), 22, '2026-10 includes 22 half-days');
select is(pg_temp.included('2026-11'), 20,
  '2026-11 includes 20 — Armistice is a closure day, All Saints is a Sunday');
select is(pg_temp.included('2026-12'), 22, '2026-12 includes 22 (Christmas)');
select is(pg_temp.included('2027-01'), 20, '2027-01 includes 20 (New Year)');
select is(pg_temp.included('2027-02'), 20, '2027-02 includes 20');
select is(pg_temp.included('2027-03'), 22, '2027-03 includes 22 (Easter Monday 29 March)');
select is(pg_temp.included('2027-04'), 22, '2027-04 includes 22');
select is(pg_temp.included('2027-05'), 19,
  '2027-05 includes 19 — Labour Day, Ascension, Victory 1945 and Whit Monday');
select is(pg_temp.included('2027-06'), 22, '2027-06 includes 22');
select is(pg_temp.included('2027-07'), 21, '2027-07 includes 21 (Bastille Day)');
select is(pg_temp.included('2027-08'), 22, '2027-08 includes 22 (Assumption is a Sunday)');
select is(pg_temp.included('2027-09'), 22, '2027-09 includes 22');
select is(pg_temp.included('2027-10'), 21, '2027-10 includes 21');
select is(pg_temp.included('2027-11'), 20,
  '2027-11 includes 20 — All Saints and Armistice both fall on weekdays');
select is(pg_temp.included('2027-12'), 23, '2027-12 includes 23');

select * from finish();
rollback;
