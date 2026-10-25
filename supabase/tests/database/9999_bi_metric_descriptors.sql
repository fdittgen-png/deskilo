-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2578 / 9999: every batched figure names its metric's version, unit, date
-- basis and coverage from the registry; a client reading another version
-- gets that request refused alone; a v1 saved view may record the versions
-- its cards were saved with. And a bounded page: a measured fixture (3
-- levels, 12 seats, every weekday booked twice per seat for the next twelve
-- months) answered by one batch of 52 figures inside a declared statement
-- budget, groups adding up to their total and months to their year, with no
-- row written. Seeded by direct insert; the calls run as the real role.
begin;
select plan(20);

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000257a' || lpad(n::text, 4, '0'))::uuid;
$$;
create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;
create function pg_temp.as_json(p_user uuid, p_sql text) returns jsonb
language plpgsql as $$
declare v jsonb;
begin
  perform pg_temp.act_as(p_user);
  execute p_sql into v;
  reset role;
  return v;
exception when others then
  reset role;
  return jsonb_build_object('error', sqlerrm, 'code', sqlstate);
end;
$$;

-- 1 owner of A, 2 plain member of A.
create function pg_temp.seed() returns void language plpgsql as $seed$
declare
  tz text := 'Europe/Paris';
  ws uuid; m_o uuid; lv uuid; o uuid; d uuid; i int; j int; first_day date;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select pg_temp.u(n), '00000000-0000-0000-0000-000000000000', 'authenticated',
         'authenticated', 'd' || n || '@biDescriptors.test', '', now(), now(), now()
    from generate_series(1, 2) n;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Descriptors A', 'FR', 'EUR', tz, pg_temp.u(1)) returning id into ws;
  update public.workspaces
     set feature_flags = coalesce(feature_flags, '{}'::jsonb)
           || '{"capacityKpi": true, "workspaceStatus": true, "invoicing": true}',
         booking_rules = coalesce(booking_rules, '{}'::jsonb)
           || '{"open_weekdays": [1,2,3,4,5], "work_start_minutes": 480, "work_end_minutes": 960}'
   where id = ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, pg_temp.u(1), true, true) returning id into m_o;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, pg_temp.u(2), false, false);
  for i in 1 .. 3 loop
    insert into public.levels (workspace_id, name) values (ws, 'L' || i) returning id into lv;
    insert into public.offices (workspace_id, level_id, name, x, y, w, h)
    values (ws, lv, 'O' || i, 0, 0, 10, 10) returning id into o;
    insert into public.desks (workspace_id, office_id, x, y, w, h)
    values (ws, o, 1, 1, 4, 2) returning id into d;
    for j in 1 .. 4 loop
      insert into public.seats (workspace_id, desk_id, x, y) values (ws, d, j, 1);
    end loop;
    perform set_config('t.l' || i, lv::text, false);
  end loop;

  -- The next twelve whole months on the workspace clock, after the history
  -- began: every weekday, every seat, 09:00-11:00 and 14:00-16:00.
  first_day := (date_trunc('month', now() at time zone tz) + interval '1 month')::date;
  set local session_replication_role = replica;
  insert into public.reservations (workspace_id, company_id, member_id, seat_id, starts_at, ends_at, status)
  select ws, ws, m_o, s.id,
         (dd + make_interval(hours => h)) at time zone tz,
         (dd + make_interval(hours => h + 2)) at time zone tz, 'reserved'
    from public.seats s,
         generate_series(first_day::timestamp, (first_day + interval '12 months' - interval '1 day'), interval '1 day') dd,
         unnest(array[9, 14]) h
   where s.workspace_id = ws and extract(isodow from dd) < 6;
  set local session_replication_role = origin;

  perform set_config('t.a', ws::text, false);
  perform set_config('t.first', first_day::text, false);
end
$seed$;
select pg_temp.seed();

create function pg_temp.batch(p_user uuid, p_requests jsonb) returns jsonb language plpgsql as $$
begin
  return pg_temp.as_json(p_user, format('select public.bi_query_batch_v1(%L, %L::jsonb)',
    current_setting('t.a'), p_requests::text));
