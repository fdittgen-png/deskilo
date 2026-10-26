-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2580 / 9999: what waits on a decision of the space now.
-- Space b1: two requests pending, one applied and one confirmed (out), one
-- person asking to join, two active members -> 3. Space b2 has a pending
-- request of its own, never counted in b1. A past period gets today's
-- value, said as not recorded; a member without the analytics right, or
-- the overview off, is refused; the registry lists the figure.
begin;
select plan(7);

insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
select ('00000000-0000-4000-8000-0000025800'||suffix)::uuid,'00000000-0000-0000-0000-000000000000',
 'authenticated','authenticated',suffix||'@pending.test','',now(),now(),now()
  from unnest(array['a1','a2','a3']) suffix;
insert into public.workspaces(id,name,country_code,currency_code,timezone,created_by,environment,feature_flags) values
 ('00000000-0000-4000-8000-0000025800b1','Pending','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000025800a1','dev',
  '{"workspaceOverview":true}'),
 ('00000000-0000-4000-8000-0000025800b2','Elsewhere','FR','EUR','Europe/Paris','00000000-0000-4000-8000-0000025800a1','dev',
  '{"workspaceOverview":true}');
insert into public.members(id,workspace_id,user_id,is_owner,is_admin,status) values
 ('00000000-0000-4000-8000-0000025800c1','00000000-0000-4000-8000-0000025800b1','00000000-0000-4000-8000-0000025800a1',true,true,'active'),
 ('00000000-0000-4000-8000-0000025800c2','00000000-0000-4000-8000-0000025800b1','00000000-0000-4000-8000-0000025800a2',false,false,'active'),
 ('00000000-0000-4000-8000-0000025800c3','00000000-0000-4000-8000-0000025800b1','00000000-0000-4000-8000-0000025800a3',false,false,'pending'),
 ('00000000-0000-4000-8000-0000025800c4','00000000-0000-4000-8000-0000025800b2','00000000-0000-4000-8000-0000025800a1',true,true,'active');

create function pg_temp.u(p text) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-0000025800' || p)::uuid;
$$;
create function pg_temp.ev(p_ws text, p_member text, p_status text) returns void language sql as $$
  insert into public.events (workspace_id, type, action, actor_member_id, subject_member_id, status)
  values (pg_temp.u(p_ws), 'expense', 'submitted', pg_temp.u(p_member), pg_temp.u(p_member), p_status);
$$;
create function pg_temp.call(p_user text, p_from text, p_to text) returns jsonb language plpgsql as $$
declare v jsonb;
begin
  perform set_config('request.jwt.claims',
    jsonb_build_object('sub', pg_temp.u(p_user), 'role', 'authenticated')::text, true);
  select public.kpi_pending_actions_current(pg_temp.u('b1'), p_from, p_to) into v;
  return v;
end;
$$;

select pg_temp.ev('b1', 'c2', 'pending');
select pg_temp.ev('b1', 'c2', 'pending');
select pg_temp.ev('b1', 'c2', 'applied');
select pg_temp.ev('b1', 'c1', 'confirmed');
select pg_temp.ev('b2', 'c4', 'pending');

set local role authenticated;
select set_config('t.now', to_char(now() at time zone 'Europe/Paris', 'YYYY-MM'), true);
select set_config('t.pending',
  pg_temp.call('a1', current_setting('t.now'), current_setting('t.now'))::text, true);

select is(current_setting('t.pending')::jsonb ->> 'value', '3',
  'two pending requests and one person asking to join; decided ones and another space are not counted');
select is((current_setting('t.pending')::jsonb ->> 'count')::int, 3, 'the count is the value');
select is(current_setting('t.pending')::jsonb -> 'quality', '[]'::jsonb, 'the current month is today''s figure');
select ok(pg_temp.call('a1', '2025-01', '2025-01') -> 'reasons' ? 'current_state',
  'a past period gets today''s value, said as such');
select throws_ok($q$select pg_temp.call('a2', '2026-01', '2026-01')$q$,
  '42501', null, 'a member without the analytics right is refused');
select is(public.kpi_registry() -> 'operations.pending_actions_current' -> 'permissions',
  '["viewAnalytics"]'::jsonb, 'the registry lists the figure behind the analytics right');
reset role;
update public.workspaces set feature_flags = feature_flags || '{"workspaceOverview": false}' where id = pg_temp.u('b1');
set local role authenticated;
select throws_ok($q$select pg_temp.call('a1', '2026-01', '2026-01')$q$,
  '42501', null, 'with the overview off, nothing is read');

select * from finish();
rollback;
