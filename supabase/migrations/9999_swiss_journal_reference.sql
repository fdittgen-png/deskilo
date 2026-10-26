-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 9999 (#2377, the Swiss journal) -- two kinds of `account_map` rows of the
-- tax reference store, CH, all UNCONFIRMED until a fiduciary has checked
-- them:
--
--   * `ch_kmu/<tax key>`: the MWST code the Swiss journal and its Banana
--     layout write on a taxed row, per rate group -- `tax:<group>` for
--     output tax (V81, V26, V38), `input:<group>` for input tax on material
--     and services (M81, M26, M38, Ziffer 400) and `asset:<group>` for the
--     input tax of an investment (I81, I26, I38, Ziffer 405): the codes of
--     Banana's Swiss VAT table. Valid from 2024-01-01, the rates they name;
--     a confirmed change of the rates needs its own version. A taxed row
--     whose group has no code stops the file and names the group.
--   * the KMU chart gains the accounts the posting engine books: 1170
--     Vorsteuer, 2000 Verbindlichkeiten, 3805 Verluste aus Forderungen,
--     6000 Raumaufwand (offered beside 6500), and the rate groups' revenue
--     accounts (3401 reduced and accommodation, 3402 exempt) under their
--     qualified roles. The output tax of every rate stays on 2200: the
--     MWST code carries the rate.

-- The shape check learns the `ch_kmu` format: a row of the Swiss journal
-- names a tax code like the DATEV and Sage rows do. Patched at its anchor,
-- so it holds whichever restatement of the function is live.
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
    $a$array['coa', 'fec', 'datev', 'sage', 'saf_t']$a$,
    $a$array['coa', 'fec', 'datev', 'sage', 'saf_t', 'ch_kmu']$a$);
  if v_def is null or position($a$'saf_t', 'ch_kmu'$a$ in v_def) = 0 then
    raise exception '9999: tax_reference_valid account_map format anchor missing';
  end if;
  execute v_def;
end
$migration$;

-- BEGIN GENERATED SEED (dart run tool/build_tax_reference_seed.dart)
insert into public.tax_reference
  (domain, country, key, valid_from, value, source, confirmed)
