-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3858 (0766): a member's plan share and pause carry their dates, on one
-- clock, and an invoice freezes its period. Each money case states its
-- amounts and its invoice count:
--  * a change is in force from its date; the job applies what is due, in
--    date order, each once, each on its own, and a second run does nothing;
--  * a subscription invoice freezes the terms it was computed with: a later
--    change, an applied pause or a resumption leave the invoiced month as
--    invoiced; a replacement recomputes from the period's first day, so a
--    change dated the 10th does not enter it;
--  * a share change with a date inside an invoiced period is refused with
--    the earliest date; the immediate command takes that date itself, and
--    so does an approval;
--  * a pause answers which months stay due and which it frees first; a
--    month paused on its first day is not invoiced its fee and includes no
--    half-days, while its use is invoiced;
--  * the invoice run issues this month only for a member resumed from a
--    pause; a full invoice and the other kinds exclude each other;
--  * a period invoiced before dated terms reads the member's row;
--  * the business's own day decides, east and west of UTC.
-- Rolled back.
begin;
select plan(82);

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
  from generate_series(1, 2) n;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by,
                               street, city, postal_code, vat_regime, vat_id, legal_id, feature_flags)
values (pg_temp.u(101), 'Terms', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(1),
        '1 Synthetic Street', 'Capital', '1000', 'vat_registered', 'FR123456789', 'REG-FR', '{"invoicing": true, "moneyTab": true, "subscriptionInvoices": true, "usageInvoices": true}');
insert into public.vat_rates (workspace_id, label, percent, is_default)
values (pg_temp.u(101), 'Synthetic standard', 20, true);
-- 201 the owner; 202 a member with an account; 203-240 members with accounts
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status,
                            subscription_pct, overage_policy, joined_at)
values (pg_temp.u(201), pg_temp.u(101), pg_temp.u(1), true, true, 'active', 100, 'blocked', now() - interval '2 years'),
       (pg_temp.u(202), pg_temp.u(101), pg_temp.u(2), false, false, 'active', 100, 'blocked', now() - interval '2 years');
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(500 + n), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'terms-m' || n || '@example.test', '', now(), now(), now()
  from generate_series(3, 40) n;
update public.profiles set first_name = 'Synthetic', last_name = 'Member ' || right(id::text, 2),
       country_code = 'FR', street = '2 Synthetic Street', city = 'Capital', postal_code = '1000'
 where id in (select pg_temp.u(500 + n) from generate_series(3, 40) n);
insert into public.members (id, workspace_id, user_id, status, subscription_pct, overage_policy, joined_at)
select pg_temp.u(200 + n), pg_temp.u(101), pg_temp.u(500 + n), 'active', 100,
       case when n in (6, 32) then 'payg' else 'blocked' end, now() - interval '2 years'
  from generate_series(3, 40) n;
delete from public.fee_bands where workspace_id = pg_temp.u(101);
insert into public.fee_bands (workspace_id, from_pct, to_pct, fee_cents, overage_fee_cents)
values (pg_temp.u(101), 0, 50, 2000, 1000), (pg_temp.u(101), 50, 100, 4000, 1000);

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
create function pg_temp.inc(p_member int, p_months int) returns int language sql as $$
  select (pg_temp.statement(p_member, p_months) ->> 'included_half_days')::int $$;
-- issue an invoice as the owner: 'issued', or the refusal
create function pg_temp.issue(p_member int, p_months int, p_kind text default 'subscription',
                              p_replaces uuid default null) returns text language plpgsql as $$
begin
  perform pg_temp.act_as(pg_temp.u(1));
  perform public.create_invoice(pg_temp.u(101), pg_temp.u(p_member), pg_temp.period(p_months), p_replaces,
    false, p_kind, false);
  return 'issued';
exception when others then
  return sqlerrm;
end $$;
create function pg_temp.invoices(p_member int, p_months int, p_kind text default 'subscription') returns int
language sql as $$
  select count(*)::int from public.invoices
   where member_id = pg_temp.u(p_member) and period = pg_temp.period(p_months) and kind = p_kind and voided_at is null $$;
create function pg_temp.invoice_id(p_member int, p_months int, p_kind text default 'subscription') returns uuid
language sql as $$
  select id from public.invoices
   where member_id = pg_temp.u(p_member) and period = pg_temp.period(p_months) and kind = p_kind and voided_at is null $$;
