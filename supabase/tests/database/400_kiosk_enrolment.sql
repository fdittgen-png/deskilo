-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3675 (GHSA-9525-vh85-5hjg, step b): a business enrols its kiosks and
-- decides where badge sign-in works. The credential is answered once and
-- only its hash is kept; owners are told of every enrolment and revocation;
-- a device counts only when enrolled, unrevoked, with its own credential,
-- of the tag's business and with kiosk enrolment on -- anything else is
-- exactly no device. On a valid kiosk the scan names the person and a
-- paused business answers "locked" for every tag; without one, no answer
-- tells a tag of a business from an unknown tag. Rolled back.
begin;
select plan(34);

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00004000' || lpad(n::text,4,'0'))::uuid;
$$;
insert into auth.users (id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select pg_temp.u(i),'00000000-0000-0000-0000-000000000000','authenticated','authenticated',
  'kiosk-enrol-'||i||'@example.test','',now(),now(),now() from generate_series(1,6) i;
update public.profiles set display_name = 'Ana Martin' where id = pg_temp.u(2);
update public.profiles set display_name = 'Bo Lind' where id = pg_temp.u(5);
-- A and B enrol kiosks; C has kiosk enrolment off.
insert into public.workspaces (id,name,country_code,currency_code,timezone,created_by,feature_flags) values
 (pg_temp.u(101),'Kiosk A','FR','EUR','Europe/Paris',pg_temp.u(1),'{"kioskMode":true,"nfcBadges":true,"badgeSignIn":true,"kioskEnrolment":true}'),
 (pg_temp.u(102),'Kiosk B','FR','EUR','Europe/Paris',pg_temp.u(4),'{"kioskMode":true,"nfcBadges":true,"badgeSignIn":true,"kioskEnrolment":true}'),
 (pg_temp.u(103),'Kiosk C','FR','EUR','Europe/Paris',pg_temp.u(6),'{"kioskMode":true,"nfcBadges":true,"badgeSignIn":true,"kioskEnrolment":false}');
insert into public.members (id,workspace_id,user_id,is_owner,is_admin,status) values
 (pg_temp.u(201),pg_temp.u(101),pg_temp.u(1),true,true,'active'),
 (pg_temp.u(202),pg_temp.u(101),pg_temp.u(2),false,false,'active'),
 (pg_temp.u(203),pg_temp.u(101),pg_temp.u(3),false,false,'active'),
 (pg_temp.u(204),pg_temp.u(102),pg_temp.u(4),true,true,'active'),
 (pg_temp.u(205),pg_temp.u(102),pg_temp.u(5),false,false,'active'),
 (pg_temp.u(206),pg_temp.u(103),pg_temp.u(6),true,true,'active');
insert into public.member_badges (id,workspace_id,member_id,token_hash,auth_enabled) values
 (pg_temp.u(302),pg_temp.u(101),pg_temp.u(202),public.badge_token_hash('4000000000000002'),true),
 (pg_temp.u(303),pg_temp.u(101),pg_temp.u(203),public.badge_token_hash('4000000000000003'),true),
 (pg_temp.u(305),pg_temp.u(102),pg_temp.u(205),public.badge_token_hash('4000000000000005'),true),
 (pg_temp.u(306),pg_temp.u(103),pg_temp.u(206),public.badge_token_hash('4000000000000006'),true);
insert into public.account_badge_pins(user_id,pin_hash)
select pg_temp.u(i),extensions.crypt('482615',extensions.gen_salt('bf',10)) from generate_series(2,6) i;

create function pg_temp.as_user(p_user uuid, p_sql text, p_delegated boolean default false)
returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims', (case when p_delegated
    then json_build_object('sub', p_user, 'role', 'authenticated', 'client_id', 'delegated')
    else json_build_object('sub', p_user, 'role', 'authenticated') end)::text, true);
  set local role authenticated;
  execute p_sql into v;
  reset role;
  -- Back to the badge function's own caller: the service role, nobody's
  -- session.
  perform set_config('request.jwt.claims', '', true);
  return v;
exception when others then
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return 'ERROR: ' || sqlerrm;
end
$f$;
-- Enrols a device of business p_ws as p_user; keeps its id and credential.
create function pg_temp.enrol(p_user int, p_ws int, p_name text, p_as text) returns text language plpgsql as $f$
declare v text;
begin
  v := pg_temp.as_user(pg_temp.u(p_user), format(
    'select public.enrol_kiosk_device_v1(%L, %L)::text', pg_temp.u(p_ws), p_name));
  if v not like 'ERROR%' then
    perform set_config('k.' || p_as || '.id', v::jsonb ->> 'device_id', false);
    perform set_config('k.' || p_as || '.secret', v::jsonb ->> 'credential', false);
  end if;
  return v;
