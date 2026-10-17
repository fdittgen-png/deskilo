-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2487 / 0456 (S4 of #2483, messaging checkpoint): the message edit window and
-- the two refresh intervals are registry settings. Real roles throughout
-- (authenticated through the one writer); every scene proves today's
-- behaviour first, then the changed value.
--   A the rows and their defaults
--   B a workspace note: 14 minutes edits, 16 is refused with the default;
--     the workspace sets 30 and the same edit at 16 succeeds; history shows it
--   C a personal message reads the platform value, never a workspace override
--   D the bounds (floors) refuse a write, with the stored value read back
--   E a member who is not an administrator is refused, platform and workspace
begin;
select plan(28);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;

-- The refusal text of editing as [p_user]; '' when the edit worked.
create function pg_temp.edit_error(p_user uuid, p_kind text, p_id uuid, p_body text) returns text
language plpgsql as $$
begin
  perform pg_temp.act_as(p_user);
  perform public.edit_message(p_kind, p_id, p_body);
  reset role;
  return '';
exception when others then
  reset role;
  return sqlerrm;
end;
$$;

-- The refusal text of a setting write as [p_user]; '' when it was saved.
create function pg_temp.write_error(p_user uuid, p_ws uuid, p_key text, p_value text) returns text
language plpgsql as $$
begin
  perform pg_temp.act_as(p_user);
  perform public.set_setting(p_ws, p_key, p_value::jsonb, 'test');
  reset role;
  return '';
exception when others then
  reset role;
  return sqlerrm;
end;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select ('00000000-0000-4000-8000-00002487' || lpad(i::text, 4, '0'))::uuid,
       '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || i || '@messaging-windows.test', '', now(), now(), now()
  from generate_series(1, 3) i;
-- 1 owner of the workspace, 2 a plain member, 3 the platform owner.
insert into public.platform_admins (user_id) values ('00000000-0000-4000-8000-000024870003');

select pg_temp.act_as('00000000-0000-4000-8000-000024870001');
select set_config('t.ws', public.create_workspace('Messaging windows', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
reset role;
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"configurableSettings": true}'
 where id = current_setting('t.ws')::uuid;
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status)
values ('00000000-0000-4000-8000-000024870022', current_setting('t.ws')::uuid,
        '00000000-0000-4000-8000-000024870002', false, false, 'active');

-- The messages: workspace notes by the plain member at 14 and 16 minutes old,
-- and a personal message of the owner 7 minutes old.
insert into public.member_notes (id, workspace_id, from_member_id, to_member_id, body, created_at) values
 ('00000000-0000-4000-8000-0000248700a1', current_setting('t.ws')::uuid, '00000000-0000-4000-8000-000024870022', null, 'note 14', now() - interval '14 minutes'),
 ('00000000-0000-4000-8000-0000248700a2', current_setting('t.ws')::uuid, '00000000-0000-4000-8000-000024870022', null, 'note 16', now() - interval '16 minutes');
insert into public.account_conversations (id, user_a, user_b)
values ('00000000-0000-4000-8000-0000248700b1', '00000000-0000-4000-8000-000024870001', '00000000-0000-4000-8000-000024870002');
insert into public.account_messages (id, conversation_id, author_id, body, created_at)
values ('00000000-0000-4000-8000-0000248700c1', '00000000-0000-4000-8000-0000248700b1', '00000000-0000-4000-8000-000024870001', 'personal 7', now() - interval '7 minutes');

-- ── A: the rows ────────────────────────────────────────────────────────
select is((select count(*)::int from public.setting_definitions where key in (
  'messaging.edit_window_minutes', 'messaging.thread_poll_seconds', 'messaging.inbox_poll_seconds')), 3, 'the three rows exist');
select is(concat_ws('/', public.setting_value(null, 'messaging.edit_window_minutes'),
  public.setting_value(null, 'messaging.thread_poll_seconds'),
  public.setting_value(null, 'messaging.inbox_poll_seconds')), '15/15/30', 'the defaults are today''s values');
select is((select scopes from public.setting_definitions where key = 'messaging.edit_window_minutes'),
  array['platform', 'workspace'], 'the edit window is set per platform and per workspace');

-- ── B: a workspace note ────────────────────────────────────────────────
select is(pg_temp.edit_error('00000000-0000-4000-8000-000024870002', 'member_note', '00000000-0000-4000-8000-0000248700a1', 'fixed 14'), '',
  'golden: a note 14 minutes old can be edited');
select is((select body from public.member_notes where id = '00000000-0000-4000-8000-0000248700a1'), 'fixed 14', 'and the body changed');
select is(pg_temp.edit_error('00000000-0000-4000-8000-000024870002', 'member_note', '00000000-0000-4000-8000-0000248700a2', 'fixed 16'),
  'this message can no longer be edited', 'golden: at 16 minutes it is refused with the same text');
select is((select body from public.member_notes where id = '00000000-0000-4000-8000-0000248700a2'), 'note 16', 'and the body is unchanged');
select is(pg_temp.write_error('00000000-0000-4000-8000-000024870001', current_setting('t.ws')::uuid, 'messaging.edit_window_minutes', '30'), '',
  'the owner sets 30 minutes for the workspace');
select is(pg_temp.edit_error('00000000-0000-4000-8000-000024870002', 'member_note', '00000000-0000-4000-8000-0000248700a2', 'fixed 16'), '',
  'with 30 the same edit at 16 minutes succeeds, at once');
select is((select body from public.member_notes where id = '00000000-0000-4000-8000-0000248700a2'), 'fixed 16', 'and the body changed');
select is(pg_temp.write_error('00000000-0000-4000-8000-000024870001', current_setting('t.ws')::uuid, 'messaging.edit_window_minutes', '20'), '',
  'the owner changes it again');
select is((select count(*)::int from public.setting_values
            where workspace_id = current_setting('t.ws')::uuid and key = 'messaging.edit_window_minutes'), 2,
  'the history keeps both versions');
select is((select count(*)::int from public.setting_values
            where workspace_id = current_setting('t.ws')::uuid and key = 'messaging.edit_window_minutes' and valid_to is null), 1,
  'and exactly one is current');

-- ── C: a personal message reads the platform value ─────────────────────
select is(pg_temp.edit_error('00000000-0000-4000-8000-000024870001', 'account_message', '00000000-0000-4000-8000-0000248700c1', 'fixed 7'), '',
  'golden: a personal message 7 minutes old can be edited');
select is(pg_temp.write_error('00000000-0000-4000-8000-000024870003', null, 'messaging.edit_window_minutes', '5'), '',
  'the platform owner shortens the platform value to 5');
select is(pg_temp.edit_error('00000000-0000-4000-8000-000024870001', 'account_message', '00000000-0000-4000-8000-0000248700c1', 'fixed again'),
  'this message can no longer be edited', 'the personal message at 7 minutes is now refused');
select is((select body from public.account_messages where id = '00000000-0000-4000-8000-0000248700c1'), 'fixed 7', 'and the body is unchanged');
select is(pg_temp.edit_error('00000000-0000-4000-8000-000024870002', 'member_note', '00000000-0000-4000-8000-0000248700a1', 'still ok'), '',
  'the workspace note keeps the workspace''s own 20 minutes (14 minutes old)');

-- ── D: the bounds refuse a value, and the stored value is read back ────
select ok(pg_temp.write_error('00000000-0000-4000-8000-000024870003', null, 'messaging.edit_window_minutes', '0') like '%is refused%',
  'an edit window of 0 minutes is refused');
select ok(pg_temp.write_error('00000000-0000-4000-8000-000024870003', null, 'messaging.edit_window_minutes', '1441') like '%is refused%',
  'an edit window past one day is refused');
select ok(pg_temp.write_error('00000000-0000-4000-8000-000024870003', null, 'messaging.thread_poll_seconds', '4') like '%is refused%',
  'a conversation refresh faster than 5 seconds is refused');
select ok(pg_temp.write_error('00000000-0000-4000-8000-000024870003', null, 'messaging.inbox_poll_seconds', '9') like '%is refused%',
  'an inbox refresh faster than 10 seconds is refused');
select ok(pg_temp.write_error('00000000-0000-4000-8000-000024870003', null, 'messaging.inbox_poll_seconds', '601') like '%is refused%',
  'an inbox refresh slower than 600 seconds is refused');
select is(concat_ws('/', public.setting_value(null, 'messaging.edit_window_minutes'),
  public.setting_value(null, 'messaging.thread_poll_seconds'), public.setting_value(null, 'messaging.inbox_poll_seconds')),
  '5/15/30', 'the refusals left the stored values as they were');
select is(pg_temp.write_error('00000000-0000-4000-8000-000024870003', null, 'messaging.thread_poll_seconds', '60'), '',
  'a valid platform refresh interval is saved');

-- ── E: a member who is not an administrator is refused ─────────────────
select is(pg_temp.write_error('00000000-0000-4000-8000-000024870002', current_setting('t.ws')::uuid, 'messaging.edit_window_minutes', '1'),
  'not allowed to change this setting', 'a plain member cannot write the workspace value');
select is(pg_temp.write_error('00000000-0000-4000-8000-000024870002', null, 'messaging.edit_window_minutes', '1'),
  'platform owners only', 'a plain member cannot write the platform value');
select is((select count(*)::int from public.setting_values where key = 'messaging.edit_window_minutes' and valid_to is null), 2,
  'readback: no new current row exists beyond the workspace''s 20 and the platform''s 5');

select * from finish();
rollback;