-- the job applying a waiting change on its day (the day cannot be moved)
create function pg_temp.apply_on_its_day(p_change uuid) returns void language plpgsql as $$
declare v public.member_term_changes;
begin
  select * into v from public.member_term_changes where id = p_change;
  perform set_config('deskilo.term_change_applying', 'on', true);
  if v.kind = 'share' then
    update public.member_term_changes c set state = 'applied', applied_on = v.due_on,
      from_pct = (select subscription_pct from public.members where id = v.member_id) where c.id = p_change;
    update public.members set subscription_pct = v.to_pct where id = v.member_id;
  else
    update public.member_term_changes c set state = 'applied', applied_on = v.due_on,
      from_status = (select status from public.members where id = v.member_id) where c.id = p_change;
    update public.members set status = v.to_status where id = v.member_id;
  end if;
  perform set_config('deskilo.term_change_applying', '', true);
end $$;
-- a change already applied on [p_on]
create function pg_temp.applied(p_member int, p_on date, p_pct int default null, p_status text default null,
                                p_group uuid default null) returns void language plpgsql as $$
declare v_m public.members;
begin
  select * into v_m from public.members where id = pg_temp.u(p_member);
  insert into public.member_term_changes (workspace_id, member_id, kind, to_pct, from_pct, to_status, from_status,
    due_on, applied_on, state, source, group_id)
  values (v_m.workspace_id, v_m.id, case when p_pct is null then 'status' else 'share' end,
    p_pct, case when p_pct is null then null else v_m.subscription_pct end,
    p_status, case when p_status is null then null else v_m.status end,
    p_on, p_on, 'applied', case when p_group is null then 'immediate' else 'scheduled' end, p_group);
  perform set_config('deskilo.term_change_applying', 'on', true);
  update public.members set subscription_pct = coalesce(p_pct, subscription_pct),
         status = coalesce(p_status, status) where id = v_m.id;
  perform set_config('deskilo.term_change_applying', '', true);
end $$;
-- the first open weekday of a month, at nine
create function pg_temp.weekday(p_months int) returns timestamptz language sql as $$
  select ((select d from generate_series(pg_temp.first(p_months), pg_temp.first(p_months) + 6, interval '1 day') d
            where extract(isodow from d) between 1 and 5 order by d limit 1) + interval '9 hours')
         at time zone 'Europe/Paris' $$;
grant execute on all functions in schema pg_temp to authenticated;

select pg_temp.act_as(pg_temp.u(1));

-- ── a change for next month leaves this one and the last as they were ──
select set_config('t.prev', pg_temp.statement(203, -1)::text, true);
select set_config('t.now', pg_temp.statement(203, 0)::text, true);
set local role authenticated;
select public.schedule_member_share_change(pg_temp.u(203), 50, pg_temp.first(1), '00000000-0000-4000-8000-000038580000');
reset role;
select is(pg_temp.statement(203, -1)::text, current_setting('t.prev'),
  'last month''s statement is byte-equal after a share is scheduled for next month');
select is(pg_temp.statement(203, 0)::text, current_setting('t.now'), 'and this month''s, its quota with it');
select is(pg_temp.fee(203, 1), '50 2000', 'next month reads the new share');
select is(public.default_tariff_of(pg_temp.u(203)) ->> 'fee_cents', '4000',
  'the default tariff is this month''s share, not next month''s');

-- ── the immediate command, in a month not invoiced ──
select set_config('t.prev2', pg_temp.statement(202, -1)::text, true);
set local role authenticated;
select set_config('t.r202', public.request_subscription_change(pg_temp.u(202), 50)::text, true);
reset role;
select is(current_setting('t.r202')::jsonb ->> 'effective_on', pg_temp.first(0)::text,
  'a share written at once in a month not invoiced takes this month''s first day, and says it');
select is((select source || ' ' || state || ' ' || (due_on = pg_temp.first(0))::text
             from public.member_term_changes where member_id = pg_temp.u(202) and kind = 'share'),
  'immediate applied true', 'and is recorded from that day');
select is(pg_temp.statement(202, -1)::text, current_setting('t.prev2'), 'last month does not move');

-- ── scheduling ──
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
set local role authenticated;
select is(public.cancel_member_term_change((current_setting('t.later')::jsonb ->> 'change_id')::uuid), 1,
  'a waiting change no invoice carries is cancelled');
select is(public.schedule_member_share_change(pg_temp.u(204), 75, pg_temp.today(),
  '00000000-0000-4000-8000-000038580002') ->> 'state', 'applied', 'a change due today applies at once');
reset role;
select is((select subscription_pct from public.members where id = pg_temp.u(204)), 75, 'and the member''s row takes it');

