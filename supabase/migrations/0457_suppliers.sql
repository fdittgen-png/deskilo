-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0457 (#2567, C1a of #2464) -- ONE `suppliers` entity: the payee that the
-- lease, the supplier-invoice inbox, the scheduled expenses and a rented
-- room all point at. Master data of the expense flows, so it sits behind
-- `supplyExpenses` (no new flag).
--
--   * `suppliers`  workspace-scoped; `supplier_number` is unique per
--     workspace, set by the owner or the next free number of the workspace
--     (the consumers #2370/#2375/#2376/#2380 validate it against their own
--     rule -- no accounting range is hard-coded here).
--   * Identity. A supplier is merged on a VERIFIED, jurisdiction-qualified
--     tax identifier and on nothing else: a name alone, or an empty VAT
--     value, is never a merge key. "Verified" means the identifier carries
--     its jurisdiction prefix and its body matches the pattern of that
--     jurisdiction in the in-force tax reference store (`vat_id_pattern`,
--     0427). The only normalisation is upper-casing and dropping the
--     presentation separators (space, dot, hyphen). A VAT-group identifier
--     (`tax_id_kind = 'vat_group'`) never merges: it names several legal
--     parties. Everything else -- no identifier, an identifier that does not
--     verify (several in one field, wrong format, unknown jurisdiction), a
--     group identifier -- becomes a `supplier_review_candidates` row and the
--     source record stays as it is until a person resolves it.
--   * Bank details have a revision history (`supplier_bank_revisions`,
--     append-only for every client): who changed them, when, and the
--     validation outcome (IBAN checksum and BIC shape). Read by
--     `manageBilling` only -- the supplier row, which pickers read, carries
--     no bank data, only the current revision number.
--   * `einvoice_inbox.supplier_id` / `expense_schedules.supplier_id`
--     nullable references. The raw supplier name and VAT text on the inbox
--     row stay untouched as the immutable evidence of what arrived.
--   * The backfill and `ingest_einvoice` share ONE path
--     (`supplier_link_source`), idempotent: a linked row, or a row with a
--     review candidate (open or resolved), is never processed again. A
--     different workspace never merges: every lookup is workspace-scoped.
--
-- Read: viewFinances / manageBilling. Write, bank, review resolution:
-- manageBilling, while supplyExpenses is on.

-- ── identity ───────────────────────────────────────────────────────────
-- The canonical form of a VERIFIED tax identifier, or null.
create or replace function public.supplier_tax_identifier(p_raw text)
returns jsonb language plpgsql stable set search_path = public as $fn$
declare
  v text := upper(regexp_replace(coalesce(p_raw, ''), '[ .\-]', '', 'g'));
  v_prefix text;
  v_body text;
  v_pattern text;
begin
  if v !~ '^[A-Z]{2}[A-Z0-9]+$' then return null; end if;
  v_prefix := left(v, 2);
  v_body := substr(v, 3);
  select t.value ->> 'pattern' into v_pattern
    from public.tax_reference t
   where t.domain = 'vat_id_pattern' and t.country = v_prefix
     and t.valid_from <= current_date
     and (t.valid_to is null or t.valid_to > current_date)
   limit 1;
  if v_pattern is null or v_body !~ ('^(?:' || v_pattern || ')$') then return null; end if;
  return jsonb_build_object('scheme', 'vat', 'jurisdiction', v_prefix, 'value', v_prefix || v_body);
end;
$fn$;
revoke execute on function public.supplier_tax_identifier(text) from public, anon;
grant execute on function public.supplier_tax_identifier(text) to authenticated;

-- IBAN: 'valid' | 'empty' | 'format' | 'checksum' (ISO 13616, mod 97).
create or replace function public.supplier_iban_check(p_iban text)
returns text language plpgsql immutable set search_path = public as $fn$
declare
  v text := upper(regexp_replace(coalesce(p_iban, ''), '\s', '', 'g'));
  r text;
  rem int := 0;
  c text;
  i int;
begin
  if v = '' then return 'empty'; end if;
  if v !~ '^[A-Z]{2}[0-9]{2}[A-Z0-9]{11,30}$' then return 'format'; end if;
  r := substr(v, 5) || substr(v, 1, 4);
  for i in 1 .. length(r) loop
    c := substr(r, i, 1);
    if c ~ '[0-9]' then
      rem := (rem * 10 + c::int) % 97;
    else
      rem := (rem * 100 + (ascii(c) - 55)) % 97;
    end if;
  end loop;
  return case when rem = 1 then 'valid' else 'checksum' end;
end;
$fn$;
revoke execute on function public.supplier_iban_check(text) from public, anon;
grant execute on function public.supplier_iban_check(text) to authenticated;

-- ── tables ─────────────────────────────────────────────────────────────
create table public.suppliers (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  supplier_number text not null
    check (char_length(supplier_number) between 1 and 20 and supplier_number = btrim(supplier_number)),
  name text not null check (char_length(btrim(name)) between 1 and 300),
  tax_id_entered text not null default '' check (char_length(tax_id_entered) <= 60),
  tax_identifier text not null default '' check (char_length(tax_identifier) <= 40),
  tax_id_kind text not null default 'vat' check (tax_id_kind in ('vat', 'vat_group')),
  street text not null default '' check (char_length(street) <= 200),
  postal_code text not null default '' check (char_length(postal_code) <= 20),
  city text not null default '' check (char_length(city) <= 100),
  country_code text not null default '' check (country_code = '' or country_code ~ '^[A-Z]{2}$'),
  contact text not null default '' check (char_length(contact) <= 300),
  status text not null default 'active' check (status in ('active', 'archived')),
  bank_revision int not null default 0 check (bank_revision >= 0),
  created_by uuid references public.members(id),
  unique (workspace_id, supplier_number)
);
select public.ensure_system_columns('suppliers');
-- One supplier per verified identifier and workspace (a group identifier is shared).
create unique index suppliers_one_per_tax_identifier
  on public.suppliers (workspace_id, tax_identifier)
  where tax_identifier <> '' and tax_id_kind = 'vat';
create index suppliers_workspace on public.suppliers (workspace_id, status, name);

create table public.supplier_bank_revisions (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  supplier_id uuid not null references public.suppliers(id) on delete cascade,
  revision int not null check (revision >= 1),
  account_holder text not null default '' check (char_length(account_holder) <= 200),
  iban text not null default '' check (char_length(iban) <= 40),
  bic text not null default '' check (char_length(bic) <= 20),
  validation text not null check (validation in ('valid', 'invalid', 'cleared')),
  validation_detail text not null default '' check (char_length(validation_detail) <= 200),
  changed_by uuid references public.members(id),
  changed_at timestamptz not null default now(),
  unique (supplier_id, revision)
);
select public.ensure_system_columns('supplier_bank_revisions');

create table public.supplier_review_candidates (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  source_table text not null check (source_table in ('einvoice_inbox')),
  source_id uuid not null,
  reason text not null
    check (reason in ('missing_identifier', 'unverified_identifier', 'group_identifier')),
  source_name text not null default '' check (char_length(source_name) <= 300),
  source_identifier text not null default '' check (char_length(source_identifier) <= 60),
  candidate_supplier_ids uuid[] not null default '{}',
  status text not null default 'open' check (status in ('open', 'resolved')),
  resolved_supplier_id uuid references public.suppliers(id),
  resolved_by uuid references public.members(id),
  resolved_at timestamptz,
  unique (workspace_id, source_table, source_id),
  check ((status = 'resolved') = (resolved_supplier_id is not null))
);
select public.ensure_system_columns('supplier_review_candidates');
create index supplier_review_open on public.supplier_review_candidates (workspace_id, status);

alter table public.einvoice_inbox
  add column supplier_id uuid references public.suppliers(id);
create index einvoice_inbox_supplier on public.einvoice_inbox (supplier_id) where supplier_id is not null;
alter table public.expense_schedules
  add column supplier_id uuid references public.suppliers(id);

-- ── row level security ─────────────────────────────────────────────────
alter table public.suppliers enable row level security;
revoke all on public.suppliers from public, anon, authenticated;
grant select on public.suppliers to authenticated;
create policy suppliers_select on public.suppliers
  for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewFinances', 'manageBilling'])));
create policy mcp_delegated_deny on public.suppliers as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

alter table public.supplier_bank_revisions enable row level security;
revoke all on public.supplier_bank_revisions from public, anon, authenticated;
grant select on public.supplier_bank_revisions to authenticated;
create policy supplier_bank_revisions_select on public.supplier_bank_revisions
  for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['manageBilling'])));
