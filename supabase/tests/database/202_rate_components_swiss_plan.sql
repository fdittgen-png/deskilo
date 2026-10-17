-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2539 / 0455: the Canadian tax components and the Swiss planned rate change
-- are reference data. (1) vat_percent_components reads `rate_component` rows
-- (the seeded ones answer exactly as the old `case` did; a row added in the
-- test is honoured, a version that ended or has not begun is not; a split
-- that does not add up to its rate is refused by the shape). (2) The Swiss
-- 2028 rates are two PROPOSED versions: the 2024 versions end on 2028-01-01,
-- the rates in force today are untouched, a member cannot change or confirm
-- them (the direct UPDATE changes no row: read back), the platform owner
-- withdraws one (its predecessor is open again) and confirms the other.
-- Rolled back.
begin;
select plan(36);

create function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000002539a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner-2539@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000002539a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'member-2539@deskilo.test', '', now(), now(), now());
delete from public.platform_admins;
insert into public.platform_admins (user_id) values ('00000000-0000-4000-8000-0000002539a1');

-- ── 1. the seeded components answer as the old case did ────────────────
select is(public.vat_percent_components('CA', 5), '[{"scheme":"GST","authority":"CA","percent":5}]'::jsonb, 'AB BC MB NT NU SK YT: GST alone');
select is(public.vat_percent_components('CA', 13), '[{"scheme":"HST","authority":"CA","percent":13}]'::jsonb, 'Ontario: HST 13');
select is(public.vat_percent_components('CA', 14), '[{"scheme":"HST","authority":"CA","percent":14}]'::jsonb, 'Nova Scotia: HST 14');
select is(public.vat_percent_components('ca', 15), '[{"scheme":"HST","authority":"CA","percent":15}]'::jsonb, 'NB NL PE: HST 15, the country in any case');
select is(public.vat_percent_components('CA', 14.975),
          '[{"scheme":"GST","authority":"CA","percent":5},{"scheme":"QST","authority":"CA-QC","percent":9.975}]'::jsonb, 'Quebec: GST then QST');
select is(public.vat_percent_components('CA', 12),
          '[{"scheme":"GST","authority":"CA","percent":5},{"scheme":"PST","authority":"CA-PST","percent":7}]'::jsonb, 'legacy GST + PST 7');
select is(public.vat_percent_components('CA', 11),
          '[{"scheme":"GST","authority":"CA","percent":5},{"scheme":"PST","authority":"CA-PST","percent":6}]'::jsonb, 'legacy GST + PST 6');
select ok(public.vat_percent_components('CA', 7.5) is null, 'a rate with no row is not split');
select ok(public.vat_percent_components('DE', 14.975) is null, 'no other country is split');
select is((select count(*)::int from public.tax_reference where domain = 'rate_component' and country = 'CA' and confirmed), 7,
          'seven confirmed rows, each with its source');
select ok(not exists (select 1 from public.tax_reference where domain = 'rate_component' and btrim(source) = ''), 'every row has a source');

-- ── 2. a row added by the platform owner is honoured; the shape is enforced ──
select pg_temp.act_as('00000000-0000-4000-8000-0000002539a1');
select lives_ok($$select public.set_tax_reference('rate_component', 'CA', '7.5',
  '{"percent":7.5,"components":[{"scheme":"GST","authority":"CA","percent":5},{"scheme":"PST","authority":"CA-PST","percent":2.5}]}',
  'test source', true, '1900-01-01')$$, 'the owner adds a component row');
reset role;
select is(public.vat_percent_components('CA', 7.5) -> 1 ->> 'scheme', 'PST', 'the new row is read');
select is(public.vat_components_entry('CA', 7.5, 10000, 750) -> 'components' -> 1 ->> 'tax_cents', '250', 'and priced to the cent');
select pg_temp.act_as('00000000-0000-4000-8000-0000002539a1');
select throws_ok($$select public.set_tax_reference('rate_component', 'CA', '8',
  '{"percent":8,"components":[{"scheme":"GST","authority":"CA","percent":5}]}', 's', true, '1900-01-01')$$,
  'P0001', null, 'components that do not add up to the rate are refused');
select throws_ok($$select public.set_tax_reference('rate_component', 'CA', '8',
  '{"percent":8,"components":[]}', 's', true, '1900-01-01')$$,
  'P0001', null, 'an empty split is refused');
select throws_ok($$select public.set_tax_reference('rate_component', 'CA', '8',
  '{"percent":8,"components":[{"scheme":"","authority":"CA","percent":8}]}', 's', true, '1900-01-01')$$,
  'P0001', null, 'a component without a scheme is refused');
select throws_ok($$select public.set_tax_reference('rate_component', 'CA', '8',
  '{"percent":8,"components":[{"scheme":"GST","authority":"CA","percent":8,"x":1}]}', 's', true, '1900-01-01')$$,
  'P0001', null, 'a component with an unknown key is refused');
reset role;
-- A version that has not begun, and one that has ended, are not read.
insert into public.tax_reference (domain, country, key, valid_from, valid_to, value, source, confirmed) values
 ('rate_component', 'CA', '9', current_date + 30, null, '{"percent":9,"components":[{"scheme":"HST","authority":"CA","percent":9}]}', 'future', true),
 ('rate_component', 'CA', '10', '2000-01-01', '2001-01-01', '{"percent":10,"components":[{"scheme":"HST","authority":"CA","percent":10}]}', 'ended', true);
