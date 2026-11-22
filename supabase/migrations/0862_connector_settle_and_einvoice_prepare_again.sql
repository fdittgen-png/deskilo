-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (claim_einvoice_dispatch_v1 gains a defaulted binding and is restated whole; accounting_connection_manageable_v1, hmrc_actor, hmrc_connection_manageable_v1 and
--  revoke_hmrc_connection_v1 are patched at asserted anchors of their live definitions; hmrc_actor and
--  hmrc_connection_manageable_v1 gain a defaulted purpose, so their one-argument signatures are dropped;
--  prepare_einvoice_v1 is restated whole)
--
-- Connectors and e-invoice transmissions.
--
--   * A delivery that already exists is settled while the connectors are in servicing. The manageable
--     door takes a purpose `settle`: the member and the right, not the capability, as for `revoke`.
--     A new delivery is still refused where it is written (record_accounting_delivery).
--   * The HMRC connection is revoked like every other connector's when mtdSubmission or
--     vatDeclarations is off: hmrc_actor takes a purpose, and `revoke` asks for the owner and nothing
--     else; the revoke function and the manageable door pass it.
--   * A claim names the binding (document, format and receiver) its caller verified and is refused
--     (`binding_changed`) when the row was prepared again with another since: a request never sends a
--     document, or to a receiver, the row no longer holds.
--   * A `prepared` or `failed` e-invoice transmission whose document or receiver changed is prepared
--     again: a new prepare replaces the stored artifact and the binding under the row's lock and
--     answers `prepared`. A `sent`, `uncertain`, `accepted` or `rejected` one keeps the conflict. The
--     first attempt's envelope stays as written; the new attempt has its own, naming the transmission
--     and its number.

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_pattern text;
  v_out text;
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  v_out := regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'), 'g');
  return case when v_out = p_def then null else v_out end;
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

-- ── a delivery under way is settled in servicing ───────────────────────
do $patch$
declare
  v_def text := pg_get_functiondef('public.accounting_connection_manageable_v1(uuid, text)'::regprocedure);
begin
  v_def := pg_temp.anchor_replace(v_def,
    $o$if coalesce(p_purpose, 'work') = 'revoke' then$o$,
    $n$if coalesce(p_purpose, 'work') in ('revoke', 'settle') then$n$);
  if v_def is null then raise exception '0862: the purpose anchor of accounting_connection_manageable_v1 is not found' using errcode = 'P0001'; end if;
  execute v_def;
end
$patch$;

-- ── HMRC: the owner revokes with the features off ──────────────────────
do $patch$
declare
  v_def text;
