-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (record_accounting_delivery, record_book_export_v1 and record_file_deliveries_v1
-- are restated whole from their live definitions with one envelope write each;
-- record_book_export_v1 gains one defaulted parameter and its old signature is
-- dropped, so its callers keep working through the default)
--
-- #3336 (slice 2b) -- the provenance envelope: what a durable result can truthfully
-- say about how it was produced, written once with the result.
--
--  * provenance_modules() is the single registry of what produces what: every
--    result_kind the table accepts has an entry, with its module id, version and
--    input schema (a lint pins the two lists together).
--  * provenance_envelopes holds ONE row per durable result (result_kind, result_id),
--    insert-only: no update, and no delete except with its workspace. It is a
--    separate table, so the invoice row, its whole-row immutability guard and its
--    legal-snapshot fingerprint are untouched. A result with no envelope reads
--    `legacy_unknown`; nothing is backfilled.
--  * The server writes what the server established (`issuer`, `rule_revision`,
--    `artifacts`); what a client says about itself goes in `declared` and is never
--    promoted to proof. A missing tax reference or module entry is an explicit
--    'unknown', never an error: stamping must not change which results can exist.
--  * Invoices: ONE AFTER INSERT trigger, so it sees the legal snapshot and the
--    frozen QRR the BEFORE hooks produced, for every issuing path
--    (create_invoice_receipted_v1, replacement, settlement, guest passes) without
--    restating any of them. A replay returns the existing invoice: no second row.
--  * Exports, file deliveries and accounting deliveries write theirs at their
--    first durable boundary (see the functions below).
-- The e-invoice transmission envelope belongs to the next slice (it consumes the
-- 0689 writer).


-- ── the registry ─────────────────────────────────────────────────────────
create or replace function public.provenance_modules()
returns jsonb language sql immutable set search_path = public as $fn$
  select jsonb_build_object(
    'invoice',             jsonb_build_object('module_id', 'invoice.issue',         'module_version', '1', 'input_schema', 'invoice-legal-snapshot/1'),
    'book_export',         jsonb_build_object('module_id', 'book.export',           'module_version', '1', 'input_schema', 'book-export/1'),
    'file_delivery',       jsonb_build_object('module_id', 'book.file-delivery',    'module_version', '1', 'input_schema', 'file-delivery/1'),
    'accounting_delivery', jsonb_build_object('module_id', 'accounting.delivery',   'module_version', '1', 'input_schema', 'accounting-delivery/1'),
    'transmission',        jsonb_build_object('module_id', 'einvoice.transmission', 'module_version', '1', 'input_schema', 'einvoice-transmission/1'))
$fn$;
revoke execute on function public.provenance_modules() from public, anon;
grant execute on function public.provenance_modules() to authenticated;

-- ── the table ────────────────────────────────────────────────────────────
create table if not exists public.provenance_envelopes (
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  result_kind text not null
    check (result_kind in ('invoice', 'book_export', 'file_delivery', 'accounting_delivery', 'transmission')),
  result_id uuid not null,
  module_id text not null,
  module_version text not null,
  input_schema text not null,
  rule_revision jsonb not null default '{"status": "unknown"}'::jsonb,
  issuer jsonb not null default '{}'::jsonb,
  declared jsonb not null default '{}'::jsonb,
  artifacts jsonb not null default '{}'::jsonb,
  produced_at timestamptz not null default now(),
  primary key (result_kind, result_id)
);
select public.ensure_system_columns('provenance_envelopes');
create index if not exists provenance_envelopes_workspace on public.provenance_envelopes (workspace_id);

alter table public.provenance_envelopes enable row level security;
revoke all on public.provenance_envelopes from public, anon, authenticated;
grant select on public.provenance_envelopes to authenticated;
drop policy if exists provenance_envelopes_select on public.provenance_envelopes;
create policy provenance_envelopes_select on public.provenance_envelopes
  for select to authenticated using (public.accounting_reader(workspace_id));
drop policy if exists mcp_delegated_deny on public.provenance_envelopes;
create policy mcp_delegated_deny on public.provenance_envelopes as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- insert-only: an update never, a delete only with its workspace
create or replace function public.provenance_envelopes_immutable()
returns trigger language plpgsql set search_path = public as $fn$
begin
  if tg_op = 'DELETE' and not exists (select 1 from public.workspaces w where w.id = old.workspace_id) then
    return old;
  end if;
  raise exception 'provenance is written once and never changed' using errcode = '23514';
