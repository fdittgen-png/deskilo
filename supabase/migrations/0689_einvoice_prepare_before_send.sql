-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- #3335 — an e-invoice is PREPARED durably before any byte leaves.
--
-- Until now send-e-invoice posted to the provider and only then inserted
-- the log row: a crash lost the attempt, two requests both posted, and a
-- lost response left no trace. The contract (docs/domain/contracts/
-- e-invoice-transmission.md) asks for one stable record per business
-- transmission, created before dispatch, claimed atomically with an owner
-- and a generation, and never resent once a dispatch may have landed.
--
-- This file extends invoice_transmissions in place (it stays the history
-- the clients read), keeps the legacy `status` column as a projection of
-- the new `phase` so a deployed older client still reads an honest row,
-- and adds service-role-only RPCs: prepare, claim, record outcome, record
-- a lookup/status answer, resolve by hand.

-- ── 1. the record ────────────────────────────────────────────────────
alter table public.invoice_transmissions
  add column if not exists phase text,
  add column if not exists business_key text,
  add column if not exists binding_hash text,
  add column if not exists owner_id uuid,
  add column if not exists generation integer not null default 0,
  add column if not exists deadline timestamptz,
  add column if not exists correlation_key text,
  add column if not exists verdict jsonb not null default '{}'::jsonb,
  add column if not exists query_error text not null default '',
  add column if not exists requested_by uuid,
  add column if not exists resolved_by uuid,
  add column if not exists resolved_reason text,
  add column if not exists resolved_evidence text,
  add column if not exists resolved_at timestamptz;

update public.invoice_transmissions set phase = status where phase is null;

alter table public.invoice_transmissions
  alter column phase set not null,
  alter column phase set default 'prepared';

alter table public.invoice_transmissions
  add constraint invoice_transmissions_phase_check
  check (phase in
    ('prepared', 'sent', 'accepted', 'rejected', 'failed', 'uncertain'));

-- One logical transmission = one row. Rows written before this change
-- keep a null key and stay a plain log.
create unique index invoice_transmissions_business_key_uq
  on public.invoice_transmissions (business_key)
  where business_key is not null;

comment on column public.invoice_transmissions.phase is
  '#3335 — prepared | sent | accepted | rejected | failed | uncertain. `status` stays the legacy three-value projection of it';
comment on column public.invoice_transmissions.business_key is
  '#3335 — workspace|invoice|provider|destination|environment; independent of request ids and bytes';
comment on column public.invoice_transmissions.binding_hash is
  '#3335 — sha256 of digest|format|receiver; a changed binding conflicts, it never opens a second submission';
comment on column public.invoice_transmissions.generation is
  '#3335 — dispatch generation; a late writer holding an older one records nothing';
comment on column public.invoice_transmissions.verdict is
  '#3335 — the document verdict, kept beside the upload receipt, never over it';
comment on column public.invoice_transmissions.query_error is
  '#3335 — the last status-query failure, kept beside the receipt';

-- ── 2. the legacy projection ─────────────────────────────────────────
-- An older client reads `status` and maps what it does not know to
-- "failed". An unresolved row is therefore projected as failed with a
-- fixed detail that says it was NOT sent again; the server refuses any
-- second dispatch regardless of what the client believes.
create or replace function public.invoice_transmissions_sync_phase()
returns trigger language plpgsql set search_path = public as $fn$
begin
  if new.phase is null or (tg_op = 'INSERT' and new.phase = 'prepared'
      and new.status in ('accepted', 'rejected')) then
    -- an older Edge Function writes `status` only
    new.phase := new.status;
  end if;
  new.status := case new.phase
    when 'accepted' then 'accepted'
    when 'rejected' then 'rejected'
    else 'failed' end;
  if new.phase in ('prepared', 'sent', 'uncertain') and new.detail = '' then
    new.detail := 'In progress or unresolved - do not resend';
  end if;
  return new;
end;
$fn$;

create trigger invoice_transmissions_sync_phase
  before insert or update on public.invoice_transmissions
  for each row execute function public.invoice_transmissions_sync_phase();

