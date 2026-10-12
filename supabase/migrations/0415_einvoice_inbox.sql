-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0415 (#2358) — the supplier e-invoice inbox: the purchase side of the
-- reception mandates (FR from Sep 2026, DE since 2025, BE from 2026).
--
-- A supplier's UBL or CII invoice reaches the space (uploaded here today;
-- the PA / Peppol address of the space will feed the same door). The Dart
-- parser (domain/inbound_einvoice.dart) reads the syntax; this table keeps
-- the bytes exactly as received, their SHA-256, and the fields the parser
-- read, so an accountant can see what arrived and decide:
--   * match  — it is the invoice of an expense already filed (events,
--              type 'expense'), same workspace, not claimed by another
--              document;
--   * reject — it is not ours / not valid / a duplicate, with a reason.
-- A document is never deleted and its bytes never change; a second copy
-- of the same bytes is refused by the unique hash.
--
-- Everything sits behind einvoiceCustomerDelivery (the e-invoicing flag).
-- Read: viewFinances. Write (ingest, match, reject): approveExpenses.

create table public.einvoice_inbox (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  syntax text not null check (syntax in ('ubl', 'cii')),
  document_hash text not null check (document_hash ~ '^[0-9a-f]{64}$'),
  source_xml text not null check (char_length(source_xml) between 1 and 5000000),
  document_type text not null default '380'
    check (char_length(document_type) between 1 and 10),
  invoice_number text not null check (char_length(invoice_number) between 1 and 200),
  issue_date date not null,
  due_date date,
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  supplier_name text not null check (char_length(supplier_name) between 1 and 300),
  supplier_vat_id text not null default '' check (char_length(supplier_vat_id) <= 40),
  supplier_endpoint text not null default '' check (char_length(supplier_endpoint) <= 300),
  net_cents bigint not null,
  tax_cents bigint not null,
  gross_cents bigint not null,
  status text not null default 'received'
    check (status in ('received', 'matched', 'rejected')),
  matched_event_id uuid references public.events(id),
  reject_reason text not null default '' check (char_length(reject_reason) <= 500),
  decided_by uuid references public.members(id),
  decided_at timestamptz,
  unique (workspace_id, document_hash),
  check ((status = 'matched') = (matched_event_id is not null)),
  check ((status = 'received') = (decided_at is null))
);
select public.ensure_system_columns('einvoice_inbox');
create index einvoice_inbox_workspace
  on public.einvoice_inbox (workspace_id, status, issue_date desc);
create unique index einvoice_inbox_one_per_expense
  on public.einvoice_inbox (matched_event_id) where matched_event_id is not null;

alter table public.einvoice_inbox enable row level security;
revoke all on public.einvoice_inbox from public, anon, authenticated;
grant select on public.einvoice_inbox to authenticated;
create policy einvoice_inbox_select on public.einvoice_inbox
  for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewFinances'])));
create policy mcp_delegated_deny on public.einvoice_inbox as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── ingest ────────────────────────────────────────────────────────────
-- p_parsed carries what the parser read: number, issue_date, due_date,
-- currency, document_type, supplier_name, supplier_vat_id,
-- supplier_endpoint, net_cents, tax_cents, gross_cents. The hash is the
-- server's own, taken over the bytes it stores.
create or replace function public.ingest_einvoice(
  p_workspace_id uuid, p_syntax text, p_xml text, p_parsed jsonb
) returns uuid
language plpgsql security definer set search_path = public as $fn$
declare
  v_member uuid;
  v_hash text;
  v_id uuid;
begin
  if not public.has_permission(p_workspace_id, 'approveExpenses') then
    raise exception 'not allowed to receive supplier invoices';
  end if;
  if not public.feature_effective(p_workspace_id, 'einvoiceCustomerDelivery') then
    raise exception 'e-invoicing is switched off in this space';
  end if;
  if p_parsed is null or jsonb_typeof(p_parsed) <> 'object' then
    raise exception 'the parsed invoice is missing';
  end if;
  select id into v_member from public.members
   where workspace_id = p_workspace_id and user_id = auth.uid() and status = 'active';
  v_hash := encode(sha256(convert_to(p_xml, 'UTF8')), 'hex');
  if exists (select 1 from public.einvoice_inbox
              where workspace_id = p_workspace_id and document_hash = v_hash) then
    raise exception 'this invoice is already in the inbox';
  end if;
  if (p_parsed ->> 'gross_cents')::bigint is distinct from
     (p_parsed ->> 'net_cents')::bigint + (p_parsed ->> 'tax_cents')::bigint then
    raise exception 'net plus tax is not the gross amount';
  end if;
  insert into public.einvoice_inbox
    (workspace_id, syntax, document_hash, source_xml, document_type,
     invoice_number, issue_date, due_date, currency, supplier_name,
     supplier_vat_id, supplier_endpoint, net_cents, tax_cents, gross_cents)
  values
    (p_workspace_id, p_syntax, v_hash, p_xml,
     coalesce(nullif(p_parsed ->> 'document_type', ''), '380'),
     p_parsed ->> 'number', (p_parsed ->> 'issue_date')::date,
     nullif(p_parsed ->> 'due_date', '')::date, p_parsed ->> 'currency',
     p_parsed ->> 'supplier_name',
     coalesce(p_parsed ->> 'supplier_vat_id', ''),
     coalesce(p_parsed ->> 'supplier_endpoint', ''),
     (p_parsed ->> 'net_cents')::bigint, (p_parsed ->> 'tax_cents')::bigint,
     (p_parsed ->> 'gross_cents')::bigint)
  returning id into v_id;
  return v_id;
