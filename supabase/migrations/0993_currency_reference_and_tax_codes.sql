-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
--
-- #4501 (audit MD-06, MD-03) -- one currency reference, and the tax administration's codes checked at the write.
--   * public.currency_reference   every currency an amount is read in: its ISO 4217 code, its minor digits, whether a
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
  ('AUD', 2, true, null),
  ('BGN', 2, true, date '2026-01-01'),
  ('BHD', 3, false, null),
  ('BIF', 0, false, null),
  ('BRL', 2, true, null),
  ('CAD', 2, true, null),
  ('CHF', 2, true, null),
  ('CLP', 0, false, null),
  ('CNY', 2, true, null),
  ('CZK', 2, true, null),
  ('DJF', 0, false, null),
  ('DKK', 2, true, null),
  ('EUR', 2, true, null),
  ('GBP', 2, true, null),
  ('GNF', 0, false, null),
  ('HKD', 2, true, null),
  ('HRK', 2, true, date '2023-01-01'),
  ('HUF', 2, true, null),
  ('ILS', 2, true, null),
  ('INR', 2, true, null),
  ('IQD', 3, false, null),
  ('ISK', 0, true, null),
  ('JOD', 3, false, null),
  ('JPY', 0, true, null),
  ('KMF', 0, false, null),
  ('KRW', 0, true, null),
  ('KWD', 3, false, null),
  ('LYD', 3, false, null),
  ('MXN', 2, true, null),
  ('NOK', 2, true, null),
  ('NZD', 2, true, null),
  ('OMR', 3, false, null),
  ('PLN', 2, true, null),
  ('PYG', 0, false, null),
  ('RON', 2, true, null),
  ('RWF', 0, false, null),
  ('SEK', 2, true, null),
  ('SGD', 2, true, null),
  ('TND', 3, false, null),
  ('TRY', 2, true, null),
  ('UGX', 0, false, null),
  ('USD', 2, true, null),
  ('VND', 0, false, null),
  ('VUV', 0, false, null),
  ('XAF', 0, false, null),
  ('XOF', 0, false, null),
  ('XPF', 0, false, null),
  ('ZAR', 2, true, null);

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
