-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4501 (0993, audit MD-06 and MD-03): one currency reference gives the minor digits, and a code it does not hold
-- is refused, never read as two decimals; everyone signed in reads it and no one writes it. The tax administration's
-- write takes a currency of the reference, a time zone of the database and a country the store holds; a value as
-- stored before is kept when only something else changes, and rates, sources and wording stay free. Rolled back.
begin;
select plan(14);

create or replace function pg_temp.act_as(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', jsonb_build_object('sub', p_user, 'role', 'authenticated', 'aal', 'aal2')::text, true);
  execute 'set local role authenticated';
end;
$$;
create or replace function pg_temp.err(p_sql text) returns text language plpgsql as $f$
declare d text;
begin
  execute p_sql;
  return 'ok';
exception when others then
  get stacked diagnostics d = pg_exception_detail;
  return 'ERR ' || sqlstate || coalesce(' ' || nullif(d, ''), '');
end
$f$;
grant execute on all functions in schema pg_temp to authenticated, anon;

insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at) values
 ('00000000-0000-4000-8000-0000004501a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'owner-4501@deskilo.test', '', now(), now(), now()),
 ('00000000-0000-4000-8000-0000004501a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'member-4501@deskilo.test', '', now(), now(), now());
delete from public.platform_admins;
insert into public.platform_admins (user_id) values ('00000000-0000-4000-8000-0000004501a1');

-- the currency reference
select is(public.currency_minor_digits('JPY'), 0, 'a yen has no minor digits');
select is(public.currency_minor_digits(' kwd '), 3, 'a dinar has three, whatever the case');
select is(public.currency_minor_digits('EUR'), 2, 'a euro has two');
select is(pg_temp.err($$select public.currency_minor_digits('XYZ')$$),
  'ERR DKL02 {"reason": "currency", "currency": "XYZ"}', 'a code the reference does not hold is refused, not read as two');
select is((select withdrawn_on::text from public.currency_reference where code = 'HRK'), '2023-01-01',
  'a currency its country replaced carries the day it was withdrawn');

select pg_temp.act_as('00000000-0000-4000-8000-0000004501a2');
select is((select count(*)::int from public.currency_reference where business), 28, 'a member reads the business currencies');
select is(pg_temp.err($$insert into public.currency_reference (code, minor_digits) values ('XYZ', 2)$$), 'ERR 42501',
  'and writes none');
reset role;

-- the tax administration's codes
select pg_temp.act_as('00000000-0000-4000-8000-0000004501a1');
select is(pg_temp.err($$select public.set_tax_reference('country', 'FR', 'catalogue',
  '{"currency":"XYZ","time_zone":"Europe/Paris","banking_scheme":"sepa","position":8}', 'test', true, '2027-01-01')$$),
  'ERR DKL02 {"reason": "currency"}', 'a currency the reference does not hold is refused');
select is(pg_temp.err($$select public.set_tax_reference('country', 'FR', 'catalogue',
  '{"currency":"EUR","time_zone":"Mars/Olympus","banking_scheme":"sepa","position":8}', 'test', true, '2027-01-01')$$),
  'ERR DKL02 {"reason": "time_zone"}', 'so is a time zone the database does not know');
select is(pg_temp.err($$select public.set_tax_reference('threshold', 'QQ', 'small_business_next_year',
  '{"cents":100,"effect":"next_year","currency":"EUR"}', 'test', true, '2027-01-01')$$),
  'ERR DKL02 {"reason": "country"}', 'and a new series for a country the store does not hold');
select is(pg_temp.err($$select public.set_tax_reference('country', 'FR', 'catalogue',
  '{"currency":"EUR","time_zone":"Europe/Paris","banking_scheme":"sepa","position":9}', 'a new source', true, '2027-01-01')$$),
  'ok', 'a value of known codes is stored; its other fields stay free');
reset role;

-- a value stored before the lists keeps its code until it changes
update public.tax_reference set value = value || '{"currency":"ZZZ"}'
 where domain = 'country' and country = 'FR' and key = 'catalogue' and valid_from = '2027-01-01';
select pg_temp.act_as('00000000-0000-4000-8000-0000004501a1');
select is(pg_temp.err($$select public.set_tax_reference('country', 'FR', 'catalogue',
  '{"currency":"ZZZ","time_zone":"Europe/Paris","banking_scheme":"sepa","position":10}', 'test', true, '2028-01-01')$$),
  'ok', 'a stored code outside the list is kept when only the position changes');
select is(pg_temp.err($$select public.set_tax_reference('country', 'FR', 'catalogue',
  '{"currency":"ZZY","time_zone":"Europe/Paris","banking_scheme":"sepa","position":10}', 'test', true, '2029-01-01')$$),
  'ERR DKL02 {"reason": "currency"}', 'and refused once it changes to another unknown one');
select is(pg_temp.err($$select public.set_tax_reference('rate', 'FR', 'standard',
  '{"label":"Standard 21 %","percent":21,"group":"standard","category":"S","position":0}', 'Finance act', false, '2030-01-01')$$),
  'ok', 'a rate, with no code in it, is written as before');
reset role;

select * from finish();
rollback;
