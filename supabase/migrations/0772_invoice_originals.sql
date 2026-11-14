-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (one private storage bucket with an insert and a select policy, no update
-- and no delete; one column on invoices with its stamp; one table; the
-- provenance registry restated whole with one kind more)
--
-- #3853 -- an issued invoice is its stored original: its PDF, its XML and
-- their digests, kept once per invoice. Every later view, download or
-- reprint serves those bytes.
--
-- 1. invoices.keeps_original: true on every invoice issued from now on, so
--    the invoice itself says whether an original is kept for it. An invoice
--    issued before keeps none and prints as a labelled copy.
-- 2. The PDF is an object of the private bucket invoice-originals, at
--    <workspace_id>/<invoice_id>/<sha256 of the PDF>.pdf, at most the
--    bucket's own file_size_limit (5 MiB). It is written once, by someone who
--    may issue invoices in that business, for an invoice that keeps an
--    original and has none recorded yet. No API role updates or deletes an
--    object: it leaves with its invoice, by the server's roles. An upload
--    that no recorded original names is left as it is; the server's own
--    maintenance removes those.
-- 3. invoice_originals: one small row per invoice -- the object's path, the
--    PDF's size read from the stored object, the PDF's SHA-256 as declared
--    by whoever stored it, the XML itself and its SHA-256 computed here. The
--    system columns record who stored it and when. Readable by whoever reads
--    the invoice; never changed.
-- 4. store_invoice_original(invoice, pdf_sha256, xml): after the upload,
--    once per invoice, by someone who may issue invoices in the invoice's
--    own business. It requires the object at the path the declared digest
--    names, and checks that the XML names, once each, the number, currency
--    and amount due of the invoice row as it was issued; every expected value
--    is read from the row. A refusal records nothing. Each stored original
--    leaves a provenance entry with the invoice's number and the digests,
--    never the bytes.
-- The PDF's digest is recorded as declared and checked by whoever reads the
-- original against the bytes they download; how its page looks is checked
-- by nobody.

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
-- The largest XML kept: about thirty times the Demo business's largest
-- invoice (11 lines, 15 725 bytes).
create or replace function public.invoice_original_xml_max_bytes()
returns integer language sql immutable set search_path = public as $fn$
  select 512 * 1024
$fn$;
revoke execute on function public.invoice_original_xml_max_bytes() from public, anon;
grant execute on function public.invoice_original_xml_max_bytes() to authenticated;

create table if not exists public.invoice_originals (
  invoice_id uuid primary key references public.invoices(id) on delete cascade,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  path text not null unique,
  pdf_bytes bigint not null check (pdf_bytes > 0),
  pdf_sha256 text not null check (pdf_sha256 ~ '^[0-9a-f]{64}$'),
  xml text not null,
  xml_sha256 text not null
);
select public.ensure_system_columns('invoice_originals');
comment on table public.invoice_originals is
  '#3853 -- the stored original of each issued invoice: its PDF in the invoice-originals bucket, its XML here; served by every later view, download or reprint';
comment on column public.invoice_originals.path is 'the PDF''s object in the invoice-originals bucket';
comment on column public.invoice_originals.pdf_bytes is 'the size of the stored object, read by the server';
comment on column public.invoice_originals.pdf_sha256 is 'hex sha256 of the PDF as declared by whoever stored it; checked at every read';
comment on column public.invoice_originals.xml_sha256 is 'hex sha256 of xml, computed by the server';
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

-- ── 3. the bucket ─────────────────────────────────────────────────────────
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('invoice-originals', 'invoice-originals', false, 5242880, array['application/pdf'])
on conflict (id) do nothing;

-- The invoice an object path names, or null for any other shape.
create or replace function public.invoice_original_invoice(p_name text)
returns uuid language sql immutable set search_path = public as $fn$
  select case when p_name ~ ('^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
                             '/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
                             '/[0-9a-f]{64}\.pdf$')
              then split_part(p_name, '/', 2)::uuid end;
$fn$;
revoke execute on function public.invoice_original_invoice(text) from public, anon;
grant execute on function public.invoice_original_invoice(text) to authenticated;

-- Whether the caller may upload [p_name]: its folder is the business of the
-- invoice it names, that invoice keeps an original and has none recorded,
-- and the caller may issue invoices there; never an assistant's token.
create or replace function public.invoice_original_may_upload(p_name text)
returns boolean language sql stable security definer set search_path = public as $fn$
  select auth.uid() is not null
     and not public.mcp_is_delegated()
     and exists (select 1 from public.invoices i
                  where i.id = public.invoice_original_invoice(p_name)
                    and i.workspace_id::text = split_part(p_name, '/', 1)
                    and i.keeps_original
                    and public.has_permission(i.workspace_id, 'issueInvoices'))
     and not exists (select 1 from public.invoice_originals o
                      where o.invoice_id = public.invoice_original_invoice(p_name));
$fn$;
revoke execute on function public.invoice_original_may_upload(text) from public, anon;
grant execute on function public.invoice_original_may_upload(text) to authenticated;

