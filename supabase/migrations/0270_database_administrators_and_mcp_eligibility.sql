-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0270 (#1608, #1611) -- who administers THIS database, and who may use
-- MCP on it.
--
-- Two authorities that are not workspace roles and never become one:
--
--   * a DATABASE ADMINISTRATOR is a registered identity (0269 binding) an
--     operator provisioned for this installation. Several may exist. An
--     administrator reviews MCP eligibility; provisioning OTHER
--     administrators is a separate authority (`can_provision`) that the
--     review RPCs never confer and nobody grants themselves.
--   * MCP ELIGIBILITY is one approval per registered identity per
--     installation, reused by every workspace the person belongs to here.
--     It creates no membership, exposes no service, grants no role and is
--     not OAuth consent: those remain separate gates (#1610, #1615).
--
-- Bootstrap and recovery are the operator's, through `tool/instance.dart
-- db-admins` (service role / SQL owner). The last active administrator
-- cannot be REMOVED by anyone: the refusal is the tested behaviour, and an
-- operator adds a successor first. The one way to lose the last one is
-- unlinking their identity; then the MCP runtime switches off until an
-- operator provisions a successor.
--
-- Every decision needs the reviewer's CURRENT trust on this installation,
-- an active identity binding and native AAL2 (`auth.jwt()->>'aal'`). Nothing
-- reads user metadata or a request header. Revoking an identity binding
-- revokes the administrator trust and the eligibility attached to it.

-- The MCP runtime switch and the installation epoch: off until an
-- operator turns it on (#1633); the epoch moves on recovery (#1631).
create table if not exists public.mcp_runtime (
  singleton boolean primary key default true check (singleton),
  enabled boolean not null default false,
  epoch integer not null default 1 check (epoch >= 1)
);
select public.ensure_system_columns('mcp_runtime');
insert into public.mcp_runtime (singleton) values (true) on conflict do nothing;
alter table public.mcp_runtime enable row level security;
revoke all on table public.mcp_runtime from anon, authenticated;

create table if not exists public.database_administrators (
  id uuid primary key default gen_random_uuid(),
  installation_id uuid not null references public.installation_identity (installation_id),
  binding_id uuid not null references public.identity_bindings (id),
  local_user_id uuid not null references auth.users (id) on delete cascade,
  can_provision boolean not null default false,
  status text not null default 'active' check (status in ('active', 'revoked')),
  granted_by text not null check (granted_by ~ '^(operator|admin:[0-9a-f-]{36})$'),
  granted_at timestamptz not null default now(),
  revoked_at timestamptz,
  check ((status = 'revoked') = (revoked_at is not null))
);
select public.ensure_system_columns('database_administrators');
create unique index if not exists database_administrators_one_active
  on public.database_administrators (installation_id, local_user_id) where status = 'active';
alter table public.database_administrators enable row level security;
revoke all on table public.database_administrators from anon, authenticated;

create table if not exists public.mcp_eligibility_requests (
  id uuid primary key default gen_random_uuid(),
  installation_id uuid not null references public.installation_identity (installation_id),
  binding_id uuid not null references public.identity_bindings (id),
  local_user_id uuid not null references auth.users (id) on delete cascade,
  revision integer not null default 1 check (revision >= 1),
  status text not null default 'pending'
    check (status in ('pending', 'withdrawn', 'approved', 'rejected')),
  requested_at timestamptz not null default now()
);
select public.ensure_system_columns('mcp_eligibility_requests');
create unique index if not exists mcp_eligibility_requests_one_pending
  on public.mcp_eligibility_requests (installation_id, local_user_id) where status = 'pending';
alter table public.mcp_eligibility_requests enable row level security;
revoke all on table public.mcp_eligibility_requests from anon, authenticated;

create table if not exists public.mcp_eligibility_grants (
  id uuid primary key default gen_random_uuid(),
  installation_id uuid not null references public.installation_identity (installation_id),
  binding_id uuid not null references public.identity_bindings (id),
  local_user_id uuid not null references auth.users (id) on delete cascade,
  decision_id uuid not null unique,
  request_id uuid references public.mcp_eligibility_requests (id),
  decision text not null check (decision in ('approved', 'rejected')),
  status text not null check (status in ('active', 'revoked', 'rejected')),
  decided_by uuid not null references auth.users (id),
  decided_at timestamptz not null default now(),
  expires_at timestamptz,
  revoked_at timestamptz,
  reason text not null default '' check (length(reason) <= 500),
  check ((decision = 'approved') = (expires_at is not null)),
  check ((status = 'rejected') = (decision = 'rejected'))
);
select public.ensure_system_columns('mcp_eligibility_grants');
create unique index if not exists mcp_eligibility_grants_one_active
  on public.mcp_eligibility_grants (installation_id, local_user_id) where status = 'active';
alter table public.mcp_eligibility_grants enable row level security;
revoke all on table public.mcp_eligibility_grants from anon, authenticated;

-- Append-only: every change of trust or eligibility, with who and why.
create table if not exists public.database_authority_audit (
  id bigint generated always as identity primary key,
  installation_id uuid not null,
  action text not null,
  actor text not null,
  target_user_id uuid,
  detail jsonb not null default '{}'::jsonb,
  at timestamptz not null default now()
);
select public.ensure_system_columns('database_authority_audit');
alter table public.database_authority_audit enable row level security;
revoke all on table public.database_authority_audit from anon, authenticated;

create or replace function public.database_authority_audit_append_only()
returns trigger language plpgsql set search_path = public as $fn$
begin
  raise exception 'the database authority audit is append-only';
end;
$fn$;
revoke execute on function public.database_authority_audit_append_only() from public, anon, authenticated;
drop trigger if exists database_authority_audit_append_only on public.database_authority_audit;
create trigger database_authority_audit_append_only
  before update or delete on public.database_authority_audit
  for each row execute function public.database_authority_audit_append_only();

create or replace function public.installation_id()
returns uuid language sql stable security definer set search_path = public as $fn$
  select installation_id from public.installation_identity;
$fn$;
revoke execute on function public.installation_id() from public, anon, authenticated;

-- The caller's active binding id, when their account is still eligible.
create or replace function public.my_active_binding()
returns uuid language plpgsql stable security definer set search_path = public, auth as $fn$
declare
  v_binding uuid;
begin
  select b.id into v_binding
    from public.identity_bindings b
    join auth.users u on u.id = b.local_user_id
   where b.local_user_id = auth.uid() and b.status = 'active'
     and b.installation_id = public.installation_id()
     and u.deleted_at is null and not coalesce(u.is_anonymous, false)
     and not coalesce(u.banned_until > now(), false);
  return v_binding;
end;
$fn$;
revoke execute on function public.my_active_binding() from public, anon, authenticated;

-- The reviewer: a current administrator of THIS installation, through an
-- active binding, at AAL2. Raises otherwise; returns the admin row id.
create or replace function public.require_database_reviewer(p_provision boolean default false)
returns uuid language plpgsql stable security definer set search_path = public as $fn$
declare
  v_binding uuid := public.my_active_binding();
  v_admin public.database_administrators;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if v_binding is null then raise exception 'no verified identity binding'; end if;
  select * into v_admin from public.database_administrators
   where installation_id = public.installation_id() and local_user_id = auth.uid()
     and binding_id = v_binding and status = 'active';
  if v_admin.id is null then raise exception 'not a database administrator here'; end if;
  if coalesce(auth.jwt()->>'aal', 'aal1') <> 'aal2' then
    raise exception 'a database decision needs a second factor (aal2)';
  end if;
  if p_provision and not v_admin.can_provision then
    raise exception 'provisioning administrators is a separate authority';
  end if;
  return v_admin.id;
end;
$fn$;
revoke execute on function public.require_database_reviewer(boolean) from public, anon, authenticated;

-- ── administrators ───────────────────────────────────────────────────

create or replace function public.grant_database_admin_internal(
  p_target uuid, p_can_provision boolean, p_granted_by text)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_binding uuid;
  v_existing public.database_administrators;
begin
  perform pg_advisory_xact_lock(hashtextextended('database_administrators', 1608));
  select id into v_binding from public.identity_bindings
   where local_user_id = p_target and status = 'active'
     and installation_id = public.installation_id();
  if v_binding is null then
    raise exception 'the target has no verified identity binding on this installation';
  end if;
  select * into v_existing from public.database_administrators
   where installation_id = public.installation_id() and local_user_id = p_target and status = 'active';
  if v_existing.id is not null then
    if v_existing.can_provision = p_can_provision then
      return jsonb_build_object('status', 'unchanged', 'administrator', v_existing.id);
    end if;
    update public.database_administrators set status = 'revoked', revoked_at = now()
     where id = v_existing.id;
  end if;
  insert into public.database_administrators
    (installation_id, binding_id, local_user_id, can_provision, granted_by)
  values (public.installation_id(), v_binding, p_target, p_can_provision, p_granted_by)
  returning * into v_existing;
  insert into public.database_authority_audit (installation_id, action, actor, target_user_id, detail)
  values (public.installation_id(), 'administrator_granted', p_granted_by, p_target,
          jsonb_build_object('can_provision', p_can_provision));
  return jsonb_build_object('status', 'granted', 'administrator', v_existing.id);
end;
$fn$;
revoke execute on function public.grant_database_admin_internal(uuid, boolean, text) from public, anon, authenticated;

create or replace function public.revoke_database_admin_internal(p_target uuid, p_actor text)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_count int;
begin
  perform pg_advisory_xact_lock(hashtextextended('database_administrators', 1608));
  if not exists (select 1 from public.database_administrators
                  where installation_id = public.installation_id() and local_user_id = p_target
                    and status = 'active') then
    return jsonb_build_object('status', 'unchanged');
  end if;
  select count(*) into v_count from public.database_administrators
   where installation_id = public.installation_id() and status = 'active';
  if v_count <= 1 then
    raise exception 'the last database administrator cannot be removed; add a successor first';
  end if;
  update public.database_administrators set status = 'revoked', revoked_at = now()
   where installation_id = public.installation_id() and local_user_id = p_target and status = 'active';
  insert into public.database_authority_audit (installation_id, action, actor, target_user_id)
  values (public.installation_id(), 'administrator_revoked', p_actor, p_target);
  return jsonb_build_object('status', 'revoked');
end;
$fn$;
revoke execute on function public.revoke_database_admin_internal(uuid, text) from public, anon, authenticated;

-- Operator doors (service role / SQL owner only): bootstrap and recovery.
create or replace function public.operator_grant_database_admin(p_target uuid, p_can_provision boolean default true)
returns jsonb language sql volatile security definer set search_path = public as $fn$
  select public.grant_database_admin_internal(p_target, p_can_provision, 'operator');
$fn$;
revoke execute on function public.operator_grant_database_admin(uuid, boolean) from public, anon, authenticated;

create or replace function public.operator_revoke_database_admin(p_target uuid)
returns jsonb language sql volatile security definer set search_path = public as $fn$
  select public.revoke_database_admin_internal(p_target, 'operator');
$fn$;
revoke execute on function public.operator_revoke_database_admin(uuid) from public, anon, authenticated;

-- Administrator doors: only an administrator holding `can_provision`, at
-- AAL2, and never about themselves.
create or replace function public.provision_database_admin(p_target uuid, p_can_provision boolean default false)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
begin
  perform public.require_database_reviewer(true);
  if p_target = auth.uid() then raise exception 'nobody provisions themselves'; end if;
  return public.grant_database_admin_internal(p_target, p_can_provision, 'admin:' || auth.uid());
end;
$fn$;
revoke execute on function public.provision_database_admin(uuid, boolean) from public, anon;
grant execute on function public.provision_database_admin(uuid, boolean) to authenticated;

create or replace function public.remove_database_admin(p_target uuid)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
begin
  perform public.require_database_reviewer(true);
  if p_target = auth.uid() then raise exception 'nobody removes themselves here; ask another administrator'; end if;
  return public.revoke_database_admin_internal(p_target, 'admin:' || auth.uid());
end;
$fn$;
revoke execute on function public.remove_database_admin(uuid) from public, anon;
grant execute on function public.remove_database_admin(uuid) to authenticated;

-- ── eligibility: the subject's side ──────────────────────────────────

create or replace function public.my_database_capabilities()
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_binding uuid := public.my_active_binding();
  v_admin public.database_administrators;
  v_grant public.mcp_eligibility_grants;
  v_request public.mcp_eligibility_requests;
  v_eligibility text;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  select * into v_admin from public.database_administrators
   where installation_id = public.installation_id() and local_user_id = auth.uid()
     and status = 'active' and binding_id = v_binding;
  select * into v_grant from public.mcp_eligibility_grants
   where installation_id = public.installation_id() and local_user_id = auth.uid()
     and status = 'active' and binding_id = v_binding;
  select * into v_request from public.mcp_eligibility_requests
   where installation_id = public.installation_id() and local_user_id = auth.uid() and status = 'pending';
  v_eligibility := case
    when v_binding is null then 'no_identity'
    when v_grant.id is not null and v_grant.expires_at > now() then 'eligible'
    when v_grant.id is not null then 'expired'
    when v_request.id is not null then 'requested'
    else 'not_requested' end;
  return jsonb_build_object(
    'installation_id', public.installation_id(),
    'runtime_enabled', (select enabled from public.mcp_runtime),
    'database_administrator', v_admin.id is not null,
    'can_provision', coalesce(v_admin.can_provision, false),
    'mcp_eligibility', v_eligibility,
    'eligible_until', case when v_eligibility = 'eligible' then v_grant.expires_at end,
    'request_revision', v_request.revision);
end;
$fn$;
revoke execute on function public.my_database_capabilities() from public, anon;
grant execute on function public.my_database_capabilities() to authenticated;

create or replace function public.request_mcp_eligibility()
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_binding uuid := public.my_active_binding();
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if v_binding is null then raise exception 'no verified identity binding'; end if;
  perform pg_advisory_xact_lock(hashtextextended('mcp_eligibility|' || auth.uid(), 1611));
  if not exists (select 1 from public.mcp_eligibility_requests
                  where installation_id = public.installation_id() and local_user_id = auth.uid()
                    and status = 'pending') then
    insert into public.mcp_eligibility_requests (installation_id, binding_id, local_user_id)
    values (public.installation_id(), v_binding, auth.uid());
  end if;
  return public.my_database_capabilities();
end;
$fn$;
revoke execute on function public.request_mcp_eligibility() from public, anon;
grant execute on function public.request_mcp_eligibility() to authenticated;

create or replace function public.withdraw_mcp_eligibility()
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  update public.mcp_eligibility_requests set status = 'withdrawn'
   where installation_id = public.installation_id() and local_user_id = auth.uid() and status = 'pending';
  update public.mcp_eligibility_grants set status = 'revoked', revoked_at = now()
   where installation_id = public.installation_id() and local_user_id = auth.uid() and status = 'active';
  insert into public.database_authority_audit (installation_id, action, actor, target_user_id)
  values (public.installation_id(), 'eligibility_withdrawn', 'self', auth.uid());
  return public.my_database_capabilities();
end;
$fn$;
revoke execute on function public.withdraw_mcp_eligibility() from public, anon;
grant execute on function public.withdraw_mcp_eligibility() to authenticated;

-- ── eligibility: the administrator's side ────────────────────────────

create or replace function public.list_mcp_eligibility_requests()
returns table (request_id uuid, local_user_id uuid, email text, revision integer, requested_at timestamptz)
language plpgsql stable security definer set search_path = public, auth as $fn$
begin
  perform public.require_database_reviewer();
  return query
    select r.id, r.local_user_id, u.email::text, r.revision, r.requested_at
      from public.mcp_eligibility_requests r join auth.users u on u.id = r.local_user_id
     where r.installation_id = public.installation_id() and r.status = 'pending'
     order by r.requested_at, r.id;
end;
$fn$;
revoke execute on function public.list_mcp_eligibility_requests() from public, anon;
grant execute on function public.list_mcp_eligibility_requests() to authenticated;

-- One decision, idempotent by [p_decision_id]: the same id with the same
-- decision answers what was stored; with another it conflicts; a replay
-- after a revocation answers the stored decision and reactivates nothing.
create or replace function public.decide_mcp_eligibility(
  p_subject uuid, p_decision_id uuid, p_approve boolean,
  p_expected_revision integer default null, p_valid_days integer default 90,
  p_reason text default '')
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_reviewer uuid := public.require_database_reviewer();
  v_prior public.mcp_eligibility_grants;
  v_request public.mcp_eligibility_requests;
  v_binding uuid;
  v_days integer := coalesce(p_valid_days, 90);
begin
  if p_decision_id is null then raise exception 'a decision needs its id'; end if;
  if v_days < 1 or v_days > 365 then raise exception 'eligibility lasts 1 to 365 days'; end if;
  if p_subject = auth.uid() then raise exception 'nobody decides their own eligibility'; end if;
  perform pg_advisory_xact_lock(hashtextextended('mcp_eligibility|' || p_subject, 1611));

  select * into v_prior from public.mcp_eligibility_grants where decision_id = p_decision_id;
  if v_prior.id is not null then
    if v_prior.local_user_id <> p_subject or (v_prior.decision = 'approved') <> p_approve then
      return jsonb_build_object('status', 'conflict', 'reason', 'decision_id_reused');
    end if;
    return jsonb_build_object('status', 'replayed', 'decision', v_prior.decision,
                              'current', v_prior.status);
  end if;

  select id into v_binding from public.identity_bindings
   where local_user_id = p_subject and status = 'active' and installation_id = public.installation_id();
  if v_binding is null then
    return jsonb_build_object('status', 'refused', 'reason', 'no_identity_binding');
  end if;
  select * into v_request from public.mcp_eligibility_requests
   where installation_id = public.installation_id() and local_user_id = p_subject and status = 'pending';
  if p_expected_revision is not null and coalesce(v_request.revision, 0) <> p_expected_revision then
    return jsonb_build_object('status', 'conflict', 'reason', 'request_changed');
  end if;

  if p_approve then
    update public.mcp_eligibility_grants set status = 'revoked', revoked_at = now()
     where installation_id = public.installation_id() and local_user_id = p_subject and status = 'active';
  end if;
  insert into public.mcp_eligibility_grants
    (installation_id, binding_id, local_user_id, decision_id, request_id, decision, status,
     decided_by, expires_at, reason)
  values (public.installation_id(), v_binding, p_subject, p_decision_id, v_request.id,
          case when p_approve then 'approved' else 'rejected' end,
          case when p_approve then 'active' else 'rejected' end,
          auth.uid(), case when p_approve then now() + make_interval(days => v_days) end,
          coalesce(p_reason, ''));
  if v_request.id is not null then
    update public.mcp_eligibility_requests
       set status = case when p_approve then 'approved' else 'rejected' end
     where id = v_request.id;
  end if;
  insert into public.database_authority_audit (installation_id, action, actor, target_user_id, detail)
  values (public.installation_id(), case when p_approve then 'eligibility_approved' else 'eligibility_rejected' end,
          'admin:' || auth.uid(), p_subject,
          jsonb_build_object('decision_id', p_decision_id, 'valid_days', v_days, 'reviewer', v_reviewer));
  return jsonb_build_object('status', 'decided', 'decision', case when p_approve then 'approved' else 'rejected' end);
end;
$fn$;
revoke execute on function public.decide_mcp_eligibility(uuid, uuid, boolean, integer, integer, text) from public, anon;
grant execute on function public.decide_mcp_eligibility(uuid, uuid, boolean, integer, integer, text) to authenticated;

create or replace function public.revoke_mcp_eligibility(p_subject uuid, p_reason text default '')
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_count int;
begin
  perform public.require_database_reviewer();
  perform pg_advisory_xact_lock(hashtextextended('mcp_eligibility|' || p_subject, 1611));
  update public.mcp_eligibility_grants set status = 'revoked', revoked_at = now()
   where installation_id = public.installation_id() and local_user_id = p_subject and status = 'active';
  get diagnostics v_count = row_count;
  insert into public.database_authority_audit (installation_id, action, actor, target_user_id, detail)
  values (public.installation_id(), 'eligibility_revoked', 'admin:' || auth.uid(), p_subject,
          jsonb_build_object('reason', left(coalesce(p_reason, ''), 500)));
  return jsonb_build_object('status', case when v_count > 0 then 'revoked' else 'unchanged' end);
end;
$fn$;
revoke execute on function public.revoke_mcp_eligibility(uuid, text) from public, anon;
grant execute on function public.revoke_mcp_eligibility(uuid, text) to authenticated;

-- An unlinked identity takes its authority with it (#1647).
create or replace function public.identity_binding_revoked_cascade()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  if old.status = 'active' and new.status = 'revoked' then
    update public.database_administrators set status = 'revoked', revoked_at = now()
     where binding_id = new.id and status = 'active';
    update public.mcp_eligibility_grants set status = 'revoked', revoked_at = now()
     where binding_id = new.id and status = 'active';
    update public.mcp_eligibility_requests set status = 'withdrawn'
     where binding_id = new.id and status = 'pending';
    insert into public.database_authority_audit (installation_id, action, actor, target_user_id)
    values (new.installation_id, 'identity_unlinked', 'self', new.local_user_id);
    -- The last administrator unlinked: nobody governs MCP here any more,
    -- so it stops until an operator provisions a successor (#1608).
    if not exists (select 1 from public.database_administrators
                    where installation_id = new.installation_id and status = 'active') then
      update public.mcp_runtime set enabled = false where enabled;
    end if;
  end if;
  return new;
end;
$fn$;
revoke execute on function public.identity_binding_revoked_cascade() from public, anon, authenticated;
drop trigger if exists identity_binding_revoked_cascade on public.identity_bindings;
create trigger identity_binding_revoked_cascade
  after update of status on public.identity_bindings
  for each row execute function public.identity_binding_revoked_cascade();

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(270);
