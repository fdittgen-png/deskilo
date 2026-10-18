-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2569 / 0485 (C2b): the lease reminders on the calendar. Real roles.
-- Expected values are written by hand: a lease fixed until 2026-12-31 with
-- 3 months notice has its notice deadline on 2026-09-30 and ends on
-- 2026-12-31; once notice is given, the end moves to the effective end and
-- the deadline is gone.
begin;
select plan(8);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;
create function pg_temp.as_json(p_user uuid, p_sql text) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.act_as(p_user);
  execute p_sql into v;
  reset role;
  return v;
exception when others then
  reset role;
  return jsonb_build_object('error', sqlerrm);
end;
$$;
create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00002575' || lpad(n::text, 4, '0'))::uuid;
$$;
create function pg_temp.rq(n int) returns uuid language sql as $$
  select ('c0000000-0000-4000-8000-00000000' || lpad(n::text, 4, '0'))::uuid;
$$;
create function pg_temp.items(p_user uuid, p_member uuid default null) returns jsonb language plpgsql as $$
begin
  return pg_temp.as_json(p_user, format(
    'select public.calendar_items(%L, ''2026-01-01T00:00:00Z'', ''2027-01-31T00:00:00Z'', array[''lease''], %L)',
    current_setting('t.a'), p_member)) -> 'items';
end;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(i), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || i || '@leasecal.test', '', now(), now(), now()
  from generate_series(1, 2) i;
select pg_temp.act_as(pg_temp.u(1));
select set_config('t.a', public.create_workspace('Lease cal', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb)
  || '{"supplyExpenses": true, "scheduledExpenses": true, "premisesLease": true}' where id = current_setting('t.a')::uuid;
insert into public.members (workspace_id, user_id, is_owner, is_admin, status, subscription_pct, joined_at)
values (current_setting('t.a')::uuid, pg_temp.u(2), false, false, 'active', 100, '2026-01-01');
insert into public.suppliers (id, workspace_id, supplier_number, name, status)
values ('00000000-0000-4000-8000-0000257500a1', current_setting('t.a')::uuid, '1', 'SCI Les Halles', 'active');

select set_config('t.l', pg_temp.as_json(pg_temp.u(1), format(
  'select public.save_premises_lease_v1(%L, null, 0, %L::jsonb, %L)', current_setting('t.a'),
  '{"supplier_id":"00000000-0000-4000-8000-0000257500a1","premises":"12 rue des Halles","starts_on":"2025-01-01","fixed_until":"2026-12-31","notice_months":3}',
  pg_temp.rq(1)))::text, true);

select is(jsonb_array_length(pg_temp.items(pg_temp.u(1))), 2, 'the responsible member sees two dates: the notice deadline and the end');
select is((select string_agg(i ->> 'status' || ':' || substr(i ->> 'at', 1, 10), ',' order by i ->> 'at')
             from jsonb_array_elements(pg_temp.items(pg_temp.u(1))) i), 'notice_deadline:2026-09-29,end:2026-12-30',
  'golden: 30 Sep and 31 Dec 2026 at Paris midnight, in UTC');
select is(jsonb_array_length(pg_temp.items(pg_temp.u(2))), 0, 'another member sees none of it');
select is(jsonb_array_length(pg_temp.items(pg_temp.u(1), (select id from public.members where user_id = pg_temp.u(2) and workspace_id = current_setting('t.a')::uuid))), 0,
  'nor does the owner on someone else''s calendar');

update public.workspaces set feature_flags = feature_flags || '{"premisesLease": false}' where id = current_setting('t.a')::uuid;
select is(jsonb_array_length(pg_temp.items(pg_temp.u(1))), 0, 'with the flag off the calendar shows no lease date');
update public.workspaces set feature_flags = feature_flags || '{"premisesLease": true}' where id = current_setting('t.a')::uuid;

select pg_temp.as_json(pg_temp.u(1), format('select public.add_lease_term_v1(%L, %L, 1, ''rent'', '''', 100000, 1, ''2025-01-01'', %L)',
  current_setting('t.a'), current_setting('t.l')::jsonb ->> 'id', pg_temp.rq(2)));
select pg_temp.as_json(pg_temp.u(1), format('select public.give_lease_notice_v1(%L, %L, 2, ''2026-06-30'', ''2026-11-30'', ''moving out'', %L)',
  current_setting('t.a'), current_setting('t.l')::jsonb ->> 'id', pg_temp.rq(3)));
select is(jsonb_array_length(pg_temp.items(pg_temp.u(1))), 1, 'once notice is given the deadline is gone');
select is(pg_temp.items(pg_temp.u(1)) -> 0 ->> 'status', 'end', 'and what is left is the end');
select is(substr(pg_temp.items(pg_temp.u(1)) -> 0 ->> 'at', 1, 10), '2026-11-29', 'on the effective end, 30 Nov, at Paris midnight in UTC');

select * from finish();
rollback;