create policy mcp_delegated_deny on public.supplier_bank_revisions as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

alter table public.supplier_review_candidates enable row level security;
revoke all on public.supplier_review_candidates from public, anon, authenticated;
grant select on public.supplier_review_candidates to authenticated;
create policy supplier_review_candidates_select on public.supplier_review_candidates
  for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewFinances', 'manageBilling'])));
create policy mcp_delegated_deny on public.supplier_review_candidates as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── numbering and the one linking path ─────────────────────────────────
create or replace function public.supplier_next_number(p_workspace_id uuid)
returns text language plpgsql security definer set search_path = public as $fn$
begin
  perform pg_advisory_xact_lock(hashtextextended('supplier_number:' || p_workspace_id::text, 0));
  return (select (coalesce(max(s.supplier_number::bigint), 0) + 1)::text
            from public.suppliers s
           where s.workspace_id = p_workspace_id and s.supplier_number ~ '^[0-9]{1,15}$');
end;
$fn$;
revoke execute on function public.supplier_next_number(uuid) from public, anon, authenticated;

-- Links ONE source record to a supplier, or leaves a review candidate.
-- Returns 'linked' | 'created' | 'review' | 'skipped'. Idempotent.
create or replace function public.supplier_link_source(p_source_table text, p_source_id uuid)
returns text language plpgsql security definer set search_path = public as $fn$
declare
  v_doc public.einvoice_inbox;
  v_ident jsonb;
  v_value text;
  v_reason text;
  v_hint uuid[];
  v_id uuid;
  v_member uuid;
