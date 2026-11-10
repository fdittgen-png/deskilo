-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3549/#3550 (0710): set_business_kind writes the kind pair without the
-- configurableSettings gate, for whoever holds manageConfiguration. A member
-- without it is refused, an unknown kind is refused, the primary is never
-- also a further kind, and a swap (primary <-> further kind) succeeds.
-- Rolled back.
begin;
select plan(9);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- The error set_business_kind raises in workspace b1, or null.
create function pg_temp.kind_error(p_kind text, p_more text) returns text language plpgsql as $$
begin
  perform public.set_business_kind('00000000-0000-4000-8000-0000003550b1', p_kind, p_more);
  return null;
exception when others then return sqlerrm;
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

create function pg_temp.current(p_key text) returns text language sql as $$
  select public.setting_value('00000000-0000-4000-8000-0000003550b1', p_key) #>> '{}'
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000003550a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner-3550@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000003550a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'member-3550@deskilo.test', '', now(), now(), now());
-- configurableSettings is NOT switched on: the RPC must not need it.
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags) values
 ('00000000-0000-4000-8000-0000003550b1', 'Kinds 3550', 'FR', 'EUR', 'Europe/Paris', '00000000-0000-4000-8000-0000003550a1', '{}');
insert into public.members (workspace_id, user_id, is_owner, is_admin, joined_at) values
 ('00000000-0000-4000-8000-0000003550b1', '00000000-0000-4000-8000-0000003550a1', true, true, '2026-01-01'),
 ('00000000-0000-4000-8000-0000003550b1', '00000000-0000-4000-8000-0000003550a2', false, false, '2026-01-01');

select pg_temp.act_as('00000000-0000-4000-8000-0000003550a1');
select is(pg_temp.kind_error('practice', 'studio'), null,
          'the owner sets the kind with configurableSettings off');
select is(pg_temp.current('business.kind') || '|' || pg_temp.current('business.more_kinds'),
          'practice|studio', 'both keys are written');
select is(pg_temp.kind_error('studio', 'practice'), null, 'a swap of primary and further kind succeeds');
select is(pg_temp.current('business.kind') || '|' || pg_temp.current('business.more_kinds'),
          'studio|practice', 'the swap is stored');
select is(pg_temp.kind_error('salon', 'salon, studio'), null, 'a further kind equal to the primary is dropped');
select is(pg_temp.current('business.more_kinds'), 'studio', 'the primary is not also a further kind');
select alike(pg_temp.kind_error('bakery', ''), '%unknown business kind%', 'an unknown kind is refused');

select pg_temp.act_as('00000000-0000-4000-8000-0000003550a2');
select alike(pg_temp.kind_error('coworking', ''), '%not allowed%',
             'a member without manageConfiguration is refused');
reset role;
select ok(not has_function_privilege('anon', 'public.set_business_kind(uuid, text, text)', 'execute'),
          'anon cannot call it');

select * from finish();
rollback;
