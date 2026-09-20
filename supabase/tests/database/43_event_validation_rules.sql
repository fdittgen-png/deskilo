-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #1454 — an approval trail enforces the decisions it records.
--
-- Two rules were only ever exercised through Dart fakes:
--
--   * an unconfirmed delegated action cannot take effect
--     (`respond_to_event`, its quorum, and the 0181 apply trigger);
--   * nobody validates their own event (0086), except where an owner
--     explicitly allowed it: `owner_may_self_validate` (0149) and the
--     reservation-deletion owner switch (0119, narrowed by 0121).
--
-- They are driven here through the real RPCs, as `authenticated`, with
-- seven distinct people: the owner, the admin who acts, an independent
-- admin, the member whose membership changes, the member a payment
-- credits, a member without rights, and the owner of another workspace. The last section removes each guard
-- in turn and shows the forbidden effect then happens, so the refusals
-- above are known to come from those guards and not from the fixture.
begin;
select plan(47);

create or replace function pg_temp.act_as(p_user uuid) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, false);
  perform set_config('request.jwt.claim.sub', p_user::text, false);
  execute 'set local role authenticated';
end
$act$;

create or replace function pg_temp.id(p_key text) returns uuid language sql as $id$
  select current_setting('deskilo.ev.' || p_key)::uuid;
$id$;

-- "<event status>/<member status>" — read as the seeding role.
create or replace function pg_temp.state(p_event text, p_member text) returns text language sql as $st$
  select e.status || '/' || m.status
    from public.events e, public.members m
   where e.id = pg_temp.id(p_event) and m.id = pg_temp.id(p_member);
$st$;

-- "<event status>/<ledger rows>/<posted cents>" for a payment event.
create or replace function pg_temp.money(p_event text) returns text language sql as $mo$
  select e.status || '/' || count(l.id) || '/' || coalesce(sum(l.amount_cents), 0)
    from public.events e
    left join public.ledger_entries l on l.event_id = e.id
   where e.id = pg_temp.id(p_event)
   group by e.status;
$mo$;

-- Replaces one exact piece of respond_to_event, or fails if it is gone.
create or replace function pg_temp.patch(p_from text, p_to text) returns void language plpgsql as $pa$
declare v_def text := pg_get_functiondef('public.respond_to_event(uuid,boolean)'::regprocedure);
begin
  if position(p_from in v_def) = 0 then
    raise exception 'respond_to_event no longer contains: %', p_from;
  end if;
  execute replace(v_def, p_from, p_to);
end
$pa$;

create or replace function pg_temp.restore() returns void language plpgsql as $re$
begin
  execute current_setting('deskilo.ev.orig');
