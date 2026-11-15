-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #4028 (0779) -- a configuration applied to a business in another
-- currency or country. The export states its source's currency and
-- country. EUR into GBP: the priced entities are refused with a reason
-- naming both currencies, the target keeps its validation threshold, the
-- rest is applied; in 'mirror' (a restore from a file) the business's own
-- prices, fee bands, rates and threshold stay. FR into IT in euros: `vat` is refused, the prices are
-- applied. The same currency and country, a payload that states neither,
-- and a deployment inside a pair apply as before. A template states its
-- owner business's currency at apply time. Rolled back.
begin;
select plan(21);

create or replace function pg_temp.act_as(p_user uuid) returns void language plpgsql as $act$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end
$act$;
create or replace function pg_temp.ws(p text) returns uuid language sql as $$
  select current_setting('deskilo.fence.' || p)::uuid
$$;
create or replace function pg_temp.refused(p_result jsonb) returns text language sql as $$
  select coalesce(string_agg(e->>'entity', ',' order by e->>'entity'), '')
    from jsonb_array_elements(coalesce(p_result->'refused', '[]'::jsonb)) e
$$;
grant execute on all functions in schema pg_temp to authenticated;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
values ('00000000-0000-4000-8000-000000004028', '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated', 'fence-owner@deskilo.test', '', now(), now(), now());

select pg_temp.act_as('00000000-0000-4000-8000-000000004028');
select set_config('deskilo.fence.' || k,
  public.create_workspace('FENCE-' || upper(k), c, cur, tz, env, false, null)::text, false)
  from (values ('paris', 'FR', 'EUR', 'Europe/Paris', 'dev'),
               ('london', 'GB', 'GBP', 'Europe/London', 'dev'),
               ('milan', 'IT', 'EUR', 'Europe/Rome', 'dev'),
               ('lyon', 'FR', 'EUR', 'Europe/Paris', 'dev'),
               ('leeds', 'GB', 'GBP', 'Europe/London', 'dev'),
               ('bristol', 'GB', 'GBP', 'Europe/London', 'dev'),
               ('york', 'GB', 'GBP', 'Europe/London', 'dev'),
               ('hull', 'GB', 'GBP', 'Europe/London', 'dev'),
               ('paris_prod', 'FR', 'EUR', 'Europe/Paris', 'prod')) v(k, c, cur, tz, env);
reset role;

-- test data written as the server: what Paris sells, and the rules it keeps
insert into public.vat_rates (workspace_id, label, percent, category, is_default, active)
values (pg_temp.ws('paris'), 'TVA 20 % fence', 20, 'S', false, true);
insert into public.plans (workspace_id, name, base_fee_cents, included_half_days, overage_fee_cents, active)
values (pg_temp.ws('paris'), 'Resident fence', 25000, 40, 1500, true);
insert into public.services (workspace_id, name, price_cents, active)
values (pg_temp.ws('paris'), 'Coffee fence', 250, true);
update public.workspaces set booking_rules = booking_rules || '{"granularity": "half_day"}'
 where id = pg_temp.ws('paris');
insert into public.validation_policies (workspace_id, event_type, required_count, admins_may_validate, min_amount_cents)
values (pg_temp.ws('paris'), 'lease_change', 1, true, 50000),
       (pg_temp.ws('london'), 'lease_change', 1, true, 7000);
-- York's own prices, rate and threshold, which a restore in mirror must keep
insert into public.vat_rates (workspace_id, label, percent, category, is_default, active)
values (pg_temp.ws('york'), 'VAT 20 % York', 20, 'S', false, true);
insert into public.plans (workspace_id, name, base_fee_cents, included_half_days, overage_fee_cents, active)
values (pg_temp.ws('york'), 'York plan', 18000, 20, 1200, true);
insert into public.services (workspace_id, name, price_cents, active)
values (pg_temp.ws('york'), 'York tea', 180, true);
insert into public.packages (workspace_id, name, days, price_cents, active)
values (pg_temp.ws('york'), 'York ten', 10, 15000, true);
delete from public.fee_bands where workspace_id = pg_temp.ws('york');
insert into public.fee_bands (workspace_id, from_pct, to_pct, fee_cents, overage_fee_cents)
values (pg_temp.ws('york'), 0, 100, 4000, 0);
insert into public.validation_policies (workspace_id, event_type, required_count, admins_may_validate, min_amount_cents)
values (pg_temp.ws('york'), 'lease_change', 1, true, 9000);
-- Paris's production half
update public.workspaces set pair_id = '00000000-0000-4000-8000-0000000040f1'
 where id in (pg_temp.ws('paris'), pg_temp.ws('paris_prod'));

