-- SPDX-License-Identifier: 0BSD
-- 0182 — #985: VAT like an ERP — dated rate versions, one tax point per
-- line, and a counterparty dimension.
--
-- A rate row becomes one VERSION of a value: valid_from / valid_to and
-- supersedes_id link the versions of the same family. Items keep pointing
-- at the row they point at; vat_rate_percent_at(rate, date) walks the
-- family and returns the value in force on that date, so a change by law
-- is a new row and never an edit — the transactions already taxed keep
-- their tax, and only the supplies dated after the change use the new
-- value. The tax point of a billed month is its last day, or today when
-- the month is billed ahead (the prepayment rule, art. 65). Charges
-- stamped at booking (services, packages) stay authoritative; unstamped
-- ledger rows resolve at the period's tax point, which never moves once
-- the period is over.
--
-- The counterparty dimension: members.vat_treatment — auto (the #895
-- rule), domestic, reverse_charge (AE), export (G), exempt (E with a
-- reason). create_invoice applies the matrix business × product.
--
-- Harnessed live (rolled back): a family 20 % → 21 % effective 2026-09-01:
-- August lines at 20, September at 21, the successor read backwards gives
-- 20, a service charged today carries 21; export → every line 0 and G;
-- exempt → E with the reason; domestic on an EU business → the rate.

alter table public.vat_rates
  add column if not exists valid_from date not null default '1900-01-01',
  add column if not exists valid_to date,
  add column if not exists supersedes_id uuid references public.vat_rates(id) on delete set null;
alter table public.vat_rates drop constraint if exists vat_rates_validity_check;
alter table public.vat_rates add constraint vat_rates_validity_check
  check (valid_to is null or valid_to > valid_from);

alter table public.members
  add column if not exists vat_treatment text not null default 'auto',
  add column if not exists vat_exemption_reason text not null default '';
alter table public.members drop constraint if exists members_vat_treatment_check;
alter table public.members add constraint members_vat_treatment_check
  check (vat_treatment in ('auto', 'domestic', 'reverse_charge', 'export', 'exempt'));
alter table public.members drop constraint if exists members_vat_exemption_reason_check;
alter table public.members add constraint members_vat_exemption_reason_check
  check (char_length(vat_exemption_reason) <= 200);

-- The family of a rate: every version reachable through supersedes_id,
-- in both directions.
create or replace function public.vat_rate_family(p_rate_id uuid)
returns setof public.vat_rates
language sql stable security definer set search_path = public as $fn$
  with recursive fam as (
    select r.* from public.vat_rates r where r.id = p_rate_id
    union
    select r.* from public.vat_rates r
      join fam on r.supersedes_id = fam.id or fam.supersedes_id = r.id
  )
  select * from fam;
$fn$;

-- The value of a rate's family in force on a date. Null when the family
-- has no active version at all — callers fall back to the default.
create or replace function public.vat_rate_percent_at(p_rate_id uuid, p_date date)
returns numeric
language sql stable security definer set search_path = public as $fn$
  select coalesce(
    (select f.percent from public.vat_rate_family(p_rate_id) f
      where f.active and f.valid_from <= p_date
        and (f.valid_to is null or f.valid_to > p_date)
      order by f.valid_from desc, (f.id = p_rate_id) desc
      limit 1),
    (select r.percent from public.vat_rates r where r.id = p_rate_id and r.active));
$fn$;

create or replace function public.workspace_default_vat_rate_id(p_workspace_id uuid)
returns uuid
language sql stable security definer set search_path = public as $fn$
  select id from public.vat_rates
   where workspace_id = p_workspace_id and is_default and active
   limit 1;
$fn$;

create or replace function public.workspace_default_vat_percent(p_workspace_id uuid, p_date date)
returns numeric
language sql stable security definer set search_path = public as $fn$
  select case when public.workspace_charges_vat(p_workspace_id) then
    coalesce(public.vat_rate_percent_at(
      public.workspace_default_vat_rate_id(p_workspace_id), p_date), 0)
  else 0 end;
$fn$;

create or replace function public.workspace_default_vat_percent(p_workspace_id uuid)
returns numeric
language sql stable security definer set search_path = public as $fn$
  select public.workspace_default_vat_percent(p_workspace_id, current_date);
$fn$;

create or replace function public.workspace_tariff_vat_percent(p_workspace_id uuid, p_date date)
returns numeric
language sql stable security definer set search_path = public as $fn$
  select coalesce(
    (select public.vat_rate_percent_at(w.subscription_vat_rate_id, p_date)
       from public.workspaces w where w.id = p_workspace_id),
    public.workspace_default_vat_percent(p_workspace_id, p_date));
