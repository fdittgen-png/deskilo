-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2579 C1 — a saved Web-BI view may be a report (definition version 2).
-- A v2 report is stored only while biReportDesigner is effective (a root flag:
-- no finance feature is needed), is bounded and declarative (ids, orders, grid,
-- pages, visuals, bytes, plain text only), and is never overwritten by a
-- version-1 writer. Reading needs only the reader's current analytics rights.
-- Positive cases beside every refusal; the v1 rules of 133 still hold.
begin;
select plan(23);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-00000257900a';
  u_a uuid := '00000000-0000-4000-8000-00000257900b';
  u_m uuid := '00000000-0000-4000-8000-00000257900c';
  ws uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'bireports-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_a, u_m]) u;
  -- Only the designer is switched on: it needs no other feature.
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Reports', 'FR', 'EUR', 'Europe/Paris', u_o, '{"biReportDesigner": true}'::jsonb)
  returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_o, true, true), (ws, u_a, false, true), (ws, u_m, false, false);
  perform set_config('br.ws', ws::text, false);
  perform set_config('br.owner', u_o::text, false);
  perform set_config('br.admin', u_a::text, false);
  perform set_config('br.member', u_m::text, false);
end
$seed$;

create or replace function pg_temp.act_as(p_who text) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('br.' || p_who),
                      'role', 'authenticated')::text, true);
end
$act$;

create or replace function pg_temp.save(p_who text, p_id uuid, p_scope text, p_name text,
                                        p_def jsonb, p_rev int) returns jsonb
language plpgsql as $s$
begin
  perform pg_temp.act_as(p_who);
  return public.bi_view_save(current_setting('br.ws')::uuid, p_id, p_scope, p_name, p_def, p_rev);
exception when others then
  return jsonb_build_object('refused', sqlstate);
end
$s$;

-- One KPI visual; the keys can be overridden to build a bad one.
create or replace function pg_temp.visual(p_id text, p_order int, p_over jsonb default '{}') returns jsonb
language sql as $v$
  select jsonb_build_object(
    'id', p_id, 'type', 'kpi', 'metricId', 'capacity.seat_utilisation', 'metricVersion', 1,
    'dimension', null, 'filters', '[]'::jsonb, 'sort', null, 'format', null,
    'layout', jsonb_build_object('order', p_order, 'span', 6, 'height', 2),
    'interaction', 'filter', 'drill', null) || p_over
$v$;

create or replace function pg_temp.report(p_visuals jsonb, p_over jsonb default '{}') returns jsonb
language sql as $r$
  select jsonb_build_object(
    'v', 2, 'reportFilters', '[]'::jsonb,
    'period', jsonb_build_object('mode', 'relative', 'grain', 'month', 'offset', -1),
    'pages', jsonb_build_array(jsonb_build_object(
      'id', 'p1', 'title', 'Page 1', 'filters', '[]'::jsonb, 'visuals', p_visuals)),
    'printStyle', jsonb_build_object('paper', 'A4', 'orientation', 'portrait', 'showSources', true)) || p_over
$r$;

select pg_temp.seed();

select is(pg_temp.save('admin', null, 'private', 'Report',
            pg_temp.report(jsonb_build_array(pg_temp.visual('v1', 0), pg_temp.visual('v2', 1,
              '{"metricId":"finance.invoiced"}'))), 0) ->> 'revision',
          '1', 'an analytics reader saves a private report (the designer is a root flag)');
select is((select definition -> 'pages' -> 0 -> 'visuals' -> 1 ->> 'metricId' from public.bi_views where name = 'Report'),
          'finance.invoiced', 'and the second visual keeps its metric and place');

select is(pg_temp.save('admin', null, 'private', 'Two pages',
            pg_temp.report(jsonb_build_array(pg_temp.visual('v1', 0)),
              jsonb_build_object('pages', jsonb_build_array(
                jsonb_build_object('id', 'p1', 'title', 'A', 'visuals', jsonb_build_array(pg_temp.visual('v1', 0))),
                jsonb_build_object('id', 'p2', 'title', 'B', 'visuals', jsonb_build_array(pg_temp.visual('v2', 0)))))),
            0) ->> 'revision',
          '1', 'two pages with their own visuals are stored');

select is(pg_temp.save('admin',
            (select id from public.bi_views where name = 'Report'), 'private', 'Report',
            pg_temp.report(jsonb_build_array(pg_temp.visual('v2', 0, '{"metricId":"finance.invoiced"}'),
                                             pg_temp.visual('v1', 1))), 1) ->> 'revision',
          '2', 'reordering keeps the ids and moves the revision on');
select is(pg_temp.save('admin',
            (select id from public.bi_views where name = 'Report'), 'private', 'Report',
            pg_temp.report(jsonb_build_array(pg_temp.visual('v1', 0))), 1) ->> 'refused',
          '40001', 'a second editor on the same revision is refused, not merged');

