-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0480 (#2571) -- how long a country makes a space keep its records is
-- reference data, not a sentence in a help page.
--
--   1. retention   a new domain of the tax reference store: one row per
--      country and document class (invoice, books, correspondence, voucher),
--      value {years, from}, `from` being the end of the fiscal year or the
--      document's own date. `*` is the default for a country without a row.
--      `tax_reference_valid` learns the shape.
--   2. retention_rule(workspace, class)         the row in force: years, from,
--      country, source, confirmed. Only an active member reads it.
--      retention_until(workspace, class, date) the first day the document may
--      go: the fiscal-year end (book profile, calendar year without one) or the
--      document date, plus the years.
--   3. preview_my_erasure states the rule for the invoices and the ledger it
--      retains, and the day the latest of them may go.
--
-- Every value arrives UNCONFIRMED with its statute: the platform owner confirms
-- the ones a person with the authority has checked (confirm_tax_reference).
-- Nothing is deleted when a clock ends (non-goal), and the US per-state
-- override is a separate setting.

-- ── 1. the shape of a retention row ───────────────────────────────────
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
    $a$    when 'rate_component' then$a$,
    $a$    when 'retention' then
      -- How long a kind of record is kept, and from when the clock runs.
      if exists (select 1 from jsonb_object_keys(p_value) k where k <> all (array['years', 'from'])) then return false; end if;
      if jsonb_typeof(p_value -> 'years') is distinct from 'number'
         or (p_value ->> 'years') !~ '^[0-9]+$' then return false; end if;
      if (p_value ->> 'years')::int < 1 or (p_value ->> 'years')::int > 100 then return false; end if;
      return jsonb_typeof(p_value -> 'from') = 'string'
         and (p_value ->> 'from') = any (array['fiscal_year_end', 'document_date']);
    when 'rate_component' then$a$);
  if v_def is null or position($a$when 'retention' then$a$ in v_def) = 0 then
    raise exception '0480: tax_reference_valid rate_component anchor missing';
  end if;
  execute v_def;
end
$migration$;

-- ── 2. the readers ────────────────────────────────────────────────────
-- The version in force today for a country's class, else the `*` default.
create or replace function public.retention_rule_of(p_country text, p_class text)
returns jsonb
language sql stable security definer set search_path = public as $fn$
  select jsonb_build_object('years', (t.value ->> 'years')::int, 'from', t.value ->> 'from',
                            'country', t.country, 'source', t.source, 'confirmed', t.confirmed)
    from public.tax_reference t
   where t.domain = 'retention' and t.key = p_class
     and t.country in (upper(btrim(coalesce(p_country, ''))), '*')
     and t.valid_from <= current_date
     and (t.valid_to is null or t.valid_to > current_date)
   order by (t.country = '*'), t.valid_from desc
   limit 1;
$fn$;
revoke execute on function public.retention_rule_of(text, text) from public, anon, authenticated;

create or replace function public.retention_rule(p_workspace_id uuid, p_class text)
returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_me public.members := public.my_active_member(p_workspace_id);
begin
  return public.retention_rule_of(
    (select w.country_code from public.workspaces w where w.id = p_workspace_id), p_class);
end;
$fn$;
revoke execute on function public.retention_rule(uuid, text) from public, anon;
grant execute on function public.retention_rule(uuid, text) to authenticated;

-- The first day a document of p_class dated p_document_date may go. Null when
-- no rule is known for the class (a class nobody listed is never "free").
create or replace function public.retention_until(p_workspace_id uuid, p_class text, p_document_date date)
returns date
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_me public.members := public.my_active_member(p_workspace_id);
  v_rule jsonb;
  v_month int := 1;
  v_day int := 1;
  v_start date;
  v_base date;