end
$re$;

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_owner uuid := '00000000-0000-4000-8000-000000014540';
  u_actor uuid := '00000000-0000-4000-8000-000000014541';
  u_peer  uuid := '00000000-0000-4000-8000-000000014542';
  u_subj  uuid := '00000000-0000-4000-8000-000000014543';
  u_plain uuid := '00000000-0000-4000-8000-000000014544';
  u_other uuid := '00000000-0000-4000-8000-000000014545';
  u_res   uuid := '00000000-0000-4000-8000-000000014546';
  ws uuid; other_ws uuid;
  m_owner uuid; m_actor uuid; m_peer uuid; m_subj uuid; m_plain uuid; m_res uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'validation-' || n || '@deskilo.test', '', now(), now(), now()
    from (values (u_owner, 'owner'), (u_actor, 'actor'), (u_peer, 'peer'),
                 (u_subj, 'subject'), (u_plain, 'plain'), (u_other, 'other'),
                 (u_res, 'resident')) v(u, n);

  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Validation', 'FR', 'EUR', 'Europe/Paris', u_owner) returning id into ws;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Elsewhere', 'FR', 'EUR', 'Europe/Paris', u_other) returning id into other_ws;

  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_owner, true, true) returning id into m_owner;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_actor, false, true) returning id into m_actor;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_peer, false, true) returning id into m_peer;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_subj, false, false) returning id into m_subj;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_plain, false, false) returning id into m_plain;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_res, false, false) returning id into m_res;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (other_ws, u_other, true, true);

  -- The workspace's rules: a membership change and a payment each need
  -- two accepts; a reservation deletion settles itself for the owner
  -- only. Nobody may approve their own act (both switches default false).
  insert into public.validation_policies (workspace_id, event_type, required_count)
  values (ws, 'member_status_change', 2), (ws, 'payment', 2);
  insert into public.validation_policies
    (workspace_id, event_type, required_count, auto_validate_owner, auto_validate_admin)
  values (ws, 'reservation_delete', 1, true, false);

  -- Two finished bookings to delete: the owner's and the acting admin's.
  insert into public.reservations (workspace_id, member_id, starts_at, ends_at, status, space_label)
  values (ws, m_owner, now() - interval '2 days', now() - interval '2 days' + interval '4 hours',
          'completed', 'owner''s room'),
         (ws, m_actor, now() - interval '3 days', now() - interval '3 days' + interval '4 hours',
          'completed', 'admin''s room');

  perform set_config('deskilo.ev.ws', ws::text, false);
  perform set_config('deskilo.ev.other_ws', other_ws::text, false);
  perform set_config('deskilo.ev.owner', m_owner::text, false);
  perform set_config('deskilo.ev.actor', m_actor::text, false);
  perform set_config('deskilo.ev.peer', m_peer::text, false);
  perform set_config('deskilo.ev.subject', m_subj::text, false);
  perform set_config('deskilo.ev.plain', m_plain::text, false);
  perform set_config('deskilo.ev.resident', m_res::text, false);
  perform set_config('deskilo.ev.owners_booking',
    (select id::text from public.reservations where member_id = m_owner), false);
  perform set_config('deskilo.ev.actors_booking',
    (select id::text from public.reservations where member_id = m_actor), false);
end;
$seed$;

select pg_temp.seed();

-- ── Who holds what ───────────────────────────────────────────────────────

select pg_temp.act_as('00000000-0000-4000-8000-000000014544');
select ok(not public.has_permission(pg_temp.id('ws'), 'manageMembers')
          and not public.is_owner_of(pg_temp.id('ws')),
  'the plain member holds neither manageMembers nor ownership');

select pg_temp.act_as('00000000-0000-4000-8000-000000014541');
select ok(public.has_permission(pg_temp.id('ws'), 'manageMembers')
          and not public.is_owner_of(pg_temp.id('ws')),
  'the acting admin may request a membership change but is not an owner');

select pg_temp.act_as('00000000-0000-4000-8000-000000014545');
select ok(not public.is_member_of(pg_temp.id('ws')) and public.is_owner_of(pg_temp.id('other_ws')),
  'the other caller owns another workspace and is not a member of this one');

-- ── A delegated membership change waits for its quorum ───────────────────

select pg_temp.act_as('00000000-0000-4000-8000-000000014541');
select set_config('deskilo.ev.e1',
  public.request_member_status_change(pg_temp.id('resident'), 'paused') ->> 'event_id', false);

reset role;
select is(pg_temp.state('e1', 'resident'), 'pending/active',
  'a delegated status change enters pending and the member is untouched');

select pg_temp.act_as('00000000-0000-4000-8000-000000014544');
select throws_ok(
  $$ select public.request_member_status_change(pg_temp.id('resident'), 'exited') $$,
  'not allowed to change memberships',
  'the plain member really lacks the permission: requesting the change is refused');

select pg_temp.act_as('00000000-0000-4000-8000-000000014541');
select throws_ok($$ select public.respond_to_event(pg_temp.id('e1'), true) $$,
  'you are not an eligible validator for this event',
  'the admin who asked cannot approve their own request');

