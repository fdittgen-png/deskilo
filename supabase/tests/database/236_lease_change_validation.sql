-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2569 / 0506: the lease_change validation domain. A rent change above the
-- policy's minimum and a notice are held for a second person; the
-- confirmation applies exactly what was asked, a rejection nothing; below the
-- minimum, without a policy, and for other charges nothing is held. Real
-- roles; every refusal is followed by a readback.
begin;
select plan(22);
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
  select ('00000000-0000-4000-8000-00002570' || lpad(n::text, 4, '0'))::uuid;
$$;
create function pg_temp.rq(n int) returns uuid language sql as $$
  select ('c0000000-0000-4000-8000-00000000' || lpad(n::text, 4, '0'))::uuid;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(i), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || i || '@leasehold.test', '', now(), now(), now()
  from generate_series(1, 3) i;
-- 1 owner, 2 plain member, 3 admin who validates.
select pg_temp.act_as(pg_temp.u(1));
select set_config('t.a', public.create_workspace('Hold A', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb)
  || '{"supplyExpenses": true, "scheduledExpenses": true, "premisesLease": true}' where id = current_setting('t.a')::uuid;
insert into public.members (workspace_id, user_id, is_owner, is_admin, status, subscription_pct, joined_at) values
 (current_setting('t.a')::uuid, pg_temp.u(2), false, false, 'active', 100, '2026-01-01'),
 (current_setting('t.a')::uuid, pg_temp.u(3), false, true, 'active', 100, '2026-01-01');
insert into public.suppliers (id, workspace_id, supplier_number, name, status)
values ('00000000-0000-4000-8000-0000257000a1', current_setting('t.a')::uuid, '1', 'SCI Les Halles', 'active');

create function pg_temp.rev() returns int language sql as $$
  select revision from public.premises_leases where id = current_setting('t.id')::uuid;
$$;
create function pg_temp.term(p_user uuid, p_kind text, p_amount int, p_from date, p_req int) returns jsonb language plpgsql as $$
begin
  return pg_temp.as_json(p_user, format('select public.add_lease_term_v1(%L, %L, %s, %L, '''', %s, 1, %L, %L)',
    current_setting('t.a'), current_setting('t.id'), pg_temp.rev(), p_kind, p_amount, p_from, pg_temp.rq(p_req)));
end;
$$;
create function pg_temp.notice(p_user uuid, p_req int) returns jsonb language plpgsql as $$
begin
  return pg_temp.as_json(p_user, format('select public.give_lease_notice_v1(%L, %L, %s, ''2026-10-01'', ''2027-03-31'', ''Moving out'', %L)',
    current_setting('t.a'), current_setting('t.id'), pg_temp.rev(), pg_temp.rq(p_req)));
end;
$$;
create function pg_temp.decide(p_user uuid, p_event text, p_accept boolean) returns jsonb language plpgsql as $$
begin
  perform pg_temp.act_as(p_user);
  perform public.respond_to_event(p_event::uuid, p_accept);
  reset role;
  return '{}'::jsonb;
exception when others then
  reset role;
  return jsonb_build_object('error', sqlerrm);
end;
$$;
create function pg_temp.rents() returns text language sql as $$
  select string_agg(amount_cents::text, ',' order by effective_from) from public.lease_terms
   where lease_id = current_setting('t.id')::uuid and kind = 'rent';
$$;

select set_config('t.id', (pg_temp.as_json(pg_temp.u(1), format(
  'select public.save_premises_lease_v1(%L, null, 0, %L::jsonb, %L)', current_setting('t.a'),
  '{"supplier_id":"00000000-0000-4000-8000-0000257000a1","premises":"12 rue des Halles","starts_on":"2025-01-01","notice_months":3}',
  pg_temp.rq(1))) ->> 'id'), true);
select is(pg_temp.term(pg_temp.u(1), 'rent', 100000, '2025-01-01', 2) ->> 'status', 'active', 'H1 the first rent is recorded');

-- no policy: nothing is held
select is(pg_temp.term(pg_temp.u(1), 'rent', 110000, '2025-09-01', 3) ->> 'pending', null, 'H2 without a policy a rent change applies at once');
select is(pg_temp.rents(), '100000,110000', 'H2b readback: both rents are there');

reset role;
insert into public.validation_policies (workspace_id, event_type, required_count, admins_may_validate, min_amount_cents)
values (current_setting('t.a')::uuid, 'lease_change', 1, true, 5000);

select is(pg_temp.term(pg_temp.u(2), 'rent', 130000, '2026-01-01', 4) ->> 'error', 'you may not manage the lease', 'H3 a plain member changes nothing');
select is(pg_temp.term(pg_temp.u(1), 'rent', 112000, '2026-01-01', 5) ->> 'pending', null, 'H4 a change of 20.00 is below the 50.00 minimum: applied');
select set_config('t.r1', pg_temp.term(pg_temp.u(1), 'rent', 122000, '2026-03-01', 6)::text, true);
select is(current_setting('t.r1')::jsonb ->> 'pending', 'true', 'H5 a change of 100.00 is held');
select is(pg_temp.rents(), '100000,110000,112000', 'H5b readback: the held rent is not recorded');
select is((select count(*)::int from public.events where type = 'lease_change' and status = 'pending'), 1, 'H5c one pending lease_change event');
select is((select payload ->> 'new_amount_cents' from public.events where id = (current_setting('t.r1')::jsonb ->> 'event_id')::uuid), '122000', 'H5d carrying exactly what was asked');
select is(pg_temp.term(pg_temp.u(1), 'rent', 122000, '2026-03-01', 6) ->> 'event_id', current_setting('t.r1')::jsonb ->> 'event_id', 'H6 the same request replays the same pending answer');
select is((select count(*)::int from public.events where type = 'lease_change'), 1, 'H6b and files no second event');
select is(pg_temp.term(pg_temp.u(1), 'service_charge_advance', 90000, '2025-01-01', 7) ->> 'pending', null, 'H7 an advance is never held');

select is(pg_temp.decide(pg_temp.u(3), (current_setting('t.r1')::jsonb ->> 'event_id'), true) ->> 'error', null, 'H8 the admin confirms');
select is(pg_temp.rents(), '100000,110000,112000,122000', 'H8b the confirmed rent is now recorded, as asked');
select is((select created_by from public.lease_terms where amount_cents = 122000 and kind = 'rent'),
  (select id from public.members where user_id = pg_temp.u(1) and workspace_id = current_setting('t.a')::uuid),
  'H8c as the member who asked, not the one who confirmed');

select set_config('t.r2', pg_temp.term(pg_temp.u(1), 'rent', 140000, '2026-06-01', 8)::text, true);
select is(pg_temp.decide(pg_temp.u(3), (current_setting('t.r2')::jsonb ->> 'event_id'), false) ->> 'error', null, 'H9 a rejection');
select is(pg_temp.rents(), '100000,110000,112000,122000', 'H9b applies nothing');

-- notice
select set_config('t.n1', pg_temp.notice(pg_temp.u(1), 9)::text, true);
select is(current_setting('t.n1')::jsonb ->> 'pending', 'true', 'H10 notice is held while the space has a policy');
select is((select status from public.premises_leases where id = current_setting('t.id')::uuid), 'active', 'H10b readback: the lease is still active');
select is(pg_temp.decide(pg_temp.u(3), (current_setting('t.n1')::jsonb ->> 'event_id'), true) ->> 'error', null, 'H11 confirmed');
select is((select status || ':' || effective_end::text from public.premises_leases where id = current_setting('t.id')::uuid),
  'notice_given:2027-03-31', 'H11b the lease ends on the day asked');

select is((select count(*)::int from public.events where type = 'lease_change'), 3, 'H12 three held changes in all: nothing else was filed');

select * from finish();
rollback;
