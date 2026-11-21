-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4168 (A1, 0835): what a kind's confirmation did, observed on the server. The
-- stage adapter refuses a profile that is no longer the one reviewed (nothing
-- written, the refusal recorded), saves the kind and records that stage, writes
-- the confirmed features against the read-set and records a refused write as
-- refused while the kind stays saved; the same request answers the same outcome
-- and writes nothing again; a recorded stage is never changed or deleted; only
-- the owner of THAT business reads the events and nobody writes them directly.
begin;
select plan(21);

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
select x, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'kc4168-' || x || '@deskilo.test', '', now(), now(), now()
  from unnest(array['00000000-0000-4000-8000-000000048601','00000000-0000-4000-8000-000000048602','00000000-0000-4000-8000-000000048603']::uuid[]) x;
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags)
values ('00000000-0000-4000-8000-000000048610', 'Kind A', 'FR', 'EUR', 'Europe/Paris', '00000000-0000-4000-8000-000000048601', '{"configurableSettings": true}'),
       ('00000000-0000-4000-8000-000000048611', 'Kind B', 'FR', 'EUR', 'Europe/Paris', '00000000-0000-4000-8000-000000048603', '{"configurableSettings": true}');
insert into public.members (workspace_id, user_id, is_owner, is_admin, status, joined_at)
values ('00000000-0000-4000-8000-000000048610', '00000000-0000-4000-8000-000000048601', true, true, 'active', '2026-01-01'),
       ('00000000-0000-4000-8000-000000048610', '00000000-0000-4000-8000-000000048602', false, false, 'active', '2026-01-01'),
       ('00000000-0000-4000-8000-000000048611', '00000000-0000-4000-8000-000000048603', true, true, 'active', '2026-01-01');

create function pg_temp.as_user(p_user text, p_sql text, p_client text default null) returns text language plpgsql as $f$
declare v text;
begin
  perform set_config('request.jwt.claims',
    (json_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::jsonb
      || case when p_client is null then '{}'::jsonb else jsonb_build_object('client_id', p_client) end)::text, true);
  perform set_config('request.jwt.claim.sub', p_user, true);
  execute 'set local role authenticated';
  execute p_sql into v;
  execute 'reset role';
  return coalesce(nullif(v, ''), 'ok');
exception when others then
  execute 'reset role';
  return 'ERR ' || sqlstate;
end $f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create function pg_temp.apply(p_user text, p_request text, p_kind text, p_version text, p_digest text,
                              p_flags text default '{}', p_expected text default null, p_client text default null)
returns text language sql as $f$
  select pg_temp.as_user(p_user, format($s$select public.apply_business_kind_v1(%L, %L, %L, '', %s, %L, %L::jsonb, %L::jsonb)::text$s$,
    '00000000-0000-4000-8000-000000048610', p_request, p_kind, p_version, p_digest, p_flags, p_expected), p_client)
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select set_config('t.ver', (select profile_version::text from public.business_kinds where code = 'freelancer'), false);
select set_config('t.dig', (select profile_digest from public.business_kinds where code = 'freelancer'), false);

-- the confirmation: the kind and its features
select set_config('t.a', pg_temp.apply('00000000-0000-4000-8000-000000048601', '00000000-0000-4000-8000-000000048640', 'freelancer', current_setting('t.ver'), current_setting('t.dig'),
  '{"placeBooking": false, "invoicing": true}', '{"placeBooking": true}'), false);
select is(current_setting('t.a')::jsonb ->> 'kind_stage' || '|' || (current_setting('t.a')::jsonb ->> 'flags_stage'), 'applied|applied',
  'the owner confirms the kind and its features: both stages applied');