values
('account_map', 'CH', 'ch_kmu/asset:intermediate', '2024-01-01', '{"format":"ch_kmu","role":"asset:intermediate","tax_code":"I38","label":"Vorsteuer 3,8 % Investitionen (Ziffer 405)"}'::jsonb, 'Banana Accounting+ Swiss VAT table (MWST-Tabelle of its Swiss templates, rates from 2024): the code a Banana file''s VAT table carries for input tax at the accommodation rate on investments; the Swiss journal writes it on each row of that rate group (#2377). A fiduciary''s own VAT table may name it otherwise. Not yet confirmed by a fiduciary', false),
('account_map', 'CH', 'ch_kmu/asset:reduced', '2024-01-01', '{"format":"ch_kmu","role":"asset:reduced","tax_code":"I26","label":"Vorsteuer 2,6 % Investitionen (Ziffer 405)"}'::jsonb, 'Banana Accounting+ Swiss VAT table (MWST-Tabelle of its Swiss templates, rates from 2024): the code a Banana file''s VAT table carries for input tax at the reduced rate on investments; the Swiss journal writes it on each row of that rate group (#2377). A fiduciary''s own VAT table may name it otherwise. Not yet confirmed by a fiduciary', false),
('account_map', 'CH', 'ch_kmu/asset:standard', '2024-01-01', '{"format":"ch_kmu","role":"asset:standard","tax_code":"I81","label":"Vorsteuer 8,1 % Investitionen (Ziffer 405)"}'::jsonb, 'Banana Accounting+ Swiss VAT table (MWST-Tabelle of its Swiss templates, rates from 2024): the code a Banana file''s VAT table carries for input tax at the normal rate on investments; the Swiss journal writes it on each row of that rate group (#2377). A fiduciary''s own VAT table may name it otherwise. Not yet confirmed by a fiduciary', false),
('account_map', 'CH', 'ch_kmu/input:intermediate', '2024-01-01', '{"format":"ch_kmu","role":"input:intermediate","tax_code":"M38","label":"Vorsteuer 3,8 % Material und Dienstleistungen (Ziffer 400)"}'::jsonb, 'Banana Accounting+ Swiss VAT table (MWST-Tabelle of its Swiss templates, rates from 2024): the code a Banana file''s VAT table carries for input tax at the accommodation rate on material and services; the Swiss journal writes it on each row of that rate group (#2377). A fiduciary''s own VAT table may name it otherwise. Not yet confirmed by a fiduciary', false),
('account_map', 'CH', 'ch_kmu/input:reduced', '2024-01-01', '{"format":"ch_kmu","role":"input:reduced","tax_code":"M26","label":"Vorsteuer 2,6 % Material und Dienstleistungen (Ziffer 400)"}'::jsonb, 'Banana Accounting+ Swiss VAT table (MWST-Tabelle of its Swiss templates, rates from 2024): the code a Banana file''s VAT table carries for input tax at the reduced rate on material and services; the Swiss journal writes it on each row of that rate group (#2377). A fiduciary''s own VAT table may name it otherwise. Not yet confirmed by a fiduciary', false),
('account_map', 'CH', 'ch_kmu/input:standard', '2024-01-01', '{"format":"ch_kmu","role":"input:standard","tax_code":"M81","label":"Vorsteuer 8,1 % Material und Dienstleistungen (Ziffer 400)"}'::jsonb, 'Banana Accounting+ Swiss VAT table (MWST-Tabelle of its Swiss templates, rates from 2024): the code a Banana file''s VAT table carries for input tax at the normal rate on material and services; the Swiss journal writes it on each row of that rate group (#2377). A fiduciary''s own VAT table may name it otherwise. Not yet confirmed by a fiduciary', false),
('account_map', 'CH', 'ch_kmu/tax:intermediate', '2024-01-01', '{"format":"ch_kmu","role":"tax:intermediate","tax_code":"V38","label":"Umsatz Beherbergungssatz 3,8 % (Ziffer 343)"}'::jsonb, 'Banana Accounting+ Swiss VAT table (MWST-Tabelle of its Swiss templates, rates from 2024): the code a Banana file''s VAT table carries for sales at the accommodation rate; the Swiss journal writes it on each row of that rate group (#2377). A fiduciary''s own VAT table may name it otherwise. Not yet confirmed by a fiduciary', false),
('account_map', 'CH', 'ch_kmu/tax:reduced', '2024-01-01', '{"format":"ch_kmu","role":"tax:reduced","tax_code":"V26","label":"Umsatz reduzierter Satz 2,6 % (Ziffer 313)"}'::jsonb, 'Banana Accounting+ Swiss VAT table (MWST-Tabelle of its Swiss templates, rates from 2024): the code a Banana file''s VAT table carries for sales at the reduced rate; the Swiss journal writes it on each row of that rate group (#2377). A fiduciary''s own VAT table may name it otherwise. Not yet confirmed by a fiduciary', false),
('account_map', 'CH', 'ch_kmu/tax:standard', '2024-01-01', '{"format":"ch_kmu","role":"tax:standard","tax_code":"V81","label":"Umsatz Normalsatz 8,1 % (Ziffer 303)"}'::jsonb, 'Banana Accounting+ Swiss VAT table (MWST-Tabelle of its Swiss templates, rates from 2024): the code a Banana file''s VAT table carries for sales at the normal rate; the Swiss journal writes it on each row of that rate group (#2377). A fiduciary''s own VAT table may name it otherwise. Not yet confirmed by a fiduciary', false),
('account_map', 'CH', 'coa/09-vat_input', '1900-01-01', '{"format":"coa","role":"vat_input","account":"1170","label":"Vorsteuer MWST Material, Waren, Dienstleistungen, Energie"}'::jsonb, 'Schweizer Kontenrahmen KMU (veb.ch), account 1170 Vorsteuer MWST Material, Waren, Dienstleistungen, Energie: the input tax of the suggested chart (#2377). A suggestion the accountant re-points; not yet confirmed by a fiduciary', false),
('account_map', 'CH', 'coa/10-suppliers', '1900-01-01', '{"format":"coa","role":"suppliers","account":"2000","label":"Verbindlichkeiten aus Lieferungen und Leistungen"}'::jsonb, 'Schweizer Kontenrahmen KMU (veb.ch), account 2000 Verbindlichkeiten aus Lieferungen und Leistungen: what the space owes its suppliers (#2377). A suggestion the accountant re-points; not yet confirmed by a fiduciary', false),
('account_map', 'CH', 'coa/11-write_off', '1900-01-01', '{"format":"coa","role":"write_off","account":"3805","label":"Verluste aus Forderungen"}'::jsonb, 'Schweizer Kontenrahmen KMU (veb.ch), account 3805 Verluste aus Forderungen: the written-off rest of a receivable (Debitorenverluste) (#2377). A suggestion the accountant re-points; not yet confirmed by a fiduciary', false),
('account_map', 'CH', 'coa/12-expenses', '1900-01-01', '{"format":"coa","role":"expenses","account":"6000","label":"Raumaufwand"}'::jsonb, 'Schweizer Kontenrahmen KMU (veb.ch), account 6000 Raumaufwand: the rent of the premises, offered beside 6500 (#2377). A suggestion the accountant re-points; not yet confirmed by a fiduciary', false),
('account_map', 'CH', 'coa/13-revenue_reduced', '1900-01-01', '{"format":"coa","role":"revenue:reduced","account":"3401","label":"Dienstleistungsertrag zum reduzierten Satz und Beherbergung"}'::jsonb, 'Schweizer Kontenrahmen KMU (veb.ch), account 3401 Dienstleistungsertrag zum reduzierten Satz und Beherbergung: the revenue of the reduced rate group (#2377). A suggestion the accountant re-points; not yet confirmed by a fiduciary', false),
('account_map', 'CH', 'coa/14-revenue_intermediate', '1900-01-01', '{"format":"coa","role":"revenue:intermediate","account":"3401","label":"Dienstleistungsertrag zum reduzierten Satz und Beherbergung"}'::jsonb, 'Schweizer Kontenrahmen KMU (veb.ch), account 3401 Dienstleistungsertrag zum reduzierten Satz und Beherbergung: the revenue of the accommodation rate group (#2377). A suggestion the accountant re-points; not yet confirmed by a fiduciary', false),
('account_map', 'CH', 'coa/15-revenue_exempt', '1900-01-01', '{"format":"coa","role":"revenue:exempt","account":"3402","label":"Dienstleistungsertrag, von der Steuer ausgenommen"}'::jsonb, 'Schweizer Kontenrahmen KMU (veb.ch), account 3402 Dienstleistungsertrag, von der Steuer ausgenommen: the revenue of the exempt letting (art. 21 MWSTG) (#2377). A suggestion the accountant re-points; not yet confirmed by a fiduciary', false)
on conflict (domain, country, key, valid_from) do nothing;
-- END GENERATED SEED

select public.set_deskilo_schema_version(9999);
