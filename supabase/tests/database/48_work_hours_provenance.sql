-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #1307 S4 — the working day says where it came from, and goes back.
begin;
select plan(6);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u uuid := '00000000-0000-4000-8000-000000001307';
  ws uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'provenance@deskilo.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('Provenance', 'FR', 'EUR', 'Europe/Paris', u) returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin) values (ws, u, true, true);
  perform set_config('deskilo.pv.ws', ws::text, false);
  perform set_config('request.jwt.claims',
    json_build_object('sub', u::text, 'role', 'authenticated')::text, false);
end;
$seed$;

select pg_temp.seed();

create or replace function pg_temp.state() returns text language sql as $$
  select public.work_hours_provenance(current_setting('deskilo.pv.ws')::uuid)->>'state';
$$;

select is(pg_temp.state(), 'default', 'no work-hour key set: the product default');

select public.set_booking_rule(current_setting('deskilo.pv.ws')::uuid, 'work_start_minutes', '420');
select is(pg_temp.state(), 'workspace', 'a key set here is a workspace setting');

select public.apply_workspace_template(current_setting('deskilo.pv.ws')::uuid,
  (select id from public.workspace_templates where key = 'association_fr'),
  array['hours_booking']);
select is(pg_temp.state(), 'template',
  'after the association template carried the hours, they read as the template''s');
select ok(
  public.work_hours_provenance(current_setting('deskilo.pv.ws')::uuid)->'template'->>'name' is not null,
  'and the template is named');

select public.set_booking_rule(current_setting('deskilo.pv.ws')::uuid, 'work_end_minutes', '1200');
select is(pg_temp.state(), 'workspace', 'an edit after the template makes it a workspace setting again');

select public.reset_work_hours(current_setting('deskilo.pv.ws')::uuid);
select is(pg_temp.state(), 'default', 'resetting removes the keys: back to the product default');

select * from finish();
rollback;
