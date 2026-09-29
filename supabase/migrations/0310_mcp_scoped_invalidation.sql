-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0310 (#1631) -- revocation, identity changes and recovery, each at its
-- own scope.
--
-- The dispatcher (0271 onwards) already re-checks every gate on every
-- call and on every replay: a feature switched off, an operation removed
-- from the policy, a role lost, a membership paused. Those are
-- RESTRICTIONS -- the records stay, and a later ON gives back only what
-- is still approved and consented. This file adds the REVOCATIONS, the
-- lifecycle changes after which an old consent must never come back by
-- itself:
--
--   scope                          what ends                         who else keeps it
--   ─────────────────────────────  ────────────────────────────────  ────────────────────────
--   the person withdraws one       that workspace's consent, for     every other workspace
--   workspace (native)             that assistant                    and assistant
--   membership exits, is deleted   that person's consent to that     the same person's other
--   or moves to another account    workspace, for every assistant    workspaces
--   the person disconnects an      that assistant's connection and   other assistants
--   assistant (native)             all its workspaces here
--   the operator revokes an        every connection of that          every other assistant
--   assistant for the instance     assistant, for everybody here
--   eligibility is revoked,        every connection of that person   everybody else; every
--   withdrawn, lapses and is re-   on THIS database                  other database
--   decided, or the identity is
--   unlinked
--   the operator resets MCP        every connection, eligibility,    identities, workspace
--   authority after a restore      administrator trust and pending   policies, idempotency
--                                  confirmation; the epoch moves     tombstones, the audit
--
-- Renewing a CURRENT approval is not a revocation: consent survives it.
-- A policy saved by an owner belongs to the workspace, not to its author,
-- so an owner leaving revokes nothing (is_owner_of already refuses the
-- former owner's edits, and the revision refuses a stale one).
--
-- Every revocation goes through one helper, mcp_invalidate_consent, which
-- updates the consent rows the dispatcher reads `for share` -- so a call
-- already holding them finishes first and a call arriving after the
-- commit finds them revoked -- and writes one audit row. Replay
-- tombstones (mcp_idempotency) are never deleted: a request id used
-- before a revocation answers its stored outcome after a legitimate
-- re-enrollment, and never executes again.
--
-- The installation epoch: an operator restoring this database resets MCP
-- authority here (operator_reset_mcp_authority), which moves the epoch;
-- the endpoint carries the epoch it was deployed for (DESKILO_MCP_EPOCH)
-- in `x-deskilo-mcp-epoch`, and the pre-request guard refuses a request
-- whose epoch is not this database's. The epoch lives in the endpoint's
-- configuration as well as here, so a database restored behind an
-- endpoint configured for another epoch fails closed. It does not detect
-- a privileged rollback of the database AND the endpoint configuration.

-- ── the one invalidation helper ─────────────────────────────────────

-- p_user null = every person; p_client null = every assistant;
-- p_workspace null = the whole connection (and the connection itself is
-- revoked), otherwise only that workspace's consent.
create or replace function public.mcp_invalidate_consent(
  p_user uuid, p_client text, p_workspace uuid, p_reason text, p_actor text)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_workspaces uuid[];
  v_connections int := 0;
  v_confirmations int := 0;
  v_preparations int := 0;
begin
  if p_reason is null or p_reason !~ '^[a-z_]{3,40}$' then
    raise exception 'an invalidation needs its reason';
  end if;
  with revoked as (
    update public.mcp_connection_scopes s set revoked_at = now()
      from public.mcp_connections c
     where s.connection_id = c.id and c.installation_id = public.installation_id()
       and (p_user is null or c.local_user_id = p_user)
       and (p_client is null or c.client_id = p_client)
       and (p_workspace is null or s.workspace_id = p_workspace)
       and s.revoked_at is null
    returning s.workspace_id)
  select coalesce(array_agg(distinct workspace_id order by workspace_id), '{}') into v_workspaces from revoked;

  if p_workspace is null then
    update public.mcp_connections set status = 'revoked', revoked_at = now()
     where installation_id = public.installation_id() and status = 'active'
       and (p_user is null or local_user_id = p_user)
       and (p_client is null or client_id = p_client);
    get diagnostics v_connections = row_count;
    update public.mcp_connection_preparations set status = 'abandoned'
     where installation_id = public.installation_id() and status = 'prepared'
       and (p_user is null or local_user_id = p_user)
       and (p_client is null or client_id = p_client);
    get diagnostics v_preparations = row_count;
  end if;

  -- A native confirmation waiting on a consent that just ended authorises
  -- nothing; the dispatcher would refuse it anyway, this keeps its status
  -- truthful.
  update public.mcp_action_confirmations set status = 'revoked'
   where installation_id = public.installation_id() and status in ('pending', 'acknowledged')
     and (p_user is null or local_user_id = p_user)
     and (p_client is null or client_id = p_client)
     and (p_workspace is null or workspace_id = p_workspace);
  get diagnostics v_confirmations = row_count;

  if cardinality(v_workspaces) > 0 or v_connections > 0 or v_confirmations > 0 or v_preparations > 0 then
    insert into public.database_authority_audit (installation_id, action, actor, target_user_id, detail)
    values (public.installation_id(), 'mcp_consent_invalidated', coalesce(p_actor, 'system'), p_user,
            jsonb_strip_nulls(jsonb_build_object(
              'reason', p_reason, 'client_id', p_client, 'workspace_id', p_workspace,
              'workspaces', to_jsonb(v_workspaces), 'connections', v_connections,
              'confirmations', v_confirmations, 'preparations', v_preparations)));
  end if;
  return jsonb_build_object(
    'installation_id', public.installation_id(),
    'scope', case when p_workspace is null then 'connection' else 'workspace' end,
    'client_id', p_client,
    'workspaces', to_jsonb(v_workspaces),
    'connections', v_connections);
end;
$fn$;
revoke execute on function public.mcp_invalidate_consent(uuid, text, uuid, text, text) from public, anon, authenticated;

-- ── the person's own revocations (native only), now through the helper ─

create or replace function public.revoke_mcp_workspace_scope(p_client_id text, p_workspace_id uuid)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_out jsonb;
begin
  perform public.mcp_require_native();
  if p_workspace_id is null then raise exception 'name the workspace to remove'; end if;
  v_out := public.mcp_invalidate_consent(auth.uid(), p_client_id, p_workspace_id,
                                         'workspace_consent_withdrawn', 'self');
  return v_out || jsonb_build_object('status',
    case when jsonb_array_length(v_out->'workspaces') > 0 then 'revoked' else 'unchanged' end);
end;
$fn$;
revoke execute on function public.revoke_mcp_workspace_scope(text, uuid) from public, anon;
grant execute on function public.revoke_mcp_workspace_scope(text, uuid) to authenticated;

create or replace function public.revoke_mcp_connection(p_client_id text)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_out jsonb;
begin
  perform public.mcp_require_native();
  if p_client_id is null then raise exception 'name the assistant to disconnect'; end if;
  v_out := public.mcp_invalidate_consent(auth.uid(), p_client_id, null, 'connection_revoked', 'self');
  return v_out || jsonb_build_object('status',
    case when (v_out->>'connections')::int > 0 then 'revoked' else 'unchanged' end);
end;
$fn$;
revoke execute on function public.revoke_mcp_connection(text) from public, anon;
grant execute on function public.revoke_mcp_connection(text) to authenticated;

-- ── lifecycle triggers ───────────────────────────────────────────────

-- Eligibility ended (administrator revoke, self-withdrawal, identity
-- unlink, or a lapsed approval replaced by a new decision): every
-- connection of that person on this database ends with it. A renewal of
-- a still-current approval is marked by decide_mcp_eligibility and ends
-- nothing.
create or replace function public.mcp_eligibility_revoked_invalidate()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  if old.status = 'active' and new.status = 'revoked' then
    if coalesce(current_setting('deskilo.mcp_eligibility_renewal', true), '') = new.local_user_id::text
       and old.expires_at > now() then
      return new;
    end if;
    perform public.mcp_invalidate_consent(new.local_user_id, null, null, 'eligibility_revoked', 'system');
  end if;
  return new;
end;
$fn$;
revoke execute on function public.mcp_eligibility_revoked_invalidate() from public, anon, authenticated;
drop trigger if exists mcp_eligibility_revoked_invalidate on public.mcp_eligibility_grants;
create trigger mcp_eligibility_revoked_invalidate
  after update of status on public.mcp_eligibility_grants
  for each row execute function public.mcp_eligibility_revoked_invalidate();

-- An unlinked identity: its connections end even when no grant was
-- active (a relink is a new binding and starts from nothing).
create or replace function public.identity_binding_revoked_invalidate()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  if old.status = 'active' and new.status = 'revoked' then
    perform public.mcp_invalidate_consent(new.local_user_id, null, null, 'identity_unlinked', 'system');
  end if;
  return new;
end;
$fn$;
revoke execute on function public.identity_binding_revoked_invalidate() from public, anon, authenticated;
drop trigger if exists identity_binding_revoked_invalidate on public.identity_bindings;
create trigger identity_binding_revoked_invalidate
  after update of status on public.identity_bindings
  for each row execute function public.identity_binding_revoked_invalidate();

-- The operator revokes an assistant for the whole instance: every
-- connection of it ends, so approving it again later revives nothing.
create or replace function public.mcp_client_revoked_invalidate()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  if old.status = 'active' and new.status = 'revoked' then
    perform public.mcp_invalidate_consent(null, new.client_id, null, 'client_revoked', 'operator');
  end if;
  return new;
end;
$fn$;
revoke execute on function public.mcp_client_revoked_invalidate() from public, anon, authenticated;
drop trigger if exists mcp_client_revoked_invalidate on public.mcp_clients;
create trigger mcp_client_revoked_invalidate
  after update of status on public.mcp_clients
  for each row execute function public.mcp_client_revoked_invalidate();

-- A membership that ends (exited, deleted) or moves to another account
-- ends that person's consent to THAT workspace. A pause is a restriction:
-- the dispatcher refuses while it lasts, and nothing is revoked.
create or replace function public.members_mcp_invalidate()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  if tg_op = 'DELETE' then
    if old.user_id is not null then
      perform public.mcp_invalidate_consent(old.user_id, null, old.workspace_id, 'membership_ended', 'system');
    end if;
    return old;
  end if;
  if old.user_id is null then
    return new;
  end if;
  if new.user_id is distinct from old.user_id then
    perform public.mcp_invalidate_consent(old.user_id, null, old.workspace_id, 'membership_reassigned', 'system');
  elsif new.status = 'exited' and old.status <> 'exited' then
    perform public.mcp_invalidate_consent(old.user_id, null, old.workspace_id, 'membership_ended', 'system');
  end if;
  return new;
end;
$fn$;
revoke execute on function public.members_mcp_invalidate() from public, anon, authenticated;
drop trigger if exists members_mcp_invalidate on public.members;
create trigger members_mcp_invalidate
  after update of status, user_id or delete on public.members
  for each row execute function public.members_mcp_invalidate();

-- The last administrator's account deleted (the row cascades away, no
-- status change to catch): nobody governs MCP here any more, so the
-- runtime stops until an operator provisions a successor -- the same
-- rule as the last administrator unlinking (0270).
create or replace function public.database_administrator_deleted()
returns trigger language plpgsql security definer set search_path = public as $fn$
begin
  if old.status = 'active' and not exists (
       select 1 from public.database_administrators
        where installation_id = old.installation_id and status = 'active') then
    update public.mcp_runtime set enabled = false where enabled;
    insert into public.database_authority_audit (installation_id, action, actor, target_user_id)
    values (old.installation_id, 'last_administrator_deleted', 'system', old.local_user_id);
  end if;
  return old;
end;
$fn$;
revoke execute on function public.database_administrator_deleted() from public, anon, authenticated;
drop trigger if exists database_administrator_deleted on public.database_administrators;
create trigger database_administrator_deleted
  after delete on public.database_administrators
  for each row execute function public.database_administrator_deleted();

-- ── a renewal is not a revocation (anchored patch of 0270) ───────────

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

do $migration$
declare
  v_def text;
  v_next text;
begin
  select pg_get_functiondef('public.decide_mcp_eligibility(uuid, uuid, boolean, integer, integer, text)'::regprocedure)
    into v_def;
  v_next := pg_temp.anchor_replace(v_def,
$a$  if p_approve then
    update public.mcp_eligibility_grants set status = 'revoked', revoked_at = now()
     where installation_id = public.installation_id() and local_user_id = p_subject and status = 'active';
  end if;$a$,
$b$  if p_approve then
    -- #1631 — replacing a CURRENT approval is a renewal: consent survives.
    -- Replacing a lapsed one is not, and its connections end.
    perform set_config('deskilo.mcp_eligibility_renewal',
      case when exists (select 1 from public.mcp_eligibility_grants
                         where installation_id = public.installation_id() and local_user_id = p_subject
                           and status = 'active' and expires_at > now())
           then p_subject::text else '' end, true);
    update public.mcp_eligibility_grants set status = 'revoked', revoked_at = now()
     where installation_id = public.installation_id() and local_user_id = p_subject and status = 'active';
    perform set_config('deskilo.mcp_eligibility_renewal', '', true);
  end if;$b$);
  if v_next is null then
    raise exception '0310: decide_mcp_eligibility renewal anchor not found';
  end if;
  execute v_next;
end
$migration$;

-- ── the runtime: an administrator, and the epoch ─────────────────────

-- On only with the delegated-token guard complete (0273) AND at least one
-- current database administrator to govern it.
create or replace function public.operator_set_mcp_runtime(p_enabled boolean)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_status jsonb := public.mcp_facade_guard_status();
begin
  if p_enabled and (not (v_status->>'pre_request_installed')::boolean
                    or jsonb_array_length(v_status->'tables_without_denial') > 0) then
    raise exception 'MCP stays off: the delegated-token guard is not complete (%)', v_status;
  end if;
  if p_enabled and not exists (select 1 from public.database_administrators
                                where installation_id = public.installation_id() and status = 'active') then
    raise exception 'MCP stays off: no database administrator governs it; provision one first';
  end if;
  update public.mcp_runtime set enabled = p_enabled;
  insert into public.database_authority_audit (installation_id, action, actor, detail)
  values (public.installation_id(), case when p_enabled then 'runtime_enabled' else 'runtime_disabled' end,
          'operator', v_status);
  return jsonb_build_object('enabled', p_enabled, 'guard', v_status,
                            'epoch', (select epoch from public.mcp_runtime));
end;
$fn$;
revoke execute on function public.operator_set_mcp_runtime(boolean) from public, anon, authenticated;

-- What the operator verifies before and after a controlled restore.
create or replace function public.operator_mcp_runtime_status()
returns jsonb language sql stable security definer set search_path = public as $fn$
  select jsonb_build_object(
    'installation_id', public.installation_id(),
    'enabled', r.enabled,
    'epoch', r.epoch,
    'administrators', (select count(*) from public.database_administrators
                        where installation_id = public.installation_id() and status = 'active'),
    'eligible_users', (select count(*) from public.mcp_eligibility_grants
                        where installation_id = public.installation_id() and status = 'active'
                          and expires_at > now()),
    'active_connections', (select count(*) from public.mcp_connections
                            where installation_id = public.installation_id() and status = 'active'),
    'identity_authority', (select jsonb_build_object('kind', kind, 'issuer', issuer)
                             from public.identity_authority))
  from public.mcp_runtime r;
$fn$;
revoke execute on function public.operator_mcp_runtime_status() from public, anon, authenticated;

-- The controlled restore/clone step. The operator switches MCP off, names
-- the installation they mean to reset (a restored copy of ANOTHER
-- installation fails here), and every piece of copied authority ends:
-- connections and consent, eligibility and its pending requests,
-- administrator trust, pending confirmations. The epoch moves, so an
-- endpoint still configured for the old one is refused until it is
-- redeployed. Identities (who a local user IS), workspace policies
-- (organisational configuration), idempotency tombstones and the audit
-- stay. Re-enrollment is the ordinary path: an operator provisions an
-- administrator, who approves eligibility; people consent again.
create or replace function public.operator_reset_mcp_authority(p_installation_id uuid, p_reason text)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_runtime public.mcp_runtime;
  v_grants int;
  v_admins int;
  v_requests int;
  v_consent jsonb;
begin
  if p_installation_id is distinct from public.installation_id() then
    raise exception 'this database is installation %, not %', public.installation_id(), p_installation_id;
  end if;
  if coalesce(length(btrim(p_reason)), 0) = 0 or length(p_reason) > 500 then
    raise exception 'a reset needs its reason (1 to 500 characters)';
  end if;
  select * into v_runtime from public.mcp_runtime for update;
  if v_runtime.enabled then
    raise exception 'switch the MCP runtime off before resetting its authority';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('database_administrators', 1608));

  v_consent := public.mcp_invalidate_consent(null, null, null, 'authority_reset', 'operator');
  update public.mcp_eligibility_grants set status = 'revoked', revoked_at = now()
   where installation_id = public.installation_id() and status = 'active';
  get diagnostics v_grants = row_count;
  update public.mcp_eligibility_requests set status = 'withdrawn'
   where installation_id = public.installation_id() and status = 'pending';
  get diagnostics v_requests = row_count;
  update public.database_administrators set status = 'revoked', revoked_at = now()
   where installation_id = public.installation_id() and status = 'active';
  get diagnostics v_admins = row_count;
  update public.mcp_action_confirmations set status = 'revoked'
   where installation_id = public.installation_id() and status in ('pending', 'acknowledged');
  update public.mcp_runtime set epoch = v_runtime.epoch + 1;

  insert into public.database_authority_audit (installation_id, action, actor, detail)
  values (public.installation_id(), 'authority_reset', 'operator',
          jsonb_build_object('reason', p_reason, 'epoch', v_runtime.epoch + 1,
                             'eligibility_revoked', v_grants, 'requests_withdrawn', v_requests,
                             'administrators_revoked', v_admins,
                             'connections_revoked', (v_consent->>'connections')::int));
  return jsonb_build_object(
    'installation_id', public.installation_id(), 'epoch', v_runtime.epoch + 1,
    'eligibility_revoked', v_grants, 'requests_withdrawn', v_requests,
    'administrators_revoked', v_admins, 'connections_revoked', (v_consent->>'connections')::int);
