-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3902 (0756): workspace pairing, badge sign-in and e-invoice credentials.
-- The pair, environment and creator of a workspace are set by the server;
-- a member joins the twin only when both sides share an owner. A badge opens
-- its own workspace, and an account that owns or administers another one signs
-- in with its password. At a kiosk the kiosk's own badge is found first. An
-- e-invoice connection moved to another host keeps no secret it was not sent
-- with. A new online payment opens only while online payments are on.
-- Rolled back.
begin;
select plan(18);

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00003902' || lpad(n::text, 4, '0'))::uuid;
$$;
insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select pg_temp.u(i), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
  'hardening-' || i || '@example.test', '', now(), now(), now() from generate_series(1, 12) i;

create function pg_temp.as_user(p_user uuid, p_sql text) returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  set local role authenticated;
  execute p_sql into v;
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return coalesce(v, 'ok');
exception when others then
  reset role;
  perform set_config('request.jwt.claims', '', true);
  return 'ERROR ' || sqlstate || ' ' || sqlerrm;
end
$f$;
grant execute on all functions in schema pg_temp to authenticated;

-- ── 1. the pair of a workspace ──────────────────────────────────────
-- X (user 1) creates a pair; Y (user 2) has a single workspace A.
select set_config('t.x', pg_temp.as_user(pg_temp.u(1), format(
  'select public.create_workspace_once(%L, %L, %L, %L, %L, %L, true, null, null)::text',
  pg_temp.u(901), 'Pair X', 'FR', 'EUR', 'Europe/Paris', 'dev')), true);
select set_config('t.pair', (select pair_id::text from public.workspaces where id = current_setting('t.x')::uuid), true);
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by)
values (pg_temp.u(101), 'Single A', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(2));
insert into public.members (workspace_id, user_id, is_owner, is_admin, status)
values (pg_temp.u(101), pg_temp.u(2), true, true, 'active');

select is((select count(*)::int from public.workspaces where pair_id = current_setting('t.pair')::uuid), 2,
  'the owner of a pair holds two workspaces');

-- A member added on one side of a genuine pair is on the other side too.
insert into public.members (workspace_id, user_id, is_owner, is_admin, status)
values (current_setting('t.x')::uuid, pg_temp.u(3), false, false, 'active');
select is((select count(*)::int from public.members m join public.workspaces w on w.id = m.workspace_id
            where w.pair_id = current_setting('t.pair')::uuid and m.user_id = pg_temp.u(3)), 2,
  'a member of one side of a pair is a member of its twin');

select ok(pg_temp.as_user(pg_temp.u(2), format(
  'update public.workspaces set pair_id = %L where id = %L', current_setting('t.pair'), pg_temp.u(101)))
  like 'ERROR 42501%', 'a member cannot change a workspace''s pair');
select ok(pg_temp.as_user(pg_temp.u(2), format(
  'update public.workspaces set environment = ''prod'' where id = %L', pg_temp.u(101)))
  like 'ERROR 42501%', 'a member cannot change a workspace''s environment');
select ok(pg_temp.as_user(pg_temp.u(2), format(
  'update public.workspaces set created_by = %L where id = %L', pg_temp.u(1), pg_temp.u(101)))
  like 'ERROR 42501%', 'a member cannot change a workspace''s creator');
select ok(pg_temp.as_user(pg_temp.u(1), format(
  'select public.set_workspace_environment(%L, %L)::text', current_setting('t.x'), 'dev'))
  not like '%set by the server%', 'the server''s own environment change still runs');

-- A workspace whose pair it shares no owner with gets no member mirrored there.
update public.workspaces set pair_id = current_setting('t.pair')::uuid where id = pg_temp.u(101);
insert into public.members (workspace_id, user_id, is_owner, is_admin, co_owner, status)
values (pg_temp.u(101), pg_temp.u(4), false, true, 'active', 'active');
select is((select count(*)::int from public.members m join public.workspaces w on w.id = m.workspace_id
            where w.pair_id = current_setting('t.pair')::uuid and w.id <> pg_temp.u(101)
              and m.user_id = pg_temp.u(4)), 0,
  'a member joins the twin only when both sides share an owner');