$fn$;

create or replace function public.workspace_tariff_vat_percent(p_workspace_id uuid)
returns numeric
language sql stable security definer set search_path = public as $fn$
  select public.workspace_tariff_vat_percent(p_workspace_id, current_date);
$fn$;

-- The tax point of a billed month: its last day, or today when the month
-- is billed ahead.
create or replace function public.vat_tax_point(p_period text)
returns date
language sql immutable as $fn$
  select least(
    (to_date(p_period || '-01', 'YYYY-MM-DD') + interval '1 month' - interval '1 day')::date,
    current_date);
$fn$;

-- The counterparty dimension, set by whoever may issue invoices.
create or replace function public.set_member_vat_treatment(p_member_id uuid, p_treatment text, p_reason text default '')
returns void
language plpgsql security definer set search_path = public as $fn$
declare
  v_target public.members;
begin
  select * into v_target from public.members where id = p_member_id;
  if v_target.id is null then raise exception 'unknown member'; end if;
  if not public.has_permission(v_target.workspace_id, 'issueInvoices') then
    raise exception 'not allowed to set the VAT treatment';
  end if;
  if p_treatment not in ('auto', 'domestic', 'reverse_charge', 'export', 'exempt') then
    raise exception 'unknown VAT treatment';
  end if;
  update public.members
     set vat_treatment = p_treatment,
         vat_exemption_reason = left(coalesce(p_reason, ''), 200)
   where id = p_member_id;
end;
$fn$;

-- set_vat_rates carries the versions: valid_from, valid_to, supersedes_id.
create or replace function public.set_vat_rates(p_workspace_id uuid, p_rates jsonb)
returns void
language plpgsql security definer set search_path = public as $fn$
declare
  v_rate jsonb;
  v_defaults int := 0;
  v_keep uuid[] := '{}';
  v_id uuid;
  v_super uuid;
begin
  if not public.has_permission(p_workspace_id, 'manageBilling') then
    raise exception 'not the owner of this workspace';
  end if;
  if p_rates is null or jsonb_typeof(p_rates) <> 'array' then
    raise exception 'rates must be an array';
  end if;
  for v_rate in select * from jsonb_array_elements(p_rates) loop
    if coalesce((v_rate->>'is_default')::boolean, false) then
      v_defaults := v_defaults + 1;
    end if;
  end loop;
  if jsonb_array_length(p_rates) > 0 and v_defaults <> 1 then
    raise exception 'exactly one rate must be the default';
  end if;

  for v_rate in select * from jsonb_array_elements(p_rates) loop
    v_super := null;
    if nullif(v_rate->>'supersedes_id', '') is not null then
      select id into v_super from public.vat_rates
       where id = (v_rate->>'supersedes_id')::uuid and workspace_id = p_workspace_id;
    end if;
    if (v_rate->>'id') is not null and (v_rate->>'id') <> '' then
      v_id := (v_rate->>'id')::uuid;
      update public.vat_rates
         set label = v_rate->>'label',
             group_key = coalesce(nullif(v_rate->>'group_key', ''), group_key),
             outside_base = coalesce((v_rate->>'outside_base')::boolean, false),
             exemption_reason = left(coalesce(v_rate->>'exemption_reason', ''), 200),
             percent = (v_rate->>'percent')::numeric,
             category = coalesce(v_rate->>'category', 'S'),
             is_default = false,
             active = coalesce((v_rate->>'active')::boolean, true),
             valid_from = coalesce((nullif(v_rate->>'valid_from', ''))::date, valid_from),
             valid_to = (nullif(v_rate->>'valid_to', ''))::date,
             supersedes_id = case when v_rate ? 'supersedes_id' then v_super else supersedes_id end
       where id = v_id and workspace_id = p_workspace_id;
    else
      insert into public.vat_rates
        (workspace_id, label, percent, category, is_default, active, group_key, outside_base, exemption_reason,
         valid_from, valid_to, supersedes_id)
      values (
        p_workspace_id,
        v_rate->>'label',
        (v_rate->>'percent')::numeric,
        coalesce(v_rate->>'category', 'S'),
        false,
        coalesce((v_rate->>'active')::boolean, true),
        coalesce(nullif(v_rate->>'group_key', ''), 'standard'),
        coalesce((v_rate->>'outside_base')::boolean, false),
        left(coalesce(v_rate->>'exemption_reason', ''), 200),
        coalesce((nullif(v_rate->>'valid_from', ''))::date, '1900-01-01'::date),
        (nullif(v_rate->>'valid_to', ''))::date,
        v_super)
      returning id into v_id;
    end if;
    v_keep := v_keep || v_id;
  end loop;

  update public.vat_rates set active = false, is_default = false
   where workspace_id = p_workspace_id and not (id = any(v_keep));

  for v_rate in select * from jsonb_array_elements(p_rates) loop
    if coalesce((v_rate->>'is_default')::boolean, false) then
      update public.vat_rates set is_default = true
       where workspace_id = p_workspace_id
         and (case when (v_rate->>'id') is not null and (v_rate->>'id') <> ''
                   then id = (v_rate->>'id')::uuid
                   else label = v_rate->>'label'
                        and percent = (v_rate->>'percent')::numeric end);
    end if;
  end loop;
