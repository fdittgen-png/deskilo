-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (two functions created; invoice_essentials_missing patched at two asserted
-- anchors)
--
-- #4105 -- what the country's own invoice rules require of an address is
-- refused before the invoice is issued, not found after. Each country's postal
-- layout carries two facts about its region (the address form asks for it;
-- the invoice requires it), and postal_region_rules() is the server's copy of
-- them, generated from the app (tool/build_postal_region_rules_sql.dart, bound
-- by test/lint/postal_region_rules_sql_test.dart). A party in the seller's own
-- country whose country's invoices require the region and that has none is
-- refused: `seller_region`, `buyer_region`. A buyer abroad is never refused
-- for its own country's rules.

-- ── 1. the region facts of each country (generated) ─────────────────────
create or replace function public.postal_region_rules()
returns jsonb language sql immutable set search_path = public as $fn$
  select '{"CA":{"form":true,"invoice":"seller"},"CH":{"form":false,"invoice":"none"},"ES":{"form":false,"invoice":"none"},"IE":{"form":false,"invoice":"none"},"IT":{"form":true,"invoice":"everyParty"},"RO":{"form":true,"invoice":"everyParty"},"US":{"form":true,"invoice":"seller"}}'::jsonb
$fn$;
revoke execute on function public.postal_region_rules() from public, anon, authenticated;

-- ── 2. the region a party lacks, for the seller's own country ───────────
create or replace function public.invoice_region_missing(
  p_seller jsonb, p_buyer jsonb, p_seller_country text)
returns text[] language sql stable set search_path = public as $fn$
  select array_remove(array[
    case when coalesce(public.postal_region_rules()
                         -> upper(btrim(coalesce(p_seller_country, ''))) ->> 'invoice', 'none')
                in ('seller', 'everyParty')
              and btrim(coalesce(p_seller ->> 'subdivision', '')) = ''
         then 'seller_region' end,
    case when coalesce(public.postal_region_rules()
                         -> upper(btrim(coalesce(p_seller_country, ''))) ->> 'invoice', 'none')
                = 'everyParty'
              and upper(btrim(coalesce(nullif(p_buyer ->> 'country', ''), p_seller_country, '')))
                  = upper(btrim(coalesce(p_seller_country, '')))
              and btrim(coalesce(p_buyer ->> 'subdivision', '')) = ''
         then 'buyer_region' end], null)
$fn$;
revoke execute on function public.invoice_region_missing(jsonb, jsonb, text)
  from public, anon, authenticated;

-- ── 3. the issue check asks it, in both of its branches ─────────────────
do $migration$
declare
  v_fn text;
  v_old text;
  v_new text;
  v_def text;
begin
  for v_fn, v_old, v_new in select * from (values
    -- a seller under sales tax (a US or Canadian state or province)
    ('public.invoice_essentials_missing(uuid,uuid,jsonb,jsonb)',
     $r$    return v_missing;
  end if;
$r$,
     $r$    -- #4105 -- the region the seller's country requires on the invoice
    v_missing := v_missing || public.invoice_region_missing(v_seller, v_buyer, v_country);
    return v_missing;
  end if;
$r$),
    -- a seller under VAT (an Italian province, a Romanian county)
    ('public.invoice_essentials_missing(uuid,uuid,jsonb,jsonb)',
     $r$    v_missing := array_append(v_missing, 'buyer_tax_id'::text);
  end if;
$r$,
     $r$    v_missing := array_append(v_missing, 'buyer_tax_id'::text);
  end if;
  -- #4105 -- the region the seller's country requires on the invoice
  v_missing := v_missing || public.invoice_region_missing(v_seller, v_buyer, v_country);
$r$)) v(f, o, n)
  loop
    v_def := pg_get_functiondef(v_fn::regprocedure);
    if position(v_new in v_def) > 0 then continue; end if;
    if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
      raise exception '% no longer has the shape 0792 extends: %', v_fn, left(v_old, 60) using errcode = 'P0001';
    end if;
    execute replace(v_def, v_old, v_new);
  end loop;
