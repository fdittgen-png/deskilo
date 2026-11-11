-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3594 (GHSA-6m6w-2j3m-rm75): a join request shows who asks. Whoever
-- decides the requests (manageMembers) reads the pending person's name; a
-- member without that permission reads nothing of them; the e-mail address
-- is listed only once the person is a member.
begin;
select plan(8);

-- e1 owner of f1 · e2 asks to join f1 · e3 plain member of f1
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000035942'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@joinrequest.test','',now(),now(),now()
  from unnest(array['e1','e2','e3']) suffix;
update public.profiles set display_name = 'Asking Person'
 where id = '00000000-0000-4000-8000-0000035942e2';
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,role_permissions,feature_flags) values
 ('00000000-0000-4000-8000-0000035942f1','Join request','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000035942e1','dev','{}','{}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,co_owner,status) values
 ('00000000-0000-4000-8000-0000035942c1','00000000-0000-4000-8000-0000035942f1','00000000-0000-4000-8000-0000035942e1',true,true,'none','active'),
 ('00000000-0000-4000-8000-0000035942c2','00000000-0000-4000-8000-0000035942f1','00000000-0000-4000-8000-0000035942e2',false,false,'none','pending'),
 ('00000000-0000-4000-8000-0000035942c3','00000000-0000-4000-8000-0000035942f1','00000000-0000-4000-8000-0000035942e3',false,false,'none','active');

-- What [p_reader] reads of the asking person, and of the space's e-mails.
create or replace function pg_temp.profiles_as(p_reader text) returns jsonb language plpgsql as $f$
declare v jsonb;
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_reader, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v := public.member_profiles('00000000-0000-4000-8000-0000035942f1',
         array['00000000-0000-4000-8000-0000035942e2'::uuid]);
  reset role;
  return v;
end;
$f$;
create or replace function pg_temp.emails_as(p_reader text) returns text[] language plpgsql as $f$
declare v text[];
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_reader, 'role', 'authenticated')::text, true);
  set local role authenticated;
  select array_agg(e.email order by e.email) into v
    from public.member_emails('00000000-0000-4000-8000-0000035942f1') e;
  reset role;
  return v;
end;
$f$;

-- ── pending ─────────────────────────────────────────────────────────
select is(pg_temp.profiles_as('00000000-0000-4000-8000-0000035942e1')->0->'community'->>'display_name','Asking Person','whoever decides the requests reads who asks');
select ok(not (pg_temp.profiles_as('00000000-0000-4000-8000-0000035942e1')->0 ? 'operational'),'and nothing beyond the community view');
select is(jsonb_array_length(pg_temp.profiles_as('00000000-0000-4000-8000-0000035942e3')),0,'a member who does not decide requests reads nothing of them');
select ok(not ('e2@joinrequest.test' = any(pg_temp.emails_as('00000000-0000-4000-8000-0000035942e1'))),'the e-mail address of a request is not listed');
select ok('e3@joinrequest.test' = any(pg_temp.emails_as('00000000-0000-4000-8000-0000035942e1')),'a member''s address still is');

-- ── once a member ───────────────────────────────────────────────────
update public.members set status = 'active' where id = '00000000-0000-4000-8000-0000035942c2';
select ok('e2@joinrequest.test' = any(pg_temp.emails_as('00000000-0000-4000-8000-0000035942e1')),'once a member, their address is listed');
select ok(pg_temp.profiles_as('00000000-0000-4000-8000-0000035942e1')->0 ? 'operational','and the billing details reach whoever invoices');
select is(pg_temp.profiles_as('00000000-0000-4000-8000-0000035942e3')->0->'community'->>'display_name','Asking Person','and a space mate reads their name');

select * from finish();
rollback;
