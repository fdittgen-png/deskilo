-- SPDX-License-Identifier: 0BSD
--
-- #1280 S4 — updating from a template marks what this workspace changed
-- since it last applied the same template, so one tick cannot undo it.
begin;
select plan(3);

create or replace function pg_temp.act_as(p_user uuid) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', p_user::text, true);
  execute 'set local role authenticated';
end
$act$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
values ('00000000-0000-4000-8000-0000000012f1', '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated', 'customized-owner@deskilo.test', '', now(), now(), now());

select pg_temp.act_as('00000000-0000-4000-8000-0000000012f1');
select set_config('deskilo.cz.src',
  public.create_workspace('Source', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select set_config('deskilo.cz.dst',
  public.create_workspace('Target', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select set_config('deskilo.cz.fresh',
  public.create_workspace('Fresh', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);

reset role;
update public.workspaces set booking_rules = booking_rules || '{"granularity":"half_day"}'
 where id = current_setting('deskilo.cz.src')::uuid;

select pg_temp.act_as('00000000-0000-4000-8000-0000000012f1');
select set_config('deskilo.cz.tpl', public.save_workspace_as_template(
  current_setting('deskilo.cz.src')::uuid, 'rules', 'Rules', '', 'private', '{}',
  array['hours_booking'])::text, true);
select public.apply_workspace_template(current_setting('deskilo.cz.dst')::uuid,
  current_setting('deskilo.cz.tpl')::uuid, array['hours_booking']);

-- The workspace customizes its hours; the template moves on as well.
reset role;
update public.workspaces set booking_rules = booking_rules || '{"granularity":"hours"}'
 where id = current_setting('deskilo.cz.dst')::uuid;
update public.workspaces set booking_rules = booking_rules || '{"granularity":"full_day"}'
 where id = current_setting('deskilo.cz.src')::uuid;
select pg_temp.act_as('00000000-0000-4000-8000-0000000012f1');
select public.save_workspace_as_template(current_setting('deskilo.cz.src')::uuid,
  'rules', 'Rules', '', 'private', '{}', array['hours_booking']);

select is(
  (select (g.value->>'customized')::boolean
     from jsonb_array_elements(public.preview_workspace_template(
       current_setting('deskilo.cz.dst')::uuid, current_setting('deskilo.cz.tpl')::uuid)->'groups') g
    where g.value->>'group' = 'hours_booking'),
  true,
  'a group changed here since the last application is marked customized');
select is(
  (select count(*)::int
     from jsonb_array_elements(public.preview_workspace_template(
       current_setting('deskilo.cz.dst')::uuid, current_setting('deskilo.cz.tpl')::uuid)->'groups') g,
          jsonb_array_elements(g.value->'items') i
    where (i.value->>'customized')::boolean),
  1,
  'and so is the item itself');
select is(
  (select count(*)::int
     from jsonb_array_elements(public.preview_workspace_template(
       current_setting('deskilo.cz.fresh')::uuid, current_setting('deskilo.cz.tpl')::uuid)->'groups') g
    where (g.value->>'customized')::boolean),
  0,
  'a workspace that never applied the template sees no marks');

select * from finish();
rollback;
