-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (two nullable columns, the registry and doors of HMRC, and two anchored
-- restatements: set_accounting_credentials, mark_vat_declaration_submitted)
--
-- 0648 (#2470) -- the consumer slice of the HMRC MTD VAT submission.
--
-- 1. A per-connection LEASE before a provider refresh. HMRC's refresh tokens
--    are single-use, so two writers (the refresh action and the delivery
--    path) must never call the token endpoint for one connection at the
--    same time: the second would be refused for a token the first just spent
--    and could clear the first's newer pair. The writer that wants to refresh
--    claims the lease; everyone else waits and re-reads. A lease is a holder
--    and an expiry, so a crashed writer frees it by itself.

alter table public.accounting_connections
  add column refresh_lease_holder text,
  add column refresh_lease_until timestamptz;

-- True when [p_holder] now holds the lease of a live connection: nobody held
-- it, the previous hold ran out, or [p_holder] already held it. The hold is
-- 5 to 60 seconds.
create or replace function public.claim_accounting_refresh_lease(
  p_connection_id uuid, p_holder text, p_seconds integer
) returns boolean language plpgsql security definer set search_path = public as $fn$
declare
  v_claimed uuid;
begin
  if char_length(btrim(coalesce(p_holder, ''))) not between 8 and 100 then
    raise exception 'a lease holder is 8 to 100 characters' using errcode = '22023';
  end if;
  update public.accounting_connections c
     set refresh_lease_holder = p_holder,
         refresh_lease_until = now() + make_interval(secs => least(greatest(coalesce(p_seconds, 30), 5), 60))
   where c.id = p_connection_id and c.revoked_at is null
     and (c.refresh_lease_until is null or c.refresh_lease_until < now()
          or c.refresh_lease_holder = p_holder)
  returning c.id into v_claimed;
  return v_claimed is not null;
end;
$fn$;
revoke execute on function public.claim_accounting_refresh_lease(uuid, text, integer)
  from public, anon, authenticated;
grant execute on function public.claim_accounting_refresh_lease(uuid, text, integer) to service_role;

-- Gives the lease back; a holder that no longer holds it changes nothing.
create or replace function public.release_accounting_refresh_lease(
  p_connection_id uuid, p_holder text
) returns void language plpgsql security definer set search_path = public as $fn$
begin
  update public.accounting_connections c
     set refresh_lease_holder = null, refresh_lease_until = null
   where c.id = p_connection_id and c.refresh_lease_holder = p_holder;
end;
$fn$;
revoke execute on function public.release_accounting_refresh_lease(uuid, text)
  from public, anon, authenticated;
grant execute on function public.release_accounting_refresh_lease(uuid, text) to service_role;

-- ── the registry knows HMRC (dart run tool/build_accounting_targets_sql.dart) ──
create or replace function public.accounting_connection_targets()
returns jsonb
language sql
immutable
set search_path = public
as $$
  select '{
    "bexio_api": ["oauth2", "token"],
    "business_central_ca": ["token"],
    "business_central_ch": ["token"],
    "business_central_de": ["token"],
    "business_central_fr": ["token"],
    "business_central_gb": ["token"],
    "business_central_us": ["token"],
    "hmrc_mtd": ["oauth2"],
    "pennylane_api": ["oauth2", "token"],
    "quickbooks_online_ca": ["oauth2"],
    "quickbooks_online_gb": ["oauth2"],
    "quickbooks_online_us": ["oauth2"],
    "sage_business_cloud_ca": ["oauth2"],
    "sage_business_cloud_de": ["oauth2"],
    "sage_business_cloud_es": ["oauth2"],
    "sage_business_cloud_fr": ["oauth2"],
    "sage_business_cloud_gb": ["oauth2"],
    "sage_business_cloud_ie": ["oauth2"],
    "sage_business_cloud_us": ["oauth2"],
    "xero_ca": ["oauth2"],
    "xero_eu": ["oauth2"],
    "xero_gb": ["oauth2"],
    "xero_us": ["oauth2"]
  }'::jsonb
$$;
revoke execute on function public.accounting_connection_targets() from public, anon;
grant execute on function public.accounting_connection_targets() to authenticated, service_role;

