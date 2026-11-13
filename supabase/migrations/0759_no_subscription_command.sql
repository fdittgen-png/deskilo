-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0759 (#3879) -- "No subscription" goes through the subscription command.
-- A member may have no subscription since 0235, and the app offers it; the
-- command takes 0 now, beside 1 to 100. A member who pays as they go cannot
-- have no subscription: the constraint and trigger of 0235 refuse it, with
-- their own sentence. With a validation policy, the approved request applies 0
-- as it applies any other share.
--
-- The assistant's path (mcp_target) takes 0 as well: the operation's
-- contract already names pct 0 to 100, and the assistant does what the app
-- does.

-- The command (0181), restated whole.
create or replace function public.request_subscription_change(p_member_id uuid, p_pct integer)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_m public.members; v_actor public.members; v_id uuid; v_payload jsonb;
begin
  select * into v_m from public.members where id = p_member_id;
  if v_m.id is null then raise exception 'unknown member' using errcode = '22023'; end if;
  if p_pct < 0 or p_pct > 100 then raise exception 'pct out of range' using errcode = '22023'; end if;
  v_actor := public.my_active_member(v_m.workspace_id);
  if not public.has_permission(v_m.workspace_id, 'manageMembers') then
    raise exception 'not allowed to change subscriptions' using errcode = '42501';
  end if;
  v_payload := jsonb_build_object('member_id', p_member_id, 'before', v_m.subscription_pct, 'after', p_pct);
  if public.validation_requires(v_m.workspace_id, 'subscription_change', 0) then
    insert into public.events (workspace_id, type, action, actor_member_id, subject_member_id, payload, status)
    values (v_m.workspace_id, 'subscription_change', 'submitted', v_actor.id, p_member_id, v_payload, 'pending') returning id into v_id;
    return jsonb_build_object('pending', true, 'event_id', v_id);
  end if;
  update public.members set subscription_pct = p_pct where id = p_member_id;
  perform public.record_applied_event(v_m.workspace_id, 'subscription_change', v_actor.id, p_member_id, v_payload);
  return jsonb_build_object('pending', false);
end $$;

revoke execute on function public.request_subscription_change(uuid, integer) from public, anon;
grant execute on function public.request_subscription_change(uuid, integer) to authenticated;

-- The assistant's path (mcp_target, 0272 with 0289-0291), restated whole:
-- pct 0 to 100, as its contract says.
create or replace function public.mcp_target(p_workspace_id uuid, p_operation text, p_args jsonb)
returns jsonb language plpgsql stable security definer set search_path = public as $function$
declare
  v_invoice public.invoices;
  v_member public.members;
  v_event public.events;
  v_name text;
begin
  -- #1623 — nor a percentage or a status the workflow would refuse.
  if p_operation = 'request_subscription_change'
     and (coalesce(p_args->>'pct', '') !~ '^\d{1,3}$'
          or (p_args->>'pct')::integer not between 0 and 100) then
    raise exception using errcode = '22023', message = 'pct';
  end if;
  if p_operation = 'request_member_status_change'
     and coalesce(p_args->>'status', '') not in ('active', 'paused', 'exited') then
    raise exception using errcode = '22023', message = 'status';
  end if;
  -- #1624 — a decision is yes or no, never something to guess at.
  if p_operation = 'respond_to_validation'
     and coalesce(p_args->>'accept', '') not in ('true', 'false') then
    raise exception using errcode = '22023', message = 'accept';
  end if;
  -- #1622 — a request a person could never approve is not put to them.
  if p_operation = 'request_invoice_issue'
     and coalesce(p_args->>'period', '') !~ '^\d{4}-(0[1-9]|1[0-2])$' then
    raise exception using errcode = '22023', message = 'period';
  end if;
  if p_operation in ('request_invoice_void', 'request_refund') then
    select * into v_invoice from public.invoices
     where id = public.mcp_uuid_arg(p_args, 'invoice_id') and workspace_id = p_workspace_id;
    if v_invoice.id is null then return null; end if;
    return jsonb_build_object('kind', 'invoice', 'id', v_invoice.id, 'number', v_invoice.number,
      'total_cents', v_invoice.total_cents, 'currency', v_invoice.currency, 'period', v_invoice.period,
      'revision', md5(to_jsonb(v_invoice)::text));
  elsif p_operation in ('request_invoice_issue', 'request_member_status_change', 'request_subscription_change') then
    select * into v_member from public.members
     where id = public.mcp_uuid_arg(p_args, 'member_id') and workspace_id = p_workspace_id;
    if v_member.id is null then return null; end if;
    select coalesce(nullif(v_member.managed_name, ''), p.display_name, '') into v_name
      from (select 1) x left join public.profiles p on p.id = v_member.user_id;
    return jsonb_build_object('kind', 'member', 'id', v_member.id, 'name', v_name,
      'status', v_member.status, 'subscription_pct', v_member.subscription_pct,
      'revision', md5(to_jsonb(v_member)::text));
  elsif p_operation = 'respond_to_validation' then
    select * into v_event from public.events
     where id = public.mcp_uuid_arg(p_args, 'event_id') and workspace_id = p_workspace_id;
    if v_event.id is null then return null; end if;
    return jsonb_build_object('kind', 'event', 'id', v_event.id, 'type', v_event.type,
      'status', v_event.status, 'revision', md5(to_jsonb(v_event)::text));
  end if;
  return null;
end;
$function$;
revoke execute on function public.mcp_target(uuid, text, jsonb) from public, anon, authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(759);
