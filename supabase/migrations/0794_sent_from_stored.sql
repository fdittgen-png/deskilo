-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- #4120 -- what is sent to a network is built from what the invoice stored,
-- and what was sent can be read again.
--  * An invoice issued from now on freezes, in its legal snapshot, the
--    business's own account as the invoice prints it and the revision of the
--    tax reference it was issued under. An invoice issued before is never
--    rewritten: it is sent with today's values, and invoice_send_basis says
--    which values are today's so the sheet names them before Send.
--  * invoice_sent_document lets a person who may issue invoices read the
--    document that left, exactly the stored bytes, and only while their hash
--    still matches. invoice_transmission_artifacts itself stays unreadable to
--    every API role.

-- ── 1. the revision of the tax reference a country's invoices read ──────
create or replace function public.tax_reference_revision(p_country text)
returns text language sql stable security definer set search_path = public as $fn$
  select encode(extensions.digest(convert_to(coalesce(string_agg(
           concat_ws('|', r.domain, r.country, r.key, r.valid_from, r.valid_to, r.value::text),
           E'\n' order by r.domain, r.country, r.key, r.valid_from), ''), 'UTF8'), 'sha256'), 'hex')
    from public.tax_reference r
   where r.country in (upper(btrim(coalesce(p_country, ''))), '*')
$fn$;
revoke execute on function public.tax_reference_revision(text) from public, anon, authenticated;