-- ── the job: in date order, each once, each on its own ──
insert into public.member_term_changes (workspace_id, member_id, kind, to_pct, due_on, state, source)
values (pg_temp.u(101), pg_temp.u(205), 'share', 50, pg_temp.first(0), 'scheduled', 'scheduled'),
       (pg_temp.u(101), pg_temp.u(205), 'share', 25, pg_temp.first(0), 'scheduled', 'scheduled'),
       (pg_temp.u(101), pg_temp.u(215), 'share', 50, pg_temp.first(-1), 'scheduled', 'scheduled'),
       (pg_temp.u(101), pg_temp.u(215), 'share', 75, pg_temp.first(-1) + 10, 'scheduled', 'scheduled'),
       (pg_temp.u(101), pg_temp.u(206), 'share', 0, pg_temp.today(), 'scheduled', 'scheduled');
select ok(public.apply_due_member_term_changes() >= 5, 'the job applies the changes that are due');
select is((select count(*)::int from public.member_term_changes
            where member_id in (pg_temp.u(205), pg_temp.u(215)) and state = 'scheduled'), 0, 'each once');
select is(public.apply_due_member_term_changes(), 0, 'a second run the same day applies nothing');
select is((select subscription_pct from public.members where id = pg_temp.u(205)), 25,
  'in date order: the later one stands');
select is(pg_temp.fee(215, -1) || ' / ' || pg_temp.fee(215, 0), '50 2000 / 75 4000',
  'a catch-up across dates gives each period the change in force on its first day');
select ok((select state = 'refused' and reason <> '' from public.member_term_changes
            where member_id = pg_temp.u(206) and to_pct = 0),
  'a share the member''s rules refuse on its day is kept as refused, with the reason, and the others went on');
select ok((select bool_and(payload ? 'effective_on') from public.events
            where subject_member_id = pg_temp.u(205) and type = 'subscription_change'),
  'and the record says the date it is in force from');

-- ── a pause ──
set local role authenticated;
select public.schedule_member_pause(pg_temp.u(207), pg_temp.today(), pg_temp.today() + 1,
  '00000000-0000-4000-8000-000038580003');
select public.schedule_member_pause(pg_temp.u(208), pg_temp.today(), null, '00000000-0000-4000-8000-000038580004');
reset role;
select is((pg_temp.statement(208, 1) ->> 'fee_cents') || ' ' || pg_temp.inc(208, 1), '0 0',
  'a month paused on its first day owes no fee and includes no half-day');
select is(pg_temp.statement(207, 1) ->> 'fee_cents', '4000', 'a pause that ends before the month charges it in full');
update public.member_term_changes set due_on = pg_temp.today() where member_id = pg_temp.u(207) and to_status = 'active';
select public.apply_due_member_term_changes();
select is((select status from public.members where id = pg_temp.u(207)), 'active',
  'a pause ending on a date resumes the member that day');

-- ── a. paused at once after next month's advance invoice, resumed in it ──
select is(pg_temp.issue(210, 1), 'issued', 'next month is invoiced in advance');
set local role authenticated;
select set_config('t.a', public.request_member_status_change(pg_temp.u(210), 'paused')::text, true);
reset role;
select is((current_setting('t.a')::jsonb -> 'due') ? pg_temp.period(1)
       and current_setting('t.a')::jsonb ->> 'first_free' = pg_temp.period(2), true,
  'a pause at once answers that the invoiced month stays due and names the first free one');
select is(pg_temp.fee(210, 1) || ' ' || (pg_temp.inc(210, 1) > 0)::text, '100 4000 true',
  'the invoiced month reads its invoice, fee and half-days');
select pg_temp.applied(210, pg_temp.first(1) + 4, p_status => 'active');
select is(pg_temp.fee(210, 2) || ' / ' || pg_temp.issue(210, 2) || ' ' || pg_temp.invoices(210, 2),
  '100 4000 / issued 1', 'resumed on the 5th, the month after is invoiced in full, once');
select is(pg_temp.fee(210, 1), '100 4000', 'and the month of the resumption stays as invoiced');

-- ── b. a pause inside an invoiced month ──
select is(pg_temp.issue(211, 1), 'issued', 'the month is invoiced first');
select set_config('t.b0', pg_temp.statement(211, 1)::text, true);
set local role authenticated;
select set_config('t.b', public.schedule_member_pause(pg_temp.u(211), pg_temp.first(1), pg_temp.first(1) + 19,
  '00000000-0000-4000-8000-000038580005')::text, true);
