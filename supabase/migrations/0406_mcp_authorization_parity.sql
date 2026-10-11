-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0406 (#2391) -- MCP authorization and parity, measured by one matrix
-- (supabase/tests/database/169_mcp_authorization_matrix.sql).
--
-- * A member reads her own pending requests under the `own` ceiling:
--   list_pending_validations and get_validation become `own` operations;
--   the rows are the ones she made or is the subject of, and the ones she
--   may decide only when her consent reaches the whole workspace.
-- * get_member_statement: an administrator holding viewFinances reads a
--   member's statement, as the app shows it (the same member_statement and
--   its may_view_member_finances rule); a member of another workspace is
--   not_found.
-- * get_availability lists seats and the desks, offices and levels booked
--   as a whole, each with its kind; `kind` filters; "free" is the booking
--   engine's verdict for every kind (mcp_place_bookable).
-- * get_capabilities says why not: `refused` lists every operation the
--   assistant may not use here with not_exposed, no_consent, forbidden or
--   target_ceiling; `operations` no longer lists one the ceiling refuses.
--
-- mcp_read_v1 and mcp_execute_v1 are restated WHOLE (the live bodies after
-- their anchored patches, plus the above): the repository now holds the
-- text that runs.

-- The booking engine's verdict for one place of any kind, as the member,
-- always rolled back (0345's probe, for seats, desks, offices and levels).
create or replace function public.mcp_place_bookable(p_workspace_id uuid, p_seat_id uuid, p_desk_id uuid,
  p_office_id uuid, p_level_id uuid, p_from timestamptz, p_to timestamptz)
returns text language plpgsql volatile set search_path = public as $fn$
begin
  if auth.uid() is null then return 'not authenticated'; end if;
  begin
    perform public.create_reservation(p_workspace_id => p_workspace_id, p_seat_id => p_seat_id,
      p_desk_id => p_desk_id, p_office_id => p_office_id, p_level_id => p_level_id,
      p_starts_at => p_from, p_ends_at => p_to);
    raise exception using errcode = 'P0001', message = 'mcp-availability-probe';
  exception when others then
    return case when sqlerrm = 'mcp-availability-probe' then null else sqlerrm end;
  end;
end;
$fn$;
revoke execute on function public.mcp_place_bookable(uuid, uuid, uuid, uuid, uuid, timestamptz, timestamptz)
  from public, anon, authenticated;

-- Why an operation is not available to this caller here, or null: the
-- facade's own gates, in its order, for get_capabilities.
create or replace function public.mcp_capability_refusal(p_workspace_id uuid, p_operation text,
  p_policy_operations text[], p_scope_operations text[], p_ceiling text)
returns text language sql stable set search_path = public as $fn$
  select case
    when not (p_operation = any (p_policy_operations)) then 'not_exposed'
    when not (p_operation = any (p_scope_operations)) then 'no_consent'
    when s->>'authority' = 'permission' and not public.has_permission(p_workspace_id, s->>'permission')
      then 'forbidden'
    when s->>'scope' = 'workspace' and p_operation <> 'get_capabilities' and p_ceiling <> 'workspace'
      then 'target_ceiling'
  end
  from (select public.mcp_operation_catalogue()->'operations'->p_operation as s) q;
$fn$;
revoke execute on function public.mcp_capability_refusal(uuid, text, text[], text[], text)
  from public, anon, authenticated;

create or replace function public.mcp_read_v1(p_workspace_id uuid, p_member public.members, p_operation text, p_args jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_limit integer := least(greatest(coalesce((p_args->>'limit')::integer, 25), 1), 100);
  v_from timestamptz;
  v_to timestamptz;
  v_after_at timestamptz;
  v_after_id uuid;
  v_rows jsonb;
  v_count integer;
  v_last jsonb;
  v_event public.events;
  v_can boolean;
  v_reason text;
  v_level uuid;
  v_office uuid;
  v_kind text;
  v_page jsonb;
  v_more boolean;
  -- #2391 — beyond her own rows only when her consent reaches the
  -- workspace (the facade always says which; a direct definer call is the
  -- service role's).
  v_wide boolean := coalesce(p_args->>'_ceiling', 'workspace') = 'workspace';
begin
  select at, id into v_after_at, v_after_id
    from public.mcp_cursor_position(p_args->>'cursor', p_operation, p_workspace_id);

  if p_operation in ('get_availability', 'list_my_reservations') then
    v_from := public.mcp_time_arg(p_args, case when p_operation = 'get_availability' then 'starts_at' else 'from' end);
    v_to := public.mcp_time_arg(p_args, case when p_operation = 'get_availability' then 'ends_at' else 'to' end);
    if v_to <= v_from or v_to - v_from > interval '31 days' then
      return jsonb_build_object('refused', 'validation_error', 'code', 'window');
    end if;
  end if;

  if p_operation = 'list_my_reservations' then
    select coalesce(jsonb_agg(r order by (r->>'starts_at')::timestamptz, r->>'reservation_id'), '[]'::jsonb) into v_rows
      from (
        select jsonb_build_object('reservation_id', x.id, 'seat_id', x.seat_id, 'desk_id', x.desk_id,
                 'office_id', x.office_id, 'level_id', x.level_id,
                 'label', public.mcp_place_label(x.seat_id, x.desk_id, x.office_id, x.level_id),
                 'starts_at', x.starts_at, 'ends_at', x.ends_at, 'status', x.status) as r
          from public.reservations x
         where x.workspace_id = p_workspace_id and x.member_id = p_member.id
           and x.starts_at < v_to and x.ends_at > v_from
           and (v_after_at is null or (x.starts_at, x.id) > (v_after_at, v_after_id))
         order by x.starts_at, x.id
         limit v_limit + 1) q;
    v_count := jsonb_array_length(v_rows);
    if v_count > v_limit then
      v_rows := v_rows - v_limit;
      v_last := v_rows->(v_limit - 1);
      return jsonb_build_object('items', v_rows, 'next_cursor',
        public.mcp_cursor(p_operation, p_workspace_id, (v_last->>'starts_at')::timestamptz, (v_last->>'reservation_id')::uuid));
    end if;
    return jsonb_build_object('items', v_rows, 'next_cursor', null);
  end if;

  if p_operation = 'get_availability' then
    -- #2145 — optionally one level or one office; #2391 — every kind the app
    -- books (seats, and desks, offices and levels booked as a whole),
    -- optionally one kind. A page is the next place ids in order; it is
    -- shown by label, and the cursor follows the ids it paged by. "free" is
    -- the booking engine's own verdict (0345), asked only for this page.
    v_level := public.mcp_uuid_arg(p_args, 'level_id', false);
    v_office := public.mcp_uuid_arg(p_args, 'office_id', false);
    v_kind := nullif(p_args->>'kind', '');
    if v_kind is not null and v_kind not in ('seat', 'desk', 'office', 'level') then
      raise exception using errcode = '22023', message = 'kind';
    end if;
    select coalesce(jsonb_agg(to_jsonb(q) order by q.id), '[]'::jsonb) into v_page
      from (select p.*
              from (select 'seat' as kind, s.id, s.id as seat_id, d.id as desk_id, o.id as office_id,
                           o.level_id, s.name
                      from public.seats s
                      join public.desks d on d.id = s.desk_id
                      join public.offices o on o.id = d.office_id
                     where s.workspace_id = p_workspace_id
                    union all
                    select 'desk', d.id, null, d.id, o.id, o.level_id, d.name
                      from public.desks d
                      join public.offices o on o.id = d.office_id
                     where d.workspace_id = p_workspace_id and d.bookable_as_whole
                    union all
                    select 'office', o.id, null, null, o.id, o.level_id, o.name
                      from public.offices o
                     where o.workspace_id = p_workspace_id and o.bookable_as_whole
                    union all
                    select 'level', l.id, null, null, null, l.id, l.name
                      from public.levels l
                     where l.workspace_id = p_workspace_id and l.bookable_as_whole) p
             where (v_kind is null or p.kind = v_kind)
               and (v_level is null or p.level_id = v_level)
               and (v_office is null or p.office_id = v_office)
               and (v_after_id is null or p.id > v_after_id)
             order by p.id
             limit v_limit + 1) q;
    v_more := jsonb_array_length(v_page) > v_limit;
    if v_more then
      v_page := v_page - v_limit;
    end if;
    select coalesce(jsonb_agg(r order by r->>'label', r->>'kind', coalesce(r->>'seat_id', r->>'desk_id',
                                 r->>'office_id', r->>'level_id')), '[]'::jsonb) into v_rows
      from (
        select jsonb_build_object('kind', x.kind, 'seat_id', x.seat_id, 'desk_id', x.desk_id,
                 'office_id', x.office_id, 'level_id', x.level_id,
                 'label', public.mcp_place_label(x.seat_id,
                            case when x.kind = 'desk' then x.desk_id end,
                            case when x.kind = 'office' then x.office_id end,
                            case when x.kind = 'level' then x.level_id end),
                 'name', x.name,
                 'free', public.mcp_place_bookable(p_workspace_id, x.seat_id,
                            case when x.kind = 'desk' then x.desk_id end,
                            case when x.kind = 'office' then x.office_id end,
                            case when x.kind = 'level' then x.level_id end, v_from, v_to) is null) as r
          from jsonb_to_recordset(v_page) as x(kind text, id uuid, seat_id uuid, desk_id uuid,
                                               office_id uuid, level_id uuid, name text)) q;
    return jsonb_build_object('window', jsonb_build_object('starts_at', v_from, 'ends_at', v_to),
      'observed_at', now(), 'items', v_rows,
      'next_cursor', case when v_more then
        public.mcp_cursor(p_operation, p_workspace_id, now(),
          (v_page->(jsonb_array_length(v_page) - 1)->>'id')::uuid) end,
      'not_checked', jsonb_build_array('price', 'approval'));
  end if;

  if p_operation = 'list_my_invoices' then
    select coalesce(jsonb_agg(r order by (r->>'issued_at')::timestamptz desc, r->>'invoice_id' desc), '[]'::jsonb) into v_rows
      from (
        select jsonb_build_object('invoice_id', i.id, 'number', i.number, 'period', i.period,
                 'kind', i.kind, 'total_cents', i.total_cents, 'currency', i.currency,
                 'issued_at', i.issued_at, 'voided', i.voided_at is not null) as r
          from public.invoices i
         where i.workspace_id = p_workspace_id and i.member_id = p_member.id
           and (v_after_at is null or (i.issued_at, i.id) < (v_after_at, v_after_id))
         order by i.issued_at desc, i.id desc
         limit v_limit + 1) q;
    v_count := jsonb_array_length(v_rows);
    if v_count > v_limit then
      v_rows := v_rows - v_limit;
      v_last := v_rows->(v_limit - 1);
      return jsonb_build_object('items', v_rows, 'next_cursor',
        public.mcp_cursor(p_operation, p_workspace_id, (v_last->>'issued_at')::timestamptz, (v_last->>'invoice_id')::uuid));
    end if;
    return jsonb_build_object('items', v_rows, 'next_cursor', null);
  end if;

  if p_operation = 'list_pending_validations' then
    -- Pending events the caller authored or is the subject of; under a
    -- workspace ceiling also the ones she may answer.
    select coalesce(jsonb_agg(r order by (r->>'requested_at')::timestamptz, r->>'event_id'), '[]'::jsonb) into v_rows
      from (
        select jsonb_build_object('event_id', e.id, 'type', e.type, 'requested_at', e.created_at,
                 'mine', e.actor_member_id = p_member.id or e.subject_member_id = p_member.id) as r
          from public.events e
         where e.workspace_id = p_workspace_id and e.status = 'pending'
           and (e.actor_member_id = p_member.id or e.subject_member_id = p_member.id
                or (v_wide and (p_member.is_owner or p_member.is_admin
                                or public.may_validate_event_type(p_workspace_id, e.type))))
           and (v_after_at is null or (e.created_at, e.id) > (v_after_at, v_after_id))
         order by e.created_at, e.id
         limit v_limit + 1) q;
    v_count := jsonb_array_length(v_rows);
    if v_count > v_limit then
      v_rows := v_rows - v_limit;
      v_last := v_rows->(v_limit - 1);
      return jsonb_build_object('items', v_rows, 'next_cursor',
        public.mcp_cursor(p_operation, p_workspace_id, (v_last->>'requested_at')::timestamptz, (v_last->>'event_id')::uuid));
    end if;
    return jsonb_build_object('items', v_rows, 'next_cursor', null);
  end if;

  if p_operation = 'get_validation' then
    select * into v_event from public.events
     where id = public.mcp_uuid_arg(p_args, 'event_id') and workspace_id = p_workspace_id;
    if v_event.id is null
       or not (v_event.actor_member_id = p_member.id or v_event.subject_member_id = p_member.id
               or (v_wide and (p_member.is_owner or p_member.is_admin
                               or public.may_validate_event_type(p_workspace_id, v_event.type)))) then
      return jsonb_build_object('refused', 'not_found', 'code', 'not_found');
    end if;
    v_can := false;
    if v_event.status = 'pending' then
      begin
        perform public.respond_to_event(v_event.id, true);
        raise exception using errcode = 'P0002', message = 'mcp preview';
      exception
        when no_data_found then
          v_can := sqlerrm = 'mcp preview';
        when raise_exception then
          v_reason := left(sqlerrm, 120);
        when others then
          v_reason := 'unavailable';
      end;
    end if;
    return jsonb_build_object(
      'event_id', v_event.id, 'type', v_event.type, 'status', v_event.status,
      'requested_at', v_event.created_at,
      'decisions', (select count(*) from public.event_decisions d where d.event_id = v_event.id),
      'can_respond', v_can, 'reason', v_reason);
  end if;

  if p_operation = 'list_my_favorites' then
    return public.mcp_favorites_v1(p_workspace_id);
  end if;
  if p_operation = 'get_place' then
    return public.mcp_place_v1(p_workspace_id, p_member, p_args);
  end if;

  return jsonb_build_object('refused', 'validation_error', 'code', 'unknown_operation');
end;
$fn$;
revoke execute on function public.mcp_read_v1(uuid, public.members, text, jsonb) from public, anon, authenticated;

create or replace function public.mcp_execute_v1(p_installation_id uuid, p_workspace_id uuid, p_operation text,
                                                 p_arguments jsonb, p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_spec jsonb := public.mcp_operation_catalogue()->'operations'->p_operation;
  v_args jsonb := coalesce(p_arguments, '{}'::jsonb);
  v_client text := auth.jwt()->>'client_id';
  v_binding uuid;
  v_grant public.mcp_eligibility_grants;
  v_connection public.mcp_connections;
  v_policy public.workspace_mcp_policies;
  v_scope public.mcp_connection_scopes;
  v_member public.members;
  v_ceiling text;
  v_prior public.mcp_idempotency;
  v_confirmation public.mcp_action_confirmations;
  v_target jsonb;
  v_digest text;
  v_data jsonb;
  v_result jsonb;
  v_reservation public.reservations;
  v_id uuid;
  v_status text;
  v_code text;
  v_ops jsonb;
  v_refused jsonb;
  v_retry integer;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if v_spec is null or not (v_spec->>'dispatch')::boolean then
    return public.mcp_usage_note(v_spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'validation_error', null, 'unknown_operation'));
  end if;
  if p_installation_id is distinct from public.installation_id() then
    return public.mcp_usage_note(v_spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'denied', null, 'wrong_installation'));
  end if;
  if not (select enabled from public.mcp_runtime) then
    return public.mcp_usage_note(v_spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'denied', null, 'runtime_disabled'));
  end if;
  if v_client is null then
    return public.mcp_usage_note(v_spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'denied', null, 'no_client'));
  end if;
  v_binding := public.my_active_binding();
  if v_binding is null then
    return public.mcp_usage_note(v_spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'denied', null, 'no_identity'));
  end if;
  if not public.mcp_has_google_identity() then
    return public.mcp_usage_note(v_spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'denied', null, 'no_google_identity'));
  end if;
  select * into v_grant from public.mcp_eligibility_grants
   where installation_id = public.installation_id() and local_user_id = auth.uid()
     and binding_id = v_binding and status = 'active' and expires_at > now()
   for share;
  if v_grant.id is null then
    return public.mcp_usage_note(v_spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'denied', null, 'not_eligible'));
  end if;
  select * into v_connection from public.mcp_connections
   where installation_id = public.installation_id() and local_user_id = auth.uid()
     and binding_id = v_binding and client_id = v_client and status = 'active';
  if v_connection.id is null or not exists (select 1 from public.mcp_clients
                                             where client_id = v_client and status = 'active') then
    return public.mcp_usage_note(v_spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'denied', null, 'no_connection'));
  end if;
  select * into v_policy from public.workspace_mcp_policies where workspace_id = p_workspace_id for share;
  if v_policy.workspace_id is null or not v_policy.enabled
     or not public.feature_effective(p_workspace_id, 'mcpAccess')
     or not (p_operation = any (v_policy.operations))
     or (v_policy.allowed_clients is not null and not (v_client = any (v_policy.allowed_clients))) then
    return public.mcp_usage_note(v_spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'denied', null, 'not_exposed'));
  end if;
  select * into v_scope from public.mcp_connection_scopes
   where connection_id = v_connection.id and workspace_id = p_workspace_id and revoked_at is null
   for share;
  if v_scope.connection_id is null or not (p_operation = any (v_scope.operations)) then
    return public.mcp_usage_note(v_spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'denied', null, 'no_consent'));
  end if;
  begin
    v_member := public.my_active_member(p_workspace_id);
  exception when others then
    return public.mcp_usage_note(v_spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'denied', null, 'not_a_member'));
  end;
  if v_spec->>'authority' = 'permission'
     and not public.has_permission(p_workspace_id, v_spec->>'permission') then
    return public.mcp_usage_note(v_spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'denied', null, 'forbidden'));
  end if;
  v_ceiling := case when v_policy.target_ceiling = 'workspace' and v_scope.target_ceiling = 'workspace'
                    then 'workspace' else 'own' end;
  if v_spec->>'scope' = 'workspace' and p_operation <> 'get_capabilities' and v_ceiling <> 'workspace' then
    return public.mcp_usage_note(v_spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'denied', null, 'target_ceiling'));
  end if;
  -- #1630 — a read is limited once authorised, before any work.
  if v_spec->>'mutation' = 'read' then
    v_retry := public.mcp_limit_retry_after(p_workspace_id, v_client, false);
    if v_retry is not null then
      return public.mcp_usage_note(v_spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'rate_limited', null, 'rate_limited')
             || jsonb_build_object('data', jsonb_build_object('retry_after', v_retry)));
    end if;
  end if;
  if v_spec->>'mutation' = 'read' then
    begin
      if p_operation = 'get_capabilities' then
        -- #2391 — what it may do here, and for everything else why not.
        select coalesce(jsonb_agg(o order by o), '[]'::jsonb) into v_ops
          from unnest(v_policy.operations) o
         where public.mcp_capability_refusal(p_workspace_id, o, v_policy.operations, v_scope.operations, v_ceiling) is null;
        select coalesce(jsonb_agg(jsonb_build_object('operation', k, 'reason', r) order by k), '[]'::jsonb) into v_refused
          from (select k, public.mcp_capability_refusal(p_workspace_id, k, v_policy.operations, v_scope.operations, v_ceiling) r
                  from jsonb_each(public.mcp_operation_catalogue()->'operations') e(k, s)
                 where (s->>'dispatch')::boolean) q
         where r is not null;
        v_data := jsonb_build_object('operations', v_ops, 'refused', v_refused, 'target_ceiling', v_ceiling,
                                     'eligible_until', v_grant.expires_at)
                  || public.mcp_workspace_context(p_workspace_id);
      elsif p_operation in ('get_my_statement', 'get_member_statement') then
        if p_operation = 'get_my_statement' then
          if v_args ? 'member_id' and public.mcp_uuid_arg(v_args, 'member_id') <> v_member.id then -- #2145
            return public.mcp_usage_note(v_spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'not_found', null, 'not_found'));
          end if;
          v_id := v_member.id;
        else
          -- #2391 — viewFinances (checked above) reads a member of THIS workspace.
          select m.id into v_id from public.members m
           where m.id = public.mcp_uuid_arg(v_args, 'member_id') and m.workspace_id = p_workspace_id;
          if v_id is null then
            return public.mcp_usage_note(v_spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'not_found', null, 'not_found'));
          end if;
        end if;
        if coalesce(v_args->>'period', '') !~ '^\d{4}-(0[1-9]|1[0-2])$' then
          return public.mcp_usage_note(v_spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'validation_error',
                                     null, 'invalid_arguments', jsonb_build_object('period', 'invalid_month')));
        end if;
        v_data := public.member_statement(v_id, v_args->>'period')
          || jsonb_build_object('currency', (select w.currency_code from public.workspaces w where w.id = p_workspace_id))
          || case when p_operation = 'get_member_statement' then jsonb_build_object('member_id', v_id)
                  else '{}'::jsonb end;
      else
        v_data := public.mcp_read_v1(p_workspace_id, v_member, p_operation,
          (v_args - '_ceiling') || jsonb_build_object('_ceiling', v_ceiling));
        if v_data ? 'refused' then
          return public.mcp_usage_note(v_spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id,
            v_data->>'refused', null, v_data->>'code'));
        end if;
      end if;
    exception when invalid_parameter_value or invalid_text_representation or invalid_datetime_format then
      return public.mcp_usage_note(v_spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'validation_error',
                                 null, 'invalid_arguments'));
    end;
    return public.mcp_usage_note(v_spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'completed', v_data));
  end if;
  if p_request_id is null then
    return public.mcp_usage_note(v_spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'validation_error',
                               null, 'invalid_arguments', jsonb_build_object('request_id', 'required')));
  end if;
  v_digest := md5(p_workspace_id::text || '|' || p_operation || '|' || (v_args - 'request_id')::text);
  perform pg_advisory_xact_lock(hashtextextended(
    public.installation_id()::text || auth.uid()::text || v_client || p_request_id::text, 1612));
  select * into v_prior from public.mcp_idempotency
   where installation_id = public.installation_id() and local_user_id = auth.uid()
     and client_id = v_client and request_id = p_request_id;
  if v_prior.id is not null then
    if v_prior.workspace_id <> p_workspace_id or v_prior.operation <> p_operation
       or v_prior.args_digest <> v_digest then
      return public.mcp_usage_note(v_spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'conflict', null, 'request_id_reused'));
    end if;
    -- #1644 — the stored answer, through TODAY's allow-list.
    return v_prior.outcome || jsonb_strip_nulls(jsonb_build_object('data',
      -- #1645 — and through the CURRENT disclosure layers.
      public.mcp_project_data(p_operation, v_prior.outcome->'data',
        public.mcp_disclosed_fields(p_operation, p_workspace_id))));
  end if;
  -- #1630 — a mutation is limited after the replay (a replay is not a
  -- new call) and before confirmation or any business work.
  v_retry := public.mcp_limit_retry_after(p_workspace_id, v_client, true);
  if v_retry is not null then
    return public.mcp_usage_note(v_spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'rate_limited', null, 'rate_limited')
           || jsonb_build_object('data', jsonb_build_object('retry_after', v_retry)));
  end if;
  if v_spec->>'confirmation' = 'native' then
    select * into v_confirmation from public.mcp_action_confirmations
     where installation_id = public.installation_id() and local_user_id = auth.uid()
       and client_id = v_client and request_id = p_request_id
     for update;
    begin
      v_target := public.mcp_target(p_workspace_id, p_operation, v_args);
    exception when invalid_parameter_value or invalid_text_representation then
      return public.mcp_usage_note(v_spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'validation_error', null, 'invalid_arguments'));
    end;
    if v_target is null then
      return public.mcp_usage_note(v_spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'not_found', null, 'not_found'));
    end if;
    if v_confirmation.id is null then
      insert into public.mcp_action_confirmations (installation_id, local_user_id, client_id,
        workspace_id, eligibility_grant_id, operation, request_id, args_digest, target_revision, preview)
      values (public.installation_id(), auth.uid(), v_client, p_workspace_id, v_grant.id,
              p_operation, p_request_id, v_digest, coalesce(v_target->>'revision', ''),
              jsonb_build_object('arguments', v_args - 'request_id', 'target', v_target - 'revision'))
      returning * into v_confirmation;
      return public.mcp_usage_note(v_spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'requires_confirmation',
        jsonb_build_object('confirmation_id', v_confirmation.id, 'expires_at', v_confirmation.expires_at)));
    end if;
    if v_confirmation.workspace_id <> p_workspace_id or v_confirmation.operation <> p_operation
       or v_confirmation.args_digest <> v_digest then
      return public.mcp_usage_note(v_spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'conflict', null, 'request_id_reused'));
    end if;
    if v_confirmation.eligibility_grant_id <> v_grant.id
       or coalesce(v_target->>'revision', '') <> v_confirmation.target_revision then
      update public.mcp_action_confirmations set status = 'revoked'
       where id = v_confirmation.id and status in ('pending', 'acknowledged');
      return public.mcp_usage_note(v_spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'conflict', null, 'confirmation_stale'));
    end if;
    if v_confirmation.status = 'pending' and v_confirmation.expires_at > now() then
      return public.mcp_usage_note(v_spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'requires_confirmation',
        jsonb_build_object('confirmation_id', v_confirmation.id, 'expires_at', v_confirmation.expires_at)));
    end if;
    if v_confirmation.status <> 'acknowledged' or v_confirmation.expires_at <= now() then
      return public.mcp_usage_note(v_spec, public.mcp_envelope(p_request_id, p_operation, p_workspace_id, 'denied', null,
        case when v_confirmation.status = 'declined' then 'confirmation_declined' else 'confirmation_expired' end));
    end if;
    update public.mcp_action_confirmations set status = 'consumed', consumed_at = now()
     where id = v_confirmation.id;
  end if;
  v_status := 'completed';
  begin
    if p_operation in ('update_reservation', 'check_in', 'check_out', 'cancel_reservation',
                         'request_reservation_deletion') then
      select * into v_reservation from public.reservations
       where id = public.mcp_uuid_arg(v_args, 'reservation_id')
         and workspace_id = p_workspace_id and member_id = v_member.id
         for update;
      if v_reservation.id is null then
        v_status := 'not_found'; v_code := 'not_found';
      elsif v_args ? 'expected_state'
            and v_args->>'expected_state' is distinct from public.mcp_reservation_digest(v_reservation.id) then
        v_status := 'conflict'; v_code := 'stale';
        v_data := public.mcp_reservation_view(v_reservation.id);
      end if;
    end if;
    if v_status = 'completed' then
      if p_operation in ('create_reservation', 'update_reservation') then
        v_args := public.mcp_apply_period(p_workspace_id, v_args);
      end if;
      if p_operation = 'create_reservation' then
        v_id := public.create_reservation_once(p_request_id, p_workspace_id,
          public.mcp_uuid_arg(v_args, 'seat_id', false), public.mcp_uuid_arg(v_args, 'desk_id', false),
          public.mcp_uuid_arg(v_args, 'office_id', false), public.mcp_uuid_arg(v_args, 'level_id', false),
          public.mcp_time_arg(v_args, 'starts_at'), public.mcp_time_arg(v_args, 'ends_at'),
          coalesce((v_args->>'check_in')::boolean, false));
        v_data := jsonb_build_object('reservation_id', v_id);
        perform public.mcp_record_reservation_origin(v_id, p_workspace_id, v_member.id, v_client, p_request_id);
      elsif p_operation = 'update_reservation' then
        perform public.update_reservation(v_reservation.id,
          public.mcp_time_arg(v_args, 'starts_at'), public.mcp_time_arg(v_args, 'ends_at'));
      elsif p_operation = 'check_in' then
        perform public.check_in_reservation(v_reservation.id);
      elsif p_operation = 'check_out' then
        perform public.check_out_reservation(v_reservation.id);
      elsif p_operation = 'cancel_reservation' then
        perform public.cancel_reservation(v_reservation.id);
      elsif p_operation in ('set_favorite', 'rate_place') then
        v_data := public.mcp_place_feedback_write(p_workspace_id, p_operation, v_args);
      elsif p_operation = 'request_reservation_deletion' then
        v_id := public.request_reservation_deletion(v_reservation.id, left(coalesce(v_args->>'reason', ''), 500));
        v_data := jsonb_build_object('event_id', v_id);
        if (select status from public.events where id = v_id) = 'pending' then
          v_status := 'pending_validation';
        end if;
      elsif p_operation = 'request_invoice_issue' then
        v_result := public.request_invoice_issue(p_workspace_id, public.mcp_uuid_arg(v_args, 'member_id'),
          v_args->>'period', coalesce(v_args->>'kind', 'full'));
        v_status := public.mcp_request_outcome(v_result);
        v_data := jsonb_strip_nulls(jsonb_build_object('event_id', v_result->'event_id', 'invoice_id', v_result->'invoice_id'));
      elsif p_operation = 'request_invoice_void' then
        v_result := public.request_invoice_void(public.mcp_uuid_arg(v_args, 'invoice_id'),
          left(coalesce(v_args->>'reason', ''), 500));
        v_status := public.mcp_request_outcome(v_result);
        v_data := jsonb_strip_nulls(jsonb_build_object('event_id', v_result->'event_id'));
      elsif p_operation = 'request_refund' then
        v_result := public.request_refund(public.mcp_uuid_arg(v_args, 'invoice_id'),
          left(coalesce(v_args->>'note', ''), 500));
        v_status := public.mcp_request_outcome(v_result);
        v_data := jsonb_strip_nulls(jsonb_build_object('event_id', v_result->'event_id'));
      elsif p_operation = 'request_member_status_change'
            and (select status from public.members where id = public.mcp_uuid_arg(v_args, 'member_id'))
                = v_args->>'status' then
        v_data := jsonb_build_object('unchanged', true);
      elsif p_operation = 'request_member_status_change' then
        v_result := public.request_member_status_change(public.mcp_uuid_arg(v_args, 'member_id'), v_args->>'status');
        v_status := public.mcp_request_outcome(v_result);
        v_data := jsonb_strip_nulls(jsonb_build_object('event_id', v_result->'event_id'));
      elsif p_operation = 'request_subscription_change'
            and (select subscription_pct from public.members where id = public.mcp_uuid_arg(v_args, 'member_id'))
                = (v_args->>'pct')::integer then
        v_data := jsonb_build_object('unchanged', true);
      elsif p_operation = 'request_subscription_change' then
        v_result := public.request_subscription_change(public.mcp_uuid_arg(v_args, 'member_id'),
          (v_args->>'pct')::integer);
        v_status := public.mcp_request_outcome(v_result);
        v_data := jsonb_strip_nulls(jsonb_build_object('event_id', v_result->'event_id'));
      elsif p_operation = 'respond_to_validation' then
        perform public.respond_to_event(public.mcp_uuid_arg(v_args, 'event_id'),
          (v_args->>'accept')::boolean);
        v_data := jsonb_build_object('event_id', public.mcp_uuid_arg(v_args, 'event_id'),
          'event_status', (select status from public.events where id = public.mcp_uuid_arg(v_args, 'event_id')),
          'decision_recorded', exists (select 1 from public.event_decisions d
                                        where d.event_id = public.mcp_uuid_arg(v_args, 'event_id')
                                          and d.member_id = v_member.id),
          'effect_applied', (select status from public.events where id = public.mcp_uuid_arg(v_args, 'event_id'))
                            in ('applied', 'confirmed'));
        if v_data->>'event_status' = 'pending' then
          v_status := 'pending_validation';
        end if;
      end if;
      if p_operation in ('request_member_status_change', 'request_subscription_change') then
        v_data := coalesce(v_data, '{}'::jsonb)
                  || coalesce(public.mcp_member_view(public.mcp_uuid_arg(v_args, 'member_id')), '{}'::jsonb);
      end if;
      if p_operation in ('request_invoice_issue', 'request_invoice_void', 'request_refund') then
        if p_operation = 'request_invoice_issue' and v_status = 'completed'
           and public.mcp_invoice_view((v_data->>'invoice_id')::uuid) is null then
          raise exception 'the invoice could not be read back';
        end if;
        v_data := coalesce(v_data, '{}'::jsonb) || coalesce(public.mcp_invoice_view(coalesce(
          (v_data->>'invoice_id')::uuid, public.mcp_uuid_arg(v_args, 'invoice_id', false))), '{}'::jsonb);
      end if;
      if p_operation in ('create_reservation', 'update_reservation', 'check_in', 'check_out',
                         'cancel_reservation', 'request_reservation_deletion') then
        if public.mcp_reservation_view(case when p_operation = 'create_reservation' then v_id
                                            else v_reservation.id end) is null then
          raise exception 'the reservation could not be read back';
        end if;
        v_data := coalesce(v_data, '{}'::jsonb) || public.mcp_reservation_view(
          case when p_operation = 'create_reservation' then v_id else v_reservation.id end);
      end if;
    end if;
  exception
    when invalid_parameter_value or invalid_text_representation or invalid_datetime_format then
      v_status := 'validation_error'; v_code := 'invalid_arguments'; v_data := null;
    when raise_exception or check_violation or exclusion_violation or unique_violation then
      v_status := 'conflict'; v_code := 'refused'; v_data := jsonb_build_object('reason', case when sqlstate = 'P0001' then left(sqlerrm, 200) end);
  end;
  v_data := public.mcp_envelope(p_request_id, p_operation, p_workspace_id, v_status, v_data, v_code);
  if v_status <> 'validation_error' then
    insert into public.mcp_idempotency (installation_id, local_user_id, client_id, request_id,
      workspace_id, operation, args_digest, status, outcome)
    values (public.installation_id(), auth.uid(), v_client, p_request_id, p_workspace_id,
            p_operation, v_digest,
            case when v_status in ('completed', 'pending_validation') then 'applied' else 'refused' end, v_data);
  end if;
  return public.mcp_usage_note(v_spec, v_data);