select pg_temp.act_as('00000000-0000-4000-8000-000000004028');
select set_config('deskilo.fence.export', public.export_workspace_configuration(pg_temp.ws('paris'))::text, false);
select is((select (e->'workspace'->>'currency_code', e->'workspace'->>'country_code')::text
             from (select current_setting('deskilo.fence.export')::jsonb e) x),
  '(EUR,FR)', 'the export states its source''s currency and country');

-- ── EUR into GBP, FR into GB ──
select set_config('deskilo.fence.r_london', public.import_workspace_configuration(pg_temp.ws('london'),
  current_setting('deskilo.fence.export')::jsonb, 'merge')::text, false);
select is(pg_temp.refused(current_setting('deskilo.fence.r_london')::jsonb), 'services,tariffs,validation_rules,vat',
  'into another currency and country the priced entities, the threshold and the rates are named as refused');
select ok(exists (select 1 from jsonb_array_elements(current_setting('deskilo.fence.r_london')::jsonb->'refused') e
                   where e->>'entity' = 'services' and e->>'reason' like '%EUR%GBP%'),
  'the reason names both currencies');
select is((select count(*)::int from public.plans where workspace_id = pg_temp.ws('london') and name = 'Resident fence')
        + (select count(*)::int from public.services where workspace_id = pg_temp.ws('london') and name = 'Coffee fence'), 0,
  'no plan or service arrives as a bare number in another currency');
select is((select count(*)::int from public.vat_rates where workspace_id = pg_temp.ws('london') and label = 'TVA 20 % fence'), 0,
  'no tax rate arrives in another country');
select is((select booking_rules->>'granularity' from public.workspaces where id = pg_temp.ws('london')), 'half_day',
  'the rest is applied');
select is((select min_amount_cents from public.validation_policies
            where workspace_id = pg_temp.ws('london') and event_type = 'lease_change'), 7000,
  'the target keeps its own validation threshold');
select is((select (currency_code, country_code)::text from public.workspaces where id = pg_temp.ws('london')), '(GBP,GB)',
  'the import never writes the source''s currency or country');

-- ── a restore from a file is a mirror ──
select set_config('deskilo.fence.r_york', public.import_workspace_configuration(pg_temp.ws('york'),
  current_setting('deskilo.fence.export')::jsonb, 'mirror')::text, false);
select is(pg_temp.refused(current_setting('deskilo.fence.r_york')::jsonb), 'services,tariffs,validation_rules,vat',
  'a mirror names the same refusals');
select is((select (
    (select count(*) from public.plans where workspace_id = pg_temp.ws('york') and name = 'York plan' and active),
    (select count(*) from public.services where workspace_id = pg_temp.ws('york') and name = 'York tea' and active),
    (select count(*) from public.packages where workspace_id = pg_temp.ws('york') and name = 'York ten' and active),
    (select string_agg(fee_cents::text, ',') from public.fee_bands where workspace_id = pg_temp.ws('york')),
    (select count(*) from public.vat_rates where workspace_id = pg_temp.ws('york') and label = 'VAT 20 % York' and active),
    (select count(*) from public.plans where workspace_id = pg_temp.ws('york') and name = 'Resident fence'))::text),
  '(1,1,1,4000,1,0)', 'a mirror keeps the business''s own prices, fee bands and rates, and brings none');
select is((select min_amount_cents from public.validation_policies
            where workspace_id = pg_temp.ws('york') and event_type = 'lease_change'), 9000,
  'a mirror that re-writes the policies keeps the business''s own threshold');
