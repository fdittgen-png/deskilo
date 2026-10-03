-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #1923 C — saved Web-BI views. viewAnalytics reads and keeps private
-- views; a team view and the team default need workspaceSettings; nobody
-- sees or changes another person's private view; a stale revision is
-- refused (no lost update); a definition is bounded and declarative; my
-- default and the team default are independent; my views travel in my
-- access export. Positive cases beside every refusal.
begin;
select plan(21);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u_o uuid := '00000000-0000-4000-8000-00000019230a';
  u_a uuid := '00000000-0000-4000-8000-00000019230b';
  u_m uuid := '00000000-0000-4000-8000-00000019230c';
  u_x uuid := '00000000-0000-4000-8000-00000019230d';
  ws uuid; ws2 uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'biviews-' || u || '@deskilo.test', '', now(), now(), now()
    from unnest(array[u_o, u_a, u_m, u_x]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Views', 'FR', 'EUR', 'Europe/Paris', u_o) returning id into ws;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Elsewhere', 'FR', 'EUR', 'Europe/Paris', u_x) returning id into ws2;
  -- owner: viewAnalytics + workspaceSettings; admin: viewAnalytics only
  -- (the default admin list); member: neither; stranger: another space.
  insert into public.members (workspace_id, user_id, is_owner, is_admin)
  values (ws, u_o, true, true), (ws, u_a, false, true), (ws, u_m, false, false),
         (ws2, u_x, true, true);
  perform set_config('bv.ws', ws::text, false);
  perform set_config('bv.owner', u_o::text, false);
  perform set_config('bv.admin', u_a::text, false);
  perform set_config('bv.member', u_m::text, false);
  perform set_config('bv.stranger', u_x::text, false);
end
$seed$;

create or replace function pg_temp.act_as(p_who text) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', current_setting('bv.' || p_who),
                      'role', 'authenticated')::text, true);
end
$act$;

-- Saves as p_who and returns the view json, or the SQLSTATE refused.
create or replace function pg_temp.save(p_who text, p_id uuid, p_scope text, p_name text,
                                        p_def jsonb, p_rev int) returns jsonb
language plpgsql as $s$
begin
  perform pg_temp.act_as(p_who);
  return public.bi_view_save(current_setting('bv.ws')::uuid, p_id, p_scope, p_name, p_def, p_rev);
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

select pg_temp.seed();

select is(has_table_privilege('authenticated', 'public.bi_views', 'select')
          or has_table_privilege('anon', 'public.bi_views', 'select'), false,
          'the table itself is not readable: every read goes through the gate');

select is(pg_temp.save('admin', null, 'private', 'Mine', '{"v":1,"query":{"by":"level"}}', 0) ->> 'revision',
          '1', 'an analytics reader saves a private view');
select is(pg_temp.save('admin', null, 'workspace', 'Team?', '{"v":1}', 0) ->> 'refused',
          '42501', 'but not a team view without workspaceSettings');
select is(pg_temp.save('owner', null, 'workspace', 'Team', '{"v":1,"query":{"grain":"year"}}', 0) ->> 'scope',
          'workspace', 'the manager shares a team view');
select is(pg_temp.save('owner', null, 'private', 'Owner only', '{"v":1}', 0) ->> 'mine',
          'true', 'and keeps a private one');
select is(pg_temp.save('member', null, 'private', 'Nope', '{"v":1}', 0) ->> 'refused',
          '42501', 'a member without viewAnalytics keeps no view');
select is(pg_temp.call('stranger', format('select public.bi_views_list(%L)', current_setting('bv.ws'))),
          '42501', 'a stranger lists nothing');
select is(pg_temp.call('member', format('select public.bi_views_list(%L)', current_setting('bv.ws'))),
          '42501', 'nor does a member without viewAnalytics');

select pg_temp.act_as('admin');
select is((select jsonb_agg(v ->> 'name' order by v ->> 'name')
             from jsonb_array_elements(public.bi_views_list(current_setting('bv.ws')::uuid)) v),
          '["Mine", "Team"]'::jsonb, 'the reader sees their own views and the team''s, not the owner''s private one');

select is(pg_temp.save('admin',
            (select id from public.bi_views where name = 'Owner only'), 'private', 'Taken', '{"v":1}', 1) ->> 'refused',
          '42501', 'nobody changes another person''s private view');
select is(pg_temp.save('admin',
            (select id from public.bi_views where name = 'Mine'), 'private', 'Mine', '{"v":1,"query":{"grain":"quarter"}}', 1) ->> 'revision',
          '2', 'saving with the revision read moves it on');
select is(pg_temp.save('admin',
            (select id from public.bi_views where name = 'Mine'), 'private', 'Lost', '{"v":1}', 1) ->> 'refused',
          '40001', 'a save from a stale revision is refused, not lost silently');
select is((select definition from public.bi_views where name = 'Mine'),
          '{"v":1,"query":{"grain":"quarter"}}'::jsonb, 'and the newer definition stands');
select is(pg_temp.save('admin', null, 'private', 'mine', '{"v":1}', 0) ->> 'refused',
          '23505', 'two of my views do not share a name');
select is(pg_temp.save('admin', null, 'private', 'Script', '{"v":1,"sql":"select 1"}', 0) ->> 'refused',
          '22023', 'a definition holds only the declared keys');
select is(pg_temp.save('admin', null, 'private', 'Huge',
            jsonb_build_object('v', 1, 'cards', (select jsonb_agg('m' || g) from generate_series(1, 21) g)), 0) ->> 'refused',
          '22023', 'and stays bounded');

select is(pg_temp.call('admin', format('select public.bi_view_set_default(%L, ''workspace'', %L)',
            current_setting('bv.ws'), (select id from public.bi_views where name = 'Team'))),
          '42501', 'only the manager sets the team default');
select is(pg_temp.call('owner', format('select public.bi_view_set_default(%L, ''workspace'', %L)',
            current_setting('bv.ws'), (select id from public.bi_views where name = 'Team'))),
          'ok', 'the manager does');
select is(pg_temp.call('admin', format('select public.bi_view_set_default(%L, ''private'', %L)',
            current_setting('bv.ws'), (select id from public.bi_views where name = 'Mine')))
          || pg_temp.call('admin', format('select public.bi_view_set_default(%L, ''private'', null)',
            current_setting('bv.ws'))),
          'okok', 'a reader sets and clears their own default');
select is((select is_default from public.bi_views where name = 'Team'), true,
          'clearing my default leaves the team default alone');

select pg_temp.act_as('admin');
select is((select jsonb_agg(v ->> 'name') from jsonb_array_elements(
             public.export_my_data(current_setting('bv.ws')::uuid) -> 'bi_views') v),
          '["Mine"]'::jsonb, 'my access export carries my views, not the team''s');

select * from finish();
rollback;
