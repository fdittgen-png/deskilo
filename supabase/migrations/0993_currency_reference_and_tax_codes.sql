-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
--
-- #4501 (audit MD-06, MD-03) -- one currency reference, and the tax administration's codes checked at the write.
--   * public.currency_reference   the currencies of ISO 4217 (funds, metals and test codes left out): each code, its minor digits, whether a
--                                 business may keep its books in it (the subset the pickers offer) and, for a currency
--                                 its country replaced, the day it stopped being legal tender. The app holds the same
--                                 rows (deskilo_money_kernel currencyReference; test/lint/currency_reference_parity_test
--                                 keeps them equal). A reference table: every authenticated person reads it, no one
--                                 writes it but a migration.
--   * currency_minor_digits       reads the reference and refuses a code it does not hold (DKL02 currency), where it
--                                 answered 2 for any code; it is the one the till, the standalone invoices, the stock
--                                 receipts and the exchange rates convert with.
--   * set_tax_reference           a value's currency is one of the reference, its time zone one of the database's, a
--                                 country it names (alias_of) and the country of a new series are countries the store
--                                 holds (its `country` rows); a value as stored before is kept when only something else
--                                 changes. Rates, sources and legal wording stay free. Anchored patch of the live body.

create table public.currency_reference (
  code text primary key check (code ~ '^[A-Z]{3}$'),
  minor_digits integer not null check (minor_digits between 0 and 4),
  business boolean not null default false,
  withdrawn_on date
);
select public.ensure_system_columns('currency_reference');

comment on table public.currency_reference is
  '#4501 -- the currencies an amount is read in, with their minor digits and lifecycle; the app''s currencyReference.';

