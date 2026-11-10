-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #3549 (0703): the business kinds are data; a workspace says its kind in two
-- registry settings. Every workspace reads coworking until it says otherwise;
-- an unknown kind is refused, and so is a further kind that repeats the
-- primary one; a member without manageConfiguration cannot set it; another
-- tenant reads nothing; no client writes the kinds. Rolled back.
begin;
select plan(12);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

-- The error [p_key] := [p_value] raises in workspace b1, or null.
create function pg_temp.set_error(p_key text, p_value text) returns text language plpgsql as $$
begin
  perform public.set_setting('00000000-0000-4000-8000-0000003549b1', p_key, to_jsonb(p_value), '');
  return null;
exception when others then return sqlerrm;
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000003549a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner-3549@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000003549a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'member-3549@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000003549a3', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'other-3549@deskilo.test', '', now(), now(), now());
insert into public.workspaces (id, name, country_code, currency_code, timezone, created_by, feature_flags) values
 ('00000000-0000-4000-8000-0000003549b1', 'Kinds 3549 A', 'FR', 'EUR', 'Europe/Paris', '00000000-0000-4000-8000-0000003549a1', '{"configurableSettings": true}'),
 ('00000000-0000-4000-8000-0000003549b2', 'Kinds 3549 B', 'FR', 'EUR', 'Europe/Paris', '00000000-0000-4000-8000-0000003549a3', '{"configurableSettings": true}');
insert into public.members (workspace_id, user_id, is_owner, is_admin, joined_at) values
 ('00000000-0000-4000-8000-0000003549b1', '00000000-0000-4000-8000-0000003549a1', true, true, '2026-01-01'),
 ('00000000-0000-4000-8000-0000003549b1', '00000000-0000-4000-8000-0000003549a2', false, false, '2026-01-01'),
 ('00000000-0000-4000-8000-0000003549b2', '00000000-0000-4000-8000-0000003549a3', true, true, '2026-01-01');

-- the registry
select is((select array_agg(code order by sort_order) from public.business_kinds),
          array['coworking','studio','practice','salon','service'], 'the five kinds are seeded in order');
select is((select default_value #>> '{}' from public.setting_definitions where key = 'business.kind'),
          'coworking', 'every workspace reads coworking until it says otherwise');
select is((select edit_permission from public.setting_definitions where key = 'business.more_kinds'),
          'manageConfiguration', 'the kind is changed with manageConfiguration');

-- the owner sets it
select pg_temp.act_as('00000000-0000-4000-8000-0000003549a1');
select is(pg_temp.set_error('business.kind', 'practice'), null, 'the owner sets a known kind');
select like(pg_temp.set_error('business.kind', 'bakery'), '%unknown business kind%', 'an unknown kind is refused');
select is(pg_temp.set_error('business.more_kinds', 'studio, salon'), null, 'further known kinds are kept');
select like(pg_temp.set_error('business.more_kinds', 'studio,practice'), '%primary business kind%',
            'a further kind may not repeat the primary one');
select like(pg_temp.set_error('business.more_kinds', 'studio,studio'), '%listed twice%',
            'a further kind is not listed twice');
select ok(not has_table_privilege('authenticated', 'public.business_kinds', 'insert'),
          'no client adds a kind');

-- a member without the permission, and another tenant
select pg_temp.act_as('00000000-0000-4000-8000-0000003549a2');
select like(pg_temp.set_error('business.kind', 'salon'), '%not allowed%',
            'a member without manageConfiguration cannot set it');
select pg_temp.act_as('00000000-0000-4000-8000-0000003549a3');
select is((select count(*)::int from public.setting_values
            where workspace_id = '00000000-0000-4000-8000-0000003549b1' and key like 'business.%'),
          0, 'another tenant reads none of its kind settings');
select is((select count(*)::int from public.business_kinds), 5, 'everyone signed in reads the kinds');

select * from finish();
rollback;
