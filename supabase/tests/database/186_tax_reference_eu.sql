-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #2478 (C2 of #2476): is_eu_country / eu_country_code read the eu_member
-- rows. Same answers as the array they replaced for a fixed list of codes
-- (the list the Dart golden pins), and the answer follows the data: a
-- member added or closed from today changes it, an alias row is the only
-- thing that makes EL be GR.
begin;
select plan(9);

select is(
  (select count(*)::int from unnest(array[
    'AT','BE','BG','CY','CZ','DE','DK','EE','EL','ES','FI','FR','GB','GR','HR','HU','IE','IS','IT','LI',
    'LT','LU','LV','MC','MT','NL','NO','PL','PT','RO','SE','SI','SK','CH','CA','US','XI','TR','','el',' gr ']) c
    where public.is_eu_country(c)),
  30,
  'the member set is the old array: 27 members, EL, el and " gr " by alias or case');
select is((select count(*)::int from public.tax_reference where domain = 'eu_member' and key = 'member'), 27, '27 member rows');
select is(public.eu_country_code(' el '), 'GR', 'the alias row turns EL into GR');
select is(public.eu_country_code('de'), 'DE', 'any other code is only upper-cased');
select ok(not public.is_eu_country(null) and not public.is_eu_country(''), 'nothing is not a member');

-- The answer follows the data (rolled back with the file).
insert into public.tax_reference (domain, country, key, valid_from, value, source, confirmed)
values ('eu_member', 'GB', 'member', current_date, '{}'::jsonb, 'a test row', false);
select ok(public.is_eu_country('GB'), 'a member row in force today makes the country a member');
update public.tax_reference set valid_to = current_date + 1 where domain = 'eu_member' and country = 'GB';
select ok(public.is_eu_country('GB'), 'still a member until the row closes');
update public.tax_reference set valid_from = current_date - 1, valid_to = current_date
 where domain = 'eu_member' and country = 'GB';
select ok(not public.is_eu_country('GB'), 'a closed row is no member');

-- The shape check knows the alias and refuses a malformed one.
select ok(public.tax_reference_valid('eu_member', '{"alias_of":"GR"}'::jsonb)
          and not public.tax_reference_valid('eu_member', '{"alias_of":"grc"}'::jsonb)
          and not public.tax_reference_valid('eu_member', '{"x":1}'::jsonb),
          'eu_member is {} or {alias_of: ISO code}');

select * from finish();
rollback;
