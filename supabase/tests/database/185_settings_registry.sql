-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2484 / 0428: the settings registry. The registry row decides who may write
-- (the platform owner alone for the platform scope, the definition's
-- permission for a workspace), what is acceptable (type, bounds, security
-- floor, guardrails) and what is audited; `setting_value` resolves workspace
-- over platform over the registry default; a change closes the version in
-- force. The dunning rules no longer store the proof setting. Seeds run as
-- postgres, callers as `authenticated`.
begin;
select plan(31);

create function pg_temp.act_as(p_user uuid, p_client text default null) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_strip_nulls(jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2', 'client_id', p_client))::text, true);
  execute 'set local role authenticated';
end;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000002484a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'platform-2484@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000002484a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner-2484@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000002484a3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'member-2484@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000002484a4', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'other-2484@deskilo.test', '', now(), now(), now());
delete from public.platform_admins;
insert into public.platform_admins (user_id) values ('00000000-0000-4000-8000-0000002484a1');

insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, dunning_rules) values
 ('00000000-0000-4000-8000-0000002484b1', 'Settings 2484 A', 'FR', 'EUR', 'Europe/Paris', '00000000-0000-4000-8000-0000002484a2', '{"levels": 3}'),
 ('00000000-0000-4000-8000-0000002484b2', 'Settings 2484 B', 'FR', 'EUR', 'Europe/Paris', '00000000-0000-4000-8000-0000002484a4', '{}');
insert into public.members (workspace_id, user_id, is_owner, is_admin, joined_at) values
 ('00000000-0000-4000-8000-0000002484b1', '00000000-0000-4000-8000-0000002484a2', true, true, '2026-01-01'),
 ('00000000-0000-4000-8000-0000002484b1', '00000000-0000-4000-8000-0000002484a3', false, false, '2026-01-01'),
 ('00000000-0000-4000-8000-0000002484b2', '00000000-0000-4000-8000-0000002484a4', true, true, '2026-01-01');

-- Two rows only this file needs: a floor and a guardrail.
insert into public.setting_definitions (key, type, default_value, min_value, max_value, unit, group_key, scopes,
                                        edit_permission, floor_value, editable, note) values
 ('test.lockout_minutes', 'duration', '15', 5, 120, 'minutes', 'test', array['platform'], '', 10, true, 'floor test'),
 ('test.fixed_limit', 'int', '8', null, null, 'digits', 'test', array['platform', 'workspace'], 'workspaceSettings', null, false, 'the reader accepts eight');

-- ── the default applies until somebody sets something ──────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000002484a3');
select is(public.setting_value('00000000-0000-4000-8000-0000002484b1', 'dunning.first_after_days')::text, '14',
          'a member reads the registry default while nothing is set');
select throws_ok($$select public.setting_value('00000000-0000-4000-8000-0000002484b2', 'dunning.first_after_days')$$,
  'P0001', null, 'a member cannot read another workspace''s value');
select throws_ok($$select public.setting_value('00000000-0000-4000-8000-0000002484b1', 'no.such_key')$$,
  'P0001', null, 'an unknown key is an error, not a silent default');

-- ── permission by definition ───────────────────────────────────────────
select throws_ok($$select public.set_setting('00000000-0000-4000-8000-0000002484b1', 'dunning.first_after_days', '30', '')$$,
  'P0001', 'not allowed to change this setting', 'a member without the permission cannot set a workspace value');
select throws_ok($$select public.set_setting(null, 'dunning.first_after_days', '30', '')$$,
  'P0001', 'platform owners only', 'nor the platform default');

select pg_temp.act_as('00000000-0000-4000-8000-0000002484a2');
select is(public.set_setting('00000000-0000-4000-8000-0000002484b1', 'dunning.first_after_days', '30', 'quarterly')->>'status', 'saved',
          'the workspace owner sets the workspace value');
select is(public.setting_value('00000000-0000-4000-8000-0000002484b1', 'dunning.first_after_days')::text, '30', 'and it applies');
select throws_ok($$select public.set_setting(null, 'dunning.first_after_days', '30', '')$$,
  'P0001', 'platform owners only', 'a workspace owner cannot write the platform scope');
select throws_ok($$select public.set_setting('00000000-0000-4000-8000-0000002484b2', 'dunning.first_after_days', '30', '')$$,
  'P0001', null, 'nor another workspace''s value');

-- ── validation: type, bounds, floor, guardrail ─────────────────────────
select throws_ok($$select public.set_setting('00000000-0000-4000-8000-0000002484b1', 'dunning.first_after_days', '0', '')$$,
  'P0001', null, 'below the minimum is refused');
