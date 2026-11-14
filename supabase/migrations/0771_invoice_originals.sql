-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- #3853 -- an issued invoice is its stored original: the PDF, its XML and
-- their digests, kept once per invoice. Every later view, download or
-- reprint serves those bytes.
--
-- 1. invoices.keeps_original: true on every invoice issued from now on, so
--    the invoice itself says whether an original is kept for it. An invoice
--    issued before keeps none and prints as a labelled copy.
-- 2. invoice_originals: one row per invoice, readable by whoever reads the
--    invoice, written only by store_invoice_original and never changed. The
--    system columns record who stored it and when.
-- 3. store_invoice_original: once per invoice, by someone who may issue
--    invoices in the invoice's own business. The bytes live in the table row.
--    Before it keeps them it checks that the PDF is a PDF of at most
--    invoice_original_max_bytes(), and that the XML names, once each, the
--    number, currency and amount due of the invoice row as it was issued.
--    The caller's words are never compared with themselves: every expected
--    value is read from the row. Each stored original leaves a provenance
--    entry with the invoice's number and the digests, never the bytes.

-- ── 1. which invoices keep an original ────────────────────────────────────
-- An added column with a constant default changes no row: the invoices
-- issued before stay as they were and keep no original.
alter table public.invoices add column if not exists keeps_original boolean not null default false;
comment on column public.invoices.keeps_original is
  '#3853 (0771) -- an original of this invoice is kept: true for every invoice issued from 0771 on';

create or replace function public.invoice_keeps_original_stamp()
returns trigger language plpgsql set search_path = public as $fn$
begin
  new.keeps_original := true;
  return new;
end;
$fn$;
revoke execute on function public.invoice_keeps_original_stamp() from public, anon, authenticated;

drop trigger if exists invoice_keeps_original_stamp on public.invoices;
create trigger invoice_keeps_original_stamp
  before insert on public.invoices
  for each row execute function public.invoice_keeps_original_stamp();

-- ── 2. the originals ──────────────────────────────────────────────────────
create table if not exists public.invoice_originals (
  invoice_id uuid primary key references public.invoices(id) on delete cascade,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  pdf bytea not null,
  xml bytea not null,
  sha256 text not null,
  xml_sha256 text not null
);
select public.ensure_system_columns('invoice_originals');
comment on table public.invoice_originals is
  '#3853 -- the stored original of each issued invoice: the PDF and its XML, served by every later view, download or reprint';
comment on column public.invoice_originals.sha256 is 'hex sha256 of pdf';
comment on column public.invoice_originals.xml_sha256 is 'hex sha256 of xml';
create index if not exists invoice_originals_workspace_idx
  on public.invoice_originals (workspace_id);

alter table public.invoice_originals enable row level security;
-- an original is read by whoever reads its invoice
drop policy if exists invoice_originals_select on public.invoice_originals;
create policy invoice_originals_select on public.invoice_originals
  for select using (exists (select 1 from public.invoices i where i.id = invoice_id));
drop policy if exists mcp_delegated_deny on public.invoice_originals;
create policy mcp_delegated_deny on public.invoice_originals as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
revoke insert, update, delete on public.invoice_originals from anon, authenticated;

create or replace function public.invoice_originals_immutable()
returns trigger language plpgsql set search_path = public as $fn$
begin
  raise exception 'an invoice''s original is never changed' using errcode = '42501';
end;
$fn$;
revoke execute on function public.invoice_originals_immutable() from public, anon, authenticated;

drop trigger if exists invoice_originals_no_update on public.invoice_originals;
create trigger invoice_originals_no_update
  before update on public.invoice_originals
  for each row execute function public.invoice_originals_immutable();

-- ── 3. the provenance of an original ──────────────────────────────────────
-- 0693's registry, restated whole with the stored original as a result kind.
create or replace function public.provenance_modules()
returns jsonb language sql immutable set search_path = public as $fn$
  select jsonb_build_object(
    'invoice',             jsonb_build_object('module_id', 'invoice.issue',         'module_version', '1', 'input_schema', 'invoice-legal-snapshot/1'),
    'book_export',         jsonb_build_object('module_id', 'book.export',           'module_version', '1', 'input_schema', 'book-export/1'),
    'file_delivery',       jsonb_build_object('module_id', 'book.file-delivery',    'module_version', '1', 'input_schema', 'file-delivery/1'),
    'accounting_delivery', jsonb_build_object('module_id', 'accounting.delivery',   'module_version', '1', 'input_schema', 'accounting-delivery/1'),
    'transmission',        jsonb_build_object('module_id', 'einvoice.transmission', 'module_version', '1', 'input_schema', 'einvoice-transmission/1'),
    'invoice_original',    jsonb_build_object('module_id', 'invoice.original',      'module_version', '1', 'input_schema', 'invoice-original/1'))
$fn$;
revoke execute on function public.provenance_modules() from public, anon;
grant execute on function public.provenance_modules() to authenticated;

alter table public.provenance_envelopes drop constraint if exists provenance_envelopes_result_kind_check;
alter table public.provenance_envelopes add constraint provenance_envelopes_result_kind_check
  check (result_kind in ('invoice', 'book_export', 'file_delivery', 'accounting_delivery', 'transmission',
                         'invoice_original'));