end
$f$;
create function pg_temp.verify(p_uid text, p_pin text, p_as text default null, p_secret text default null)
returns jsonb language sql as $f$
  select public.badge_auth_verify(p_uid, p_pin, '198.51.100.40',
    case when p_as is null then null else current_setting('k.' || p_as || '.id')::uuid end,
    case when p_as is null then null else coalesce(p_secret, current_setting('k.' || p_as || '.secret')) end)
$f$;

-- ── enrolment ──────────────────────────────────────────────────────
select ok(pg_temp.enrol(1, 101, 'Front desk', 'a') ~ '"credential": "[0-9a-f]{64}"', 'the owner enrols a device: its credential, once');
select ok((select secret_hash <> current_setting('k.a.secret') and secret_hash = encode(extensions.digest(current_setting('k.a.secret'),'sha256'),'hex')
             from public.kiosk_devices where id = current_setting('k.a.id')::uuid),
  'the server keeps only the credential''s hash');
select is((select count(*)::int from public.events where workspace_id = pg_temp.u(101) and type = 'kiosk_device'
            and payload ->> 'change' = 'enrolled' and payload ->> 'device_name' = 'Front desk'), 1,
  'the owner is told, with the device''s name');
select is(pg_temp.enrol(3, 101, 'Back door', 'x'), 'ERROR: not allowed', 'a member without the kiosk permission may not enrol');
select is(pg_temp.as_user(pg_temp.u(1), format('select public.enrol_kiosk_device_v1(%L, %L)::text', pg_temp.u(101), 'Bot'), true),
  'ERROR: not allowed', 'nor an assistant''s delegated session');
select is(pg_temp.enrol(6, 103, 'Desk', 'c'), 'ERROR: kiosk enrolment is off', 'nor a business with kiosk enrolment off');
select is(pg_temp.enrol(1, 101, '   ', 'x'), 'ERROR: a name of 1 to 80 characters is required', 'a device has a name');
select ok(pg_temp.enrol(4, 102, 'Lobby', 'b') like '{%', 'business B enrols its own kiosk');
create function pg_temp.list(p_user int, p_ws int) returns text language sql as $f$
  select pg_temp.as_user(pg_temp.u(p_user), format('select public.kiosk_devices_v1(%L)::text', pg_temp.u(p_ws)))
$f$;
select is(case when pg_temp.list(1, 101) like 'ERROR%' then pg_temp.list(1, 101)
               when (pg_temp.list(1, 101)::jsonb -> 0) ?& array['name','enrolled_by','enrolled_at','last_used_at','revoked_at']
                and not ((pg_temp.list(1, 101)::jsonb -> 0) ? 'secret_hash') then 'named, no hash'
               else pg_temp.list(1, 101) end,
  'named, no hash', 'the list names each device, who enrolled it and when, never its hash');
select is(pg_temp.as_user(pg_temp.u(2), format('select public.kiosk_devices_v1(%L)::text', pg_temp.u(101))), 'ERROR: not allowed',
  'a member without the kiosk permission does not see the list');

-- ── the scan ───────────────────────────────────────────────────────
select is(pg_temp.verify('4000000000000002', null, 'a') ->> 'display_name', 'Ana Martin', 'on its business''s kiosk the scan names the person');
select is(pg_temp.verify('4000000000000002', null), '{"ok": true}'::jsonb, 'without a device it names nobody');
select is(pg_temp.verify('4000000000000005', null, 'a'), '{"ok": true}'::jsonb, 'a kiosk of A names nobody of B');
select is(pg_temp.verify('4000000000000002', null, 'a', repeat('f', 64)), '{"ok": true}'::jsonb, 'a wrong credential is no device');
select is(pg_temp.verify('4000999999999999', null, 'a'), '{"ok": true}'::jsonb, 'an unknown tag on a kiosk: the same answer, no name');

-- ── where badge sign-in works ──────────────────────────────────────
select is(pg_temp.verify('4000000000000002', '482615') ->> 'reason', 'refused', 'enrolled kiosks only (the default): off a kiosk the right PIN is refused');
select is((select count(*)::int from public.badge_auth_attempts where token_hash = public.badge_token_hash('4000000000000002')
            and step = 'pin' and not succeeded and workspace_id is null), 1,
  'and counted as an unknown tag''s, never against the business');
select is(pg_temp.verify('4000000000000002', '482615', 'b') ->> 'reason', 'refused', 'a kiosk of another business is no kiosk for it');
select is(pg_temp.verify('4000000000000002', '482615', 'a') ->> 'display_name', 'Ana Martin', 'on its own kiosk the right PIN signs in');
select ok((select last_used_at is not null from public.kiosk_devices where id = current_setting('k.a.id')::uuid), 'and the kiosk''s last use is noted');
select public.store_setting(pg_temp.u(101), 'security.badge_signin_where', '"any_device"'::jsonb, 'test', null);
select is(pg_temp.verify('4000000000000003', '482615') ->> 'ok', 'true', 'any device: the right PIN signs in anywhere');
select is(pg_temp.verify('4000000000000006', '482615') ->> 'ok', 'true', 'with kiosk enrolment off the setting is not in force: any device, as before');