-- ── 2. a badge opens its own workspace ──────────────────────────────
-- W1 (owner 5): plain members 6 and 7 with badges. 6 also owns W2. 7 is an
-- administrator of W1's twin (W1t).
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags, pair_id) values
 (pg_temp.u(111), 'Badge W1', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(5), '{"kioskMode":true,"nfcBadges":true,"badgeSignIn":true,"kioskEnrolment":false}', pg_temp.u(911)),
 (pg_temp.u(112), 'Badge W2', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(6), '{}', null),
 (pg_temp.u(113), 'Badge W1 twin', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(5), '{}', pg_temp.u(911));
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
 (pg_temp.u(211), pg_temp.u(111), pg_temp.u(5), true, true, 'active'),
 (pg_temp.u(212), pg_temp.u(111), pg_temp.u(6), false, false, 'active'),
 (pg_temp.u(213), pg_temp.u(111), pg_temp.u(7), false, false, 'active'),
 (pg_temp.u(214), pg_temp.u(112), pg_temp.u(6), true, true, 'active');
-- 7 administers the twin (with the mirror's own rule, the row is set here).
insert into public.members (workspace_id, user_id, is_owner, is_admin, status)
select pg_temp.u(113), pg_temp.u(7), false, true, 'active'
 where not exists (select 1 from public.members where workspace_id = pg_temp.u(113) and user_id = pg_temp.u(7));
update public.members set is_admin = true where workspace_id = pg_temp.u(113) and user_id = pg_temp.u(7);
insert into public.member_badges (workspace_id, member_id, token_hash, auth_enabled) values
 (pg_temp.u(111), pg_temp.u(212), public.badge_token_hash('3902000000000006'), true),
 (pg_temp.u(111), pg_temp.u(213), public.badge_token_hash('3902000000000007'), true);
insert into public.account_badge_pins (user_id, pin_hash)
select pg_temp.u(i), extensions.crypt('482615', extensions.gen_salt('bf', 10)) from generate_series(5, 12) i
on conflict (user_id) do nothing;

select is(public.badge_auth_verify('3902000000000006', '482615', '198.51.100.41', null, null) ->> 'ok', 'false',
  'an account that owns another workspace signs in with its password, not the badge');
-- 6 hands W2 to another owner and stays there as a plain member.
insert into public.members (workspace_id, user_id, is_owner, is_admin, status)
values (pg_temp.u(112), pg_temp.u(5), true, true, 'active');
update public.members set is_owner = false, is_admin = false where id = pg_temp.u(214);
select is(public.badge_auth_verify('3902000000000006', '482615', '198.51.100.41', null, null) ->> 'ok', 'true',
  'the same account, a plain member of its other workspace, signs in with its badge');
select is(public.badge_auth_verify('3902000000000007', '482615', '198.51.100.41', null, null) ->> 'ok', 'true',
  'administering the twin of the badge''s own workspace does not stop it');

-- ── 3. at a kiosk, its own workspace's badge first ──────────────────
-- The same tag, armed first in W4 (member 8), then in W3 (member 9); W3 has
-- an enrolled kiosk.
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags) values
 (pg_temp.u(121), 'Kiosk W3', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(10),
  '{"kioskMode":true,"nfcBadges":true,"badgeSignIn":true,"kioskEnrolment":true}'),
 (pg_temp.u(122), 'Other W4', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(11), '{"kioskMode":true,"nfcBadges":true,"badgeSignIn":true,"kioskEnrolment":false}');
insert into public.members (id, workspace_id, user_id, is_owner, is_admin, status) values
 (pg_temp.u(221), pg_temp.u(121), pg_temp.u(10), true, true, 'active'),
 (pg_temp.u(222), pg_temp.u(121), pg_temp.u(9), false, false, 'active'),
 (pg_temp.u(223), pg_temp.u(122), pg_temp.u(11), true, true, 'active'),
 (pg_temp.u(224), pg_temp.u(122), pg_temp.u(8), false, false, 'active');
