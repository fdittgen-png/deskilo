-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2454 / 0486: a feature declared for some countries is unavailable in
-- another one, the stored switch is kept, and every other feature answers as
-- before. Real roles. The EU list is the eu_member rows of the tax reference.
begin;
select plan(11);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;
create function pg_temp.u(n int) returns uuid language sql as $$
  select ('00000000-0000-4000-8000-00002454' || lpad(n::text, 4, '0'))::uuid;
$$;
create function pg_temp.on(p_ws text, p_key text) returns boolean language plpgsql as $$
declare v boolean;
begin
  perform pg_temp.act_as(pg_temp.u(1));
  select public.feature_effective(p_ws::uuid, p_key) into v;
  reset role;
  return v;
end;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
values (pg_temp.u(1), '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
        'u1@countries.test', '', now(), now(), now());
select pg_temp.act_as(pg_temp.u(1));
select set_config('t.fr', public.create_workspace('Feature FR', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, true);
select set_config('t.gb', public.create_workspace('Feature GB', 'GB', 'GBP', 'Europe/London', 'dev', false, null)::text, true);
select set_config('t.de', public.create_workspace('Feature DE', 'DE', 'EUR', 'Europe/Berlin', 'dev', false, null)::text, true);
reset role;
-- every feature stored ON, so only the country can make a difference
update public.workspaces
   set feature_flags = (select jsonb_object_agg(k, true) from jsonb_object_keys(public.feature_registry()) k)
 where id in (current_setting('t.fr')::uuid, current_setting('t.gb')::uuid, current_setting('t.de')::uuid);

select is(public.feature_registry() -> 'recapitulativeStatement' -> 'countries', '["@eu"]'::jsonb, 'the registry says: the EU');
select ok(public.feature_available_in('FR', 'recapitulativeStatement'), 'France is in the Union');
select ok(public.feature_available_in('de', 'recapitulativeStatement'), 'so is Germany, in lower case too');
select ok(not public.feature_available_in('GB', 'recapitulativeStatement'), 'the United Kingdom is not');
select ok(public.feature_available_in('', 'recapitulativeStatement'), 'an unknown country restricts nothing');
select ok(public.feature_available_in('GB', 'vatDeclarations'), 'a feature with no country list is available everywhere');

select ok(pg_temp.on(current_setting('t.fr'), 'recapitulativeStatement'), 'a French space has the statement: no change');
select ok(pg_temp.on(current_setting('t.de'), 'recapitulativeStatement'), 'and a German one');
select ok(not pg_temp.on(current_setting('t.gb'), 'recapitulativeStatement'), 'a British space has it stored ON and effectively off');
select ok(pg_temp.on(current_setting('t.gb'), 'vatDeclarations'), 'while its other features answer as they always did');
select is((select feature_flags ->> 'recapitulativeStatement' from public.workspaces where id = current_setting('t.gb')::uuid), 'true',
  'and the stored switch is untouched');

select * from finish();
rollback;