reset role;
select is((current_setting('t.b')::jsonb -> 'due')::text || ' ' || coalesce(current_setting('t.b')::jsonb ->> 'first_free', 'none'),
  format('["%s"] none', pg_temp.period(1)), 'the scheduling answer names that month as due, and no free month');
select is(pg_temp.statement(211, 1)::text, current_setting('t.b0'), 'its statement equals the invoice when scheduled');
select pg_temp.apply_on_its_day((select id from public.member_term_changes
  where request_id = '00000000-0000-4000-8000-000038580005' and to_status = 'paused'));
select is(pg_temp.statement(211, 1)::text, current_setting('t.b0'), 'on the day the pause starts');
select pg_temp.apply_on_its_day((select id from public.member_term_changes
  where request_id = '00000000-0000-4000-8000-000038580005' and to_status = 'active'));
select is(pg_temp.statement(211, 1)::text || ' ' || (pg_temp.statement(211, 1) ->> 'fee_cents'),
  current_setting('t.b0') || ' 4000', 'and after it ends: 4000, as invoiced');

-- ── c. a pause from the 1st to the 1st two months later ──
set local role authenticated;
select public.schedule_member_pause(pg_temp.u(212), pg_temp.first(1), pg_temp.first(3), '00000000-0000-4000-8000-000038580006');
reset role;
select is(pg_temp.issue(212, 1) || ' / ' || pg_temp.issue(212, 2), 'unknown subject member / unknown subject member',
  'no invoice for the two paused months');
select is(pg_temp.issue(212, 3) || ' ' || (pg_temp.issue(212, 3) like 'period already invoiced%')::text || ' '
       || pg_temp.invoices(212, 3), 'issued true 1', 'the month it ends on is invoiced, exactly once');
select is((pg_temp.statement(212, 1) ->> 'fee_cents') || ' ' || pg_temp.fee(212, 3), '0 100 4000',
  'a paused month owes 0, the month after the pause 4000');

-- ── d. a share scheduled before its month is invoiced in advance ──
set local role authenticated;
select set_config('t.d', public.schedule_member_share_change(pg_temp.u(213), 50, pg_temp.first(1),
  '00000000-0000-4000-8000-000038580007') ->> 'change_id', true);
reset role;
select is(pg_temp.issue(213, 1), 'issued', 'the month is invoiced in advance with the change waiting');
select is(pg_temp.fee(213, 1) || ' / ' || pg_temp.fee(213, 0), '50 2000 / 100 4000',
  'it is invoiced at the new share, and this month keeps the old one');
select set_config('t.d1', pg_temp.inc(213, 1)::text, true);
set local role authenticated;
select throws_ok(format($$ select public.cancel_member_term_change(%L) $$, current_setting('t.d')),
  '55000', 'this change is already on an invoice — schedule a new one',
  'a change an invoice carries is no longer cancelled');
reset role;
select pg_temp.apply_on_its_day(current_setting('t.d')::uuid);
select is(pg_temp.fee(213, 1) || ' ' || pg_temp.inc(213, 1), '50 2000 ' || current_setting('t.d1'),
  'on its day the month still reads 50 %, fee and half-days');

-- ── e. the immediate command in an invoiced month ──
select is(pg_temp.issue(214, 0), 'issued', 'this month is invoiced');
set local role authenticated;
select set_config('t.e', public.request_subscription_change(pg_temp.u(214), 50)::text, true);
reset role;
select is((current_setting('t.e')::jsonb ->> 'state') || ' ' || (current_setting('t.e')::jsonb ->> 'effective_on'),
  'scheduled ' || pg_temp.first(1), 'a share written at once in an invoiced month takes the first day of the next');
select is(pg_temp.fee(214, 0) || ' / ' || pg_temp.fee(214, 1), '100 4000 / 50 2000',
  'this month stays as invoiced, the next reads the new share');
set local role authenticated;
select throws_like(format($$ select public.schedule_member_share_change(%L, 50, %L, gen_random_uuid()) $$,
  pg_temp.u(214), pg_temp.today()), '%already invoiced — the earliest is ' || pg_temp.first(1) || '%',
  'a share dated inside an invoiced month is refused with the earliest date');
reset role;