select is(pg_temp.save('admin',
            (select id from public.bi_views where name = 'Report'), 'private', 'Report',
            '{"v":1,"query":{"grain":"year"}}', 2) ->> 'refused',
          '0A000', 'a version-1 writer cannot overwrite a report');
select is((select definition ->> 'v' from public.bi_views where name = 'Report'),
          '2', 'and the report stands');

select is(pg_temp.save('admin', null, 'private', 'Old question', '{"v":1,"cards":["capacity.seat_utilisation"]}', 0) ->> 'revision',
          '1', 'a version-1 view is still saved as before');
select is(pg_temp.save('admin',
            (select id from public.bi_views where name = 'Old question'), 'private', 'Old question',
            pg_temp.report(jsonb_build_array(pg_temp.visual('v1', 0))), 1) ->> 'revision',
          '2', 'and promoted to a report by an explicit save of the copy');

-- Bounds and shapes.
select is(pg_temp.save('admin', null, 'private', 'Sql',
            pg_temp.report(jsonb_build_array(pg_temp.visual('v1', 0, '{"sql":"select 1"}'))), 0) ->> 'refused',
          '22023', 'a visual holds only the declared keys (no SQL, no formula)');
select is(pg_temp.save('admin', null, 'private', 'Link',
            pg_temp.report(jsonb_build_array(pg_temp.visual('v1', 0, '{"drill":"https://evil.example/x"}'))), 0) ->> 'refused',
          '22023', 'a drill target is a registered name, never a link');
select is(pg_temp.save('admin', null, 'private', 'Unknown type',
            pg_temp.report(jsonb_build_array(pg_temp.visual('v1', 0, '{"type":"pie3d"}'))), 0) ->> 'refused',
          '22023', 'an unknown visual type is refused');
select is(pg_temp.save('admin', null, 'private', 'Same id',
            pg_temp.report(jsonb_build_array(pg_temp.visual('v1', 0), pg_temp.visual('v1', 1))), 0) ->> 'refused',
          '22023', 'duplicate ids are refused');
select is(pg_temp.save('admin', null, 'private', 'Same place',
            pg_temp.report(jsonb_build_array(pg_temp.visual('v1', 0), pg_temp.visual('v2', 0))), 0) ->> 'refused',
          '22023', 'two visuals at one reading position are refused');
select is(pg_temp.save('admin', null, 'private', 'Wide',
            pg_temp.report(jsonb_build_array(pg_temp.visual('v1', 0, '{"layout":{"order":0,"span":13,"height":2}}'))), 0) ->> 'refused',
          '22023', 'a span beyond the 12-column grid is refused');
select is(pg_temp.save('admin', null, 'private', 'Many visuals',
            pg_temp.report((select jsonb_agg(pg_temp.visual('v' || g, g)) from generate_series(1, 25) g)), 0) ->> 'refused',
          '22023', 'more than 24 visuals are refused');
select is(pg_temp.save('admin', null, 'private', 'Text with a metric',
            pg_temp.report(jsonb_build_array(pg_temp.visual('v1', 0, '{"type":"text","text":"hello"}'))), 0) ->> 'refused',
          '22023', 'a text visual carries no metric');
select is(pg_temp.save('admin', null, 'private', 'Plain text',
            pg_temp.report(jsonb_build_array(pg_temp.visual('v1', 0,
              '{"type":"text","metricId":null,"text":"<b>Note</b> & more"}'))), 0) ->> 'revision',
          '1', 'a text visual stores plain content (shown escaped, never as markup)');
select is(pg_temp.save('admin', null, 'private', 'Fixed period',
            pg_temp.report(jsonb_build_array(pg_temp.visual('v1', 0)),
              '{"period":{"mode":"fixed","grain":"quarter","at":"2026-Q5"}}'), 0) ->> 'refused',
          '22023', 'a fixed period must exist in its grain');

-- The flag and the rights.
select is(pg_temp.save('member', null, 'private', 'Nope',
            pg_temp.report(jsonb_build_array(pg_temp.visual('v1', 0))), 0) ->> 'refused',
          '42501', 'a member without viewAnalytics keeps no report');
select is(pg_temp.save('admin', (select id from public.bi_views where name = 'Report'), 'private', 'Taken',
            pg_temp.report(jsonb_build_array(pg_temp.visual('v1', 0))), 2) ->> 'revision',
          '3', 'positive control: the author still edits their report');

update public.workspaces set feature_flags = '{"biReportDesigner": false}'::jsonb
 where id = current_setting('br.ws')::uuid;
select is(pg_temp.save('admin', null, 'private', 'Off',
            pg_temp.report(jsonb_build_array(pg_temp.visual('v1', 0))), 0) ->> 'refused',
          '0A000', 'with the designer off no report is written');

select pg_temp.act_as('admin');
select is((select count(*) from jsonb_array_elements(public.bi_views_list(current_setting('br.ws')::uuid)) v
            where v #>> '{definition,v}' = '2'),
          4::bigint,'but the stored reports are still read with the reader''s own rights');

select * from finish();
rollback;