-- ── 4. storing an original ────────────────────────────────────────────────
-- The largest original kept, PDF and XML together, from the largest picture
-- the report image library accepts (its bucket's own limit, 0215): five
-- pictures' worth. A design with two pictures at that limit, header and
-- footer, makes a PDF of about two and a half (a PNG is embedded re-encoded),
-- so the ceiling is about twice that; the invoice itself adds a few kilobytes.
create or replace function public.invoice_original_max_bytes()
returns bigint language sql stable security definer set search_path = public as $fn$
  select 5 * coalesce((select b.file_size_limit from storage.buckets b where b.id = 'floor-plans'),
                      10485760)::bigint
$fn$;
revoke execute on function public.invoice_original_max_bytes() from public, anon;
grant execute on function public.invoice_original_max_bytes() to authenticated;

-- p_pdf is the PDF in base64; p_xml the CII document it carries.
create or replace function public.store_invoice_original(p_invoice_id uuid, p_pdf text, p_xml text)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_inv public.invoices;
  v_pdf bytea;
  v_doc xml;
  v_ns text[] := array[
    array['rsm', 'urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100'],
    array['ram', 'urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100']];
  v_found xml[];
  v_number text;
  v_currency text;
  v_due text;
  v_due_minor numeric;
  v_sha text;
  v_xml_sha text;
begin
  select * into v_inv from public.invoices where id = p_invoice_id;
  if not found then
    raise exception 'no such invoice' using errcode = 'P0002';
  end if;
  if not public.has_permission(v_inv.workspace_id, 'issueInvoices') then
    raise exception 'not allowed to issue invoices' using errcode = '42501';
  end if;
  if not v_inv.keeps_original then
    raise exception 'this invoice was issued before its original was kept' using errcode = '22023';
  end if;
  if exists (select 1 from public.invoice_originals o where o.invoice_id = p_invoice_id) then
    raise exception 'this invoice already has its original' using errcode = '23505';
  end if;

  begin
    v_pdf := decode(coalesce(p_pdf, ''), 'base64');
  exception when others then
    raise exception 'the original is not a PDF' using errcode = '22023';
  end;
  if length(v_pdf) < 5 or substring(v_pdf from 1 for 5) <> '\x255044462d'::bytea then
    raise exception 'the original is not a PDF' using errcode = '22023';
  end if;
  if length(v_pdf) + octet_length(coalesce(p_xml, '')) > public.invoice_original_max_bytes() then
    raise exception 'the original is larger than % bytes', public.invoice_original_max_bytes()
      using errcode = '22023';
  end if;

  begin
    v_doc := xmlparse(document coalesce(p_xml, ''));
  exception when others then
    raise exception 'the structured part is not an XML document' using errcode = '22023';
  end;
  -- each value from its one place in the document: none, or two, is no value
  v_found := xpath('/rsm:CrossIndustryInvoice/rsm:ExchangedDocument/ram:ID/text()', v_doc, v_ns);
  v_number := case when cardinality(v_found) = 1 then v_found[1]::text end;
  v_found := xpath('/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction'
                   '/ram:ApplicableHeaderTradeSettlement/ram:InvoiceCurrencyCode/text()', v_doc, v_ns);
  v_currency := case when cardinality(v_found) = 1 then v_found[1]::text end;
  v_found := xpath('/rsm:CrossIndustryInvoice/rsm:SupplyChainTradeTransaction'
                   '/ram:ApplicableHeaderTradeSettlement/ram:SpecifiedTradeSettlementHeaderMonetarySummation'
                   '/ram:DuePayableAmount/text()', v_doc, v_ns);
  v_due := case when cardinality(v_found) = 1 then v_found[1]::text end;
  if v_number is distinct from v_inv.number then
    raise exception 'the structured part does not name this invoice''s number' using errcode = '22023';
  end if;
  if v_currency is distinct from v_inv.currency then
    raise exception 'the structured part does not name this invoice''s currency' using errcode = '22023';
  end if;
  begin
    v_due_minor := v_due::numeric * power(10::numeric, public.currency_minor_digits(v_inv.currency));
  exception when others then
    v_due_minor := null;
  end;
  if v_due_minor is distinct from v_inv.total_cents::numeric then
    raise exception 'the structured part does not name this invoice''s amount due' using errcode = '22023';
  end if;

  v_sha := encode(sha256(v_pdf), 'hex');
  v_xml_sha := encode(sha256(convert_to(p_xml, 'UTF8')), 'hex');
  insert into public.invoice_originals (invoice_id, workspace_id, pdf, xml, sha256, xml_sha256)
  values (v_inv.id, v_inv.workspace_id, v_pdf, convert_to(p_xml, 'UTF8'), v_sha, v_xml_sha);
  perform public.record_provenance(v_inv.workspace_id, 'invoice_original', v_inv.id,
    jsonb_build_object('stored_by', auth.uid(), 'number', v_inv.number),
    '{}'::jsonb,
    jsonb_build_object('pdf_sha256', v_sha, 'xml_sha256', v_xml_sha,
                       'pdf_bytes', length(v_pdf), 'xml_bytes', octet_length(p_xml)));
  return jsonb_build_object('invoice_id', v_inv.id, 'sha256', v_sha, 'xml_sha256', v_xml_sha);
end;
$fn$;
revoke execute on function public.store_invoice_original(uuid, text, text) from public, anon;
grant execute on function public.store_invoice_original(uuid, text, text) to authenticated;

select public.set_deskilo_schema_version(771);