end;
$fn$;
revoke execute on function public.provenance_envelopes_immutable() from public, anon, authenticated;
drop trigger if exists provenance_envelopes_immutable on public.provenance_envelopes;
create trigger provenance_envelopes_immutable
  before update or delete on public.provenance_envelopes
  for each row execute function public.provenance_envelopes_immutable();

-- ── the one writer ───────────────────────────────────────────────────────
-- Called only from the server-side producers below. The module comes from the
-- registry; an unknown kind is a programming error and raises, a missing
-- optional fact is the explicit 'unknown'. Writing twice is a no-op: the first
-- envelope of a result is the truth.
create or replace function public.record_provenance(
  p_workspace_id uuid, p_kind text, p_result_id uuid,
  p_issuer jsonb, p_declared jsonb, p_artifacts jsonb,
  p_rule_revision jsonb default null)
returns void language plpgsql security definer set search_path = public as $fn$
declare
  v_mod jsonb := public.provenance_modules() -> p_kind;
begin
  if v_mod is null then
    raise exception 'unknown provenance kind %', p_kind using errcode = '22023';
  end if;
  insert into public.provenance_envelopes
    (workspace_id, result_kind, result_id, module_id, module_version, input_schema,
     rule_revision, issuer, declared, artifacts)
  values (p_workspace_id, p_kind, p_result_id, v_mod ->> 'module_id', v_mod ->> 'module_version',
          v_mod ->> 'input_schema', coalesce(p_rule_revision, '{"status": "unknown"}'::jsonb),
          coalesce(p_issuer, '{}'::jsonb), coalesce(p_declared, '{}'::jsonb), coalesce(p_artifacts, '{}'::jsonb))
  on conflict (result_kind, result_id) do nothing;
end;
$fn$;
revoke execute on function public.record_provenance(uuid, text, uuid, jsonb, jsonb, jsonb, jsonb)
  from public, anon, authenticated;

-- ── invoices: one hook after the BEFORE hooks ───────────────────────────
-- The tax reference in force at the issue date for the workspace's country,
-- reduced to a count and a digest of its rows; none in force reads 'unknown'.
create or replace function public.invoice_provenance_stamp()
returns trigger language plpgsql security definer set search_path = public as $fn$
declare
  v_country text;
  v_day date;
  v_rows int;
  v_digest text;
  v_rule jsonb := '{"status": "unknown"}'::jsonb;
  v_snapshot_sha text;
begin
  select w.country_code into v_country from public.workspaces w where w.id = new.workspace_id;
  v_day := coalesce(new.issued_at, now())::date;
  select count(*), encode(sha256(convert_to(coalesce(string_agg(r.domain || '|' || r.country || '|' || r.key || '|' || r.valid_from::text,
                                                                ';' order by r.domain, r.country, r.key, r.valid_from), ''), 'utf8')), 'hex')
    into v_rows, v_digest
    from public.tax_reference r
   where (r.country = v_country or r.country = '*')
     and r.valid_from <= v_day and (r.valid_to is null or r.valid_to >= v_day);
  if v_rows > 0 then
    v_rule := jsonb_build_object('status', 'known', 'as_of', v_day, 'country', v_country,
                                 'rows', v_rows, 'digest', v_digest);
  end if;
  if new.legal_snapshot is not null then
    v_snapshot_sha := encode(sha256(convert_to(new.legal_snapshot::text, 'utf8')), 'hex');
  end if;
  perform public.record_provenance(new.workspace_id, 'invoice', new.id,
    jsonb_build_object('issuer_member_id', new.issuer_member_id, 'country_code', v_country,
                       'currency', new.currency, 'kind', new.kind),
    '{}'::jsonb,
    jsonb_build_object('legal_snapshot_sha256', v_snapshot_sha,
                       'qrr_frozen', coalesce(new.legal_snapshot ->> 'qrr', '') <> ''),
    v_rule);
  return null;
end;
$fn$;
revoke execute on function public.invoice_provenance_stamp() from public, anon, authenticated;
drop trigger if exists invoice_provenance_stamp on public.invoices;
create trigger invoice_provenance_stamp
  after insert on public.invoices
  for each row execute function public.invoice_provenance_stamp();