-- ── a held change approved after its month was invoiced ──
insert into public.validation_policies (workspace_id, event_type, required_count, admins_may_validate, validator_scope)
values (pg_temp.u(101), 'subscription_change', 1, true, 'admins')
on conflict do nothing;
set local role authenticated;
select set_config('t.held', public.request_subscription_change(pg_temp.u(230), 50)::text, true);
reset role;
select is(pg_temp.issue(230, 0), 'issued', 'the month is invoiced while the change waits for approval');
update public.events set status = 'confirmed' where id = (current_setting('t.held')::jsonb ->> 'event_id')::uuid;
select is((select payload ->> 'effective_on' from public.events where id = (current_setting('t.held')::jsonb ->> 'event_id')::uuid)
       || ' / ' || pg_temp.fee(230, 0) || ' / ' || pg_temp.fee(230, 1),
  pg_temp.first(1) || ' / 100 4000 / 50 2000',
  'approved, it takes the first day not invoiced, and the event says it');
delete from public.validation_policies where workspace_id = pg_temp.u(101) and event_type = 'subscription_change';

-- ── g. a full invoice and the other kinds exclude each other ──
select is(pg_temp.issue(220, 0, 'full') || ' / ' || pg_temp.issue(220, 0, 'subscription') || ' / ' || pg_temp.issue(220, 0, 'usage'),
  'issued / period already invoiced for this member / period already invoiced for this member',
  'after a full invoice, no second fee and no second use');
select is(pg_temp.issue(221, 0, 'subscription') || ' / ' || pg_temp.issue(221, 0, 'full'),
  'issued / period already invoiced for this member', 'and after a subscription, no full invoice');

-- ── h. use in a month paused on its first day ──
insert into public.levels (id, workspace_id, name) values (pg_temp.u(601), pg_temp.u(101), 'L');
insert into public.offices (id, workspace_id, level_id, name, x, y, w, h, area_kind)
values (pg_temp.u(602), pg_temp.u(101), pg_temp.u(601), 'O', 0, 0, 10, 10, 'workspace');
insert into public.desks (id, workspace_id, office_id, name, x, y, w, h)
values (pg_temp.u(603), pg_temp.u(101), pg_temp.u(602), 'D', 1, 1, 4, 2);
insert into public.seats (id, workspace_id, desk_id, name, x, y, resource_kind, capacity, parking_kind)
values (pg_temp.u(604), pg_temp.u(101), pg_temp.u(603), 'S1', 1, 1, 'seat', null, null),
       (pg_temp.u(605), pg_temp.u(101), pg_temp.u(603), 'S2', 2, 1, 'seat', null, null);
select pg_temp.applied(222, pg_temp.first(-1) + 5, p_status => 'paused');
insert into public.reservations (workspace_id, member_id, seat_id, starts_at, ends_at)
values (pg_temp.u(101), pg_temp.u(222), pg_temp.u(605), pg_temp.weekday(0), pg_temp.weekday(0) + interval '3 hours'),
       (pg_temp.u(101), pg_temp.u(222), pg_temp.u(605), pg_temp.weekday(0) + interval '4 hours', pg_temp.weekday(0) + interval '7 hours');
select is(pg_temp.issue(222, 0, 'subscription'), 'unknown subject member', 'a month paused on its first day has no fee invoice');
select is((pg_temp.statement(222, 0) ->> 'fee_cents') || ' ' || pg_temp.inc(222, 0) || ' '
       || (pg_temp.statement(222, 0) ->> 'extra_half_days') || ' ' || (pg_temp.statement(222, 0) ->> 'balance_cents'),
  '0 0 2 -2000', 'its two booked half-days are use beyond a quota of 0: 2000 owed');
select set_config('t.h', pg_temp.issue(222, 0, 'usage'), true);
select is(current_setting('t.h') || ' ' || pg_temp.invoices(222, 0, 'usage'), 'issued 1', 'and its use is invoiced');
select is((select sum((l ->> 'amount_cents')::int)::int from public.invoices i, jsonb_array_elements(i.lines) l
            where i.id = pg_temp.invoice_id(222, 0, 'usage')), 2000,
  'for what the statement owes');

-- ── replacement ──
select is(pg_temp.issue(225, 0), 'issued', 'a month invoiced at 100 %');
select pg_temp.applied(225, pg_temp.first(0) + 9, p_pct => 50);
select is(pg_temp.issue(225, 0, 'subscription', pg_temp.invoice_id(225, 0)) || ' ' || pg_temp.fee(225, 0),
  'issued 100 4000', 'a replacement recomputes from the first day: a change dated the 10th does not enter it');
select is(pg_temp.issue(211, 1, 'subscription', pg_temp.invoice_id(211, 1)) || ' ' || pg_temp.fee(211, 1),
  'unknown subject member 100 4000', 'a month paused on its first day is not invoiced again, and keeps its invoice');

