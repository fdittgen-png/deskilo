-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0634 (#2488, S5 of #2483) -- the countries a workspace can be created in
-- are reference data, not a list in the app. A new domain of the tax
-- reference store, `country`: one row per ISO 3166-1 code, key `catalogue`,
-- value {currency, time_zone, banking_scheme, position}. The platform
-- administrator edits them in the reference editor; the app reads them
-- (the creation form, the currency and zone a new workspace starts with, the
-- shape of its payment instructions). `tax_reference_valid` learns the shape.
--
-- The 32 rows are the catalogue the app has shipped since #711, unchanged and
-- UNCONFIRMED: they are creation defaults, not a tax or issuing fact (what
-- DesKilo issues for stays `issuing_gate`).

-- ── 1. the shape of a country row ─────────────────────────────────────
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_pattern text;
  v_out text;
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  v_out := regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'), 'g');
  return case when v_out = p_def then null else v_out end;
end
$f$;

revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef('public.tax_reference_valid(text,jsonb)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$    when 'retention' then$a$,
    $a$    when 'country' then
      -- A country a workspace can be created in: its currency, the zone of
      -- its capital and how its banks identify an account.
      if exists (select 1 from jsonb_object_keys(p_value) k
                  where k <> all (array['currency', 'time_zone', 'banking_scheme', 'position'])) then return false; end if;
      if jsonb_typeof(p_value -> 'currency') is distinct from 'string'
         or (p_value ->> 'currency') !~ '^[A-Z]{3}$' then return false; end if;
      if jsonb_typeof(p_value -> 'time_zone') is distinct from 'string'
         or (p_value ->> 'time_zone') !~ '^[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+){0,2}$'
         or length(p_value ->> 'time_zone') > 64 then return false; end if;
      if jsonb_typeof(p_value -> 'banking_scheme') is distinct from 'string'
         or (p_value ->> 'banking_scheme') <> all (array['sepa', 'uk', 'us', 'ca', 'ch']) then return false; end if;
      return not (p_value ? 'position')
         or (jsonb_typeof(p_value -> 'position') = 'number' and (p_value ->> 'position') ~ '^[0-9]+$');
    when 'retention' then$a$);
  if v_def is null or position($a$when 'country' then$a$ in v_def) = 0 then
    raise exception '0634: tax_reference_valid retention anchor missing';
  end if;
  execute v_def;
end
$migration$;

-- ── 2. the rows ───────────────────────────────────────────────────────
-- BEGIN GENERATED SEED (dart run tool/build_tax_reference_seed.dart)
insert into public.tax_reference
  (domain, country, key, valid_from, value, source, confirmed)
values
('country', 'AT', 'catalogue', '1900-01-01', '{"currency":"EUR","time_zone":"Europe/Vienna","banking_scheme":"sepa","position":1}'::jsonb, 'the catalogue a workspace is created from (#711): ISO 3166-1 country, ISO 4217 currency, IANA zone of the capital, banking scheme of the payment instructions. Creation defaults only: not a tax or issuing fact (issuing_gate carries those).', false),
('country', 'BE', 'catalogue', '1900-01-01', '{"currency":"EUR","time_zone":"Europe/Brussels","banking_scheme":"sepa","position":2}'::jsonb, 'the catalogue a workspace is created from (#711): ISO 3166-1 country, ISO 4217 currency, IANA zone of the capital, banking scheme of the payment instructions. Creation defaults only: not a tax or issuing fact (issuing_gate carries those).', false),
('country', 'BG', 'catalogue', '1900-01-01', '{"currency":"BGN","time_zone":"Europe/Sofia","banking_scheme":"sepa","position":21}'::jsonb, 'the catalogue a workspace is created from (#711): ISO 3166-1 country, ISO 4217 currency, IANA zone of the capital, banking scheme of the payment instructions. Creation defaults only: not a tax or issuing fact (issuing_gate carries those).', false),
('country', 'CA', 'catalogue', '1900-01-01', '{"currency":"CAD","time_zone":"America/Toronto","banking_scheme":"ca","position":32}'::jsonb, 'the catalogue a workspace is created from (#711): ISO 3166-1 country, ISO 4217 currency, IANA zone of the capital, banking scheme of the payment instructions. Creation defaults only: not a tax or issuing fact (issuing_gate carries those).', false),
('country', 'CH', 'catalogue', '1900-01-01', '{"currency":"CHF","time_zone":"Europe/Zurich","banking_scheme":"ch","position":28}'::jsonb, 'the catalogue a workspace is created from (#711): ISO 3166-1 country, ISO 4217 currency, IANA zone of the capital, banking scheme of the payment instructions. Creation defaults only: not a tax or issuing fact (issuing_gate carries those).', false),
('country', 'CY', 'catalogue', '1900-01-01', '{"currency":"EUR","time_zone":"Asia/Nicosia","banking_scheme":"sepa","position":3}'::jsonb, 'the catalogue a workspace is created from (#711): ISO 3166-1 country, ISO 4217 currency, IANA zone of the capital, banking scheme of the payment instructions. Creation defaults only: not a tax or issuing fact (issuing_gate carries those).', false),
('country', 'CZ', 'catalogue', '1900-01-01', '{"currency":"CZK","time_zone":"Europe/Prague","banking_scheme":"sepa","position":22}'::jsonb, 'the catalogue a workspace is created from (#711): ISO 3166-1 country, ISO 4217 currency, IANA zone of the capital, banking scheme of the payment instructions. Creation defaults only: not a tax or issuing fact (issuing_gate carries those).', false),
('country', 'DE', 'catalogue', '1900-01-01', '{"currency":"EUR","time_zone":"Europe/Berlin","banking_scheme":"sepa","position":4}'::jsonb, 'the catalogue a workspace is created from (#711): ISO 3166-1 country, ISO 4217 currency, IANA zone of the capital, banking scheme of the payment instructions. Creation defaults only: not a tax or issuing fact (issuing_gate carries those).', false),
('country', 'DK', 'catalogue', '1900-01-01', '{"currency":"DKK","time_zone":"Europe/Copenhagen","banking_scheme":"sepa","position":23}'::jsonb, 'the catalogue a workspace is created from (#711): ISO 3166-1 country, ISO 4217 currency, IANA zone of the capital, banking scheme of the payment instructions. Creation defaults only: not a tax or issuing fact (issuing_gate carries those).', false),
('country', 'EE', 'catalogue', '1900-01-01', '{"currency":"EUR","time_zone":"Europe/Tallinn","banking_scheme":"sepa","position":5}'::jsonb, 'the catalogue a workspace is created from (#711): ISO 3166-1 country, ISO 4217 currency, IANA zone of the capital, banking scheme of the payment instructions. Creation defaults only: not a tax or issuing fact (issuing_gate carries those).', false),
('country', 'ES', 'catalogue', '1900-01-01', '{"currency":"EUR","time_zone":"Europe/Madrid","banking_scheme":"sepa","position":6}'::jsonb, 'the catalogue a workspace is created from (#711): ISO 3166-1 country, ISO 4217 currency, IANA zone of the capital, banking scheme of the payment instructions. Creation defaults only: not a tax or issuing fact (issuing_gate carries those).', false),
('country', 'FI', 'catalogue', '1900-01-01', '{"currency":"EUR","time_zone":"Europe/Helsinki","banking_scheme":"sepa","position":7}'::jsonb, 'the catalogue a workspace is created from (#711): ISO 3166-1 country, ISO 4217 currency, IANA zone of the capital, banking scheme of the payment instructions. Creation defaults only: not a tax or issuing fact (issuing_gate carries those).', false),
('country', 'FR', 'catalogue', '1900-01-01', '{"currency":"EUR","time_zone":"Europe/Paris","banking_scheme":"sepa","position":8}'::jsonb, 'the catalogue a workspace is created from (#711): ISO 3166-1 country, ISO 4217 currency, IANA zone of the capital, banking scheme of the payment instructions. Creation defaults only: not a tax or issuing fact (issuing_gate carries those).', false),
('country', 'GB', 'catalogue', '1900-01-01', '{"currency":"GBP","time_zone":"Europe/London","banking_scheme":"uk","position":30}'::jsonb, 'the catalogue a workspace is created from (#711): ISO 3166-1 country, ISO 4217 currency, IANA zone of the capital, banking scheme of the payment instructions. Creation defaults only: not a tax or issuing fact (issuing_gate carries those).', false),
('country', 'GR', 'catalogue', '1900-01-01', '{"currency":"EUR","time_zone":"Europe/Athens","banking_scheme":"sepa","position":9}'::jsonb, 'the catalogue a workspace is created from (#711): ISO 3166-1 country, ISO 4217 currency, IANA zone of the capital, banking scheme of the payment instructions. Creation defaults only: not a tax or issuing fact (issuing_gate carries those).', false),
('country', 'HR', 'catalogue', '1900-01-01', '{"currency":"EUR","time_zone":"Europe/Zagreb","banking_scheme":"sepa","position":10}'::jsonb, 'the catalogue a workspace is created from (#711): ISO 3166-1 country, ISO 4217 currency, IANA zone of the capital, banking scheme of the payment instructions. Creation defaults only: not a tax or issuing fact (issuing_gate carries those).', false),
('country', 'HU', 'catalogue', '1900-01-01', '{"currency":"HUF","time_zone":"Europe/Budapest","banking_scheme":"sepa","position":24}'::jsonb, 'the catalogue a workspace is created from (#711): ISO 3166-1 country, ISO 4217 currency, IANA zone of the capital, banking scheme of the payment instructions. Creation defaults only: not a tax or issuing fact (issuing_gate carries those).', false),
('country', 'IE', 'catalogue', '1900-01-01', '{"currency":"EUR","time_zone":"Europe/Dublin","banking_scheme":"sepa","position":11}'::jsonb, 'the catalogue a workspace is created from (#711): ISO 3166-1 country, ISO 4217 currency, IANA zone of the capital, banking scheme of the payment instructions. Creation defaults only: not a tax or issuing fact (issuing_gate carries those).', false),
('country', 'IT', 'catalogue', '1900-01-01', '{"currency":"EUR","time_zone":"Europe/Rome","banking_scheme":"sepa","position":12}'::jsonb, 'the catalogue a workspace is created from (#711): ISO 3166-1 country, ISO 4217 currency, IANA zone of the capital, banking scheme of the payment instructions. Creation defaults only: not a tax or issuing fact (issuing_gate carries those).', false),
('country', 'LT', 'catalogue', '1900-01-01', '{"currency":"EUR","time_zone":"Europe/Vilnius","banking_scheme":"sepa","position":13}'::jsonb, 'the catalogue a workspace is created from (#711): ISO 3166-1 country, ISO 4217 currency, IANA zone of the capital, banking scheme of the payment instructions. Creation defaults only: not a tax or issuing fact (issuing_gate carries those).', false),
('country', 'LU', 'catalogue', '1900-01-01', '{"currency":"EUR","time_zone":"Europe/Luxembourg","banking_scheme":"sepa","position":14}'::jsonb, 'the catalogue a workspace is created from (#711): ISO 3166-1 country, ISO 4217 currency, IANA zone of the capital, banking scheme of the payment instructions. Creation defaults only: not a tax or issuing fact (issuing_gate carries those).', false),
('country', 'LV', 'catalogue', '1900-01-01', '{"currency":"EUR","time_zone":"Europe/Riga","banking_scheme":"sepa","position":15}'::jsonb, 'the catalogue a workspace is created from (#711): ISO 3166-1 country, ISO 4217 currency, IANA zone of the capital, banking scheme of the payment instructions. Creation defaults only: not a tax or issuing fact (issuing_gate carries those).', false),
('country', 'MT', 'catalogue', '1900-01-01', '{"currency":"EUR","time_zone":"Europe/Malta","banking_scheme":"sepa","position":16}'::jsonb, 'the catalogue a workspace is created from (#711): ISO 3166-1 country, ISO 4217 currency, IANA zone of the capital, banking scheme of the payment instructions. Creation defaults only: not a tax or issuing fact (issuing_gate carries those).', false),
('country', 'NL', 'catalogue', '1900-01-01', '{"currency":"EUR","time_zone":"Europe/Amsterdam","banking_scheme":"sepa","position":17}'::jsonb, 'the catalogue a workspace is created from (#711): ISO 3166-1 country, ISO 4217 currency, IANA zone of the capital, banking scheme of the payment instructions. Creation defaults only: not a tax or issuing fact (issuing_gate carries those).', false),
('country', 'NO', 'catalogue', '1900-01-01', '{"currency":"NOK","time_zone":"Europe/Oslo","banking_scheme":"sepa","position":29}'::jsonb, 'the catalogue a workspace is created from (#711): ISO 3166-1 country, ISO 4217 currency, IANA zone of the capital, banking scheme of the payment instructions. Creation defaults only: not a tax or issuing fact (issuing_gate carries those).', false),
('country', 'PL', 'catalogue', '1900-01-01', '{"currency":"PLN","time_zone":"Europe/Warsaw","banking_scheme":"sepa","position":25}'::jsonb, 'the catalogue a workspace is created from (#711): ISO 3166-1 country, ISO 4217 currency, IANA zone of the capital, banking scheme of the payment instructions. Creation defaults only: not a tax or issuing fact (issuing_gate carries those).', false),
('country', 'PT', 'catalogue', '1900-01-01', '{"currency":"EUR","time_zone":"Europe/Lisbon","banking_scheme":"sepa","position":18}'::jsonb, 'the catalogue a workspace is created from (#711): ISO 3166-1 country, ISO 4217 currency, IANA zone of the capital, banking scheme of the payment instructions. Creation defaults only: not a tax or issuing fact (issuing_gate carries those).', false),
('country', 'RO', 'catalogue', '1900-01-01', '{"currency":"RON","time_zone":"Europe/Bucharest","banking_scheme":"sepa","position":26}'::jsonb, 'the catalogue a workspace is created from (#711): ISO 3166-1 country, ISO 4217 currency, IANA zone of the capital, banking scheme of the payment instructions. Creation defaults only: not a tax or issuing fact (issuing_gate carries those).', false),
('country', 'SE', 'catalogue', '1900-01-01', '{"currency":"SEK","time_zone":"Europe/Stockholm","banking_scheme":"sepa","position":27}'::jsonb, 'the catalogue a workspace is created from (#711): ISO 3166-1 country, ISO 4217 currency, IANA zone of the capital, banking scheme of the payment instructions. Creation defaults only: not a tax or issuing fact (issuing_gate carries those).', false),
('country', 'SI', 'catalogue', '1900-01-01', '{"currency":"EUR","time_zone":"Europe/Ljubljana","banking_scheme":"sepa","position":19}'::jsonb, 'the catalogue a workspace is created from (#711): ISO 3166-1 country, ISO 4217 currency, IANA zone of the capital, banking scheme of the payment instructions. Creation defaults only: not a tax or issuing fact (issuing_gate carries those).', false),
('country', 'SK', 'catalogue', '1900-01-01', '{"currency":"EUR","time_zone":"Europe/Bratislava","banking_scheme":"sepa","position":20}'::jsonb, 'the catalogue a workspace is created from (#711): ISO 3166-1 country, ISO 4217 currency, IANA zone of the capital, banking scheme of the payment instructions. Creation defaults only: not a tax or issuing fact (issuing_gate carries those).', false),
('country', 'US', 'catalogue', '1900-01-01', '{"currency":"USD","time_zone":"America/New_York","banking_scheme":"us","position":31}'::jsonb, 'the catalogue a workspace is created from (#711): ISO 3166-1 country, ISO 4217 currency, IANA zone of the capital, banking scheme of the payment instructions. Creation defaults only: not a tax or issuing fact (issuing_gate carries those).', false)
on conflict (domain, country, key, valid_from) do nothing;
-- END GENERATED SEED

select public.set_deskilo_schema_version(634);