-- ── the doors of HMRC ─────────────────────────────────────────────────────
-- The member acting for [p_workspace_id] when MTD may be used there: the
-- owner or co-owner of a GB space with mtdSubmission and vatDeclarations on.
create or replace function public.hmrc_actor(p_workspace_id uuid)
returns uuid language plpgsql stable security definer set search_path = public as $fn$
declare
  v_me public.members;
begin
  if auth.uid() is null then raise exception 'not signed in' using errcode = '42501'; end if;
  if public.mcp_is_delegated() then
    raise exception 'an assistant may not file VAT returns' using errcode = '42501';
  end if;
  select * into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if v_me.id is null or not (v_me.is_owner or coalesce(v_me.co_owner, 'none') = 'active') then
    raise exception 'only the owner files VAT declarations' using errcode = '42501';
  end if;
  if not public.feature_effective(p_workspace_id, 'mtdSubmission')
     or not public.feature_effective(p_workspace_id, 'vatDeclarations') then
    raise exception 'MTD submission is switched off in this space' using errcode = '55000';
  end if;
  if not exists (select 1 from public.workspaces w where w.id = p_workspace_id and upper(w.country_code) = 'GB') then
    raise exception 'MTD is for UK spaces' using errcode = '0A000';
  end if;
  return v_me.id;
end;
$fn$;
revoke execute on function public.hmrc_actor(uuid) from public, anon, authenticated;

-- The nine digits of a UK VAT number (GB or XI prefix, spaces and dots
-- allowed), or null.
create or replace function public.hmrc_vrn(p_vat_id text)
returns text language sql immutable set search_path = public as $fn$
  select case when d ~ '^[0-9]{9}$' then d end
    from (select regexp_replace(regexp_replace(upper(coalesce(p_vat_id, '')), '^(GB|XI)', ''), '[^0-9]', '', 'g') as d) x;
$fn$;
revoke execute on function public.hmrc_vrn(text) from public, anon, authenticated;

