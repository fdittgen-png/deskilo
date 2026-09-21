-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #1282 S5 — the association template, end to end.
--
-- The specification test the epic asks for: a fresh workspace, the
-- builtin applied, and then the numbers the association's own report
-- prints. It is the one test that would notice the template quietly
-- ceasing to mean what it says — a booking rule dropped in an import, a
-- holiday generator that stopped generating, a statement that counts
-- open days differently.
--
-- The fifteen numbers are the specification, not an observation: they
-- come from the report the association produced for 2026-10 … 2027-12,
-- and they are what the template exists to reproduce. A 100 % member
-- gets their doubles because a half-day is half a day whatever the
-- subscription.
--
-- The red-first case is the last assertion of the holiday half: November
-- 2026 has 21 weekdays and reads 20 only because Armistice Day is a
-- closure day. A generator that produced nothing would still pass every
-- other number in the list.
begin;
select plan(19);

create or replace function pg_temp.groups() returns text[] language sql as $$
  select array_agg(distinct e->>'group')
    from jsonb_array_elements(public.deployable_entities()) e;
$$;

-- The builtin's id: `apply_workspace_template` takes an id, while
-- `template_compatibility` takes the row. Passing the wrong one is a
-- missing-function error rather than a wrong answer, which is the kind
-- of mistake worth making early.
create or replace function pg_temp.template() returns uuid
language sql as $$
  select id from public.workspace_templates
   where key = 'association_fr' and owner_workspace_id is null;
$$;

create or replace function pg_temp.act_as(p_who text) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('deskilo.assoc.' || p_who),
                      'role', 'authenticated')::text, true);
end
$act$;

create or replace function pg_temp.ws() returns uuid language sql as $$
  select current_setting('deskilo.assoc.ws')::uuid;
$$;

create or replace function pg_temp.member(p_who text) returns uuid language sql as $$
  select current_setting('deskilo.assoc.m_' || p_who)::uuid;
$$;

-- Half-days included in p_period for p_who, as the statement says.
create or replace function pg_temp.included(p_who text, p_period text)
returns int language sql as $$
  select ((public.member_statement(pg_temp.member(p_who), p_period))
            ->>'included_half_days')::int;
$$;

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_owner uuid := '00000000-0000-4000-8000-0000000000a1';
  u_full  uuid := '00000000-0000-4000-8000-0000000000a2';
  u_none  uuid := '00000000-0000-4000-8000-0000000000a3';
  u_bare  uuid := '00000000-0000-4000-8000-0000000000a4';
  ws uuid; bare uuid; m_half uuid; m_full uuid; m_none uuid; m_bare uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u_owner,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','assoc-owner@deskilo.test','',now(),now(),now()),
         (u_full,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','assoc-full@deskilo.test','',now(),now(),now()),
         (u_none,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','assoc-none@deskilo.test','',now(),now(),now()),
         (u_bare,'00000000-0000-0000-0000-000000000000','authenticated','authenticated','assoc-bare@deskilo.test','',now(),now(),now());

  insert into public.workspaces (name, country_code, currency_code, timezone,
                                 created_by, default_locale)
  values ('Association', 'FR', 'EUR', 'Europe/Paris', u_owner, 'fr')
  returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, subscription_pct)
  values (ws, u_owner, true, true, 50) returning id into m_half;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, subscription_pct)
  values (ws, u_full, false, false, 100) returning id into m_full;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, subscription_pct)
  values (ws, u_none, false, false, 0) returning id into m_none;

  -- The same template WITHOUT the calendar group, so the holidays never
  -- arrive: the control for the number that depends on them.
  insert into public.workspaces (name, country_code, currency_code, timezone,
                                 created_by, default_locale)
  values ('No holidays', 'FR', 'EUR', 'Europe/Paris', u_bare, 'fr')
  returning id into bare;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, subscription_pct)
  values (bare, u_bare, true, true, 50) returning id into m_bare;

  perform set_config('deskilo.assoc.ws', ws::text, false);
  perform set_config('deskilo.assoc.bare', bare::text, false);
  perform set_config('deskilo.assoc.owner', u_owner::text, false);
  perform set_config('deskilo.assoc.none', u_none::text, false);
  perform set_config('deskilo.assoc.bareowner', u_bare::text, false);
  perform set_config('deskilo.assoc.m_half', m_half::text, false);
  perform set_config('deskilo.assoc.m_full', m_full::text, false);
  perform set_config('deskilo.assoc.m_none', m_none::text, false);
  perform set_config('deskilo.assoc.m_bare', m_bare::text, false);
end
$seed$;