begin
  if p_source_table <> 'einvoice_inbox' then
    raise exception 'unknown supplier source %', p_source_table;
  end if;
  select * into v_doc from public.einvoice_inbox where id = p_source_id for update;
  if v_doc.id is null then raise exception 'unknown supplier source'; end if;
  if v_doc.supplier_id is not null
     or exists (select 1 from public.supplier_review_candidates c
                 where c.workspace_id = v_doc.workspace_id
                   and c.source_table = p_source_table and c.source_id = p_source_id) then
    return 'skipped';
  end if;
  v_ident := public.supplier_tax_identifier(v_doc.supplier_vat_id);
  if v_ident is null then
    v_reason := case when btrim(v_doc.supplier_vat_id) = '' then 'missing_identifier'
                     else 'unverified_identifier' end;
  else
    v_value := v_ident ->> 'value';
    select coalesce(array_agg(s.id order by s.supplier_number), '{}') into v_hint
      from public.suppliers s
     where s.workspace_id = v_doc.workspace_id and s.tax_identifier = v_value
       and s.tax_id_kind = 'vat_group';
    if cardinality(v_hint) > 0 then v_reason := 'group_identifier'; end if;
  end if;
  if v_reason is not null then
    -- The name only HINTS at who it might be; it never links.
    if v_reason <> 'group_identifier' then
      select coalesce(array_agg(s.id order by s.supplier_number), '{}') into v_hint
        from public.suppliers s
       where s.workspace_id = v_doc.workspace_id
         and lower(btrim(s.name)) = lower(btrim(v_doc.supplier_name));
    end if;
    insert into public.supplier_review_candidates
      (workspace_id, source_table, source_id, reason, source_name, source_identifier, candidate_supplier_ids)
    values (v_doc.workspace_id, p_source_table, p_source_id, v_reason,
            left(v_doc.supplier_name, 300), left(v_doc.supplier_vat_id, 60), v_hint);
    return 'review';
  end if;
  select s.id into v_id from public.suppliers s
   where s.workspace_id = v_doc.workspace_id and s.tax_identifier = v_value and s.tax_id_kind = 'vat';
  if v_id is not null then
    update public.einvoice_inbox set supplier_id = v_id where id = p_source_id;
    return 'linked';
  end if;
  select id into v_member from public.members
   where workspace_id = v_doc.workspace_id and user_id = auth.uid() and status = 'active';
  insert into public.suppliers
    (workspace_id, supplier_number, name, tax_id_entered, tax_identifier, created_by)
  values (v_doc.workspace_id, public.supplier_next_number(v_doc.workspace_id),
          left(btrim(v_doc.supplier_name), 300), left(v_doc.supplier_vat_id, 60), v_value, v_member)
  returning id into v_id;
  update public.einvoice_inbox set supplier_id = v_id where id = p_source_id;
  return 'created';
end;
$fn$;
revoke execute on function public.supplier_link_source(text, uuid) from public, anon, authenticated;

-- The backfill: every inbox row not yet linked or under review.
create or replace function public.supplier_backfill(p_workspace_id uuid default null)
returns int language plpgsql security definer set search_path = public as $fn$
declare
  r record;
  n int := 0;
begin
  for r in
    select i.id from public.einvoice_inbox i
     where i.supplier_id is null and (p_workspace_id is null or i.workspace_id = p_workspace_id)
     order by i.workspace_id, i.issue_date, i.id
  loop
    if public.supplier_link_source('einvoice_inbox', r.id) <> 'skipped' then n := n + 1; end if;
  end loop;
  return n;
end;
$fn$;
revoke execute on function public.supplier_backfill(uuid) from public, anon, authenticated;

