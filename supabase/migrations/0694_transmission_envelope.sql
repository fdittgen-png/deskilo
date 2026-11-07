-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (prepare_einvoice_v1 is restated whole from its live definition with one
-- defaulted parameter and one envelope write, and its old fourteen-argument
-- signature is dropped, so its callers keep working through the default;
-- record_provenance and invoice_provenance_stamp are restated whole)
--
-- #3336 (slice 3) -- the transmission envelope, and what a client may say about
-- itself.
--
--  * prepare_einvoice_v1 (the one preparation writer, 0689) writes the
--    'transmission' envelope on the `prepared` insert only: a replay or a
--    conflict never reaches it, and the dispatch generations, outcomes and the
--    manual resolution stay facts on the transmission row. The envelope is never
--    touched after, so a state change of the capability (0692) leaves it as it
--    was and a late outcome still lands on the admitted attempt.
--  * What the client declares about its renderer (`p_declared`) is clipped in
--    ONE place, record_provenance: only the keys renderer, renderer_version,
--    app_version and format survive, and only string values of at most 120
--    characters -- a non-string is dropped, never coerced -- and a declaration of
--    more than 4096 bytes is refused (22023). It stays in `declared`, apart from
--    the server-established `issuer` and `artifacts`.
--  * Review of 0693: the invoice's rule day is the workspace's LOCAL day
--    (book_local_day), not the UTC date.

-- ── what a client may declare ──────────────────────────────────────────
create or replace function public.provenance_clip_declared(p_declared jsonb)
returns jsonb language sql immutable set search_path = public as $fn$
  select coalesce(jsonb_object_agg(x.k, x.v), '{}'::jsonb)
    from (select e.key as k, to_jsonb(left(e.value #>> '{}', 120)) as v
            from jsonb_each(case when jsonb_typeof(p_declared) = 'object'
                                 then p_declared else '{}'::jsonb end) e
           where e.key in ('renderer', 'renderer_version', 'app_version', 'format')
             and jsonb_typeof(e.value) = 'string') x
$fn$;
revoke execute on function public.provenance_clip_declared(jsonb) from public, anon, authenticated;

-- ── the one writer, with the declaration clipped and capped ─────────────
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
  if pg_column_size(coalesce(p_declared, '{}'::jsonb)) > 4096 then
    raise exception 'the declared provenance is too large' using errcode = '22023';
  end if;
  insert into public.provenance_envelopes
    (workspace_id, result_kind, result_id, module_id, module_version, input_schema,
     rule_revision, issuer, declared, artifacts)
  values (p_workspace_id, p_kind, p_result_id, v_mod ->> 'module_id', v_mod ->> 'module_version',
          v_mod ->> 'input_schema', coalesce(p_rule_revision, '{"status": "unknown"}'::jsonb),
          coalesce(p_issuer, '{}'::jsonb), public.provenance_clip_declared(p_declared),
          coalesce(p_artifacts, '{}'::jsonb))
  on conflict (result_kind, result_id) do nothing;
end;
$fn$;
revoke execute on function public.record_provenance(uuid, text, uuid, jsonb, jsonb, jsonb, jsonb)
  from public, anon, authenticated;

-- ── the invoice hook: the rule day is the workspace's local day ─────────
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
  v_day := public.book_local_day(new.workspace_id, coalesce(new.issued_at, now()));
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

-- ── the preparation writer of 0689, with its envelope ──────────────────
drop function if exists public.prepare_einvoice_v1(uuid, uuid, text, text, text, uuid, text, text, text, text, text, text, text, bytea);
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
    where business_key = v_key;
  if v_row.binding_hash is distinct from v_binding then
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

select public.set_deskilo_schema_version(694);