select throws_ok($$select public.set_setting('00000000-0000-4000-8000-0000002484b1', 'dunning.first_after_days', '366', '')$$,
  'P0001', null, 'above the maximum is refused');
select throws_ok($$select public.set_setting('00000000-0000-4000-8000-0000002484b1', 'dunning.first_after_days', '"ten"', '')$$,
  'P0001', null, 'the wrong type is refused');
select throws_ok($$select public.set_setting('00000000-0000-4000-8000-0000002484b1', 'test.fixed_limit', '6', '')$$,
  'P0001', null, 'a guardrail cannot be written');
select throws_ok($$select public.set_setting('00000000-0000-4000-8000-0000002484b1', 'test.lockout_minutes', '30', '')$$,
  'P0001', null, 'a platform-only setting has no workspace value');

-- ── the platform owner: default, floor, precedence ─────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000002484a1');
select throws_ok($$select public.set_setting(null, 'test.lockout_minutes', '9', '')$$,
  'P0001', null, 'a value under the security floor is refused (above the minimum, below the floor)');
select is(public.set_setting(null, 'test.lockout_minutes', '30', '')->>'status', 'saved', 'a value over the floor is saved');
select is(public.set_setting(null, 'dunning.first_after_days', '10', 'platform default')->>'status', 'saved',
          'the platform owner sets the platform default');
select is(public.set_setting(null, 'dunning.first_after_days', '10', '')->>'status', 'unchanged', 'the same value again is not a new version');
select is(public.setting_value('00000000-0000-4000-8000-0000002484b2', 'dunning.first_after_days')::text, '10',
          'a workspace with no value of its own gets the platform default');
select is(public.setting_value('00000000-0000-4000-8000-0000002484b1', 'dunning.first_after_days')::text, '30',
          'a workspace value beats the platform default');

-- ── versions and history ───────────────────────────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-0000002484a2');
select public.set_setting('00000000-0000-4000-8000-0000002484b1', 'dunning.first_after_days', '45', '');
select is(jsonb_array_length(public.setting_history('00000000-0000-4000-8000-0000002484b1', 'dunning.first_after_days')), 2,
          'the history holds 30 and 45');
select is((select count(*)::int from jsonb_array_elements(public.setting_history('00000000-0000-4000-8000-0000002484b1', 'dunning.first_after_days')) e
            where e ->> 'valid_to' is null), 1,
          'exactly one version is in force: the one before was closed, not edited');

-- ── the dunning rules mirror the key; the two stay in step ────────────
select public.set_dunning_rules('00000000-0000-4000-8000-0000002484b1', '{"levels": 4, "first_after_days": 60}');
select is(public.setting_value('00000000-0000-4000-8000-0000002484b1', 'dunning.first_after_days')::text, '60',
          'the dunning dialog''s save lands in the setting');
select public.set_setting('00000000-0000-4000-8000-0000002484b1', 'dunning.first_after_days', '12', '');
reset role;
select is((select dunning_rules ->> 'first_after_days' from public.workspaces where id = '00000000-0000-4000-8000-0000002484b1'), '12',
          'and a write of the setting updates the rules'' mirror (the configuration transfer reads it)');
select is((select dunning_rules ->> 'levels' from public.workspaces where id = '00000000-0000-4000-8000-0000002484b1'), '4',
          'without touching the rest of the rules');
update public.workspaces set dunning_rules = dunning_rules || '{"first_after_days": 999}'
 where id = '00000000-0000-4000-8000-0000002484b1';
select is(public.setting_value('00000000-0000-4000-8000-0000002484b1', 'dunning.first_after_days')::text, '365',
          'an import writing the rules directly reaches the setting, held inside its bounds');
select is((select dunning_rules ->> 'first_after_days' from public.workspaces where id = '00000000-0000-4000-8000-0000002484b1'), '365',
          'and the mirror is brought back inside them');

-- ── the table is only read, only as far as the policy allows; the audit ─
select pg_temp.act_as('00000000-0000-4000-8000-0000002484a3');
select throws_ok($$insert into public.setting_values (scope, workspace_id, key, value) values ('platform', null, 'dunning.first_after_days', '5')$$,
  '42501', null, 'a client cannot insert a value');
select is((select count(*)::int from public.setting_values where workspace_id = '00000000-0000-4000-8000-0000002484b2'), 0,
          'a member sees no value of another workspace');
select ok((select count(*)::int from public.setting_values where workspace_id = '00000000-0000-4000-8000-0000002484b1') > 0,
          'and the values of their own');
reset role;
select ok((select count(*) from public.database_authority_audit where action = 'setting_set') >= 5, 'every change is audited');

select * from finish();
rollback;