begin
  if p_document_date is null then return null; end if;
  v_rule := public.retention_rule_of(
    (select w.country_code from public.workspaces w where w.id = p_workspace_id), p_class);
  if v_rule is null then return null; end if;
  if v_rule ->> 'from' = 'document_date' then
    v_base := p_document_date;
  else
    -- The fiscal year the book profile in force on that day opens on; the
    -- calendar year without a profile.
    select b.fiscal_year_start_month, b.fiscal_year_start_day into v_month, v_day
      from public.book_profiles b
     where b.workspace_id = p_workspace_id and b.effective_from <= p_document_date
     order by b.effective_from desc limit 1;
    v_month := coalesce(v_month, 1);
    v_start := make_date(extract(year from p_document_date)::int, v_month, 1);
    v_start := least(v_start + (coalesce(v_day, 1) - 1), (v_start + interval '1 month')::date - 1);
    if v_start > p_document_date then v_start := v_start - interval '1 year'; end if;
    v_base := (v_start + interval '1 year')::date - 1;
  end if;
  return (v_base + make_interval(years => (v_rule ->> 'years')::int))::date;
end;
$fn$;
revoke execute on function public.retention_until(uuid, text, date) from public, anon;
grant execute on function public.retention_until(uuid, text, date) to authenticated;

-- ── 3. the erasure preview states the rule ────────────────────────────
do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef('public.preview_my_erasure(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$'basis', 'accounting evidence the space must keep; issued documents are not rewritten',
        'period', 'the statutory accounting period of ' || coalesce(v_country, 'the workspace''s country')),$a$,
    $a$'basis', 'accounting evidence the space must keep; issued documents are not rewritten',
        'period', coalesce((public.retention_rule_of(v_country, 'invoice') ->> 'years') || ' years'
                           || case when public.retention_rule_of(v_country, 'invoice') ->> 'from' = 'fiscal_year_end'
                                   then ' from the end of the fiscal year' else ' from the document date' end
                           || ' (' || (case when public.retention_rule_of(v_country, 'invoice') ->> 'country' = '*' then 'default rule'
                                            else public.retention_rule_of(v_country, 'invoice') ->> 'country' end) || ')',
                           'the statutory accounting period of ' || coalesce(v_country, 'the workspace''s country')),
        'until', public.retention_until(p_workspace_id, 'invoice',
                   (select max(i.issued_at)::date from public.invoices i where i.member_id = v_me.id))),$a$);
  v_def := pg_temp.anchor_replace(v_def,
    $a$'basis', 'the space''s accounts',
        'period', 'the statutory accounting period of ' || coalesce(v_country, 'the workspace''s country')),$a$,
    $a$'basis', 'the space''s accounts',
        'period', coalesce((public.retention_rule_of(v_country, 'books') ->> 'years') || ' years'
                           || case when public.retention_rule_of(v_country, 'books') ->> 'from' = 'fiscal_year_end'
                                   then ' from the end of the fiscal year' else ' from the document date' end
                           || ' (' || (case when public.retention_rule_of(v_country, 'books') ->> 'country' = '*' then 'default rule'
                                            else public.retention_rule_of(v_country, 'books') ->> 'country' end) || ')',
                           'the statutory accounting period of ' || coalesce(v_country, 'the workspace''s country')),
        'until', public.retention_until(p_workspace_id, 'books',
                   (select max(l.created_at)::date from public.ledger_entries l where l.member_id = v_me.id))),$a$);
  if v_def is null or position($a$retention_rule_of(v_country, 'books')$a$ in v_def) = 0
     or position($a$retention_rule_of(v_country, 'invoice')$a$ in v_def) = 0 then
    raise exception '0480: preview_my_erasure anchor missing';
  end if;
  execute v_def;
end
$migration$;

-- ── 4. the seed ───────────────────────────────────────────────────────
-- BEGIN GENERATED SEED (dart run tool/build_tax_reference_seed.dart)
insert into public.tax_reference
  (domain, country, key, valid_from, value, source, confirmed)