-- ── l. a month invoiced before dated terms ──
select pg_temp.applied(224, pg_temp.first(-2), p_status => 'paused');
delete from public.member_term_changes where member_id = pg_temp.u(224);
insert into public.invoices (id, workspace_id, member_id, issuer_member_id, number, title, lines, total_cents,
                             currency, member_name, workspace_name, issuer_name, signature, issued_at, period, kind)
values (pg_temp.u(924), pg_temp.u(101), pg_temp.u(224), pg_temp.u(201), 'T-924', 'T', '[]'::jsonb, 4800,
        'EUR', 'A', 'B', 'O', 'sig', now() - interval '40 days', pg_temp.period(-1), 'subscription');
select is(pg_temp.fee(224, -1) || ' ' || (pg_temp.inc(224, -1) > 0)::text, '100 4000 true',
  'a month invoiced before its terms were frozen reads the member''s row, fee and half-days');

-- ── a refused pause, a pause overtaken ──
update public.members set status = 'pending' where id = pg_temp.u(226);
insert into public.member_term_changes (workspace_id, member_id, kind, to_status, due_on, state, source, group_id)
values (pg_temp.u(101), pg_temp.u(226), 'status', 'paused', pg_temp.today(), 'scheduled', 'scheduled', pg_temp.u(926)),
       (pg_temp.u(101), pg_temp.u(226), 'status', 'active', pg_temp.today() + 5, 'scheduled', 'scheduled', pg_temp.u(926));
select pg_temp.applied(227, pg_temp.first(0), p_status => 'paused', p_group => pg_temp.u(927));
select pg_temp.applied(227, pg_temp.today(), p_status => 'active');
select pg_temp.applied(227, pg_temp.today(), p_status => 'paused');
insert into public.member_term_changes (workspace_id, member_id, kind, to_status, due_on, state, source, group_id)
values (pg_temp.u(101), pg_temp.u(227), 'status', 'active', pg_temp.today(), 'scheduled', 'scheduled', pg_temp.u(927));
select public.apply_due_member_term_changes();
select is((select string_agg(state || ' / ' || reason, ', ' order by due_on) from public.member_term_changes
            where member_id = pg_temp.u(226) and source = 'scheduled'),
  'refused / the member is not active, cancelled / its pause was refused', 'a refused pause takes its resumption with it');
select is((select state || ' / ' || reason from public.member_term_changes
            where member_id = pg_temp.u(227) and state <> 'applied'),
  'refused / the member was paused again since', 'a resumption does not end a pause made since');

-- ── a member who left ──
set local role authenticated;
select public.schedule_member_pause(pg_temp.u(228), pg_temp.today(), pg_temp.today() + 5, '00000000-0000-4000-8000-000038580008');
reset role;
update public.members set status = 'exited' where id = pg_temp.u(228);
select is((select state || ' / ' || reason from public.member_term_changes
            where member_id = pg_temp.u(228) and to_status = 'active' and source = 'scheduled'),
  'cancelled / the member left', 'a member who leaves has their waiting changes cancelled');
update public.members set status = 'exited' where id = pg_temp.u(229);
insert into public.member_term_changes (workspace_id, member_id, kind, to_status, due_on, state, source)
values (pg_temp.u(101), pg_temp.u(229), 'status', 'active', pg_temp.today(), 'scheduled', 'scheduled');
select public.apply_due_member_term_changes();
select is((select state || ' / ' || reason from public.member_term_changes where member_id = pg_temp.u(229) and source = 'scheduled')
       || ' / ' || (select status from public.members where id = pg_temp.u(229)),
  'refused / the membership has ended / exited', 'a resumption is refused for a member who left, who stays out');

-- ── i. a pause scheduled and cancelled leaves the credits as they were ──
insert into public.reservations (id, workspace_id, member_id, seat_id, starts_at, ends_at)
values (pg_temp.u(623), pg_temp.u(101), pg_temp.u(223), pg_temp.u(604), pg_temp.weekday(1), pg_temp.weekday(1) + interval '3 hours');
insert into public.member_credits (id, workspace_id, member_id, half_days) values (pg_temp.u(723), pg_temp.u(101), pg_temp.u(223), 3);
insert into public.member_credit_uses (workspace_id, credit_id, reservation_id, half_days)
values (pg_temp.u(101), pg_temp.u(723), pg_temp.u(623), 1);
select set_config('t.i', (select md5(string_agg(u::text, '' order by u.id)) from public.member_credit_uses u
                           where credit_id = pg_temp.u(723)), true);
