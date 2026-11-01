-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2488 / 0634: the countries a workspace can be created in are the `country`
-- rows of the tax reference store. The shape refuses what the app could not
-- read (a lower-case or missing currency, a banking scheme with no payment
-- form, an unknown field, a zone that is not a name), and the 32 seeded rows
-- are the catalogue the app has shipped since #711, value for value.
begin;
select plan(10);

create function pg_temp.refused(p_sql text) returns boolean language plpgsql as $$
begin
  execute p_sql;
  return false;
exception when check_violation then
  return true;
end;
$$;
grant execute on all functions in schema pg_temp to authenticated, anon;

select is((select count(*)::int from public.tax_reference where domain = 'country'), 32,
  'the catalogue has its 32 countries');

select is((select value from public.tax_reference where domain = 'country' and country = 'FR' and key = 'catalogue'),
  '{"currency":"EUR","time_zone":"Europe/Paris","banking_scheme":"sepa","position":8}'::jsonb,
  'France is euro, Paris, SEPA, 8th');
select is((select array[value ->> 'banking_scheme', value ->> 'currency'] from public.tax_reference
            where domain = 'country' and country = 'CH'), array['ch', 'CHF'], 'Switzerland has its own banking scheme');
select is((select array_agg(country order by (value ->> 'position')::int) from public.tax_reference where domain = 'country'),
  array['AT','BE','CY','DE','EE','ES','FI','FR','GR','HR','IE','IT','LT','LU','LV','MT','NL','PT','SI','SK',
        'BG','CZ','DK','HU','PL','RO','SE','CH','NO','GB','US','CA'],
  'the order is the one the creation form has always listed');
select is((select count(*)::int from public.tax_reference where domain = 'country' and confirmed), 0,
  'they arrive unconfirmed: creation defaults, not a legal fact');

select lives_ok($$insert into public.tax_reference (domain, country, key, valid_from, value, source, confirmed)
  values ('country', 'AU', 'catalogue', '2026-01-01',
          '{"currency":"AUD","time_zone":"Australia/Sydney","banking_scheme":"sepa"}'::jsonb, 'test', false)$$,
  'a country can be added with its currency, zone and scheme (position optional)');
select is(pg_temp.refused($$insert into public.tax_reference (domain, country, key, valid_from, value, source, confirmed)
  values ('country', 'NZ', 'catalogue', '2026-01-01',
          '{"currency":"nzd","time_zone":"Pacific/Auckland","banking_scheme":"sepa"}'::jsonb, 'test', false)$$), true,
  'a lower-case currency is refused');
select is(pg_temp.refused($$insert into public.tax_reference (domain, country, key, valid_from, value, source, confirmed)
  values ('country', 'NZ', 'catalogue', '2026-01-01',
          '{"currency":"NZD","time_zone":"Pacific/Auckland","banking_scheme":"swift"}'::jsonb, 'test', false)$$), true,
  'a banking scheme the app has no payment form for is refused');
select is(pg_temp.refused($$insert into public.tax_reference (domain, country, key, valid_from, value, source, confirmed)
  values ('country', 'NZ', 'catalogue', '2026-01-01',
          '{"currency":"NZD","time_zone":"Pacific/Auckland","banking_scheme":"sepa","vat":20}'::jsonb, 'test', false)$$), true,
  'a field the shape does not know is refused');
select is(pg_temp.refused($$insert into public.tax_reference (domain, country, key, valid_from, value, source, confirmed)
  values ('country', 'NZ', 'catalogue', '2026-01-01',
          '{"currency":"NZD","time_zone":"not a zone","banking_scheme":"sepa"}'::jsonb, 'test', false)$$), true,
  'a time zone that is not a name is refused');

select * from finish();
rollback;
