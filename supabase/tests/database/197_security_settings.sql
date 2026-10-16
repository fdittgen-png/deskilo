-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2485 / 0451 (S2 of #2483): the security and access limits are registry
-- settings with bounds that only tighten. Each scene first proves today's
-- behaviour at the default, then the changed value, then that a stored value
-- looser than the bound is held at the bound.
--   A the badge lockout (5 failures / 15 minutes) at the platform value
--   B every row refuses a value past its bound, through the one writer
--   C an invitation keeps the expiry it was created with
--   D the group creation limit and E the message-request limit
--   F the assistant confirmation expiry is the column default
begin;
select plan(32);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;

create function pg_temp.reasons(p_uid text, p_n int) returns text[] language plpgsql as $$
declare r text[] := '{}'; i int;
begin
  for i in 1 .. p_n loop
    r := r || (public.badge_auth_verify(p_uid, '0000') ->> 'reason');
  end loop;
  return r;
end;
$$;

create function pg_temp.refused(p_key text, p_value text) returns boolean language plpgsql as $$
begin
  perform public.set_setting(null, p_key, p_value::jsonb, '');
  return false;
exception when others then return sqlerrm like '%is refused%';
end;
$$;

create function pg_temp.limit_reached(p_group boolean, p_sender uuid, p_n int, p_to uuid[]) returns text
language plpgsql as $$
declare i int; v_msg text;
begin
  perform pg_temp.act_as(p_sender);
  for i in 1 .. p_n loop
    if p_group then
      perform public.create_account_group('G' || i, array[p_to[1]], p_sender);
    else
      perform public.send_account_message(p_to[i], 'hello', p_sender);
    end if;
  end loop;
  begin
    if p_group then
      perform public.create_account_group('G-over', array[p_to[1]], p_sender);
    else
      perform public.send_account_message(p_to[p_n + 1], 'hello', p_sender);
    end if;
    v_msg := 'no refusal';
  exception when others then v_msg := sqlerrm;
  end;
  reset role;
  return v_msg;
end;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select ('00000000-0000-4000-8000-00002485' || lpad(i::text, 4, '0'))::uuid,
       '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
       'u' || i || '@security-settings.test', '', now(), now(), now()
  from generate_series(1, 40) i;
-- 1 owner of the workspace, 2 platform owner, 3 and 4 group senders, 5 group
-- member, 6 and 7 message senders, 10..30 their possible recipients.
insert into public.platform_admins (user_id) values ('00000000-0000-4000-8000-000024850002');

-- ── A: the badge lockout ───────────────────────────────────────────────
select is((select count(*)::int from public.setting_definitions
            where key in ('security.badge_lockout_failures', 'security.badge_lockout_minutes')), 2,
  'the two lockout rows exist');
select is(public.setting_value(null, 'security.badge_lockout_failures')::text || '/' || public.setting_value(null, 'security.badge_lockout_minutes')::text,
  '5/15', 'the defaults are today''s 5 failures in 15 minutes');
select is(pg_temp.reasons('sec-a', 6), array['refused', 'refused', 'refused', 'refused', 'refused', 'locked'],
  'golden: five failures lock the sixth try');
select public.store_setting(null, 'security.badge_lockout_failures', '3'::jsonb, 'test', null);
select is(pg_temp.reasons('sec-b', 4), array['refused', 'refused', 'refused', 'locked'],
  'tightened to 3: the fourth try is locked, at once');
select public.store_setting(null, 'security.badge_lockout_failures', '9'::jsonb, 'test', null);
select is(public.setting_value(null, 'security.badge_lockout_failures')::text, '5',
  'a stored value looser than the bound is held at the bound');
select is(pg_temp.reasons('sec-c', 5), array['refused', 'refused', 'refused', 'refused', 'refused'], 'five failures are recorded');
update public.badge_auth_attempts set attempted_at = now() - interval '20 minutes'
 where token_hash = public.badge_token_hash('sec-c');
select is(pg_temp.reasons('sec-c', 1), array['refused'], 'failures older than the 15-minute window do not lock');
select public.store_setting(null, 'security.badge_lockout_minutes', '30'::jsonb, 'test', null);
select is(pg_temp.reasons('sec-c', 1), array['locked'], 'a 30-minute window counts them again, at once');
select public.store_setting(null, 'security.badge_lockout_minutes', '5'::jsonb, 'test', null);
select is(public.setting_value(null, 'security.badge_lockout_minutes')::text, '15', 'a window shorter than the bound is held at it');
select public.store_setting(null, 'security.badge_lockout_minutes', '15'::jsonb, 'test', null);
select public.store_setting(null, 'security.badge_lockout_failures', '5'::jsonb, 'test', null);

-- ── B: every row refuses a value past its bound ────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-000024850002');
select ok(pg_temp.refused('security.badge_lockout_failures', '6'), 'more badge failures than today is refused');
select ok(pg_temp.refused('security.badge_lockout_minutes', '10'), 'a shorter lockout than today is refused');
select ok(pg_temp.refused('security.invitation_expiry_days', '15'), 'a longer invitation than today is refused');
select ok(pg_temp.refused('mcp.confirmation_expiry_minutes', '6'), 'a longer confirmation than today is refused');
select ok(pg_temp.refused('mcp.probe_freshness_minutes', '16'), 'a staler probe than today is refused');
select ok(pg_temp.refused('messaging.group_creation_per_hour', '11'), 'more groups than today is refused');
select ok(pg_temp.refused('messaging.message_requests_per_day', '11'), 'more message requests than today is refused');
select is(public.set_setting(null, 'security.badge_lockout_failures', '4', 'tighten')->>'status', 'saved', 'tightening is saved');
select is(public.setting_value(null, 'security.badge_lockout_failures')::text, '4', 'and applies at once');
select public.set_setting(null, 'security.badge_lockout_failures', '5', 'restore');
reset role;

-- ── C: an invitation keeps the expiry it was created with ──────────────
select pg_temp.act_as('00000000-0000-4000-8000-000024850001');
select set_config('t.ws', public.create_workspace('Security settings', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select set_config('t.c1', public.create_invitation(current_setting('t.ws')::uuid, false, 'Ada', 'Lovelace'), true);
reset role;
select ok((select expires_at between now() + interval '14 days' - interval '1 minute' and now() + interval '14 days' + interval '1 minute'
             from public.invitations where code = current_setting('t.c1')),
  'golden: an invitation lasts 14 days');
update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"configurableSettings": true}'
 where id = current_setting('t.ws')::uuid;
select pg_temp.act_as('00000000-0000-4000-8000-000024850001');
select is(public.set_setting(current_setting('t.ws')::uuid, 'security.invitation_expiry_days', '7', 'tighten')->>'status', 'saved',
  'the workspace tightens the invitation lifetime');
select set_config('t.c2', public.create_invitation(current_setting('t.ws')::uuid, false, 'Grace', 'Hopper'), true);
reset role;
select ok((select expires_at between now() + interval '7 days' - interval '1 minute' and now() + interval '7 days' + interval '1 minute'
             from public.invitations where code = current_setting('t.c2')),
  'an invitation created after the change lasts 7 days');
select ok((select expires_at between now() + interval '14 days' - interval '1 minute' and now() + interval '14 days' + interval '1 minute'
             from public.invitations where code = current_setting('t.c1')),
  'the one created before keeps its own expiry');
select public.store_setting(current_setting('t.ws')::uuid, 'security.invitation_expiry_days', '30'::jsonb, 'test', null);
select is(public.setting_value(null, 'security.invitation_expiry_days')::text, '14', 'the platform value is the default');
select is((select public.setting_value(current_setting('t.ws')::uuid, 'security.invitation_expiry_days')::text), '14',
  'a workspace value looser than the bound is held at it');

-- ── D: group creation per hour ─────────────────────────────────────────
select pg_temp.act_as('00000000-0000-4000-8000-000024850005');
select public.set_visibility('reachability', 'signed_in');
reset role;
select is(pg_temp.limit_reached(true, '00000000-0000-4000-8000-000024850003', 10, array['00000000-0000-4000-8000-000024850005'::uuid]),
  'group limit reached', 'golden: ten groups an hour, the eleventh is refused with the same text');
select public.store_setting(null, 'messaging.group_creation_per_hour', '2'::jsonb, 'test', null);
select is(pg_temp.limit_reached(true, '00000000-0000-4000-8000-000024850004', 2, array['00000000-0000-4000-8000-000024850005'::uuid]),
  'group limit reached', 'tightened to 2: the third group is refused');
select public.store_setting(null, 'messaging.group_creation_per_hour', '10'::jsonb, 'test', null);

-- ── E: message requests per day ────────────────────────────────────────
select is(pg_temp.limit_reached(false, '00000000-0000-4000-8000-000024850006', 10,
    (select array_agg(('00000000-0000-4000-8000-00002485' || lpad(i::text, 4, '0'))::uuid order by i) from generate_series(11, 21) i)),
  'message limit reached', 'golden: ten requests a day, the eleventh is refused with the same text');
select public.store_setting(null, 'messaging.message_requests_per_day', '3'::jsonb, 'test', null);
select is(pg_temp.limit_reached(false, '00000000-0000-4000-8000-000024850007', 3,
    (select array_agg(('00000000-0000-4000-8000-00002485' || lpad(i::text, 4, '0'))::uuid order by i) from generate_series(11, 21) i)),
  'message limit reached', 'tightened to 3: the fourth request is refused');

-- ── F: the confirmation expiry is the column default ───────────────────
select ok((select pg_get_expr(d.adbin, d.adrelid) like '%mcp_confirmation_expires_at%'
             from pg_attrdef d join pg_attribute a on a.attrelid = d.adrelid and a.attnum = d.adnum
            where d.adrelid = 'public.mcp_action_confirmations'::regclass and a.attname = 'expires_at'),
  'a new confirmation''s expiry comes from the setting');
select ok(public.mcp_confirmation_expires_at() between now() + interval '5 minutes' - interval '1 minute' and now() + interval '5 minutes' + interval '1 minute',
  'golden: five minutes');
select public.store_setting(null, 'mcp.confirmation_expiry_minutes', '2'::jsonb, 'test', null);
select ok(public.mcp_confirmation_expires_at() between now() + interval '2 minutes' - interval '1 minute' and now() + interval '2 minutes' + interval '1 minute',
  'tightened to 2 minutes, at once');
select public.store_setting(null, 'mcp.confirmation_expiry_minutes', '9'::jsonb, 'test', null);
select ok(public.mcp_confirmation_expires_at() between now() + interval '5 minutes' - interval '1 minute' and now() + interval '5 minutes' + interval '1 minute',
  'a stored value looser than the bound is held at five minutes');

select * from finish();
rollback;
