-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2579 C2 — saved reports are written safely and read within the reader's
-- rights. A retried request makes one revision and a reused request id with
-- another write (or by another person) is refused; two editors on one
-- revision: one saves, the other is refused and nothing is merged; a team
-- view is written by an analytics reader who manages the space OR designs
-- its documents; an operational reader of a mixed team report receives no
-- finance figure id, is told how many were withheld, cannot save over it and
-- saves only figures they may read; a question left with none of its figures
-- is withheld, never widened; another metric version is 0A000, an unknown
-- metric or dimension and a widening filter 22023; the space's report limits
-- refuse a larger report; another workspace's caller and target are refused.
-- Positive cases beside every refusal.
begin;
select plan(40);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000025790c1';
  u_d uuid := '00000000-0000-4000-8000-0000025790c2';
  u_m uuid := '00000000-0000-4000-8000-0000025790c3';
  u_v uuid := '00000000-0000-4000-8000-0000025790c4';
  u_n uuid := '00000000-0000-4000-8000-0000025790c5';
  u_x uuid := '00000000-0000-4000-8000-0000025790c6';
  ws uuid; ws2 uuid; m_m uuid; m_v uuid; r_ops uuid; r_read uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'bidefs-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_d, u_m, u_v, u_n, u_x]) u;
  -- The designer is a root flag; the figures' own features and their parents
  -- are on too, and custom roles (which the two analysts' roles need). The admin row of the matrix is a finance designer without
  -- workspaceSettings.
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by,
                                 feature_flags, role_permissions)
  values ('Definitions', 'FR', 'EUR', 'Europe/Paris', u_o,
          '{"biReportDesigner": true, "capacityKpi": true, "customRoles": true, "moneyTab": true, "invoicing": true, "workspaceStatus": true}'::jsonb,
          '{"admin": ["viewAnalytics", "viewFinances", "designDocuments"]}'::jsonb)
  returning id into ws;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Elsewhere', 'FR', 'EUR', 'Europe/Paris', u_x, '{"biReportDesigner": true}'::jsonb)
  returning id into ws2;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_o, true, true), (ws, u_d, false, true), (ws, u_m, false, false),
         (ws, u_v, false, false), (ws, u_n, false, false), (ws2, u_x, true, true);
  select id into m_m from public.members where workspace_id = ws and user_id = u_m;
  select id into m_v from public.members where workspace_id = ws and user_id = u_v;
  -- An operational designer (analytics + designDocuments, no finance) and a
  -- plain analytics reader.
  insert into public.workspace_roles (workspace_id, key, permissions)
  values (ws, 'ops_designer', array['viewAnalytics', 'designDocuments']) returning id into r_ops;
  insert into public.workspace_roles (workspace_id, key, permissions)
  values (ws, 'reader', array['viewAnalytics']) returning id into r_read;
  insert into public.workspace_role_members (workspace_id, role_id, member_id)
  values (ws, r_ops, m_m), (ws, r_read, m_v);
  perform set_config('bd.ws', ws::text, false);
  perform set_config('bd.ws2', ws2::text, false);
  perform set_config('bd.owner', u_o::text, false);
  perform set_config('bd.designer', u_d::text, false);
  perform set_config('bd.ops', u_m::text, false);
  perform set_config('bd.reader', u_v::text, false);
  perform set_config('bd.member', u_n::text, false);
  perform set_config('bd.stranger', u_x::text, false);
end
$seed$;

create or replace function pg_temp.act_as(p_who text) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('bd.' || p_who),
                      'role', 'authenticated')::text, true);
end
$act$;

-- Saves as p_who (into p_ws, default the space) and returns the view json, or
-- the SQLSTATE refused.
create or replace function pg_temp.save(p_who text, p_id uuid, p_scope text, p_name text,
                                        p_def jsonb, p_rev int, p_req uuid default null,
                                        p_ws text default 'ws') returns jsonb
language plpgsql as $s$
begin
  perform pg_temp.act_as(p_who);
  return public.bi_view_save(current_setting('bd.' || p_ws)::uuid, p_id, p_scope, p_name, p_def,
                             p_rev, p_req);
exception when others then
  return jsonb_build_object('refused', sqlstate);
end
$s$;

create or replace function pg_temp.call(p_who text, p_sql text) returns text
language plpgsql as $c$
begin
  perform pg_temp.act_as(p_who);
  execute p_sql;
  return 'ok';
exception when others then
  return sqlstate;
end
$c$;