set local role authenticated;
select public.cancel_member_term_change((public.schedule_member_pause(pg_temp.u(223), pg_temp.first(1), null,
  '00000000-0000-4000-8000-000038580009') ->> 'change_id')::uuid);
reset role;
select is((select md5(string_agg(u::text, '' order by u.id)) from public.member_credit_uses u where credit_id = pg_temp.u(723)),
  current_setting('t.i'), 'a pause scheduled and cancelled leaves every credit use as it was');

-- ── the quota checks read the period's terms ──
set local role authenticated;
select public.schedule_member_share_change(pg_temp.u(231), 0, pg_temp.first(2), '00000000-0000-4000-8000-000038580010');
select public.schedule_member_pause(pg_temp.u(232), pg_temp.first(1), null, '00000000-0000-4000-8000-000038580011');
reset role;
insert into public.reservations (workspace_id, member_id, seat_id, starts_at, ends_at)
values (pg_temp.u(101), pg_temp.u(231), pg_temp.u(605), pg_temp.weekday(1), pg_temp.weekday(1) + interval '3 hours'),
       (pg_temp.u(101), pg_temp.u(231), pg_temp.u(605), pg_temp.weekday(2), pg_temp.weekday(2) + interval '3 hours'),
       (pg_temp.u(101), pg_temp.u(232), pg_temp.u(604), pg_temp.weekday(0), pg_temp.weekday(0) + interval '3 hours'),
       (pg_temp.u(101), pg_temp.u(232), pg_temp.u(604), pg_temp.weekday(1) + interval '4 hours', pg_temp.weekday(1) + interval '7 hours');
select lives_ok(format($$ select public.assert_member_quota(%L, %L) $$, pg_temp.u(231), pg_temp.weekday(1)),
  'a booking in a month of the old share is inside its quota');
select throws_ok(format($$ select public.assert_member_quota(%L, %L) $$, pg_temp.u(231), pg_temp.weekday(2)),
  'DKK02', null, 'and one in a month of the new share of 0 is beyond it');
select is(public.member_quota_shortfall(pg_temp.u(232), pg_temp.weekday(0)) || ' / '
       || public.member_quota_shortfall(pg_temp.u(232), pg_temp.weekday(1) + interval '4 hours'), '0 / 1',
  'a month paused on its first day includes no half-day: its use is beyond the quota');

-- ── who ──
select pg_temp.act_as(pg_temp.u(2));
set local role authenticated;
select throws_ok($$ select public.schedule_member_share_change('00000000-0000-4000-8000-000038580203', 50,
  current_date + 10, gen_random_uuid()) $$, 'DKN01', null, 'a member without the right schedules nothing');
select is((select count(*)::int from public.member_term_changes where member_id <> pg_temp.u(202)), 0,
  'a member reads only their own changes');
select is((select count(*)::int from public.member_period_terms where member_id <> pg_temp.u(202)), 0,
  'and only their own invoiced terms');
reset role;
select pg_temp.act_as(pg_temp.u(1));
set local role authenticated;
select throws_ok($$ select public.schedule_member_pause('00000000-0000-4000-8000-000038580201',
  current_date + 10, null, gen_random_uuid()) $$, 'DKN01', null, 'an owner is not paused');
reset role;
insert into public.member_term_changes (workspace_id, member_id, kind, to_status, due_on, state, source)
values (pg_temp.u(101), pg_temp.u(201), 'status', 'paused', pg_temp.today(), 'scheduled', 'scheduled');
select public.apply_due_member_term_changes();
select is((select state || ' / ' || reason from public.member_term_changes
            where member_id = pg_temp.u(201) and to_status = 'paused'),
  'refused / an owner hands the workspace over first', 'nor by the job, for someone who has become an owner since');

-- ── another business; east and west of UTC ──
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by)
values (pg_temp.u(102), 'Other', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(2)),
       (pg_temp.u(103), 'East', 'FR', 'EUR', 'Pacific/Kiritimati', pg_temp.u(1)),
       (pg_temp.u(104), 'West', 'FR', 'EUR', 'Pacific/Pago_Pago', pg_temp.u(1));
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status, subscription_pct, overage_policy, joined_at)
values (pg_temp.u(300), pg_temp.u(102), pg_temp.u(2), true, true, 'active', 100, 'blocked', now() - interval '2 years'),
       (pg_temp.u(400), pg_temp.u(103), pg_temp.u(1), true, true, 'active', 100, 'blocked', now() - interval '2 years'),
       (pg_temp.u(410), pg_temp.u(104), pg_temp.u(1), true, true, 'active', 100, 'blocked', now() - interval '2 years');
