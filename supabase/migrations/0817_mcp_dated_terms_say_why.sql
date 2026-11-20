-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (mcp_confirm is restated whole with one more handler; three confirmation
-- targets are restated; no stored state moves.)
--
-- 0817 (#4241) -- a dated plan change says why it is refused before the person
-- is asked, not only after.
--
--   * Cancelling a change: the target asks the command itself (always rolled
--     back), so a change whose period an invoice already carries, one that
--     applies today and one no longer waiting are refused at the confirmation
--     with the command's own reason (`conflict`, `refused`, `data.reason`);
--     the person never confirms something that then fails.
--   * Scheduling a share or a pause: a day that is too early, not a period's
--     first day or already invoiced answers with the command's reason, which
--     names the earliest day allowed, instead of a bare `invalid_arguments`.
--     A malformed argument (a share above 100, a day that does not exist) is
--     still `validation_error`.
--
-- The confirmation maps only a few sqlstates to an answer (0638). One more is
-- added: `DKT01`, "a term change is refused", raised by these targets with the
-- command's message (bounded), answered as `conflict` / `refused` with that
-- reason, as the facade answers the same refusal at execution.

-- ── mcp_confirm, restated whole from its live body, with one more handler ──
-- (0638 notes the confirmation maps only a few sqlstates; DKT01 is added before
-- the generic invalid-argument one. Nothing else in the function changes.)
CREATE OR REPLACE FUNCTION public.mcp_confirm(c mcp_call_context, p_request_id uuid, p_digest text, p_args jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_confirmation public.mcp_action_confirmations;
  v_target jsonb;
begin
  select * into v_confirmation from public.mcp_action_confirmations
   where installation_id = public.installation_id() and local_user_id = auth.uid()
     and client_id = c.client_id and request_id = p_request_id
   for update;
  begin
    v_target := public.mcp_target_of(c.workspace_id, c.operation, p_args);
  exception
    when sqlstate 'DKS01' then
      return public.mcp_usage_note(c.spec, public.mcp_envelope(p_request_id, c.operation, c.workspace_id,
        'denied', null, 'secret_in_app_only'));
    when insufficient_privilege then
      return public.mcp_usage_note(c.spec, public.mcp_envelope(p_request_id, c.operation, c.workspace_id,
        'denied', null, 'not_exposed'));
    when sqlstate 'DKT01' then
      return public.mcp_usage_note(c.spec, public.mcp_envelope(p_request_id, c.operation, c.workspace_id,
        'conflict', jsonb_build_object('reason', left(sqlerrm, 200)), 'refused'));
    when invalid_parameter_value or invalid_text_representation then
      return public.mcp_usage_note(c.spec, public.mcp_envelope(p_request_id, c.operation, c.workspace_id,
        'validation_error', null, 'invalid_arguments'));
  end;
  if v_target is null then
    return public.mcp_usage_note(c.spec, public.mcp_envelope(p_request_id, c.operation, c.workspace_id,
      'not_found', null, 'not_found'));
  end if;
  if v_confirmation.id is null then
    insert into public.mcp_action_confirmations (installation_id, local_user_id, client_id,
      workspace_id, eligibility_grant_id, operation, request_id, args_digest, target_revision, preview)
    values (public.installation_id(), auth.uid(), c.client_id, c.workspace_id, c.grant_id,
            c.operation, p_request_id, p_digest, coalesce(v_target->>'revision', ''),
            jsonb_build_object('arguments', p_args - 'request_id', 'target', v_target - 'revision'))
    returning * into v_confirmation;
    return public.mcp_usage_note(c.spec, public.mcp_envelope(p_request_id, c.operation, c.workspace_id,
      'requires_confirmation',
      jsonb_build_object('confirmation_id', v_confirmation.id, 'expires_at', v_confirmation.expires_at)));
  end if;
  if v_confirmation.workspace_id <> c.workspace_id or v_confirmation.operation <> c.operation
     or v_confirmation.args_digest <> p_digest then
    return public.mcp_usage_note(c.spec, public.mcp_envelope(p_request_id, c.operation, c.workspace_id,
      'conflict', null, 'request_id_reused'));
  end if;
  if v_confirmation.eligibility_grant_id <> c.grant_id
     or coalesce(v_target->>'revision', '') <> v_confirmation.target_revision then
    update public.mcp_action_confirmations set status = 'revoked'
     where id = v_confirmation.id and status in ('pending', 'acknowledged');
    return public.mcp_usage_note(c.spec, public.mcp_envelope(p_request_id, c.operation, c.workspace_id,
      'conflict', null, 'confirmation_stale'));
  end if;
  if v_confirmation.status = 'pending' and v_confirmation.expires_at > now() then
    return public.mcp_usage_note(c.spec, public.mcp_envelope(p_request_id, c.operation, c.workspace_id,
      'requires_confirmation',
      jsonb_build_object('confirmation_id', v_confirmation.id, 'expires_at', v_confirmation.expires_at)));
  end if;
  if v_confirmation.status <> 'acknowledged' or v_confirmation.expires_at <= now() then
    return public.mcp_usage_note(c.spec, public.mcp_envelope(p_request_id, c.operation, c.workspace_id,
      'denied', null,
      case when v_confirmation.status = 'declined' then 'confirmation_declined' else 'confirmation_expired' end));
  end if;
  update public.mcp_action_confirmations set status = 'consumed', consumed_at = now()
   where id = v_confirmation.id;
  return null;
end;
$function$;
revoke execute on function public.mcp_confirm(public.mcp_call_context, uuid, text, jsonb) from public, anon, authenticated;

create or replace function public.mcp_target_schedule_member_share_change(p_workspace_id uuid, p_args jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_member public.members;
  v_name text;
  v_pct int;
  v_on date;
begin
  if coalesce(p_args->>'pct', '') !~ '^\d{1,3}$' or (p_args->>'pct')::int > 100 then
    raise exception using errcode = '22023', message = 'pct';
  end if;
  v_pct := (p_args->>'pct')::int;
  begin
    v_on := (p_args->>'effective_on')::date;
  exception when others then
    raise exception using errcode = '22023', message = 'effective_on';
  end;
  select * into v_member from public.members
   where id = public.mcp_uuid_arg(p_args, 'member_id') and workspace_id = p_workspace_id;
  if v_member.id is null then return null; end if;
  begin
    perform public.schedule_member_share_change(v_member.id, v_pct, v_on, gen_random_uuid());
    raise exception 'probe' using errcode = 'DKP01';
  exception
    when sqlstate 'DKP01' then null;
    when sqlstate 'DKN01' then
      raise exception 'not allowed to change subscriptions' using errcode = '42501';
    -- the command's own refusal (the earliest day allowed, an invoiced period):
    -- said to the assistant with its reason, before anyone is asked
    when sqlstate '22023' or sqlstate '55000' or sqlstate 'P0001' then
      raise exception '%', left(sqlerrm, 200) using errcode = 'DKT01';
  end;
  -- the label the person is shown: read through the one name helper, never
  -- from a profile column here (an authorization function does not read them)
  v_name := coalesce(nullif(v_member.managed_name, ''), public.mcp_person_name(v_member.user_id), '');
  return jsonb_build_object('kind', 'member', 'id', v_member.id, 'name', v_name,
    'status', v_member.status, 'subscription_pct', v_member.subscription_pct,
    'to_pct', v_pct, 'effective_on', v_on,
    'revision', md5(to_jsonb(v_member)::text || (
      select coalesce(string_agg(c.id::text || c.state, ',' order by c.seq), '')
        from public.member_term_changes c
       where c.member_id = v_member.id and c.state in ('pending', 'scheduled'))));
end;
$fn$;
revoke execute on function public.mcp_target_schedule_member_share_change(uuid, jsonb) from public, anon, authenticated;

create or replace function public.mcp_target_schedule_member_pause(p_workspace_id uuid, p_args jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_member public.members;
  v_name text;
  v_from date;
  v_to date;
begin
  begin
    v_from := (p_args->>'from')::date;
    v_to := (p_args->>'to')::date;
  exception when others then
    raise exception using errcode = '22023', message = 'from or to';
  end;
  select * into v_member from public.members
   where id = public.mcp_uuid_arg(p_args, 'member_id') and workspace_id = p_workspace_id;
  if v_member.id is null then return null; end if;
  begin
    perform public.schedule_member_pause(v_member.id, v_from, v_to, gen_random_uuid());
    raise exception 'probe' using errcode = 'DKP01';
  exception
    when sqlstate 'DKP01' then null;
    when sqlstate 'DKN01' then
      raise exception 'not allowed to change memberships' using errcode = '42501';
    when sqlstate '22023' or sqlstate '55000' or sqlstate 'P0001' then
      raise exception '%', left(sqlerrm, 200) using errcode = 'DKT01';
  end;
  -- the label the person is shown: read through the one name helper, never
  -- from a profile column here (an authorization function does not read them)
  v_name := coalesce(nullif(v_member.managed_name, ''), public.mcp_person_name(v_member.user_id), '');
  return jsonb_strip_nulls(jsonb_build_object('kind', 'member', 'id', v_member.id, 'name', v_name,
    'status', v_member.status, 'subscription_pct', v_member.subscription_pct,
    'from', v_from, 'to', v_to,
    'revision', md5(to_jsonb(v_member)::text || (
      select coalesce(string_agg(c.id::text || c.state, ',' order by c.seq), '')
        from public.member_term_changes c
       where c.member_id = v_member.id and c.state in ('pending', 'scheduled')))));
end;
$fn$;
revoke execute on function public.mcp_target_schedule_member_pause(uuid, jsonb) from public, anon, authenticated;

create or replace function public.mcp_target_cancel_member_term_change(p_workspace_id uuid, p_args jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_change public.member_term_changes;
  v_member public.members;
  v_name text;
begin
  select * into v_change from public.member_term_changes
   where id = public.mcp_uuid_arg(p_args, 'change_id') and workspace_id = p_workspace_id;
  if v_change.id is null then return null; end if;
  select * into v_member from public.members where id = v_change.member_id;
  -- only a change the command would cancel is put to the person: the command is
  -- asked, inside a block that is always rolled back, so an invoiced period, a
  -- change that applies today or one no longer waiting is refused with the
  -- command's own reason before anyone confirms it
  begin
    perform public.cancel_member_term_change(v_change.id);
    raise exception 'probe' using errcode = 'DKP01';
  exception
    when sqlstate 'DKP01' then null;
    when sqlstate 'DKN01' then
      raise exception 'not allowed to change memberships' using errcode = '42501';
    when sqlstate '22023' or sqlstate '55000' or sqlstate 'P0001' then
      raise exception '%', left(sqlerrm, 200) using errcode = 'DKT01';
  end;
  -- the label the person is shown: read through the one name helper, never
  -- from a profile column here (an authorization function does not read them)
  v_name := coalesce(nullif(v_member.managed_name, ''), public.mcp_person_name(v_member.user_id), '');
  return jsonb_strip_nulls(jsonb_build_object('kind', 'member', 'id', v_member.id, 'name', v_name,
    'status', v_member.status, 'subscription_pct', v_member.subscription_pct,
    'change_kind', v_change.kind, 'to_pct', v_change.to_pct, 'to_status', v_change.to_status,
    'effective_on', v_change.due_on,
    'revision', md5(to_jsonb(v_change)::text)));
end;
$fn$;
revoke execute on function public.mcp_target_cancel_member_term_change(uuid, jsonb) from public, anon, authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(817);
