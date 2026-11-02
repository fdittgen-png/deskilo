-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- A recovery acknowledgement is bound to the particular uncertain attempt.
-- Wire tokens are lowercase SHA-256 hex, domain-separated and bound to the
-- declaration, internal holder and a fresh random marker; no holder is exposed.
alter table public.hmrc_submissions
  add column recovery_marker uuid not null default gen_random_uuid();

create or replace function public.hmrc_connection_v1(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  c public.accounting_connections;
  v_vrn text;
  v_unconfirmed jsonb;
  v_markers jsonb;
begin
  perform public.hmrc_actor(p_workspace_id);
  select public.hmrc_vrn(w.vat_id) into v_vrn from public.workspaces w where w.id = p_workspace_id;
  select * into c from public.accounting_connections x
   where x.workspace_id = p_workspace_id and x.target_id = 'hmrc_mtd' and x.revoked_at is null
   order by x.created_datetime desc limit 1;
  select coalesce(jsonb_agg(s.declaration_id order by s.declaration_id), '[]'::jsonb),
         coalesce(jsonb_object_agg(s.declaration_id::text, encode(sha256(convert_to('hmrc-recovery-v1|' || s.declaration_id::text || '|' || s.holder || '|' || s.recovery_marker::text, 'UTF8')), 'hex')), '{}'::jsonb)
    into v_unconfirmed, v_markers
    from public.hmrc_submissions s
   where s.workspace_id = p_workspace_id
     and (s.state = 'unconfirmed' or (s.state = 'in_flight' and s.claim_until <= statement_timestamp()));
  return jsonb_build_object(
    'vrn', v_vrn, 'unconfirmed_declaration_ids', v_unconfirmed,
    'recovery_markers', v_markers,
    'connection', case when c.id is null then null else jsonb_build_object(
      'id', c.id, 'issuer_site_id', c.issuer_site_id, 'status', c.status,
      'status_detail', c.status_detail, 'remote_tenant_id', c.remote_tenant_id,
      'display_name', c.display_name, 'connected_at', c.connected_at,
      'token_expires_at', c.token_expires_at) end);
end;
$fn$;
revoke execute on function public.hmrc_connection_v1(uuid) from public, anon;
grant execute on function public.hmrc_connection_v1(uuid) to authenticated;

create or replace function public.claim_hmrc_submission_v2(
  p_declaration_id uuid, p_holder text, p_seconds integer, p_boxes_sha256 text,
  p_recovery_marker text
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  s public.hmrc_submissions;
  v_ws uuid;
  v_inserted uuid;
  v_until timestamptz;
begin
  if char_length(btrim(coalesce(p_holder, ''))) not between 8 and 100 then
    raise exception 'a claim holder is 8 to 100 characters' using errcode = '22023';
  end if;
  if coalesce(p_boxes_sha256, '') !~ '^[0-9a-f]{64}$' then
    raise exception 'the digest of the submitted figures is required' using errcode = '22023';
  end if;
  select workspace_id into v_ws from public.vat_declarations where id = p_declaration_id;
  if v_ws is null then raise exception 'unknown declaration' using errcode = 'P0002'; end if;
  insert into public.hmrc_submissions (declaration_id, workspace_id, boxes_sha256, state, holder, claim_until)
    values (p_declaration_id, v_ws, p_boxes_sha256, 'in_flight', p_holder, clock_timestamp())
    on conflict (declaration_id) do nothing returning declaration_id into v_inserted;
  if v_inserted is not null then
    update public.hmrc_submissions
       set claim_until = clock_timestamp() + make_interval(secs => least(greatest(coalesce(p_seconds, 30), 5), 120))
     where declaration_id = p_declaration_id;
    return jsonb_build_object('claimed', true);
  end if;
  select * into s from public.hmrc_submissions where declaration_id = p_declaration_id for update;
  if not found then return jsonb_build_object('claimed', false, 'state', 'in_flight'); end if;
  if s.state = 'accepted' and s.boxes_sha256 <> p_boxes_sha256 then
    return jsonb_build_object('claimed', false, 'state', 'accepted_for_other_figures');
  end if;
  if s.state = 'accepted' then
    return jsonb_build_object('claimed', false, 'state', 'accepted',
      'form_bundle_number', s.form_bundle_number, 'processing_date', s.processing_date,
      'charge_ref_number', s.charge_ref_number);
  end if;
  if s.state = 'in_flight' and s.claim_until > clock_timestamp() then
    return jsonb_build_object('claimed', false, 'state', 'in_flight');
  end if;
  if p_recovery_marker is distinct from encode(sha256(convert_to('hmrc-recovery-v1|' || s.declaration_id::text || '|' || s.holder || '|' || s.recovery_marker::text, 'UTF8')), 'hex') or s.holder = p_holder then
    return jsonb_build_object('claimed', false, 'state', 'unconfirmed');
  end if;
  v_until := clock_timestamp() + make_interval(secs => least(greatest(coalesce(p_seconds, 30), 5), 120));
  update public.hmrc_submissions set state = 'in_flight', holder = p_holder, claim_until = v_until,
         boxes_sha256 = p_boxes_sha256, recovery_marker = gen_random_uuid()
   where declaration_id = p_declaration_id;
  return jsonb_build_object('claimed', true);
end;
$fn$;
revoke execute on function public.claim_hmrc_submission_v2(uuid, text, integer, text, text) from public, anon, authenticated;
grant execute on function public.claim_hmrc_submission_v2(uuid, text, integer, text, text) to service_role;

-- Older callers can submit a new return or replay a kept receipt, but cannot
-- silently reclaim an uncertain attempt without the explicit recovery marker.
create or replace function public.claim_hmrc_submission(
  p_declaration_id uuid, p_holder text, p_seconds integer, p_boxes_sha256 text
) returns jsonb language sql security definer set search_path = public as $fn$
  select public.claim_hmrc_submission_v2(p_declaration_id, p_holder, p_seconds, p_boxes_sha256, null);
$fn$;
revoke execute on function public.claim_hmrc_submission(uuid, text, integer, text) from public, anon, authenticated;
grant execute on function public.claim_hmrc_submission(uuid, text, integer, text) to service_role;

select public.set_deskilo_schema_version(652);