insert into public.member_badges (workspace_id, member_id, token_hash, auth_enabled, created_at) values
 (pg_temp.u(122), pg_temp.u(224), public.badge_token_hash('3902000000000099'), true, now() - interval '1 day'),
 (pg_temp.u(121), pg_temp.u(222), public.badge_token_hash('3902000000000099'), true, now());
select set_config('t.kiosk', pg_temp.as_user(pg_temp.u(10), format(
  'select public.enrol_kiosk_device_v1(%L, %L)::text', pg_temp.u(121), 'Front desk')), true);
select is(public.badge_auth_verify('3902000000000099', '482615', '198.51.100.42',
            (current_setting('t.kiosk')::jsonb ->> 'device_id')::uuid,
            current_setting('t.kiosk')::jsonb ->> 'credential') ->> 'user_id',
  pg_temp.u(9)::text,
  'at a kiosk, a tag armed in several workspaces opens the kiosk''s own');

-- ── 4. e-invoice credentials ────────────────────────────────────────
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by)
values (pg_temp.u(131), 'E-invoice W5', 'FR', 'EUR', 'Europe/Paris', pg_temp.u(12));
insert into public.members (workspace_id, user_id, is_owner, is_admin, status)
values (pg_temp.u(131), pg_temp.u(12), true, true, 'active');
create function pg_temp.creds(p_config jsonb) returns text language sql as $f$
  select pg_temp.as_user(pg_temp.u(12), format(
    'select public.set_einvoice_credentials(%L, %L)::text', pg_temp.u(131), p_config));
$f$;
create function pg_temp.has_secret(p_key text) returns boolean language sql as $f$
  select (select config ? p_key from public.einvoice_credentials where workspace_id = pg_temp.u(131))
     and exists (select 1 from vault.secrets where name = public.einvoice_secret_name(pg_temp.u(131), p_key));
$f$;
select pg_temp.creds('{"endpoint": "https://one.example.test", "api_key": "first"}');
select ok(pg_temp.has_secret('api_key'), 'a secret is stored with its connection');
select pg_temp.creds('{"scope": "invoices"}');
select ok(pg_temp.has_secret('api_key'), 'a change of another field keeps the secret');
select pg_temp.creds('{"endpoint": "https://two.example.test"}');
select ok(not pg_temp.has_secret('api_key')
      and not exists (select 1 from vault.secrets where name = public.einvoice_secret_name(pg_temp.u(131), 'api_key')),
  'a connection moved to another host keeps no secret it was not sent with');
select pg_temp.creds('{"endpoint": "https://three.example.test", "api_key": "second"}');
select ok(pg_temp.has_secret('api_key'), 'a secret sent with the move is stored');
select pg_temp.creds('{"base_url_uat": "https://uat.example.test", "client_secret_uat": "uat"}');
select pg_temp.creds('{"base_url_uat": "https://uat2.example.test"}');
select ok(not pg_temp.has_secret('client_secret_uat') and not pg_temp.has_secret('api_key'),
  'the test host''s address counts as a host too');

-- ── 5. online payments ──────────────────────────────────────────────
update public.workspaces set feature_flags = '{"onlinePayments": false}' where id = pg_temp.u(131);
select ok(pg_temp.as_user(pg_temp.u(12), format(
  'select (public.open_payment_intent(%L, (select id from public.members where workspace_id = %L and user_id = %L), %L, %L, 1000, %L)).id::text',
  pg_temp.u(131), pg_temp.u(131), pg_temp.u(12), 'stripe', '2026-11', 'EUR')) like 'ERROR%online payments are off%',
  'no new online payment opens while online payments are off');
update public.workspaces set feature_flags = '{"onlinePayments": true}' where id = pg_temp.u(131);
select ok(pg_temp.as_user(pg_temp.u(12), format(
  'select (public.open_payment_intent(%L, (select id from public.members where workspace_id = %L and user_id = %L), %L, %L, 1000, %L)).id::text',
  pg_temp.u(131), pg_temp.u(131), pg_temp.u(12), 'stripe', '2026-11', 'EUR')) not like 'ERROR%',
  'a new online payment opens while they are on');

select * from finish();
rollback;
