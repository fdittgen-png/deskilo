-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #2581 — a report is exported from one authorised snapshot. The owner
-- exports the capacity and finance figures of one statement with a digest,
-- and one evidence row records who, which format, a fingerprint and the
-- digest (never a figure). A reader without exportData is refused although
-- the same figures stay readable to them; an exporter without the finance
-- right gets the capacity figure and not the finance one; a role revoked
-- before the call refuses it. Another workspace's caller, another
-- workspace's report id, a private report of someone else, a stale
-- revision and a figure the report does not hold are refused; an unknown
-- format, a malformed or unregistered request and a request over the
-- space's limit are refused (54000, never a cut file); a format whose
-- feature is off is 0A000 while the other format still answers. The
-- evidence is append-only but lets an account's erasure through. The saved
-- print layout accepts margins, a typed header and footer and page breaks,
-- and refuses anything longer, multi-line or unknown. Positive cases beside
-- every refusal.
begin;
select plan(36);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-0000025810c1';
  u_a uuid := '00000000-0000-4000-8000-0000025810c2';
  u_e uuid := '00000000-0000-4000-8000-0000025810c3';
  u_x uuid := '00000000-0000-4000-8000-0000025810c4';
  ws uuid; ws2 uuid; m_a uuid; m_e uuid; r_a uuid; r_e uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'biexport-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_a, u_e, u_x]) u;
  -- The figures' features and their parents, custom roles for the two
  -- readers' roles, and both export formats.
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Exports', 'FR', 'EUR', 'Europe/Paris', u_o,
          '{"capacityKpi": true, "customRoles": true, "moneyTab": true, "invoicing": true, "workspaceStatus": true, "pdfExport": true, "dataExport": true}'::jsonb)
  returning id into ws;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, feature_flags)
  values ('Elsewhere', 'FR', 'EUR', 'Europe/Paris', u_x,
          '{"capacityKpi": true, "pdfExport": true, "dataExport": true}'::jsonb)
  returning id into ws2;
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_o, true, true), (ws, u_a, false, false), (ws, u_e, false, false),
         (ws2, u_x, true, true);
  select id into m_a from public.members where workspace_id = ws and user_id = u_a;
  select id into m_e from public.members where workspace_id = ws and user_id = u_e;
  -- An analyst who reads every figure but may not export; an exporter who
  -- may export and reads the capacity figure, not the finances.
  insert into public.workspace_roles (workspace_id, key, permissions)
  values (ws, 'analyst', array['viewAnalytics', 'viewFinances', 'manageReservations']) returning id into r_a;
  insert into public.workspace_roles (workspace_id, key, permissions)
  values (ws, 'exporter', array['viewAnalytics', 'exportData', 'manageReservations']) returning id into r_e;
  insert into public.workspace_role_members (workspace_id, role_id, member_id)
  values (ws, r_a, m_a), (ws, r_e, m_e);
  perform set_config('bx.ws', ws::text, false);
  perform set_config('bx.ws2', ws2::text, false);
  perform set_config('bx.owner', u_o::text, false);
  perform set_config('bx.analyst', u_a::text, false);
  perform set_config('bx.exporter', u_e::text, false);
  perform set_config('bx.stranger', u_x::text, false);
  perform set_config('bx.role_e', r_e::text, false);
end
$seed$;

create or replace function pg_temp.act_as(p_who text) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('bx.' || p_who),
                      'role', 'authenticated')::text, true);
end
$act$;

create or replace function pg_temp.cap(p_key text) returns jsonb language sql as $c$
  select jsonb_build_object('request_key', p_key, 'metric_id', 'capacity.seat_utilisation',
                            'from', '2026-09-01T00:00:00Z', 'to', '2026-10-01T00:00:00Z')
$c$;

create or replace function pg_temp.fin(p_key text) returns jsonb language sql as $f$
  select jsonb_build_object('request_key', p_key, 'metric_id', 'finance.invoiced',
                            'from_month', '2026-09', 'to_month', '2026-09')
$f$;

-- Exports as p_who (from p_ws, default the space) and returns the answer,
-- or the SQLSTATE refused.
create or replace function pg_temp.export(p_who text, p_requests jsonb, p_format text default 'pdf',
                                          p_report uuid default null, p_rev int default null,
                                          p_ws text default 'ws') returns jsonb
language plpgsql as $e$
begin
  perform pg_temp.act_as(p_who);
  return public.bi_export_snapshot_v1(current_setting('bx.' || p_ws)::uuid, p_requests,
                                      p_report, p_rev, p_format);
exception when others then
  return jsonb_build_object('refused', sqlstate);
end
$e$;

create or replace function pg_temp.call(p_who text, p_sql text) returns text
language plpgsql as $c$
begin
  if p_who is not null then perform pg_temp.act_as(p_who); end if;
  execute p_sql;
  return 'ok';
exception when others then
  return sqlstate;
end
$c$;