insert into public.members (id, workspace_id, managed_name, status, subscription_pct, overage_policy, joined_at)
values (pg_temp.u(301), pg_temp.u(102), 'Other', 'active', 100, 'blocked', now() - interval '2 years'),
       (pg_temp.u(401), pg_temp.u(103), 'East', 'active', 100, 'blocked', now() - interval '2 years'),
       (pg_temp.u(411), pg_temp.u(104), 'West', 'active', 100, 'blocked', now() - interval '2 years');
select set_config('t.east', public.workspace_today(pg_temp.u(103))::text, true);
select set_config('t.west', public.workspace_today(pg_temp.u(104))::text, true);
set local role authenticated;
select throws_ok(format($$ select public.schedule_member_share_change(%L, 50, %L, gen_random_uuid()) $$,
  pg_temp.u(301), pg_temp.today() + 10), 'DKN01', null, 'a member of another business is refused');
select is(public.schedule_member_share_change(pg_temp.u(401), 50, current_setting('t.east')::date, gen_random_uuid()) ->> 'state'
       || ' / ' || (public.schedule_member_share_change(pg_temp.u(411), 50, current_setting('t.west')::date, gen_random_uuid()) ->> 'state'),
  'applied / applied', 'east and west of UTC, the business''s own today applies at once');
select throws_ok(format($$ select public.schedule_member_share_change(%L, 60, %L, gen_random_uuid()) $$,
  pg_temp.u(401), current_setting('t.east')::date - 1), '22023', 'a change is scheduled for today or later',
  'and its yesterday is refused, though it may be today elsewhere');
reset role;
select ok(current_setting('t.east')::date > current_setting('t.west')::date,
  'the two businesses are on different days');

-- ── the member's own data ──
select pg_temp.act_as(pg_temp.u(2));
set local role authenticated;
select ok(jsonb_array_length(public.export_my_data(pg_temp.u(101)) -> 'term_changes') >= 1
      and public.export_my_data(pg_temp.u(101)) ? 'period_terms',
  'the member''s export carries their dated changes and their invoiced terms');
reset role;
select pg_temp.act_as(pg_temp.u(1));
set local role authenticated;
select public.schedule_member_share_change(pg_temp.u(202), 100, pg_temp.today() + 40, '00000000-0000-4000-8000-000038580012');
reset role;
select pg_temp.act_as(pg_temp.u(2));
set local role authenticated;
select public.erase_my_membership(pg_temp.u(101));
reset role;
select is((select state || ' / ' || reason from public.member_term_changes
            where request_id = '00000000-0000-4000-8000-000038580012'),
  'cancelled / the membership was erased', 'erasing the membership cancels what was scheduled, with the reason');
select is((select count(*)::int from public.member_term_changes
            where member_id = pg_temp.u(202) and to_status = 'exited'), 0,
  'and its own status change is not recorded as a term');

-- ── the invoice run ──
select pg_temp.act_as(pg_temp.u(1));
-- 216 joined this month; 217 approved from pending; 218 back from exited; 219 resumed from a pause on the 1st
update public.members set joined_at = now() where id = pg_temp.u(216);
update public.members set status = 'pending' where id = pg_temp.u(217);
select pg_temp.applied(217, pg_temp.first(0), p_status => 'active');
update public.members set status = 'exited' where id = pg_temp.u(218);
select pg_temp.applied(218, pg_temp.first(0), p_status => 'active');
select pg_temp.applied(219, pg_temp.first(-1), p_status => 'paused');
select pg_temp.applied(219, pg_temp.first(0), p_status => 'active');
select lives_ok(format($$ select public.sweep_billing_invoices(%L) $$, pg_temp.u(101)), 'the invoice run goes through');
select is(pg_temp.invoices(216, 0) + pg_temp.invoices(217, 0) + pg_temp.invoices(218, 0), 0,
  'no invoice for this month for a joiner, an approval or a member back from leaving');
select is(pg_temp.invoices(219, 0), 1, 'a member resumed from a pause on the 1st is invoiced this month, once');
select set_config('t.k', (select count(*)::text from public.invoices where workspace_id = pg_temp.u(101)), true);
select public.sweep_billing_invoices(pg_temp.u(101));
select is((select count(*)::text from public.invoices where workspace_id = pg_temp.u(101)), current_setting('t.k'),
  'a second run issues nothing more');

select * from finish();
rollback;