select pg_temp.act_as('00000000-0000-4000-8000-000000014544');
select throws_ok($$ select public.respond_to_event(pg_temp.id('e1'), true) $$,
  'you are not an eligible validator for this event',
  'a member without validator rights cannot approve it');

select pg_temp.act_as('00000000-0000-4000-8000-000000014546');
select throws_ok($$ select public.respond_to_event(pg_temp.id('e1'), true) $$,
  'you are not an eligible validator for this event',
  'nor can the member it concerns');

select pg_temp.act_as('00000000-0000-4000-8000-000000014545');
select throws_ok($$ select public.respond_to_event(pg_temp.id('e1'), true) $$,
  'not a member',
  'a caller from another workspace is refused');

select pg_temp.act_as('00000000-0000-4000-8000-000000014541');
update public.events set status = 'confirmed', decided_at = now() where id = pg_temp.id('e1');
select throws_ok(
  $$ insert into public.event_decisions (event_id, member_id, decision)
     values (pg_temp.id('e1'), pg_temp.id('peer'), 'accept') $$,
  '42501', null,
  'a decision row cannot be written around the function');

reset role;
select is(pg_temp.state('e1', 'resident'), 'pending/active',
  'and writing the event status directly matches no row: still pending, member untouched');

select pg_temp.act_as('00000000-0000-4000-8000-000000014542');
select lives_ok($$ select public.respond_to_event(pg_temp.id('e1'), true) $$,
  'an independent admin accepts');

reset role;
select is(pg_temp.state('e1', 'resident'), 'pending/active',
  'one accept of the two required leaves it pending and the member untouched');

select pg_temp.act_as('00000000-0000-4000-8000-000000014542');
select throws_ok($$ select public.respond_to_event(pg_temp.id('e1'), true) $$,
  'you already decided this event',
  'the same validator cannot count twice');

select pg_temp.act_as('00000000-0000-4000-8000-000000014540');
select lives_ok($$ select public.respond_to_event(pg_temp.id('e1'), true) $$,
  'a second eligible validator accepts');

reset role;
select is(pg_temp.state('e1', 'resident'), 'confirmed/paused',
  'the quorum reached, the change applies');
select is(
  (select count(*)::int from public.event_decisions
    where event_id = pg_temp.id('e1') and decision = 'accept'),
  2, 'on exactly two recorded accepts');

select pg_temp.act_as('00000000-0000-4000-8000-000000014542');
select throws_ok($$ select public.respond_to_event(pg_temp.id('e1'), true) $$,
  'already decided',
  'a replayed decision on a settled event is refused');

-- ── A rejection changes nothing ──────────────────────────────────────────

select pg_temp.act_as('00000000-0000-4000-8000-000000014541');
select set_config('deskilo.ev.e2',
  public.request_member_status_change(pg_temp.id('resident'), 'exited') ->> 'event_id', false);

select pg_temp.act_as('00000000-0000-4000-8000-000000014540');
select lives_ok($$ select public.respond_to_event(pg_temp.id('e2'), false) $$,
  'an eligible validator rejects');

select pg_temp.act_as('00000000-0000-4000-8000-000000014542');
select throws_ok($$ select public.respond_to_event(pg_temp.id('e2'), true) $$,
  'already decided',
  'and a later accept cannot revive it');

reset role;
select is(pg_temp.state('e2', 'resident'), 'rejected/paused',
  'a rejected change leaves the member untouched');

-- ── The owner exception, beside the ordinary refusal ─────────────────────

update public.validation_policies set required_count = 1
 where workspace_id = pg_temp.id('ws') and event_type = 'member_status_change';

select pg_temp.act_as('00000000-0000-4000-8000-000000014540');
select set_config('deskilo.ev.e3',
  public.request_member_status_change(pg_temp.id('resident'), 'active') ->> 'event_id', false);
select throws_ok($$ select public.respond_to_event(pg_temp.id('e3'), true) $$,
  'you are not an eligible validator for this event',
  'by default the owner cannot approve their own request either');

