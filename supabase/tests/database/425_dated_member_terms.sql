-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3858 (0766): a member's plan share and pause carry their dates. A past
-- period reads its terms from the store; a share changed for next month
-- leaves last month's and this month's statements as they were; a change due
-- today applies at once and one for later waits; the sweep catches up in date
-- order, once, and a change whose first period was invoiced takes effect from
-- the first period not yet invoiced; a change the row refuses on its day is
-- kept with its reason; a pause from one date to another stops the fee of a
-- month paused on its first day and resumes the member on its last date.
-- An invoice issued after a change carries it; a change written at once
-- leaves an invoiced month as invoiced; periods before dated terms began read
-- as before; the quota checks read the period's terms; a held change approved
-- late moves; a member who left is not resumed. Amounts asserted. Rolled back.
begin;
select plan(58);

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00003858' || lpad(n::text, 4, '0'))::uuid;
$$;
create function pg_temp.act_as(p uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p, 'role', 'authenticated')::text, true);
end $$;
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'terms' || n || '@example.test', '', now(), now(), now()
  from unnest(array[1, 2]) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by)
values (pg_temp.u(101), 'Terms', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1));
-- 201 the owner; 202 a member with an account; 203-208 members the owner manages
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status,
                            subscription_pct, overage_policy, joined_at)