-- ── 3. the stored artifact ───────────────────────────────────────────
-- The exact bytes that may leave, kept with the record so recovery never
-- depends on a mutable request. Service role only.
create table public.invoice_transmission_artifacts (
  transmission_id uuid primary key
    references public.invoice_transmissions(id) on delete cascade,
  workspace_id uuid not null references public.workspaces(id)
    on delete cascade,
  bytes bytea not null,
  sha256 text not null,
  file_name text not null default '',
  mime_type text not null default 'application/pdf',
  receiver_scheme text not null default '',
  receiver_id text not null default ''
);
select public.ensure_system_columns('invoice_transmission_artifacts');

alter table public.invoice_transmission_artifacts enable row level security;
-- No select/insert policy: deny-all to client roles.
create policy mcp_delegated_deny on public.invoice_transmission_artifacts
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated())
  with check (not public.mcp_is_delegated());

-- ── 4. prepare ───────────────────────────────────────────────────────
create or replace function public.prepare_einvoice_v1(
  p_workspace_id uuid, p_invoice_id uuid, p_provider text,
  p_destination text, p_environment text, p_actor uuid, p_by_name text,
  p_format text, p_hash text, p_file_name text, p_mime_type text,
  p_receiver_scheme text, p_receiver_id text, p_bytes bytea
) returns jsonb language plpgsql security definer set search_path = public
as $fn$
declare
  v_key text := concat_ws('|', p_workspace_id, p_invoice_id, p_provider,
    p_destination, p_environment);
  v_binding text := encode(sha256(convert_to(concat_ws('|', p_hash,
    p_format, coalesce(p_receiver_scheme, ''), coalesce(p_receiver_id, '')),
    'utf8')), 'hex');
  v_id uuid;
  v_row public.invoice_transmissions;
begin
  if not exists (select 1 from public.invoices
      where id = p_invoice_id and workspace_id = p_workspace_id) then
    return jsonb_build_object('outcome', 'unknown_invoice');
  end if;

  -- a submission written before this change that the platform took
  -- (same invoice, target, destination, environment) is the original
  select * into v_row from public.invoice_transmissions
    where invoice_id = p_invoice_id and workspace_id = p_workspace_id
      and business_key is null and provider = p_provider
      and destination = p_destination and environment = p_environment
      and status = 'accepted'
    order by sent_at desc limit 1;
  if found then
    return jsonb_build_object('outcome', 'existing', 'id', v_row.id,
      'phase', v_row.phase, 'external_id', v_row.external_id,
      'detail', v_row.detail);
  end if;

  insert into public.invoice_transmissions (workspace_id, invoice_id,
    provider, status, phase, document_hash, by_name, environment,
    destination, format, business_key, binding_hash, requested_by)
  values (p_workspace_id, p_invoice_id, p_provider, 'failed', 'prepared',
    p_hash, coalesce(p_by_name, ''), p_environment, p_destination,
    p_format, v_key, v_binding, p_actor)
  on conflict (business_key) where business_key is not null do nothing
  returning id into v_id;

  if v_id is not null then
    insert into public.invoice_transmission_artifacts (transmission_id,
      workspace_id, bytes, sha256, file_name, mime_type, receiver_scheme,
      receiver_id)
    values (v_id, p_workspace_id, p_bytes, p_hash, coalesce(p_file_name, ''),
      coalesce(p_mime_type, 'application/pdf'),
      coalesce(p_receiver_scheme, ''), coalesce(p_receiver_id, ''));
    return jsonb_build_object('outcome', 'prepared', 'id', v_id,
      'phase', 'prepared');
  end if;

  select * into v_row from public.invoice_transmissions
    where business_key = v_key;
  if v_row.binding_hash is distinct from v_binding then
    return jsonb_build_object('outcome', 'conflict', 'id', v_row.id,
      'phase', v_row.phase, 'detail', 'binding_changed');
  end if;
  return jsonb_build_object('outcome', 'existing', 'id', v_row.id,
    'phase', v_row.phase, 'external_id', v_row.external_id,
    'detail', v_row.detail);
end;
$fn$;