drop policy if exists invoice_originals_insert on storage.objects;
create policy invoice_originals_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'invoice-originals' and public.invoice_original_may_upload(name));

-- Whether the caller may issue invoices in the business whose folder holds
-- [p_name]: who uploads there sees what was uploaded there.
-- The folder is read only once the name has the shape of an original's, so a
-- malformed name answers false and never raises.
create or replace function public.invoice_original_issuer(p_name text)
returns boolean language sql stable security definer set search_path = public as $fn$
  select case when public.invoice_original_invoice(p_name) is not null
              then coalesce(public.has_permission(((storage.foldername(p_name))[1])::uuid, 'issueInvoices'), false)
              else false end;
$fn$;
revoke execute on function public.invoice_original_issuer(text) from public, anon;
grant execute on function public.invoice_original_issuer(text) to authenticated;

-- An object is read when a recorded original of the business its folder
-- names records it, by whoever reads that original (and so its invoice), and
-- by who may issue invoices in the business its folder names, who uploads it.
drop policy if exists invoice_originals_select on storage.objects;
create policy invoice_originals_select on storage.objects for select to authenticated
  using (bucket_id = 'invoice-originals'
         and not public.mcp_is_delegated()
         and (exists (select 1 from public.invoice_originals o
                       where o.path = name and o.workspace_id::text = (storage.foldername(name))[1])
              or public.invoice_original_issuer(name)));

-- ── 4. the provenance of an original ──────────────────────────────────────
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

-- ── 5. recording an original ──────────────────────────────────────────────
create or replace function public.store_invoice_original(p_invoice_id uuid, p_pdf_sha256 text, p_xml text)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_inv public.invoices;
  v_path text;
  v_bytes bigint;
  v_doc xml;
  v_ns text[] := array[
    array['rsm', 'urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100'],
    array['ram', 'urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100']];
  v_found xml[];
  v_number text;
  v_currency text;
  v_due text;
  v_due_minor numeric;
  v_xml_sha text;
begin
  -- an invoice the caller may not issue in, and one that does not exist,
  -- answer alike
  select * into v_inv from public.invoices where id = p_invoice_id;
  if v_inv.id is null or public.mcp_is_delegated()
     or not coalesce(public.has_permission(v_inv.workspace_id, 'issueInvoices'), false) then
    raise exception 'not allowed to issue invoices' using errcode = '42501';
  end if;
  if not v_inv.keeps_original then
    raise exception 'this invoice was issued before its original was kept' using errcode = '22023';
  end if;
  if exists (select 1 from public.invoice_originals o where o.invoice_id = p_invoice_id) then
    raise exception 'this invoice already has its original' using errcode = '23505';
  end if;

  -- the PDF: at the path its declared digest names, already stored
  if coalesce(p_pdf_sha256, '') !~ '^[0-9a-f]{64}$' then
    raise exception 'the PDF''s digest is not a SHA-256' using errcode = '22023';
  end if;
  v_path := v_inv.workspace_id || '/' || v_inv.id || '/' || p_pdf_sha256 || '.pdf';
  select (o.metadata ->> 'size')::bigint into v_bytes
    from storage.objects o where o.bucket_id = 'invoice-originals' and o.name = v_path;
  if v_bytes is null then
    raise exception 'the original''s PDF is not stored' using errcode = '22023';
  end if;

  -- the XML: its size first, before it is parsed; then each value from its
  -- one place in the document -- none, or two, is no value
  if octet_length(coalesce(p_xml, '')) > public.invoice_original_xml_max_bytes() then
    raise exception 'the structured part is larger than % bytes', public.invoice_original_xml_max_bytes()
      using errcode = '22023';
  end if;
  begin
    v_doc := xmlparse(document coalesce(p_xml, ''));
  exception when others then
    raise exception 'the structured part is not an XML document' using errcode = '22023';
  end;
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

  v_xml_sha := encode(sha256(convert_to(p_xml, 'UTF8')), 'hex');
  insert into public.invoice_originals (invoice_id, workspace_id, path, pdf_bytes, pdf_sha256, xml, xml_sha256)
  values (v_inv.id, v_inv.workspace_id, v_path, v_bytes, p_pdf_sha256, p_xml, v_xml_sha);
  perform public.record_provenance(v_inv.workspace_id, 'invoice_original', v_inv.id,
    jsonb_build_object('stored_by', auth.uid(), 'number', v_inv.number),
    '{}'::jsonb,
    jsonb_build_object('path', v_path, 'pdf_sha256', p_pdf_sha256, 'pdf_bytes', v_bytes,
                       'xml_sha256', v_xml_sha, 'xml_bytes', octet_length(p_xml)));
  return jsonb_build_object('invoice_id', v_inv.id, 'path', v_path, 'pdf_bytes', v_bytes,
                            'pdf_sha256', p_pdf_sha256, 'xml_sha256', v_xml_sha);
end;
$fn$;
revoke execute on function public.store_invoice_original(uuid, text, text) from public, anon;
grant execute on function public.store_invoice_original(uuid, text, text) to authenticated;

select public.set_deskilo_schema_version(771);
