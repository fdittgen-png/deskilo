-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
-- (the quote line cleaner, both draft saves and the standalone line restated whole from their live definitions, their uuid reads without a catch-all; one new
--  function; no table, no stored value moves)
--
-- #4510 (FIN-05, #4500 package 4) -- a line of a quote or of a standalone invoice may name the catalogue service it was
-- picked from: `service_id`.
--   * The quote line cleaner keeps it (a uuid, never on a goods line), so the accepted quote's lines carry it into the
--     invoice draft of the conversion and into the issued invoice, which compares them as they are.
--   * Saving a quote draft or a standalone draft checks it (`catalogue_service_lines_missing`): a service of this business
--     that is not kept in stock, and active -- unless the same line (its `line_id`) already held it in what was saved
--     before: a service retired after the line was written stays on that line, and is refused for a new one. A line
--     fails as its missing fact `line_<n>_service` (DKQ06 for a quote, DKI01 for an invoice draft).
--   * The standalone line keeps it in its frozen `commercial` object, so an issued invoice names the service the line
--     was agreed from. The price, the VAT rate, the supply and the description of a line stay as the line was saved:
--     the catalogue is read to fill the line in, never to compute it, so a later edit of a service changes no saved quote,
--     draft or invoice.
-- Every function keeps its signature and its ACL (create or replace).