select pg_temp.seed();
select pg_temp.act_as('owner');
select public.apply_workspace_template(pg_temp.ws(), pg_temp.template(), pg_temp.groups());

-- ── what the template configures ─────────────────────────────────────

select is(
  (select booking_rules->>'granularity' || ' ' ||
          (booking_rules->>'work_start_minutes') || '-' ||
          (booking_rules->>'half_boundary_minutes') || '-' ||
          (booking_rules->>'work_end_minutes')
     from public.workspaces where id = pg_temp.ws()),
  'half_day 420-780-1140',
  'the space books in half-days, 07:00 to 13:00 and 13:00 to 19:00 — the '
  'whole point of the template, and four keys an import could quietly drop');

select is(
  (select string_agg(format('%s %s %s %s', c.name, c.half_days, c.price_cents,
                            coalesce(c.validity_months::text, 'never')),
                     ' / ' order by c.sort_order)
     from public.credit_products c where c.workspace_id = pg_temp.ws()),
  'Carnet 10 demi-journées 10 5000 never / '
  'Carnet 20 demi-journées 20 8000 never',
  'the two carnets the association sells arrive WITH the template — ten '
  'half-days for 50 €, twenty for 80 €, neither expiring. Until 0262 '
  'the catalogue was not in the configuration payload at all, so a '
  'template could promise prepaid half-days and deliver nothing to buy');

select is(
  (select format('%s %s %s', w.feature_flags->>'carnets',
                 w.feature_flags->>'workspaceVocabulary',
                 w.feature_flags->>'customRoles')
     from public.workspaces w where w.id = pg_temp.ws()),
  'true true true',
  'and the three features that make them usable are on: a template that '
  'carries a lexicon while the vocabulary is off, or role definitions '
  'while custom roles are off, carries what nobody can see');

select lives_ok(
  format($$ select public.enforce_booking_rules(%L,
    '2026-10-05 07:00:00+02'::timestamptz, '2026-10-05 13:00:00+02'::timestamptz, false) $$,
    pg_temp.ws()),
  'a morning half-day on a Monday is accepted');

-- ── the fifteen numbers ──────────────────────────────────────────────

select is(
  array[
    pg_temp.included('half','2026-10'), pg_temp.included('half','2026-11'),
    pg_temp.included('half','2026-12'), pg_temp.included('half','2027-01'),
    pg_temp.included('half','2027-02'), pg_temp.included('half','2027-03'),
    pg_temp.included('half','2027-04'), pg_temp.included('half','2027-05'),
    pg_temp.included('half','2027-06'), pg_temp.included('half','2027-07'),
    pg_temp.included('half','2027-08'), pg_temp.included('half','2027-09'),
    pg_temp.included('half','2027-10'), pg_temp.included('half','2027-11'),
    pg_temp.included('half','2027-12')],
  array[22,20,22,20,20,22,22,19,22,21,22,22,21,20,23],
  'a 50 % member is included for exactly the half-days the association''s '
  'own report prints, month by month, for fifteen months');

select is(
  array[
    pg_temp.included('full','2026-10'), pg_temp.included('full','2026-11'),
    pg_temp.included('full','2027-05'), pg_temp.included('full','2027-12')],
  array[44,40,38,46],
  'and a 100 % member their doubles — a half-day is half a day whatever '
  'the subscription');

select is(
  array[
    ((public.member_statement(pg_temp.member('half'),'2026-10'))->>'fee_cents')::int,
    ((public.member_statement(pg_temp.member('full'),'2026-10'))->>'fee_cents')::int],
  array[5000, 10000],
  'the subscription charges 50 € and 100 €');

-- ── the holidays are what make those numbers ─────────────────────────

select pg_temp.act_as('bareowner');
select public.apply_workspace_template(
  current_setting('deskilo.assoc.bare')::uuid,
  pg_temp.template(),
  (select array_agg(g) from unnest(pg_temp.groups()) g where g <> 'calendar_navigation'));

select is(
  ((public.member_statement(pg_temp.member('bare'), '2026-11'))
     ->>'included_half_days')::int,
  21,
  'November 2026 has 21 weekdays: without the holidays the number is 21, '
  'and the 20 above is Armistice Day. A generator that produced nothing '
  'would pass every other number in the list');

select is(
  (select count(*)::int from public.closure_days
    where workspace_id = current_setting('deskilo.assoc.bare')::uuid),
  0,
  'and that workspace really has none, rather than the number coming '
  'from somewhere else');

-- ── applying twice ───────────────────────────────────────────────────

select pg_temp.act_as('owner');
select public.apply_workspace_template(pg_temp.ws(), pg_temp.template(), pg_temp.groups());

