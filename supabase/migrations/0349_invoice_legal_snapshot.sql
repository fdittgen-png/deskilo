-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0349 (#1916) — an invoice keeps the legal clauses it was issued with,
-- and the customer's capacity is a stated fact, not a guess.
--
-- Until now the payment clauses an invoice printed (payment terms, late
-- penalty, recovery indemnity, early-payment discount) and the seller's
-- legal lines were read from the LIVE workspace settings every time the
-- document was rendered. Editing the settings rewrote the terms of every
-- invoice already issued, and which statutory defaults applied was
-- decided by the seller's legal form (an association got none) instead
-- of by the customer's capacity, which is what the law asks.
--
--   * `members.customer_capacity` — `business` or `consumer`, or null
--     (not stated: the workspace default in `invoice_legal`
--     `customer_capacity` applies, and without one the capacity is
--     `unknown`). Set by whoever may issue invoices, through
--     `set_member_customer_capacity`. Never derived from a VAT number or
--     a company name.
--   * `invoices.legal_snapshot` — written ONCE, before the row is
--     inserted, by `invoice_legal_freeze`: the seller's legal form and
--     kind, the seller and buyer countries as the parties froze them, the
--     buyer's capacity and where it came from, the effective payment
--     clauses (workspace text with the member's own on top, exactly as
--     `effective_payment_terms` merges them), the insurance and special
--     mentions, the VAT exigibility basis, and a SHA-256 fingerprint of
--     all of it. `invoices_immutable` already refuses any later change to
--     the row, this column included. The snapshot holds the OWNER'S
--     texts and the facts; which clauses a profile prints is decided by
--     the app from these facts, versioned by `schema`.
--   * Invoices issued before this migration keep `legal_snapshot = null`:
--     the app reads that as "legacy, evidence unknown" and renders them
--     as they always rendered. Nothing is reissued, nothing is invented.
--
-- The fingerprint is an integrity check of the snapshot, not an
-- electronic signature.

alter table public.members
  add column if not exists customer_capacity text
    check (customer_capacity is null
           or customer_capacity in ('business', 'consumer'));

comment on column public.members.customer_capacity is
  '#1916 — whether this customer acts as a business or as a consumer; '
  'null = not stated (the workspace default applies).';

alter table public.invoices add column if not exists legal_snapshot jsonb;

comment on column public.invoices.legal_snapshot is
  '#1916 — the legal clauses and facts frozen at issue (schema 1); null '
  'on invoices issued before 0349 (legacy, evidence unknown).';

-- ── the setter ─────────────────────────────────────────────────────────
create or replace function public.set_member_customer_capacity(
  p_member_id uuid, p_capacity text
) returns void
language plpgsql security definer set search_path = public as $fn$
declare
  v_target public.members;
begin
  select * into v_target from public.members where id = p_member_id;
  if v_target.id is null then raise exception 'unknown member'; end if;
  if auth.uid() is null
     or not public.has_permission(v_target.workspace_id, 'issueInvoices') then
    raise exception 'not allowed to set the customer capacity';
  end if;
  if p_capacity is not null and p_capacity not in ('business', 'consumer') then
    raise exception 'unknown customer capacity';
  end if;
  update public.members set customer_capacity = p_capacity
   where id = p_member_id;
end;
$fn$;

revoke execute on function public.set_member_customer_capacity(uuid, text)
  from public, anon;
grant execute on function public.set_member_customer_capacity(uuid, text)
  to authenticated;

-- ── the snapshot ───────────────────────────────────────────────────────
create or replace function public.invoice_legal_snapshot(
  p_workspace_id uuid, p_member_id uuid, p_parties jsonb
) returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_legal jsonb;
  v_country text;
  v_member_terms jsonb;
  v_member_capacity text;
  v_default_capacity text;
  v_capacity text;
  v_source text;
  v_body jsonb;
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
    'vat_exigibility', coalesce(v_legal ->> 'vat_exigibility', 'invoice'));
  return v_body || jsonb_build_object('fingerprint',
    encode(extensions.digest(convert_to(v_body::text, 'UTF8'), 'sha256'), 'hex'));
end;
$fn$;

revoke execute on function public.invoice_legal_snapshot(uuid, uuid, jsonb)
  from public, anon, authenticated;

create or replace function public.invoice_legal_freeze()
returns trigger
language plpgsql security definer set search_path = public as $fn$
begin
  if new.legal_snapshot is null then
    new.legal_snapshot := public.invoice_legal_snapshot(
      new.workspace_id, new.member_id, new.parties);
  end if;
  return new;
end;
$fn$;

revoke execute on function public.invoice_legal_freeze() from public, anon, authenticated;

drop trigger if exists invoice_legal_freeze on public.invoices;
create trigger invoice_legal_freeze
  before insert on public.invoices
  for each row execute function public.invoice_legal_freeze();

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(349);
