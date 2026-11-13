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
-- The assistant's path (mcp_target, 0290) takes 0 as well: the operation's
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

-- The assistant's path: pct 0 to 100, as its contract says.
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
  v_def := pg_get_functiondef('public.mcp_target(uuid, text, jsonb)'::regprocedure);
  -- Applied once: a second run leaves the function as it is.
  if position($a$(p_args->>'pct')::integer not between 0 and 100$a$ in v_def) > 0 then return; end if;
  v_def := pg_temp.anchor_replace(v_def,
    $a$(p_args->>'pct')::integer not between 1 and 100$a$,
    $a$(p_args->>'pct')::integer not between 0 and 100$a$);
  if v_def is null then
    raise exception 'an anchor of #3879 was not found in mcp_target' using errcode = 'P0001';
  end if;
  execute v_def;
end
$migration$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(759);