select is((select setting_value from (select public.setting_value('00000000-0000-4000-8000-000000048610', 'business.kind') #>> '{}' as setting_value) s), 'freelancer', 'the kind is saved');
select is((select count(*)::int from public.configuration_choice_events where workspace_id = '00000000-0000-4000-8000-000000048610' and request_id = '00000000-0000-4000-8000-000000048640'), 2, 'one event per stage');
select is((select source ->> 'profile_digest' from public.configuration_choice_events where request_id = '00000000-0000-4000-8000-000000048640' and stage = 'kind'),
  current_setting('t.dig'), 'the event names the reviewed source: kind, version and digest');
select is((select (changed -> 'placeBooking' ->> 'before_present')::boolean from public.configuration_choice_events where request_id = '00000000-0000-4000-8000-000000048640' and stage = 'flags'),
  false, 'the features stage records the raw value before: here the flag was absent, which is not false');
select is((select changed -> 'placeBooking' -> 'after' from public.configuration_choice_events where request_id = '00000000-0000-4000-8000-000000048640' and stage = 'flags'),
  'false'::jsonb, 'and after');

-- the same request again
select is(pg_temp.apply('00000000-0000-4000-8000-000000048601', '00000000-0000-4000-8000-000000048640', 'freelancer', current_setting('t.ver'), current_setting('t.dig'),
  '{"placeBooking": false, "invoicing": true}', '{"placeBooking": true}')::jsonb ->> 'replayed', 'true',
  'the same request answers what it recorded');
select is((select count(*)::int from public.configuration_choice_events where workspace_id = '00000000-0000-4000-8000-000000048610'), 2, 'and records nothing again');

-- a profile that is no longer the one reviewed
select is(pg_temp.apply('00000000-0000-4000-8000-000000048601', '00000000-0000-4000-8000-000000048641', 'practice', '1', 'not-the-digest')::jsonb ->> 'refusal', 'profile_changed',
  'a profile other than the reviewed one is refused, with its typed reason');
select is(public.setting_value('00000000-0000-4000-8000-000000048610', 'business.kind') #>> '{}', 'freelancer', 'and nothing is written');
select is((select outcome || '|' || refusal from public.configuration_choice_events where request_id = '00000000-0000-4000-8000-000000048641' and stage = 'kind'),
  'refused|profile_changed', 'the refusal is recorded');

-- the read-set moved meanwhile: the kind is saved, the features refused
select is(pg_temp.apply('00000000-0000-4000-8000-000000048601', '00000000-0000-4000-8000-000000048642', 'freelancer', current_setting('t.ver'), current_setting('t.dig'),
  '{"invoicing": false}', '{"invoicing": false}')::jsonb ->> 'flags_stage', 'refused',
  'features planned on a read-set that moved are refused while the kind stays saved');
select is((select refusal from public.configuration_choice_events where request_id = '00000000-0000-4000-8000-000000048642' and stage = 'flags'), 'DK409', 'with the typed refusal recorded');

-- who may
select is(pg_temp.apply('00000000-0000-4000-8000-000000048602', '00000000-0000-4000-8000-000000048643', 'freelancer', current_setting('t.ver'), current_setting('t.dig')), 'ERR 42501', 'an ordinary member is refused');
select is(pg_temp.apply('00000000-0000-4000-8000-000000048601', '00000000-0000-4000-8000-000000048644', 'freelancer', current_setting('t.ver'), current_setting('t.dig'), '{}', null, 'assistant'), 'ERR 42501', 'an assistant session is refused');
select is((select count(*)::int from public.configuration_choice_events where request_id in ('00000000-0000-4000-8000-000000048643', '00000000-0000-4000-8000-000000048644')), 0, 'and neither leaves an event');

-- the record
select throws_ok($$update public.configuration_choice_events set outcome = 'applied'$$, 'DKK02',
  'a recorded configuration stage is never changed or deleted', 'a recorded stage is never changed');
select throws_ok($$delete from public.configuration_choice_events$$, 'DKK02',
  'a recorded configuration stage is never changed or deleted', 'nor deleted');
select ok(not has_table_privilege('authenticated', 'public.configuration_choice_events', 'insert'), 'no client writes an event');
select is(pg_temp.as_user('00000000-0000-4000-8000-000000048601', $q$select count(*)::text from public.configuration_choice_events$q$), '5',
  'the owner reads the events of their business: two stages, the refusal and two more');
select is(pg_temp.as_user('00000000-0000-4000-8000-000000048602', $q$select count(*)::text from public.configuration_choice_events$q$), '0',
  'an ordinary member reads none');

select * from finish();
rollback;
