-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #4008 (0782) -- a person who left a business and comes back is a new
-- member of it, on every way of coming back. An administrator setting a
-- member who left back to active, at once or through the business's
-- validation, and an invitation bound to a managed profile that had left,
-- each bring the row back as a new member's; a member who left is not set
-- to paused. No other statement takes a row out of 'exited', as an owner
-- or as the service. Paths that only set 'exited' or activate 'pending'
-- are as they were. Rolled back.
begin;
select plan(11);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  owner_o uuid := '00000000-0000-4000-8000-000000004090';
  admin_v uuid := '00000000-0000-4000-8000-000000004091';
  left_f uuid := '00000000-0000-4000-8000-000000004092';
  left_g uuid := '00000000-0000-4000-8000-000000004093';
  claimer_h uuid := '00000000-0000-4000-8000-000000004094';
  joiner_j uuid := '00000000-0000-4000-8000-000000004095';
  twin_k uuid := '00000000-0000-4000-8000-000000004096';
  left_p uuid := '00000000-0000-4000-8000-000000004097';
  ws uuid; prod uuid; dev uuid; role_id uuid; managed uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'return-' || right(u::text, 4) || '@deskilo.test', '', now(), now(), now()
    from unnest(array[owner_o, admin_v, left_f, left_g, claimer_h, joiner_j, twin_k, left_p]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, environment)
  values ('RETURN-PARIS', 'FR', 'EUR', 'Europe/Paris', owner_o, 'prod') returning id into ws;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, joined_at)
  values (ws, owner_o, true, true, '2026-01-01'), (ws, admin_v, false, true, '2026-01-01');
  -- f, g and p were administrators and co-owners with managed access and a role, and left
  insert into public.members (workspace_id, user_id, is_owner, is_admin, co_owner, managed_access, status,
                              joined_at, member_number)
  values (ws, left_f, false, true, 'active', '{"k": 1}', 'exited', '2025-01-01', 'R-0003'),
         (ws, left_g, false, true, 'active', '{"k": 1}', 'exited', '2025-01-01', 'R-0004'),
         (ws, left_p, false, true, 'active', '{"k": 1}', 'exited', '2025-01-01', 'R-0005');
  insert into public.workspace_roles (workspace_id, key) values (ws, 'return_role') returning id into role_id;
  insert into public.workspace_role_members (workspace_id, role_id, member_id)
  select ws, role_id, m.id from public.members m where m.workspace_id = ws and m.user_id in (left_f, left_g, left_p);
  -- a managed profile with an administrator's flag that left, and an invitation bound to it
  insert into public.members (workspace_id, user_id, is_admin, status, managed_name, joined_at, member_number)
  values (ws, null, true, 'exited', 'Former profile', '2025-01-01', 'R-0006') returning id into managed;
  insert into public.invitations (workspace_id, code, is_admin, created_by, expires_at, member_id)
  values (ws, 'RETINV4008', false, owner_o, now() + interval '1 day', managed);
  -- a pair whose members leave together
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, environment, pair_id)
  values ('RETURN-PAIR', 'FR', 'EUR', 'Europe/Paris', owner_o, 'prod', '00000000-0000-4000-8000-0000000040e9')
  returning id into prod;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, environment, pair_id)
  values ('RETURN-PAIR (dev)', 'FR', 'EUR', 'Europe/Paris', owner_o, 'dev', '00000000-0000-4000-8000-0000000040e9')
  returning id into dev;
  -- a member of the pair may enter its production half
  update public.workspaces set role_permissions = coalesce(role_permissions, '{}'::jsonb) || '{"member": ["accessProd"]}'
   where id = prod;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, joined_at)
  values (prod, owner_o, true, true, '2026-01-01'), (dev, owner_o, true, true, '2026-01-01');
  insert into public.members (workspace_id, user_id, is_admin, joined_at)
  values (dev, twin_k, false, '2026-01-01') on conflict do nothing;
  insert into public.members (workspace_id, user_id, is_admin, joined_at)
  values (prod, twin_k, false, '2026-01-01') on conflict do nothing;
  perform set_config('deskilo.rt.ws', ws::text, false);
  perform set_config('deskilo.rt.prod', prod::text, false);
  perform set_config('deskilo.rt.dev', dev::text, false);
  perform set_config('deskilo.rt.code', (select invite_code from public.workspaces where id = ws), false);
  perform set_config('deskilo.rt.owner', owner_o::text, false);
  perform set_config('deskilo.rt.v', admin_v::text, false);
  perform set_config('deskilo.rt.f', left_f::text, false);
  perform set_config('deskilo.rt.g', left_g::text, false);
  perform set_config('deskilo.rt.p', left_p::text, false);
  perform set_config('deskilo.rt.h', claimer_h::text, false);
  perform set_config('deskilo.rt.j', joiner_j::text, false);
  perform set_config('deskilo.rt.k', twin_k::text, false);
  perform set_config('deskilo.rt.managed', managed::text, false);
end;
$seed$;
select pg_temp.seed();

create or replace function pg_temp.id(p text) returns uuid language sql as $$
  select current_setting('deskilo.rt.' || p)::uuid