-- The view named p_name as p_who receives it.
create or replace function pg_temp.seen(p_who text, p_name text) returns jsonb
language plpgsql as $r$
begin
  perform pg_temp.act_as(p_who);
  return (select v from jsonb_array_elements(public.bi_views_list(current_setting('bd.ws')::uuid)) v
           where v ->> 'name' = p_name);
end
$r$;

create or replace function pg_temp.id_of(p_name text) returns uuid language sql as $i$
  select id from public.bi_views where name = p_name
$i$;

create or replace function pg_temp.visual(p_id text, p_order int, p_metric text default 'capacity.seat_utilisation',
                                          p_over jsonb default '{}') returns jsonb
language sql as $v$
  select jsonb_build_object(
    'id', p_id, 'type', 'kpi', 'metricId', p_metric, 'metricVersion', 1,
    'dimension', null, 'filters', '[]'::jsonb, 'sort', null, 'format', null,
    'layout', jsonb_build_object('order', p_order, 'span', 6, 'height', 2),
    'interaction', 'filter', 'drill', null) || p_over
$v$;

create or replace function pg_temp.report(p_pages jsonb, p_over jsonb default '{}') returns jsonb
language sql as $r$
  select jsonb_build_object(
    'v', 2, 'reportFilters', '[]'::jsonb,
    'period', jsonb_build_object('mode', 'relative', 'grain', 'month', 'offset', -1),
    'pages', p_pages,
    'printStyle', jsonb_build_object('paper', 'A4', 'orientation', 'portrait', 'showSources', true)) || p_over
$r$;

create or replace function pg_temp.page(p_id text, p_visuals jsonb, p_filters jsonb default '[]') returns jsonb
language sql as $p$
  select jsonb_build_object('id', p_id, 'title', 'Page ' || p_id, 'filters', p_filters, 'visuals', p_visuals)
$p$;

-- Capacity on p1; finance then capacity on p2.
create or replace function pg_temp.mixed() returns jsonb language sql as $m$
  select pg_temp.report(jsonb_build_array(
    pg_temp.page('p1', jsonb_build_array(pg_temp.visual('v1', 0))),
    pg_temp.page('p2', jsonb_build_array(pg_temp.visual('v2', 0, 'finance.invoiced'),
                                         pg_temp.visual('v3', 1)))))
$m$;

create or replace function pg_temp.capacity() returns jsonb language sql as $c$
  select pg_temp.report(jsonb_build_array(pg_temp.page('p1', jsonb_build_array(pg_temp.visual('v1', 0)))))
$c$;

select pg_temp.seed();

-- Retry: one request, one revision.
select is(pg_temp.save('owner', null, 'workspace', 'Mixed', pg_temp.mixed(), 0,
            '00000000-0000-4000-8000-0000025790a1') ->> 'revision',
          '1', 'the owner saves a mixed team report under a request id');
select is(pg_temp.save('owner', null, 'workspace', 'Mixed', pg_temp.mixed(), 0,
            '00000000-0000-4000-8000-0000025790a1') ->> 'id',
          pg_temp.id_of('Mixed')::text, 'the same request again answers the same view');
select is((select count(*) from public.bi_views where name = 'Mixed'), 1::bigint,
          'and no second view exists');
select is(pg_temp.save('owner', null, 'workspace', 'Mixed 2', pg_temp.mixed(), 0,
            '00000000-0000-4000-8000-0000025790a1') ->> 'refused',
          '22023', 'the same request id with another write is refused');
select is(pg_temp.save('designer', null, 'workspace', 'Mixed', pg_temp.mixed(), 0,
            '00000000-0000-4000-8000-0000025790a1') ->> 'refused',
          '22023', 'nor may another person replay it');

-- Two editors on revision 1.
select is(pg_temp.save('designer', pg_temp.id_of('Mixed'), 'workspace', 'Mixed',
            pg_temp.report(jsonb_build_array(
              pg_temp.page('p2', jsonb_build_array(pg_temp.visual('v3', 0), pg_temp.visual('v2', 1, 'finance.invoiced'))),
              pg_temp.page('p1', jsonb_build_array(pg_temp.visual('v1', 0))))), 1,
            '00000000-0000-4000-8000-0000025790a2') ->> 'revision',
          '2', 'a finance designer without workspaceSettings changes the team report (pages and order moved)');
