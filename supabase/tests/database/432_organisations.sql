-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #4004 (0773) -- the organisation of a customer's businesses. An owner of
-- two businesses makes one organisation of them; someone who owns only one
-- of the two is refused; the members of a house read the organisation's
-- name, someone outside reads nothing. Only the server writes a business's
-- organisation; a twin follows its business into and out of it; the head
-- leaves last; removing a house leaves its data as it was. An assistant's
-- token is refused. Rolled back.
begin;
select plan(18);

create or replace function pg_temp.seed() returns void language plpgsql as $seed$
declare
  owner_a uuid := '00000000-0000-4000-8000-000000004004';
  owner_b uuid := '00000000-0000-4000-8000-000000004005';
  member_m uuid := '00000000-0000-4000-8000-000000004006';
  outsider uuid := '00000000-0000-4000-8000-000000004007';
  w1 uuid; w2 uuid; w3 uuid;
begin
  insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                          email_confirmed_at, created_at, updated_at)
  select u, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'org-' || right(u::text, 4) || '@deskilo.test', '', now(), now(), now()
    from unnest(array[owner_a, owner_b, member_m, outsider]) u;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('ORG-PARIS', 'FR', 'EUR', 'Europe/Paris', owner_a) returning id into w1;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('ORG-LONDON', 'GB', 'GBP', 'Europe/London', owner_a) returning id into w2;
  insert into public.workspaces (name, country_code, currency_code, timezone, created_by)
  values ('ORG-ZURICH', 'CH', 'CHF', 'Europe/Zurich', owner_b) returning id into w3;
  insert into public.members (workspace_id, user_id, is_owner, is_admin, joined_at)
  values (w1, owner_a, true, true, '2026-01-01'), (w2, owner_a, true, true, '2026-01-01'),
         (w3, owner_b, true, true, '2026-01-01');
  insert into public.members (workspace_id, user_id, joined_at) values (w2, member_m, '2026-01-01');
  perform set_config('deskilo.test.w1', w1::text, false);
  perform set_config('deskilo.test.w2', w2::text, false);
  perform set_config('deskilo.test.w3', w3::text, false);
  perform set_config('deskilo.test.owner_a', owner_a::text, false);
  perform set_config('deskilo.test.owner_b', owner_b::text, false);
  perform set_config('deskilo.test.member_m', member_m::text, false);
  perform set_config('deskilo.test.outsider', outsider::text, false);
end;
$seed$;
select pg_temp.seed();

create or replace function pg_temp.id(p text) returns uuid language sql as $$
  select current_setting('deskilo.test.' || p)::uuid
$$;
create or replace function pg_temp.org_of(p text) returns uuid language sql as $$
  select organisation_id from public.workspaces where id = pg_temp.id(p)
$$;
create or replace function pg_temp.as_user(p text, p_assistant boolean default false) returns void language sql as $$
  select set_config('request.jwt.claims',
    (jsonb_build_object('sub', current_setting('deskilo.test.' || p), 'role', 'authenticated')
       || case when p_assistant then '{"client_id": "an-assistant"}'::jsonb else '{}'::jsonb end)::text, true)
$$;
grant execute on all functions in schema pg_temp to authenticated;

-- ── an owner of two businesses makes one organisation of them ──
select pg_temp.as_user('owner_a');
set local role authenticated;
select set_config('deskilo.test.org', public.create_organisation(pg_temp.id('w1'), 'Atelier group')::text, false);
select public.add_business_to_organisation(pg_temp.id('org'), pg_temp.id('w2'));
reset role;
select is(pg_temp.org_of('w1'), pg_temp.id('org'), 'the head is a house of its organisation');
select is(pg_temp.org_of('w2'), pg_temp.id('org'), 'and so is the business its owner added');

-- ── a twin follows its business ──
-- test data written as the server: London's development twin, paired after
insert into public.workspaces (name, country_code, currency_code, timezone, created_by, pair_id, environment)
select 'ORG-LONDON (dev)', 'GB', 'GBP', 'Europe/London', pg_temp.id('owner_a'),
       '00000000-0000-4000-8000-0000000040aa', 'dev';
update public.workspaces set pair_id = '00000000-0000-4000-8000-0000000040aa' where id = pg_temp.id('w2');
select is((select organisation_id from public.workspaces where name = 'ORG-LONDON (dev)'), pg_temp.id('org'),
  'a twin follows its business into the organisation');

-- ── who is refused ──
select pg_temp.as_user('owner_b');
set local role authenticated;
select throws_ok(format('select public.add_business_to_organisation(%L, %L)', pg_temp.id('org'), pg_temp.id('w3')),
  '42501', 'only an owner of this business may do this', 'an owner of one business only adds it to no organisation');
reset role;
select pg_temp.as_user('owner_a');
set local role authenticated;
select throws_ok(format('select public.add_business_to_organisation(%L, %L)', pg_temp.id('org'), pg_temp.id('w3')),
  '42501', 'only an owner of this business may do this', 'nor does an owner of the head add a business of another');
select throws_ok(format('select public.create_organisation(%L, %L)', pg_temp.id('w2'), 'Again'),
  '22023', 'this business is already in an organisation', 'a house is in one organisation at a time');
-- the API does not write a business's organisation, an owner's neither
select throws_ok(format('update public.workspaces set organisation_id = null where id = %L', pg_temp.id('w2')),
  '42501', null, 'only the server writes the organisation of a business');
reset role;

-- ── who reads it ──
select pg_temp.as_user('member_m');
set local role authenticated;
select is((select name from public.organisations where id = pg_temp.id('org')), 'Atelier group',
  'a member of a house reads the organisation''s name');
select is(jsonb_array_length(public.my_organisations_v1() -> 0 -> 'houses'), 1,
  'and is shown only the houses they are a member of');
select is(public.my_organisations_v1() -> 0 -> 'houses' -> 0 ->> 'role', 'member',
  'with their role there');
reset role;
select pg_temp.as_user('outsider');
set local role authenticated;
select is((select count(*)::int from public.organisations), 0, 'someone outside reads no organisation');
select is(public.my_organisations_v1(), '[]'::jsonb, 'and is in none');
reset role;
select pg_temp.as_user('owner_a', true);
set local role authenticated;
select throws_ok(format('select public.rename_organisation(%L, %L)', pg_temp.id('org'), 'By an assistant'),
  '42501', 'only an owner of this business may do this', 'an assistant''s token is refused');
select is((select count(*)::int from public.organisations), 0, 'and reads no organisation');
reset role;

-- ── leaving ──
select pg_temp.as_user('owner_a');
set local role authenticated;
select throws_ok(format('select public.remove_business_from_organisation(%L)', pg_temp.id('w1')),
  '22023', 'the head leaves last', 'the head cannot leave while houses remain');
select public.remove_business_from_organisation(pg_temp.id('w2'));
reset role;
select is(pg_temp.org_of('w2'), null::uuid, 'a house leaves its organisation');
select is((select organisation_id from public.workspaces where name = 'ORG-LONDON (dev)'), null::uuid,
  'and its twin with it');
select is((select (name, currency_code, (select count(*) from public.members m where m.workspace_id = w.id))::text
             from public.workspaces w where w.id = pg_temp.id('w2')),
  '(ORG-LONDON,GBP,2)', 'its data stays as it was');

select * from finish();
rollback;