-- ── 5. expiry, claim, outcome ────────────────────────────────────────
-- Possible dispatch + a passed deadline = uncertain. Never rejection.
create or replace function public.expire_einvoice_dispatches_v1(
  p_workspace_id uuid
) returns integer language plpgsql security definer set search_path = public
as $fn$
declare v_n integer;
begin
  update public.invoice_transmissions set phase = 'uncertain'
    where workspace_id = p_workspace_id and phase = 'sent'
      and deadline is not null and deadline < now();
  get diagnostics v_n = row_count;
  return v_n;
end;
$fn$;

create or replace function public.claim_einvoice_dispatch_v1(
  p_id uuid, p_owner uuid, p_window_seconds integer
) returns jsonb language plpgsql security definer set search_path = public
as $fn$
declare
  v_row public.invoice_transmissions;
begin
  update public.invoice_transmissions set phase = 'uncertain'
    where id = p_id and phase = 'sent' and deadline < now();
  -- only a record that provably never dispatched (prepared) or whose
  -- failure proved no acceptance (failed) may be claimed
  update public.invoice_transmissions
    set phase = 'sent', owner_id = p_owner, generation = generation + 1,
        deadline = now() + make_interval(secs => p_window_seconds)
    where id = p_id and phase in ('prepared', 'failed')
    returning * into v_row;
  if found then
    return jsonb_build_object('claimed', true, 'phase', 'sent',
      'generation', v_row.generation);
  end if;
  select * into v_row from public.invoice_transmissions where id = p_id;
  return jsonb_build_object('claimed', false, 'phase', v_row.phase,
    'external_id', v_row.external_id, 'detail', v_row.detail);
end;
$fn$;

create or replace function public.record_einvoice_outcome_v1(
  p_id uuid, p_generation integer, p_owner uuid, p_phase text,
  p_external_id text, p_detail text, p_receipt jsonb
) returns jsonb language plpgsql security definer set search_path = public
as $fn$
declare v_row public.invoice_transmissions;
begin
  if p_phase not in ('accepted', 'rejected', 'failed', 'uncertain') then
    raise exception 'invalid outcome phase' using errcode = '22023';
  end if;
  update public.invoice_transmissions
    set phase = p_phase, external_id = coalesce(p_external_id, ''),
        detail = coalesce(p_detail, ''),
        receipt = coalesce(p_receipt, '{}'::jsonb),
        receipt_at = case when coalesce(p_receipt, '{}'::jsonb)
          = '{}'::jsonb then receipt_at else now() end
    where id = p_id and generation = p_generation and owner_id = p_owner
      and phase = 'sent'
    returning * into v_row;
  if not found then
    -- a stale or late writer: nothing changes
    return jsonb_build_object('recorded', false);
  end if;
  return jsonb_build_object('recorded', true, 'phase', v_row.phase);
end;
$fn$;

-- A lookup or status answer. With p_phase it settles an uncertain row
-- (accepted/rejected only); without it, it only adds facts beside the
-- upload receipt of an accepted or uncertain row.
create or replace function public.record_einvoice_lookup_v1(
  p_id uuid, p_phase text, p_external_id text, p_receipt jsonb,
  p_verdict jsonb, p_query_error text
) returns jsonb language plpgsql security definer set search_path = public
as $fn$
declare v_row public.invoice_transmissions;
begin
  if p_phase is not null and p_phase not in ('accepted', 'rejected') then
    raise exception 'invalid lookup phase' using errcode = '22023';
  end if;
  update public.invoice_transmissions set
      phase = coalesce(p_phase, phase),
      external_id = case when p_phase is null then external_id
        else coalesce(nullif(p_external_id, ''), external_id) end,
      receipt = case when p_receipt is null then receipt else p_receipt end,
      receipt_at = case when p_receipt is null then receipt_at
        else now() end,
      verdict = coalesce(p_verdict, verdict),
      query_error = coalesce(p_query_error, '')
    where id = p_id
      and ((p_phase is null and phase in ('accepted', 'uncertain'))
        or (p_phase is not null and phase = 'uncertain'))
    returning * into v_row;
  if not found then return jsonb_build_object('recorded', false); end if;
  return jsonb_build_object('recorded', true, 'phase', v_row.phase);
