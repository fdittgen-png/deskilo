-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #4042 (0783) -- public.plans is retired: tariffs are fee bands, the
-- export holds no plan, a configuration that still holds plans applies
-- everything else and writes no plan, a house carries and fences none, and
-- a business is priced by its fee bands. Rolled back.
begin;
select plan(6);

-- the pricing section of the last readiness read
create or replace function pg_temp.pricing() returns text language sql as $$
  select coalesce((select x->>'state' from jsonb_path_query(current_setting('deskilo.pl.ready')::jsonb,
                     'strict $.**') x where jsonb_typeof(x) = 'object' and x->>'section' = 'pricing' limit 1), 'absent')
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
values ('00000000-0000-4000-8000-000000004042', '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated', 'plans-4042@deskilo.test', '', now(), now(), now());
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-4000-8000-000000004042", "role": "authenticated"}', false);
set local role authenticated;
select set_config('deskilo.pl.a', public.create_workspace('PLANS-A', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, false);
select set_config('deskilo.pl.b', public.create_workspace('PLANS-B', 'FR', 'EUR', 'Europe/Paris', 'dev', false, null)::text, false);
reset role;
-- test data written as the server: A has a plan and no fee band
delete from public.fee_bands where workspace_id = current_setting('deskilo.pl.a')::uuid;
insert into public.plans (workspace_id, name, base_fee_cents, included_half_days, overage_fee_cents, active)
values (current_setting('deskilo.pl.a')::uuid, 'Resident', 25000, 40, 1500, true);
update public.workspaces set subscription_levels = '{}'::jsonb where id = current_setting('deskilo.pl.a')::uuid;

select is((select count(*)::int from jsonb_array_elements(public.deployable_entities()) e,
                  jsonb_array_elements_text(e.value->'tables') t where t.value = 'plans'), 0,
  'no entity carries plans');
select is((select count(*)::int from jsonb_object_keys(public.organisation_house_fenced_amounts()) k where k = 'plans'), 0,
  'a house fences no plan amount');

set local role authenticated;
select set_config('deskilo.pl.export', public.export_workspace_configuration(current_setting('deskilo.pl.a')::uuid)::text, false);
select public.import_workspace_configuration(current_setting('deskilo.pl.b')::uuid,
  jsonb_build_object('workspace', '{}'::jsonb, 'tables',
    jsonb_build_object('plans', jsonb_build_array(jsonb_build_object('name', 'Resident', 'base_fee_cents', 25000)))),
  'merge');
reset role;
select is(current_setting('deskilo.pl.export')::jsonb->'tables' ? 'plans', false, 'the export holds no plan');
select is((select count(*)::int from public.plans where workspace_id = current_setting('deskilo.pl.b')::uuid), 0,
  'a configuration that still holds plans writes none');

select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-4000-8000-000000004042", "role": "authenticated"}', false);
set local role authenticated;
select set_config('deskilo.pl.ready', public.workspace_readiness(current_setting('deskilo.pl.a')::uuid)::text, false);
reset role;
select is(pg_temp.pricing(), 'needs_configuration', 'a business with a plan and no fee band is not priced');
insert into public.fee_bands (workspace_id, from_pct, to_pct, fee_cents, overage_fee_cents)
values (current_setting('deskilo.pl.a')::uuid, 0, 100, 4000, 0);
set local role authenticated;
select set_config('deskilo.pl.ready', public.workspace_readiness(current_setting('deskilo.pl.a')::uuid)::text, false);
reset role;
select is(pg_temp.pricing(), 'ready', 'its fee bands price it');

select * from finish();
rollback;