end;
$fn$;

-- invoice_lines_for at the period's tax point.
create or replace function public.invoice_lines_for(p_member_id uuid, p_period text)
returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_stmt jsonb;
  v_lines jsonb := '[]'::jsonb;
  v_row record;
  v_workspace uuid;
  v_default numeric;
  v_tariff numeric;
  v_acc record;
  -- #985 — the date whose rate this month's supplies carry.
  v_tax_point date;
begin
  v_stmt := public.member_statement(p_member_id, p_period);
  select workspace_id into v_workspace from public.members where id = p_member_id;
  v_tax_point := public.vat_tax_point(p_period);
  v_default := public.workspace_default_vat_percent(v_workspace, v_tax_point);
  v_tariff := public.workspace_tariff_vat_percent(v_workspace, v_tax_point);

  if (v_stmt->>'fee_cents')::int > 0 then
    v_lines := v_lines || jsonb_build_object(
      'kind', 'subscription',
      'label', v_stmt->>'subscription_pct',
      'quantity', 1,
      'vat_percent', v_tariff,
      'amount_cents', (v_stmt->>'fee_cents')::int);
  end if;
  if (v_stmt->>'overage_cents')::int > 0 then
    v_lines := v_lines || jsonb_build_object(
      'kind', 'overage',
      'label', '',
      'quantity', (v_stmt->>'extra_half_days')::int,
      'vat_percent', v_tariff,
      'amount_cents', (v_stmt->>'overage_cents')::int);
  end if;
  if jsonb_typeof(v_stmt->'accessory_supplement_by_rate') = 'array' then
    for v_acc in
      select (e.value->>'percent')::numeric as percent,
             (e.value->>'cents')::int as cents
        from jsonb_array_elements(v_stmt->'accessory_supplement_by_rate') e
    loop
      if v_acc.cents > 0 then
        v_lines := v_lines || jsonb_build_object(
          'kind', 'accessories', 'label', '', 'quantity', 1,
          'vat_percent', v_acc.percent,
          'amount_cents', v_acc.cents);
      end if;
    end loop;
  elsif coalesce((v_stmt->>'accessory_supplement_cents')::int, 0) > 0 then
    v_lines := v_lines || jsonb_build_object(
      'kind', 'accessories', 'label', '', 'quantity', 1,
      'vat_percent', v_default,
      'amount_cents', (v_stmt->>'accessory_supplement_cents')::int);
  end if;
  if coalesce((v_stmt->>'level_supplement_cents')::int, 0) > 0 then
    v_lines := v_lines || jsonb_build_object(
      'kind', 'level', 'label', '', 'quantity', 1,
      'vat_percent', v_default,
      'amount_cents', (v_stmt->>'level_supplement_cents')::int);
  end if;
  if coalesce((v_stmt->>'office_supplement_cents')::int, 0) > 0 then
    v_lines := v_lines || jsonb_build_object(
      'kind', 'office', 'label', '', 'quantity', 1,
      'vat_percent', v_default,
      'amount_cents', (v_stmt->>'office_supplement_cents')::int);
  end if;
  if coalesce((v_stmt->>'desk_supplement_cents')::int, 0) > 0 then
    v_lines := v_lines || jsonb_build_object(
      'kind', 'desk', 'label', '', 'quantity', 1,
      'vat_percent', v_default,
      'amount_cents', (v_stmt->>'desk_supplement_cents')::int);
  end if;

  for v_row in
    select kind, category, description, amount_cents, vat_percent
      from public.ledger_entries le
     where le.member_id = p_member_id
       and le.period = p_period
       and ((le.kind = 'charge'
             and le.category in ('service', 'package', 'adjustment'))
         or (le.kind = 'credit'
             and le.category in ('payment', 'expense', 'adjustment')
             and not exists (
               select 1 from public.invoice_match_payments jr
               where jr.payment_ledger_id = le.id)))
     order by le.created_at
  loop
    v_lines := v_lines || jsonb_build_object(
      'kind', v_row.category,
      'label', v_row.description,
      'quantity', 1,
      -- The rate stamped when the charge was booked; else the default
      -- at the period's tax point. A credit is money moving: no VAT.
      'vat_percent', case when v_row.kind = 'credit'
                          then coalesce(v_row.vat_percent, 0)
                          else coalesce(v_row.vat_percent, v_default) end,
      'amount_cents', case when v_row.kind = 'credit'
                           then -v_row.amount_cents
                           else v_row.amount_cents end);
  end loop;

  return v_lines;