end;
$fn$;
revoke execute on function public.ingest_einvoice(uuid, text, text, jsonb)
  from public, anon;

-- ── candidates ────────────────────────────────────────────────────────
-- The filed expenses a document may be the invoice of: same space, the
-- same total, not rejected, not claimed by another document.
create or replace function public.einvoice_match_candidates(p_inbox_id uuid)
returns table (event_id uuid, filed_on date, category text, note text,
               amount_cents bigint, status text)
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_doc public.einvoice_inbox;
begin
  select * into v_doc from public.einvoice_inbox where id = p_inbox_id;
  if v_doc.id is null
     or not public.has_permission(v_doc.workspace_id, 'approveExpenses') then
    raise exception 'unknown inbox document';
  end if;
  return query
    select e.id, e.created_at::date, coalesce(e.payload ->> 'category', ''),
           coalesce(e.payload ->> 'note', ''),
           (e.payload ->> 'amount_cents')::bigint, e.status
      from public.events e
     where e.workspace_id = v_doc.workspace_id
       and e.type = 'expense'
       and e.status in ('pending', 'confirmed')
       and (e.payload ->> 'amount_cents')::bigint = v_doc.gross_cents
       and not exists (select 1 from public.einvoice_inbox i
                        where i.matched_event_id = e.id)
     order by e.created_at desc
     limit 50;
end;
$fn$;
revoke execute on function public.einvoice_match_candidates(uuid)
  from public, anon;

-- ── match / reject ────────────────────────────────────────────────────
create or replace function public.match_einvoice(p_inbox_id uuid, p_event_id uuid)
returns void
language plpgsql security definer set search_path = public as $fn$
declare
  v_doc public.einvoice_inbox;
  v_event public.events;
  v_member uuid;
begin
  select * into v_doc from public.einvoice_inbox where id = p_inbox_id for update;
  if v_doc.id is null
     or not public.has_permission(v_doc.workspace_id, 'approveExpenses') then
    raise exception 'unknown inbox document';
  end if;
  if v_doc.status <> 'received' then
    raise exception 'this invoice was already decided';
  end if;
  select * into v_event from public.events where id = p_event_id;
  if v_event.id is null or v_event.workspace_id <> v_doc.workspace_id
     or v_event.type <> 'expense' then
    raise exception 'that is not an expense of this space';
  end if;
  if v_event.status not in ('pending', 'confirmed') then
    raise exception 'that expense was not accepted';
  end if;
  if exists (select 1 from public.einvoice_inbox
              where matched_event_id = p_event_id) then
    raise exception 'that expense already has its invoice';
  end if;
  select id into v_member from public.members
   where workspace_id = v_doc.workspace_id and user_id = auth.uid() and status = 'active';
  update public.einvoice_inbox
     set status = 'matched', matched_event_id = p_event_id,
         decided_by = v_member, decided_at = now()
   where id = p_inbox_id;
end;
$fn$;
revoke execute on function public.match_einvoice(uuid, uuid) from public, anon;

create or replace function public.reject_einvoice(p_inbox_id uuid, p_reason text)
returns void
language plpgsql security definer set search_path = public as $fn$
declare
  v_doc public.einvoice_inbox;
  v_member uuid;
  v_reason text := trim(coalesce(p_reason, ''));
begin
  select * into v_doc from public.einvoice_inbox where id = p_inbox_id for update;
  if v_doc.id is null
     or not public.has_permission(v_doc.workspace_id, 'approveExpenses') then
    raise exception 'unknown inbox document';
  end if;
  if v_doc.status <> 'received' then
    raise exception 'this invoice was already decided';
  end if;
  if char_length(v_reason) not between 1 and 500 then
    raise exception 'a rejection needs a reason of 1-500 characters';
  end if;
  select id into v_member from public.members
   where workspace_id = v_doc.workspace_id and user_id = auth.uid() and status = 'active';
  update public.einvoice_inbox
     set status = 'rejected', reject_reason = v_reason,
         decided_by = v_member, decided_at = now()
   where id = p_inbox_id;
end;
$fn$;
revoke execute on function public.reject_einvoice(uuid, text) from public, anon;

select public.set_deskilo_schema_version(415);
