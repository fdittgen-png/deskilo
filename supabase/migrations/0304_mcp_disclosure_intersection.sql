-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0304 (#1645) -- a named display field leaves the database only when
-- every party that may withhold it agreed, now:
--
--   installation maximum (a database administrator, mcp_disclosure_maximum)
--   INTERSECT the workspace's policy (the owner, save_mcp_policy)
--   INTERSECT the native answer (the field is only kept, never added: a
--             value the native read does not return to this caller is
--             not there to keep)
--   INTERSECT the person's consent for THIS client and THIS workspace
--             (mcp_prepare_connection / mcp_finalize_connection).
--
-- The contract names the only optional fields (output_fields with
-- "disclosure": "optional", today a seat's `name`); the catalogue lists
-- them per operation. Every layer defaults to none, so an answer stays
-- minimized exactly as 0293 made it until all four name a field. Saving
-- is refused for an unknown field, for a policy above the maximum, and
-- for consent above what the policy and the maximum offer. Lowering a
-- layer takes effect on the next answer, and a replay is re-projected
-- through the CURRENT layers. (0302 and 0303 are other changes in flight.)

-- GENERATED from contracts/mcp/operations.json by tool/mcp_contract/render.dart
-- (renderMcpCatalogueSql); mcp_contract_test fails until this is verbatim.
create or replace function public.mcp_operation_catalogue()
returns jsonb
language sql
immutable
set search_path = public
as $catalogue$
  select $json${"version":1,"operations":{"list_workspaces":{"rpc":null,"dispatch":false,"authority":"self","permission":null,"features":[],"scope":"discovery","mutation":"read","confirmation":"none","output":["confirmation_id","environment","expires_at","reason","role","unchanged","workspace_id"],"optional":["name"]},"get_capabilities":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none","output":["confirmation_id","eligible_until","expires_at","operations","reason","target_ceiling","unchanged"],"optional":[]},"get_availability":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none","output":["confirmation_id","ends_at","expires_at","free","items","next_cursor","not_checked","observed_at","reason","seat_id","starts_at","unchanged","window"],"optional":["name"]},"list_my_reservations":{"rpc":null,"dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"read","confirmation":"none","output":["confirmation_id","desk_id","ends_at","expires_at","items","level_id","next_cursor","office_id","reason","reservation_id","seat_id","starts_at","status","unchanged"],"optional":[]},"get_my_statement":{"rpc":"member_statement","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess","moneyTab"],"scope":"own","mutation":"read","confirmation":"none","output":["accessory_supplement_by_rate","accessory_supplement_cents","active","amount_cents","balance_cents","confirmation_id","credits_cents","default_fee_cents","default_overage_fee_cents","desk_supplement_cents","discount_percent","expires_at","extra_half_days","fee_cents","granted_half_days","included_half_days","level_supplement_cents","negotiated","office_supplement_cents","open_days","overage_cents","overage_fee_cents","overage_policy","overage_rate_cents","period","reason","remaining_half_days","subscription_pct","unchanged","used_half_days","valid_from","vat_percent"],"optional":[]},"list_my_invoices":{"rpc":null,"dispatch":true,"authority":"self","permission":null,"features":["mcpAccess","invoicing"],"scope":"own","mutation":"read","confirmation":"none","output":["confirmation_id","currency","expires_at","invoice_id","issued_at","items","kind","next_cursor","number","period","reason","total_cents","unchanged","voided"],"optional":[]},"create_reservation":{"rpc":"create_reservation_once","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"update_reservation":{"rpc":"update_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"check_in":{"rpc":"check_in_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"check_out":{"rpc":"check_out_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"request_reservation_deletion":{"rpc":"request_reservation_deletion","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"request","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","event_id","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"request_invoice_issue":{"rpc":"request_invoice_issue","dispatch":true,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","currency","event_id","expires_at","invoice_id","invoice_number","period","reason","total_cents","unchanged","voided"],"optional":[]},"request_invoice_void":{"rpc":"request_invoice_void","dispatch":true,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","currency","event_id","expires_at","invoice_id","invoice_number","period","reason","total_cents","unchanged","voided"],"optional":[]},"request_refund":{"rpc":"request_refund","dispatch":true,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","currency","event_id","expires_at","invoice_id","invoice_number","period","reason","total_cents","unchanged","voided"],"optional":[]},"request_member_status_change":{"rpc":"request_member_status_change","dispatch":true,"authority":"permission","permission":"manageMembers","features":["mcpAccess"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","event_id","expires_at","member_id","member_status","reason","subscription_pct","unchanged"],"optional":[]},"request_subscription_change":{"rpc":"request_subscription_change","dispatch":true,"authority":"permission","permission":"manageMembers","features":["mcpAccess"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","event_id","expires_at","member_id","member_status","reason","subscription_pct","unchanged"],"optional":[]},"list_pending_validations":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none","output":["confirmation_id","event_id","expires_at","items","mine","next_cursor","reason","requested_at","type","unchanged"],"optional":[]},"get_validation":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none","output":["can_respond","confirmation_id","decisions","event_id","expires_at","reason","requested_at","status","type","unchanged"],"optional":[]},"respond_to_validation":{"rpc":"respond_to_event","dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"decision","confirmation":"native","output":["confirmation_id","decision_recorded","effect_applied","event_id","event_status","expires_at","reason","unchanged"],"optional":[]}}}$json$::jsonb
$catalogue$;
revoke execute on function public.mcp_operation_catalogue() from public, anon;
grant execute on function public.mcp_operation_catalogue() to authenticated;

-- ── the layers ──────────────────────────────────────────────────────

create table if not exists public.mcp_disclosure_maximum (
  singleton boolean primary key default true check (singleton),
  optional_fields text[] not null default '{}'
);
select public.ensure_system_columns('mcp_disclosure_maximum');
insert into public.mcp_disclosure_maximum (singleton) values (true) on conflict do nothing;
alter table public.mcp_disclosure_maximum enable row level security;
revoke all on table public.mcp_disclosure_maximum from anon, authenticated;
drop policy if exists mcp_delegated_deny on public.mcp_disclosure_maximum;
create policy mcp_delegated_deny on public.mcp_disclosure_maximum
  as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

alter table public.workspace_mcp_policies add column if not exists optional_fields text[] not null default '{}';
alter table public.mcp_connection_scopes add column if not exists optional_fields text[] not null default '{}';

-- The installation maximum as it stands.
create or replace function public.mcp_disclosure_ceiling()
returns text[] language sql stable set search_path = public as $fn$
  select coalesce((select optional_fields from public.mcp_disclosure_maximum where singleton), '{}'::text[]);
$fn$;
revoke execute on function public.mcp_disclosure_ceiling() from public, anon, authenticated;

-- Every field the contract lets a person disclose, on any operation.
create or replace function public.mcp_optional_field_names()
returns text[] language sql immutable set search_path = public as $fn$
  select coalesce(array_agg(distinct f order by f), '{}')
    from jsonb_each(public.mcp_operation_catalogue()->'operations') e(k, v),
         jsonb_array_elements_text(coalesce(v->'optional', '[]'::jsonb)) f;
$fn$;
revoke execute on function public.mcp_optional_field_names() from public, anon, authenticated;

-- A requested list, deduplicated and sorted; unknown names are refused.
create or replace function public.mcp_clean_optional_fields(p_fields text[])
returns text[] language plpgsql immutable set search_path = public as $fn$
declare
  v_field text;
  v_clean text[];
begin
  select coalesce(array_agg(distinct f order by f), '{}') into v_clean from unnest(coalesce(p_fields, '{}')) f;
  foreach v_field in array v_clean loop
    if v_field is null or not (v_field = any (public.mcp_optional_field_names())) then
      raise exception 'unknown optional field %', coalesce(v_field, 'null');
    end if;
  end loop;
  return v_clean;
end;
$fn$;
revoke execute on function public.mcp_clean_optional_fields(text[]) from public, anon, authenticated;

create or replace function public.mcp_disclosure_status()
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  if public.mcp_is_delegated() then
    raise exception 'the disclosure maximum is managed in the Deskilo app, not by an assistant';
  end if;
  perform public.require_database_reviewer();
  return jsonb_build_object(
    'optional_fields', to_jsonb(public.mcp_disclosure_ceiling()),
    'available_fields', to_jsonb(public.mcp_optional_field_names()));
end;
$fn$;
revoke execute on function public.mcp_disclosure_status() from public, anon;
grant execute on function public.mcp_disclosure_status() to authenticated;

-- The database's ceiling: set by a database administrator at AAL2 only.
-- It never widens a policy or a consent; each is still asked.
create or replace function public.set_mcp_disclosure_maximum(p_fields text[])
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_fields text[];
begin
  if public.mcp_is_delegated() then
    raise exception 'the disclosure maximum is managed in the Deskilo app, not by an assistant';
  end if;
  perform public.require_database_reviewer();
  v_fields := public.mcp_clean_optional_fields(p_fields);
  update public.mcp_disclosure_maximum set optional_fields = v_fields where singleton;
  insert into public.database_authority_audit (installation_id, action, actor, detail)
  values (public.installation_id(), 'disclosure_maximum_saved', 'admin:' || auth.uid(),
          jsonb_build_object('optional_fields', to_jsonb(v_fields)));
  return jsonb_build_object('status', 'saved', 'optional_fields', to_jsonb(v_fields));
end;
$fn$;
revoke execute on function public.set_mcp_disclosure_maximum(text[]) from public, anon;
grant execute on function public.set_mcp_disclosure_maximum(text[]) to authenticated;

-- ── the owner's policy ──────────────────────────────────────────────

create or replace function public.mcp_policy_status(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_policy public.workspace_mcp_policies;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not public.is_owner_of(p_workspace_id) then
    raise exception 'only the owner configures MCP exposure';
  end if;
  select * into v_policy from public.workspace_mcp_policies where workspace_id = p_workspace_id;
  return jsonb_build_object(
    'workspace_id', p_workspace_id,
    'revision', coalesce(v_policy.revision, 0),
    'enabled', coalesce(v_policy.enabled, false),
    'operations', to_jsonb(coalesce(v_policy.operations, '{}'::text[])),
    'target_ceiling', coalesce(v_policy.target_ceiling, 'own'),
    'allowed_clients', to_jsonb(v_policy.allowed_clients),
    'optional_fields', to_jsonb(coalesce(v_policy.optional_fields, '{}'::text[])),
    'available_optional_fields', to_jsonb(public.mcp_disclosure_ceiling()),
    'feature_enabled', public.feature_effective(p_workspace_id, 'mcpAccess'),
    'available_operations', (
      select coalesce(jsonb_agg(k order by k), '[]'::jsonb)
        from jsonb_each(public.mcp_operation_catalogue()->'operations') e(k, v)
       where (v->>'dispatch')::boolean));
end;
$fn$;
revoke execute on function public.mcp_policy_status(uuid) from public, anon;
grant execute on function public.mcp_policy_status(uuid) to authenticated;

-- A defaulted parameter: the old overload goes first, or two candidates
-- answer the same call. Null keeps the current fields, so a save that
-- does not know about them never clears them.
drop function if exists public.save_mcp_policy(uuid, integer, uuid, boolean, text[], text, text[]);
create or replace function public.save_mcp_policy(
  p_workspace_id uuid, p_expected_revision integer, p_mutation_id uuid,
  p_enabled boolean, p_operations text[], p_target_ceiling text,
  p_allowed_clients text[] default null, p_optional_fields text[] default null)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_policy public.workspace_mcp_policies;
  v_prior public.workspace_mcp_policy_revisions;
  v_ops text[];
  v_fields text[];
  v_payload jsonb;
  v_op text;
  v_client text;
  v_field text;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if p_mutation_id is null then raise exception 'a policy save needs its mutation id'; end if;
  if not public.is_owner_of(p_workspace_id) then
    raise exception 'only the owner configures MCP exposure';
  end if;
  if p_target_ceiling not in ('own', 'workspace') then
    raise exception 'unknown target ceiling %', p_target_ceiling;
  end if;
  select coalesce(array_agg(distinct o order by o), '{}') into v_ops from unnest(coalesce(p_operations, '{}')) o;
  foreach v_op in array v_ops loop
    if not coalesce((public.mcp_operation_catalogue()->'operations'->v_op->>'dispatch')::boolean, false) then
      raise exception 'unknown or unimplemented operation %', v_op;
    end if;
  end loop;
  if p_allowed_clients is not null then
    foreach v_client in array p_allowed_clients loop
      if not exists (select 1 from public.mcp_clients where client_id = v_client and status = 'active') then
        raise exception 'client % is not approved on this instance', v_client;
      end if;
    end loop;
  end if;
  if p_enabled and not public.feature_effective(p_workspace_id, 'mcpAccess') then
    raise exception 'the MCP feature is off for this workspace';
  end if;

  insert into public.workspace_mcp_policies (workspace_id, installation_id)
  values (p_workspace_id, public.installation_id()) on conflict (workspace_id) do nothing;
  select * into v_policy from public.workspace_mcp_policies where workspace_id = p_workspace_id for update;

  if p_optional_fields is null then
    select coalesce(array_agg(f order by f), '{}') into v_fields from unnest(v_policy.optional_fields) f
     where f = any (public.mcp_optional_field_names());
  else
    v_fields := public.mcp_clean_optional_fields(p_optional_fields);
    foreach v_field in array v_fields loop
      if not (v_field = any (public.mcp_disclosure_ceiling())) then
        raise exception 'field % is above this database''s disclosure maximum', v_field;
      end if;
    end loop;
  end if;
  v_payload := jsonb_build_object('enabled', p_enabled, 'operations', to_jsonb(v_ops),
    'target_ceiling', p_target_ceiling,
    'allowed_clients', to_jsonb((select array_agg(distinct c order by c) from unnest(p_allowed_clients) c)),
    'optional_fields', to_jsonb(v_fields));

  select * into v_prior from public.workspace_mcp_policy_revisions
   where workspace_id = p_workspace_id and mutation_id = p_mutation_id;
  if v_prior.id is not null then
    if v_prior.payload = v_payload then
      return jsonb_build_object('status', 'replayed', 'revision', v_prior.revision);
    end if;
    return jsonb_build_object('status', 'conflict', 'reason', 'mutation_id_reused');
  end if;
  if v_policy.revision <> coalesce(p_expected_revision, -1) then
    return jsonb_build_object('status', 'conflict', 'reason', 'stale_revision',
                              'revision', v_policy.revision);
  end if;

  insert into public.workspace_mcp_policy_revisions (workspace_id, revision, mutation_id, payload, saved_by)
  values (p_workspace_id, v_policy.revision + 1, p_mutation_id, v_payload, auth.uid());
  update public.workspace_mcp_policies
     set revision = v_policy.revision + 1, enabled = p_enabled, operations = v_ops,
         target_ceiling = p_target_ceiling,
         allowed_clients = (select array_agg(distinct c order by c) from unnest(p_allowed_clients) c),
         optional_fields = v_fields
   where workspace_id = p_workspace_id;
  insert into public.database_authority_audit (installation_id, action, actor, detail)
  values (public.installation_id(), 'workspace_policy_saved', 'owner:' || auth.uid(),
          jsonb_build_object('workspace_id', p_workspace_id, 'revision', v_policy.revision + 1));
  return jsonb_build_object('status', 'saved', 'revision', v_policy.revision + 1);
end;
$fn$;
revoke execute on function public.save_mcp_policy(uuid, integer, uuid, boolean, text[], text, text[], text[]) from public, anon;
grant execute on function public.save_mcp_policy(uuid, integer, uuid, boolean, text[], text, text[], text[]) to authenticated;

-- ── the person's consent ────────────────────────────────────────────

-- What this person could consent to, per workspace: the owner's exposed
-- operations their membership and permissions allow, and the optional
-- fields both the owner and the database allow.
create or replace function public.mcp_consent_options()
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_row record;
  v_ops text[];
  v_out jsonb := '[]'::jsonb;
begin
  perform public.mcp_require_native();
  for v_row in
    select w.id, w.name, p.operations, p.optional_fields
      from public.members m
      join public.workspaces w on w.id = m.workspace_id
      join public.workspace_mcp_policies p on p.workspace_id = w.id and p.enabled
     where m.user_id = auth.uid() and m.status = 'active'
       and public.feature_effective(w.id, 'mcpAccess')
     order by w.name, w.id
  loop
    select coalesce(array_agg(o order by o), '{}') into v_ops
      from unnest(v_row.operations) o
     where public.mcp_operation_catalogue()->'operations'->o->>'authority' <> 'permission'
        or public.has_permission(v_row.id, public.mcp_operation_catalogue()->'operations'->o->>'permission');
    if cardinality(v_ops) > 0 then
      v_out := v_out || jsonb_build_object('workspace_id', v_row.id, 'name', v_row.name, 'operations', to_jsonb(v_ops),
        'optional_fields', (select coalesce(jsonb_agg(f order by f), '[]'::jsonb) from unnest(v_row.optional_fields) f
                             where f = any (public.mcp_disclosure_ceiling())));
    end if;
  end loop;
  return jsonb_build_object('eligibility', public.my_database_capabilities()->>'mcp_eligibility',
                            'workspaces', v_out);
end;
$fn$;
revoke execute on function public.mcp_consent_options() from public, anon;
grant execute on function public.mcp_consent_options() to authenticated;

-- The subset the person chose, checked against what they may choose now.
-- A scope without `optional_fields` consents to none.
create or replace function public.mcp_prepare_connection(
  p_client_id text, p_authorization_id text, p_scopes jsonb)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_options jsonb;
  v_scope jsonb;
  v_allowed jsonb;
  v_offered jsonb;
  v_op text;
  v_field text;
  v_fields text[];
  v_clean jsonb := '[]'::jsonb;
begin
  perform public.mcp_require_native();
  if public.my_database_capabilities()->>'mcp_eligibility' <> 'eligible' then
    raise exception 'this database has not approved MCP for you yet';
  end if;
  if not exists (select 1 from public.mcp_clients where client_id = p_client_id and status = 'active') then
    raise exception 'this assistant is not approved on this instance';
  end if;
  if jsonb_typeof(p_scopes) <> 'array' or jsonb_array_length(p_scopes) = 0 then
    raise exception 'choose at least one workspace';
  end if;
  v_options := public.mcp_consent_options()->'workspaces';
  for v_scope in select * from jsonb_array_elements(p_scopes) loop
    v_allowed := null;
    select o->'operations', o->'optional_fields' into v_allowed, v_offered from jsonb_array_elements(v_options) o
     where o->>'workspace_id' = v_scope->>'workspace_id';
    if v_allowed is null then
      raise exception 'workspace % cannot be offered', v_scope->>'workspace_id';
    end if;
    for v_op in select * from jsonb_array_elements_text(coalesce(v_scope->'operations', '[]'::jsonb)) loop
      if not v_allowed ? v_op then raise exception 'operation % is not available there', v_op; end if;
    end loop;
    if jsonb_typeof(coalesce(v_scope->'optional_fields', '[]'::jsonb)) <> 'array' then
      raise exception 'optional fields are a list of names';
    end if;
    v_fields := public.mcp_clean_optional_fields(array(
      select jsonb_array_elements_text(coalesce(v_scope->'optional_fields', '[]'::jsonb))));
    foreach v_field in array v_fields loop
      if not coalesce(v_offered, '[]'::jsonb) ? v_field then
        raise exception 'field % is not offered there', v_field;
      end if;
    end loop;
    v_clean := v_clean || jsonb_build_object('workspace_id', v_scope->>'workspace_id',
      'operations', (select coalesce(jsonb_agg(distinct x order by x), '[]'::jsonb)
                       from jsonb_array_elements_text(coalesce(v_scope->'operations', '[]'::jsonb)) x),
      'optional_fields', to_jsonb(v_fields));
  end loop;
  insert into public.mcp_connection_preparations (installation_id, local_user_id, client_id, authorization_id, scopes)
  values (public.installation_id(), auth.uid(), p_client_id, p_authorization_id, v_clean)
  on conflict (authorization_id) do nothing;
  if not exists (select 1 from public.mcp_connection_preparations
                  where authorization_id = p_authorization_id and local_user_id = auth.uid()
                    and client_id = p_client_id and status = 'prepared' and scopes = v_clean) then
    raise exception 'this authorization was prepared differently';
  end if;
  return jsonb_build_object('status', 'prepared', 'scopes', v_clean);
end;
$fn$;
revoke execute on function public.mcp_prepare_connection(text, text, jsonb) from public, anon;
grant execute on function public.mcp_prepare_connection(text, text, jsonb) to authenticated;

-- After Auth approved: the connection and exactly the chosen scopes,
-- optional fields included (a reconnect replaces them, never merges).
create or replace function public.mcp_finalize_connection(p_authorization_id text)
returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_prep public.mcp_connection_preparations;
  v_binding uuid := public.my_active_binding();
  v_connection uuid;
  v_scope jsonb;
begin
  perform public.mcp_require_native();
  select * into v_prep from public.mcp_connection_preparations
   where authorization_id = p_authorization_id and local_user_id = auth.uid() for update;
  if v_prep.id is null then raise exception 'unknown authorization'; end if;
  if v_prep.status = 'finalized' then return jsonb_build_object('status', 'finalized'); end if;
  if v_prep.status <> 'prepared' or v_prep.expires_at <= now() then
    update public.mcp_connection_preparations set status = 'abandoned' where id = v_prep.id;
    return jsonb_build_object('status', 'expired');
  end if;
  if v_binding is null or public.my_database_capabilities()->>'mcp_eligibility' <> 'eligible' then
    raise exception 'this database has not approved MCP for you';
  end if;
  select id into v_connection from public.mcp_connections
   where installation_id = public.installation_id() and local_user_id = auth.uid()
     and client_id = v_prep.client_id and status = 'active';
  if v_connection is null then
    insert into public.mcp_connections (installation_id, local_user_id, binding_id, client_id)
    values (public.installation_id(), auth.uid(), v_binding, v_prep.client_id)
    returning id into v_connection;
  end if;
  for v_scope in select * from jsonb_array_elements(v_prep.scopes) loop
    -- A chosen workspace-wide operation (issue an invoice, answer a
    -- validation) is consent to act beyond the person's own records; the
    -- owner's policy ceiling still caps it in the dispatcher.
    insert into public.mcp_connection_scopes (connection_id, workspace_id, operations, target_ceiling,
                                              optional_fields, consented_at, revoked_at)
    values (v_connection, (v_scope->>'workspace_id')::uuid,
            array(select jsonb_array_elements_text(v_scope->'operations')),
            case when exists (select 1 from jsonb_array_elements_text(v_scope->'operations') o
                               where o <> 'get_capabilities'
                                 and public.mcp_operation_catalogue()->'operations'->o->>'scope' = 'workspace')
                 then 'workspace' else 'own' end,
            array(select jsonb_array_elements_text(coalesce(v_scope->'optional_fields', '[]'::jsonb))),
            now(), null)
    on conflict (connection_id, workspace_id) do update
      set operations = excluded.operations, target_ceiling = excluded.target_ceiling,
          optional_fields = excluded.optional_fields,
          consented_at = now(), revoked_at = null;
  end loop;
  update public.mcp_connection_preparations set status = 'finalized' where id = v_prep.id;
  return jsonb_build_object('status', 'finalized');
end;
$fn$;
revoke execute on function public.mcp_finalize_connection(text) from public, anon;
grant execute on function public.mcp_finalize_connection(text) to authenticated;

create or replace function public.my_mcp_connections()
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  perform public.mcp_require_native();
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'client_id', c.client_id,
             'client_name', (select name from public.mcp_clients k where k.client_id = c.client_id),
             'connected_at', c.created_at,
             'workspaces', (select coalesce(jsonb_agg(jsonb_build_object('workspace_id', s.workspace_id,
                              'name', (select name from public.workspaces w where w.id = s.workspace_id),
                              'operations', to_jsonb(s.operations),
                              'optional_fields', to_jsonb(s.optional_fields)) order by s.workspace_id), '[]'::jsonb)
                              from public.mcp_connection_scopes s
                             where s.connection_id = c.id and s.revoked_at is null))
           order by c.created_at)
      from public.mcp_connections c
     where c.installation_id = public.installation_id() and c.local_user_id = auth.uid()
       and c.status = 'active'), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.my_mcp_connections() from public, anon;
grant execute on function public.my_mcp_connections() to authenticated;

-- ── the projection ──────────────────────────────────────────────────

-- The optional fields THIS caller's client may receive for this operation
-- in this workspace, from the current rows: the intersection, or none.
create or replace function public.mcp_disclosed_fields(p_operation text, p_workspace_id uuid)
returns text[] language sql stable security definer set search_path = public as $fn$
  select coalesce(array_agg(f order by f), '{}')
    from jsonb_array_elements_text(coalesce(
           public.mcp_operation_catalogue()->'operations'->p_operation->'optional', '[]'::jsonb)) f
   where auth.uid() is not null and p_workspace_id is not null
     and auth.jwt()->>'client_id' is not null
     and f = any (public.mcp_disclosure_ceiling())
     and exists (select 1 from public.workspace_mcp_policies p
                  where p.workspace_id = p_workspace_id and p.enabled and f = any (p.optional_fields))
     and exists (select 1 from public.mcp_connection_scopes s
                   join public.mcp_connections c on c.id = s.connection_id
                  where s.workspace_id = p_workspace_id and s.revoked_at is null
                    and c.installation_id = public.installation_id() and c.local_user_id = auth.uid()
                    and c.client_id = auth.jwt()->>'client_id' and c.status = 'active'
                    and f = any (s.optional_fields));
$fn$;
revoke execute on function public.mcp_disclosed_fields(text, uuid) from public, anon, authenticated;

-- The allow-list plus the disclosed optional fields the operation names.
-- Keys are only kept, never added.
create or replace function public.mcp_project_data(p_operation text, p_value jsonb, p_optional text[])
returns jsonb language plpgsql immutable set search_path = public as $fn$
declare
  v_spec jsonb := public.mcp_operation_catalogue()->'operations'->p_operation;
  v_allowed jsonb;
  v_out jsonb;
  v_key text;
  v_inner jsonb;
begin
  if p_value is null then
    return null;
  end if;
  v_allowed := coalesce(v_spec->'output', '[]'::jsonb)
    || coalesce((select jsonb_agg(f) from jsonb_array_elements_text(coalesce(v_spec->'optional', '[]'::jsonb)) f
                  where f = any (coalesce(p_optional, '{}'))), '[]'::jsonb);
  if jsonb_typeof(p_value) = 'array' then
    select coalesce(jsonb_agg(public.mcp_project_data(p_operation, e, p_optional) order by o), '[]'::jsonb)
      into v_out from jsonb_array_elements(p_value) with ordinality x(e, o);
    return v_out;
  elsif jsonb_typeof(p_value) <> 'object' then
    return p_value;
  end if;
  v_out := '{}'::jsonb;
  for v_key, v_inner in select key, value from jsonb_each(p_value) loop
    if v_allowed ? v_key then
      v_out := v_out || jsonb_build_object(v_key, public.mcp_project_data(p_operation, v_inner, p_optional));
    end if;
  end loop;
  return v_out;
end;
$fn$;
revoke execute on function public.mcp_project_data(text, jsonb, text[]) from public, anon, authenticated;

create or replace function public.mcp_project_data(p_operation text, p_value jsonb)
returns jsonb language sql immutable set search_path = public as $fn$
  select public.mcp_project_data(p_operation, p_value, '{}'::text[]);
$fn$;
revoke execute on function public.mcp_project_data(text, jsonb) from public, anon, authenticated;

-- Stable now: the disclosed set is read from the current layers.
create or replace function public.mcp_envelope(
  p_request_id uuid, p_operation text, p_workspace_id uuid, p_status text,
  p_data jsonb default null, p_code text default null, p_fields jsonb default null)
returns jsonb language sql stable set search_path = public as $fn$
  select jsonb_strip_nulls(jsonb_build_object(
    'schema_version', 1, 'request_id', p_request_id, 'operation', p_operation,
    'workspace_id', p_workspace_id, 'status', p_status,
    'data', public.mcp_project_data(p_operation, p_data,
              case when p_data is null then '{}'::text[]
                   else public.mcp_disclosed_fields(p_operation, p_workspace_id) end),
    'error', case when p_code is null then null
                  else jsonb_strip_nulls(jsonb_build_object('code', p_code, 'fields', p_fields)) end));
$fn$;
revoke execute on function public.mcp_envelope(uuid, text, uuid, text, jsonb, text, jsonb) from public, anon, authenticated;

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text language plpgsql as $f$
begin
  if position(p_old in p_def) = 0 then return null; end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

-- A replay: the stored answer through TODAY's layers, never wider.
do $migration$
declare
  v_def text := pg_get_functiondef('public.mcp_execute_v1(uuid, uuid, text, jsonb, uuid)'::regprocedure);
  v_next text;
begin
  if position('#1645' in v_def) > 0 then
    return;
  end if;
  v_next := pg_temp.anchor_replace(v_def,
    $a$      public.mcp_project_data(p_operation, v_prior.outcome->'data')));$a$,
    $a$      -- #1645 — and through the CURRENT disclosure layers.
      public.mcp_project_data(p_operation, v_prior.outcome->'data',
        public.mcp_disclosed_fields(p_operation, p_workspace_id))));$a$);
  if v_next is null then raise exception '0304: replay anchor not found'; end if;
  execute v_next;
end
$migration$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(304);
