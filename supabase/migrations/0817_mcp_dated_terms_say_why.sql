-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (mcp_confirm gains one handler by an anchored patch; three confirmation
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

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
begin
  if (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old) <> 1 then
    return null;
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public, anon, authenticated;

do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'mcp_confirm'
     and pg_get_function_arguments(p.oid) like 'c mcp_call_context%';
  -- Applied once: a second run leaves the function as it is.
  if position($a$sqlstate 'DKT01'$a$ in v_def) > 0 then return; end if;
  v_def := pg_temp.anchor_replace(v_def,
    $a$    when invalid_parameter_value or invalid_text_representation then
$a$,
    $a$    when sqlstate 'DKT01' then
      return public.mcp_usage_note(c.spec, public.mcp_envelope(p_request_id, c.operation, c.workspace_id,
        'conflict', jsonb_build_object('reason', left(sqlerrm, 200)), 'refused'));
    when invalid_parameter_value or invalid_text_representation then
$a$);
  if v_def is null then
    raise exception 'an anchor of #4241 was not found in mcp_confirm' using errcode = 'P0001';
  end if;
  execute v_def;
end
$migration$;

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