reset role;
update public.validation_policies set owner_may_self_validate = true
 where workspace_id = pg_temp.id('ws') and event_type = 'member_status_change';

select pg_temp.act_as('00000000-0000-4000-8000-000000014541');
select set_config('deskilo.ev.e4',
  public.request_member_status_change(pg_temp.id('resident'), 'exited') ->> 'event_id', false);
select throws_ok($$ select public.respond_to_event(pg_temp.id('e4'), true) $$,
  'you are not an eligible validator for this event',
  'owner_may_self_validate does not extend to an admin');

select pg_temp.act_as('00000000-0000-4000-8000-000000014540');
select lives_ok($$ select public.respond_to_event(pg_temp.id('e3'), true) $$,
  'with owner_may_self_validate the owner signs off their own act');

reset role;
select is(pg_temp.state('e3', 'resident'), 'confirmed/active', 'and it applies');
select is(pg_temp.state('e4', 'resident'), 'pending/active',
  'while the admin''s own request still waits, and its target has not moved');

-- The reservation-deletion switch (0119/0121) is the owner's alone.
select pg_temp.act_as('00000000-0000-4000-8000-000000014540');
select set_config('deskilo.ev.d1',
  public.request_reservation_deletion(pg_temp.id('owners_booking'), 'owner')::text, false);
select pg_temp.act_as('00000000-0000-4000-8000-000000014541');
select set_config('deskilo.ev.d2',
  public.request_reservation_deletion(pg_temp.id('actors_booking'), 'admin')::text, false);

reset role;
select is(
  (select e.status || '/' || r.status || '/' ||
          (select count(*) from public.event_decisions d
            where d.event_id = e.id and d.member_id is null and d.decided_by_system)
     from public.events e, public.reservations r
    where e.id = pg_temp.id('d1') and r.id = pg_temp.id('owners_booking')),
  'confirmed/cancelled/1',
  'the owner switch settles the owner''s own deletion at birth, as a system decision');
select is(
  (select e.status || '/' || r.status || '/' ||
          (select count(*) from public.event_decisions d where d.event_id = e.id)
     from public.events e, public.reservations r
    where e.id = pg_temp.id('d2') and r.id = pg_temp.id('actors_booking')),
  'pending/completed/0',
  'the owner switch does not settle an admin''s deletion');

select pg_temp.act_as('00000000-0000-4000-8000-000000014541');
select throws_ok($$ select public.respond_to_event(pg_temp.id('d2'), true) $$,
  'you are not an eligible validator for this event',
  'and the admin cannot settle it themselves');

-- ── Money: a recorded payment posts only once validated ──────────────────

select pg_temp.act_as('00000000-0000-4000-8000-000000014541');
select set_config('deskilo.ev.f1',
  public.record_payment(pg_temp.id('ws'), pg_temp.id('subject'), 4200,
                        'cash at the desk', 'cash', null, '2026-09')::text, false);

reset role;
select is(pg_temp.money('f1'), 'pending/0/0',
  'a payment recorded for a member enters pending and posts no ledger credit');

select pg_temp.act_as('00000000-0000-4000-8000-000000014541');
select throws_ok($$ select public.respond_to_event(pg_temp.id('f1'), true) $$,
  'you are not an eligible validator for this event',
  'the admin who recorded it cannot approve it');

select pg_temp.act_as('00000000-0000-4000-8000-000000014544');
select throws_ok($$ select public.respond_to_event(pg_temp.id('f1'), true) $$,
  'you are not an eligible validator for this event',
  'nor can a member without validator rights');

select pg_temp.act_as('00000000-0000-4000-8000-000000014545');
select throws_ok($$ select public.respond_to_event(pg_temp.id('f1'), true) $$,
  'not a member',
  'nor a caller from another workspace');

select pg_temp.act_as('00000000-0000-4000-8000-000000014543');
select lives_ok($$ select public.respond_to_event(pg_temp.id('f1'), true) $$,
  'the member it credits confirms it');