select public.supplier_backfill(null);

-- ── the consumer: the inbox links its supplier on arrival ──────────────
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
  perform public.supplier_link_source('einvoice_inbox', v_id);
  return v_id;
end;
$fn$;
revoke execute on function public.ingest_einvoice(uuid, text, text, jsonb)
  from public, anon;

-- ── administration ─────────────────────────────────────────────────────
create or replace function public.supplier_guard(p_workspace_id uuid)
returns uuid language plpgsql security definer set search_path = public as $fn$
declare
  v_member uuid;
begin
  if auth.uid() is null or not public.has_permission(p_workspace_id, 'manageBilling') then
    raise exception 'not allowed to manage suppliers';
  end if;
  if not public.feature_effective(p_workspace_id, 'supplyExpenses') then
    raise exception 'supplier management is switched off in this space';
  end if;
  select id into v_member from public.members
   where workspace_id = p_workspace_id and user_id = auth.uid() and status = 'active';
  return v_member;
end;
$fn$;
revoke execute on function public.supplier_guard(uuid) from public, anon, authenticated;

-- Creates (p_supplier_id null) or updates a supplier. The tax identifier is
-- kept as entered; only a verified one becomes the merge key.
create or replace function public.save_supplier(
  p_workspace_id uuid, p_supplier_id uuid, p_name text, p_tax_id text,
  p_tax_id_kind text, p_street text, p_postal_code text, p_city text,
  p_country_code text, p_contact text, p_number text
) returns uuid
language plpgsql security definer set search_path = public as $fn$
declare
  v_member uuid := public.supplier_guard(p_workspace_id);
  v_name text := btrim(coalesce(p_name, ''));
  v_entered text := btrim(coalesce(p_tax_id, ''));
  v_kind text := coalesce(nullif(p_tax_id_kind, ''), 'vat');
  v_value text := coalesce(public.supplier_tax_identifier(p_tax_id) ->> 'value', '');
  v_number text := btrim(coalesce(p_number, ''));
  v_id uuid := p_supplier_id;
begin
  if char_length(v_name) not between 1 and 300 then
    raise exception 'a supplier needs a name of 1-300 characters';
  end if;
  if v_kind not in ('vat', 'vat_group') then raise exception 'unknown identifier kind'; end if;
  if v_value <> '' and v_kind = 'vat' and exists (
       select 1 from public.suppliers s
        where s.workspace_id = p_workspace_id and s.tax_identifier = v_value
          and s.tax_id_kind = 'vat' and s.id is distinct from p_supplier_id) then
    raise exception 'another supplier already has this tax identifier';
  end if;
  if v_number <> '' and exists (
       select 1 from public.suppliers s
        where s.workspace_id = p_workspace_id and s.supplier_number = v_number
          and s.id is distinct from p_supplier_id) then
    raise exception 'this supplier number is already used';
  end if;
  if p_supplier_id is null then
    insert into public.suppliers
      (workspace_id, supplier_number, name, tax_id_entered, tax_identifier, tax_id_kind,
       street, postal_code, city, country_code, contact, created_by)
    values (p_workspace_id,
            case when v_number = '' then public.supplier_next_number(p_workspace_id) else v_number end,
            v_name, left(v_entered, 60), v_value, v_kind,
            coalesce(p_street, ''), coalesce(p_postal_code, ''), coalesce(p_city, ''),
            upper(coalesce(p_country_code, '')), coalesce(p_contact, ''), v_member)
    returning id into v_id;
  else
    update public.suppliers set
      name = v_name, tax_id_entered = left(v_entered, 60), tax_identifier = v_value,
      tax_id_kind = v_kind, street = coalesce(p_street, ''),
      postal_code = coalesce(p_postal_code, ''), city = coalesce(p_city, ''),
      country_code = upper(coalesce(p_country_code, '')), contact = coalesce(p_contact, ''),
      supplier_number = case when v_number = '' then supplier_number else v_number end
     where id = p_supplier_id and workspace_id = p_workspace_id;
    if not found then raise exception 'unknown supplier'; end if;
  end if;
  return v_id;
end;
$fn$;
revoke execute on function public.save_supplier(uuid, uuid, text, text, text, text, text, text, text, text, text)
  from public, anon;

create or replace function public.set_supplier_status(p_supplier_id uuid, p_status text)
returns void language plpgsql security definer set search_path = public as $fn$
declare
  v_ws uuid;
begin
  select workspace_id into v_ws from public.suppliers where id = p_supplier_id;
  if v_ws is null then raise exception 'unknown supplier'; end if;
  perform public.supplier_guard(v_ws);
  if p_status not in ('active', 'archived') then raise exception 'unknown supplier status'; end if;
  update public.suppliers set status = p_status where id = p_supplier_id;