end;
$$;
-- Month k (0-based) of the fixture as a capacity request, one level or none.
create function pg_temp.month(p_key text, k int, p_level text, p_months int default 1) returns jsonb
language sql as $$
  select jsonb_build_object('request_key', p_key, 'metric_id', 'capacity.seat_utilisation',
    'from', ((current_setting('t.first')::date + make_interval(months => k))::timestamp at time zone 'Europe/Paris'),
    'to', ((current_setting('t.first')::date + make_interval(months => k + p_months))::timestamp at time zone 'Europe/Paris'))
    || case when p_level is null then '{}'::jsonb
            else jsonb_build_object('level_id', current_setting(p_level)) end;
$$;

-- ------------------------------------------------------------ the registry
select is((select count(*)::int from jsonb_each(public.kpi_registry()) e
            where not (e.value ?& array['version', 'unit', 'aggregation', 'date_basis', 'coverage'])),
  0, 'D1 every registered metric names its version, unit, aggregation, date basis and coverage');
select is(public.kpi_registry() #>> '{finance.collected,date_basis}', 'payment_matched_at',
  'D2 collected is dated by the match, not by the bank');

-- ----------------------------------------------------- what each answer names
select set_config('t.r', pg_temp.batch(pg_temp.u(1), jsonb_build_array(
  pg_temp.month('cap', 0, null),
  jsonb_build_object('request_key', 'col', 'metric_id', 'finance.collected', 'from_month', '2026-08', 'to_month', '2026-09'),
  jsonb_build_object('request_key', 'bad', 'metric_id', 'finance.invoiced', 'from_month', '2026-09', 'to_month', '2026-08'),
  jsonb_build_object('request_key', 'nope', 'metric_id', 'finance.unknown'),
  pg_temp.month('v1', 0, null) || '{"metric_version": 1}',
  pg_temp.month('v2', 0, null) || '{"metric_version": 2}'))::text, true);
select is((current_setting('t.r')::jsonb -> 'results' -> 0) - array['request_key', 'metric_id', 'ok', 'result'],
  (select jsonb_build_object('metric_version', d -> 'version', 'unit', d -> 'unit',
                             'date_basis', d -> 'date_basis', 'coverage', d -> 'coverage')
     from (select public.kpi_registry() -> 'capacity.seat_utilisation' d) x),
  'D3 a capacity answer names the registry''s descriptor of its metric');
select is((current_setting('t.r')::jsonb -> 'results' -> 1) ->> 'date_basis', 'payment_matched_at',
  'D4 a collected answer says it is dated by the match');
select is((select string_agg((x ->> 'request_key') || ':' || (x ->> 'ok'), ',' order by ord)
             from jsonb_array_elements(current_setting('t.r')::jsonb -> 'results') with ordinality t(x, ord)),
  'cap:true,col:true,bad:false,nope:false,v1:true,v2:false',
  'D5 each request answers on its own');
select is((current_setting('t.r')::jsonb -> 'results' -> 2) ->> 'unit', 'currency_minor',
  'D6 a request that failed on its own still names its descriptor');
select ok(not ((current_setting('t.r')::jsonb -> 'results' -> 3) ? 'unit'),
  'D7 an unsupported metric names no descriptor');
select is((current_setting('t.r')::jsonb -> 'results' -> 5) ->> 'code', '0A000',
  'D8 a client reading another version of the metric is refused for that request');
select is((current_setting('t.r')::jsonb -> 'results' -> 5) ->> 'metric_version', '1',
  'D9 and is told the version the server answers');
select ok((pg_temp.batch(pg_temp.u(2), jsonb_build_array(pg_temp.month('m', 0, null)))::text) like '%not allowed%',
  'D10 a plain member is still refused the whole batch');

-- ------------------------------------------------------------ saved views
select ok(public.bi_definition_valid('{"v": 1, "query": {"by": "level"}, "cards": ["capacity.seat_utilisation"]}'),
  'D11 a v1 view saved before the versions stays valid');
select ok(public.bi_definition_valid('{"v": 1, "cards": ["capacity.seat_utilisation"], "metrics": {"capacity.seat_utilisation": 1}}'),
  'D12 a v1 view may record the versions of its cards');
