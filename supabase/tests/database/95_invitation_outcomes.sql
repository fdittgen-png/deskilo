-- SPDX-License-Identifier: AGPL-3.0-or-later
-- 0309 (#1652): an invitation is previewed without a write, and its use
-- answers what happened -- through the existing join_workspace, once.
begin;
select plan(24);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000001652a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'inv-owner@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000001652a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'inv-joiner@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000001652a3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'inv-first@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000001652a4', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'inv-late@deskilo.test', '', now(), now(), now());

create function pg_temp.as_user(p_user text, p_sql text) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  execute p_sql into r;
  execute 'reset role';
  return r;
end;
$$;
create function pg_temp.err(p_user text, p_client text, p_sql text) returns text language plpgsql as $$
begin
  perform set_config('request.jwt.claims', case when p_user is null then '{"role":"anon"}'
    else jsonb_strip_nulls(jsonb_build_object('sub', p_user, 'role', 'authenticated', 'client_id', p_client))::text end, true);
  execute case when p_user is null then 'set local role anon' else 'set local role authenticated' end;
  execute p_sql;
  execute 'reset role';
  return 'no error';
exception when others then
  execute 'reset role';
  return 'refused';
end;
$$;

-- The owner's workspace, and its shared code.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000001652a1","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.ws', public.create_workspace_once('00000000-0000-4000-8000-00000000f652', 'Invite probe', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null, null)::text, true);
reset role;
select set_config('t.code', (select invite_code from public.workspaces where id = current_setting('t.ws')::uuid), true);
select set_config('t.members', (select count(*) from public.members where workspace_id = current_setting('t.ws')::uuid)::text, true);

-- 1. A preview names the workspace and the offered role, and writes nothing.
select set_config('t.p', pg_temp.as_user('00000000-0000-4000-8000-0000001652a2',
  format('select public.invitation_preview(%L)', lower(' ' || current_setting('t.code') || ' ')))::text, true);
select is(current_setting('t.p')::jsonb->>'state', 'valid', 'a live code previews as valid');
select is(current_setting('t.p')::jsonb->>'workspace_name', 'Invite probe', 'the preview names the workspace');
select is(current_setting('t.p')::jsonb->>'offered_role', 'member', 'the shared code offers membership');
select ok(not (current_setting('t.p')::jsonb ? 'workspace_id'), 'a preview does not hand out the workspace id');
select is((select count(*) from public.members where workspace_id = current_setting('t.ws')::uuid)::text,
  current_setting('t.members'), 'a preview adds no member');
select is((select count(*) from public.events where workspace_id = current_setting('t.ws')::uuid and type = 'member_join'),
  0::bigint, 'a preview adds no event');

-- 2. Joining goes through the existing admission path: pending, one event.
select set_config('t.j', pg_temp.as_user('00000000-0000-4000-8000-0000001652a2',
  format('select public.join_by_invitation(%L)', current_setting('t.code')))::text, true);
select is(current_setting('t.j')::jsonb->>'state', 'joined_pending', 'a join lands pending');
select is(current_setting('t.j')::jsonb->>'workspace_id', current_setting('t.ws'), 'the answer names the joined workspace');
select is((select status from public.members where workspace_id = current_setting('t.ws')::uuid
  and user_id = '00000000-0000-4000-8000-0000001652a2'), 'pending', 'the member row is pending');

-- 3. A second tap answers already_member and writes nothing more.
select set_config('t.j2', pg_temp.as_user('00000000-0000-4000-8000-0000001652a2',
  format('select public.join_by_invitation(%L)', current_setting('t.code')))::text, true);
select is(current_setting('t.j2')::jsonb->>'state', 'already_member', 'a repeated join is already_member');
select is((select count(*) from public.events where workspace_id = current_setting('t.ws')::uuid and type = 'member_join'),
  1::bigint, 'one member_join event after two taps');

-- 4. A paused member is not reactivated by a code.
update public.members set status = 'paused' where workspace_id = current_setting('t.ws')::uuid
  and user_id = '00000000-0000-4000-8000-0000001652a2';
select is(pg_temp.as_user('00000000-0000-4000-8000-0000001652a2',
  format('select public.join_by_invitation(%L)', current_setting('t.code')))->>'state', 'paused', 'paused answers paused');
select is((select status from public.members where workspace_id = current_setting('t.ws')::uuid
  and user_id = '00000000-0000-4000-8000-0000001652a2'), 'paused', 'and stays paused');

-- 5. A replaced workspace code is withdrawn, without the workspace's name.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000001652a1","role":"authenticated"}', true);
set local role authenticated;
select public.set_workspace_code(current_setting('t.ws')::uuid, 'PROBE1652NEW');
reset role;
select set_config('t.old', pg_temp.as_user('00000000-0000-4000-8000-0000001652a3',
  format('select public.invitation_preview(%L)', current_setting('t.code')))::text, true);
select is(current_setting('t.old')::jsonb->>'state', 'revoked', 'the replaced code is revoked');
select ok(not (current_setting('t.old')::jsonb ? 'workspace_name'), 'a revoked code names nothing');
select is(pg_temp.as_user('00000000-0000-4000-8000-0000001652a3',
  'select public.invitation_preview(''NOSUCHCODE1'')'), '{"state":"invalid"}'::jsonb, 'an unknown code is invalid, and only that');

-- 6. Personal invitations: the admin role, used by another account, expired.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-0000001652a1","role":"authenticated"}', true);
set local role authenticated;
select set_config('t.inv', public.create_invitation(current_setting('t.ws')::uuid, true, 'A', 'B', null, false), true);
select set_config('t.inv2', public.create_invitation(current_setting('t.ws')::uuid, false, 'C', 'D', null, false), true);
reset role;
select is(pg_temp.as_user('00000000-0000-4000-8000-0000001652a3',
  format('select public.invitation_preview(%L)', current_setting('t.inv')))->>'offered_role', 'admin', 'an admin invitation offers admin');
select is(pg_temp.as_user('00000000-0000-4000-8000-0000001652a3',
  format('select public.join_by_invitation(%L)', current_setting('t.inv')))->>'state', 'joined_pending', 'the first account joins');
select is(pg_temp.as_user('00000000-0000-4000-8000-0000001652a4',
  format('select public.join_by_invitation(%L)', current_setting('t.inv')))->>'state', 'wrong_account', 'another account hears wrong_account');
update public.invitations i set expires_at = now() - interval '1 minute' where i.code = current_setting('t.inv2');
select is(pg_temp.as_user('00000000-0000-4000-8000-0000001652a4',
  format('select public.join_by_invitation(%L)', current_setting('t.inv2')))->>'state', 'expired', 'an expired invitation is expired');
select ok((select i.redeemed_at is null from public.invitations i where i.code = current_setting('t.inv2')), 'and is not consumed');

-- 7. Anonymous and delegated callers are refused; the helper and the table are closed.
select is(pg_temp.err(null, null, 'select public.invitation_preview(''PROBE1652NEW'')'), 'refused', 'anon cannot preview');
select is(pg_temp.err('00000000-0000-4000-8000-0000001652a4', 'assistant', 'select public.join_by_invitation(''PROBE1652NEW'')'),
  'refused', 'an assistant token cannot join');
select is(pg_temp.err('00000000-0000-4000-8000-0000001652a4', null, 'select public.invitation_state(''PROBE1652NEW'')'),
  'refused', 'the classification is not callable directly');

select * from finish();
rollback;
