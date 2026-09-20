-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #1274 — the holidays a year actually has, and the months it may not touch.
--
-- The association's entitlement table is `weekdays(month) − public
-- holidays`. Three of the eleven French days move with Easter, so the
-- dates are pinned here rather than described: a computus that drifts by
-- a day changes somebody's bill, and nothing else in the suite would
-- notice.
--
-- The other half of this file is the rule that matters more than the
-- dates: generating closure days must never silently change financial
-- history. A month that already carries an invoice is skipped and named.
begin;
select plan(13);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_owner uuid := '00000000-0000-4000-8000-0000000000f1';
  u_member uuid := '00000000-0000-4000-8000-0000000000f2';
  ws uuid; m_owner uuid; m_member uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u_owner, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'holiday-owner@deskilo.test', '', now(), now(), now()),
         (u_member, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'holiday-member@deskilo.test', '', now(), now(), now());

  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Holidays', 'FR', 'EUR', 'Europe/Paris', u_owner) returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_owner, true, true) returning id into m_owner;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_member, false, false) returning id into m_member;

  perform set_config('deskilo.hol.ws', ws::text, false);
  perform set_config('deskilo.hol.owner', u_owner::text, false);
  perform set_config('deskilo.hol.member', u_member::text, false);
  perform set_config('deskilo.hol.m_owner', m_owner::text, false);
end
$seed$;

create or replace function pg_temp.act_as(p_who text) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('deskilo.hol.' || p_who),
                      'role', 'authenticated')::text, true);
end
$act$;

create or replace function pg_temp.days(p_country text, p_year int)
returns text language sql as $$
  select string_agg(to_char(h.day, 'MM-DD'), ',' order by h.day)
    from public.public_holidays(p_country, p_year) h;
$$;

create or replace function pg_temp.closures() returns int language sql as $$
  select count(*)::int from public.closure_days
   where workspace_id = current_setting('deskilo.hol.ws')::uuid;
$$;

select pg_temp.seed();

-- ------------------------------------------------------- the dates
select is(pg_temp.days('FR', 2026),
  '01-01,04-06,05-01,05-08,05-14,05-25,07-14,08-15,11-01,11-11,12-25',
  'FR 2026: eleven days, Easter Monday 6 April, Ascension 14 May, Whit Monday 25 May');

select is(pg_temp.days('FR', 2027),
  '01-01,03-29,05-01,05-06,05-08,05-17,07-14,08-15,11-01,11-11,12-25',
  'FR 2027: Easter moves, and the three derived days move with it');

-- A second country is DATA, not another function — the acceptance
-- criterion of #1274, demonstrated rather than asserted in prose.
select is((select count(*)::int from public.public_holidays('DE', 2026)), 9,
  'DE 2026: nine federal days, from the same generator');

select throws_matching(
  $$ select public.public_holidays('ZZ', 2026) $$,
  'no public-holiday rules',
  'a country with no rules is refused, never silently empty');

-- --------------------------------------------------------- the gate
select pg_temp.act_as('member');
select throws_matching(
  format($$ select public.generate_closure_days(%L, 'FR', 2026, true) $$,
         current_setting('deskilo.hol.ws')),
  'only an owner',
  'a member may not generate closure days — the RPC is no wider than the policy');

-- ------------------------------------------------------ the preview
select pg_temp.act_as('owner');
select is(
  jsonb_array_length(
    public.generate_closure_days(current_setting('deskilo.hol.ws')::uuid,
                                 'FR', 2026, false) -> 'days'),
  11,
  'the preview lists every day of the year it was asked for');

select is(pg_temp.closures(), 0,
  'and it writes nothing: a preview that touched the table would be an apply');

-- -------------------------------------------------------- the apply
select is(
  (public.generate_closure_days(current_setting('deskilo.hol.ws')::uuid,
                                'FR', 2026, true) ->> 'created')::int,
  11,
  'applying to a clean workspace creates the eleven days');

select is(
  (public.generate_closure_days(current_setting('deskilo.hol.ws')::uuid,
                                'FR', 2026, true) ->> 'created')::int,
  0,
  're-running the same year creates nothing — eleven rows, never twenty-two');

-- ------------------------------------------- the rule that matters most
-- An invoice exists for July 2026, so 14 July may not become a closure
-- day: it would change open_days, therefore included_half_days,
-- therefore that member's bill.
insert into public.invoices (workspace_id, member_id, issuer_member_id, number,
                             title, lines, total_cents, currency, member_name,
                             workspace_name, issuer_name, signature, period)
values (current_setting('deskilo.hol.ws')::uuid,
        current_setting('deskilo.hol.m_owner')::uuid,
        current_setting('deskilo.hol.m_owner')::uuid,
        'HOL-1', 'July', '[]'::jsonb, 5000, 'EUR', 'Owner', 'Holidays',
        'Owner', 'sig', '2026-07');

delete from public.closure_days
 where workspace_id = current_setting('deskilo.hol.ws')::uuid;

-- The guard BITES. Asserting only that a year WITHOUT an invoiced month
-- locks nothing would pass whether or not the rule worked.
select is(
  public.generate_closure_days(current_setting('deskilo.hol.ws')::uuid,
                               'FR', 2026, false) -> 'locked_months',
  '["2026-07"]'::jsonb,
  'the invoiced month is NAMED, so an owner sees what will be refused');

select is(
  (public.generate_closure_days(current_setting('deskilo.hol.ws')::uuid,
                                'FR', 2026, true) ->> 'created')::int,
  10,
  'and it is skipped: ten days created, not eleven');

select is(
  (select count(*)::int from public.closure_days
    where workspace_id = current_setting('deskilo.hol.ws')::uuid
      and day = date '2026-07-14'),
  0,
  '14 July never became a closure day in a month that carries an invoice');

-- The negative control, which is what the previous assertion was: a year
-- with nothing invoiced locks nothing.
select is(
  public.generate_closure_days(current_setting('deskilo.hol.ws')::uuid,
                               'FR', 2027, false) -> 'locked_months',
  '[]'::jsonb,
  'a year with no invoiced month locks nothing');

select * from finish();
rollback;