reset role;
select is(pg_temp.money('f1'), 'pending/0/0',
  'the member''s confirmation alone does not reach the quorum of two: nothing posted');

select pg_temp.act_as('00000000-0000-4000-8000-000000014542');
select lives_ok($$ select public.respond_to_event(pg_temp.id('f1'), true) $$,
  'an independent admin completes the quorum');

reset role;
select is(pg_temp.money('f1'), 'confirmed/1/4200',
  'the credit is posted, once, for the recorded amount');

select pg_temp.act_as('00000000-0000-4000-8000-000000014540');
select throws_ok($$ select public.respond_to_event(pg_temp.id('f1'), true) $$,
  'already decided',
  'a replayed accept is refused');

reset role;
select is(pg_temp.money('f1'), 'confirmed/1/4200', 'and posts nothing more');

select pg_temp.act_as('00000000-0000-4000-8000-000000014541');
select set_config('deskilo.ev.f2',
  public.record_payment(pg_temp.id('ws'), pg_temp.id('subject'), 1300,
                        'transfer', 'transfer', null, '2026-09')::text, false);
select pg_temp.act_as('00000000-0000-4000-8000-000000014542');
select public.respond_to_event(pg_temp.id('f2'), true);

select pg_temp.act_as('00000000-0000-4000-8000-000000014540');
select lives_ok($$ select public.respond_to_event(pg_temp.id('f2'), false) $$,
  'an eligible validator rejects a payment another has already accepted');

select pg_temp.act_as('00000000-0000-4000-8000-000000014543');
select throws_ok($$ select public.respond_to_event(pg_temp.id('f2'), true) $$,
  'already decided',
  'the member cannot revive it');

reset role;
select is(pg_temp.money('f2'), 'rejected/0/0',
  'a rejected payment posts no ledger credit');

-- ── The controls: remove each guard, and the forbidden effect happens ────

select set_config('deskilo.ev.orig',
  pg_get_functiondef('public.respond_to_event(uuid,boolean)'::regprocedure), false);
select ok(
  position('raise exception ''you are not an eligible validator for this event'';'
           in current_setting('deskilo.ev.orig')) > 0
  and position('v_required := greatest(1, v_policy.required_count);'
               in current_setting('deskilo.ev.orig')) > 0,
  'both guards are where the controls below remove them');

select pg_temp.patch('raise exception ''you are not an eligible validator for this event'';', 'null;');

select pg_temp.act_as('00000000-0000-4000-8000-000000014541');
select set_config('deskilo.ev.e5',
  public.request_member_status_change(pg_temp.id('resident'), 'paused') ->> 'event_id', false);
select lives_ok($$ select public.respond_to_event(pg_temp.id('e5'), true) $$,
  'without the eligibility refusal, the admin approves their own request');

reset role;
select is(pg_temp.state('e5', 'resident'), 'confirmed/paused',
  'and it takes effect: the self-approval refusals above come from that check');

select pg_temp.restore();
select pg_temp.patch('v_required := greatest(1, v_policy.required_count);', 'v_required := 1;');

select pg_temp.act_as('00000000-0000-4000-8000-000000014541');
select set_config('deskilo.ev.f3',
  public.record_payment(pg_temp.id('ws'), pg_temp.id('subject'), 5000,
                        'cheque', 'cheque', null, '2026-09')::text, false);
select pg_temp.act_as('00000000-0000-4000-8000-000000014543');
select public.respond_to_event(pg_temp.id('f3'), true);

reset role;
select is(pg_temp.money('f3'), 'confirmed/1/5000',
  'without the quorum count, the member''s confirmation alone posts the credit: the pending result above comes from the quorum');

select pg_temp.restore();
select is(pg_get_functiondef('public.respond_to_event(uuid,boolean)'::regprocedure),
  current_setting('deskilo.ev.orig'), 'respond_to_event is back to its real body');

select * from finish();
rollback;