select set_config('deskilo.fence.r_hull', public.import_workspace_configuration(pg_temp.ws('hull'),
  current_setting('deskilo.fence.export')::jsonb, 'mirror')::text, false);
select is((select min_amount_cents from public.validation_policies
            where workspace_id = pg_temp.ws('hull') and event_type = 'lease_change'), 0,
  'a policy new to the business arrives with no threshold: every amount asks');

-- ── FR into IT, in euros ──
select set_config('deskilo.fence.r_milan', public.import_workspace_configuration(pg_temp.ws('milan'),
  current_setting('deskilo.fence.export')::jsonb, 'merge')::text, false);
select is(pg_temp.refused(current_setting('deskilo.fence.r_milan')::jsonb), 'vat',
  'into another country in the same currency only the rates are refused');
select is((select (price_cents, (select count(*) from public.vat_rates r
                                  where r.workspace_id = pg_temp.ws('milan') and r.label = 'TVA 20 % fence'))::text
             from public.services where workspace_id = pg_temp.ws('milan') and name = 'Coffee fence'),
  '(250,0)', 'the prices are applied, the rates are not');

-- ── as before ──
select set_config('deskilo.fence.r_lyon', public.import_workspace_configuration(pg_temp.ws('lyon'),
  current_setting('deskilo.fence.export')::jsonb, 'merge')::text, false);
select is((select (current_setting('deskilo.fence.r_lyon')::jsonb ? 'refused',
                   (select count(*) from public.vat_rates where workspace_id = pg_temp.ws('lyon') and label = 'TVA 20 % fence'),
                   (select count(*) from public.services where workspace_id = pg_temp.ws('lyon') and name = 'Coffee fence'))::text),
  '(f,1,1)', 'the same currency and country: everything applied, nothing refused');
select set_config('deskilo.fence.r_leeds', public.import_workspace_configuration(pg_temp.ws('leeds'),
  jsonb_set(current_setting('deskilo.fence.export')::jsonb, '{workspace}',
    (current_setting('deskilo.fence.export')::jsonb->'workspace') - 'currency_code' - 'country_code'), 'merge')::text, false);
select is((select (current_setting('deskilo.fence.r_leeds')::jsonb ? 'refused',
                   (select count(*) from public.services where workspace_id = pg_temp.ws('leeds') and name = 'Coffee fence'))::text),
  '(f,1)', 'a payload that states neither applies as before');
select lives_ok(format('select public.deploy_entities(%L, %L, array[%L, %L, %L])',
    pg_temp.ws('paris'), pg_temp.ws('paris_prod'), 'vat', 'tariffs', 'services'),
  'a deployment inside a pair');
select is((select count(*)::int from public.services where workspace_id = pg_temp.ws('paris_prod') and name = 'Coffee fence')
        + (select count(*)::int from public.vat_rates where workspace_id = pg_temp.ws('paris_prod') and label = 'TVA 20 % fence'), 2,
  'carries prices and rates as before');

-- ── a template is its owner's ──
select set_config('deskilo.fence.tpl', public.save_workspace_as_template(pg_temp.ws('paris'), 'fence_4028', 'Fence')::text, false);
select set_config('deskilo.fence.r_bristol', public.apply_workspace_template(pg_temp.ws('bristol'),
  current_setting('deskilo.fence.tpl')::uuid)::text, false);
select ok(pg_temp.refused(current_setting('deskilo.fence.r_bristol')::jsonb) like '%services%',
  'a template from a business in euros has its prices refused in a business in pounds');
select is((select count(*)::int from public.services where workspace_id = pg_temp.ws('bristol') and name = 'Coffee fence'), 0,
  'and none arrives');
reset role;

-- ── the import never writes them ──
select is((select count(*)::int from public.workspaces
            where name like 'FENCE-%' and (currency_code, country_code) not in
              (('EUR', 'FR'), ('GBP', 'GB'), ('EUR', 'IT'))), 0,
  'no business changed currency or country');

select * from finish();
rollback;