$$;
create or replace function pg_temp.as_user(p text) returns void language sql as $$
  select set_config('request.jwt.claims',
    jsonb_build_object('sub', current_setting('deskilo.rt.' || p), 'role', 'authenticated')::text, true)
$$;
create or replace function pg_temp.mid(p_ws text, p_user text) returns uuid language sql as $$
  select m.id from public.members m where m.workspace_id = pg_temp.id(p_ws) and m.user_id = pg_temp.id(p_user)
$$;
-- who the row is now: status, rights, number, roles
create or replace function pg_temp.as_new(p_member uuid) returns text language sql as $$
  select (m.status, m.is_admin, m.is_owner, m.co_owner, m.managed_access::text, m.member_number,
          (select count(*) from public.workspace_role_members r where r.member_id = m.id))::text
    from public.members m where m.id = p_member
$$;
-- what [p_sql] raises when the service runs it
create or replace function pg_temp.as_service(p_sql text) returns text language plpgsql as $$
declare v text := 'no error';
begin
  execute 'set local role service_role';
  begin
    execute p_sql;
  exception when others then v := sqlstate || ' ' || sqlerrm;
  end;
  execute 'reset role';
  return v;
end
$$;
grant execute on all functions in schema pg_temp to authenticated, service_role;

-- ── an administrator sets a member who left back to active, at once ──
select pg_temp.as_user('owner');
set local role authenticated;
select public.request_member_status_change(pg_temp.mid('ws', 'f'), 'active');
reset role;
select is(pg_temp.as_new(pg_temp.mid('ws', 'f')), '(active,f,f,none,{},R-0003,0)',
  'an administrator brings a member who left back as a new member');

select pg_temp.as_user('owner');
set local role authenticated;
select throws_ok(format('select public.request_member_status_change(%L, %L)', pg_temp.mid('ws', 'p'), 'paused'),
  'DKM01', 'a member who left comes back as a new member', 'a member who left is not set to paused');
reset role;

-- ── the same, through the business's validation ──
insert into public.validation_policies (workspace_id, event_type, required_count, admins_may_validate)
values (pg_temp.id('ws'), 'member_status_change', 1, true);
select pg_temp.as_user('owner');
set local role authenticated;
select set_config('deskilo.rt.event',
  (public.request_member_status_change(pg_temp.mid('ws', 'g'), 'active')->>'event_id'), false);
reset role;
select pg_temp.as_user('v');
set local role authenticated;
select public.respond_to_event(current_setting('deskilo.rt.event')::uuid, true);
reset role;
select is(pg_temp.as_new(pg_temp.mid('ws', 'g')), '(active,f,f,none,{},R-0004,0)',
  'once the business''s validation decides it, a member who left is back as a new member');

-- ── an invitation bound to a managed profile that had left ──
select pg_temp.as_user('h');
set local role authenticated;
select public.join_workspace('RETINV4008');
reset role;
select is((select (m.status, m.is_admin, m.user_id = pg_temp.id('h'), m.member_number)::text
             from public.members m where m.id = pg_temp.id('managed')),
  '(pending,f,t,R-0006)', 'a managed profile that had left is claimed as a new member, pending');

-- ── no other statement takes a row out of exited ──
select pg_temp.as_user('owner');
set local role authenticated;
select throws_ok(format('update public.members set status = %L where id = %L', 'active', pg_temp.mid('ws', 'p')),
  'DKM01', 'a member who left comes back as a new member', 'not an owner''s own update');
reset role;
select is(pg_temp.as_service(format('update public.members set status = %L where id = %L', 'active', pg_temp.mid('ws', 'p'))),
  'DKM01 a member who left comes back as a new member', 'nor the service''s');
select is(pg_temp.as_new(pg_temp.mid('ws', 'p')), '(exited,t,f,active,"{""k"": 1}",R-0005,1)',
  'the row stays as it was');

-- ── the paths that set exited or activate pending are as they were ──
select pg_temp.as_user('j');
set local role authenticated;
select public.join_workspace(current_setting('deskilo.rt.code'));
reset role;
select set_config('deskilo.rt.join', (select e.id::text from public.events e
  where e.subject_member_id = pg_temp.mid('ws', 'j') and e.type = 'member_join' and e.status = 'pending'), false);
select pg_temp.as_user('v');
set local role authenticated;
select lives_ok(format('select public.respond_to_event(%L, true)', current_setting('deskilo.rt.join')),
  'a first join is approved');
reset role;
select is((select status from public.members where id = pg_temp.mid('ws', 'j')), 'active',
  'and the member is active');
select pg_temp.as_user('k');
set local role authenticated;
select lives_ok(format('select public.leave_workspace(%L)', pg_temp.id('prod')), 'a member of a pair leaves');
reset role;
select is((select string_agg(w.environment || '=' || m.status, ',' order by w.environment)
             from public.members m join public.workspaces w on w.id = m.workspace_id
            where m.user_id = pg_temp.id('k')),
  'dev=exited,prod=exited', 'and leaves both halves of the pair');

select * from finish();
rollback;
