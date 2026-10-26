-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (an anchored patch of invoice_essentials_missing and tax_reference_valid;
-- the Spanish issuing gate gets a new version and its predecessor ends on
-- that day; no issued document, no filed period is touched)
--
-- 9999 (#2363, numbered at push time) -- the remaining Spanish and Italian
-- invoice rules, as rows of the tax reference store:
--   * `threshold` learns three effects: `annual_operations` (the yearly
--     operations with one customer the modelo 347 lists, ES `modelo347`),
--     `simplified_invoice` (the total up to which a simplified invoice is
--     enough: ES 400 EUR, RD 1619/2012 art. 4; GB 250 GBP, the figure 0417
--     wrote into this function) and `stamp_duty` (the total of an Italian
--     document without VAT above which the imposta di bollo is due, the
--     row's `charge_cents` the duty), and the optional `charge_cents`;
--   * `exemption_text` IT `stamp_duty`: the line a document that owes the
--     duty prints (the FatturaPA's `DatiBollo` reads the same row);
--   * `issuing_gate` learns `outside_vat_postal_codes`: the postal-code
--     prefixes of sites where the State's VAT does not apply. Spain's new
--     version names the Canary Islands (35, 38: IGIC), Ceuta (51) and
--     Melilla (52: IPSI); a seller there is refused by name
--     (`territory_outside_vat`) until those taxes are modelled;
--   * invoice_essentials_missing reads the simplified-invoice line from the
--     row of the seller's country instead of a figure in its body.
-- Spain and Italy stay refused (`seller_country_unsupported`): the gates lift
-- with their national channels (Verifactu, SdI), not here.

-- ── 1. the shapes ─────────────────────────────────────────────────────
do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef('public.tax_reference_valid(text,jsonb)'::regprocedure) into v_def;
  v_def := replace(v_def,
    $a$array['cents', 'effect', 'currency']$a$,
    $a$array['cents', 'effect', 'currency', 'charge_cents']$a$);
  if position($a$'currency', 'charge_cents']$a$ in v_def) = 0 then
    raise exception '9999: threshold keys anchor missing';
  end if;
  v_def := replace(v_def,
    $a$array['next_year', 'immediate']$a$,
    $a$array['next_year', 'immediate', 'annual_operations', 'simplified_invoice', 'stamp_duty']$a$);
  if position($a$'simplified_invoice', 'stamp_duty']$a$ in v_def) = 0 then
    raise exception '9999: threshold effects anchor missing';
  end if;
  v_def := replace(v_def,
    $a$(p_value ->> 'currency') ~ '^[A-Z]{3}$', false);$a$,
    $a$(p_value ->> 'currency') ~ '^[A-Z]{3}$'
         and (not p_value ? 'charge_cents'
              or (jsonb_typeof(p_value -> 'charge_cents') = 'number'
                  and (p_value ->> 'charge_cents') ~ '^[1-9][0-9]*$')), false);$a$);
  if position($a$(p_value ->> 'charge_cents') ~ '^[1-9][0-9]*$'$a$ in v_def) = 0 then
    raise exception '9999: threshold currency anchor missing';
  end if;
  v_def := replace(v_def,
    $a$array['supported', 'requires_tax_number', 'national_channel_required', 'currency', 'tax_system']$a$,
    $a$array['supported', 'requires_tax_number', 'national_channel_required', 'currency', 'tax_system',
                           'outside_vat_postal_codes']$a$);
  if position($a$'outside_vat_postal_codes']$a$ in v_def) = 0 then
    raise exception '9999: issuing_gate keys anchor missing';
  end if;
  v_def := replace(v_def,
    $a$(p_value ->> 'tax_system') = any (array['vat', 'sales_tax']))), false);$a$,
    $a$(p_value ->> 'tax_system') = any (array['vat', 'sales_tax'])))
         and (not p_value ? 'outside_vat_postal_codes'
              or (jsonb_typeof(p_value -> 'outside_vat_postal_codes') = 'array'
                  and not exists (select 1 from jsonb_array_elements(p_value -> 'outside_vat_postal_codes') e
                                   where jsonb_typeof(e) <> 'string'
                                      or (e #>> '{}') !~ '^[0-9A-Z]{1,5}$'))), false);$a$);
  if position($a$(e #>> '{}') !~ '^[0-9A-Z]{1,5}$'$a$ in v_def) = 0 then
    raise exception '9999: issuing_gate tax_system anchor missing';
  end if;
  execute v_def;
end
$migration$;

-- ── 2. the Spanish gate's version in force ends where its successor begins ──
update public.tax_reference
   set valid_to = date '2026-10-25'
 where domain = 'issuing_gate' and country = 'ES' and key = 'gate'
   and valid_from = date '1900-01-01' and valid_to is null;

-- ── 3. the rows ───────────────────────────────────────────────────────
-- BEGIN GENERATED SEED (dart run tool/build_tax_reference_seed.dart)
insert into public.tax_reference
  (domain, country, key, valid_from, value, source, confirmed)
values
('exemption_text', 'IT', 'stamp_duty', '1900-01-01', '{"regime":"stamp_duty","text":"Imposta di bollo assolta in modo virtuale ai sensi del D.M. 17 giugno 2014."}'::jsonb, 'DM 17 June 2014 art. 6 (the duty on electronic invoices paid virtually) (#2363); not yet confirmed', false),
('issuing_gate', 'ES', 'gate', '2026-10-25', '{"supported":true,"requires_tax_number":true,"national_channel_required":true,"outside_vat_postal_codes":["35","38","51","52"]}'::jsonb, '#2363: the gate as it stood, and the sites the State''s VAT does not reach by postal-code prefix: Las Palmas (35) and Santa Cruz de Tenerife (38) under the Canary Islands'' IGIC (Ley 20/1991), Ceuta (51) and Melilla (52) under the IPSI (Ley 8/1991), outside the VAT''s territory by art. 3 Ley 37/1992; not yet confirmed', false),
('threshold', 'ES', 'modelo347', '1900-01-01', '{"cents":300506,"effect":"annual_operations","currency":"EUR"}'::jsonb, 'RD 1065/2007 art. 33 (modelo 347): the operations with one person or entity above EUR 3,005.06 in the calendar year, VAT included (#2363); not yet confirmed', false),
('threshold', 'ES', 'simplified_invoice', '2013-01-01', '{"cents":40000,"effect":"simplified_invoice","currency":"EUR"}'::jsonb, 'RD 1619/2012 art. 4.1.a: a simplified invoice is enough up to EUR 400, VAT included (#2363); not yet confirmed', false),
('threshold', 'GB', 'simplified_invoice', '1900-01-01', '{"cents":25000,"effect":"simplified_invoice","currency":"GBP"}'::jsonb, 'VAT Notice 700 §16.4: a less detailed invoice is enough up to GBP 250 including VAT, the figure invoice_essentials_missing carried since 0417 (#2359, #2363); typed in code, not re-verified', false),
('threshold', 'IT', 'stamp_duty', '1900-01-01', '{"cents":7747,"effect":"stamp_duty","currency":"EUR","charge_cents":200}'::jsonb, 'DPR 642/1972, tariff art. 13 note 1, and DL 69/2013: EUR 2.00 on an invoice without VAT above EUR 77.47, the figures invoice_fatturapa.dart carried (#2438, #2363); typed in code, not re-verified', false)
on conflict (domain, country, key, valid_from) do nothing;
-- END GENERATED SEED

-- ── 4. a threshold of a country, in force today ───────────────────────
create or replace function public.tax_threshold_cents(p_country text, p_key text)
returns bigint language sql stable security definer set search_path = public as $fn$
  select (t.value ->> 'cents')::bigint
    from public.tax_reference t
   where t.domain = 'threshold' and t.key = p_key
     and t.country = public.eu_country_code(p_country)
     and t.valid_from <= current_date
     and (t.valid_to is null or t.valid_to > current_date)
   order by t.valid_from desc
   limit 1;
$fn$;
revoke execute on function public.tax_threshold_cents(text, text) from public, anon, authenticated;

-- ── 5. anchored patch ─────────────────────────────────────────────────
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
  v_step record;
begin
  select pg_get_functiondef('public.invoice_essentials_missing(uuid,uuid,jsonb,jsonb)'::regprocedure)
    into v_def;
  for v_step in
    select * from (values
      (1, 'the simplified invoice',
       $old$  -- #2359 — VAT Notice 700 §16.4: up to £250 including VAT a less detailed
  -- invoice is enough, and it names no customer.
  v_simplified := v_cc = 'GB'
    and coalesce((select sum((t ->> 'gross_cents')::bigint)
                    from jsonb_array_elements(coalesce(p_vat_totals, '[]'::jsonb)) t), 0)
        <= 25000;
$old$,
       $new$  -- #2359/#2363 — up to the `simplified_invoice` threshold of the seller's
  -- country (VAT Notice 700 §16.4, RD 1619/2012 art. 4), VAT included, a less
  -- detailed invoice is enough, and it names no customer.
  v_simplified := coalesce((select sum((t ->> 'gross_cents')::bigint)
                    from jsonb_array_elements(coalesce(p_vat_totals, '[]'::jsonb)) t), 0)
        <= coalesce(public.tax_threshold_cents(v_cc, 'simplified_invoice'), -1);
$new$),
      (2, 'the territories outside the VAT',
       $old$  if not coalesce((v_gate ->> 'supported')::boolean, false)
     or coalesce((v_gate ->> 'national_channel_required')::boolean, false) then
    v_missing := array_append(v_missing, 'seller_country_unsupported'::text);
  end if;
$old$,
       $new$  if not coalesce((v_gate ->> 'supported')::boolean, false)
     or coalesce((v_gate ->> 'national_channel_required')::boolean, false) then
    v_missing := array_append(v_missing, 'seller_country_unsupported'::text);
  end if;
  -- #2363 — a site where the State's VAT does not apply (the Canary Islands'
  -- IGIC, Ceuta and Melilla's IPSI): its postal-code prefixes are the gate's.
  if exists (select 1
               from jsonb_array_elements_text(coalesce(v_gate -> 'outside_vat_postal_codes', '[]'::jsonb)) p
              where upper(btrim(coalesce(v_seller ->> 'postal_code', ''))) like p || '%') then
    v_missing := array_append(v_missing, 'territory_outside_vat'::text);
  end if;
$new$)
    ) as s(n, what, old_text, new_text) order by n
  loop
    v_def := pg_temp.anchor_replace(v_def, v_step.old_text, v_step.new_text);
    if v_def is null then
      raise exception '9999: invoice_essentials_missing anchor % (%) missing', v_step.n, v_step.what;
    end if;
  end loop;
  execute v_def;
end
$migration$;

select public.set_deskilo_schema_version(9999);