select is((select string_agg(bad, ',' order by bad) from unnest(array[
    '{"v": 1, "metrics": "x"}', '{"v": 1, "metrics": {"capacity.seat_utilisation": 0}}',
    '{"v": 1, "metrics": {"capacity.seat_utilisation": 100}}', '{"v": 1, "metrics": {"capacity.seat_utilisation": "1"}}',
    '{"v": 1, "metrics": {"Drop table": 1}}', '{"v": 1, "metrics": {"capacity.seat_utilisation": 1.5}}']) bad
   where public.bi_definition_valid(bad::jsonb)), null,
  'D13 malformed versions are refused, every one of them');
select is(pg_temp.as_json(pg_temp.u(1), format(
    'select public.bi_view_save(%L, null, ''private'', ''Versions'', %L::jsonb, 0) -> ''definition'' -> ''metrics''',
    current_setting('t.a'), '{"v": 1, "cards": ["capacity.seat_utilisation"], "metrics": {"capacity.seat_utilisation": 1}}')),
  '{"capacity.seat_utilisation": 1}'::jsonb, 'D14 a member saves a view with its versions and reads them back');
select ok((pg_temp.as_json(pg_temp.u(1), format(
    'select public.bi_view_save(%L, null, ''private'', ''Bad versions'', %L::jsonb, 0)',
    current_setting('t.a'), '{"v": 1, "cards": ["capacity.seat_utilisation"], "metrics": {"capacity.seat_utilisation": 0}}')) ->> 'code') = '22023',
  'D15 and cannot store a malformed version');

-- ------------------------------------------- a bounded page, inside its budget
-- Twelve months x (the total and three levels) = 48 figures, plus the whole
-- year as one figure per row: 52, under the default limit of 60.
select set_config('t.page', (select jsonb_agg(r order by ord) from (
    select pg_temp.month(k || ':' || coalesce(l, 'total'), k, l) r, k * 10 + coalesce(right(l, 1)::int, 0) ord
      from generate_series(0, 11) k, unnest(array[null, 't.l1', 't.l2', 't.l3']) l
    union all
    select pg_temp.month('year:' || coalesce(l, 'total'), 0, l, 12), 1000 + coalesce(right(l, 1)::int, 0)
      from unnest(array[null, 't.l1', 't.l2', 't.l3']) l) x)::text, true);
select set_config('t.n', (select count(*)::text from public.reservations where workspace_id = current_setting('t.a')::uuid), true);
set local statement_timeout = '5s';
select set_config('t.p', pg_temp.batch(pg_temp.u(1), current_setting('t.page')::jsonb)::text, true);
reset statement_timeout;
select is(current_setting('t.p')::jsonb ->> 'error', null, 'P1 the 52-figure page is answered inside the 5 s statement budget');
select is((select count(*)::int from jsonb_array_elements(current_setting('t.p')::jsonb -> 'results') x
            where (x ->> 'ok')::boolean), 52, 'P2 every figure of the page answers');
create function pg_temp.reserved(p_key text) returns numeric language sql as $$
  select (x #>> '{result,reserved_seat_hours}')::numeric
    from jsonb_array_elements(current_setting('t.p')::jsonb -> 'results') x
   where x ->> 'request_key' = p_key;
$$;
select is((select count(*)::int from generate_series(0, 11) k
            where pg_temp.reserved(k || ':total')
               <> pg_temp.reserved(k || ':t.l1') + pg_temp.reserved(k || ':t.l2') + pg_temp.reserved(k || ':t.l3')),
  0, 'P3 in every month the levels add up to the total of the same read');
select is((select sum(pg_temp.reserved(k || ':total')) from generate_series(0, 11) k),
  pg_temp.reserved('year:total'), 'P4 the twelve months add up to the year asked as one figure');
select ok((select count(*) from public.reservations where workspace_id = current_setting('t.a')::uuid)
             = current_setting('t.n')::bigint
         and pg_temp.reserved('year:total') = current_setting('t.n')::numeric * 2
         and current_setting('t.n')::int > 6000,
  'P5 the fixture is what it says (over 6000 two-hour bookings, all counted) and the read wrote nothing');

select * from finish();
rollback;
