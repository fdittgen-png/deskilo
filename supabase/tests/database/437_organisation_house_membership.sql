-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #4008 (0781) -- a member of one house asks to join another without a
-- code. With the house's welcome off (the default) they are pending there,
-- the join decision naming the house they come from, and asking again asks
-- nothing twice; with Zurich's welcome on they are active there at once and
-- the decision is written already decided by the house's welcome, while
-- London, whose owner said nothing, still decides. The welcome is each
-- house's own: the head's owner does not switch a house they do not own. An
-- exited member asks as any returning member. A person in no house of the
-- organisation and an assistant are refused. The houses a member may join
-- are listed with their request and their welcome.
-- Rolled back.
begin;
select plan(21);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  owner_o uuid := '00000000-0000-4000-8000-000000004080';
  owner_l uuid := '00000000-0000-4000-8000-000000004085';
  member_a uuid := '00000000-0000-4000-8000-000000004081';
  member_b uuid := '00000000-0000-4000-8000-000000004082';
  exited_e uuid := '00000000-0000-4000-8000-000000004083';
  outsider_x uuid := '00000000-0000-4000-8000-000000004084';
  paris uuid; zurich uuid; london uuid; org uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'askjoin-' || right(u::text, 4) || '@deskilo.test', '', now(), now(), now()
    from unnest(array[owner_o, member_a, member_b, exited_e, outsider_x, owner_l]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, environment)
  values ('ASKJOIN-PARIS', 'FR', 'EUR', 'Europe/Paris', owner_o, 'prod') returning id into paris;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, environment)
  values ('ASKJOIN-ZURICH', 'CH', 'CHF', 'Europe/Zurich', owner_o, 'prod') returning id into zurich;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by, environment)
  values ('ASKJOIN-LONDON', 'GB', 'GBP', 'Europe/London', owner_l, 'prod') returning id into london;
  update public.workspaces set feature_flags = coalesce(feature_flags, '{}'::jsonb) || '{"organisation": true}'
   where id in (paris, zurich, london);
  insert into public.members (workspace_id, user_id, is_owner, is_admin, joined_at)
  values (paris, owner_o, true, true, '2026-01-01'), (zurich, owner_o, true, true, '2026-01-01'),
         (london, owner_l, true, true, '2026-01-01'),
         (paris, member_a, false, false, '2026-01-01'), (paris, member_b, false, false, '2026-01-01'),
         (paris, exited_e, false, false, '2026-01-01');
  -- e was an administrator of Zurich with rights and terms of their own, and left
  insert into public.members (workspace_id, user_id, is_owner, is_admin, status, joined_at, member_number,
                              is_kiosk, can_reserve_level, max_active_reservations,
                              max_simultaneous_reservations, vat_treatment, subscription_pct)
  values (zurich, exited_e, false, true, 'exited', '2025-01-01', 'Z-0007',
          true, true, 3, 2, 'exempt', 50);
  insert into public.organisations (name, head_workspace_id) values ('Ask group', paris) returning id into org;
  update public.workspaces set organisation_id = org where id in (paris, zurich, london);
  perform set_config('deskilo.aj.org', org::text, false);
  perform set_config('deskilo.aj.paris', paris::text, false);
  perform set_config('deskilo.aj.zurich', zurich::text, false);
  perform set_config('deskilo.aj.london', london::text, false);
  perform set_config('deskilo.aj.owner', owner_o::text, false);
  perform set_config('deskilo.aj.a', member_a::text, false);
  perform set_config('deskilo.aj.b', member_b::text, false);
  perform set_config('deskilo.aj.e', exited_e::text, false);
  perform set_config('deskilo.aj.x', outsider_x::text, false);
end;
$seed$;
select pg_temp.seed();

create or replace function pg_temp.id(p text) returns uuid language sql as $$
  select current_setting('deskilo.aj.' || p)::uuid
$$;
create or replace function pg_temp.as_user(p text, p_assistant boolean default false) returns void language sql as $$
  select set_config('request.jwt.claims',
    (jsonb_build_object('sub', current_setting('deskilo.aj.' || p), 'role', 'authenticated')
       || case when p_assistant then '{"client_id": "an-assistant"}'::jsonb else '{}'::jsonb end)::text, true)
$$;
create or replace function pg_temp.member_in(p_ws text, p_user text) returns public.members language sql as $$
  select m from public.members m where m.workspace_id = pg_temp.id(p_ws) and m.user_id = pg_temp.id(p_user)
$$;
grant execute on all functions in schema pg_temp to authenticated;

select is(public.house_welcomes_members(pg_temp.id('zurich')), false,
  'a house does not welcome the members of the other houses until its owner says so');

-- ── the welcome off: the house decides ──
select pg_temp.as_user('a');
set local role authenticated;
select is((public.request_house_membership(pg_temp.id('zurich'))->>'status'), 'pending',
  'a member of Paris asks Zurich without a code and is pending there');
select is((public.request_house_membership(pg_temp.id('zurich'))->>'status'), 'pending',
  'asking again asks nothing twice');