-- ── 2. the snapshot an invoice freezes at issue (restated whole) ────────
create or replace function public.invoice_legal_snapshot(p_workspace_id uuid, p_member_id uuid, p_parties jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $fn$
declare
  v_legal jsonb;
  v_country text;
  v_member_terms jsonb;
  v_member_capacity text;
  v_default_capacity text;
  v_capacity text;
  v_source text;
  v_body jsonb;
  v_vies public.members;
begin
  select coalesce(w.invoice_legal, '{}'::jsonb), w.country_code
    into v_legal, v_country
    from public.workspaces w where w.id = p_workspace_id;
  select m.payment_terms, m.customer_capacity
    into v_member_terms, v_member_capacity
    from public.members m where m.id = p_member_id;
  v_default_capacity := v_legal ->> 'customer_capacity';
  if v_member_capacity in ('business', 'consumer') then
    v_capacity := v_member_capacity; v_source := 'member';
  elsif v_default_capacity in ('business', 'consumer') then
    v_capacity := v_default_capacity; v_source := 'workspace';
  else
    v_capacity := 'unknown'; v_source := 'none';
  end if;
  v_body := jsonb_build_object(
    'schema', 1,
    'seller_kind', coalesce(v_legal ->> 'seller_kind', ''),
    'seller_country', upper(coalesce(nullif(p_parties #>> '{seller,country}', ''),
                                     v_country, '')),
    'buyer_country', upper(coalesce(p_parties #>> '{buyer,country}', '')),
    'buyer_capacity', v_capacity,
    'capacity_source', v_source,
    'terms_source', case when v_member_terms is not null then 'member'
                         else 'workspace' end,
    'clauses', public.payment_terms_clean(v_legal)
               || coalesce(public.payment_terms_clean(v_member_terms), '{}'::jsonb),
    'legal_form', btrim(coalesce(v_legal ->> 'legal_form', '')),
    'registration', btrim(coalesce(v_legal ->> 'registration', '')),
    'insurance', btrim(coalesce(v_legal ->> 'insurance', '')),
    'special_mentions', btrim(coalesce(v_legal ->> 'special_mentions', '')),
    -- #2355: the stored option, or the seller country's legal default
    -- when the workspace never chose (France: services on receipts).
    'vat_exigibility', coalesce(v_legal ->> 'vat_exigibility',
      case when upper(coalesce(nullif(p_parties #>> '{seller,country}', ''),
                               v_country, '')) = 'FR'
           then 'payment' else 'invoice' end),
    -- #4120: the business's own account as the invoice prints it, and the
    -- revision of the tax reference it was issued under, so what is sent to
    -- a network later is built from what the invoice stored.
    'payment', (select coalesce(jsonb_object_agg(k, btrim(w.payment_instructions ->> k))
                                  filter (where btrim(coalesce(w.payment_instructions ->> k, '')) <> ''),
                                '{}'::jsonb)
                  from public.workspaces w,
                       unnest(array['iban', 'bic', 'bank_name', 'account_number', 'bank_code', 'qr_iban']) k
                 where w.id = p_workspace_id),
    'tax_reference_revision', public.tax_reference_revision(
      upper(coalesce(nullif(p_parties #>> '{seller,country}', ''), v_country, ''))));
  -- #2359: the option to tax the building (VAT Notice 742), as chosen
  -- on this invoice's day.
  if v_body ->> 'seller_country' in ('GB', 'CH') then
    v_body := v_body || jsonb_build_object('land_taxation', jsonb_build_object(
      'option_to_tax', coalesce(v_legal ->> 'option_to_tax', '') = 'true',
      'option_to_tax_date', coalesce(v_legal ->> 'option_to_tax_date', ''),
      'option_to_tax_reference', btrim(coalesce(v_legal ->> 'option_to_tax_reference', '')),
      'facilities_package', coalesce(v_legal ->> 'facilities_package', '') = 'true')
      -- #2360: a Swiss seller's letting is bare or a package (art. 21 / 22 MWSTG).
      || case when v_body ->> 'seller_country' = 'CH'
              then jsonb_build_object('bare_letting', coalesce(v_legal ->> 'letting_kind', '') = 'bare')
              else '{}'::jsonb end);
  end if;
  -- #2354: the VIES check of the buyer's number, as evidence of its
  -- business status, when there is one for this very number.
  select * into v_vies from public.members m where m.id = p_member_id;
  if v_vies.vies_status is not null
     and nullif(btrim(p_parties #>> '{buyer,vat_id}'), '') is not null
     and public.vies_vat_parts(v_vies.vies_vat_id, '')
         = public.vies_vat_parts(p_parties #>> '{buyer,vat_id}', '') then
    v_body := v_body || jsonb_build_object('vies', jsonb_build_object(
      'vat_id', v_vies.vies_vat_id,
      'status', v_vies.vies_status,
      'consultation', coalesce(v_vies.vies_consultation, ''),
      'checked_at', v_vies.vies_checked_at));
  end if;
  return v_body || jsonb_build_object('fingerprint',
    encode(extensions.digest(convert_to(v_body::text, 'UTF8'), 'sha256'), 'hex'));
end;
$fn$;

revoke execute on function public.invoice_legal_snapshot(uuid, uuid, jsonb)
  from public, anon, authenticated;

-- ── 3. what of a sending is today's, not the invoice's own ─────────────
create or replace function public.invoice_send_basis(p_invoice_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_ws uuid;
  v_snapshot jsonb;
  v_country text;
begin
  select i.workspace_id, i.legal_snapshot into v_ws, v_snapshot
    from public.invoices i where i.id = p_invoice_id;
  -- The right to issue first: a caller without it and an unknown invoice get
  -- the same answer.
  if v_ws is null or auth.uid() is null
     or not public.has_permission(v_ws, 'issueInvoices') then
    raise exception 'no such invoice to send' using errcode = 'DKN01';
  end if;
  v_country := coalesce(v_snapshot ->> 'seller_country', '');
  return jsonb_build_object(
    'payment', v_snapshot -> 'payment',
    'payment_today', v_snapshot -> 'payment' is null,
    'reference_today', v_snapshot ->> 'tax_reference_revision' is null
      or v_snapshot ->> 'tax_reference_revision' <> public.tax_reference_revision(v_country));
end;
$fn$;
revoke execute on function public.invoice_send_basis(uuid) from public, anon;
grant execute on function public.invoice_send_basis(uuid) to authenticated, service_role;

-- ── 4. the document that left, read again ─────────────────────────────
create or replace function public.invoice_sent_document(p_invoice_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_ws uuid;
  v_artifact public.invoice_transmission_artifacts;
begin
  select i.workspace_id into v_ws from public.invoices i where i.id = p_invoice_id;
  -- The right to issue first, before any artifact is looked up: a caller
  -- without it, an unknown invoice and an invoice never sent get one answer.
  if v_ws is null or auth.uid() is null
     or not public.has_permission(v_ws, 'issueInvoices') then
    raise exception 'no sent document for this invoice' using errcode = 'DKN01';
  end if;
  select a.* into v_artifact
    from public.invoice_transmission_artifacts a
    join public.invoice_transmissions t on t.id = a.transmission_id and t.workspace_id = a.workspace_id
   where t.invoice_id = p_invoice_id and t.workspace_id = v_ws
   order by coalesce(t.sent_at, t.created_datetime) desc, t.id desc
   limit 1;
  if v_artifact.transmission_id is null then
    raise exception 'no sent document for this invoice' using errcode = 'DKN01';
  end if;
  -- Only the bytes that left: a stored file whose hash no longer matches is
  -- said not intact, never handed out.
  if encode(extensions.digest(v_artifact.bytes, 'sha256'), 'hex') <> v_artifact.sha256 then
    raise exception 'the stored sent document is not intact' using errcode = 'DKI09';
  end if;
  return jsonb_build_object(
    'transmission_id', v_artifact.transmission_id,
    'file_name', v_artifact.file_name,
    'mime_type', v_artifact.mime_type,
    'sha256', v_artifact.sha256,
    'bytes', encode(v_artifact.bytes, 'base64'));
end;
$fn$;
revoke execute on function public.invoice_sent_document(uuid) from public, anon;
grant execute on function public.invoice_sent_document(uuid) to authenticated, service_role;

select public.set_deskilo_schema_version(794);