create or replace function pg_temp.style(p_style jsonb) returns boolean language sql as $s$
  select public.bi_report_valid(jsonb_build_object(
    'v', 2, 'reportFilters', '[]'::jsonb,
    'period', jsonb_build_object('mode', 'relative', 'grain', 'month', 'offset', -1),
    'pages', jsonb_build_array(jsonb_build_object('id', 'p1', 'title', 'Page 1', 'filters', '[]'::jsonb,
      'visuals', jsonb_build_array(jsonb_build_object(
        'id', 'v1', 'type', 'kpi', 'metricId', 'capacity.seat_utilisation', 'metricVersion', 1,
        'layout', jsonb_build_object('order', 0, 'span', 6, 'height', 2))))),
    'printStyle', p_style))
$s$;

select pg_temp.seed();

-- ── the owner exports ────────────────────────────────────────────────
select set_config('bx.answer',
  pg_temp.export('owner', jsonb_build_array(pg_temp.cap('c'), pg_temp.fin('f')))::text, false);
select is(current_setting('bx.answer')::jsonb ->> 'format', 'pdf', 'the owner exports the figures as a PDF');
select is(current_setting('bx.answer')::jsonb ->> 'workspace_id', current_setting('bx.ws'),
          'the answer names its workspace');
select is(jsonb_array_length(current_setting('bx.answer')::jsonb -> 'results'), 2,
          'both figures of the export are answered, in one statement');
select ok(current_setting('bx.answer')::jsonb ->> 'hash' ~ '^[0-9a-f]{64}$',
          'with a SHA-256 digest of the figures');
select is((select count(*)::int from public.bi_export_evidence
            where workspace_id = current_setting('bx.ws')::uuid
              and user_id = current_setting('bx.owner')::uuid and format = 'pdf'
              and requests = 2 and report_id is null
              and result_hash = current_setting('bx.answer')::jsonb ->> 'hash'), 1,
          'one evidence row records who, the format, the count and the digest');
select is((select array_agg(column_name::text order by column_name::text)
             from information_schema.columns
            where table_schema = 'public' and table_name = 'bi_export_evidence'
              and column_name <> all (public.system_column_names())),
          array['computed_at', 'filter_fingerprint', 'format', 'id', 'report_id', 'report_revision',
                'requests', 'result_hash', 'user_id', 'workspace_id'],
          'and holds no figure, name or filter value');

-- ── the right to export, and every figure's own rights ───────────────
select is(pg_temp.export('analyst', jsonb_build_array(pg_temp.cap('c'))) ->> 'refused', '42501',
          'a reader without exportData exports nothing');
select is(pg_temp.call('analyst', format('select public.bi_query_batch_v1(%L, %L)',
            current_setting('bx.ws'), jsonb_build_array(pg_temp.cap('c')))), 'ok',
          'although they still read the same figure');
select is(pg_temp.export('exporter', jsonb_build_array(pg_temp.cap('c')), 'csv') ->> 'format', 'csv',
          'an exporter who reads the capacity figure exports it');
select is(pg_temp.export('exporter', jsonb_build_array(pg_temp.cap('c'), pg_temp.fin('f')), 'csv') ->> 'refused',
          '42501', 'but not with a finance figure they may not read');
select is(pg_temp.export('stranger', jsonb_build_array(pg_temp.cap('c'))) ->> 'refused', '42501',
          'a member of another space exports nothing here');
select is(pg_temp.export('stranger', jsonb_build_array(pg_temp.cap('c')), 'pdf', null, null, 'ws2') ->> 'format',
          'pdf', 'while exporting their own space''s figure');

-- ── what is asked ────────────────────────────────────────────────────
select is(pg_temp.export('owner', jsonb_build_array(pg_temp.cap('c')), 'docx') ->> 'refused', '22023',
          'an unknown format is refused');
select is(pg_temp.export('owner', '{}'::jsonb) ->> 'refused', '22023', 'a request that is not a list is refused');
select is(pg_temp.export('owner', '[]'::jsonb) ->> 'refused', '22023', 'an empty export is refused');
select is(pg_temp.export('owner', jsonb_build_array('{"request_key": "x", "metric_id": "capacity.made_up"}'::jsonb)) ->> 'refused',
          '22023', 'an unregistered figure is refused');
select is(pg_temp.export('owner', jsonb_build_array('"capacity.seat_utilisation"'::jsonb)) ->> 'refused',
          '22023', 'a malformed request is refused');
select is(pg_temp.export('owner', (select jsonb_agg(pg_temp.cap('c' || i)) from generate_series(1, 61) i)) ->> 'refused',
          '54000', 'more figures than the space''s limit are refused, never cut');
select is(pg_temp.export('owner', (select jsonb_agg(pg_temp.cap('c' || i)) from generate_series(1, 60) i)) ->> 'format',
          'pdf', 'the limit itself is answered');
update public.workspaces set feature_flags = feature_flags || '{"dataExport": false}'::jsonb
 where id = current_setting('bx.ws')::uuid;