values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active', 100, 'blocked', now() - interval '2 years'),
       (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active', 100, 'blocked', now() - interval '2 years');
insert into public.members (id, workspace_id, managed_name, status, subscription_pct, overage_policy, joined_at)
select pg_temp.u(200 + n), pg_temp.u(101), 'Member ' || n, 'active', 100,
       case when n in (6, 21) then 'payg' else 'blocked' end, now() - interval '2 years'
  from generate_series(3, 23) n;
delete from public.fee_bands where workspace_id = pg_temp.u(101);
insert into public.fee_bands (workspace_id, from_pct, to_pct, fee_cents)
values (pg_temp.u(101), 0, 50, 2000), (pg_temp.u(101), 50, 100, 4000);

select set_config('t.today', public.workspace_today(pg_temp.u(101))::text, true);
create function pg_temp.today() returns date language sql as $$ select current_setting('t.today')::date $$;
create function pg_temp.first(p_months int) returns date language sql as $$
  select (date_trunc('month', pg_temp.today()) + make_interval(months => p_months))::date $$;
create function pg_temp.period(p_months int) returns text language sql as $$
  select to_char(pg_temp.first(p_months), 'YYYY-MM') $$;
create function pg_temp.statement(p_member int, p_months int) returns jsonb language sql as $$
  select public.member_statement(pg_temp.u(p_member), pg_temp.period(p_months)) - 'negotiated' $$;
create function pg_temp.fee(p_member int, p_months int) returns text language sql as $$
  select (pg_temp.statement(p_member, p_months) ->> 'subscription_pct') || ' '
      || (pg_temp.statement(p_member, p_months) ->> 'fee_cents') $$;
-- the first period a change dated [d] counts for
create function pg_temp.fp(d date) returns date language sql as $$
  select case when extract(day from d) = 1 then d else (date_trunc('month', d) + interval '1 month')::date end $$;
create function pg_temp.invoice(p_id int, p_member int, p_period text, p_cents int, p_issued timestamptz)
returns void language sql as $$
  insert into public.invoices (id, workspace_id, member_id, issuer_member_id, number, title, lines, total_cents,
                               currency, member_name, workspace_name, issuer_name, signature, issued_at, period)
  values (pg_temp.u(p_id), pg_temp.u(101), pg_temp.u(p_member), pg_temp.u(201), 'T-' || p_id, 'T', '[]'::jsonb,
          p_cents, 'EUR', 'A', 'B', 'O', 'sig', p_issued, p_period) $$;
-- the first open weekday of a month, at nine
create function pg_temp.weekday(p_months int) returns timestamptz language sql as $$
  select ((select d from generate_series(pg_temp.first(p_months), pg_temp.first(p_months) + 6, interval '1 day') d
            where extract(isodow from d) between 1 and 5 order by d limit 1) + interval '9 hours')
         at time zone 'Europe/Paris' $$;
create function pg_temp.issue(p_member int, p_period text) returns text language plpgsql as $$
begin
  perform public.create_invoice(pg_temp.u(101), pg_temp.u(p_member), p_period, null, false, 'subscription', false);
  return 'issued';
exception when others then
  return sqlerrm;
end $$;
grant execute on all functions in schema pg_temp to authenticated;

-- the owner reads the statements
select pg_temp.act_as(pg_temp.u(1));

-- ── a past period reads its terms from the store ──
select set_config('t.prev', pg_temp.statement(203, -1)::text, true);
select set_config('t.now', pg_temp.statement(203, 0)::text, true);
-- the sweep has applied a share of 50 that takes effect next month
select set_config('deskilo.term_change_applying', 'on', true);
update public.members set subscription_pct = 50 where id = pg_temp.u(203);
select set_config('deskilo.term_change_applying', '', true);
insert into public.member_term_changes (workspace_id, member_id, kind, to_pct, from_pct, due_on, effective_on, state, source)
values (pg_temp.u(101), pg_temp.u(203), 'share', 50, 100, pg_temp.first(1), pg_temp.first(1), 'applied', 'scheduled');
select is(pg_temp.statement(203, -1)::text, current_setting('t.prev'),
  'last month''s statement is byte-equal after a share changed for next month');
select is(pg_temp.statement(203, 0)::text, current_setting('t.now'),
  'and this month''s, its included quota with it');
select is((pg_temp.statement(203, 1) ->> 'subscription_pct') || ' ' || (pg_temp.statement(203, 1) ->> 'fee_cents'),
  '50 2000', 'next month reads the new share');

-- ── the existing command is recorded, from this period on ──
select set_config('t.prev2', pg_temp.statement(202, -1)::text, true);
select pg_temp.act_as(pg_temp.u(1));
set local role authenticated;
select public.request_subscription_change(pg_temp.u(202), 50);
reset role;
select is((select source || ' ' || state || ' ' || (effective_on = pg_temp.first(0))::text
             from public.member_term_changes where member_id = pg_temp.u(202) and kind = 'share'),
  'immediate applied true', 'a share written at once is recorded from the first day of this period');
select is(pg_temp.statement(202, -1)::text, current_setting('t.prev2'),
  'and last month''s statement does not move');

-- ── scheduling ──
select pg_temp.act_as(pg_temp.u(1));
set local role authenticated;
select set_config('t.later', public.schedule_member_share_change(pg_temp.u(204), 50, pg_temp.today() + 40,
  '00000000-0000-4000-8000-000038580001')::text, true);
select is(current_setting('t.later')::jsonb ->> 'state', 'scheduled', 'a share for a later date waits');
select is((public.schedule_member_share_change(pg_temp.u(204), 50, pg_temp.today() + 40,
  '00000000-0000-4000-8000-000038580001') ->> 'replayed'), 'true', 'the same request is answered, not repeated');
select throws_ok(format($$ select public.schedule_member_share_change(%L, 60, %L, '00000000-0000-4000-8000-000038580001') $$,
  pg_temp.u(204), pg_temp.today() + 40), '22023', 'this request id belongs to another change',
  'the same request with other values is refused');
select throws_ok(format($$ select public.schedule_member_share_change(%L, 50, %L, '00000000-0000-4000-8000-000038580001') $$,
  pg_temp.u(205), pg_temp.today() + 40), '22023', 'this request id belongs to another change',
  'and so is the same request for another member');
reset role;
select is(public.apply_member_term_change((current_setting('t.later')::jsonb ->> 'change_id')::uuid), 'scheduled',
  'a change is never applied before its day');
select pg_temp.act_as(pg_temp.u(1));
set local role authenticated;
select is(public.cancel_member_term_change((current_setting('t.later')::jsonb ->> 'change_id')::uuid), 1,
  'a waiting change is cancelled');
select is(public.schedule_member_share_change(pg_temp.u(204), 75, pg_temp.today(),
  '00000000-0000-4000-8000-000038580002') ->> 'state', 'applied', 'a change due today applies at once');
reset role;
select is((select subscription_pct from public.members where id = pg_temp.u(204)), 75, 'and the member''s row takes it');

-- ── the sweep catches up, in date order, once; an invoiced period is not rewritten ──
insert into public.invoices (id, workspace_id, member_id, issuer_member_id, number, title, lines, total_cents,
                             currency, member_name, workspace_name, issuer_name, signature, issued_at, period)
values (pg_temp.u(901), pg_temp.u(101), pg_temp.u(205), pg_temp.u(201), 'T-1', 'T', '[]'::jsonb, 4000,
        'EUR', 'A', 'B', 'O', 'sig', now(), pg_temp.period(0));
insert into public.member_term_changes (workspace_id, member_id, kind, to_pct, due_on, state, source)
values (pg_temp.u(101), pg_temp.u(205), 'share', 50, pg_temp.first(0), 'scheduled', 'scheduled');
insert into public.member_term_changes (workspace_id, member_id, kind, to_pct, due_on, state, source)
values (pg_temp.u(101), pg_temp.u(205), 'share', 25, pg_temp.first(0), 'scheduled', 'scheduled');
-- 209: scheduled before its month was invoiced in advance (the invoice carries it)
insert into public.member_term_changes (workspace_id, member_id, kind, to_pct, due_on, state, source, released_at)
values (pg_temp.u(101), pg_temp.u(209), 'share', 50, pg_temp.first(0), 'scheduled', 'scheduled', now() - interval '2 days');
select pg_temp.invoice(902, 209, pg_temp.period(0), 2000, now() - interval '1 day');
-- 210: scheduled after its month was invoiced
insert into public.member_term_changes (workspace_id, member_id, kind, to_pct, due_on, state, source, released_at)
values (pg_temp.u(101), pg_temp.u(210), 'share', 50, pg_temp.first(0), 'scheduled', 'scheduled', now() - interval '1 day');
select pg_temp.invoice(903, 210, pg_temp.period(0), 4000, now() - interval '2 days');
-- 215: two changes on different dates, both missed
insert into public.member_term_changes (workspace_id, member_id, kind, to_pct, due_on, state, source)
values (pg_temp.u(101), pg_temp.u(215), 'share', 50, pg_temp.first(-1), 'scheduled', 'scheduled'),
       (pg_temp.u(101), pg_temp.u(215), 'share', 75, pg_temp.first(-1) + 10, 'scheduled', 'scheduled');
select ok(public.apply_due_member_term_changes() >= 2, 'the sweep applies the changes that are due');
select is((select count(*)::int from public.member_term_changes
            where member_id = pg_temp.u(205) and state = 'scheduled'), 0, 'each once');
select is(public.apply_due_member_term_changes(), 0, 'a second run the same day applies nothing');
select is(pg_temp.fee(209, 0), '50 2000',
  'a change scheduled before its month was invoiced in advance stays in it: the month reads the invoiced 2000');
select is(pg_temp.fee(210, 0) || ' / ' || pg_temp.fee(210, 1), '100 4000 / 50 2000',
  'one scheduled after the invoice leaves the invoiced 4000 and counts from the next period');
select is(pg_temp.fee(215, -1) || ' / ' || pg_temp.fee(215, 0), '50 2000 / 75 4000',
  'a catch-up across dates gives each period the change in force on its first day');
select is((select subscription_pct from public.members where id = pg_temp.u(205)), 25,
  'in date order: the later one stands');
select is((select string_agg(distinct (effective_on = pg_temp.first(1))::text, ',')
             from public.member_term_changes where member_id = pg_temp.u(205)), 'true',
  'a change whose first period was invoiced takes effect from the next one');
select ok((select bool_and(payload ? 'due_on' and payload ? 'effective_on') from public.events
            where subject_member_id = pg_temp.u(205) and type = 'subscription_change'),
  'and the record says when it was due and when it took effect');

-- ── refused on its day, with the reason ──
insert into public.member_term_changes (workspace_id, member_id, kind, to_pct, due_on, state, source)
values (pg_temp.u(101), pg_temp.u(206), 'share', 0, pg_temp.today(), 'scheduled', 'scheduled');
select public.apply_due_member_term_changes();
select ok((select state = 'refused' and reason <> '' from public.member_term_changes
            where member_id = pg_temp.u(206) and to_pct = 0),
  'a share the member''s rules refuse on its day is kept as refused, with the reason');

-- ── a pause ──
select pg_temp.act_as(pg_temp.u(1));
set local role authenticated;
select public.schedule_member_pause(pg_temp.u(207), pg_temp.today(), pg_temp.today() + 1,
  '00000000-0000-4000-8000-000038580003');
select public.schedule_member_pause(pg_temp.u(208), pg_temp.today(), null,
  '00000000-0000-4000-8000-000038580004');
reset role;
select is(pg_temp.statement(208, 1) ->> 'fee_cents', '0', 'a month paused on its first day owes no subscription fee');
select is(pg_temp.statement(207, 1) ->> 'fee_cents', '4000', 'a pause that ends before the month charges it in full');
update public.member_term_changes set due_on = pg_temp.today()
 where member_id = pg_temp.u(207) and to_status = 'active';
select public.apply_due_member_term_changes();
select is((select status from public.members where id = pg_temp.u(207)), 'active',
  'a pause ending on a date resumes the member that day');

-- ── a pause from the 2nd, a pause ending on a 1st ──
select pg_temp.act_as(pg_temp.u(1));
set local role authenticated;
select public.schedule_member_pause(pg_temp.u(212), pg_temp.first(1) + 1, null,
  '00000000-0000-4000-8000-000038580007');
select public.schedule_member_pause(pg_temp.u(213), pg_temp.today(), pg_temp.first(1),
  '00000000-0000-4000-8000-000038580008');
select is(pg_temp.fee(212, 1) || ' ' || ((pg_temp.statement(212, 1) ->> 'included_half_days')::int > 0)::text,
  '100 4000 true', 'a pause from the 2nd charges that month in full, with its half-days');
select is((pg_temp.statement(212, 2) ->> 'fee_cents') || ' ' || (pg_temp.statement(212, 2) ->> 'included_half_days'),
  '0 0', 'the next month owes no fee and includes no half-day');
select is(pg_temp.statement(213, 1) ->> 'fee_cents', '4000', 'a pause ending on a 1st charges that month in full');
select isnt(pg_temp.issue(213, pg_temp.period(1)), 'unknown subject member',
  'and its invoice is issued in advance while the member is still paused');
select is(pg_temp.issue(208, pg_temp.period(1)), 'unknown subject member',
  'a month paused on its first day is not invoiced');
reset role;

-- ── a change written at once in an invoiced month ──
select pg_temp.invoice(904, 220, pg_temp.period(0), 4000, now() - interval '1 day');
select pg_temp.act_as(pg_temp.u(1));
set local role authenticated;
select public.request_subscription_change(pg_temp.u(220), 50);
reset role;
select is(pg_temp.fee(220, 0) || ' / ' || pg_temp.fee(220, 1), '100 4000 / 50 2000',
  'a share written at once leaves an invoiced month as invoiced and counts from the next');

-- ── the share of a day is the last change in force on it ──
select set_config('deskilo.term_change_applying', 'on', true);
update public.members set subscription_pct = 30 where id = pg_temp.u(223);
select set_config('deskilo.term_change_applying', '', true);
insert into public.member_term_changes (workspace_id, member_id, kind, to_pct, from_pct, due_on, effective_on, state, source)
values (pg_temp.u(101), pg_temp.u(223), 'share', 50, 100, pg_temp.first(0), pg_temp.first(1), 'applied', 'scheduled');
insert into public.member_term_changes (workspace_id, member_id, kind, to_pct, from_pct, due_on, effective_on, state, source)
values (pg_temp.u(101), pg_temp.u(223), 'share', 30, 50, pg_temp.first(0), pg_temp.first(0), 'applied', 'immediate');
select is(pg_temp.fee(223, 0), '30 2000', 'a period reads the change in force on its first day, whatever order they were applied in');

-- ── cancelling ──
select pg_temp.act_as(pg_temp.u(1));
set local role authenticated;
select set_config('t.c211', public.schedule_member_share_change(pg_temp.u(211), 50, pg_temp.first(1),
  '00000000-0000-4000-8000-000038580006') ->> 'change_id', true);
reset role;
select pg_temp.invoice(905, 211, pg_temp.period(1), 2000, now());
insert into public.member_term_changes (id, workspace_id, member_id, kind, to_status, due_on, state, source, group_id)
values (pg_temp.u(916), pg_temp.u(101), pg_temp.u(216), 'status', 'paused', pg_temp.first(0), 'pending', 'scheduled', pg_temp.u(917));
select pg_temp.act_as(pg_temp.u(1));
set local role authenticated;
select throws_ok(format($$ select public.cancel_member_term_change(%L) $$, current_setting('t.c211')),
  '55000', 'this change is already on an invoice — schedule a new one',
  'a change whose first period is invoiced is no longer cancelled');
select throws_ok(format($$ select public.cancel_member_term_change(%L) $$, pg_temp.u(916)),
  '55000', 'this change is already on an invoice — schedule a new one',
  'nor a pause whose first month the invoice run has already left out');
reset role;

-- ── a held change approved late ──
insert into public.validation_policies (workspace_id, event_type, required_count, admins_may_validate, validator_scope)
values (pg_temp.u(101), 'subscription_change', 1, true, 'admins')
on conflict do nothing;
select pg_temp.act_as(pg_temp.u(1));
set local role authenticated;
select set_config('t.held', public.schedule_member_share_change(pg_temp.u(214), 50, pg_temp.today(),
  '00000000-0000-4000-8000-000038580010')::text, true);
reset role;
select is(current_setting('t.held')::jsonb ->> 'state', 'pending', 'a change a policy holds waits for approval');
select pg_temp.invoice(906, 214, to_char(pg_temp.fp(pg_temp.today()), 'YYYY-MM'), 4000, now() - interval '1 minute');
update public.events set status = 'confirmed' where id = (current_setting('t.held')::jsonb ->> 'event_id')::uuid;
select is((select state || ' ' || (effective_on = (pg_temp.fp(pg_temp.today()) + interval '1 month')::date)::text
             from public.member_term_changes where request_id = '00000000-0000-4000-8000-000038580010'),
  'applied true', 'approved after its month was invoiced, it takes effect from the next period');
delete from public.validation_policies where workspace_id = pg_temp.u(101) and event_type = 'subscription_change';

-- ── a member who left ──
select pg_temp.act_as(pg_temp.u(1));
set local role authenticated;
select public.schedule_member_pause(pg_temp.u(217), pg_temp.today(), pg_temp.today() + 5,
  '00000000-0000-4000-8000-000038580011');
reset role;
update public.members set status = 'exited' where id = pg_temp.u(217);
select is((select state || ' / ' || reason from public.member_term_changes
            where member_id = pg_temp.u(217) and to_status = 'active' and source = 'scheduled'),
  'cancelled / the member left', 'a member who leaves has their waiting changes cancelled');
update public.members set status = 'exited' where id = pg_temp.u(218);
insert into public.member_term_changes (workspace_id, member_id, kind, to_status, due_on, state, source)
values (pg_temp.u(101), pg_temp.u(218), 'status', 'active', pg_temp.today(), 'scheduled', 'scheduled'),
       (pg_temp.u(101), pg_temp.u(219), 'status', 'active', pg_temp.today(), 'scheduled', 'scheduled');
select public.apply_due_member_term_changes();
select is((select string_agg(state || ' / ' || reason, ', ' order by member_id) from public.member_term_changes
            where member_id in (pg_temp.u(218), pg_temp.u(219)) and source = 'scheduled'),
  'refused / the membership has ended, refused / the member is not paused',
  'a resumption is refused on its day for a member who left, or who is not paused');
select is((select status from public.members where id = pg_temp.u(218)), 'exited', 'and the member stays out');

-- ── the quota checks read the period's terms ──
insert into public.levels (id, workspace_id, name) values (pg_temp.u(601), pg_temp.u(101), 'L');
insert into public.offices (id, workspace_id, level_id, name, x, y, w, h, area_kind)
values (pg_temp.u(602), pg_temp.u(101), pg_temp.u(601), 'O', 0, 0, 10, 10, 'workspace');
insert into public.desks (id, workspace_id, office_id, name, x, y, w, h)
values (pg_temp.u(603), pg_temp.u(101), pg_temp.u(602), 'D', 1, 1, 4, 2);
insert into public.seats (id, workspace_id, desk_id, name, x, y, resource_kind, capacity, parking_kind)
values (pg_temp.u(604), pg_temp.u(101), pg_temp.u(603), 'S1', 1, 1, 'seat', null, null);
-- 222 has a share of 0 from the month after next
select set_config('deskilo.term_change_applying', 'on', true);
update public.members set subscription_pct = 0 where id = pg_temp.u(222);
select set_config('deskilo.term_change_applying', '', true);
insert into public.member_term_changes (workspace_id, member_id, kind, to_pct, from_pct, due_on, effective_on, state, source)
values (pg_temp.u(101), pg_temp.u(222), 'share', 0, 100, pg_temp.first(2), pg_temp.first(2), 'applied', 'scheduled');
insert into public.reservations (workspace_id, member_id, seat_id, starts_at, ends_at)
values (pg_temp.u(101), pg_temp.u(222), pg_temp.u(604), pg_temp.weekday(1), pg_temp.weekday(1) + interval '3 hours'),
       (pg_temp.u(101), pg_temp.u(222), pg_temp.u(604), pg_temp.weekday(2), pg_temp.weekday(2) + interval '3 hours');
select lives_ok(format($$ select public.assert_member_quota(%L, %L) $$, pg_temp.u(222), pg_temp.weekday(1)),
  'a booking in a month of the old share is inside its quota');
select throws_ok(format($$ select public.assert_member_quota(%L, %L) $$, pg_temp.u(222), pg_temp.weekday(2)),
  'DKK02', null, 'and one in a month of the new share of 0 is beyond it');
-- 221 (pay as you go) is paused from next month's first day
select pg_temp.act_as(pg_temp.u(1));
set local role authenticated;
select public.schedule_member_pause(pg_temp.u(221), pg_temp.first(1), null, '00000000-0000-4000-8000-000038580012');
reset role;
insert into public.reservations (workspace_id, member_id, seat_id, starts_at, ends_at)
values (pg_temp.u(101), pg_temp.u(221), pg_temp.u(604), pg_temp.weekday(0), pg_temp.weekday(0) + interval '3 hours');
insert into public.reservations (workspace_id, member_id, seat_id, starts_at, ends_at)
values (pg_temp.u(101), pg_temp.u(221), pg_temp.u(604), pg_temp.weekday(1) + interval '4 hours', pg_temp.weekday(1) + interval '7 hours');
select is(public.member_quota_shortfall(pg_temp.u(221), pg_temp.weekday(0)) || ' / '
       || public.member_quota_shortfall(pg_temp.u(221), pg_temp.weekday(1) + interval '4 hours'), '0 / 1',
  'a month paused on its first day includes no half-day: its use is beyond the quota, the month before is not');
select pg_temp.act_as(pg_temp.u(1));
set local role authenticated;
select is(public.default_tariff_of(pg_temp.u(203)) ->> 'fee_cents', '4000',
  'the default tariff is the share in force this month, not the one set for next month');
reset role;

-- ── who ──
select pg_temp.act_as(pg_temp.u(2));
set local role authenticated;
select throws_ok($$ select public.schedule_member_share_change('00000000-0000-4000-8000-000038580203', 50,
  current_date + 10, gen_random_uuid()) $$, 'DKN01', null,
  'a member without the right schedules nothing');
select is((select count(*)::int from public.member_term_changes where member_id <> pg_temp.u(202)), 0,
  'a member reads only their own changes');
reset role;
select pg_temp.act_as(pg_temp.u(1));
set local role authenticated;
select throws_ok($$ select public.schedule_member_pause('00000000-0000-4000-8000-000038580201',
  current_date + 10, null, gen_random_uuid()) $$, 'DKN01', null,
  'an owner is not paused, as with an immediate status change');
reset role;
-- a pause scheduled for someone who has become an owner since
insert into public.member_term_changes (workspace_id, member_id, kind, to_status, due_on, state, source)
values (pg_temp.u(101), pg_temp.u(201), 'status', 'paused', pg_temp.today(), 'scheduled', 'scheduled');
select public.apply_due_member_term_changes();
select is((select state || ' / ' || reason from public.member_term_changes
            where member_id = pg_temp.u(201) and to_status = 'paused'),
  'refused / an owner hands the workspace over first', 'the sweep refuses it on its day, with the reason');

-- ── periods before dated terms began; another business ──
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by)
values (pg_temp.u(102), 'Before', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(2));
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, subscription_pct, overage_policy, joined_at)
values (pg_temp.u(300), pg_temp.u(102), pg_temp.u(2), true, true, 'active', 100, 'blocked', now() - interval '2 years');
insert into public.members (id, workspace_id, managed_name, status, subscription_pct, overage_policy, joined_at)
values (pg_temp.u(301), pg_temp.u(102), 'Paused before', 'paused', 100, 'blocked', now() - interval '2 years');
delete from public.fee_bands where workspace_id = pg_temp.u(102);
insert into public.fee_bands (workspace_id, from_pct, to_pct, fee_cents)
values (pg_temp.u(102), 0, 50, 2000), (pg_temp.u(102), 50, 100, 4000);
select is(public.member_terms_cut_over(pg_temp.u(102)), 2, 'every member there is starts their dated terms once');
select is(public.member_terms_cut_over(pg_temp.u(102)), 0, 'and only once');
select pg_temp.act_as(pg_temp.u(2));
set local role authenticated;
select is(pg_temp.fee(301, -1) || ' ' || ((pg_temp.statement(301, -1) ->> 'included_half_days')::int > 0)::text
       || ' / ' || pg_temp.fee(301, -2), '100 4000 true / 100 4000',
  'a member paused before dated terms began: past months read as before, fee and half-days');