-- ── revocation ─────────────────────────────────────────────────────
select is(pg_temp.as_user(pg_temp.u(2), format('select public.revoke_kiosk_device_v1(%L)::text', current_setting('k.b.id'))),
  'ERROR: unknown device', 'a device of another business, or without the permission: unknown');
select is(pg_temp.as_user(pg_temp.u(4), format('select public.revoke_kiosk_device_v1(%L)::text', current_setting('k.b.id'))), 'true',
  'B''s owner revokes its kiosk');
select is(pg_temp.as_user(pg_temp.u(4), format('select public.revoke_kiosk_device_v1(%L)::text', current_setting('k.b.id'))), 'false',
  'a second revocation changes nothing');
select is((select count(*)::int from public.events where workspace_id = pg_temp.u(102) and type = 'kiosk_device' and payload ->> 'change' = 'revoked'), 1,
  'the owners are told of the revocation');
select is(pg_temp.verify('4000000000000005', null, 'b'), '{"ok": true}'::jsonb, 'a revoked kiosk names nobody: it is no device');
select is(pg_temp.verify('4000000000000005', '482615', 'b') ->> 'reason', 'refused', 'and signs nobody in where kiosks are required');

-- ── the pause ──────────────────────────────────────────────────────
select public.store_setting(pg_temp.u(101), 'security.badge_signin_where', '"enrolled_kiosks"'::jsonb, 'test', null);
select public.store_setting(pg_temp.u(101), 'security.badge_workspace_failure_limit', '2'::jsonb, 'test', null);
select pg_temp.verify('4000000000000002', '000000', 'a');
select pg_temp.verify('4000000000000003', '000000', 'a');
select is(pg_temp.verify('4000888888888888', null, 'a') ->> 'reason', 'locked', 'a paused business: on its kiosk every tag waits, an unknown one too');
select is(pg_temp.verify('4000000000000003', '482615', 'a') ->> 'reason', 'locked', 'and a right PIN waits too');
select is(pg_temp.verify('4000000000000003', '482615') ->> 'reason', pg_temp.verify('4000777777777777', '482615') ->> 'reason',
  'off a kiosk, a paused business''s tag answers as an unknown tag');

-- ── one bcrypt for every PIN attempt ───────────────────────────────
-- Counted at the real crypt call inside this rolled-back transaction (as
-- pgTAP 320 does): a refusal off a kiosk, a revoked device and a foreign
-- one cost the same as any attempt.
create function pg_temp.counted_crypt(text,text) returns text language plpgsql as $$
begin
  perform set_config('t.crypt_calls',(coalesce(nullif(current_setting('t.crypt_calls',true),''),'0')::int+1)::text,true);
  return extensions.crypt($1,$2);
end;
$$;
do $instrument$
declare v_def text;
begin
  select pg_get_functiondef('public.badge_auth_verify(text,text,text,uuid,text)'::regprocedure) into v_def;
  execute replace(v_def,'extensions.crypt(','pg_temp.counted_crypt(');
end;
$instrument$;
create function pg_temp.crypts(p_uid text, p_as text default null) returns int language plpgsql as $f$
begin
  perform set_config('t.crypt_calls','0',true);
  perform pg_temp.verify(p_uid, '482615', p_as);
  return current_setting('t.crypt_calls')::int;
end
$f$;
select is(pg_temp.crypts('4000000000000005') || '|' || pg_temp.crypts('4000000000000005', 'b') || '|' || pg_temp.crypts('4000000000000005', 'a'),
  '1|1|1', 'off a kiosk, on a revoked one and on a foreign one: one bcrypt each, as any attempt');

-- ── nobody else ────────────────────────────────────────────────────
select ok(not has_function_privilege('authenticated', 'public.badge_auth_verify(text, text, text, uuid, text)', 'execute')
      and not has_function_privilege('anon', 'public.badge_auth_verify(text, text, text, uuid, text)', 'execute')
      and not has_function_privilege('authenticated', 'public.kiosk_device_business(uuid, text)', 'execute')
      and not has_table_privilege('authenticated', 'public.kiosk_devices', 'select')
      and not has_table_privilege('anon', 'public.kiosk_devices', 'select'),
  'no client verifies a badge, checks a device or reads the devices');
select ok(public.same_sha256_hex(repeat('a', 64), repeat('a', 64)) and not public.same_sha256_hex(repeat('a', 64), repeat('a', 63) || 'b')
      and not public.same_sha256_hex('nonsense', repeat('a', 64)),
  'the digest comparison: equal, different, malformed');

select * from finish();
rollback;