select is(pg_temp.save('designer', pg_temp.id_of('Mixed'), 'workspace', 'Mixed',
            pg_temp.report(jsonb_build_array(
              pg_temp.page('p2', jsonb_build_array(pg_temp.visual('v3', 0), pg_temp.visual('v2', 1, 'finance.invoiced'))),
              pg_temp.page('p1', jsonb_build_array(pg_temp.visual('v1', 0))))), 1,
            '00000000-0000-4000-8000-0000025790a2') ->> 'revision',
          '2', 'the update retried is still revision 2, not a stale conflict with itself');
select is(pg_temp.save('owner', pg_temp.id_of('Mixed'), 'workspace', 'Mixed', pg_temp.mixed(), 1) ->> 'refused',
          '40001', 'the second editor on revision 1 is refused');
select is((select definition -> 'pages' -> 0 ->> 'id' || ':' || (definition -> 'pages' -> 0 -> 'visuals' -> 1 ->> 'id')
             from public.bi_views where name = 'Mixed'),
          'p2:v2', 'and the first editor''s report stands with its ids');

-- Scope: what an operational reader receives.
select is(pg_temp.seen('ops', 'Mixed') ->> 'withheld', '1', 'the operational reader is told one figure is withheld');
select ok(position('finance' in (pg_temp.seen('ops', 'Mixed') -> 'definition')::text) = 0,
          'and receives no finance id in the definition');
select is((select string_agg(v ->> 'id', ',' order by v ->> 'id')
             from jsonb_array_elements(pg_temp.seen('ops', 'Mixed') -> 'definition' -> 'pages') pg,
                  jsonb_array_elements(pg -> 'visuals') v),
          'v1,v3', 'the capacity visuals of both pages remain, with their ids');
select is(pg_temp.seen('owner', 'Mixed') ->> 'withheld', '0', 'positive control: the owner receives every figure');
select is((select count(*) from jsonb_array_elements(pg_temp.seen('owner', 'Mixed') -> 'definition' -> 'pages') pg,
                                 jsonb_array_elements(pg -> 'visuals') v), 3::bigint,
          'all three visuals');
select is(pg_temp.save('ops', pg_temp.id_of('Mixed'), 'workspace', 'Mixed',
            pg_temp.seen('ops', 'Mixed') -> 'definition', 2) ->> 'refused',
          '42501', 'the operational designer cannot save over figures they were not shown');
select is(pg_temp.save('ops', null, 'private', 'Finance too', pg_temp.mixed(), 0) ->> 'refused',
          '42501', 'nor save a figure they may not read');
select is(pg_temp.save('ops', null, 'private', 'My copy', pg_temp.seen('ops', 'Mixed') -> 'definition', 0) ->> 'withheld',
          '0', 'a copy of what they received is theirs, whole');
select is(pg_temp.save('ops', null, 'workspace', 'Capacity', pg_temp.capacity(), 0) ->> 'revision',
          '1', 'an operational designer (designDocuments, no finance, no settings) shares a capacity report');

-- v1 questions are withheld the same way; none left is not "every card".
select is(pg_temp.save('owner', null, 'workspace', 'Q mixed',
            '{"v":1,"cards":["finance.invoiced","capacity.seat_utilisation"],"metrics":{"finance.invoiced":1}}', 0) ->> 'revision',
          '1', 'the owner shares a mixed question');
select is(pg_temp.seen('ops', 'Q mixed') -> 'definition', '{"v":1,"cards":["capacity.seat_utilisation"],"metrics":{}}'::jsonb,
          'the operational reader receives its capacity card only');
select is(pg_temp.save('owner', null, 'workspace', 'Q finance', '{"v":1,"cards":["finance.invoiced"]}', 0) ->> 'revision',
          '1', 'the owner shares a finance-only question');
select is((pg_temp.seen('ops', 'Q finance') -> 'definition' -> 'cards')::text || ' withheld=' || (pg_temp.seen('ops', 'Q finance') ->> 'withheld'),
          '[] withheld=1', 'a question left with none of its cards says so (the client refuses it, never shows all)');

-- Sharing rules.
select is(pg_temp.save('reader', null, 'workspace', 'Team try', pg_temp.capacity(), 0) ->> 'refused',
          '42501', 'an analytics reader without settings or designDocuments shares nothing');
select is(pg_temp.save('reader', null, 'private', 'Reader own', pg_temp.capacity(), 0) ->> 'revision',
          '1', 'but keeps private reports');
select is(pg_temp.call('reader', format('select public.bi_view_set_default(%L, ''workspace'', %L)',
            current_setting('bd.ws'), pg_temp.id_of('Capacity'))),
          '42501', 'nor sets the team default');