-- restates 0828 (customer_quote_line_clean; 0942 patched it at anchors, the text below carries them)
CREATE OR REPLACE FUNCTION public.customer_quote_line_clean(p_line jsonb, p_index integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
declare
  v_missing text[] := '{}';
  v_pre text := 'line_' || p_index || '_';
  v_dec constant text := '^[0-9]{1,12}(\.[0-9]{1,6})?$';
  v_desc text := btrim(coalesce(p_line ->> 'description', ''));
  v_qty text := btrim(coalesce(p_line ->> 'quantity', ''));
  v_price text := btrim(coalesce(p_line ->> 'unit_price', ''));
  v_base text := btrim(coalesce(nullif(p_line ->> 'base_quantity', ''), '1'));
  v_basis text := coalesce(nullif(p_line ->> 'basis', ''), 'net');
  v_supply text := coalesce(p_line ->> 'supply', '');
  v_unit jsonb := coalesce(p_line -> 'unit', '{}'::jsonb);
  v_line_id uuid;
  v_rate uuid;
  v_service uuid;
begin
  if p_line is null or jsonb_typeof(p_line) <> 'object' then
    return jsonb_build_object('line', null, 'missing', to_jsonb(array[v_pre || 'shape']));
  end if;
  if v_desc = '' or char_length(v_desc) > 300 then v_missing := v_missing || (v_pre || 'description'); end if;
  if v_qty !~ v_dec or v_qty::numeric <= 0 then v_missing := v_missing || (v_pre || 'quantity'); end if;
  if v_price !~ v_dec then v_missing := v_missing || (v_pre || 'unit_price'); end if;
  if v_base !~ v_dec or v_base::numeric <= 0 then v_missing := v_missing || (v_pre || 'base_quantity'); end if;
  if v_basis not in ('net', 'gross') then v_missing := v_missing || (v_pre || 'basis'); end if;
  if v_supply not in ('general', 'property', 'goods') then v_missing := v_missing || (v_pre || 'supply'); end if;
  -- #4433: a goods line names its stock item (and its variant); what is on hand is read when it is invoiced
  if v_supply = 'goods' and coalesce(p_line ->> 'item_id', '') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then
    v_missing := v_missing || (v_pre || 'item');
  end if;
  if v_supply = 'goods' and nullif(p_line ->> 'variant_id', '') is not null
     and (p_line ->> 'variant_id') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then
    v_missing := v_missing || (v_pre || 'variant');
  end if;
  if btrim(coalesce(v_unit ->> 'code', '')) = '' or char_length(v_unit ->> 'code') > 20
     or btrim(coalesce(v_unit ->> 'label', '')) = '' or char_length(v_unit ->> 'label') > 20
     or (coalesce(v_unit ->> 'un_ece_code', '') <> '' and (v_unit ->> 'un_ece_code') !~ '^[A-Z0-9]{2,3}$') then
    v_missing := v_missing || (v_pre || 'unit');
  end if;
  if p_line ->> 'line_id' is null then v_line_id := gen_random_uuid();
  elsif (p_line ->> 'line_id') ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then v_line_id := (p_line ->> 'line_id')::uuid;
  else v_line_id := null; v_missing := v_missing || (v_pre || 'line_id'); end if;
  if nullif(p_line ->> 'vat_rate_id', '') is null then v_rate := null;
  elsif (p_line ->> 'vat_rate_id') ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then v_rate := (p_line ->> 'vat_rate_id')::uuid;
  else v_missing := v_missing || (v_pre || 'vat_rate'); end if;
  -- #4510: a line may name the catalogue service it was picked from (its own, never goods); the business's catalogue is read when the draft is saved
  if nullif(p_line ->> 'service_id', '') is null then v_service := null;
  elsif (p_line ->> 'service_id') ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then v_service := (p_line ->> 'service_id')::uuid;
  else v_missing := v_missing || (v_pre || 'service'); end if;
  if v_service is not null and v_supply = 'goods' then v_missing := v_missing || (v_pre || 'service'); end if;
  if cardinality(v_missing) > 0 then
    return jsonb_build_object('line', null, 'missing', to_jsonb(v_missing));
  end if;
  return jsonb_build_object('missing', '[]'::jsonb, 'line', jsonb_strip_nulls(jsonb_build_object(
    'line_id', v_line_id, 'description', v_desc, 'quantity', trim_scale(v_qty::numeric)::text,
    'unit_price', trim_scale(v_price::numeric)::text, 'base_quantity', trim_scale(v_base::numeric)::text,
    'basis', v_basis, 'supply', v_supply,
    'unit', jsonb_build_object('code', btrim(v_unit ->> 'code'), 'label', btrim(v_unit ->> 'label'),
                               'un_ece_code', coalesce(v_unit ->> 'un_ece_code', '')),
    'vat_rate_id', v_rate,
    'service_id', v_service,
    'item_id', case when v_supply = 'goods' then p_line ->> 'item_id' end,
    'variant_id', case when v_supply = 'goods' then nullif(p_line ->> 'variant_id', '') end)));
end
$function$;

-- restates 0844 (save_customer_quote_draft_v1)
CREATE OR REPLACE FUNCTION public.save_customer_quote_draft_v1(p_workspace_id uuid, p_quote_id uuid, p_expected_version integer, p_subject uuid, p_issued_on date, p_valid_until date, p_buyer_reference text, p_purchase_order text, p_notes text, p_lines jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor public.members;
  v_q public.customer_quotes;
  v_rev public.customer_quote_revisions;
  v_lines jsonb;
  v_on date;
  v_until date;
  v_default integer;
  v_max integer;
  v_chk text[];
begin
  v_actor := public.customer_quote_actor(p_workspace_id);
  perform public.standalone_invoice_subject(p_workspace_id, p_subject);
  v_lines := public.customer_quote_lines_clean(p_lines);
  v_on := coalesce(p_issued_on, public.workspace_today(p_workspace_id));
  -- the business's own validity: the registry's default is the fallback
  v_max := (public.setting_value(p_workspace_id, 'quotes.max_validity_days') #>> '{}')::int;
  v_default := least((public.setting_value(p_workspace_id, 'quotes.default_validity_days') #>> '{}')::int, v_max);
  v_until := coalesce(p_valid_until, v_on + v_default);
  if v_until < v_on or v_until > v_on + v_max then
    raise exception 'the validity is out of range' using errcode = 'DKQ06', detail = 'valid_until';
  end if;
  if p_quote_id is null then
    v_chk := public.catalogue_service_lines_missing(p_workspace_id, v_lines, '[]'::jsonb);
    if cardinality(v_chk) > 0 then
      raise exception 'the quote is not complete' using errcode = 'DKQ06', detail = array_to_string(v_chk, ',');
    end if;
    insert into public.customer_quotes (workspace_id, subject_member_id)
    values (p_workspace_id, p_subject) returning * into v_q;
    insert into public.customer_quote_revisions
      (quote_id, workspace_id, revision, issued_on, valid_until, buyer_reference, purchase_order, notes, lines)
    values (v_q.id, p_workspace_id, 1, v_on, v_until, coalesce(btrim(p_buyer_reference), ''),
            coalesce(btrim(p_purchase_order), ''), coalesce(btrim(p_notes), ''), v_lines)
    returning * into v_rev;
    -- the series exists before the first number, so the owner may set it first
    insert into public.number_sequences (workspace_id, journal, prefix, date_part, reset)
    select p_workspace_id, 'quote', d.prefix, d.date_part, d.reset
      from public.number_sequence_defaults('quote') d
    on conflict (workspace_id, journal) do nothing;
  else
    select * into v_q from public.customer_quotes
     where id = p_quote_id and workspace_id = p_workspace_id for update;
    if v_q.id is null then raise exception 'unknown quote' using errcode = 'DKQ01'; end if;
    if v_q.subject_member_id is distinct from p_subject then
      raise exception 'a quote keeps its customer' using errcode = 'DKQ03';
    end if;
    select * into v_rev from public.customer_quote_revisions r
     where r.quote_id = v_q.id and r.status = 'draft' order by r.revision desc limit 1 for update;
    if v_rev.id is null then
      raise exception 'no draft revision: amend the quote first' using errcode = 'DKQ03';
    end if;
    if v_rev.draft_version is distinct from p_expected_version then
      raise exception 'the draft changed since it was read' using errcode = 'DKQ02';
    end if;
    v_chk := public.catalogue_service_lines_missing(p_workspace_id, v_lines, v_rev.lines);
    if cardinality(v_chk) > 0 then
      raise exception 'the quote is not complete' using errcode = 'DKQ06', detail = array_to_string(v_chk, ',');
    end if;
    update public.customer_quote_revisions set
      issued_on = v_on, valid_until = v_until,
      buyer_reference = coalesce(btrim(p_buyer_reference), ''),
      purchase_order = coalesce(btrim(p_purchase_order), ''),
      notes = coalesce(btrim(p_notes), ''), lines = v_lines,
      draft_version = draft_version + 1
     where id = v_rev.id returning * into v_rev;
  end if;
  return jsonb_build_object('quote_id', v_q.id, 'revision', v_rev.revision, 'version', v_rev.draft_version);
end
$function$;

-- restates 0820 (save_standalone_invoice_draft_v1)
CREATE OR REPLACE FUNCTION public.save_standalone_invoice_draft_v1(p_workspace_id uuid, p_draft_id uuid, p_expected_revision integer, p_subject uuid, p_service_date date, p_due_on date, p_buyer_reference text, p_purchase_order text, p_lines jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_actor public.members;
  v_draft public.standalone_invoice_drafts;
  v_lines jsonb;
  v_chk text[];
begin
  v_actor := public.issuing_member(p_workspace_id);

  if not public.feature_effective(p_workspace_id, 'standaloneInvoicing') then
    raise exception 'invoice_essentials_missing'
      using errcode = 'DKI01', detail = 'invoice_feature_disabled';
  end if;
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
    v_chk := public.catalogue_service_lines_missing(p_workspace_id, v_lines, '[]'::jsonb);
    if cardinality(v_chk) > 0 then
      raise exception 'invoice_essentials_missing' using errcode = 'DKI01', detail = array_to_string(v_chk, ',');
    end if;
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
    if v_draft.revision is distinct from p_expected_revision then
      raise exception 'invoice_essentials_missing' using errcode = 'DKI01', detail = 'draft_stale';
    end if;
    v_chk := public.catalogue_service_lines_missing(p_workspace_id, v_lines, v_draft.lines);
    if cardinality(v_chk) > 0 then
      raise exception 'invoice_essentials_missing' using errcode = 'DKI01', detail = array_to_string(v_chk, ',');
    end if;
    update public.standalone_invoice_drafts
       set subject_member_id = p_subject, service_date = p_service_date, due_on = p_due_on,
           buyer_reference = coalesce(p_buyer_reference, ''), purchase_order = coalesce(p_purchase_order, ''),
           lines = v_lines, revision = revision + 1
     where id = v_draft.id returning * into v_draft;
  end if;
  return jsonb_build_object('draft_id', v_draft.id, 'revision', v_draft.revision, 'lines', v_draft.lines);
end $function$;

-- restates 0820 (standalone_invoice_line_v1)
CREATE OR REPLACE FUNCTION public.standalone_invoice_line_v1(p_line jsonb, p_index integer, p_currency text, p_percent numeric, p_category text, p_tax_point date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public'
AS $function$
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
  v_exp integer := public.currency_minor_digits(p_currency);
  v_raw numeric; v_amount bigint; v_net bigint; v_tax bigint; v_gross bigint; v_t bigint;
  v_pct numeric := coalesce(p_percent, 0);
  v_line_id uuid;
  v_dec constant text := '^[0-9]{1,12}(\.[0-9]{1,6})?$';
  v_ret jsonb;
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
  v_line_id := case when (p_line ->> 'line_id') ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then (p_line ->> 'line_id')::uuid end;
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
  v_ret := jsonb_build_object('missing', '[]'::jsonb, 'line', jsonb_build_object(
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
  -- #4510: the line keeps the identity of the catalogue service it was picked from, with what was agreed
  if nullif(p_line ->> 'service_id', '') is not null then
    v_ret := jsonb_set(v_ret, '{line,commercial,service_id}', to_jsonb(p_line ->> 'service_id'));
  end if;
  return v_ret;
end $function$;

-- ── the catalogue check of a saved line ─────────────────────────────────
-- The missing facts (`line_<n>_service`) of the lines of [p_new] that name a service: it must be a service of the business, not
-- one kept in stock (that is goods), and active -- unless the line (by its line_id) held it already in [p_old].
create or replace function public.catalogue_service_lines_missing(p_workspace_id uuid, p_new jsonb, p_old jsonb)
returns text[] language plpgsql stable security definer set search_path = public as $fn$
declare
  v_out text[] := '{}';
  v_idx integer := 0;
  e jsonb;
  v_id uuid;
  v_svc public.services;
begin
  for e in select x from jsonb_array_elements(coalesce(p_new, '[]'::jsonb)) x loop
    v_idx := v_idx + 1;
    if jsonb_typeof(e) <> 'object' or nullif(e ->> 'service_id', '') is null then continue; end if;
    if (e ->> 'service_id') !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$' then
      v_out := v_out || ('line_' || v_idx || '_service');
      continue;
    end if;
    v_id := (e ->> 'service_id')::uuid;
    select * into v_svc from public.services s where s.id = v_id and s.workspace_id = p_workspace_id;
    if v_svc.id is null or coalesce(v_svc.stockable, false) or coalesce(e ->> 'supply', '') = 'goods' then
      v_out := v_out || ('line_' || v_idx || '_service');
    elsif not v_svc.active and not exists (
        select 1 from jsonb_array_elements(coalesce(p_old, '[]'::jsonb)) o
         where jsonb_typeof(o) = 'object' and o ->> 'line_id' = e ->> 'line_id' and o ->> 'service_id' = e ->> 'service_id') then
      v_out := v_out || ('line_' || v_idx || '_service');
    end if;
  end loop;
  return v_out;
end
$fn$;
revoke execute on function public.catalogue_service_lines_missing(uuid, jsonb, jsonb) from public, anon, authenticated;

-- the four restated functions keep the grants they have (create or replace keeps them); stated here so the file says who may call them
revoke execute on function public.customer_quote_line_clean(jsonb, integer) from public, anon, authenticated;
revoke execute on function public.standalone_invoice_line_v1(jsonb, integer, text, numeric, text, date) from public, anon, authenticated;
revoke execute on function public.save_customer_quote_draft_v1(uuid, uuid, integer, uuid, date, date, text, text, text, jsonb) from public, anon;
revoke execute on function public.save_standalone_invoice_draft_v1(uuid, uuid, integer, uuid, date, date, text, text, jsonb) from public, anon;

select public.set_deskilo_schema_version(996);