-- Opens the pending HMRC connection of an issuer: its VRN is the workspace's
-- VAT number, recorded as the remote tenant, so a token for another
-- registration can never be stored under it.
create or replace function public.open_hmrc_connection_v1(
  p_workspace_id uuid, p_issuer_site_id uuid, p_display_name text
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid := public.hmrc_actor(p_workspace_id);
  v_vrn text;
  c public.accounting_connections;
begin
  select public.hmrc_vrn(w.vat_id) into v_vrn from public.workspaces w where w.id = p_workspace_id;
  if v_vrn is null then
    raise exception 'the space has no valid UK VAT number' using errcode = 'DKA03';
  end if;
  if not exists (select 1 from public.sites s where s.id = p_issuer_site_id and s.workspace_id = p_workspace_id) then
    raise exception 'the issuer is not a site of this space' using errcode = 'DKA03';
  end if;
  if exists (select 1 from public.accounting_connections x
              where x.issuer_site_id = p_issuer_site_id and x.target_id = 'hmrc_mtd' and x.revoked_at is null) then
    raise exception 'this issuer is already connected to HMRC: revoke it first' using errcode = 'DKA01';
  end if;
  insert into public.accounting_connections
    (workspace_id, issuer_site_id, target_id, auth_kind, remote_tenant_id, display_name, connected_by_member_id)
  values (p_workspace_id, p_issuer_site_id, 'hmrc_mtd', 'oauth2', v_vrn,
          left(btrim(coalesce(p_display_name, '')), 120), v_me)
  returning * into c;
  return public.accounting_connection_json(c);
end;
$fn$;
revoke execute on function public.open_hmrc_connection_v1(uuid, uuid, text) from public, anon;
grant execute on function public.open_hmrc_connection_v1(uuid, uuid, text) to authenticated;

-- The caller may manage this HMRC connection (and it is still open).
create or replace function public.hmrc_connection_manageable_v1(p_connection_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  c public.accounting_connections;
begin
  select * into c from public.accounting_connections where id = p_connection_id;
  if c.id is null or c.target_id <> 'hmrc_mtd' then raise exception 'unknown connection' using errcode = 'P0002'; end if;
  perform public.hmrc_actor(c.workspace_id);
  if c.revoked_at is not null then raise exception 'this connection was revoked' using errcode = 'DKA02'; end if;
  return jsonb_build_object('id', c.id, 'workspace_id', c.workspace_id, 'target_id', c.target_id,
                            'auth_kind', c.auth_kind, 'status', c.status);
end;
$fn$;
revoke execute on function public.hmrc_connection_manageable_v1(uuid) from public, anon;
grant execute on function public.hmrc_connection_manageable_v1(uuid) to authenticated;

-- What a submission needs to know, for the caller who may file: the prepared
-- return, its period and totals, and the connected registration bound to the
-- workspace's own VAT number. Nothing is returned for a return already filed
-- or changed since it was prepared.
create or replace function public.hmrc_filing_context_v1(p_declaration_id uuid, p_connection_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  d public.vat_declarations;
  c public.accounting_connections;
  v_vrn text;
  v_sum record;
begin
  select * into d from public.vat_declarations where id = p_declaration_id;
  if d.id is null then raise exception 'unknown declaration' using errcode = 'P0002'; end if;
  perform public.hmrc_actor(d.workspace_id);
  if d.status <> 'prepared' then
    raise exception 'prepare the return before filing it (or it is filed already)' using errcode = 'DKA03';
  end if;
  select * into c from public.accounting_connections where id = p_connection_id;
  if c.id is null or c.workspace_id <> d.workspace_id or c.target_id <> 'hmrc_mtd'
     or c.revoked_at is not null or c.status <> 'connected' then
    raise exception 'connect HMRC first' using errcode = 'DKA02';
  end if;
  select public.hmrc_vrn(w.vat_id) into v_vrn from public.workspaces w where w.id = d.workspace_id;
  if v_vrn is null or c.remote_tenant_id is distinct from v_vrn then
    raise exception 'the connection is for another VAT registration' using errcode = 'DKA03';
  end if;
  if public.vat_period_overlaps_filed(d.workspace_id, d.period_start, d.period_end) then
    raise exception 'this period overlaps a filed return: its changes are declared as corrections of the next period' using errcode = 'DKA03';
  end if;
  select * into v_sum from public.vat_return_summary(d.workspace_id, d.period_start, d.period_end);
  if (v_sum.lines, v_sum.total_net_cents, v_sum.total_vat_cents, v_sum.invoice_count)
     is distinct from (d.lines, d.total_net_cents, d.total_vat_cents, d.invoice_count) then
    raise exception 'the period changed since this return was prepared: prepare it again' using errcode = 'DKA03';
  end if;
  return jsonb_build_object('declaration_id', d.id, 'workspace_id', d.workspace_id,
    'period_start', d.period_start, 'period_end', d.period_end,
    'total_vat_cents', d.total_vat_cents, 'lines', d.lines, 'vrn', v_vrn, 'connection_id', c.id);
end;
$fn$;
revoke execute on function public.hmrc_filing_context_v1(uuid, uuid) from public, anon;
grant execute on function public.hmrc_filing_context_v1(uuid, uuid) to authenticated;

-- Revokes an HMRC connection: its own door (owner or co-owner, MTD's flag),
-- the same local clearing as any connection. HMRC documents no revocation
-- endpoint, so the revocation is local only and the screen says so.
create or replace function public.revoke_hmrc_connection_v1(p_connection_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  c public.accounting_connections;
begin
  select * into c from public.accounting_connections where id = p_connection_id for update;
  if c.id is null or c.target_id <> 'hmrc_mtd' then raise exception 'unknown connection' using errcode = 'P0002'; end if;
  perform public.hmrc_actor(c.workspace_id);
  if c.revoked_at is not null then return public.accounting_connection_json(c); end if;
  perform public.clear_accounting_credentials(c.id);
  update public.accounting_connections
     set status = 'revoked', status_detail = '', revoked_at = now()
   where id = c.id
  returning * into c;
  return public.accounting_connection_json(c);
end;
$fn$;
revoke execute on function public.revoke_hmrc_connection_v1(uuid) from public, anon;
grant execute on function public.revoke_hmrc_connection_v1(uuid) to authenticated;

-- The token writer for a refresh: refuses (55P03) a writer that no longer
-- holds a live lease on the connection, so a refresh that ran past its lease
-- cannot overwrite the pair a later holder stored.
create or replace function public.set_accounting_credentials_leased(
  p_connection_id uuid, p_holder text, p_secrets jsonb, p_patch jsonb
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  c public.accounting_connections;
begin
  select * into c from public.accounting_connections where id = p_connection_id for update;
  if c.id is null then raise exception 'unknown connection' using errcode = 'P0002'; end if;
  if c.refresh_lease_holder is distinct from p_holder or c.refresh_lease_until is null
     or c.refresh_lease_until < now() then
    raise exception 'the refresh lease of this connection is no longer yours' using errcode = '55P03';
  end if;
  return public.set_accounting_credentials(p_connection_id, p_secrets, p_patch);
end;
$fn$;
revoke execute on function public.set_accounting_credentials_leased(uuid, text, jsonb, jsonb)
  from public, anon, authenticated;
grant execute on function public.set_accounting_credentials_leased(uuid, text, jsonb, jsonb) to service_role;

-- The target of a connection, without its secrets: the edge function asks
-- which door to use BEFORE it decrypts anything.
create or replace function public.accounting_connection_target_v1(p_connection_id uuid)
returns text language sql stable security definer set search_path = public as $fn$
  select c.target_id from public.accounting_connections c where c.id = p_connection_id;
$fn$;
revoke execute on function public.accounting_connection_target_v1(uuid) from public, anon, authenticated;
grant execute on function public.accounting_connection_target_v1(uuid) to service_role;

-- ── one submission to HMRC at a time per return, and the receipt kept ─────
-- A return is submitted by ONE caller at a time (a double tap is `in_flight`),
-- and once HMRC accepted it the receipt is kept here BEFORE the local filing
-- is attempted, so a failed local write never loses it: the next attempt
-- files the kept receipt and posts nothing.
create table public.hmrc_submissions (
  declaration_id uuid primary key references public.vat_declarations(id) on delete restrict,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  -- the figures this submission is for: a re-prepared return with other
  -- lines never inherits an earlier acceptance
  boxes_sha256 text not null check (boxes_sha256 ~ '^[0-9a-f]{64}$'),
  state text not null check (state in ('in_flight', 'accepted', 'unconfirmed')),
  holder text not null check (char_length(holder) between 8 and 100),
  claim_until timestamptz not null,
  form_bundle_number text not null default '' check (char_length(form_bundle_number) <= 100),
  processing_date text not null default '' check (char_length(processing_date) <= 60),
  charge_ref_number text not null default '' check (char_length(charge_ref_number) <= 100),
  check ((state = 'accepted') = (form_bundle_number <> ''))
);
select public.ensure_system_columns('hmrc_submissions');
alter table public.hmrc_submissions enable row level security;
revoke all on public.hmrc_submissions from public, anon, authenticated;
-- House pattern: a delegated (assistant) token never reaches the filing record.
create policy mcp_delegated_deny on public.hmrc_submissions as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- {claimed: true} when [p_holder] may post; otherwise {claimed: false, state}
-- with the kept receipt when HMRC already accepted it. An earlier attempt
-- whose outcome is unknown (unconfirmed, or a claim that ran out) may be
-- tried again: HMRC refuses a duplicate by its own code.
create or replace function public.claim_hmrc_submission(
  p_declaration_id uuid, p_holder text, p_seconds integer, p_boxes_sha256 text
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  s public.hmrc_submissions;
  v_ws uuid;
  v_until timestamptz := now() + make_interval(secs => least(greatest(coalesce(p_seconds, 30), 5), 120));
begin
  if char_length(btrim(coalesce(p_holder, ''))) not between 8 and 100 then
    raise exception 'a claim holder is 8 to 100 characters' using errcode = '22023';
  end if;
  if coalesce(p_boxes_sha256, '') !~ '^[0-9a-f]{64}$' then
    raise exception 'the digest of the submitted figures is required' using errcode = '22023';
  end if;
  select workspace_id into v_ws from public.vat_declarations where id = p_declaration_id;
  if v_ws is null then raise exception 'unknown declaration' using errcode = 'P0002'; end if;
  select * into s from public.hmrc_submissions where declaration_id = p_declaration_id for update;
  if s.declaration_id is null then
    insert into public.hmrc_submissions (declaration_id, workspace_id, boxes_sha256, state, holder, claim_until)
    values (p_declaration_id, v_ws, p_boxes_sha256, 'in_flight', p_holder, v_until);
    return jsonb_build_object('claimed', true);
  end if;
  if s.state = 'accepted' and s.boxes_sha256 <> p_boxes_sha256 then
    -- HMRC took an earlier version of this return: its receipt is not this one's.
    return jsonb_build_object('claimed', false, 'state', 'accepted_for_other_figures');
  end if;
  if s.state = 'accepted' then
    return jsonb_build_object('claimed', false, 'state', 'accepted',
      'form_bundle_number', s.form_bundle_number, 'processing_date', s.processing_date,
      'charge_ref_number', s.charge_ref_number);
  end if;
  if s.state = 'in_flight' and s.claim_until > now() and s.holder <> p_holder then
    return jsonb_build_object('claimed', false, 'state', 'in_flight');
  end if;
  update public.hmrc_submissions set state = 'in_flight', holder = p_holder, claim_until = v_until,
         boxes_sha256 = p_boxes_sha256
   where declaration_id = p_declaration_id;
  return jsonb_build_object('claimed', true);
end;
$fn$;
revoke execute on function public.claim_hmrc_submission(uuid, text, integer, text) from public, anon, authenticated;
grant execute on function public.claim_hmrc_submission(uuid, text, integer, text) to service_role;

-- HMRC accepted: keep the receipt (only the holder of the claim may).
create or replace function public.record_hmrc_acceptance(
  p_declaration_id uuid, p_holder text, p_form_bundle text, p_processing_date text, p_charge_ref text
) returns void language plpgsql security definer set search_path = public as $fn$
begin
  update public.hmrc_submissions
     set state = 'accepted', form_bundle_number = left(btrim(coalesce(p_form_bundle, '')), 100),
         processing_date = left(coalesce(p_processing_date, ''), 60),
         charge_ref_number = left(coalesce(p_charge_ref, ''), 100)
   where declaration_id = p_declaration_id and holder = p_holder and state = 'in_flight'
     and btrim(coalesce(p_form_bundle, '')) <> '';
  if not found then
    raise exception 'this submission is no longer yours' using errcode = '55P03';
  end if;
end;
$fn$;
revoke execute on function public.record_hmrc_acceptance(uuid, text, text, text, text) from public, anon, authenticated;
grant execute on function public.record_hmrc_acceptance(uuid, text, text, text, text) to service_role;

-- The attempt ended without a receipt. Nothing was sent (p_sent false): the
-- claim is deleted. Something was sent and the outcome is unknown: it stays
-- `unconfirmed` for the next attempt and the person's check at HMRC.
create or replace function public.release_hmrc_submission(
  p_declaration_id uuid, p_holder text, p_sent boolean
) returns void language plpgsql security definer set search_path = public as $fn$
begin
  if p_sent then
    update public.hmrc_submissions set state = 'unconfirmed'
     where declaration_id = p_declaration_id and holder = p_holder and state = 'in_flight';
  else
    delete from public.hmrc_submissions
     where declaration_id = p_declaration_id and holder = p_holder and state = 'in_flight';
  end if;
end;
$fn$;
revoke execute on function public.release_hmrc_submission(uuid, text, boolean) from public, anon, authenticated;
grant execute on function public.release_hmrc_submission(uuid, text, boolean) to service_role;

-- ── anchored patches (pg_temp.anchor_replace) ─────────────────────────────
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_count integer;
  v_pattern text;
begin
  -- Exactly one occurrence, or the patch stops: a restatement that changed
  -- two places, or none, is never silently written.
  v_count := (char_length(p_def) - char_length(replace(p_def, p_old, ''))) / greatest(char_length(p_old), 1);
  if v_count = 1 then
    return replace(p_def, p_old, p_new);
  end if;
  if v_count > 1 then
    raise exception 'anchor occurs % times: %', v_count, left(p_old, 80);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  select count(*) into v_count from regexp_matches(p_def, v_pattern, 'g');
  if v_count <> 1 then
    raise exception 'anchor occurs % times (whitespace-tolerant): %', v_count, left(p_old, 80);
  end if;
  return regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'));
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $migration$
declare
  v_def text;
  v_sig text;
begin
  -- The token writer checks the flag of the connection's own target.
  select pg_get_functiondef('public.set_accounting_credentials(uuid,jsonb,jsonb)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$if not public.feature_effective(c.workspace_id, 'accountingConnectors') then$a$,
    $a$if not public.feature_effective(c.workspace_id,
         case when c.target_id = 'hmrc_mtd' then 'mtdSubmission' else 'accountingConnectors' end) then$a$);
  if v_def is null then raise exception '0648: set_accounting_credentials anchor missing'; end if;
  execute v_def;

  -- The generic accounting doors never open, manage or revoke an HMRC
  -- connection: it has its own doors above (owner right, MTD's flag, VRN).
  select pg_get_functiondef('public.open_accounting_connection_v1(uuid,uuid,text,text,text)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$if v_ways is null then$a$,
    $a$if v_ways is null or btrim(coalesce(p_target_id, '')) = 'hmrc_mtd' then$a$);
  if v_def is null then raise exception '0648: open_accounting_connection_v1 anchor missing'; end if;
  execute v_def;
  for v_sig in select unnest(array[
      'public.accounting_connection_manageable_v1(uuid)',
      'public.revoke_accounting_connection_v1(uuid)',
      'public.save_accounting_map_v1(uuid,text,text,text,text,text)']) loop
    select pg_get_functiondef(v_sig::regprocedure) into v_def;
    v_def := pg_temp.anchor_replace(v_def,
      $a$perform public.accounting_connector_actor(c.workspace_id, 'manageBilling');$a$,
      $a$if c.target_id = 'hmrc_mtd' then raise exception 'an HMRC connection has its own doors' using errcode = '22023'; end if;
  perform public.accounting_connector_actor(c.workspace_id, 'manageBilling');$a$);
    execute v_def;
  end loop;
  -- a map belongs to a connection: its delete door looks the connection up.
  select pg_get_functiondef('public.delete_accounting_map_v1(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$perform public.accounting_connector_actor(m.workspace_id, 'manageBilling');$a$,
    $a$if exists (select 1 from public.accounting_connections k where k.id = m.connection_id and k.target_id = 'hmrc_mtd') then
    raise exception 'an HMRC connection has its own doors' using errcode = '22023';
  end if;
  perform public.accounting_connector_actor(m.workspace_id, 'manageBilling');$a$);
  execute v_def;

  -- The channel hmrc_mtd is accepted only inside the HMRC wrapper below.
  select pg_get_functiondef('public.mark_vat_declaration_submitted(uuid,text,text)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$if coalesce(p_channel, '') not in ('manual', 'export') then$a$,
    $a$if coalesce(p_channel, '') not in ('manual', 'export')
     and not (p_channel = 'hmrc_mtd'
              and coalesce(current_setting('deskilo.hmrc_filing', true), '') = p_declaration_id::text) then$a$);
  if v_def is null then raise exception '0648: mark_vat_declaration_submitted anchor missing'; end if;
  execute v_def;
end
$migration$;

-- Files the prepared return as HMRC's: the edge function calls this (service
-- role) only AFTER HMRC returned a receipt. The actor must be an owner or
-- co-owner of the declaration's space and MTD must be on there; the whole
-- ordinary filing (period lock, entries, number) then runs as that person.
create or replace function public.file_vat_declaration_hmrc_v1(
  p_declaration_id uuid, p_actor_user uuid, p_receipt text
) returns void language plpgsql security definer set search_path = public as $fn$
declare
  d public.vat_declarations;
begin
  select * into d from public.vat_declarations where id = p_declaration_id for update;
  if d.id is null then raise exception 'unknown declaration' using errcode = 'P0002'; end if;
  if not public.feature_effective(d.workspace_id, 'mtdSubmission')
     or not exists (select 1 from public.workspaces w where w.id = d.workspace_id and upper(w.country_code) = 'GB') then
    raise exception 'MTD submission is not available in this space' using errcode = '55000';
  end if;
  if not exists (select 1 from public.members m
                  where m.workspace_id = d.workspace_id and m.user_id = p_actor_user and m.status = 'active'
                    and (m.is_owner or coalesce(m.co_owner, 'none') = 'active')) then
    raise exception 'only the owner files VAT declarations' using errcode = '42501';
  end if;
  perform set_config('request.jwt.claim.sub', p_actor_user::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', p_actor_user)::text, true);
  perform set_config('deskilo.hmrc_filing', p_declaration_id::text, true);
  perform public.mark_vat_declaration_submitted(p_declaration_id, 'hmrc_mtd', p_receipt);
  perform set_config('deskilo.hmrc_filing', '', true);
end;
$fn$;
revoke execute on function public.file_vat_declaration_hmrc_v1(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.file_vat_declaration_hmrc_v1(uuid, uuid, text) to service_role;

select public.set_deskilo_schema_version(648);