-- ── the reader ───────────────────────────────────────────────────────────
create or replace function public.provenance_envelope_v1(p_workspace_id uuid, p_kind text, p_result_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  e public.provenance_envelopes;
begin
  perform public.accounting_connector_member(p_workspace_id, 'read');
  select * into e from public.provenance_envelopes
   where workspace_id = p_workspace_id and result_kind = p_kind and result_id = p_result_id;
  if e.result_id is null then
    return jsonb_build_object('status', 'legacy_unknown');
  end if;
  return jsonb_build_object('status', 'recorded', 'result_kind', e.result_kind, 'result_id', e.result_id,
    'module_id', e.module_id, 'module_version', e.module_version, 'input_schema', e.input_schema,
    'rule_revision', e.rule_revision, 'issuer', e.issuer, 'declared', e.declared,
    'artifacts', e.artifacts, 'produced_at', e.produced_at);
end;
$fn$;
revoke execute on function public.provenance_envelope_v1(uuid, text, uuid) from public, anon;
grant execute on function public.provenance_envelope_v1(uuid, text, uuid) to authenticated;

-- ── the producers, restated whole from their live definitions ───────────
drop function if exists public.record_book_export_v1(uuid, text, date, date, text, bigint, integer, integer);
CREATE OR REPLACE FUNCTION public.record_book_export_v1(p_workspace_id uuid, p_format_id text, p_from date, p_to date, p_sha256 text, p_bytes bigint, p_rows integer, p_documents integer, p_declared jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_me uuid;
  e public.book_exports;
  v_closed boolean;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if v_me is null then raise exception 'not an active member'; end if;
  -- The client logs every accounting export it makes; a space that keeps
  -- neither accounting periods nor accounting transfers logs nothing.
  if not (public.feature_effective(p_workspace_id, 'accountingPeriods')
          or public.feature_effective(p_workspace_id, 'accountingConnectors')) then
    return jsonb_build_object('logged', false);
  end if;
  if not public.has_permission(p_workspace_id, 'exportData') then
    raise exception 'you may not export the books';
  end if;
  if p_to < p_from then raise exception 'the period ends before it starts'; end if;
  -- closed when every day of the export lies inside closed periods
  select not exists (
      select 1 from generate_series(p_from, p_to, interval '1 day') d
       where not public.book_period_closed(p_workspace_id, d::date)) into v_closed;
  insert into public.book_exports
    (workspace_id, format_id, period_from, period_to, sha256, byte_count, row_count, document_count,
     closed_period, exported_by_member_id)
  values (p_workspace_id, btrim(p_format_id), p_from, p_to, lower(p_sha256), p_bytes, p_rows, p_documents,
          v_closed, v_me)
  returning * into e;
  -- #3336 -- what this server established (the actor, the bytes' digest, the
  -- counts) beside what the client declared about its renderer, kept apart
  perform public.record_provenance(p_workspace_id, 'book_export', e.id,
    jsonb_build_object('exported_by_member_id', v_me, 'format_id', btrim(p_format_id)),
    case when jsonb_typeof(p_declared) = 'object' then p_declared else '{}'::jsonb end,
    jsonb_build_object('sha256', lower(p_sha256), 'bytes', p_bytes, 'rows', p_rows, 'documents', p_documents));
  return jsonb_build_object('logged', true, 'id', e.id, 'closed_period', e.closed_period, 'exported_at', e.exported_at);
end;
$function$;
revoke execute on function public.record_book_export_v1(uuid, text, date, date, text, bigint, integer, integer, jsonb)
  from public, anon;
grant execute on function public.record_book_export_v1(uuid, text, date, date, text, bigint, integer, integer, jsonb)
  to authenticated;

CREATE OR REPLACE FUNCTION public.record_accounting_delivery(p_connection_id uuid, p_document_kind text, p_document_id uuid, p_event_date date, p_document_number text, p_period_from date, p_period_to date, p_payload_sha256 text, p_status text, p_remote jsonb, p_error text, p_in_flight_seconds integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  c public.accounting_connections;
  d public.accounting_deliveries;
  v_identity text;
  v_remote_id text := coalesce(p_remote ->> 'id', '');
  v_status text := p_status;
  v_error text := left(coalesce(p_error, ''), 1000);
  v_outcome text;
begin
  select * into c from public.accounting_connections where id = p_connection_id;
  if c.id is null then raise exception 'unknown connection' using errcode = 'P0002'; end if;
  if p_status not in ('generated', 'sent', 'acknowledged', 'conflict', 'failed') then
    raise exception 'unknown delivery status %', p_status using errcode = '22023';
  end if;
  v_identity := 'c:' || c.id || ':' || btrim(p_document_kind) || ':' || p_document_id || ':' || p_event_date;
  select * into d from public.accounting_deliveries
   where workspace_id = c.workspace_id and identity_key = v_identity for update;
  if d.id is null and not public.capability_admits(c.workspace_id, 'accountingConnectors') then
    raise exception 'accounting connections are switched off in this space' using errcode = '0A000';
  end if;
  if d.id is null and c.remote_tenant_id <> '' then
    -- the same document, delivered by a revoked connection to the same company
    select dd.* into d from public.accounting_deliveries dd
      join public.accounting_connections pc on pc.id = dd.connection_id
     where dd.workspace_id = c.workspace_id and pc.id <> c.id and pc.revoked_at is not null
       and pc.issuer_site_id = c.issuer_site_id and pc.target_id = c.target_id
       and pc.remote_tenant_id = c.remote_tenant_id
       and dd.document_kind = btrim(p_document_kind) and dd.document_id = p_document_id
       and dd.event_date = p_event_date
     order by dd.created_datetime desc limit 1 for update of dd;
    if d.id is not null then
      update public.accounting_deliveries
         set connection_id = c.id, identity_key = v_identity
       where id = d.id
      returning * into d;
    end if;
  end if;
  if d.id is null then
    if c.revoked_at is not null or c.status <> 'connected' then
      raise exception 'this connection cannot deliver: %', c.status using errcode = '23514';
    end if;
    insert into public.accounting_deliveries
      (workspace_id, issuer_site_id, connection_id, target_id, identity_key, idempotency_key,
       period_from, period_to, document_kind, document_id, document_number, event_date,
       payload_sha256, status, error, sent_at)
    values (c.workspace_id, c.issuer_site_id, c.id, c.target_id, v_identity,
            public.accounting_idempotency_key(v_identity), p_period_from, p_period_to,
            btrim(p_document_kind), p_document_id, coalesce(p_document_number, ''), p_event_date,
            lower(p_payload_sha256), case when p_status = 'acknowledged' then 'sent' else p_status end,
            v_error, case when p_status in ('sent', 'acknowledged') then now() end)
    returning * into d;
    -- #3336 -- the context of the first durable preparation, pinned once and
    -- kept through every later outcome of this delivery
    perform public.record_provenance(c.workspace_id, 'accounting_delivery', d.id,
      jsonb_build_object('issuer_site_id', c.issuer_site_id, 'target_id', c.target_id,
                         'connection_id', c.id, 'document_kind', btrim(p_document_kind)),
      '{}'::jsonb,
      jsonb_build_object('payload_sha256', lower(p_payload_sha256)));
    if p_status <> 'acknowledged' then
      return public.accounting_delivery_json(d) || jsonb_build_object('outcome', 'created');
    end if;
  end if;
  if d.status = 'acknowledged' then
    if d.payload_sha256 = lower(p_payload_sha256) and (v_remote_id = '' or v_remote_id = d.remote_id) then
      return public.accounting_delivery_json(d) || jsonb_build_object('outcome', 'unchanged');
    end if;
    if d.payload_sha256 <> lower(p_payload_sha256) then
      raise exception 'this document was acknowledged with another content: it needs a correction, not a second delivery'
        using errcode = '23514';
    end if;
  end if;
  -- Preparing a delivery that already exists changes nothing: a send whose
  -- outcome is unknown stays so until a readback resolves it.
  if p_status = 'generated' then
    if coalesce(p_in_flight_seconds, 0) > 0 and d.status in ('generated', 'sent')
       and greatest(d.created_datetime, coalesce(d.sent_at, d.created_datetime))
           > now() - make_interval(secs => p_in_flight_seconds) then
      return public.accounting_delivery_json(d) || jsonb_build_object('outcome', 'in_flight');
    end if;
    return public.accounting_delivery_json(d) || jsonb_build_object('outcome', 'existing');
  end if;
  if v_remote_id <> '' and d.remote_id <> '' and v_remote_id <> d.remote_id then
    v_status := 'conflict';
    v_error := left('the remote holds ' || d.remote_id || ' and answered ' || v_remote_id, 1000);
  elsif v_status = 'acknowledged' and v_remote_id = '' and d.remote_id = '' then
    raise exception 'an acknowledged delivery names its remote id' using errcode = '22023';
  end if;
  update public.accounting_deliveries set
    status = v_status,
    error = case when v_status in ('conflict', 'failed') then v_error else '' end,
    payload_sha256 = lower(p_payload_sha256),
    document_number = coalesce(nullif(p_document_number, ''), document_number),
    remote_id = case when v_status = 'conflict' then remote_id else coalesce(nullif(v_remote_id, ''), remote_id) end,
    remote_number = coalesce(nullif(p_remote ->> 'number', ''), remote_number),
    remote_version = coalesce(nullif(p_remote ->> 'version', ''), remote_version),
    remote_state = coalesce(nullif(p_remote ->> 'state', ''), remote_state),
    attempts = attempts + case when v_status = 'sent' and d.status <> 'generated' then 1 else 0 end,
    sent_at = case when v_status = 'sent' then now() else sent_at end,
    acknowledged_at = case when v_status = 'acknowledged' then now() else acknowledged_at end
  where id = d.id
  returning * into d;
  v_outcome := case when v_status = 'conflict' and p_status <> 'conflict' then 'conflict' else 'updated' end;
  return public.accounting_delivery_json(d) || jsonb_build_object('outcome', v_outcome);
end;
$function$;
revoke execute on function public.record_accounting_delivery(uuid, text, uuid, date, text, date, date, text, text, jsonb, text, integer)
  from public, anon, authenticated;
grant execute on function public.record_accounting_delivery(uuid, text, uuid, date, text, date, date, text, text, jsonb, text, integer)
  to service_role;

CREATE OR REPLACE FUNCTION public.record_file_deliveries_v1(p_workspace_id uuid, p_target_id text, p_issuer_site_id uuid, p_book_export_id uuid, p_documents jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_me uuid := public.accounting_connector_actor(p_workspace_id, 'exportData');
  x public.book_exports;
  v_doc jsonb;
  v_identity text;
  v_kind text;
  v_id uuid;
  v_day date;
  d public.accounting_deliveries;
  v_sha text;
  v_created int := 0;
  v_unchanged int := 0;
  v_changed int := 0;
  v_new uuid;
begin
  select * into x from public.book_exports e where e.id = p_book_export_id and e.workspace_id = p_workspace_id;
  if x.id is null then raise exception 'unknown export of this space' using errcode = 'DKA03'; end if;
  if x.format_id <> btrim(p_target_id) then
    raise exception 'the export was written for another target' using errcode = 'DKA03';
  end if;
  if not exists (select 1 from public.sites s where s.id = p_issuer_site_id and s.workspace_id = p_workspace_id) then
    raise exception 'the issuer is not a site of this space' using errcode = 'DKA03';
  end if;
  if jsonb_typeof(p_documents) is distinct from 'array' then
    raise exception 'the documents are a list' using errcode = 'DKA03';
  end if;
  for v_doc in select value from jsonb_array_elements(p_documents) loop
    v_sha := lower(v_doc ->> 'sha256');
    -- typed before they name an identity: one uuid, one day, however written
    v_kind := btrim(v_doc ->> 'kind');
    v_id := (v_doc ->> 'id')::uuid;
    v_day := (v_doc ->> 'date')::date;
    v_identity := 'f:' || x.format_id || ':' || p_issuer_site_id || ':' || v_kind || ':' || v_id || ':' || v_day;
    -- the latest generation of the document's delivery
    select * into d from public.accounting_deliveries
     where workspace_id = p_workspace_id
       and (identity_key = v_identity or identity_key like v_identity || ':%')
     order by generation desc limit 1 for update;
    if d.id is not null and d.payload_sha256 = v_sha then
      v_unchanged := v_unchanged + 1;
      continue;
    end if;
    insert into public.accounting_deliveries
      (workspace_id, issuer_site_id, target_id, book_export_id, identity_key, idempotency_key,
       period_from, period_to, document_kind, document_id, document_number, event_date,
       payload_sha256, status, generation, recorded_by_member_id)
    values (p_workspace_id, p_issuer_site_id, x.format_id, x.id,
            case when d.id is null then v_identity else v_identity || ':' || (d.generation + 1) end,
            public.accounting_idempotency_key(v_identity), x.period_from, x.period_to,
            v_kind, v_id, coalesce(v_doc ->> 'number', ''), v_day, v_sha, 'generated',
            coalesce(d.generation + 1, 1), v_me)
    returning id into v_new;
    -- #3336 -- the delivery refers to the export it was written from and
    -- carries its own digest; a changed file is a new generation, a new row
    perform public.record_provenance(p_workspace_id, 'file_delivery', v_new,
      jsonb_build_object('book_export_id', x.id, 'target_id', x.format_id,
                         'issuer_site_id', p_issuer_site_id, 'recorded_by_member_id', v_me),
      '{}'::jsonb,
      jsonb_build_object('sha256', v_sha, 'generation', coalesce(d.generation + 1, 1)));
    if d.id is null then v_created := v_created + 1; else v_changed := v_changed + 1; end if;
  end loop;
  return jsonb_build_object('created', v_created, 'unchanged', v_unchanged, 'changed', v_changed);
end;
$function$;
revoke execute on function public.record_file_deliveries_v1(uuid, text, uuid, uuid, jsonb) from public, anon;
grant execute on function public.record_file_deliveries_v1(uuid, text, uuid, uuid, jsonb) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(693);