begin
  v_def := pg_get_functiondef('public.hmrc_actor(uuid)'::regprocedure);
  v_def := pg_temp.anchor_replace(v_def, $o$hmrc_actor(p_workspace_id uuid)$o$,
    $n$hmrc_actor(p_workspace_id uuid, p_purpose text DEFAULT 'work'::text)$n$);
  if v_def is null then raise exception '0862: the signature anchor of hmrc_actor is not found' using errcode = 'P0001'; end if;
  v_def := pg_temp.anchor_replace(v_def,
    $o$if not public.feature_effective(p_workspace_id, 'mtdSubmission')
     or not public.feature_effective(p_workspace_id, 'vatDeclarations') then$o$,
    $n$if coalesce(p_purpose, 'work') <> 'revoke'
     and (not public.feature_effective(p_workspace_id, 'mtdSubmission')
          or not public.feature_effective(p_workspace_id, 'vatDeclarations')) then$n$);
  if v_def is null then raise exception '0862: the feature anchor of hmrc_actor is not found' using errcode = 'P0001'; end if;
  v_def := pg_temp.anchor_replace(v_def,
    $o$if not exists (select 1 from public.workspaces w where w.id = p_workspace_id and upper(w.country_code) = 'GB') then$o$,
    $n$if coalesce(p_purpose, 'work') <> 'revoke'
     and not exists (select 1 from public.workspaces w where w.id = p_workspace_id and upper(w.country_code) = 'GB') then$n$);
  if v_def is null then raise exception '0862: the country anchor of hmrc_actor is not found' using errcode = 'P0001'; end if;
  drop function public.hmrc_actor(uuid);
  execute v_def;

  v_def := pg_get_functiondef('public.hmrc_connection_manageable_v1(uuid)'::regprocedure);
  v_def := pg_temp.anchor_replace(v_def, $o$hmrc_connection_manageable_v1(p_connection_id uuid)$o$,
    $n$hmrc_connection_manageable_v1(p_connection_id uuid, p_purpose text DEFAULT 'work'::text)$n$);
  if v_def is null then raise exception '0862: the signature anchor of hmrc_connection_manageable_v1 is not found' using errcode = 'P0001'; end if;
  v_def := pg_temp.anchor_replace(v_def, $o$perform public.hmrc_actor(c.workspace_id);$o$,
    $n$perform public.hmrc_actor(c.workspace_id, coalesce(p_purpose, 'work'));$n$);
  if v_def is null then raise exception '0862: the actor anchor of hmrc_connection_manageable_v1 is not found' using errcode = 'P0001'; end if;
  drop function public.hmrc_connection_manageable_v1(uuid);
  execute v_def;

  v_def := pg_get_functiondef('public.revoke_hmrc_connection_v1(uuid)'::regprocedure);
  v_def := pg_temp.anchor_replace(v_def, $o$perform public.hmrc_actor(c.workspace_id);$o$,
    $n$perform public.hmrc_actor(c.workspace_id, 'revoke');$n$);
  if v_def is null then raise exception '0862: the actor anchor of revoke_hmrc_connection_v1 is not found' using errcode = 'P0001'; end if;
  execute v_def;
end
$patch$;
revoke execute on function public.hmrc_actor(uuid, text) from public, anon, authenticated;
revoke execute on function public.hmrc_connection_manageable_v1(uuid, text) from public, anon;
grant execute on function public.hmrc_connection_manageable_v1(uuid, text) to authenticated;

-- ── the claim is of the document the caller verified ──────────────────
-- A claim that names the binding it verified is refused (`binding_changed`) when the row has been prepared
-- again with another document or receiver since: no request sends what the row no longer holds.
drop function if exists public.claim_einvoice_dispatch_v1(uuid, uuid, integer);

-- restates 0689
create or replace function public.claim_einvoice_dispatch_v1(
  p_id uuid, p_owner uuid, p_window_seconds integer, p_binding text default null
) returns jsonb language plpgsql security definer set search_path = public
as $fn$
declare
  v_row public.invoice_transmissions;
begin
  if p_window_seconds is null or p_window_seconds <= 0 then
    raise exception 'a dispatch window is required' using errcode = '22023';
  end if;
  update public.invoice_transmissions set phase = 'uncertain'
    where id = p_id and phase = 'sent' and deadline < now();
  -- only a record that provably never dispatched (prepared) or whose
  -- failure proved no acceptance (failed) may be claimed
  update public.invoice_transmissions
    set phase = 'sent', owner_id = p_owner, generation = generation + 1,
        deadline = now() + make_interval(secs => p_window_seconds)
    where id = p_id and phase in ('prepared', 'failed')
      -- the claim is of the document and receiver the caller verified (0862)
      and (p_binding is null or binding_hash = p_binding)
    returning * into v_row;
  if found then
    return jsonb_build_object('claimed', true, 'phase', 'sent',
      'generation', v_row.generation);
  end if;
  select * into v_row from public.invoice_transmissions where id = p_id;
  if v_row.phase in ('prepared', 'failed') and p_binding is not null
     and v_row.binding_hash is distinct from p_binding then
    return jsonb_build_object('claimed', false, 'phase', v_row.phase, 'detail', 'binding_changed');
  end if;
  return jsonb_build_object('claimed', false, 'phase', v_row.phase,
    'external_id', v_row.external_id, 'detail', v_row.detail);
end;
$fn$;
revoke execute on function public.claim_einvoice_dispatch_v1(uuid, uuid, integer, text)
  from public, anon, authenticated;
grant execute on function public.claim_einvoice_dispatch_v1(uuid, uuid, integer, text) to service_role;