select ok(public.vat_percent_components('CA', 9) is null, 'a version that begins later is not read');
select ok(public.vat_percent_components('CA', 10) is null, 'a version that has ended is not read');

-- ── 3. the Swiss plan: proposed, nothing in force changes ──────────────
select is((select string_agg(key || ':' || valid_from || ':' || valid_to::text, ' ' order by key)
             from public.tax_reference
            where domain = 'rate' and country = 'CH' and valid_from = '2024-01-01' and key in ('standard', 'intermediate')),
          'intermediate:2024-01-01:2028-01-01 standard:2024-01-01:2028-01-01', 'the 2024 versions end where the 2028 ones begin');
select is((select string_agg(key || ':' || (value ->> 'percent') || ':' || confirmed::text, ' ' order by key)
             from public.tax_reference
            where domain = 'rate' and country = 'CH' and valid_from = '2028-01-01'),
          'intermediate:4.0:false standard:8.5:false', 'the 2028 rates are proposed, not confirmed');
select is((select string_agg(key || ':' || (value ->> 'percent'), ' ' order by key)
             from public.tax_reference
            where domain = 'rate' and country = 'CH' and key in ('standard', 'intermediate', 'reduced')
              and valid_from <= date '2027-12-31' and (valid_to is null or valid_to > date '2027-12-31')),
          'intermediate:3.8 reduced:2.6 standard:8.1', 'the rates in force until 2027-12-31 are the old ones');
select is((select count(*)::int from public.tax_reference
            where domain = 'rate' and country = 'CH' and key = 'reduced'), 1, 'the reduced rate is not touched');

-- A member reads the rows (positive control) but changes nothing, whatever the route.
select pg_temp.act_as('00000000-0000-4000-8000-0000002539a2');
select is((select count(*)::int from public.tax_reference where domain = 'rate' and country = 'CH' and valid_from = '2028-01-01'),
          2, 'a member reads the two proposed versions');
select throws_ok($$update public.tax_reference set confirmed = true
                    where domain = 'rate' and country = 'CH' and valid_from = '2028-01-01'$$,
  '42501', null, 'a member cannot update a version directly');
select throws_ok($$select public.confirm_tax_reference((select id from public.tax_reference
                    where domain = 'rate' and country = 'CH' and key = 'standard' and valid_from = '2028-01-01'), 'x')$$,
  'P0001', 'platform owners only', 'a member cannot confirm');
select throws_ok($$select public.withdraw_tax_reference((select id from public.tax_reference
                    where domain = 'rate' and country = 'CH' and key = 'standard' and valid_from = '2028-01-01'), 'x')$$,
  'P0001', 'platform owners only', 'a member cannot withdraw');
reset role;
select is((select count(*)::int from public.tax_reference
            where domain = 'rate' and country = 'CH' and valid_from = '2028-01-01' and not confirmed), 2,
          'read back: both versions are still there and still proposed');

-- The owner withdraws the standard rate (the vote failed) and confirms the other.
select pg_temp.act_as('00000000-0000-4000-8000-0000002539a1');
select lives_ok($$select public.withdraw_tax_reference((select id from public.tax_reference
                    where domain = 'rate' and country = 'CH' and key = 'standard' and valid_from = '2028-01-01'), 'The vote failed')$$,
  'the owner withdraws a proposed version');
select is(public.confirm_tax_reference((select id from public.tax_reference
                    where domain = 'rate' and country = 'CH' and key = 'intermediate' and valid_from = '2028-01-01'),
                    'Federal Gazette') ->> 'confirmed', 'true', 'the owner confirms the other');
select throws_ok($$select public.withdraw_tax_reference((select id from public.tax_reference
                    where domain = 'rate' and country = 'CH' and key = 'intermediate' and valid_from = '2028-01-01'), 'x')$$,
  'P0001', 'a confirmed version is history and is only superseded', 'a confirmed version is no longer withdrawable');
reset role;
-- Row readback of both acts.
select is((select count(*)::int from public.tax_reference
            where domain = 'rate' and country = 'CH' and key = 'standard' and valid_from = '2028-01-01'), 0,
          'the withdrawn version is gone');
select ok((select valid_to from public.tax_reference
            where domain = 'rate' and country = 'CH' and key = 'standard' and valid_from = '2024-01-01') is null,
          'and 8.1 % is open again');
select is((select confirmed::text || ':' || (value ->> 'percent') from public.tax_reference
            where domain = 'rate' and country = 'CH' and key = 'intermediate' and valid_from = '2028-01-01'),
          'true:4.0', 'the confirmed version keeps its value');
select is((select count(*)::int from public.database_authority_audit
            where (action = 'tax_reference_withdraw' and detail -> 'version' ->> 'key' = 'standard'
                   and detail -> 'version' ->> 'valid_from' = '2028-01-01')
               or (action = 'tax_reference_confirm' and detail ->> 'key' = 'intermediate'
                   and detail ->> 'valid_from' = '2028-01-01')), 2, 'both acts are audited');

select * from finish();
rollback;