select is(pg_temp.call('ops', format('select public.bi_view_set_default(%L, ''workspace'', %L)',
            current_setting('bd.ws'), pg_temp.id_of('Capacity'))),
          'ok', 'which a designDocuments holder does');
select is(pg_temp.call('reader', format('select public.bi_view_delete(%L, %L, 1)',
            current_setting('bd.ws'), pg_temp.id_of('Capacity'))),
          '42501', 'nor deletes a team view');
select is(pg_temp.save('member', null, 'private', 'Nope', pg_temp.capacity(), 0) ->> 'refused',
          '42501', 'a member without viewAnalytics keeps no report');

-- Versions, names, filters.
select is(pg_temp.save('owner', null, 'private', 'Old version',
            pg_temp.report(jsonb_build_array(pg_temp.page('p1', jsonb_build_array(
              pg_temp.visual('v1', 0, 'capacity.seat_utilisation', '{"metricVersion": 2}'))))), 0) ->> 'refused',
          '0A000', 'a figure at another version is unsupported, never substituted');
select is(pg_temp.save('owner', null, 'private', 'Old question',
            '{"v":1,"cards":["capacity.seat_utilisation"],"metrics":{"capacity.seat_utilisation":2}}', 0) ->> 'refused',
          '0A000', 'the same for a question');
select is(pg_temp.save('owner', null, 'private', 'Unknown',
            pg_temp.report(jsonb_build_array(pg_temp.page('p1', jsonb_build_array(
              pg_temp.visual('v1', 0, 'capacity.made_up'))))), 0) ->> 'refused',
          '22023', 'an unknown metric is refused');
select is(pg_temp.save('owner', null, 'private', 'Bad dimension',
            pg_temp.capacity() || '{"reportFilters":[{"dimension":"member_email","operator":"eq","value":"a"}]}', 0) ->> 'refused',
          '22023', 'an unregistered filter dimension is refused');
select is(pg_temp.save('owner', null, 'private', 'Widening',
            pg_temp.report(jsonb_build_array(pg_temp.page('p1', jsonb_build_array(pg_temp.visual('v1', 0)),
              '[{"dimension":"level","operator":"eq","value":"l2"}]')),
              '{"reportFilters":[{"dimension":"level","operator":"eq","value":"l1"}]}'), 0) ->> 'refused',
          '22023', 'a page filter that would widen the report''s is refused');
select is(pg_temp.save('owner', null, 'private', 'Narrowing',
            pg_temp.report(jsonb_build_array(pg_temp.page('p1', jsonb_build_array(
                pg_temp.visual('v1', 0, 'capacity.seat_utilisation',
                  '{"filters":[{"dimension":"level","operator":"neq","value":"l2"}]}')),
              '[{"dimension":"level","operator":"eq","value":"l1"}]')),
              '{"reportFilters":[{"dimension":"level","operator":"in","value":"l1,l2"}]}'), 0) ->> 'revision',
          '1', 'filters that only narrow are stored');

-- The space's limits.
select pg_temp.act_as('owner');
select is(public.set_setting(current_setting('bd.ws')::uuid, 'bi.report_max_pages', '1'::jsonb, 'one page') ->> 'status',
          'saved', 'the owner lowers the space''s page limit to 1');
select is(pg_temp.save('owner', null, 'private', 'Two pages', pg_temp.mixed(), 0) ->> 'refused',
          '22023', 'a two-page report is then refused');
select is(pg_temp.save('owner', null, 'private', 'One page', pg_temp.capacity(), 0) ->> 'revision',
          '1', 'a one-page report is still saved');

-- Other workspaces.
select is(pg_temp.save('stranger', null, 'private', 'Intruder', pg_temp.capacity(), 0) ->> 'refused',
          '42501', 'a member of another space saves nothing here');
select is(pg_temp.save('stranger', pg_temp.id_of('Mixed'), 'workspace', 'Mixed', pg_temp.capacity(), 2,
            null, 'ws2') ->> 'refused',
          '42501', 'nor reaches this space''s view through their own');
select ok(not has_function_privilege('anon', 'public.bi_view_save(uuid, uuid, text, text, jsonb, int, uuid)', 'execute')
          and has_function_privilege('authenticated', 'public.bi_view_save(uuid, uuid, text, text, jsonb, int, uuid)', 'execute')
          and to_regprocedure('public.bi_view_save(uuid, uuid, text, text, jsonb, int)') is null,
          'one writer, for signed-in callers only');

select * from finish();
rollback;