select is(
  (select count(*)::int from public.fee_bands where workspace_id = pg_temp.ws()),
  2,
  'a second apply neither duplicates the fee bands nor deletes them: the '
  'bands partition 0-100 and merge as one set, never row by row');

select cmp_ok(
  (select count(*)::int from public.closure_days where workspace_id = pg_temp.ws()),
  '>', 0,
  'and the closure days the first apply brought are still there');

select is(
  (select format('%s of %s', count(*) filter (where c.active), count(*))
     from public.credit_products c where c.workspace_id = pg_temp.ws()),
  '2 of 2',
  'and the carnets merge by name rather than being sold twice: still '
  'two products, both still on sale');

-- ── a member with no subscription, and a carnet the TEMPLATE brought ─
--
-- This section used to switch `carnets` on by hand and insert a
-- ten-half-day, 150 € , twelve-month product of its own before selling
-- it. That proved the carnet machinery and nothing whatever about the
-- template — the numbers were not even the ones the association
-- advertises. Both repairs are gone: the flag and the product below are
-- what `apply_workspace_template` left behind.

select public.sell_credit(
  pg_temp.ws(), pg_temp.member('none'),
  (select c.id from public.credit_products c
    where c.workspace_id = pg_temp.ws()
      and c.name = 'Carnet 10 demi-journées'));

select is(
  public.member_credit_balance(pg_temp.member('none'), now()),
  10,
  'a member with no subscription buys the ten half-days the template '
  'priced');

-- Returns the eleven attempts as one row, because running them twice
-- would book the same seat twice. A refusal among the FIRST ten raises
-- rather than being counted as a refused eleventh: the old version
-- swallowed every exception, so ten bookings failing for some unrelated
-- reason would have read as the carnet working.
create or replace function pg_temp.book_ten_then_one_more()
returns table (made int, refusal text)
language plpgsql as $book$
declare
  v_seat uuid; d date; i int;
begin
  made := 0;
  refusal := '';
  select s.id into v_seat from public.seats s where s.workspace_id = pg_temp.ws() limit 1;
  for i in 0..10 loop
    d := date '2026-10-05' + (i * 7);
    begin
      perform public.create_reservation(pg_temp.ws(), v_seat, null,
        (d + time '07:00') at time zone 'Europe/Paris',
        (d + time '13:00') at time zone 'Europe/Paris', false, null, null);
      made := made + 1;
    exception when others then
      if i < 10 then
        raise exception 'booking % of the carnet was refused: %', i + 1, sqlerrm;
      end if;
      refusal := sqlerrm;
    end;
  end loop;
  return next;
end
$book$;

select pg_temp.act_as('none');
create temp table carnet_run as select * from pg_temp.book_ten_then_one_more();

select is(
  (select made from carnet_run),
  10,
  'and books exactly ten half-days across two months — which is what a '
  'carnet without a subscription means');

select is(
  (select refusal from carnet_run),
  'half-day quota exceeded — request additional half-days',
  'and the eleventh is refused for the reason it should be, named in '
  'full: a test that only counted ten would pass on any refusal at all');


-- ── #1282 S4: the bureau arrives, and holds nobody ───────────────────
--
-- The slice that never landed with the rest. #1287 made a workspace
-- able to define its own roles; the template carried none, so a space
-- applying it still had to invent the bureau by hand.

select is(
  (select string_agg(r.key, ',' order by r.sort_order)
     from public.workspace_roles r where r.workspace_id = pg_temp.ws()),
  'tresorier,secretaire,referent_salle',
  'the template brings the three roles a French association elects, in '
  'the order the bureau is usually listed');

select is(
  (select array_to_string(r.permissions, '+') from public.workspace_roles r
    where r.workspace_id = pg_temp.ws() and r.key = 'secretaire'),
  'manageMembers+manageDocuments+viewPersonalData',
  'and each holds the narrowest set that makes its job possible — the '
  'secretary keeps the members and the documents, and cannot issue an '
  'invoice');

select is(
  (select count(*)::int from public.workspace_roles r
    where r.workspace_id = pg_temp.ws()
      and 'manageRoles' = any(r.permissions)),
  0,
  'no role the template brings may redefine a role. That authority stays '
  'with the owner (0255), so a template cannot hand out the power to '
  'rewrite what a template handed out');

select is(
  (select count(*)::int from public.workspace_role_members rm
     join public.workspace_roles r on r.id = rm.role_id
    where r.workspace_id = pg_temp.ws()),
  0,
  'and NOBODY holds them (#1505): applying a template grants nothing '
  'until an owner gives a role to somebody');

select * from finish();
rollback;
