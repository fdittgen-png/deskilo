-- SPDX-License-Identifier: AGPL-3.0-or-later
-- GHSA-9525-vh85-5hjg: the scan step names nobody and answers the same for
-- a real, an unknown and a revoked tag; it is counted per tag and per
-- source and answers "locked" past either ceiling; the person is named once
-- the PIN is right; one badge failing again and again cannot pause badge
-- sign-in for the whole business, while several different badges do.
begin;
select plan(12);

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00003840' || lpad(n::text,4,'0'))::uuid;
$$;
insert into auth.users (id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select pg_temp.u(i),'00000000-0000-0000-0000-000000000000','authenticated','authenticated',
  'badge-identify-'||i||'@example.test','',now(),now(),now() from generate_series(1,3) i;
update public.profiles set display_name = 'Badge Holder' where id = pg_temp.u(1);
insert into public.workspaces (id,name,country_code,currency_code,timezone,created_by,feature_flags)
values (pg_temp.u(101),'Badge identify','FR','EUR','Europe/Paris',pg_temp.u(1),'{"kioskMode":true,"nfcBadges":true,"badgeSignIn":true}');
insert into public.members (id,workspace_id,user_id,is_owner,is_admin,status)
values (pg_temp.u(201),pg_temp.u(101),pg_temp.u(1),true,true,'active'),
       (pg_temp.u(202),pg_temp.u(101),pg_temp.u(2),false,false,'active'),
       (pg_temp.u(203),pg_temp.u(101),pg_temp.u(3),false,false,'active');
insert into public.member_badges (id,workspace_id,member_id,token_hash,auth_enabled,revoked_at)
values (pg_temp.u(301),pg_temp.u(101),pg_temp.u(201),public.badge_token_hash('3840000000000001'),true,null),
       (pg_temp.u(302),pg_temp.u(101),pg_temp.u(202),public.badge_token_hash('3840000000000002'),true,null),
       (pg_temp.u(303),pg_temp.u(101),pg_temp.u(203),public.badge_token_hash('3840000000000003'),true,now());
insert into public.account_badge_pins(user_id,pin_hash)
select pg_temp.u(i),extensions.crypt('482615',extensions.gen_salt('bf',10)) from generate_series(1,3) i;
select public.store_setting(pg_temp.u(101),'security.badge_workspace_failure_limit','2'::jsonb,'test',null);

-- ── the scan names nobody ──────────────────────────────────────────
select is(public.badge_auth_verify('3840000000000001',null,'198.51.100.1'),'{"ok": true}'::jsonb,'a real tag: the scan names nobody');
select is(public.badge_auth_verify('3840999999999999',null,'198.51.100.1'),public.badge_auth_verify('3840000000000001',null,'198.51.100.1'),'an unknown tag answers the same');
select is(public.badge_auth_verify('3840000000000003',null,'198.51.100.1'),public.badge_auth_verify('3840000000000001',null,'198.51.100.1'),'a revoked tag answers the same');
select is((select count(*)::int from public.badge_auth_attempts where step='identify' and source_hash=public.badge_token_hash('198.51.100.1')),5,'every scan is counted, by its source too');
select is((select count(*)::int from public.badge_auth_attempts where source_hash is not null and source_hash = '198.51.100.1'),0,'the source is kept only as a hash');

-- ── the PIN names the person ───────────────────────────────────────
select is(public.badge_auth_verify('3840000000000001','482615')->>'display_name','Badge Holder','the right PIN names the person');

-- ── per tag and per source ─────────────────────────────────────────
-- The platform defaults: 10 scans of one tag, 30 from one source.
delete from public.badge_auth_attempts where step='identify';
select public.badge_auth_verify('3840000000000002',null,'203.0.113.'||i) from generate_series(1,10) i;
select is(public.badge_auth_verify('3840000000000002',null,'203.0.113.9')->>'reason','locked','past its ceiling, one tag is told to wait');
select is(public.badge_auth_verify('3840000000000001',null,'203.0.113.9'),'{"ok": true}'::jsonb,'another tag is not');
select public.badge_auth_verify('38400000000001'||lpad(i::text,2,'0'),null,'192.0.2.7') from generate_series(10,39) i;
select is(public.badge_auth_verify('3840000000000099',null,'192.0.2.7')->>'reason','locked','past its ceiling, one source is told to wait');

-- ── one badge cannot pause the business ────────────────────────────
select public.badge_auth_verify('3840000000000001','000000') from generate_series(1,4);
select is(public.badge_auth_verify('3840000000000002','482615')->>'ok','true','one badge failing again and again leaves the others usable');
select is((select count(*)::int from public.events where workspace_id=pg_temp.u(101) and type='badge_security_alert'),0,'and alerts nobody');
select public.badge_auth_verify('3840000000000002','000000');
select is(public.badge_auth_verify('3840000000000002','482615')->>'reason','locked','two different badges failing reach the business ceiling');

select * from finish();
rollback;