end;
$fn$;

-- ── 6. manual resolution ─────────────────────────────────────────────
-- The existing send authority (active member; owner/admin or
-- issueInvoices), an attributable reason and evidence, and a
-- compare-and-set on `uncertain`: a second resolution changes nothing.
create or replace function public.resolve_einvoice_manually_v1(
  p_id uuid, p_actor uuid, p_outcome text, p_reason text, p_evidence text
) returns jsonb language plpgsql security definer set search_path = public
as $fn$
declare
  v_ws uuid;
  v_member public.members;
  v_row public.invoice_transmissions;
begin
  if p_outcome not in ('accepted', 'rejected', 'failed') then
    raise exception 'invalid resolution' using errcode = '22023';
  end if;
  if coalesce(trim(p_reason), '') = '' or coalesce(trim(p_evidence), '') = ''
  then
    raise exception 'a reason and the evidence are required'
      using errcode = '22023';
  end if;
  select workspace_id into v_ws from public.invoice_transmissions
    where id = p_id;
  if v_ws is null then
    return jsonb_build_object('resolved', false, 'detail', 'unknown');
  end if;
  select * into v_member from public.members
    where workspace_id = v_ws and user_id = p_actor and status = 'active';
  if not found or not (v_member.is_admin or v_member.is_owner
      or public.member_has_permission(v_member.id, 'issueInvoices')) then
    raise exception 'not allowed to resolve this transmission'
      using errcode = '42501';
  end if;
  update public.invoice_transmissions
    set phase = p_outcome, resolved_by = p_actor,
        resolved_reason = left(trim(p_reason), 300),
        resolved_evidence = left(trim(p_evidence), 1000),
        resolved_at = now(), detail = 'resolved_manually'
    where id = p_id and phase = 'uncertain'
    returning * into v_row;
  if not found then
    select * into v_row from public.invoice_transmissions where id = p_id;
    return jsonb_build_object('resolved', false, 'phase', v_row.phase);
  end if;
  return jsonb_build_object('resolved', true, 'phase', v_row.phase);
end;
$fn$;

-- ── 7. who may call ──────────────────────────────────────────────────
-- Only the Edge Function (service role) reaches these; the handler checks
-- who is asking before it calls, and resolve re-checks the actor itself.
revoke all on table public.invoice_transmission_artifacts
  from public, anon, authenticated;
revoke execute on function public.prepare_einvoice_v1(uuid, uuid, text, text, text, uuid, text, text, text, text, text, text, text, bytea)
  from public, anon, authenticated;
grant execute on function public.prepare_einvoice_v1(uuid, uuid, text, text, text, uuid, text, text, text, text, text, text, text, bytea) to service_role;
revoke execute on function public.expire_einvoice_dispatches_v1(uuid)
  from public, anon, authenticated;
grant execute on function public.expire_einvoice_dispatches_v1(uuid) to service_role;
revoke execute on function public.claim_einvoice_dispatch_v1(uuid, uuid, integer)
  from public, anon, authenticated;
grant execute on function public.claim_einvoice_dispatch_v1(uuid, uuid, integer) to service_role;
revoke execute on function public.record_einvoice_outcome_v1(uuid, integer, uuid, text, text, text, jsonb)
  from public, anon, authenticated;
grant execute on function public.record_einvoice_outcome_v1(uuid, integer, uuid, text, text, text, jsonb) to service_role;
revoke execute on function public.record_einvoice_lookup_v1(uuid, text, text, jsonb, jsonb, text)
  from public, anon, authenticated;
grant execute on function public.record_einvoice_lookup_v1(uuid, text, text, jsonb, jsonb, text) to service_role;
revoke execute on function public.resolve_einvoice_manually_v1(uuid, uuid, text, text, text)
  from public, anon, authenticated;
grant execute on function public.resolve_einvoice_manually_v1(uuid, uuid, text, text, text) to service_role;
revoke execute on function public.invoice_transmissions_sync_phase()
  from public, anon, authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(689);