-- ── a prepared or failed transmission is prepared again ────────────────
-- restates 0694
CREATE OR REPLACE FUNCTION public.prepare_einvoice_v1(p_workspace_id uuid, p_invoice_id uuid, p_provider text, p_destination text, p_environment text, p_actor uuid, p_by_name text, p_format text, p_hash text, p_file_name text, p_mime_type text, p_receiver_scheme text, p_receiver_id text, p_bytes bytea, p_declared jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
    -- #3336 -- how this transmission was prepared, written once with the
    -- record: what the server established, and what the client declared about
    -- its renderer apart from it. Replays and conflicts never reach this line.
    perform public.record_provenance(p_workspace_id, 'transmission', v_id,
      jsonb_build_object('actor_user_id', p_actor, 'provider', p_provider,
                         'destination', p_destination, 'environment', p_environment,
                         'business_key', v_key),
      p_declared,
      jsonb_build_object('sha256', p_hash, 'format', p_format,
                         'bytes', octet_length(p_bytes),
                         'receiver_scheme', coalesce(p_receiver_scheme, ''),
                         'receiver_given', coalesce(p_receiver_id, '') <> ''));
    return jsonb_build_object('outcome', 'prepared', 'id', v_id,
      'phase', 'prepared');
  end if;

  select * into v_row from public.invoice_transmissions
    where business_key = v_key for update;
  if v_row.binding_hash is distinct from v_binding then
    -- Nothing left the system from a `prepared` or a `failed` row: the document or the receiver
    -- that changed since replaces what was stored, under the row's lock, and the row is prepared
    -- again. A row that was sent, is uncertain or was answered keeps the conflict.
    if v_row.phase in ('prepared', 'failed') then
      update public.invoice_transmission_artifacts
         set bytes = p_bytes, sha256 = p_hash, file_name = coalesce(p_file_name, ''),
             mime_type = coalesce(p_mime_type, 'application/pdf'),
             receiver_scheme = coalesce(p_receiver_scheme, ''), receiver_id = coalesce(p_receiver_id, '')
       where transmission_id = v_row.id;
      update public.invoice_transmissions
         set phase = 'prepared', document_hash = p_hash, format = p_format, binding_hash = v_binding,
             by_name = coalesce(p_by_name, ''), requested_by = p_actor, external_id = '', detail = '',
             receipt = '{}'::jsonb, receipt_at = null, verdict = '{}'::jsonb, query_error = '',
             owner_id = null, deadline = null
       where id = v_row.id;
      -- the first attempt's envelope stays as it was written; this attempt has its own
      perform public.record_provenance(p_workspace_id, 'transmission', gen_random_uuid(),
        jsonb_build_object('actor_user_id', p_actor, 'provider', p_provider,
                           'destination', p_destination, 'environment', p_environment,
                           'business_key', v_key, 'transmission_id', v_row.id,
                           'attempt', 1 + (select count(*) from public.provenance_envelopes e
                                            where e.workspace_id = p_workspace_id
                                              and e.issuer ->> 'transmission_id' = v_row.id::text)),
        p_declared,
        jsonb_build_object('sha256', p_hash, 'format', p_format,
                           'bytes', octet_length(p_bytes),
                           'receiver_scheme', coalesce(p_receiver_scheme, ''),
                           'receiver_given', coalesce(p_receiver_id, '') <> ''));
      return jsonb_build_object('outcome', 'prepared', 'id', v_row.id, 'phase', 'prepared');
    end if;
    return jsonb_build_object('outcome', 'conflict', 'id', v_row.id,
      'phase', v_row.phase, 'detail', 'binding_changed');
  end if;
  return jsonb_build_object('outcome', 'existing', 'id', v_row.id,
    'phase', v_row.phase, 'external_id', v_row.external_id,
    'detail', v_row.detail);
end;
$function$;

revoke execute on function public.prepare_einvoice_v1(uuid, uuid, text, text, text, uuid, text, text, text, text, text, text, text, bytea, jsonb)
  from public, anon, authenticated;
grant execute on function public.prepare_einvoice_v1(uuid, uuid, text, text, text, uuid, text, text, text, text, text, text, text, bytea, jsonb)
  to service_role;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(862);
