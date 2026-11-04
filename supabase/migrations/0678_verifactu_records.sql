-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- #2358 — the Verifactu records of a Spanish seller, kept and chained on the
-- server (RD 1007/2023, Orden HAC/1177/2024).
--
-- Every invoice a Spanish seller issues gets an alta record (RegistroAlta);
-- cancelling it gets an anulación record (RegistroAnulacion). Each record
-- carries its "huella": the SHA-256, upper-case hex, of the fields the
-- AEAT's "Detalle de las especificaciones técnicas para generación de la
-- huella" names, joined with '&', the previous record's huella among them.
-- The chain is one per issuer (workspace and NIF): two records issued at
-- the same moment must not claim the same predecessor, so the chain is
-- extended under a transaction lock, here and never on a phone.
--
--   * `verifactu_huella_alta` / `verifactu_huella_anulacion` hash exactly
--     the AEAT concatenation (pgTAP 357 reproduces the AEAT's three
--     published examples);
--   * `record_verifactu_v1(invoice, kind)` derives the record from the
--     issued invoice itself — its number, its date in the space's time zone,
--     its seller and buyer snapshot, its issued breakdown — as
--     `verifactuRecordFor` (lib/features/money/domain/verifactu.dart) does:
--     F1, F2 without a buyer tax id, R1 for a rectification; a credit
--     note's amounts negative. A second call for the same record answers
--     the one already kept; an anulación needs the alta and comes once;
--   * they are read by whoever the role matrix lets issue invoices or view
--     the finances, and kept only by an invoice issuer;
--   * the records are append-only: the AEAT submission (owner-blocked on
--     the seller's qualified certificate) will only ever move the
--     submission columns.
--
-- Nothing is sent anywhere by this migration.

create table if not exists public.verifactu_records (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete restrict,
  invoice_id uuid not null references public.invoices(id) on delete restrict,
  kind text not null check (kind in ('alta', 'anulacion')),
  -- The position in the issuer's chain, from 1.
  chain_position bigint not null check (chain_position > 0),
  issuer_nif text not null check (issuer_nif <> ''),
  invoice_number text not null,
  issue_date text not null check (issue_date ~ '^\d{2}-\d{2}-\d{4}$'),
  -- F1 / F2 / R1 on an alta; '' on an anulación (it hashes no type).
  invoice_type text not null default '',
  tax_total text not null default '',
  grand_total text not null default '',
  previous_huella text not null default '',
  previous_number text not null default '',
  previous_issue_date text not null default '',
  generated_at text not null,
  huella text not null check (huella ~ '^[0-9A-F]{64}$'),
  submission_status text not null default 'not_submitted'
    check (submission_status in ('not_submitted', 'accepted', 'accepted_with_errors', 'rejected')),
  submission_detail text not null default '',
  unique (workspace_id, issuer_nif, chain_position)
);
select public.ensure_system_columns('verifactu_records');

create unique index if not exists verifactu_records_one_per_kind
  on public.verifactu_records (invoice_id, kind);
create index if not exists verifactu_records_chain
  on public.verifactu_records (workspace_id, issuer_nif, chain_position desc);

comment on table public.verifactu_records is
  '#2358 — the Verifactu alta and anulación records of a Spanish seller, '
  'chained by their SHA-256 huella; append-only, written by record_verifactu_v1.';

-- The AEAT concatenation of an alta record, hashed.
create or replace function public.verifactu_huella_alta(
  p_issuer_nif text, p_number text, p_issue_date text, p_type text,
  p_tax_total text, p_grand_total text, p_previous_huella text, p_generated_at text
) returns text
language sql immutable set search_path = public as $fn$
  select upper(encode(sha256(convert_to(
    'IDEmisorFactura=' || btrim(p_issuer_nif)
    || '&NumSerieFactura=' || btrim(p_number)
    || '&FechaExpedicionFactura=' || btrim(p_issue_date)
    || '&TipoFactura=' || btrim(p_type)
    || '&CuotaTotal=' || btrim(p_tax_total)
    || '&ImporteTotal=' || btrim(p_grand_total)
    || '&Huella=' || btrim(p_previous_huella)
    || '&FechaHoraHusoGenRegistro=' || btrim(p_generated_at),
    'UTF8')), 'hex'))
$fn$;

revoke execute on function public.verifactu_huella_alta(text, text, text, text, text, text, text, text)
  from public, anon, authenticated;

-- The AEAT concatenation of an anulación record, hashed.
create or replace function public.verifactu_huella_anulacion(
  p_issuer_nif text, p_number text, p_issue_date text, p_previous_huella text, p_generated_at text
) returns text
language sql immutable set search_path = public as $fn$
  select upper(encode(sha256(convert_to(
    'IDEmisorFacturaAnulada=' || btrim(p_issuer_nif)
    || '&NumSerieFacturaAnulada=' || btrim(p_number)
    || '&FechaExpedicionFacturaAnulada=' || btrim(p_issue_date)
    || '&Huella=' || btrim(p_previous_huella)
    || '&FechaHoraHusoGenRegistro=' || btrim(p_generated_at),
    'UTF8')), 'hex'))
$fn$;

revoke execute on function public.verifactu_huella_anulacion(text, text, text, text, text)
  from public, anon, authenticated;

-- An amount as the AEAT writes it: two decimals, '.', a leading '-'.
create or replace function public.verifactu_amount(p_cents bigint)
returns text
language sql immutable set search_path = public as $fn$
  select case when p_cents < 0 then '-' else '' end
      || (abs(p_cents) / 100)::text || '.' || lpad((abs(p_cents) % 100)::text, 2, '0')
$fn$;

revoke execute on function public.verifactu_amount(bigint) from public, anon, authenticated;

-- [p_at] in [p_tz], ISO 8601 with its offset ('2027-02-03T10:15:30+01:00'):
-- the offset is hashed, so the record keeps the spelling it hashed.
create or replace function public.verifactu_timestamp(p_at timestamptz, p_tz text)
returns text
language plpgsql stable set search_path = public as $fn$
declare
  v_local timestamp := p_at at time zone p_tz;
  v_offset interval := v_local - (p_at at time zone 'UTC');
  v_minutes int := (extract(epoch from v_offset) / 60)::int;
begin
  return to_char(v_local, 'YYYY-MM-DD"T"HH24:MI:SS')
      || case when v_minutes < 0 then '-' else '+' end
      || lpad((abs(v_minutes) / 60)::text, 2, '0') || ':'
      || lpad((abs(v_minutes) % 60)::text, 2, '0');
end;
$fn$;

revoke execute on function public.verifactu_timestamp(timestamptz, text) from public, anon, authenticated;

-- Keeps the records, and lets the submission state move alone.
create or replace function public.verifactu_records_append_only()
returns trigger
language plpgsql set search_path = public as $fn$
begin
  if tg_op = 'DELETE' then
    raise exception 'verifactu records are kept';
  end if;
  if (to_jsonb(new) - public.system_column_names() - 'submission_status' - 'submission_detail')
     is distinct from
     (to_jsonb(old) - public.system_column_names() - 'submission_status' - 'submission_detail') then
    raise exception 'verifactu records are immutable';
  end if;
  return new;
end;
$fn$;

revoke execute on function public.verifactu_records_append_only() from public, anon, authenticated;

drop trigger if exists verifactu_records_append_only on public.verifactu_records;
create trigger verifactu_records_append_only
  before update or delete on public.verifactu_records
  for each row execute function public.verifactu_records_append_only();

create or replace function public.record_verifactu_v1(p_invoice_id uuid, p_kind text default 'alta')
returns public.verifactu_records
language plpgsql security definer set search_path = public as $fn$
declare
  v_inv public.invoices;
  v_tz text;
  v_seller jsonb;
  v_buyer jsonb;
  v_nif text;
  v_buyer_id text;
  v_prev public.verifactu_records;
  v_alta public.verifactu_records;
  v_kept public.verifactu_records;
  v_type text := '';
  v_gross bigint;
  v_tax bigint;
  v_tax_total text := '';
  v_grand_total text := '';
  v_issue_date text;
  v_stamp text;
  v_huella text;
  v_row public.verifactu_records;
begin
  -- A signed-in person in a native session only: a delegated (MCP) session
  -- keeps no fiscal record, whatever right its user holds.
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception using errcode = '42501', message = 'keeping a Verifactu record is not available';
  end if;
  if p_kind not in ('alta', 'anulacion') then
    raise exception 'a Verifactu record is an alta or an anulacion';
  end if;
  select * into v_inv from public.invoices where id = p_invoice_id;
  if v_inv.id is null then raise exception 'unknown invoice'; end if;
  -- The role matrix decides (#1321): an owner who takes invoicing away from
  -- the admins takes this away too.
  if not public.has_permission(v_inv.workspace_id, 'issueInvoices') then
    raise exception 'you may not keep this invoice''s records';
  end if;
  v_seller := coalesce(v_inv.parties -> 'seller', '{}'::jsonb);
  v_buyer := coalesce(v_inv.parties -> 'buyer', '{}'::jsonb);
  if upper(coalesce(v_seller ->> 'country', '')) <> 'ES' then
    raise exception 'Verifactu records are kept for a Spanish seller only';
  end if;
  v_nif := upper(replace(coalesce(nullif(v_seller ->> 'vat_id', ''), v_seller ->> 'legal_id', ''), ' ', ''));
  if v_nif like 'ES%' then v_nif := substr(v_nif, 3); end if;
  if v_nif = '' then raise exception 'the seller has no NIF'; end if;

  -- One chain per issuer, extended by one transaction at a time.
  perform pg_advisory_xact_lock(hashtextextended('verifactu:' || v_inv.workspace_id || ':' || v_nif, 0));

  select * into v_kept from public.verifactu_records
   where invoice_id = v_inv.id and kind = p_kind;
  if v_kept.id is not null then return v_kept; end if;
  if p_kind = 'anulacion' then
    select * into v_alta from public.verifactu_records where invoice_id = v_inv.id and kind = 'alta';
    if v_alta.id is null then raise exception 'there is no alta record to cancel'; end if;
  end if;

  select * into v_prev from public.verifactu_records
   where workspace_id = v_inv.workspace_id and issuer_nif = v_nif
   order by chain_position desc limit 1;

  select coalesce(nullif(timezone, ''), 'Europe/Madrid') into v_tz
    from public.workspaces where id = v_inv.workspace_id;
  v_issue_date := to_char(v_inv.issued_at at time zone v_tz, 'DD-MM-YYYY');
  v_stamp := public.verifactu_timestamp(now(), v_tz);

  if p_kind = 'alta' then
    v_buyer_id := coalesce(nullif(v_buyer ->> 'vat_id', ''), v_buyer ->> 'legal_id', '');
    v_type := case
      when v_inv.total_cents < 0 or coalesce(v_inv.replaces_number, '') <> '' then 'R1'
      when v_buyer_id = '' then 'F2'
      else 'F1' end;
    select coalesce(sum((t ->> 'gross_cents')::bigint), v_inv.total_cents),
           coalesce(sum((t ->> 'vat_cents')::bigint), 0)
      into v_gross, v_tax
      from jsonb_array_elements(coalesce(v_inv.vat_totals, '[]'::jsonb)) t;
    if v_inv.total_cents < 0 then
      v_tax := -abs(v_tax);
      if v_gross > 0 then v_gross := -v_gross; end if;
    end if;
    v_tax_total := public.verifactu_amount(v_tax);
    v_grand_total := public.verifactu_amount(v_gross);
    v_huella := public.verifactu_huella_alta(
      v_nif, v_inv.number, v_issue_date, v_type, v_tax_total, v_grand_total,
      coalesce(v_prev.huella, ''), v_stamp);
  else
    v_issue_date := v_alta.issue_date;
    v_huella := public.verifactu_huella_anulacion(
      v_nif, v_inv.number, v_issue_date, coalesce(v_prev.huella, ''), v_stamp);
  end if;

  insert into public.verifactu_records (
    workspace_id, invoice_id, kind, chain_position, issuer_nif, invoice_number,
    issue_date, invoice_type, tax_total, grand_total, previous_huella,
    previous_number, previous_issue_date, generated_at, huella)
  values (
    v_inv.workspace_id, v_inv.id, p_kind, coalesce(v_prev.chain_position, 0) + 1, v_nif, v_inv.number,
    v_issue_date, v_type, v_tax_total, v_grand_total, coalesce(v_prev.huella, ''),
    coalesce(v_prev.invoice_number, ''), coalesce(v_prev.issue_date, ''), v_stamp, v_huella)
  returning * into v_row;
  return v_row;
end;
$fn$;

revoke execute on function public.record_verifactu_v1(uuid, text) from public, anon;
grant execute on function public.record_verifactu_v1(uuid, text) to authenticated;

alter table public.verifactu_records enable row level security;
revoke all on public.verifactu_records from anon;
revoke insert, update, delete on public.verifactu_records from authenticated;
grant select on public.verifactu_records to authenticated;

drop policy if exists verifactu_records_select on public.verifactu_records;
create policy verifactu_records_select on public.verifactu_records
  for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['issueInvoices', 'viewFinances'])));
drop policy if exists mcp_delegated_deny on public.verifactu_records;
create policy mcp_delegated_deny on public.verifactu_records as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(678);
