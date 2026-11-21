-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- #4165 (A1) -- a standalone customer invoice: a named customer, itemised
-- ad hoc lines, explicit service, issue and due dates, and no member-month.
--
--   * `invoices.source` ('monthly' for every existing row, 'standalone' for
--     this producer) says what an invoice is; `kind` keeps its legacy values.
--     A standalone invoice has no period (the monthly uniqueness never sees
--     it), a service date and a due date.
--   * `standalone_invoice_drafts` persists the draft: a revision, and lines with
--     a stable `line_id`. It is written by `save_standalone_invoice_draft_v1`
--     only.
--   * `preview_standalone_invoice_v1` runs the real issuer in a block it rolls
--     back and reports what was missing or what would be frozen.
--     `issue_standalone_invoice_v1` issues the CONFIRMED revision under a
--     durable request identity: the same request and payload answers the same
--     invoice, another payload under it is refused, a stale revision refuses
--     before a number is taken, and one draft makes at most one invoice.
--   * The server computes every amount from exact decimals (quantity x entered
--     price / base quantity, net or gross, half away from zero per line, in the
--     currency's own minor unit) and freezes the `commercial` v1 facts of
--     #4162 beside the legacy line fields. A rate comes from the seller's own
--     VAT rates at the tax point, never from the client.
--
-- Not here: payment and the customer's own view (B), the composer (A2), approval
-- (an issue that the workspace's policy sends for approval is refused, not
-- bypassed), goods and sales-tax sellers (refused). Monthly `create_invoice`
-- and its callers are unchanged.

-- ── 1. what an invoice is ─────────────────────────────────────────────────
alter table public.invoices
  add column if not exists source text not null default 'monthly',
  add column if not exists service_date date,
  add column if not exists due_on date;
alter table public.invoices
  add constraint invoices_source_check check (source in ('monthly', 'standalone')),
  add constraint invoices_standalone_shape check (
    source = 'monthly'
    or (period is null and service_date is not null and due_on is not null
        and kind = 'full' and replaces_invoice_id is null));
comment on column public.invoices.source is
  '#4165 -- monthly: derived from a member-month (every invoice before this); standalone: itemised ad hoc lines under a draft';

-- ── 2. the receipts of the new command ───────────────────────────────────
alter table public.financial_command_receipts
  drop constraint financial_command_receipts_kind_check,
  drop constraint financial_command_receipts_subject_check,
  drop constraint financial_command_receipts_applied_check,
  add constraint financial_command_receipts_kind_check
    check (command_kind in ('invoice_issue', 'invoice_create', 'invoice_replace',
                            'settle_invoices', 'invoice_void', 'refund',
                            'standalone_invoice_issue')),
  add constraint financial_command_receipts_subject_check
    check ((command_kind in ('invoice_issue', 'invoice_create', 'invoice_replace',
                             'settle_invoices', 'standalone_invoice_issue'))
           = (subject_invoice_id is null)),
  add constraint financial_command_receipts_applied_check
    check (state <> 'applied'
           or (command_kind in ('invoice_issue', 'invoice_create', 'invoice_replace',
                                'settle_invoices', 'standalone_invoice_issue'))
              = (invoice_id is not null));

-- ── 3. the due date a standalone invoice states ──────────────────────────
-- Restated from the live definition with one branch: the due date confirmed on
-- the draft is the invoice's maturity, as a document term.
create or replace function public.invoice_maturity_freeze()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_tz text;
  v_days int;
begin
  select coalesce(nullif(w.timezone, ''), 'UTC') into v_tz
    from public.workspaces w where w.id = new.workspace_id;
  if new.source = 'standalone' and new.due_on is not null then
    insert into public.invoice_maturities (workspace_id, invoice_id, due_on, basis, terms_days, evidence)
    values (new.workspace_id, new.id, new.due_on, 'document_term',
            greatest(new.due_on - (new.issued_at at time zone v_tz)::date, 0),
            'the due date confirmed on the standalone invoice draft');
    return new;
  end if;
  v_days := least(greatest((public.setting_value(new.workspace_id, 'dunning.first_after_days') #>> '{}')::int, 0), 365);
  if public.setting_origin(new.workspace_id, 'dunning.first_after_days') = 'workspace' then
    insert into public.invoice_maturities (workspace_id, invoice_id, due_on, basis, terms_days, evidence)
    values (new.workspace_id, new.id,
            (new.issued_at at time zone v_tz)::date + v_days, 'document_term', v_days,
            format('the workspace payment term of %s days in force at issue', v_days));
  else
    insert into public.invoice_maturities (workspace_id, invoice_id, due_on, basis, terms_days, evidence)
    values (new.workspace_id, new.id,
            (new.issued_at at time zone v_tz)::date + v_days, 'default_term', v_days,
            format('no payment term configured; the default of %s days needs review', v_days));
  end if;
  return new;
end $fn$;
revoke execute on function public.invoice_maturity_freeze() from public, anon, authenticated;

-- ── 4. the draft ─────────────────────────────────────────────────────────
create table public.standalone_invoice_drafts (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  subject_member_id uuid not null,
  revision integer not null default 1 check (revision >= 1),
  status text not null default 'draft' check (status in ('draft', 'issued')),
  service_date date,
  due_on date,
  buyer_reference text not null default '' check (char_length(buyer_reference) <= 120),
  purchase_order text not null default '' check (char_length(purchase_order) <= 120),
  lines jsonb not null default '[]'::jsonb check (jsonb_typeof(lines) = 'array'),
  issued_invoice_id uuid,
  foreign key (workspace_id, subject_member_id) references public.members (workspace_id, id) on delete restrict,
  foreign key (workspace_id, issued_invoice_id) references public.invoices (workspace_id, id) on delete restrict,
  check ((status = 'issued') = (issued_invoice_id is not null))
);
select public.ensure_system_columns('standalone_invoice_drafts');
create unique index standalone_invoice_drafts_one_invoice
  on public.standalone_invoice_drafts (issued_invoice_id) where issued_invoice_id is not null;
create index standalone_invoice_drafts_workspace_idx
  on public.standalone_invoice_drafts (workspace_id, status);

alter table public.standalone_invoice_drafts enable row level security;
revoke all on public.standalone_invoice_drafts from public, anon, authenticated;
grant select on public.standalone_invoice_drafts to authenticated;
create policy standalone_invoice_drafts_issuers_read on public.standalone_invoice_drafts
  for select to authenticated
  using (public.has_permission(workspace_id, 'issueInvoices'));
create policy mcp_delegated_deny on public.standalone_invoice_drafts
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── 5. small internal helpers ────────────────────────────────────────────
-- The minor digits of a currency, as the kernel's Currencies table says.
create or replace function public.standalone_currency_exponent(p_currency text)
returns integer language sql immutable set search_path = public as $fn$
  select case
    when upper(p_currency) in ('BIF','CLP','DJF','GNF','ISK','JPY','KMF','KRW','PYG','RWF',
                               'UGX','VND','VUV','XAF','XOF','XPF') then 0
    when upper(p_currency) in ('BHD','IQD','JOD','KWD','LYD','OMR','TND') then 3
    else 2 end
$fn$;
revoke execute on function public.standalone_currency_exponent(text) from public, anon, authenticated;

-- The customer of a standalone invoice (a seam: the billing-customer work
-- restates it). Today: a member of this business, active, not a kiosk.
create or replace function public.standalone_invoice_subject(p_workspace_id uuid, p_subject uuid)
returns public.members language plpgsql stable security definer set search_path = public as $fn$
declare
  v_subject public.members;
begin
  select * into v_subject from public.members m
   where m.id = p_subject and m.workspace_id = p_workspace_id
     and m.status = 'active' and not m.is_kiosk;
  if v_subject.id is null then
    raise exception 'invoice_essentials_missing' using errcode = 'DKI01', detail = 'unknown_subject';
  end if;
  return v_subject;
end $fn$;
revoke execute on function public.standalone_invoice_subject(uuid, uuid) from public, anon, authenticated;

-- The buyer block of a standalone invoice (a seam, as above): the fields
-- `create_invoice` freezes for a member, from the profile or the managed identity.
create or replace function public.standalone_invoice_buyer(p_workspace_id uuid, p_subject uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_ws public.workspaces;
  v_subject public.members;
  v_name text; v_address text; v_country text; v_vat text; v_company text; v_street text;
  v_postal text; v_city text; v_legal text; v_email text; v_phone text; v_person text; v_courtesy text;
begin
  select * into v_ws from public.workspaces where id = p_workspace_id;
  select * into v_subject from public.members where id = p_subject and workspace_id = p_workspace_id;
  select coalesce(nullif(public.profile_full_name(pr), ''), pr.display_name, ''),
         coalesce(nullif(public.profile_postal_block(pr, v_ws.country_code, v_ws.default_locale), ''),
                  pr.address, ''),
         coalesce(pr.country_code, ''), coalesce(pr.vat_id, ''),
         coalesce(pr.company, ''), coalesce(pr.street, ''),
         coalesce(pr.postal_code, ''), coalesce(pr.city, ''),
         coalesce(pr.legal_id, ''), coalesce(pr.email, ''), coalesce(pr.phone, ''),
         coalesce(public.profile_person_name(pr), ''), coalesce(pr.courtesy, '')
    into v_name, v_address, v_country, v_vat, v_company, v_street, v_postal, v_city,
         v_legal, v_email, v_phone, v_person, v_courtesy
    from jsonb_populate_record(null::public.profiles,
           coalesce((select to_jsonb(p) from public.profiles p where p.id = v_subject.user_id),
                    coalesce((select mi.identity from public.managed_identities mi
                               where mi.member_id = v_subject.id), '{}'::jsonb))) pr;
  return jsonb_build_object(
    'name', v_name, 'company', v_company, 'person', v_person, 'courtesy', v_courtesy,
    'street', case when v_street <> '' then v_street else v_address end,
    'postal_code', v_postal, 'city', v_city, 'legal_id', v_legal,
    'member_number', coalesce(v_subject.member_number, ''),
    'email', v_email, 'phone', v_phone,
    'country', coalesce(nullif(v_country, ''), v_ws.country_code),
    'vat_id', v_vat,
    'vat_treatment', coalesce(v_subject.vat_treatment, 'auto'),
    'tax_exemption_reason', coalesce(v_subject.vat_exemption_reason, ''));
end $fn$;
revoke execute on function public.standalone_invoice_buyer(uuid, uuid) from public, anon, authenticated;

-- One line: the facts entered, read exactly, and what the server freezes of
-- them. Returns {line, missing}; `missing` names each fact that is not
-- acceptable as `line_<n>_<fact>`. Nothing is rounded but the minor-unit amount.
create or replace function public.standalone_invoice_line_v1(
  p_line jsonb, p_index integer, p_currency text, p_percent numeric, p_category text,
  p_tax_point date
) returns jsonb language plpgsql stable set search_path = public as $fn$
declare
  v_missing text[] := '{}';
  v_pre text := 'line_' || p_index || '_';
  v_qty_text text := btrim(coalesce(p_line ->> 'quantity', ''));
  v_price_text text := btrim(coalesce(p_line ->> 'unit_price', ''));
  v_base_text text := btrim(coalesce(nullif(p_line ->> 'base_quantity', ''), '1'));
  v_basis text := coalesce(p_line ->> 'basis', '');
  v_supply text := coalesce(p_line ->> 'supply', '');
  v_desc text := btrim(coalesce(p_line ->> 'description', ''));
  v_unit jsonb := coalesce(p_line -> 'unit', '{}'::jsonb);
  v_unit_code text; v_unit_label text; v_unit_un text;
  v_qty numeric; v_price numeric; v_base numeric;
  v_exp integer := public.standalone_currency_exponent(p_currency);
  v_raw numeric; v_amount bigint; v_net bigint; v_tax bigint; v_gross bigint; v_t bigint;
  v_pct numeric := coalesce(p_percent, 0);
  v_line_id uuid;
  v_dec constant text := '^[0-9]{1,12}(\.[0-9]{1,6})?$';
begin
  if v_desc = '' or char_length(v_desc) > 300 then v_missing := v_missing || (v_pre || 'description'); end if;
  if v_qty_text !~ v_dec then v_missing := v_missing || (v_pre || 'quantity');
  else
    v_qty := v_qty_text::numeric;
    if v_qty <= 0 then v_missing := v_missing || (v_pre || 'quantity'); end if;
  end if;
  if v_price_text !~ v_dec then v_missing := v_missing || (v_pre || 'unit_price');
  else v_price := v_price_text::numeric; end if;
  if v_base_text !~ v_dec then v_missing := v_missing || (v_pre || 'base_quantity');
  else
    v_base := v_base_text::numeric;
    if v_base <= 0 then v_missing := v_missing || (v_pre || 'base_quantity'); end if;
  end if;
  if v_basis not in ('net', 'gross') then v_missing := v_missing || (v_pre || 'basis'); end if;
  -- goods and every kind this version does not interpret are refused, never
  -- read as a service
  if v_supply not in ('general', 'property') then v_missing := v_missing || (v_pre || 'supply'); end if;
  v_unit_code := btrim(coalesce(v_unit ->> 'code', ''));
  v_unit_label := btrim(coalesce(v_unit ->> 'label', ''));
  v_unit_un := btrim(coalesce(v_unit ->> 'un_ece_code', ''));
  if v_unit_code = '' or char_length(v_unit_code) > 20 or v_unit_label = '' or char_length(v_unit_label) > 20
     or (v_unit_un <> '' and v_unit_un !~ '^[A-Z0-9]{2,3}$') then
    v_missing := v_missing || (v_pre || 'unit');
  end if;
  begin
    v_line_id := (p_line ->> 'line_id')::uuid;
  exception when others then v_line_id := null; end;
  if v_line_id is null then v_missing := v_missing || (v_pre || 'line_id'); end if;
  if cardinality(v_missing) > 0 then
    return jsonb_build_object('line', null, 'missing', to_jsonb(v_missing));
  end if;

  v_raw := v_qty * v_price / v_base * (10::numeric ^ v_exp);
  if v_raw > 2000000000 then
    return jsonb_build_object('line', null, 'missing', to_jsonb(array[v_pre || 'amount']));
  end if;
  v_amount := round(v_raw)::bigint;   -- half away from zero
  if v_basis = 'gross' then
    v_gross := v_amount;
    v_net := round(v_gross * 100.0 / (100 + v_pct))::bigint;
    v_tax := v_gross - v_net;
  else
    v_net := v_amount;
    v_tax := null;
    -- the tax that keeps the legacy reader's split of the gross equal to this net
    foreach v_t in array array[round(v_net * v_pct / 100)::bigint,
                               round(v_net * v_pct / 100)::bigint - 1,
                               round(v_net * v_pct / 100)::bigint + 1] loop
      if v_t >= 0 and round((v_net + v_t) * 100.0 / (100 + v_pct))::bigint = v_net then
        v_tax := v_t; exit;
      end if;
    end loop;
    if v_tax is null then
      return jsonb_build_object('line', null, 'missing', to_jsonb(array[v_pre || 'amount']));
    end if;
    v_gross := v_net + v_tax;
  end if;
  if v_gross > 2000000000 then
    return jsonb_build_object('line', null, 'missing', to_jsonb(array[v_pre || 'amount']));
  end if;
  return jsonb_build_object('missing', '[]'::jsonb, 'line', jsonb_build_object(
    'kind', 'service',
    'label', v_desc,
    'quantity', 1,
    'amount_cents', v_gross,
    'vat_percent', v_pct,
    'vat_category', p_category,
    'supply', v_supply,
    'commercial', jsonb_build_object(
      'version', 1,
      'line_id', v_line_id,
      'quantity', trim_scale(v_qty)::text,
      'unit', jsonb_build_object('code', v_unit_code, 'un_ece_code', v_unit_un, 'label', v_unit_label),
      'unit_price', jsonb_build_object(
        'amount', trim_scale(v_price)::text, 'currency', upper(p_currency),
        'basis', v_basis, 'base_quantity', trim_scale(v_base)::text),
      'supply', v_supply,
      'tax_facts', jsonb_build_object('tax_point', p_tax_point::text, 'category', p_category,
                                       'vat_percent', v_pct),
      'amounts', jsonb_build_object(
        'currency', upper(p_currency), 'net_minor', v_net::text,
        'tax_minor', v_tax::text, 'gross_minor', v_gross::text,
        'rule', 'half_up_per_line'))));
end $fn$;
revoke execute on function public.standalone_invoice_line_v1(jsonb, integer, text, numeric, text, date)
  from public, anon, authenticated;

-- ── 6. the issuer ────────────────────────────────────────────────────────
-- The sibling of `create_invoice` for a standalone draft: the same helpers
-- (the place of supply, the essentials, the numbering, the issuing site), the
-- month-dependent steps replaced: the tax point is the service date, the lines
-- are the draft's, no member-month is looked at. A missing or refused fact
-- raises DKI01 with its names BEFORE a number is taken.
create or replace function public.standalone_invoice_issue_core(
  p_workspace_id uuid,
  p_actor public.members,
  p_draft public.standalone_invoice_drafts
) returns uuid language plpgsql security definer set search_path = public as $fn$
declare
  v_ws public.workspaces;
  v_subject public.members;
  v_site public.sites;
  v_buyer jsonb;
  v_tp date;
  v_zero text;
  v_regime text;
  v_treatment text;
  v_treatment_reason text;
  v_capacity text;
  v_seller_country text;
  v_buyer_country text;
  v_gate jsonb;
  v_default_rate uuid;
  v_rate uuid;
  v_pct numeric;
  v_cat text;
  v_supply text;
  v_in jsonb;
  v_out jsonb;
  v_lines jsonb := '[]'::jsonb;
  v_missing text[] := '{}';
  v_idx integer := 0;
  v_total bigint := 0;
  v_vat_totals jsonb;
  v_parties jsonb;
  v_essentials text[];
  v_issuer_name text;
  v_number text;
  v_id uuid;
  v_signature text;
  v_capacity_unknown boolean;
  v_reverse_charge boolean;
begin
  if p_draft.status <> 'draft' then
    raise exception 'invoice_essentials_missing' using errcode = 'DKI01', detail = 'draft_closed';
  end if;
  if not public.invoice_issuing_enabled(p_workspace_id, 'full') then
    raise exception 'invoice_essentials_missing' using errcode = 'DKI01', detail = 'invoice_feature_disabled';
  end if;
  v_subject := public.standalone_invoice_subject(p_workspace_id, p_draft.subject_member_id);
  select * into v_ws from public.workspaces where id = p_workspace_id;
  v_regime := coalesce(v_ws.vat_regime, 'not_subject');

  if p_draft.service_date is null then v_missing := v_missing || 'service_date'; end if;
  if p_draft.due_on is null then v_missing := v_missing || 'due_on';
  elsif p_draft.due_on < current_date then v_missing := v_missing || 'due_on_before_issue';
  elsif p_draft.due_on > current_date + 365 then v_missing := v_missing || 'due_on_too_far'; end if;
  if jsonb_array_length(p_draft.lines) = 0 then v_missing := v_missing || 'lines'; end if;
  if jsonb_array_length(p_draft.lines) > 100 then v_missing := v_missing || 'lines_too_many'; end if;
  if v_ws.currency_code is null or v_ws.currency_code !~ '^[A-Z]{3}$' then
    v_missing := v_missing || 'currency';
  end if;
  -- a seller that adds sales tax to net amounts is not supported by this producer
  v_seller_country := coalesce(v_ws.country_code, '');
  v_gate := public.issuing_gate_of(v_seller_country);
  if coalesce(v_gate ->> 'tax_system', 'vat') = 'sales_tax'
     and coalesce((v_gate ->> 'supported')::boolean, false)
     and public.feature_effective(p_workspace_id, 'salesTax') then
    v_missing := v_missing || 'sales_tax_unsupported';
  end if;
  if cardinality(v_missing) > 0 then
    raise exception 'invoice_essentials_missing' using errcode = 'DKI01', detail = array_to_string(v_missing, ',');
  end if;

  v_tp := least(p_draft.service_date, current_date);
  v_zero := public.vat_zero_category(p_workspace_id, v_regime, v_tp);
  v_buyer := public.standalone_invoice_buyer(p_workspace_id, v_subject.id);
  v_treatment := coalesce(v_buyer ->> 'vat_treatment', 'auto');
  v_treatment_reason := coalesce(v_buyer ->> 'tax_exemption_reason', '');
  v_buyer_country := coalesce(nullif(v_buyer ->> 'country', ''), v_ws.country_code);
  v_site := public.document_site_for_member(v_subject.id);
  v_seller_country := case when v_site.id is not null and not v_site.is_default
                                and coalesce(v_site.country_code, '') <> ''
                           then v_site.country_code
                           else coalesce(v_ws.country_code, '') end;
  v_capacity := coalesce(public.invoice_legal_snapshot(
                  p_workspace_id, v_subject.id, '{}'::jsonb) ->> 'buyer_capacity', 'unknown');
  select r.id into v_default_rate from public.vat_rates r
   where r.workspace_id = p_workspace_id and r.is_default and r.active
   order by r.valid_from desc limit 1;

  for v_in in select e from jsonb_array_elements(p_draft.lines) e loop
    v_idx := v_idx + 1;
    v_supply := coalesce(v_in ->> 'supply', '');
    v_pct := 0;
    if v_regime <> 'not_subject' then
      begin
        v_rate := coalesce((v_in ->> 'vat_rate_id')::uuid, v_default_rate);
      exception when others then v_rate := null; end;
      if v_rate is null or not exists (select 1 from public.vat_rates r
                                        where r.id = v_rate and r.workspace_id = p_workspace_id) then
        v_missing := v_missing || ('line_' || v_idx || '_vat_rate');
        continue;
      end if;
      v_pct := public.vat_rate_percent_at(v_rate, v_tp);
      if v_pct is null then
        v_missing := v_missing || ('line_' || v_idx || '_vat_rate');
        continue;
      end if;
    end if;
    v_cat := case when v_supply in ('general', 'property') then
                public.supply_vat_category_for(
                  p_workspace_id, v_tp, v_treatment, v_supply, v_regime, v_seller_country,
                  v_buyer_country, v_capacity,
                  coalesce((v_ws.invoice_legal ->> 'reverse_charge')::boolean, true))
              else '' end;
    if v_cat <> '' then v_pct := 0; end if;
    v_out := public.standalone_invoice_line_v1(
      v_in, v_idx, v_ws.currency_code, v_pct,
      case when v_cat <> '' then v_cat when v_pct > 0 then 'S' else v_zero end, v_tp);
    if jsonb_array_length(v_out -> 'missing') > 0 then
      v_missing := v_missing || array(select jsonb_array_elements_text(v_out -> 'missing'));
    else
      v_lines := v_lines || jsonb_build_array(v_out -> 'line');
      v_total := v_total + (v_out #>> '{line,amount_cents}')::bigint;
    end if;
  end loop;
  if v_total > 2000000000 then v_missing := v_missing || 'total_amount'; end if;
  if v_total <= 0 and cardinality(v_missing) = 0 then v_missing := v_missing || 'total_not_positive'; end if;
  if cardinality(v_missing) > 0 then
    raise exception 'invoice_essentials_missing' using errcode = 'DKI01', detail = array_to_string(v_missing, ',');
  end if;

  v_reverse_charge := exists (select 1 from jsonb_array_elements(v_lines) l where l ->> 'vat_category' = 'AE');
  v_capacity_unknown :=
        v_capacity not in ('business', 'consumer')
    and v_treatment not in ('domestic', 'reverse_charge', 'export', 'exempt')
    and v_regime = 'vat_registered'
    and public.eu_country_code(v_buyer_country) <> public.eu_country_code(v_seller_country)
    and exists (select 1 from jsonb_array_elements(v_lines) l where l ->> 'supply' = 'general');

  -- the breakdown is the sum of the frozen line amounts, per rate and category
  select coalesce(jsonb_agg(jsonb_build_object(
           'percent', g.pct, 'category', g.cat,
           'gross_cents', g.gross, 'net_cents', g.net, 'vat_cents', g.gross - g.net)
         || public.vat_components_entry(v_seller_country, g.pct, g.net, g.gross - g.net)
         || case when g.cat = 'E' and g.pct = 0 and v_regime = 'vat_registered'
                      and v_treatment in ('auto', 'domestic')
                      and public.vat_zero_exemption_reason(p_workspace_id, v_tp) <> ''
                 then jsonb_build_object('exemption_reason',
                        public.vat_zero_exemption_reason(p_workspace_id, v_tp))
                 else '{}'::jsonb end
         order by g.pct desc, g.cat), '[]'::jsonb)
    into v_vat_totals
    from (
      select (l ->> 'vat_percent')::numeric as pct, l ->> 'vat_category' as cat,
             sum((l #>> '{commercial,amounts,gross_minor}')::bigint)::int as gross,
             sum((l #>> '{commercial,amounts,net_minor}')::bigint)::int as net
        from jsonb_array_elements(v_lines) l group by 1, 2) g;

  v_parties := jsonb_build_object(
    'seller', jsonb_build_object(
      'name', v_ws.name,
      'site', coalesce(v_site.name, ''),
      'site_id', v_site.id,
      'site_default', coalesce(v_site.is_default, true),
      'street', case when v_site.id is not null and not v_site.is_default and (v_site.street <> '' or v_site.city <> '') then v_site.street
                       else coalesce(nullif(v_ws.street, ''), coalesce(v_ws.address, '')) end,
      'city', case when v_site.id is not null and not v_site.is_default and (v_site.street <> '' or v_site.city <> '') then v_site.city else coalesce(v_ws.city, '') end,
      'postal_code', case when v_site.id is not null and not v_site.is_default and (v_site.street <> '' or v_site.city <> '') then v_site.postal_code else coalesce(v_ws.postal_code, '') end,
      'country', case when v_site.id is not null and not v_site.is_default and v_site.country_code <> '' then v_site.country_code else v_ws.country_code end,
      'vat_id', case when v_site.id is not null and not v_site.is_default and v_site.vat_id <> '' then v_site.vat_id else coalesce(v_ws.vat_id, '') end,
      'legal_id', case when v_site.id is not null and not v_site.is_default and v_site.legal_id <> '' then v_site.legal_id else coalesce(v_ws.legal_id, '') end,
      'vat_regime', v_regime,
      'tax_exemption_reason',
        case when v_site.id is not null and not v_site.is_default and v_site.tax_exemption_reason <> '' then v_site.tax_exemption_reason
             else coalesce(v_ws.tax_exemption_reason, '') end)
      || public.workspace_einvoice_address(p_workspace_id),
    'buyer', (v_buyer || jsonb_build_object(
      'reference', left(btrim(coalesce(p_draft.buyer_reference, '')), 120),
      'order', left(btrim(coalesce(p_draft.purchase_order, '')), 120)))
      || public.member_einvoice_address(v_subject.id));

  v_essentials := public.invoice_essentials_missing(p_workspace_id, v_subject.id, v_parties, v_vat_totals);
  if v_capacity_unknown then v_essentials := array_append(v_essentials, 'buyer_capacity_unknown'::text); end if;
  if public.feature_effective(p_workspace_id, 'viesVerification')
     and v_treatment not in ('domestic', 'reverse_charge', 'export', 'exempt')
     and v_reverse_charge
     and not exists (select 1 from jsonb_array_elements(v_lines) l where l ->> 'vat_category' in ('G', 'E')) then
    v_essentials := array_remove(v_essentials, 'vat_treatment_unreviewed'::text);
    if not public.member_vies_verified(v_subject.id, coalesce(v_buyer ->> 'vat_id', '')) then
      v_essentials := array_append(v_essentials, 'vies_unverified'::text);
    end if;
  end if;
  -- the workspace's policy may send this amount for approval: not bypassed here
  if public.validation_requires(p_workspace_id, 'invoice_issue', v_total::int) then
    v_essentials := array_append(v_essentials, 'approval_required'::text);
  end if;
  if cardinality(v_essentials) > 0 then
    raise exception 'invoice_essentials_missing' using errcode = 'DKI01', detail = array_to_string(v_essentials, ',');
  end if;

  select coalesce(display_name, '') into v_issuer_name from public.profiles where id = p_actor.user_id;
  v_number := public.next_document_number(p_workspace_id, 'invoice');
  v_id := gen_random_uuid();
  -- the signature of algorithm 7, over the same facts; a standalone invoice has no period
  v_signature := encode(extensions.digest(convert_to(concat_ws('|',
      v_id::text, v_number, p_workspace_id::text, v_subject.id::text,
      v_buyer ->> 'name', coalesce(v_buyer ->> 'street', ''), v_ws.name,
      coalesce(v_ws.address, ''), v_issuer_name,
      null::text, v_lines::text, v_total::text, v_ws.currency_code,
      now()::date::text, '', '', '',
      v_parties::text, v_vat_totals::text, 'full'),
      'UTF8'), 'sha256'), 'hex');

  insert into public.invoices
    (id, workspace_id, member_id, issuer_member_id, number, period, title,
     lines, total_cents, currency, member_name, member_address,
     workspace_name, workspace_address, issuer_name, signature,
     replaces_invoice_id, replaces_number, details, parties, vat_totals,
     kind, signature_algo, source, service_date, due_on)
  values
    (v_id, p_workspace_id, v_subject.id, p_actor.id, v_number, null,
     p_draft.service_date::text, v_lines, v_total::int, v_ws.currency_code,
     v_buyer ->> 'name', coalesce(v_buyer ->> 'street', ''), v_ws.name,
     case when v_site.id is not null and not v_site.is_default and (v_site.street <> '' or v_site.city <> '')
          then btrim(v_site.street || ', ' || v_site.postal_code || ' ' || v_site.city, ', ')
          else coalesce(v_ws.address, '') end, v_issuer_name, v_signature,
     null, '', null, v_parties, v_vat_totals,
     'full', 7, 'standalone', p_draft.service_date, p_draft.due_on);
  update public.standalone_invoice_drafts
     set status = 'issued', issued_invoice_id = v_id
   where id = p_draft.id;
  return v_id;
end $fn$;
revoke execute on function public.standalone_invoice_issue_core(uuid, public.members, public.standalone_invoice_drafts)
  from public, anon, authenticated;

-- ── 7. the commands ──────────────────────────────────────────────────────
-- Save a draft (new when p_draft_id is null). The expected revision guards a
-- concurrent edit: a stale one is refused. Every line keeps (or is given) a
-- stable line_id.
create or replace function public.save_standalone_invoice_draft_v1(
  p_workspace_id uuid,
  p_draft_id uuid,
  p_expected_revision integer,
  p_subject uuid,
  p_service_date date,
  p_due_on date,
  p_buyer_reference text,
  p_purchase_order text,
  p_lines jsonb
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_actor public.members;
  v_draft public.standalone_invoice_drafts;
  v_lines jsonb;
begin
  v_actor := public.issuing_member(p_workspace_id);
  perform public.standalone_invoice_subject(p_workspace_id, p_subject);
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) > 100 then
    raise exception 'invoice_essentials_missing' using errcode = 'DKI01', detail = 'lines';
  end if;
  if char_length(coalesce(p_buyer_reference, '')) > 120 or char_length(coalesce(p_purchase_order, '')) > 120 then
    raise exception 'invoice_essentials_missing' using errcode = 'DKI01', detail = 'buyer_reference';
  end if;
  select coalesce(jsonb_agg(
           case when jsonb_typeof(e) <> 'object' then e
                when e ? 'line_id' and (e ->> 'line_id') ~ '^[0-9a-fA-F-]{36}$' then e
                else e || jsonb_build_object('line_id', gen_random_uuid()) end
           order by o), '[]'::jsonb)
    into v_lines from jsonb_array_elements(p_lines) with ordinality t(e, o);
  perform pg_advisory_xact_lock(hashtext(p_workspace_id::text));
  if p_draft_id is null then
    insert into public.standalone_invoice_drafts
      (workspace_id, subject_member_id, service_date, due_on, buyer_reference, purchase_order, lines)
    values (p_workspace_id, p_subject, p_service_date, p_due_on,
            coalesce(p_buyer_reference, ''), coalesce(p_purchase_order, ''), v_lines)
    returning * into v_draft;
  else
    select * into v_draft from public.standalone_invoice_drafts d
     where d.id = p_draft_id and d.workspace_id = p_workspace_id for update;
    if v_draft.id is null then
      raise exception 'invoice_essentials_missing' using errcode = 'DKI01', detail = 'draft_unknown';
    end if;
    if v_draft.status <> 'draft' then
      raise exception 'invoice_essentials_missing' using errcode = 'DKI01', detail = 'draft_closed';
    end if;
    if v_draft.revision <> p_expected_revision then
      raise exception 'invoice_essentials_missing' using errcode = 'DKI01', detail = 'draft_stale';
    end if;
    update public.standalone_invoice_drafts
       set subject_member_id = p_subject, service_date = p_service_date, due_on = p_due_on,
           buyer_reference = coalesce(p_buyer_reference, ''), purchase_order = coalesce(p_purchase_order, ''),
           lines = v_lines, revision = revision + 1
     where id = v_draft.id returning * into v_draft;
  end if;
  return jsonb_build_object('draft_id', v_draft.id, 'revision', v_draft.revision, 'lines', v_draft.lines);
end $fn$;
revoke execute on function public.save_standalone_invoice_draft_v1(uuid, uuid, integer, uuid, date, date, text, text, jsonb)
  from public, anon;
grant execute on function public.save_standalone_invoice_draft_v1(uuid, uuid, integer, uuid, date, date, text, text, jsonb)
  to authenticated;

-- What issuing the CONFIRMED revision would freeze, or what is missing: the
-- real issuer, run in a block that is rolled back (the number it took too).
create or replace function public.preview_standalone_invoice_v1(
  p_workspace_id uuid, p_draft_id uuid, p_revision integer
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_actor public.members;
  v_draft public.standalone_invoice_drafts;
  v_id uuid;
  v_detail text;
  v_inv public.invoices;
begin
  v_actor := public.issuing_member(p_workspace_id);
  select * into v_draft from public.standalone_invoice_drafts d
   where d.id = p_draft_id and d.workspace_id = p_workspace_id;
  if v_draft.id is null then
    return jsonb_build_object('missing', jsonb_build_array('draft_unknown'), 'preview', null);
  end if;
  if v_draft.revision <> p_revision then
    return jsonb_build_object('missing', jsonb_build_array('draft_stale'), 'preview', null);
  end if;
  begin
    v_id := public.standalone_invoice_issue_core(p_workspace_id, v_actor, v_draft);
    select * into v_inv from public.invoices where id = v_id;
    raise exception using message = 'dry run', errcode = 'DKI02', detail = jsonb_build_object(
      'lines', v_inv.lines, 'vat_totals', v_inv.vat_totals, 'parties', v_inv.parties,
      'total_cents', v_inv.total_cents, 'currency', v_inv.currency,
      'service_date', v_inv.service_date, 'due_on', v_inv.due_on)::text;
  exception
    when sqlstate 'DKI01' then
      get stacked diagnostics v_detail = pg_exception_detail;
      return jsonb_build_object('missing', to_jsonb(string_to_array(v_detail, ',')), 'preview', null);
    when sqlstate 'DKI02' then
      get stacked diagnostics v_detail = pg_exception_detail;
      return jsonb_build_object('missing', '[]'::jsonb, 'preview', v_detail::jsonb);
  end;
end $fn$;
revoke execute on function public.preview_standalone_invoice_v1(uuid, uuid, integer) from public, anon;
grant execute on function public.preview_standalone_invoice_v1(uuid, uuid, integer) to authenticated;

-- Issue the confirmed revision under a durable request identity.
create or replace function public.issue_standalone_invoice_v1(
  p_workspace_id uuid, p_draft_id uuid, p_revision integer, p_request_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_actor public.members;
  v_draft public.standalone_invoice_drafts;
  v_digest text;
  v_id uuid;
  v_number text;
begin
  v_actor := public.issuing_member(p_workspace_id);
  if p_request_id is null then
    raise exception 'invoice_essentials_missing' using errcode = 'DKI01', detail = 'request_id_required';
  end if;
  v_digest := encode(sha256(convert_to(jsonb_build_object(
    'draft_id', p_draft_id, 'revision', p_revision)::text, 'UTF8')), 'hex');
  v_id := public.financial_receipt_replay_v1(p_workspace_id, v_actor.id, p_request_id,
    'standalone_invoice_issue', v_digest);
  if v_id is not null then
    select number into v_number from public.invoices where id = v_id;
    return jsonb_build_object('invoice_id', v_id, 'number', v_number, 'replayed', true);
  end if;
  perform pg_advisory_xact_lock(hashtext(p_workspace_id::text));
  select * into v_draft from public.standalone_invoice_drafts d
   where d.id = p_draft_id and d.workspace_id = p_workspace_id for update;
  if v_draft.id is null then
    raise exception 'invoice_essentials_missing' using errcode = 'DKI01', detail = 'draft_unknown';
  end if;
  if v_draft.revision <> p_revision then
    raise exception 'invoice_essentials_missing' using errcode = 'DKI01', detail = 'draft_stale';
  end if;
  v_id := public.standalone_invoice_issue_core(p_workspace_id, v_actor, v_draft);
  insert into public.financial_command_receipts
    (workspace_id, actor_member_id, request_id, command_kind, payload_digest, state, invoice_id)
  values (p_workspace_id, v_actor.id, p_request_id, 'standalone_invoice_issue', v_digest, 'applied', v_id);
  select number into v_number from public.invoices where id = v_id;
  return jsonb_build_object('invoice_id', v_id, 'number', v_number, 'replayed', false);
end $fn$;
revoke execute on function public.issue_standalone_invoice_v1(uuid, uuid, integer, uuid) from public, anon;
grant execute on function public.issue_standalone_invoice_v1(uuid, uuid, integer, uuid) to authenticated;

select public.set_deskilo_schema_version(820);
