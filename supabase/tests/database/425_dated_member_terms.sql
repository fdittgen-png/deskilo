-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3858 (0766): a member's plan share and pause carry their dates. A past
-- period reads its terms from the store; a share changed for next month
-- leaves last month's and this month's statements as they were; a change due
-- today applies at once and one for later waits; the sweep catches up in date
-- order, once, and a change whose first period was invoiced takes effect from
-- the first period not yet invoiced; a change the row refuses on its day is
-- kept with its reason; a pause from one date to another stops the fee of a
-- month paused on its first day and resumes the member on its last date.
-- Rolled back.
begin;
select plan(26);

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
       case when n = 6 then 'payg' else 'blocked' end, now() - interval '2 years'
  from generate_series(3, 8) n;
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
select ok(public.apply_due_member_term_changes() >= 2, 'the sweep applies the changes that are due');
select is((select count(*)::int from public.member_term_changes
            where member_id = pg_temp.u(205) and state = 'scheduled'), 0, 'each once');
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

select * from finish();
rollback;