end
$migration$;

-- ── 4. the draft an issue would store, asked before issuing ─────────────
-- invoice_issue_readiness (0416) dry-runs create_invoice and answers what is
-- missing. This dry run answers the same, and when nothing is missing, the
-- parties the invoice would store: the app judges what the configured channel
-- will need on exactly those, before the number is taken, with the function
-- it uses before sending (#4105, one source).
create or replace function public.invoice_issue_draft(
  p_workspace_id uuid, p_member_id uuid, p_period text,
  p_kind text default 'full', p_replaces uuid default null,
  p_correction_reason text default ''
) returns jsonb
language plpgsql security definer set search_path = public as $fn$
declare
  v_detail text;
  v_id uuid;
  v_parties jsonb;
begin
  if auth.uid() is null
     or not public.has_permission(p_workspace_id, 'issueInvoices') then
    raise exception 'admins may not issue invoices here' using errcode = 'DKN01';
  end if;
  begin
    v_id := public.create_invoice(
      p_workspace_id, p_member_id, p_period, p_replaces, false, p_kind, true,
      '', '', p_correction_reason);
    select i.parties into v_parties from public.invoices i where i.id = v_id;
    -- Issued inside this block: undo it, carrying the parties out.
    raise exception using message = 'dry run', errcode = 'DKI02',
      detail = coalesce(v_parties, '{}'::jsonb)::text;
  exception
    when sqlstate 'DKI01' then
      get stacked diagnostics v_detail = pg_exception_detail;
      return jsonb_build_object('missing', to_jsonb(string_to_array(v_detail, ',')),
                                'parties', null);
    when sqlstate 'DKI02' then
      get stacked diagnostics v_detail = pg_exception_detail;
      return jsonb_build_object('missing', '[]'::jsonb, 'parties', v_detail::jsonb);
  end;
end;
$fn$;
revoke execute on function public.invoice_issue_draft(uuid, uuid, text, text, uuid, text)
  from public, anon;
grant execute on function public.invoice_issue_draft(uuid, uuid, text, text, uuid, text)
  to authenticated, service_role;

-- ── 5. a business without its own region is told before it issues ──────
-- The readiness of a space (and with it the setup's legal identity step)
-- counts the region the country's invoices require of the seller: the same
-- rule, the same key, before the first issue asks for it.
create or replace function public.workspace_lacks_region(p_workspace_id uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select coalesce('seller_region' = any(public.invoice_region_missing(
           jsonb_build_object('subdivision', coalesce(w.invoice_legal ->> 'subdivision', '')),
           '{"country": "-"}'::jsonb, w.country_code)), false)
    from public.workspaces w where w.id = p_workspace_id
$fn$;
revoke execute on function public.workspace_lacks_region(uuid) from public, anon, authenticated;

do $migration$
declare
  v_def text := pg_get_functiondef('public.workspace_readiness(uuid)'::regprocedure);
  v_old text := $r$         'state', case when v_identity then 'ready' else 'needs_configuration' end,
         'reason', case when not v_identity then 'invoicing_needs_identity' end))
$r$;
  v_new text := $r$         'state', case when v_identity and not public.workspace_lacks_region(p_workspace_id)
                       then 'ready' else 'needs_configuration' end,
         'reason', case when not v_identity then 'invoicing_needs_identity'
                        when public.workspace_lacks_region(p_workspace_id) then 'seller_region' end))
$r$;
begin
  if position(v_new in v_def) > 0 then return; end if;
  if (length(v_def) - length(replace(v_def, v_old, ''))) / length(v_old) <> 1 then
    raise exception 'workspace_readiness no longer has the shape 0792 extends' using errcode = 'P0001';
  end if;
  execute replace(v_def, v_old, v_new);
end
$migration$;

select public.set_deskilo_schema_version(792);
