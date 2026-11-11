-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3594 (GHSA-6m6w-2j3m-rm75): the community view of a member follows the
-- person's contact and presence settings. With the defaults a space mate
-- reads neither the WhatsApp number, the status nor the last-seen time;
-- once the person opens them to their spaces, the mate reads them; a
-- space they did not choose reads nothing; an administrator receives no
-- more than a mate through this view; and the preview of "how others see
-- me" equals what the mate receives, before and after.
begin;
select plan(14);

-- c1 owner/admin of d1 · c2 subject (d1 + d2) · c3 mate in d1 · c4 owner of d2
insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000003594'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@community.test','',now(),now(),now()
  from unnest(array['c1','c2','c3','c4']) suffix;
update public.profiles set display_name = 'Community Subject', whatsapp = '+33600003594',
       status_text = 'At the window desk'
 where id = '00000000-0000-4000-8000-0000003594c2';
insert into public.presence(user_id, last_seen_at)
values ('00000000-0000-4000-8000-0000003594c2', now())
on conflict (user_id) do update set last_seen_at = excluded.last_seen_at;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,role_permissions,feature_flags) values
 ('00000000-0000-4000-8000-0000003594d1','Community one','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000003594c1','dev','{}','{}'),
 ('00000000-0000-4000-8000-0000003594d2','Community two','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000003594c4','dev','{}','{}');
insert into public.members(workspace_id,user_id,is_owner,is_admin,co_owner,status) values
 ('00000000-0000-4000-8000-0000003594d1','00000000-0000-4000-8000-0000003594c1',true,true,'none','active'),
 ('00000000-0000-4000-8000-0000003594d1','00000000-0000-4000-8000-0000003594c2',false,false,'none','active'),
 ('00000000-0000-4000-8000-0000003594d1','00000000-0000-4000-8000-0000003594c3',false,false,'none','active'),
 ('00000000-0000-4000-8000-0000003594d2','00000000-0000-4000-8000-0000003594c4',true,true,'none','active'),
 ('00000000-0000-4000-8000-0000003594d2','00000000-0000-4000-8000-0000003594c2',false,false,'none','active');

-- What reader [p_reader] receives of the subject in d1, as that reader.
create or replace function pg_temp.seen_by(p_reader text) returns jsonb language plpgsql as $f$
declare v jsonb;
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_reader, 'role', 'authenticated')::text, true);
  set local role authenticated;
  v := public.member_profiles('00000000-0000-4000-8000-0000003594d1',
         array['00000000-0000-4000-8000-0000003594c2'::uuid])->0->'community';
  reset role;
  return v;
end;
$f$;
-- The subject's own preview as a space mate.
create or replace function pg_temp.preview() returns jsonb language plpgsql as $f$
declare v jsonb;
begin
  perform set_config('request.jwt.claims',
    '{"sub":"00000000-0000-4000-8000-0000003594c2","role":"authenticated"}', true);
  set local role authenticated;
  v := public.preview_my_member_profile('space_mate')->'community';
  reset role;
  return v;
end;
$f$;

-- ── defaults ────────────────────────────────────────────────────────
select is(pg_temp.seen_by('00000000-0000-4000-8000-0000003594c3')->>'whatsapp','','by default a space mate does not read the WhatsApp number');
select is(pg_temp.seen_by('00000000-0000-4000-8000-0000003594c3')->>'status_text','','nor the status');
select is(pg_temp.seen_by('00000000-0000-4000-8000-0000003594c3')->>'last_seen_at',null,'nor the last-seen time');
select is(pg_temp.seen_by('00000000-0000-4000-8000-0000003594c3')->>'display_name','Community Subject','the name is still read');
select is(pg_temp.seen_by('00000000-0000-4000-8000-0000003594c1'),pg_temp.seen_by('00000000-0000-4000-8000-0000003594c3'),'an administrator receives no more than a space mate');
select is(pg_temp.preview(),pg_temp.seen_by('00000000-0000-4000-8000-0000003594c3'),'the preview equals what the space mate receives');

-- ── opened to their spaces ─────────────────────────────────────────
insert into public.account_field_audience(user_id, field, audience) values
 ('00000000-0000-4000-8000-0000003594c2','contact_channels','my_spaces'),
 ('00000000-0000-4000-8000-0000003594c2','presence','my_spaces');
select is(pg_temp.seen_by('00000000-0000-4000-8000-0000003594c3')->>'whatsapp','+33600003594','opened to their spaces, the mate reads the WhatsApp number');
select is(pg_temp.seen_by('00000000-0000-4000-8000-0000003594c3')->>'status_text','At the window desk','and the status');
select isnt(pg_temp.seen_by('00000000-0000-4000-8000-0000003594c3')->>'last_seen_at',null,'and the last-seen time');
select is(pg_temp.preview(),pg_temp.seen_by('00000000-0000-4000-8000-0000003594c3'),'the preview still equals what the mate receives');

-- ── one chosen space ───────────────────────────────────────────────
update public.account_field_audience set audience = 'chosen_spaces'
 where user_id = '00000000-0000-4000-8000-0000003594c2' and field = 'presence';
insert into public.account_field_audience_spaces(user_id, field, workspace_id) values
 ('00000000-0000-4000-8000-0000003594c2','presence','00000000-0000-4000-8000-0000003594d2');
select is(pg_temp.seen_by('00000000-0000-4000-8000-0000003594c3')->>'status_text','','a space the person did not choose does not read the status');
select is(pg_temp.seen_by('00000000-0000-4000-8000-0000003594c3')->>'whatsapp','+33600003594','while the contact setting still applies on its own');

-- ── grants ──────────────────────────────────────────────────────────
select ok(not has_function_privilege('authenticated','public.community_field_shown(uuid,text,uuid)','execute')
      and not has_function_privilege('anon','public.community_field_shown(uuid,text,uuid)','execute'),'the decision is callable by no client');
select ok(not has_function_privilege('authenticated','public.member_profile_projection(uuid,text[],uuid)','execute'),'nor is the projection');

select * from finish();
rollback;