values
('retention', '*', 'books', '1900-01-01', '{"years":10,"from":"fiscal_year_end"}'::jsonb, 'A conservative default for a country without its own row: the longest period among the countries listed (10 years) for invoices, books and vouchers, 6 years for correspondence; the owner confirms the rule of the country (#2571); not yet verified by a person with the authority to confirm it', false),
('retention', '*', 'correspondence', '1900-01-01', '{"years":6,"from":"fiscal_year_end"}'::jsonb, 'A conservative default for a country without its own row: the longest period among the countries listed (10 years) for invoices, books and vouchers, 6 years for correspondence; the owner confirms the rule of the country (#2571); not yet verified by a person with the authority to confirm it', false),
('retention', '*', 'invoice', '1900-01-01', '{"years":10,"from":"fiscal_year_end"}'::jsonb, 'A conservative default for a country without its own row: the longest period among the countries listed (10 years) for invoices, books and vouchers, 6 years for correspondence; the owner confirms the rule of the country (#2571); not yet verified by a person with the authority to confirm it', false),
('retention', '*', 'voucher', '1900-01-01', '{"years":10,"from":"fiscal_year_end"}'::jsonb, 'A conservative default for a country without its own row: the longest period among the countries listed (10 years) for invoices, books and vouchers, 6 years for correspondence; the owner confirms the rule of the country (#2571); not yet verified by a person with the authority to confirm it', false),
('retention', 'AT', 'books', '1900-01-01', '{"years":7,"from":"fiscal_year_end"}'::jsonb, 'Bundesabgabenordnung §132: books, vouchers and business papers 7 years from the end of the calendar year they relate to; UStG §18 Abs. 10 (longer for real estate) (#2571); not yet verified by a person with the authority to confirm it', false),
('retention', 'AT', 'correspondence', '1900-01-01', '{"years":7,"from":"fiscal_year_end"}'::jsonb, 'Bundesabgabenordnung §132: books, vouchers and business papers 7 years from the end of the calendar year they relate to; UStG §18 Abs. 10 (longer for real estate) (#2571); not yet verified by a person with the authority to confirm it', false),
('retention', 'AT', 'invoice', '1900-01-01', '{"years":7,"from":"fiscal_year_end"}'::jsonb, 'Bundesabgabenordnung §132: books, vouchers and business papers 7 years from the end of the calendar year they relate to; UStG §18 Abs. 10 (longer for real estate) (#2571); not yet verified by a person with the authority to confirm it', false),
('retention', 'AT', 'voucher', '1900-01-01', '{"years":7,"from":"fiscal_year_end"}'::jsonb, 'Bundesabgabenordnung §132: books, vouchers and business papers 7 years from the end of the calendar year they relate to; UStG §18 Abs. 10 (longer for real estate) (#2571); not yet verified by a person with the authority to confirm it', false),
('retention', 'CA', 'books', '1900-01-01', '{"years":6,"from":"fiscal_year_end"}'::jsonb, 'Income Tax Act (Canada) s.230(4) and Excise Tax Act s.286(3): books and records 6 years from the end of the last tax year they relate to (#2571); not yet verified by a person with the authority to confirm it', false),
('retention', 'CA', 'correspondence', '1900-01-01', '{"years":6,"from":"fiscal_year_end"}'::jsonb, 'Income Tax Act (Canada) s.230(4) and Excise Tax Act s.286(3): books and records 6 years from the end of the last tax year they relate to (#2571); not yet verified by a person with the authority to confirm it', false),
('retention', 'CA', 'invoice', '1900-01-01', '{"years":6,"from":"fiscal_year_end"}'::jsonb, 'Income Tax Act (Canada) s.230(4) and Excise Tax Act s.286(3): books and records 6 years from the end of the last tax year they relate to (#2571); not yet verified by a person with the authority to confirm it', false),
('retention', 'CA', 'voucher', '1900-01-01', '{"years":6,"from":"fiscal_year_end"}'::jsonb, 'Income Tax Act (Canada) s.230(4) and Excise Tax Act s.286(3): books and records 6 years from the end of the last tax year they relate to (#2571); not yet verified by a person with the authority to confirm it', false),
('retention', 'CH', 'books', '1900-01-01', '{"years":10,"from":"fiscal_year_end"}'::jsonb, 'Obligationenrecht Art. 958f: books, accounting vouchers and business correspondence 10 years from the end of the financial year; MWSTG Art. 70 (VAT records 10 years) (#2571); not yet verified by a person with the authority to confirm it', false),
('retention', 'CH', 'correspondence', '1900-01-01', '{"years":10,"from":"fiscal_year_end"}'::jsonb, 'Obligationenrecht Art. 958f: books, accounting vouchers and business correspondence 10 years from the end of the financial year; MWSTG Art. 70 (VAT records 10 years) (#2571); not yet verified by a person with the authority to confirm it', false),
('retention', 'CH', 'invoice', '1900-01-01', '{"years":10,"from":"fiscal_year_end"}'::jsonb, 'Obligationenrecht Art. 958f: books, accounting vouchers and business correspondence 10 years from the end of the financial year; MWSTG Art. 70 (VAT records 10 years) (#2571); not yet verified by a person with the authority to confirm it', false),
('retention', 'CH', 'voucher', '1900-01-01', '{"years":10,"from":"fiscal_year_end"}'::jsonb, 'Obligationenrecht Art. 958f: books, accounting vouchers and business correspondence 10 years from the end of the financial year; MWSTG Art. 70 (VAT records 10 years) (#2571); not yet verified by a person with the authority to confirm it', false),
('retention', 'DE', 'books', '1900-01-01', '{"years":10,"from":"fiscal_year_end"}'::jsonb, 'Abgabenordnung §147 Abs. 1 and 3, as amended by the Bureaucracy Relief Act IV (2025): booking vouchers and invoices 8 years, books and annual accounts 10 years, commercial letters 6 years, counted from the end of the calendar year of the document; HGB §257 (#2571); not yet verified by a person with the authority to confirm it', false),
('retention', 'DE', 'correspondence', '1900-01-01', '{"years":6,"from":"fiscal_year_end"}'::jsonb, 'Abgabenordnung §147 Abs. 1 and 3, as amended by the Bureaucracy Relief Act IV (2025): booking vouchers and invoices 8 years, books and annual accounts 10 years, commercial letters 6 years, counted from the end of the calendar year of the document; HGB §257 (#2571); not yet verified by a person with the authority to confirm it', false),
('retention', 'DE', 'invoice', '1900-01-01', '{"years":8,"from":"fiscal_year_end"}'::jsonb, 'Abgabenordnung §147 Abs. 1 and 3, as amended by the Bureaucracy Relief Act IV (2025): booking vouchers and invoices 8 years, books and annual accounts 10 years, commercial letters 6 years, counted from the end of the calendar year of the document; HGB §257 (#2571); not yet verified by a person with the authority to confirm it', false),
('retention', 'DE', 'voucher', '1900-01-01', '{"years":8,"from":"fiscal_year_end"}'::jsonb, 'Abgabenordnung §147 Abs. 1 and 3, as amended by the Bureaucracy Relief Act IV (2025): booking vouchers and invoices 8 years, books and annual accounts 10 years, commercial letters 6 years, counted from the end of the calendar year of the document; HGB §257 (#2571); not yet verified by a person with the authority to confirm it', false),
('retention', 'FR', 'books', '1900-01-01', '{"years":10,"from":"fiscal_year_end"}'::jsonb, 'Code de commerce L123-22 (accounting books and vouchers 10 years); Livre des procédures fiscales L102 B (documents for the tax audit 6 years) (#2571); not yet verified by a person with the authority to confirm it', false),
('retention', 'FR', 'correspondence', '1900-01-01', '{"years":6,"from":"fiscal_year_end"}'::jsonb, 'Code de commerce L123-22 (accounting books and vouchers 10 years); Livre des procédures fiscales L102 B (documents for the tax audit 6 years) (#2571); not yet verified by a person with the authority to confirm it', false),
('retention', 'FR', 'invoice', '1900-01-01', '{"years":6,"from":"fiscal_year_end"}'::jsonb, 'Code de commerce L123-22 (accounting books and vouchers 10 years); Livre des procédures fiscales L102 B (documents for the tax audit 6 years) (#2571); not yet verified by a person with the authority to confirm it', false),
('retention', 'FR', 'voucher', '1900-01-01', '{"years":6,"from":"fiscal_year_end"}'::jsonb, 'Code de commerce L123-22 (accounting books and vouchers 10 years); Livre des procédures fiscales L102 B (documents for the tax audit 6 years) (#2571); not yet verified by a person with the authority to confirm it', false),
('retention', 'GB', 'books', '1900-01-01', '{"years":6,"from":"fiscal_year_end"}'::jsonb, 'HMRC VAT Notice 700/21 s.5 and Finance Act 1998 Sch.18 para 21: VAT records 6 years; Companies Act 2006 s.388 (accounting records 6 years for a private company) from the end of the accounting period (#2571); not yet verified by a person with the authority to confirm it', false),
('retention', 'GB', 'correspondence', '1900-01-01', '{"years":6,"from":"fiscal_year_end"}'::jsonb, 'HMRC VAT Notice 700/21 s.5 and Finance Act 1998 Sch.18 para 21: VAT records 6 years; Companies Act 2006 s.388 (accounting records 6 years for a private company) from the end of the accounting period (#2571); not yet verified by a person with the authority to confirm it', false),
('retention', 'GB', 'invoice', '1900-01-01', '{"years":6,"from":"fiscal_year_end"}'::jsonb, 'HMRC VAT Notice 700/21 s.5 and Finance Act 1998 Sch.18 para 21: VAT records 6 years; Companies Act 2006 s.388 (accounting records 6 years for a private company) from the end of the accounting period (#2571); not yet verified by a person with the authority to confirm it', false),
('retention', 'GB', 'voucher', '1900-01-01', '{"years":6,"from":"fiscal_year_end"}'::jsonb, 'HMRC VAT Notice 700/21 s.5 and Finance Act 1998 Sch.18 para 21: VAT records 6 years; Companies Act 2006 s.388 (accounting records 6 years for a private company) from the end of the accounting period (#2571); not yet verified by a person with the authority to confirm it', false),
('retention', 'IE', 'books', '1900-01-01', '{"years":6,"from":"fiscal_year_end"}'::jsonb, 'Value-Added Tax Consolidation Act 2010 s.84(3): records 6 years; Companies Act 2014 s.285 (accounting records 6 years) (#2571); not yet verified by a person with the authority to confirm it', false),
('retention', 'IE', 'correspondence', '1900-01-01', '{"years":6,"from":"fiscal_year_end"}'::jsonb, 'Value-Added Tax Consolidation Act 2010 s.84(3): records 6 years; Companies Act 2014 s.285 (accounting records 6 years) (#2571); not yet verified by a person with the authority to confirm it', false),
('retention', 'IE', 'invoice', '1900-01-01', '{"years":6,"from":"fiscal_year_end"}'::jsonb, 'Value-Added Tax Consolidation Act 2010 s.84(3): records 6 years; Companies Act 2014 s.285 (accounting records 6 years) (#2571); not yet verified by a person with the authority to confirm it', false),
('retention', 'IE', 'voucher', '1900-01-01', '{"years":6,"from":"fiscal_year_end"}'::jsonb, 'Value-Added Tax Consolidation Act 2010 s.84(3): records 6 years; Companies Act 2014 s.285 (accounting records 6 years) (#2571); not yet verified by a person with the authority to confirm it', false),
('retention', 'US', 'books', '1900-01-01', '{"years":4,"from":"document_date"}'::jsonb, 'IRS Publication 583 and 26 CFR 31.6001-1(e)(2): the federal default of 4 years; several states ask longer (a per-state override is a separate setting) (#2571); not yet verified by a person with the authority to confirm it', false),
('retention', 'US', 'correspondence', '1900-01-01', '{"years":4,"from":"document_date"}'::jsonb, 'IRS Publication 583 and 26 CFR 31.6001-1(e)(2): the federal default of 4 years; several states ask longer (a per-state override is a separate setting) (#2571); not yet verified by a person with the authority to confirm it', false),
('retention', 'US', 'invoice', '1900-01-01', '{"years":4,"from":"document_date"}'::jsonb, 'IRS Publication 583 and 26 CFR 31.6001-1(e)(2): the federal default of 4 years; several states ask longer (a per-state override is a separate setting) (#2571); not yet verified by a person with the authority to confirm it', false),
('retention', 'US', 'voucher', '1900-01-01', '{"years":4,"from":"document_date"}'::jsonb, 'IRS Publication 583 and 26 CFR 31.6001-1(e)(2): the federal default of 4 years; several states ask longer (a per-state override is a separate setting) (#2571); not yet verified by a person with the authority to confirm it', false)
on conflict (domain, country, key, valid_from) do nothing;
-- END GENERATED SEED

select public.set_deskilo_schema_version(480);