end;
$fn$;
revoke execute on function public.set_supplier_status(uuid, text) from public, anon;

-- A bank-detail change is a new revision with its validation outcome and
-- who made it; an unchanged value adds nothing. Returns the current revision.
create or replace function public.set_supplier_bank(
  p_supplier_id uuid, p_account_holder text, p_iban text, p_bic text
) returns int
language plpgsql security definer set search_path = public as $fn$
declare
  v_ws uuid;
  v_member uuid;
  v_cur public.supplier_bank_revisions;
  v_holder text := btrim(coalesce(p_account_holder, ''));
  v_iban text := upper(regexp_replace(coalesce(p_iban, ''), '\s', '', 'g'));
  v_bic text := upper(regexp_replace(coalesce(p_bic, ''), '\s', '', 'g'));
  v_iban_check text;
  v_validation text;
  v_detail text := '';
  v_rev int;
begin
  select workspace_id, bank_revision into v_ws, v_rev from public.suppliers where id = p_supplier_id for update;
  if v_ws is null then raise exception 'unknown supplier'; end if;
  v_member := public.supplier_guard(v_ws);
  select * into v_cur from public.supplier_bank_revisions
   where supplier_id = p_supplier_id and revision = v_rev;
  if v_cur.id is not null and v_cur.account_holder = v_holder
     and v_cur.iban = v_iban and v_cur.bic = v_bic then
    return v_rev;
  end if;
  if v_cur.id is null and v_holder = '' and v_iban = '' and v_bic = '' then
    return v_rev;
  end if;
  v_iban_check := public.supplier_iban_check(v_iban);
  if v_holder = '' and v_iban = '' and v_bic = '' then
    v_validation := 'cleared';
  elsif v_iban_check not in ('valid', 'empty') then
    v_validation := 'invalid'; v_detail := 'iban_' || v_iban_check;
  elsif v_bic <> '' and v_bic !~ '^[A-Z]{6}[A-Z0-9]{2}([A-Z0-9]{3})?$' then
    v_validation := 'invalid'; v_detail := 'bic_format';
  elsif v_iban_check = 'empty' then
    v_validation := 'invalid'; v_detail := 'iban_empty';
  else
    v_validation := 'valid';
  end if;
  v_rev := v_rev + 1;
  insert into public.supplier_bank_revisions
    (workspace_id, supplier_id, revision, account_holder, iban, bic, validation, validation_detail, changed_by)
  values (v_ws, p_supplier_id, v_rev, v_holder, v_iban, v_bic, v_validation, v_detail, v_member);
  update public.suppliers set bank_revision = v_rev where id = p_supplier_id;
  return v_rev;
end;
$fn$;
revoke execute on function public.set_supplier_bank(uuid, text, text, text) from public, anon;

-- A person decides a review candidate: link the source to a supplier of the
-- workspace, or (null) make a new supplier from the source's own text.
create or replace function public.resolve_supplier_review(p_candidate_id uuid, p_supplier_id uuid)
returns uuid language plpgsql security definer set search_path = public as $fn$
declare
  v_c public.supplier_review_candidates;
  v_member uuid;
  v_id uuid := p_supplier_id;
begin
  select * into v_c from public.supplier_review_candidates where id = p_candidate_id for update;
  if v_c.id is null then raise exception 'unknown review candidate'; end if;
  v_member := public.supplier_guard(v_c.workspace_id);
  if v_c.status <> 'open' then raise exception 'this candidate was already resolved'; end if;
  if v_id is null then
    insert into public.suppliers (workspace_id, supplier_number, name, tax_id_entered, created_by)
    values (v_c.workspace_id, public.supplier_next_number(v_c.workspace_id),
            left(btrim(v_c.source_name), 300), v_c.source_identifier, v_member)
    returning id into v_id;
  elsif not exists (select 1 from public.suppliers s
                     where s.id = v_id and s.workspace_id = v_c.workspace_id) then
    raise exception 'that supplier is not of this space';
  end if;
  update public.einvoice_inbox set supplier_id = v_id
   where id = v_c.source_id and workspace_id = v_c.workspace_id;
  update public.supplier_review_candidates
     set status = 'resolved', resolved_supplier_id = v_id, resolved_by = v_member, resolved_at = now()
   where id = p_candidate_id;
  return v_id;
end;
$fn$;
revoke execute on function public.resolve_supplier_review(uuid, uuid) from public, anon;

select public.set_deskilo_schema_version(457);