end;
$fn$;
revoke execute on function public.operator_reset_mcp_authority(uuid, text) from public, anon, authenticated;

-- The epoch a delegated request presents (the endpoint sets it from its
-- own configuration), compared with this database's. Absent = not
-- presented: the endpoint refuses to serve without one, so only a direct
-- PostgREST caller omits it, and every other gate still applies to that.
create or replace function public.mcp_runtime_epoch_mismatch()
returns boolean language plpgsql stable security definer set search_path = public as $fn$
declare
  v_presented text;
begin
  begin
    v_presented := nullif(current_setting('request.headers', true), '')::jsonb->>'x-deskilo-mcp-epoch';
  exception when others then
    return true;
  end;
  if v_presented is null then
    return false;
  end if;
  return v_presented !~ '^[1-9][0-9]{0,8}$'
      or v_presented::integer is distinct from (select epoch from public.mcp_runtime);
end;
$fn$;
revoke execute on function public.mcp_runtime_epoch_mismatch() from public;
grant execute on function public.mcp_runtime_epoch_mismatch() to anon, authenticated;

-- 0274's guard, plus the epoch.
create or replace function public.mcp_pre_request()
returns void language plpgsql stable set search_path = public as $fn$
declare
  v_path text := coalesce(current_setting('request.path', true), '');
  v_method text := upper(coalesce(current_setting('request.method', true), ''));
begin
  if not public.mcp_is_delegated() then
    return;
  end if;
  if public.mcp_runtime_epoch_mismatch() then
    raise sqlstate 'PGRST' using
      message = json_build_object('code', 'MCP409',
        'message', 'this endpoint was deployed for another installation epoch')::text,
      detail = json_build_object('status', 409, 'headers', json_build_object())::text;
  end if;
  if v_method = 'POST' and v_path in ('/rpc/mcp_execute_v1', '/rpc/mcp_my_operations',
                                      '/rpc/my_database_capabilities') then
    return;
  end if;
  raise sqlstate 'PGRST' using
    message = json_build_object('code', 'MCP403',
      'message', 'a delegated token may only call the MCP facade')::text,
    detail = json_build_object('status', 403, 'headers', json_build_object())::text;
end;
$fn$;
revoke execute on function public.mcp_pre_request() from public;
grant execute on function public.mcp_pre_request() to anon, authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(310);
