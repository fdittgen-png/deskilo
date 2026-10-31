-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2580 — a report visual may carry how it is presented, and nothing more:
-- a visible title and description (plain text on one line, bounded), the
-- legend, value labels and source note (booleans), a permitted palette and a
-- line's axis. Every other key, a palette or axis outside the list, an empty,
-- long or multi-line text and a non-boolean switch are refused, by the shape
-- check and by the writer. A styled report is saved and read back with its
-- style; a report without one is unchanged. A person's overview layout (a
-- private report whose page is `overview`, #2583 C2) is theirs alone: another
-- analytics reader neither receives nor overwrites it, and keeps their own.
begin;
select plan(19);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000025800c1';
  u_a uuid := '00000000-0000-4000-8000-0000025800c2';
  ws uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'bistyle-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_a]) u;
  -- The designer and the capacity figure are roots; the admin row of the
  -- matrix reads the analytics.
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by,
                                 feature_flags, role_permissions)
  values ('Styles', 'FR', 'EUR', 'Europe/Paris', u_o,
          '{"biReportDesigner": true, "capacityKpi": true, "customRoles": true, "moneyTab": true, "invoicing": true, "workspaceStatus": true, "configurableSettings": true}'::jsonb,
          '{"admin": ["viewAnalytics"]}'::jsonb)
  returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_o, true, true), (ws, u_a, false, true);
  perform set_config('bs.ws', ws::text, false);
  perform set_config('bs.owner', u_o::text, false);
  perform set_config('bs.analyst', u_a::text, false);
end
$seed$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create or replace function pg_temp.visual(p_style jsonb) returns jsonb language sql as $v$
  select jsonb_build_object(
    'id', 'v1', 'type', 'line', 'metricId', 'capacity.seat_utilisation', 'metricVersion', 1,
    'filters', '[]'::jsonb, 'interaction', 'filter',
    'layout', jsonb_build_object('order', 0, 'span', 6, 'height', 3))
    || case when p_style is null then '{}'::jsonb else jsonb_build_object('style', p_style) end
$v$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create or replace function pg_temp.report(p_style jsonb) returns jsonb language sql as $r$
  select jsonb_build_object(
    'v', 2, 'reportFilters', '[]'::jsonb,
    'period', jsonb_build_object('mode', 'relative', 'grain', 'month', 'offset', 0),
    'pages', jsonb_build_array(jsonb_build_object(
      'id', 'p1', 'title', 'Page 1', 'filters', '[]'::jsonb,
      'visuals', jsonb_build_array(pg_temp.visual(p_style)))))
$r$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create or replace function pg_temp.save(p_name text, p_def jsonb, p_who text default 'owner',
                                        p_id uuid default null, p_rev int default 0) returns jsonb
language plpgsql as $s$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('bs.' || p_who), 'role', 'authenticated')::text, true);
  return public.bi_view_save(current_setting('bs.ws')::uuid, p_id, 'private', p_name, p_def, p_rev, null);
exception when others then
  return jsonb_build_object('refused', sqlstate);
end
$s$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- The overview layouts p_who receives: their page-`overview` reports' names.
create or replace function pg_temp.layouts(p_who text) returns text language plpgsql as $l$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('bs.' || p_who), 'role', 'authenticated')::text, true);
  return (select string_agg(v ->> 'name', ',' order by v ->> 'name')
            from jsonb_array_elements(public.bi_views_list(current_setting('bs.ws')::uuid)) v
           where v #>> '{definition,pages,0,id}' = 'overview');
end
$l$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create or replace function pg_temp.overview(p_name text) returns jsonb language sql as $o$
  select jsonb_set(pg_temp.report(null), '{pages,0}',
                   (pg_temp.report(null) #> '{pages,0}') || jsonb_build_object('id', 'overview', 'title', p_name))
$o$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select pg_temp.seed();

-- The shape.
select ok(public.bi_report_valid(pg_temp.report(null)), 'a visual without a style is valid as before');
select ok(public.bi_report_valid(pg_temp.report(
  '{"title": "Seats", "description": "Booked seat time over offered seat time", "legend": false,
    "labels": false, "palette": "contrast", "axis": "fit", "note": false}'::jsonb)),
  'every style key at a permitted value is valid');
select ok(public.bi_report_valid(pg_temp.report('{}'::jsonb)), 'an empty style is valid');
select ok(not public.bi_report_valid(pg_temp.report('{"colour": "#ff0000"}'::jsonb)),
  'a key outside the style is refused');
select ok(not public.bi_report_valid(pg_temp.report('{"palette": "neon"}'::jsonb)),
  'a palette outside the permitted ones is refused');
select ok(not public.bi_report_valid(pg_temp.report('{"axis": "log"}'::jsonb)),
  'an axis other than zero or fit is refused');
select ok(not public.bi_report_valid(pg_temp.report('{"title": ""}'::jsonb)),
  'an empty title is refused');
select ok(not public.bi_report_valid(pg_temp.report(jsonb_build_object('title', repeat('x', 81)))),
  'a title over 80 characters is refused');
select ok(not public.bi_report_valid(pg_temp.report(jsonb_build_object('title', E'two\nlines'))),
  'a title on two lines is refused');
select ok(not public.bi_report_valid(pg_temp.report(jsonb_build_object('description', repeat('x', 201)))),
  'a description over 200 characters is refused');
select ok(not public.bi_report_valid(pg_temp.report('{"legend": "no"}'::jsonb)),
  'a switch that is not a boolean is refused');
select ok(not public.bi_report_valid(pg_temp.report('"bold"'::jsonb)),
  'a style that is not an object is refused');

-- The writer.
select is(pg_temp.save('Styled', pg_temp.report('{"title": "Seats", "palette": "mono"}'::jsonb))
            #>> '{definition,pages,0,visuals,0,style}',
          '{"title": "Seats", "palette": "mono"}',
          'a styled report is saved and read back with its style');
select is((select definition #>> '{pages,0,visuals,0,style,title}' from public.bi_views where name = 'Styled'),
          'Seats', 'the stored definition holds the style as written');
select is(pg_temp.save('Bad style', pg_temp.report('{"palette": "neon"}'::jsonb)) ->> 'refused',
          '22023', 'the writer refuses a report with an invalid style');
-- Overview layouts are each person's own.
select is(pg_temp.save('Owner overview', pg_temp.overview('Owner overview')) ->> 'revision', '1',
          'the owner saves an overview layout');
select is(pg_temp.layouts('analyst'), null,
          'another analytics reader does not receive it');
select is(pg_temp.save('Analyst overview', pg_temp.overview('Analyst overview'), 'analyst') ->> 'revision', '1',
          'and keeps a layout of their own beside it');
select ok(not has_function_privilege('anon', 'public.bi_report_valid(jsonb)', 'execute'),
          'the shape check stays closed to anonymous callers');

select * from finish();
rollback;
