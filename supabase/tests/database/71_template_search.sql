-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #1659: the server's template search pages what the caller may read,
-- never leaks a hidden template, filters typed feature flags and refuses
-- a cursor from another query.
begin;
select plan(6);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000000283a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'q1659a@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000000283a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'q1659b@deskilo.test', '', now(), now(), now());
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000283a2","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.b', public.create_workspace('Other', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000283a1","role":"authenticated"}', true);
select set_config('t.a', public.create_workspace('Mine', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
insert into public.workspace_templates (key, name, visibility, owner_workspace_id, configuration, entities)
select 'zz_' || n, 'Zzcäse ' || lpad(n::text, 2, '0'), 'private', current_setting('t.a')::uuid,
       case when n <= 5 then '{"workspace":{"feature_flags":{"kioskMode":false}}}'::jsonb
            when n <= 10 then '{"workspace":{"feature_flags":{"kioskMode":true}}}'::jsonb else '{}'::jsonb end,
       '{features}'
  from generate_series(1, 60) n;
insert into public.workspace_templates (key, name, visibility, owner_workspace_id, configuration, entities)
values ('zz_secret', 'Zzcase secret', 'private', current_setting('t.b')::uuid, '{}', '{features}');
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000000283a1","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.p1', public.search_workspace_templates('ZZCASE', '{}', '{}', 25, null)::text, true);
select set_config('t.p2', public.search_workspace_templates('ZZCASE', '{}', '{}', 25, current_setting('t.p1')::jsonb->>'next_cursor')::text, true);
select set_config('t.p3', public.search_workspace_templates('ZZCASE', '{}', '{}', 25, current_setting('t.p2')::jsonb->>'next_cursor')::text, true);

select is(array[jsonb_array_length(current_setting('t.p1')::jsonb->'items'), jsonb_array_length(current_setting('t.p2')::jsonb->'items'),
                jsonb_array_length(current_setting('t.p3')::jsonb->'items')], array[25, 25, 10],
  'three pages, accent- and case-insensitive');
select is((select count(distinct x->>'id')::int from (
    select jsonb_array_elements(current_setting('t.p1')::jsonb->'items') x
    union all select jsonb_array_elements(current_setting('t.p2')::jsonb->'items')
    union all select jsonb_array_elements(current_setting('t.p3')::jsonb->'items')) q), 60, 'every readable match once');
select ok((current_setting('t.p1') || current_setting('t.p2') || current_setting('t.p3')) not like '%secret%',
  'another owner''s private template never appears');
select is(jsonb_array_length(public.search_workspace_templates('zzcase', array['kioskMode'], '{}', 100, null)->'items'), 55,
  'a required feature drops only the templates that switch it off');
select is(jsonb_array_length(public.search_workspace_templates('zzcase', '{}', array['kioskMode'], 100, null)->'items'), 55,
  'an excluded feature drops the templates that switch it on');
select throws_ok(format($$select public.search_workspace_templates('other', '{}', '{}', 25, %L)$$,
  current_setting('t.p1')::jsonb->>'next_cursor'), '22023', null, 'a cursor from another query is refused');

select * from finish();
rollback;