select is(pg_temp.statement(301, 1) ->> 'fee_cents', '0', 'from the first month after, the pause owes no fee');
reset role;
select is(public.member_billable_in(pg_temp.u(301), pg_temp.period(-1), 'usage'), false,
  'and a past month is invoiced only to an active member, as before');
select pg_temp.act_as(pg_temp.u(1));
set local role authenticated;
select throws_ok(format($$ select public.schedule_member_share_change(%L, 50, %L, gen_random_uuid()) $$,
  pg_temp.u(301), pg_temp.today() + 10), 'DKN01', null, 'a member of another business is refused');
select lives_ok(format($$ select public.sweep_billing_invoices(%L) $$, pg_temp.u(101)),
  'the invoice run goes through members active and paused');
reset role;

-- ── the member's own data ──
select pg_temp.act_as(pg_temp.u(2));
set local role authenticated;
select ok(jsonb_array_length(public.export_my_data(pg_temp.u(101)) -> 'term_changes') >= 1,
  'the member''s export carries their dated changes');
reset role;
select pg_temp.act_as(pg_temp.u(1));
set local role authenticated;
select public.schedule_member_share_change(pg_temp.u(202), 100, pg_temp.today() + 40,
  '00000000-0000-4000-8000-000038580005');
reset role;
select pg_temp.act_as(pg_temp.u(2));
set local role authenticated;
select public.erase_my_membership(pg_temp.u(101));
reset role;
select is((select state || ' / ' || reason from public.member_term_changes
            where request_id = '00000000-0000-4000-8000-000038580005'),
  'cancelled / the membership was erased', 'erasing the membership cancels what was scheduled, with the reason');
select is((select count(*)::int from public.member_term_changes
            where member_id = pg_temp.u(202) and to_status = 'exited'), 0,
  'and its own status change is not recorded as a term');

select * from finish();
rollback;