insert into public.currency_reference (code, minor_digits, business, withdrawn_on) values
  ('AED', 2, false, null),
  ('AFN', 2, false, null),
  ('ALL', 2, false, null),
  ('AMD', 2, false, null),
  ('ANG', 2, false, null),
  ('AOA', 2, false, null),
  ('ARS', 2, false, null),
  ('AUD', 2, true, null),
  ('AWG', 2, false, null),
  ('AZN', 2, false, null),
  ('BAM', 2, false, null),
  ('BBD', 2, false, null),
  ('BDT', 2, false, null),
  ('BGN', 2, true, date '2026-01-01'),
  ('BHD', 3, false, null),
  ('BIF', 0, false, null),
  ('BMD', 2, false, null),
  ('BND', 2, false, null),
  ('BOB', 2, false, null),
  ('BRL', 2, true, null),
  ('BSD', 2, false, null),
  ('BTN', 2, false, null),
  ('BWP', 2, false, null),
  ('BYN', 2, false, null),
  ('BZD', 2, false, null),
  ('CAD', 2, true, null),
  ('CDF', 2, false, null),
  ('CHF', 2, true, null),
  ('CLP', 0, false, null),
  ('CNY', 2, true, null),
  ('COP', 2, false, null),
  ('CRC', 2, false, null),
  ('CUP', 2, false, null),
  ('CVE', 2, false, null),
  ('CZK', 2, true, null),
  ('DJF', 0, false, null),
  ('DKK', 2, true, null),
  ('DOP', 2, false, null),
  ('DZD', 2, false, null),
  ('EGP', 2, false, null),
  ('ERN', 2, false, null),
  ('ETB', 2, false, null),
  ('EUR', 2, true, null),
  ('FJD', 2, false, null),
  ('FKP', 2, false, null),
  ('GBP', 2, true, null),
  ('GEL', 2, false, null),
  ('GHS', 2, false, null),
  ('GIP', 2, false, null),
  ('GMD', 2, false, null),
  ('GNF', 0, false, null),
  ('GTQ', 2, false, null),
  ('GYD', 2, false, null),
  ('HKD', 2, true, null),
  ('HNL', 2, false, null),
  ('HRK', 2, true, date '2023-01-01'),
  ('HTG', 2, false, null),
  ('HUF', 2, true, null),
  ('IDR', 2, false, null),
  ('ILS', 2, true, null),
  ('INR', 2, true, null),
  ('IQD', 3, false, null),
  ('IRR', 2, false, null),
  ('ISK', 0, true, null),
  ('JMD', 2, false, null),
  ('JOD', 3, false, null),
  ('JPY', 0, true, null),
  ('KES', 2, false, null),
  ('KGS', 2, false, null),
  ('KHR', 2, false, null),
  ('KMF', 0, false, null),
  ('KPW', 2, false, null),
  ('KRW', 0, true, null),
  ('KWD', 3, false, null),
  ('KYD', 2, false, null),
  ('KZT', 2, false, null),
  ('LAK', 2, false, null),
  ('LBP', 2, false, null),
  ('LKR', 2, false, null),
  ('LRD', 2, false, null),
  ('LSL', 2, false, null),
  ('LYD', 3, false, null),
  ('MAD', 2, false, null),
  ('MDL', 2, false, null),
  ('MGA', 2, false, null),
  ('MKD', 2, false, null),
  ('MMK', 2, false, null),
  ('MNT', 2, false, null),
  ('MOP', 2, false, null),
  ('MRU', 2, false, null),
  ('MUR', 2, false, null),
  ('MVR', 2, false, null),
  ('MWK', 2, false, null),
  ('MXN', 2, true, null),
  ('MYR', 2, false, null),
  ('MZN', 2, false, null),
  ('NAD', 2, false, null),
  ('NGN', 2, false, null),
  ('NIO', 2, false, null),
  ('NOK', 2, true, null),
  ('NPR', 2, false, null),
  ('NZD', 2, true, null),
  ('OMR', 3, false, null),
  ('PAB', 2, false, null),
  ('PEN', 2, false, null),
  ('PGK', 2, false, null),
  ('PHP', 2, false, null),
  ('PKR', 2, false, null),
  ('PLN', 2, true, null),
  ('PYG', 0, false, null),
  ('QAR', 2, false, null),
  ('RON', 2, true, null),
  ('RSD', 2, false, null),
  ('RUB', 2, false, null),
  ('RWF', 0, false, null),
  ('SAR', 2, false, null),
  ('SBD', 2, false, null),
  ('SCR', 2, false, null),
  ('SDG', 2, false, null),
  ('SEK', 2, true, null),
  ('SGD', 2, true, null),
  ('SHP', 2, false, null),
  ('SLE', 2, false, null),
  ('SOS', 2, false, null),
  ('SRD', 2, false, null),
  ('SSP', 2, false, null),
  ('STN', 2, false, null),
  ('SVC', 2, false, null),
  ('SYP', 2, false, null),
  ('SZL', 2, false, null),
  ('THB', 2, false, null),
  ('TJS', 2, false, null),
  ('TMT', 2, false, null),
  ('TND', 3, false, null),
  ('TOP', 2, false, null),
  ('TRY', 2, true, null),
  ('TTD', 2, false, null),
  ('TWD', 2, false, null),
  ('TZS', 2, false, null),
  ('UAH', 2, false, null),
  ('UGX', 0, false, null),
  ('USD', 2, true, null),
  ('UYU', 2, false, null),
  ('UZS', 2, false, null),
  ('VES', 2, false, null),
  ('VND', 0, false, null),
  ('VUV', 0, false, null),
  ('WST', 2, false, null),
  ('XAF', 0, false, null),
  ('XCD', 2, false, null),
  ('XCG', 2, false, null),
  ('XOF', 0, false, null),
  ('XPF', 0, false, null),
  ('YER', 2, false, null),
  ('ZAR', 2, true, null),
  ('ZMW', 2, false, null),
  ('ZWG', 2, false, null);

