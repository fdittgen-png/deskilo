-- SPDX-License-Identifier: 0BSD
-- VAT declarations (#534): the periodic return a VAT-registered
-- workspace owes its tax administration — per-rate taxable base and
-- output VAT, aggregated from the period's ISSUED invoices.
--
-- The NUMBERS are computed CLIENT-side with the exact vatSplit the
-- invoices themselves were built with (per-line gross → net rounding),
-- so the declaration matches every issued document to the cent; the
-- server stores the snapshot and owns the lifecycle:
--   draft      — generated, editable by regenerating (upsert per period)
--   submitted  — transmitted electronically (send-e-invoice channel, a
--                portal upload, or filed by hand on the authority's EFI
--                portal) — immutable from then on.
--
-- France files the CA3 via EDI/EFI, Germany the UStVA via ELSTER only:
-- DIRECT government submission needs certified channels/credentials no
-- app can ship generically. What the app supports entirely is the part
-- software can own: the return's numbers on the official lines, the
-- machine-readable + PDF documents, electronic dispatch through the
-- configured platform, and the audit trail.

create table public.vat_declarations (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id)
    on delete cascade,
  period_start date not null,
  period_end date not null,
  status text not null default 'draft'
    check (status in ('draft', 'submitted')),
  -- [{"percent": 20, "gross_cents": int, "net_cents": int,
  --   "vat_cents": int, "invoice_count": int}, ...]
  lines jsonb not null,
  total_net_cents int not null,
  total_vat_cents int not null,
  currency text not null default '',
  invoice_count int not null default 0,
  created_at timestamptz not null default now(),
  created_by_name text not null default '',
  submitted_at timestamptz,
  submitted_channel text not null default '',
  submitted_receipt text not null default '',
  unique (workspace_id, period_start, period_end)
);

alter table public.vat_declarations enable row level security;

-- Read: the workspace's admins (the finance surface) — mirrors invoices.
create policy vat_declarations_select on public.vat_declarations
  for select using (public.is_admin_of(workspace_id));
-- Writes via the RPCs only (default-deny).

-- Generates or regenerates the DRAFT for a period. Only the owner (or a
-- co-owner acting as one) of a vat_registered workspace; a submitted
-- declaration for the period refuses regeneration — the filed return is
-- history, corrections belong to the next period or the authority's own
-- amendment process.
create or replace function public.save_vat_declaration(
  p_workspace_id uuid,
  p_period_start date,
  p_period_end date,
  p_lines jsonb,
  p_total_net_cents int,
  p_total_vat_cents int,
  p_currency text,
  p_invoice_count int
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_actor public.members;
  v_existing public.vat_declarations;
  v_id uuid;
begin
  select * into v_actor from public.members
    where workspace_id = p_workspace_id
      and user_id = auth.uid() and status = 'active';
  if v_actor.id is null or not (v_actor.is_owner or coalesce(v_actor.co_owner, 'none') = 'active') then
    raise exception 'only the owner files VAT declarations';
  end if;
  if not public.workspace_charges_vat(p_workspace_id) then
    raise exception 'the workspace is not VAT registered';
  end if;
  if p_period_end < p_period_start then
    raise exception 'invalid period';
  end if;

  select * into v_existing from public.vat_declarations
    where workspace_id = p_workspace_id
      and period_start = p_period_start and period_end = p_period_end;
  if v_existing.id is not null then
    if v_existing.status = 'submitted' then
      raise exception 'declaration already submitted for this period';
    end if;
    update public.vat_declarations
       set lines = p_lines,
           total_net_cents = p_total_net_cents,
           total_vat_cents = p_total_vat_cents,
           currency = p_currency,
           invoice_count = p_invoice_count,
           created_at = now()
     where id = v_existing.id;
    return v_existing.id;
  end if;

  insert into public.vat_declarations
      (workspace_id, period_start, period_end, lines,
       total_net_cents, total_vat_cents, currency, invoice_count,
       created_by_name)
    values
      (p_workspace_id, p_period_start, p_period_end, p_lines,
       p_total_net_cents, p_total_vat_cents, p_currency, p_invoice_count,
       coalesce((select display_name from public.profiles
                  where id = auth.uid()), ''))
    returning id into v_id;
  return v_id;
end;
$$;
revoke execute on function public.save_vat_declaration(
  uuid, date, date, jsonb, int, int, text, int) from public, anon;

-- Stamps a draft as SUBMITTED with the channel that carried it
-- ('platform' = the send-e-invoice upload, 'export' = the owner took
-- the file to the authority's portal, 'manual' = keyed into EFI/ELSTER
-- by hand) and whatever receipt/acknowledgement id came back.
create or replace function public.mark_vat_declaration_submitted(
  p_declaration_id uuid,
  p_channel text,
  p_receipt text default ''
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_decl public.vat_declarations;
  v_actor public.members;
begin
  select * into v_decl from public.vat_declarations
    where id = p_declaration_id;
  if v_decl.id is null then raise exception 'unknown declaration'; end if;
  select * into v_actor from public.members
    where workspace_id = v_decl.workspace_id
      and user_id = auth.uid() and status = 'active';
  if v_actor.id is null or not (v_actor.is_owner or coalesce(v_actor.co_owner, 'none') = 'active') then
    raise exception 'only the owner files VAT declarations';
  end if;
  if v_decl.status = 'submitted' then
    raise exception 'declaration already submitted';
  end if;
  if p_channel not in ('platform', 'export', 'manual') then
    raise exception 'unknown channel';
  end if;
  update public.vat_declarations
     set status = 'submitted',
         submitted_at = now(),
         submitted_channel = p_channel,
         submitted_receipt = left(coalesce(p_receipt, ''), 500)
   where id = p_declaration_id;
end;
$$;
revoke execute on function public.mark_vat_declaration_submitted(
  uuid, text, text) from public, anon;