select is(pg_temp.export('owner', jsonb_build_array(pg_temp.cap('c')), 'xlsx') ->> 'refused', '0A000',
          'a data file is refused while data export is off');
select is(pg_temp.export('owner', jsonb_build_array(pg_temp.cap('c')), 'pdf') ->> 'format', 'pdf',
          'while a PDF is still answered');
update public.workspaces set feature_flags = feature_flags || '{"dataExport": true}'::jsonb
 where id = current_setting('bx.ws')::uuid;

-- ── a saved report ───────────────────────────────────────────────────
insert into public.bi_views (workspace_id, user_id, scope, name, definition)
values (current_setting('bx.ws')::uuid, current_setting('bx.owner')::uuid, 'private', 'Seats',
        jsonb_build_object('v', 2, 'reportFilters', '[]'::jsonb,
          'period', jsonb_build_object('mode', 'relative', 'grain', 'month', 'offset', -1),
          'pages', jsonb_build_array(jsonb_build_object('id', 'p1', 'title', 'Seats', 'filters', '[]'::jsonb,
            'visuals', jsonb_build_array(jsonb_build_object(
              'id', 'v1', 'type', 'kpi', 'metricId', 'capacity.seat_utilisation', 'metricVersion', 1,
              'layout', jsonb_build_object('order', 0, 'span', 6, 'height', 2)))))));
select set_config('bx.report', (select id::text from public.bi_views where name = 'Seats'), false);
select is(pg_temp.export('owner', jsonb_build_array(pg_temp.cap('c')), 'pdf',
            current_setting('bx.report')::uuid, 1) ->> 'report_revision', '1',
          'the owner exports their report at the revision they opened');
select is((select count(*)::int from public.bi_export_evidence
            where report_id = current_setting('bx.report')::uuid and report_revision = 1), 1,
          'and the evidence names the report and its revision');
select is(pg_temp.export('owner', jsonb_build_array(pg_temp.cap('c')), 'pdf',
            current_setting('bx.report')::uuid, 2) ->> 'refused', '40001',
          'a revision they did not open is stale');
select is(pg_temp.export('owner', jsonb_build_array(pg_temp.cap('c'), pg_temp.fin('f')), 'pdf',
            current_setting('bx.report')::uuid, 1) ->> 'refused', '42501',
          'a figure the report does not hold is refused, even to its owner');
select is(pg_temp.export('exporter', jsonb_build_array(pg_temp.cap('c')), 'csv',
            current_setting('bx.report')::uuid, 1) ->> 'refused', '42501',
          'someone else''s private report is not exported by its id');
select is(pg_temp.export('stranger', jsonb_build_array(pg_temp.cap('c')), 'pdf',
            current_setting('bx.report')::uuid, 1, 'ws2') ->> 'refused', '42501',
          'nor reached through another workspace');

-- ── a right revoked before the call ──────────────────────────────────
delete from public.workspace_role_members where role_id = current_setting('bx.role_e')::uuid;
select is(pg_temp.export('exporter', jsonb_build_array(pg_temp.cap('c')), 'csv') ->> 'refused', '42501',
          'a revoked role exports nothing from the next call on');

-- ── the evidence ─────────────────────────────────────────────────────
reset role;
select is(pg_temp.call(null, 'update public.bi_export_evidence set format = ''csv'''), 'P0001',
          'the evidence is never edited');
select is(pg_temp.call(null, format('update public.bi_export_evidence set user_id = null where user_id = %L',
            current_setting('bx.owner'))), 'ok',
          'but an account''s erasure goes through');
select ok(not has_table_privilege('authenticated', 'public.bi_export_evidence', 'select, insert, update, delete')
          and not has_table_privilege('anon', 'public.bi_export_evidence', 'select'),
          'no client reads or writes the evidence directly');
select ok(not has_function_privilege('anon', 'public.bi_export_snapshot_v1(uuid, jsonb, uuid, int, text)', 'execute')
          and has_function_privilege('authenticated', 'public.bi_export_snapshot_v1(uuid, jsonb, uuid, int, text)', 'execute'),
          'the export read is for signed-in callers only');

-- ── the print layout ─────────────────────────────────────────────────
select ok(pg_temp.style('{"paper": "Letter", "orientation": "landscape", "showSources": false, "margin": "narrow", "header": "Board pack — Q3", "footer": "Confidential", "pageBreaks": false}'),
          'a print layout with margins, a header, a footer and page breaks is stored');
select ok(not pg_temp.style(jsonb_build_object('header', repeat('x', 121))),
          'a header over 120 characters is refused');
select ok(not pg_temp.style(jsonb_build_object('footer', E'two\nlines')),
          'a footer on two lines is refused');
select ok(not pg_temp.style('{"margin": "none"}') and not pg_temp.style('{"html": "<b>x</b>"}'),
          'an unknown margin or key is refused');

select * from finish();
rollback;
