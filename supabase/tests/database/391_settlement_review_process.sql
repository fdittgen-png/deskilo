-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3510 (0722): a refused settlement report becomes a process. A review kept
-- for the first time tells every member who may see the finances, once per
-- settlement and reason; a billing manager marks it handled with a note; a
-- handled review leaves the waiting list and stays readable. Rolled back.
begin;
select plan(13);

do $seed$
declare u uuid := '00000000-0000-4000-8000-0000003510a1'; plain uuid := '00000000-0000-4000-8000-0000003510a2';
        other uuid := '00000000-0000-4000-8000-0000003510a3'; ws uuid; ws2 uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
  values (u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner@review.test', '', now(), now(), now()),
         (plain, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'plain@review.test', '', now(), now(), now()),
         (other, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'other@review.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by) values ('Review', 'FR', 'EUR', 'Europe/Paris', u) returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, status) values (ws, u, true, true, 'active'), (ws, plain, false, false, 'active');
  -- another business, whose owner may manage billing there
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by) values ('Elsewhere', 'FR', 'EUR', 'Europe/Paris', other) returning id into ws2;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, status) values (ws2, other, true, true, 'active');
  perform set_config('t.ws', ws::text, false);
  perform set_config('t.other', other::text, false);
  perform set_config('t.owner', u::text, false);
  perform set_config('t.plain', plain::text, false);
  perform public.record_provider_settlement_v1(ws, 'mollie', 'stl_1', 34000, 'EUR', date '2026-03-15', 'paid',
    '[{"period":"2026-03","method":"ideal","description":"iDEAL","cost_count":3,"amount_net_cents":120}]');
end;
$seed$;

create or replace function pg_temp.report(p_amount bigint, p_net int) returns text language sql as $f$
  select public.record_provider_settlement_v1(current_setting('t.ws')::uuid, 'mollie', 'stl_1', p_amount, 'EUR',
    date '2026-03-15', 'paid',
    format('[{"period":"2026-03","method":"ideal","description":"iDEAL","cost_count":3,"amount_net_cents":%s}]', p_net)::jsonb) ->> 'outcome'
$f$;
create or replace function pg_temp.alerts() returns int language sql as $f$
  select count(*)::int from public.events
   where workspace_id = current_setting('t.ws')::uuid and type = 'settlement_review'
$f$;
create or replace function pg_temp.handle(p_user text, p_note text) returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('t.' || p_user), 'role', 'authenticated')::text, true);
  set local role authenticated;
  select public.mark_settlement_review_handled_v1(
           (select id from public.provider_settlement_reviews
             where workspace_id = current_setting('t.ws')::uuid and reason = 'costs_changed'), p_note)::text into v;
  reset role;
  return v;
exception when others then
  reset role;
  return 'ERROR: ' || sqlerrm;
end
$f$;

select is(pg_temp.report(34000, 999), 'refused', 'a changed report is refused');
select is(pg_temp.alerts(), 1, 'and tells the one member who may see the finances (the owner), once');
select is((select subject_member_id::text || '|' || (payload ->> 'reason') from public.events
            where workspace_id = current_setting('t.ws')::uuid and type = 'settlement_review'),
          (select id::text from public.members where user_id = current_setting('t.owner')::uuid) || '|costs_changed',
          'the event names the settlement''s reason, for the owner');
select is(pg_temp.report(34000, 777), 'refused', 'the same kind of change again is refused again');
select is(pg_temp.alerts(), 1, 'but tells no one twice for the same settlement and reason');
select is(pg_temp.report(35000, 120), 'refused', 'another amount is another reason');
select is(pg_temp.alerts(), 2, 'and is told once more');
select ok(public.event_type_view_permissions('settlement_review') = array['viewFinances'],
          'who may read the alert: whoever may see the finances');

select is(pg_temp.handle('plain', 'looked'), 'ERROR: unknown review', 'a member without billing rights cannot handle it');
select is(pg_temp.handle('other', 'looked'), 'ERROR: unknown review',
          'nor can the billing manager of another business');
select is(pg_temp.handle('owner', '  '), 'ERROR: a note of 1 to 1000 characters is required', 'handling needs a note');
select is(pg_temp.handle('owner', 'Mollie corrected a fee; booked through a correction'), '{"handled": true}',
          'the owner marks it handled');
select is((select (handled_by::text = current_setting('t.owner')) || '|' || handled_note || '|' || (handled_at is not null)
             from public.provider_settlement_reviews where reason = 'costs_changed'),
          'true|Mollie corrected a fee; booked through a correction|true',
          'it stays readable: who, when, and the note');

select * from finish();
rollback;