alter table public.currency_reference enable row level security;
revoke all on public.currency_reference from public, anon, authenticated;
grant select on public.currency_reference to authenticated;
create policy currency_reference_select on public.currency_reference for select to authenticated using (true);
create policy mcp_delegated_deny on public.currency_reference as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
-- A table of no business is a personal surface (0564): it answers a recognised native session only.
create policy personal_native_session on public.currency_reference as restrictive for all to public
  using ((select public.personal_native_session())) with check ((select public.personal_native_session()));

-- restates 0590: the digits come from the reference; a code it does not hold is refused, never read as two.
create or replace function public.currency_minor_digits(p_currency text)
returns integer language plpgsql stable set search_path = public as $fn$
declare
  v_digits integer;
begin
  select c.minor_digits into v_digits from public.currency_reference c where c.code = upper(btrim(coalesce(p_currency, '')));
  if v_digits is null then
    perform public.refuse('DKL02', jsonb_build_object('reason', 'currency', 'currency', p_currency),
      'a currency the reference does not hold');
  end if;
  return v_digits;
end
$fn$;
revoke execute on function public.currency_minor_digits(text) from public, anon;
grant execute on function public.currency_minor_digits(text) to authenticated;

-- Why the codes of [p_value] (a currency, a time zone, a country it names) cannot be stored for [p_domain] where
-- [p_stored] was, or null: a code equal to the stored one is kept as it is.
create or replace function public.tax_reference_code_refusal(p_domain text, p_value jsonb, p_stored jsonb)
returns text language sql stable set search_path = public as $fn$
  select case
    when p_value ? 'currency' and p_value ->> 'currency' is distinct from p_stored ->> 'currency'
         and not exists (select 1 from public.currency_reference c where c.code = p_value ->> 'currency') then 'currency'
    when p_value ? 'time_zone' and p_value ->> 'time_zone' is distinct from p_stored ->> 'time_zone'
         and not exists (select 1 from pg_timezone_names z where z.name = p_value ->> 'time_zone') then 'time_zone'
    when p_value ? 'alias_of' and coalesce(p_value ->> 'alias_of', '') <> ''
         and p_value ->> 'alias_of' is distinct from p_stored ->> 'alias_of'
         and not exists (select 1 from public.tax_reference t
                          where t.domain = 'country' and t.country = upper(p_value ->> 'alias_of')) then 'country'
  end
$fn$;
revoke execute on function public.tax_reference_code_refusal(text, jsonb, jsonb) from public, anon, authenticated;

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text) returns text language plpgsql as $f$
begin
  if (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old) <> 1 then
    perform public.refuse('DKG11', jsonb_build_object('field', left(p_old, 60), 'reason', 'anchor_missing'), '0993: anchor not found exactly once');
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;

do $patch$
declare
  v_def text := pg_get_functiondef('public.set_tax_reference(text,text,text,jsonb,text,boolean,date)'::regprocedure);
begin
  execute pg_temp.anchor_replace(v_def,
    '  insert into public.tax_reference (domain, country, key, valid_from, value, source, confirmed)',
    '  -- #4501 (0993) -- the codes are picked from their lists; a new series names a country the store holds
  if v_last.id is null and p_domain <> ''country'' and v_country <> ''*''
     and not exists (select 1 from public.tax_reference t where t.domain = ''country'' and t.country = v_country) then
    perform public.refuse(''DKL02'', jsonb_build_object(''reason'', ''country''), ''a country the store does not hold'');
  end if;
  if public.tax_reference_code_refusal(p_domain, p_value, v_last.value) is not null then
    perform public.refuse(''DKL02'', jsonb_build_object(''reason'', public.tax_reference_code_refusal(p_domain, p_value, v_last.value)),
      ''a code its list does not hold'');
  end if;
  insert into public.tax_reference (domain, country, key, valid_from, value, source, confirmed)');
end
$patch$;

select public.set_deskilo_schema_version(993);
