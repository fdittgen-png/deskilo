-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1617: the bounded MCP reads — paged with a scoped cursor, windowed,
-- own-records only, validation visibility by role, and a can_respond
-- preview asked of respond_to_event itself that leaves nothing behind.
begin;
select plan(12);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end;
$$;
create function pg_temp.read(p_user uuid, p_op text, p_args jsonb) returns jsonb language sql as $$
  select public.mcp_read_v1(current_setting('t.w')::uuid,
    (select m from public.members m where m.workspace_id = current_setting('t.w')::uuid and m.user_id = p_user),
    p_op, p_args);
$$;
create function pg_temp.at(p_days integer, p_time time) returns text language sql as $$
  select to_char((((now() at time zone 'Europe/Paris')::date + p_days + p_time) at time zone 'Europe/Paris') at time zone 'UTC',
                 'YYYY-MM-DD"T"HH24:MI:SS"Z"');
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000000166a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'o1617@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000000166a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1617@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000000166a3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'v1617@deskilo.test', '', now(), now(), now());
select pg_temp.act_as('00000000-0000-4000-8000-0000000166a1');
select set_config('t.w', public.create_workspace('Reads', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select public.apply_workspace_template(current_setting('t.w')::uuid, (select id from public.workspace_templates where key = 'tiny'));
reset role;
insert into public.members (workspace_id, user_id, status) values
 (current_setting('t.w')::uuid, '00000000-0000-4000-8000-0000000166a2', 'active'),
 (current_setting('t.w')::uuid, '00000000-0000-4000-8000-0000000166a3', 'active');
select set_config('t.seat', (select id::text from public.seats where workspace_id = current_setting('t.w')::uuid order by id limit 1), true);
select set_config('t.u', (select id::text from public.members where workspace_id = current_setting('t.w')::uuid
  and user_id = '00000000-0000-4000-8000-0000000166a2'), true);
insert into public.reservations (workspace_id, seat_id, member_id, starts_at, ends_at, status)
select current_setting('t.w')::uuid, current_setting('t.seat')::uuid, current_setting('t.u')::uuid,
       pg_temp.at(d, '08:00')::timestamptz, pg_temp.at(d, '12:00')::timestamptz, 'reserved'
  from generate_series(2, 4) d;
insert into public.reservations (workspace_id, seat_id, member_id, starts_at, ends_at, status)
values (current_setting('t.w')::uuid, current_setting('t.seat')::uuid, current_setting('t.u')::uuid,
        now() - interval '3 days', now() - interval '3 days' + interval '4 hours', 'completed');
select pg_temp.act_as('00000000-0000-4000-8000-0000000166a2');
select set_config('t.ev', public.request_reservation_deletion(
  (select id from public.reservations where member_id = current_setting('t.u')::uuid and status = 'completed'), 'mistake')::text, true);
reset role;

select set_config('t.win', json_build_object('from', pg_temp.at(0, '00:00'), 'to', pg_temp.at(10, '00:00'), 'limit', 2)::text, true);
select set_config('t.p1', pg_temp.read('00000000-0000-4000-8000-0000000166a2', 'list_my_reservations', current_setting('t.win')::jsonb)::text, true);
select is(jsonb_array_length(current_setting('t.p1')::jsonb->'items'), 2, 'a page is the limit');
select ok(current_setting('t.p1')::jsonb->>'next_cursor' is not null, 'and says there is more');
select is(jsonb_array_length(pg_temp.read('00000000-0000-4000-8000-0000000166a2', 'list_my_reservations',
  current_setting('t.win')::jsonb || jsonb_build_object('cursor', current_setting('t.p1')::jsonb->>'next_cursor'))->'items'), 1,
  'the cursor continues where the page stopped');
select throws_ok(format($$select pg_temp.read('00000000-0000-4000-8000-0000000166a2', 'list_pending_validations', '{"cursor": %s}')$$,
  to_jsonb(current_setting('t.p1')::jsonb->>'next_cursor')), '22023', null, 'a cursor from another operation is refused');
select is(pg_temp.read('00000000-0000-4000-8000-0000000166a2', 'list_my_reservations',
  '{"from":"2026-10-01T00:00:00Z","to":"2026-11-10T00:00:00Z"}')->>'code', 'window', 'more than 31 days is refused');
select is(jsonb_array_length(pg_temp.read('00000000-0000-4000-8000-0000000166a3', 'list_my_reservations',
  current_setting('t.win')::jsonb)->'items'), 0, 'another member reads none of them');
select is((select r->>'free' from jsonb_array_elements(pg_temp.read('00000000-0000-4000-8000-0000000166a2', 'get_availability',
  jsonb_build_object('starts_at', pg_temp.at(2, '09:00'), 'ends_at', pg_temp.at(2, '10:00')))->'items') r
  where r->>'seat_id' = current_setting('t.seat')), 'false', 'the booked seat is not free');

select pg_temp.act_as('00000000-0000-4000-8000-0000000166a1');
select is((pg_temp.read('00000000-0000-4000-8000-0000000166a1', 'get_validation',
  jsonb_build_object('event_id', current_setting('t.ev')))->>'can_respond')::boolean, true, 'the owner may answer');
select pg_temp.act_as('00000000-0000-4000-8000-0000000166a2');
select is((pg_temp.read('00000000-0000-4000-8000-0000000166a2', 'get_validation',
  jsonb_build_object('event_id', current_setting('t.ev')))->>'can_respond')::boolean, false, 'the author may not');
select pg_temp.act_as('00000000-0000-4000-8000-0000000166a3');
select is(jsonb_array_length(pg_temp.read('00000000-0000-4000-8000-0000000166a3', 'list_pending_validations', '{}')->'items'), 0,
  'a bystander sees no pending validation');
select is(pg_temp.read('00000000-0000-4000-8000-0000000166a3', 'get_validation',
  jsonb_build_object('event_id', current_setting('t.ev')))->>'code', 'not_found', 'nor its detail');
reset role;
select is((select status || '/' || (select count(*) from public.event_decisions d where d.event_id = e.id)
  from public.events e where e.id = current_setting('t.ev')::uuid), 'pending/0', 'the previews decided nothing');

select * from finish();
rollback;
