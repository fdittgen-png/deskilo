-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0290 (#1623) -- the membership and subscription request tools refuse
-- impossible values before a human is asked, write nothing when nothing
-- changes, and read the member back.
--
-- request_member_status_change / request_subscription_change already run
-- through mcp_execute_v1 with the workspace-scoped member target, the
-- #1619 native confirmation (stale target -> fresh confirmation), request-
-- id idempotency and the existing request_* workflows. A live probe showed:
--   * a percentage of 150 or 'abc' and a status of 'banana' were each put
--     to a person to confirm; mcp_target now refuses them as
--     invalid_arguments first (1..100 as the workflow itself requires;
--     active / paused / exited as request_member_status_change accepts);
--   * choosing the value the member already has submitted a request and
--     recorded an event; it now answers completed/unchanged and writes
--     nothing, as the native screen does;
--   * a completed request answered {}; both tools now read the member
--     back (status, subscription_pct).

create or replace function public.mcp_member_view(p_member_id uuid)
returns jsonb language sql stable set search_path = public as $fn$
  select jsonb_build_object('member_id', m.id, 'member_status', m.status,
           'subscription_pct', m.subscription_pct)
    from public.members m where m.id = p_member_id;
$fn$;
revoke execute on function public.mcp_member_view(uuid) from public, anon, authenticated;

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text language plpgsql as $f$
begin
  if position(p_old in p_def) = 0 then return null; end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $migration$
declare
  v_def text;
  v_next text;
begin
  v_def := pg_get_functiondef('public.mcp_target(uuid, text, jsonb)'::regprocedure);
  if position('#1623' in v_def) = 0 then
    v_next := pg_temp.anchor_replace(v_def,
      $a$  -- #1622 — a request a person could never approve is not put to them.$a$,
      $a$  -- #1623 — nor a percentage or a status the workflow would refuse.
  if p_operation = 'request_subscription_change'
     and (coalesce(p_args->>'pct', '') !~ '^\d{1,3}$'
          or (p_args->>'pct')::integer not between 1 and 100) then
    raise exception using errcode = '22023', message = 'pct';
  end if;
  if p_operation = 'request_member_status_change'
     and coalesce(p_args->>'status', '') not in ('active', 'paused', 'exited') then
    raise exception using errcode = '22023', message = 'status';
  end if;
  -- #1622 — a request a person could never approve is not put to them.$a$);
    if v_next is null then raise exception '0290: mcp_target anchor not found (needs 0289)'; end if;
    execute v_next;
  end if;

  v_def := pg_get_functiondef('public.mcp_execute_v1(uuid, uuid, text, jsonb, uuid)'::regprocedure);
  if position('public.mcp_member_view(' in v_def) = 0 then
    v_next := pg_temp.anchor_replace(v_def,
      $a$      elsif p_operation = 'request_member_status_change' then
        v_result := public.request_member_status_change(public.mcp_uuid_arg(v_args, 'member_id'), v_args->>'status');
        v_status := public.mcp_request_outcome(v_result);
        v_data := jsonb_strip_nulls(jsonb_build_object('event_id', v_result->'event_id'));
      elsif p_operation = 'request_subscription_change' then
        v_result := public.request_subscription_change(public.mcp_uuid_arg(v_args, 'member_id'),
          (v_args->>'pct')::integer);
        v_status := public.mcp_request_outcome(v_result);
        v_data := jsonb_strip_nulls(jsonb_build_object('event_id', v_result->'event_id'));$a$,
      $a$      elsif p_operation = 'request_member_status_change'
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
        v_data := jsonb_strip_nulls(jsonb_build_object('event_id', v_result->'event_id'));$a$);
    if v_next is null then raise exception '0290: member branches not found'; end if;
    v_def := v_next;
    v_next := pg_temp.anchor_replace(v_def,
      $a$      if p_operation in ('request_invoice_issue', 'request_invoice_void', 'request_refund') then$a$,
      $a$      if p_operation in ('request_member_status_change', 'request_subscription_change') then
        v_data := coalesce(v_data, '{}'::jsonb)
                  || coalesce(public.mcp_member_view(public.mcp_uuid_arg(v_args, 'member_id')), '{}'::jsonb);
      end if;
      if p_operation in ('request_invoice_issue', 'request_invoice_void', 'request_refund') then$a$);
    if v_next is null then raise exception '0290: read-back anchor not found (needs 0289)'; end if;
    execute v_next;
  end if;
end
$migration$;

select public.set_deskilo_schema_version(290);
