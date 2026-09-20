-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #1451 — the Workspace settings Save commits every field or none, never
-- overwrites a change it did not see, and a retried Save is not a
-- different result.
begin;
select plan(9);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  u uuid := '00000000-0000-4000-8000-000000001451';
  v uuid := '00000000-0000-4000-8000-000000001454';
  ws uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  values (u, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'settings-owner@deskilo.test', '', now(), now(), now()),
         (v, '00000000-0000-0000-0000-000000000000', 'authenticated',
          'authenticated', 'settings-member@deskilo.test', '', now(), now(), now());
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, billing_rules)
  values ('Settings', 'DE', 'EUR', 'Europe/Berlin', u, '{"reminder_days": 7}') returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin) values (ws, u, true, true);
  insert into public.members (workspace_id, user_id) values (ws, v);
  perform set_config('deskilo.set.ws', ws::text, false);
  perform set_config('deskilo.set.owner', u::text, false);
  perform set_config('deskilo.set.member', v::text, false);
  perform set_config('request.jwt.claims',
    json_build_object('sub', u::text, 'role', 'authenticated')::text, false);
end;
$seed$;

select pg_temp.seed();

create or replace function pg_temp.opened() returns timestamptz language sql as $$
  select modified_datetime from public.workspaces where id = current_setting('deskilo.set.ws')::uuid;
$$;

create or replace function pg_temp.payload(p_address text, p_pct int default 80) returns jsonb language sql as $$
  select jsonb_build_object(
    'country_code', 'fr', 'currency_code', 'eur', 'timezone', 'Europe/Paris',
    'whatsapp_group', '', 'address', p_address, 'default_locale', 'fr',
    'desk_opacity', 60,
    'invitation_templates', jsonb_build_object('fr', ' Bonjour ', 'en', '  '),
    'new_member_defaults', jsonb_build_object('subscription_pct', p_pct));
$$;

select set_config('deskilo.set.v0', pg_temp.opened()::text, false);
-- `modified_datetime` is stamped with now(), which one transaction never
-- moves; a form opened before somebody else's change carries an OLDER
-- version, and that is what the conflict path compares.
select set_config('deskilo.set.stale', (pg_temp.opened() - interval '1 minute')::text, false);

-- An invalid rule is refused AFTER the column assignments would have run.
select throws_like(
  format($$ select public.save_workspace_settings(%L, %L, pg_temp.payload('1 rue Neuve', 500)) $$,
         current_setting('deskilo.set.ws'), current_setting('deskilo.set.v0')),
  '%percentage between%',
  'an invalid value is refused');

select is(
  (select country_code || '|' || timezone || '|' || coalesce(address, '') from public.workspaces
    where id = current_setting('deskilo.set.ws')::uuid),
  'DE|Europe/Berlin|', 'and not one field of that Save was written');

select is(
  public.save_workspace_settings(current_setting('deskilo.set.ws')::uuid,
    current_setting('deskilo.set.v0')::timestamptz, pg_temp.payload('1 rue Neuve'))->>'status',
  'saved', 'a valid Save commits');

select is(
  (select country_code || '|' || currency_code || '|' || timezone || '|' || address || '|' || default_locale
          || '|' || desk_opacity || '|' || invitation_templates::text || '|' || invitation_template
          || '|' || (billing_rules->'new_member_defaults'->>'subscription_pct')
     from public.workspaces where id = current_setting('deskilo.set.ws')::uuid),
  'FR|EUR|Europe/Paris|1 rue Neuve|fr|60|{"fr": "Bonjour"}||80',
  'every field together: ISO codes upper-cased, blank templates dropped, the legacy template cleared');

select is(
  (select billing_rules->>'reminder_days' from public.workspaces where id = current_setting('deskilo.set.ws')::uuid),
  '7', 'every other billing rule survives');

select is(
  public.save_workspace_settings(current_setting('deskilo.set.ws')::uuid,
    current_setting('deskilo.set.stale')::timestamptz, pg_temp.payload('1 rue Neuve'))->>'status',
  'unchanged', 'a retry of the same Save on the old version is not a conflict and writes nothing');

select throws_ok(
  format($$ select public.save_workspace_settings(%L, %L, pg_temp.payload('2 rue Autre')) $$,
         current_setting('deskilo.set.ws'), current_setting('deskilo.set.stale')),
  'DK409', 'the workspace settings changed since they were opened',
  'a different Save on a version that moved is a conflict');

select is(
  (select address from public.workspaces where id = current_setting('deskilo.set.ws')::uuid),
  '1 rue Neuve', 'and the committed change was not overwritten');

-- A plain member, under RLS. The payload is rendered before the role
-- changes: the session's temp functions belong to the seeding role.
select set_config('deskilo.set.hijack', pg_temp.payload('hijack')::text, false);
select set_config('request.jwt.claims',
  json_build_object('sub', current_setting('deskilo.set.member'), 'role', 'authenticated')::text, true);
set local role authenticated;
select throws_ok(
  format($$ select public.save_workspace_settings(%L, null, %L::jsonb) $$,
         current_setting('deskilo.set.ws'), current_setting('deskilo.set.hijack')),
  'only the owner and co-owners change the workspace settings',
  'a plain member cannot save the workspace settings');
reset role;

select * from finish();
rollback;