end;
$fn$;

-- Anchored patches: member_statement (accessory slices at the tax
-- point), record_service_charge and buy_package (the value of today),
-- create_invoice (the counterparty matrix), the configuration transfer
-- (versions travel).
do $patch$
declare
  v_def text;
  v_old text;
  v_new text;
begin
  -- member_statement
  select pg_get_functiondef(p.oid) into v_def from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'member_statement';
  v_old := '  v_acc_default numeric;';
  if position(v_old in v_def) = 0 then raise exception 'anchor A missing'; end if;
  v_def := replace(v_def, v_old, '  v_acc_default numeric;' || E'\n' || '  v_tax_point date;');
  v_old := '    v_acc_default := public.workspace_default_vat_percent(v_member.workspace_id);';
  if position(v_old in v_def) = 0 then raise exception 'anchor B missing'; end if;
  v_def := replace(v_def, v_old,
    '    v_tax_point := public.vat_tax_point(p_period);' || E'\n' ||
    '    v_acc_default := public.workspace_default_vat_percent(v_member.workspace_id, v_tax_point);');
  v_old := 'coalesce((select vr.percent from public.vat_rates vr' || E'\n' ||
           '                            where vr.id = a.vat_rate_id and vr.active),';
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 2 then
    raise exception 'anchor C must occur twice';
  end if;
  v_def := replace(v_def, v_old, 'coalesce(public.vat_rate_percent_at(a.vat_rate_id, v_tax_point),');
  execute v_def;

  -- record_service_charge
  select pg_get_functiondef(p.oid) into v_def from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'record_service_charge';
  v_old := '        (select percent from public.vat_rates' || E'\n' ||
           '          where id = v_service.vat_rate_id and active),';
  if position(v_old in v_def) = 0 then raise exception 'anchor D missing'; end if;
  v_def := replace(v_def, v_old, '        public.vat_rate_percent_at(v_service.vat_rate_id, current_date),');
  execute v_def;

  -- buy_package
  select pg_get_functiondef(p.oid) into v_def from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'buy_package';
  v_old := '        (select percent from public.vat_rates' || E'\n' ||
           '          where id = v_pkg.vat_rate_id and active),';
  if position(v_old in v_def) = 0 then raise exception 'anchor E missing'; end if;
  v_def := replace(v_def, v_old, '        public.vat_rate_percent_at(v_pkg.vat_rate_id, current_date),');
  execute v_def;

  -- create_invoice: the matrix business × product
  select pg_get_functiondef(p.oid) into v_def from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'create_invoice';
  v_old := '  v_reverse_charge boolean := false;';
  if position(v_old in v_def) = 0 then raise exception 'anchor F missing'; end if;
  v_def := replace(v_def, v_old, v_old || E'\n' ||
    '  v_treatment text := ''auto'';' || E'\n' ||
    '  v_treatment_reason text := '''';' || E'\n' ||
    '  v_buyer_category text := '''';');
  v_old := '  v_reverse_charge :=' || E'\n' ||
           '        coalesce(v_workspace.vat_regime, ''not_subject'') = ''vat_registered''';
  if position(v_old in v_def) = 0 then raise exception 'anchor G missing'; end if;
  v_def := replace(v_def, v_old,
    '  select coalesce(m.vat_treatment, ''auto''), coalesce(m.vat_exemption_reason, '''')' || E'\n' ||
    '    into v_treatment, v_treatment_reason from public.members m where m.id = v_subject.id;' || E'\n' ||
    '  v_reverse_charge := v_treatment = ''reverse_charge'' or (v_treatment = ''auto'' and' || E'\n' ||
    '        coalesce(v_workspace.vat_regime, ''not_subject'') = ''vat_registered''');
  v_old := '    and upper(btrim(v_member_country)) <> upper(btrim(v_workspace.country_code));' || E'\n' ||
           '  if v_reverse_charge then';
  if position(v_old in v_def) = 0 then raise exception 'anchor H missing'; end if;
  v_def := replace(v_def, v_old,
    '    and upper(btrim(v_member_country)) <> upper(btrim(v_workspace.country_code)));' || E'\n' ||
    '  -- #985 — the counterparty decides the category of every taxable line.' || E'\n' ||
    '  v_buyer_category := case when v_treatment = ''export'' then ''G''' || E'\n' ||
    '                           when v_treatment = ''exempt'' then ''E''' || E'\n' ||
    '                           when v_reverse_charge then ''AE'' else '''' end;' || E'\n' ||
    '  if v_buyer_category <> '''' then');
  v_old := '      ''category'', case when v_reverse_charge then ''AE''';
  if position(v_old in v_def) = 0 then raise exception 'anchor I missing'; end if;
  v_def := replace(v_def, v_old, '      ''category'', case when v_buyer_category <> '''' then v_buyer_category');
  v_old := '      ''vat_id'', v_member_vat));';
  if position(v_old in v_def) = 0 then raise exception 'anchor J missing'; end if;
  v_def := replace(v_def, v_old,
    '      ''vat_id'', v_member_vat,' || E'\n' ||
    '      ''vat_treatment'', v_treatment,' || E'\n' ||
    '      ''tax_exemption_reason'', v_treatment_reason));');
  execute v_def;

  -- export_workspace_configuration: the versions travel
  select pg_get_functiondef(p.oid) into v_def from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'export_workspace_configuration';
  v_old := '''outside_base'', r.outside_base, ''exemption_reason'', r.exemption_reason)';
  if position(v_old in v_def) = 0 then raise exception 'anchor K missing'; end if;
  v_def := replace(v_def, v_old,
    '''outside_base'', r.outside_base, ''exemption_reason'', r.exemption_reason,' || E'\n' ||
    '          ''valid_from'', r.valid_from, ''valid_to'', r.valid_to,' || E'\n' ||
    '          ''supersedes'', (select s.label from public.vat_rates s where s.id = r.supersedes_id))');
  execute v_def;

  -- import_workspace_configuration
  select pg_get_functiondef(p.oid) into v_def from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'import_workspace_configuration';
  v_old := '                v_row->>''group_key'', coalesce((v_row->>''outside_base'')::boolean, false), v_row->>''exemption_reason'');';
  if position(v_old in v_def) = 0 then raise exception 'anchor L missing'; end if;
  v_def := replace(v_def, v_old,
    '                v_row->>''group_key'', coalesce((v_row->>''outside_base'')::boolean, false), v_row->>''exemption_reason'');' || E'\n' ||
    '        update public.vat_rates set valid_from = coalesce((nullif(v_row->>''valid_from'', ''''))::date, ''1900-01-01''::date),' || E'\n' ||
    '               valid_to = (nullif(v_row->>''valid_to'', ''''))::date' || E'\n' ||
    '         where workspace_id = p_workspace_id and label = v_row->>''label'' and percent = (v_row->>''percent'')::numeric;');
  v_old := '               exemption_reason = v_row->>''exemption_reason''' || E'\n' ||
           '         where id = v_id;';
  if position(v_old in v_def) = 0 then raise exception 'anchor M missing'; end if;
  v_def := replace(v_def, v_old,
    '               exemption_reason = v_row->>''exemption_reason'',' || E'\n' ||
    '               valid_from = coalesce((nullif(v_row->>''valid_from'', ''''))::date, valid_from),' || E'\n' ||
    '               valid_to = (nullif(v_row->>''valid_to'', ''''))::date' || E'\n' ||
    '         where id = v_id;');
  v_old := '                        where e.value->>''label'' = r.label and (e.value->>''percent'')::numeric = r.percent);' || E'\n' ||
           '  end if;';
  if position(v_old in v_def) = 0 then raise exception 'anchor N missing'; end if;
  v_def := replace(v_def, v_old,
    '                        where e.value->>''label'' = r.label and (e.value->>''percent'')::numeric = r.percent);' || E'\n' ||
    '    -- #985 — the family, by label, once every version exists.' || E'\n' ||
    '    for v_row in select value from jsonb_array_elements(v_t->''vat_rates'') loop' || E'\n' ||
    '      if nullif(v_row->>''supersedes'', '''') is not null then' || E'\n' ||
    '        update public.vat_rates r set supersedes_id = public.vat_rate_id_by_label(p_workspace_id, v_row->>''supersedes'')' || E'\n' ||
    '         where r.workspace_id = p_workspace_id and r.label = v_row->>''label'' and r.percent = (v_row->>''percent'')::numeric;' || E'\n' ||
    '      end if;' || E'\n' ||
    '    end loop;' || E'\n' ||
    '  end if;');
  execute v_def;
end;
$patch$;