end;
$fn$;
revoke execute on function public.mcp_execute_v1(uuid, uuid, text, jsonb, uuid) from public, anon;
grant execute on function public.mcp_execute_v1(uuid, uuid, text, jsonb, uuid) to authenticated;

create or replace function public.mcp_operation_catalogue()
returns jsonb
language sql
immutable
set search_path = public
as $catalogue$
  select $json${"version":1,"operations":{"list_workspaces":{"rpc":null,"dispatch":false,"authority":"self","permission":null,"features":[],"scope":"discovery","mutation":"read","confirmation":"none","output":["confirmation_id","expires_at","operations","reason","unchanged","workspace_id"],"optional":["name"]},"get_capabilities":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none","output":["afternoon","booking_periods","confirmation_id","currency","eligible_until","expires_at","from","full_day","granularity","half_boundary","morning","open_weekdays","opening_hours","operation","operations","reason","refused","target_ceiling","time_zone","to","unchanged","work_end","work_start"],"optional":[]},"get_availability":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"read","confirmation":"none","output":["confirmation_id","desk_id","ends_at","expires_at","free","items","kind","label","level_id","next_cursor","not_checked","observed_at","office_id","reason","seat_id","starts_at","unchanged","window"],"optional":["name"]},"list_my_reservations":{"rpc":null,"dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"read","confirmation":"none","output":["confirmation_id","desk_id","ends_at","expires_at","items","label","level_id","next_cursor","office_id","reason","reservation_id","seat_id","starts_at","status","unchanged"],"optional":[]},"get_place":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"read","confirmation":"none","output":["amenities","average","bookable_as_whole","confirmation_id","count","desk_id","expires_at","favorite","image_available","image_requested","kind","label","level_id","mine","office_id","rating","reason","render","reservation_id","seat_id","seats","unchanged"],"optional":["name"]},"list_my_favorites":{"rpc":null,"dispatch":true,"authority":"self","permission":null,"features":["mcpAccess","placeFeedback"],"scope":"own","mutation":"read","confirmation":"none","output":["average","confirmation_id","count","expires_at","favorite","items","kind","label","mine","rating","reason","resource_id","unchanged"],"optional":[]},"get_my_statement":{"rpc":"member_statement","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess","moneyTab"],"scope":"own","mutation":"read","confirmation":"none","output":["accessory_supplement_by_rate","accessory_supplement_cents","active","amount_cents","balance_cents","confirmation_id","credits_cents","currency","default_fee_cents","default_overage_fee_cents","desk_supplement_cents","discount_percent","expires_at","extra_half_days","fee_cents","granted_half_days","included_half_days","level_supplement_cents","negotiated","office_supplement_cents","open_days","overage_cents","overage_fee_cents","overage_policy","overage_rate_cents","period","reason","remaining_half_days","subscription_pct","unchanged","used_half_days","valid_from","vat_percent"],"optional":[]},"get_member_statement":{"rpc":"member_statement","dispatch":true,"authority":"permission","permission":"viewFinances","features":["mcpAccess","moneyTab"],"scope":"workspace","mutation":"read","confirmation":"none","output":["accessory_supplement_by_rate","accessory_supplement_cents","active","amount_cents","balance_cents","confirmation_id","credits_cents","currency","default_fee_cents","default_overage_fee_cents","desk_supplement_cents","discount_percent","expires_at","extra_half_days","fee_cents","granted_half_days","included_half_days","level_supplement_cents","member_id","negotiated","office_supplement_cents","open_days","overage_cents","overage_fee_cents","overage_policy","overage_rate_cents","period","reason","remaining_half_days","subscription_pct","unchanged","used_half_days","valid_from","vat_percent"],"optional":[]},"list_my_invoices":{"rpc":null,"dispatch":true,"authority":"self","permission":null,"features":["mcpAccess","invoicing"],"scope":"own","mutation":"read","confirmation":"none","output":["confirmation_id","currency","expires_at","invoice_id","issued_at","items","kind","next_cursor","number","period","reason","total_cents","unchanged","voided"],"optional":[]},"create_reservation":{"rpc":"create_reservation_once","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"update_reservation":{"rpc":"update_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"check_in":{"rpc":"check_in_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"check_out":{"rpc":"check_out_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"cancel_reservation":{"rpc":"cancel_reservation","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"write","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"set_favorite":{"rpc":null,"dispatch":true,"authority":"self","permission":null,"features":["mcpAccess","placeFeedback"],"scope":"own","mutation":"write","confirmation":"none","output":["average","confirmation_id","count","expires_at","favorite","mine","reason","unchanged"],"optional":[]},"rate_place":{"rpc":null,"dispatch":true,"authority":"self","permission":null,"features":["mcpAccess","placeFeedback"],"scope":"own","mutation":"write","confirmation":"none","output":["average","confirmation_id","count","expires_at","favorite","mine","reason","unchanged"],"optional":[]},"request_reservation_deletion":{"rpc":"request_reservation_deletion","dispatch":true,"authority":"self","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"request","confirmation":"none","output":["checked_in_at","checked_out_at","confirmation_id","desk_id","ends_at","event_id","expires_at","level_id","office_id","reason","reservation_id","seat_id","starts_at","state_digest","status","unchanged"],"optional":[]},"request_invoice_issue":{"rpc":"request_invoice_issue","dispatch":true,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","currency","event_id","expires_at","invoice_id","invoice_number","period","reason","total_cents","unchanged","voided"],"optional":[]},"request_invoice_void":{"rpc":"request_invoice_void","dispatch":true,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","currency","event_id","expires_at","invoice_id","invoice_number","period","reason","total_cents","unchanged","voided"],"optional":[]},"request_refund":{"rpc":"request_refund","dispatch":true,"authority":"permission","permission":"issueInvoices","features":["mcpAccess","invoicing"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","currency","event_id","expires_at","invoice_id","invoice_number","period","reason","total_cents","unchanged","voided"],"optional":[]},"request_member_status_change":{"rpc":"request_member_status_change","dispatch":true,"authority":"permission","permission":"manageMembers","features":["mcpAccess"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","event_id","expires_at","member_id","member_status","reason","subscription_pct","unchanged"],"optional":[]},"request_subscription_change":{"rpc":"request_subscription_change","dispatch":true,"authority":"permission","permission":"manageMembers","features":["mcpAccess"],"scope":"workspace","mutation":"request","confirmation":"native","output":["confirmation_id","event_id","expires_at","member_id","member_status","reason","subscription_pct","unchanged"],"optional":[]},"list_pending_validations":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"read","confirmation":"none","output":["confirmation_id","event_id","expires_at","items","mine","next_cursor","reason","requested_at","type","unchanged"],"optional":[]},"get_validation":{"rpc":null,"dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"own","mutation":"read","confirmation":"none","output":["can_respond","confirmation_id","decisions","event_id","expires_at","reason","requested_at","status","type","unchanged"],"optional":[]},"respond_to_validation":{"rpc":"respond_to_event","dispatch":true,"authority":"member","permission":null,"features":["mcpAccess"],"scope":"workspace","mutation":"decision","confirmation":"native","output":["confirmation_id","decision_recorded","effect_applied","event_id","event_status","expires_at","reason","unchanged"],"optional":[]}}}$json$::jsonb
$catalogue$;
revoke execute on function public.mcp_operation_catalogue() from public, anon;
grant execute on function public.mcp_operation_catalogue() to authenticated;

select public.set_deskilo_schema_version(406);
