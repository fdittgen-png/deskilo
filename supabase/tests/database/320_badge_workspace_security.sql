-- SPDX-License-Identifier: AGPL-3.0-or-later
-- A distributed badge attack stops at the workspace ceiling, alerts its owners
-- once, and leaves other workspaces usable. Every PIN refusal does one crypt;
-- only badge administrators see a PIN-review notice, never credential material.
begin;
select plan(26);

create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00003091' || lpad(n::text,4,'0'))::uuid;
$$;
create function pg_temp.act_as(n int) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',jsonb_build_object(
    'sub',pg_temp.u(n),'role','authenticated','aal','aal2')::text,true);
  execute 'set local role authenticated';
end;
$$;
grant execute on all functions in schema pg_temp to authenticated,anon;

insert into auth.users (id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select pg_temp.u(i),'00000000-0000-0000-0000-000000000000','authenticated','authenticated',
  'badge-security-'||i||'@example.test','',now(),now(),now() from generate_series(1,4) i;
insert into public.workspaces (id,name,country_code,currency_code,timezone,created_by,feature_flags)
values (pg_temp.u(101),'Badge security A','FR','EUR','Europe/Paris',pg_temp.u(1),'{"kioskMode":true,"nfcBadges":true,"badgeSignIn":true}'),
       (pg_temp.u(102),'Badge security B','FR','EUR','Europe/Paris',pg_temp.u(4),'{"kioskMode":true,"nfcBadges":true,"badgeSignIn":true}');
insert into public.members (id,workspace_id,user_id,is_owner,is_admin,status)
values (pg_temp.u(201),pg_temp.u(101),pg_temp.u(1),true,true,'active'),
       (pg_temp.u(202),pg_temp.u(101),pg_temp.u(2),false,false,'active'),
       (pg_temp.u(203),pg_temp.u(101),pg_temp.u(3),false,false,'exited'),
       (pg_temp.u(204),pg_temp.u(102),pg_temp.u(4),true,true,'active');
insert into public.member_badges (id,workspace_id,member_id,token_hash,auth_enabled)
values (pg_temp.u(301),pg_temp.u(101),pg_temp.u(201),public.badge_token_hash('3091000000000001'),true),
       (pg_temp.u(302),pg_temp.u(101),pg_temp.u(202),public.badge_token_hash('3091000000000002'),true),
       (pg_temp.u(303),pg_temp.u(101),pg_temp.u(203),public.badge_token_hash('3091000000000003'),true),
       (pg_temp.u(304),pg_temp.u(102),pg_temp.u(204),public.badge_token_hash('3091000000000004'),true);
insert into public.account_badge_pins(user_id,pin_hash)
select pg_temp.u(i),extensions.crypt('482615',extensions.gen_salt('bf',10)) from generate_series(1,4) i;
select public.store_setting(pg_temp.u(101),'security.badge_workspace_failure_limit','2'::jsonb,'test',null);
-- END FIXTURE

select is(public.badge_auth_verify('3091000000000001','000000')->>'reason','refused','first badge failure is refused');
select is(public.badge_auth_verify('3091000000000002','000000')->>'reason','refused','second badge reaches the workspace ceiling');
select is(public.badge_auth_verify('3091000000000001','482615')->>'reason','locked','the workspace ceiling refuses a correct PIN on another badge');
select is((select count(*)::int from public.events where workspace_id=pg_temp.u(101) and type='badge_security_alert'),1,'the ceiling emits one owner alert');
select public.badge_auth_verify('3091000000000002','482615');
select is((select count(*)::int from public.events where workspace_id=pg_temp.u(101) and type='badge_security_alert'),1,'locked retries do not duplicate the alert');
select is(public.badge_auth_verify('3091000000000004','482615')->>'ok','true','a different workspace remains usable');
update public.badge_auth_attempts set attempted_at=now()-interval '25 hours' where workspace_id=pg_temp.u(101);
select is(public.badge_auth_verify('3091000000000001','482615')->>'ok','true','the workspace recovers after the failure window');

select pg_temp.act_as(1);
select is((select count(*)::int from public.events where workspace_id=pg_temp.u(101) and type='badge_security_alert'),1,'the owner reads their alert through RLS');
select ok(public.badge_pin_needs_review(pg_temp.u(101),pg_temp.u(202)),'an old PIN of unknown length needs review');
reset role;
select pg_temp.act_as(2);
select throws_ok($$select public.badge_pin_needs_review(pg_temp.u(101),pg_temp.u(201))$$,'P0001','not allowed','a plain member cannot inspect another account PIN');
select is((select count(*)::int from public.events where workspace_id=pg_temp.u(101) and type='badge_security_alert'),0,'a plain member does not read the owner alert');
select public.set_badge_pin('482615');
reset role;
select is((select pin_length::int from public.account_badge_pins where user_id=pg_temp.u(2)),6,'new PINs record their length without exposing the hash');
select pg_temp.act_as(1);
select is(public.badge_pin_needs_review(pg_temp.u(101),pg_temp.u(202)),false,'the notice clears after a compliant PIN change');
reset role;

select set_config('request.jwt.claims','{"role":"service_role"}',true);

-- Instrument the real crypt boundary inside this rolled-back transaction,
-- rather than compare noisy wall-clock timings on a shared runner.
alter function extensions.crypt(text,text) rename to crypt_3091_actual;
create function extensions.crypt(text,text) returns text language plpgsql as $$
begin
  perform set_config('t.crypt_calls',(coalesce(nullif(current_setting('t.crypt_calls',true),''),'0')::int+1)::text,true);
  return extensions.crypt_3091_actual($1,$2);
end;
$$;
create function pg_temp.crypt_calls(p_uid text,p_pin text) returns int language plpgsql as $$
begin
  perform set_config('t.crypt_calls','0',true);
  perform public.badge_auth_verify(p_uid,p_pin);
  return current_setting('t.crypt_calls')::int;
end;
$$;
grant execute on all functions in schema pg_temp to authenticated,anon;
select is(pg_temp.crypt_calls('3091999999999999','000000'),1,'an unknown badge does one crypt');
select is(pg_temp.crypt_calls('3091000000000003','000000'),1,'an inactive member does one crypt');
update public.workspaces set feature_flags='{"kioskMode":true,"nfcBadges":true,"badgeSignIn":false}' where id=pg_temp.u(102);
select is(pg_temp.crypt_calls('3091000000000004','000000'),1,'a disabled feature does one crypt');
delete from public.account_badge_pins where user_id=pg_temp.u(4);
update public.workspaces set feature_flags='{"kioskMode":true,"nfcBadges":true,"badgeSignIn":true}' where id=pg_temp.u(102);
select is(pg_temp.crypt_calls('3091000000000004','000000'),1,'an account with no PIN does one dummy crypt');
update public.member_badges set revoked_at=now() where id=pg_temp.u(304);
select is(pg_temp.crypt_calls('3091000000000004','000000'),1,'a revoked badge does one dummy crypt');
select is(pg_temp.crypt_calls('3091000000000001','000000'),1,'a wrong PIN does one crypt');
select is(pg_temp.crypt_calls('3091000000000001','482615'),1,'a correct PIN does one crypt');
insert into public.badge_auth_attempts(token_hash,succeeded)
select public.badge_token_hash('3091999999999998'),false from generate_series(1,5);
select is(pg_temp.crypt_calls('3091999999999998','482615'),1,'a tag lock still does one crypt');
select is(public.badge_auth_verify('abcd','482615')->>'reason','refused','a short UID is refused');
select ok(not has_function_privilege('authenticated','public.record_badge_auth_failure(text,uuid)','EXECUTE'),'the failure recorder is not a public authenticated API');
select ok(not has_function_privilege('anon','public.badge_auth_verify(text,text)','EXECUTE'),'anonymous clients cannot bypass the Edge boundary');
select ok(not has_table_privilege('authenticated','public.badge_auth_attempts','select'),'clients cannot read the attempt log');
select is((select count(*)::int from pg_policies where schemaname='public' and tablename='badge_auth_attempts' and permissive='PERMISSIVE'),0,'the workspace attack log still has no permissive client policy');
select * from finish();
rollback;