select is((select string_agg(h->>'name' || ':' || coalesce(h->>'request', '-'), ',' order by h->>'name')
             from jsonb_array_elements(public.my_organisation_houses_v1()) h),
  'ASKJOIN-LONDON:-,ASKJOIN-ZURICH:pending', 'their list names the houses they may join and their request, not their own');
reset role;
select is((select (m.origin, m.member_number <> '', m.is_admin)::text
             from pg_temp.member_in('zurich', 'a') m),
  '(invited,t,f)', 'the row an invitation creates, with the house''s own member number');
select is((select count(*)::int from public.events e
            where e.workspace_id = pg_temp.id('zurich') and e.type = 'member_join' and e.status = 'pending'
              and e.subject_member_id = (pg_temp.member_in('zurich', 'a')).id
              and e.payload->>'from_workspace_id' = pg_temp.id('paris')::text), 1,
  'one join decision, naming the house they come from');


-- ── who is refused ──
select pg_temp.as_user('x');
set local role authenticated;
select throws_ok(format('select public.request_house_membership(%L)', pg_temp.id('zurich')),
  '42501', 'only a member of a house of this organisation asks to join another',
  'a person in no house of the organisation asks nothing');
reset role;
select pg_temp.as_user('b', true);
set local role authenticated;
select throws_ok(format('select public.request_house_membership(%L)', pg_temp.id('zurich')),
  '42501', 'only a person asks to join a house', 'nor does an assistant''s token');
reset role;
select pg_temp.as_user('a');
set local role authenticated;
select throws_ok(format('select public.set_house_members_welcome(%L, true)', pg_temp.id('zurich')),
  '42501', 'only an owner of this business may do this', 'a member does not change a house''s welcome');
reset role;
select pg_temp.as_user('owner');
set local role authenticated;
select throws_ok(format('select public.set_house_members_welcome(%L, true)', pg_temp.id('london')),
  '42501', 'only an owner of this business may do this',
  'the head''s owner does not switch the welcome of a house they do not own');

-- ── Zurich's welcome on: active at once there, not in London ──
select lives_ok(format('select public.set_house_members_welcome(%L, true)', pg_temp.id('zurich')),
  'an owner of Zurich welcomes the members of the other houses');
reset role;
select pg_temp.as_user('b');
set local role authenticated;
select is((public.request_house_membership(pg_temp.id('zurich'))->>'status'), 'active',
  'with the welcome on, a member of Paris is a member of Zurich at once');
reset role;
select is((select (m.status, m.member_number <> '')::text from pg_temp.member_in('zurich', 'b') m),
  '(active,t)', 'with the house''s own member number');
select is((select (e.status, e.decided_at is not null, e.payload->>'by', e.payload->>'from_workspace_name')::text
             from public.events e
            where e.workspace_id = pg_temp.id('zurich') and e.type = 'member_join'
              and e.subject_member_id = (pg_temp.member_in('zurich', 'b')).id),
  '(confirmed,t,house_welcome,ASKJOIN-PARIS)',
  'the journal holds the join, decided by the house''s welcome, naming where they came from');
-- a former administrator returns as a new member, and the house decides
select pg_temp.as_user('e');
set local role authenticated;
select is((public.request_house_membership(pg_temp.id('zurich'))->>'status'), 'pending',
  'someone who left Zurich asks again and Zurich decides, its welcome notwithstanding');
reset role;
select is((select (m.status, m.is_admin, m.is_owner, m.co_owner)::text from pg_temp.member_in('zurich', 'e') m),
  '(pending,f,f,none)', 'without the role they had');
select is((select (m.is_kiosk, m.can_reserve_level, m.max_active_reservations, m.max_simultaneous_reservations,
                   m.vat_treatment, m.subscription_pct, m.member_number, m.joined_at::date)::text
             from pg_temp.member_in('zurich', 'e') m),
  '(f,f,,,auto,100,Z-0007,2025-01-01)',
  'and without the rights and terms they had, keeping their number and their history');
select pg_temp.as_user('b');
set local role authenticated;
select is((public.request_house_membership(pg_temp.id('london'))->>'status'), 'pending',
  'Zurich''s welcome does not make London welcoming');
select is((select string_agg(h->>'name' || ':' || (h->>'welcome'), ',') from jsonb_array_elements(public.my_organisation_houses_v1()) h),
  'ASKJOIN-LONDON:false', 'their list gives each house''s own welcome');
reset role;

-- ── a house that leaves takes its welcome with it ──
update public.workspaces set organisation_id = null where id = pg_temp.id('zurich');
update public.workspaces set organisation_id = pg_temp.id('org') where id = pg_temp.id('zurich');
select is(public.house_welcomes_members(pg_temp.id('zurich')), false,
  'a house added again welcomes no one until its owner says so anew');

-- ── every column of members is kept or reset when someone returns ──
select is((select coalesce(string_agg(c.column_name, ', ' order by c.column_name), '')
             from information_schema.columns c
            where c.table_schema = 'public' and c.table_name = 'members'
              and not ((public.house_member_return_columns()->'kept') ? c.column_name
                       or (public.house_member_return_columns()->'reset') ? c.column_name)),
  '', 'every column of members is named as kept or reset for a returning member');

select * from finish();
rollback;
