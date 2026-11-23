-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- apps: additive
-- (three functions patched at asserted anchors, one function added; nothing stored changes)
--
-- #4367 (CS5, fourth file) -- with the till sessions on, a sale needs an open session on its till.
--
--   * `counter_receipt_draft_v1` takes `till_id` in its body (a business that runs sessions names one) and ties the draft to
--     the OPEN session of that till; none open is refused (DKL12 till_open_first, "Open the till first").
--   * `counter_receipt_finalize_v1` takes a share lock on the session of the receipt: a close takes it for update, so the sale
--     lands in the session only if its transaction committed before the close; a session that is closed by then refuses the
--     sale (DKL12 closed). One ordering, whichever transaction commits first.
--   * `counter_refund_v1`: a cash refund comes out of a drawer, so each cash part names its `till_id` and needs an open
--     session there; the refund is recorded against it and lowers its expected cash. Other tenders need none.
--   Off (the sessions feature): the three functions behave exactly as before.

-- the open session of a till of this business, or the refusal that names the till
create or replace function public.counter_open_session(p_workspace_id uuid, p_till text)
returns uuid language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_till uuid;
  v_session uuid;
begin
  begin v_till := nullif(p_till, '')::uuid; exception when others then v_till := null; end;
  -- share-locked: a close (for update) waits for the transaction that took the session, as for a sale
  select s.id into v_session from public.counter_till_sessions s
   where s.workspace_id = p_workspace_id and s.till_id = v_till and s.state = 'open' for share;
  if v_session is null then
    raise exception 'open the till first' using errcode = 'DKL12',
      detail = jsonb_build_object('reason', 'till_open_first', 'till_id', v_till)::text;
  end if;
  return v_session;
end;
$fn$;
revoke execute on function public.counter_open_session(uuid, text) from public, anon, authenticated;

create or replace function pg_temp.occurrences(p_def text, p_old text)
returns int language sql as $f$
  select (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old)
$f$;
revoke execute on function pg_temp.occurrences(text, text) from public;

-- restates 0894
do $patch$
declare
  v_def text := pg_get_functiondef('public.counter_receipt_draft_v1(uuid, uuid, uuid, integer, jsonb)'::regprocedure);
  v_next text := v_def;
  v_olds text[] := array[
    E'  v_state text;\nbegin\n  v_me := public.counter_actor(p_workspace_id);\n  if p_request_id is null or coalesce(jsonb_typeof(p_body), \'\') <> \'object\' then',
    E'  v_tp := public.workspace_today(p_workspace_id);\n  v_calc := public.counter_lines_of(',
    E'  v_state := public.counter_operation_state(p_workspace_id, \'issue_receipt\');'];
  v_news text[] := array[
    E'  v_state text;\n  v_session uuid;\nbegin\n  v_me := public.counter_actor(p_workspace_id);\n  if p_request_id is null or coalesce(jsonb_typeof(p_body), \'\') <> \'object\' then',
    E'  -- with the till sessions on, a sale belongs to the open session of its till\n  if public.feature_effective(p_workspace_id, \'counterTillSessions\') then\n    v_session := public.counter_open_session(p_workspace_id, p_body ->> \'till_id\');\n  end if;\n  v_tp := public.workspace_today(p_workspace_id);\n  v_calc := public.counter_lines_of(',
    E'  if v_session is not null then\n    update public.counter_receipts set till_session_id = v_session where id = v_rec.id;\n  end if;\n  v_state := public.counter_operation_state(p_workspace_id, \'issue_receipt\');'];
begin
  for k in 1 .. array_length(v_olds, 1) loop
    if pg_temp.occurrences(v_def, v_olds[k]) <> 1 then
      raise exception '0908: anchor % not found exactly once in counter_receipt_draft_v1', k using errcode = 'P0001';
    end if;
    v_next := replace(v_next, v_olds[k], v_news[k]);
  end loop;
  execute v_next;
end
$patch$;

-- restates 0894
do $patch$
declare
  v_def text := pg_get_functiondef('public.counter_receipt_finalize_v1(uuid, uuid, uuid, integer, jsonb)'::regprocedure);
  v_next text := v_def;
  v_olds text[] := array[
    E'  v_goods jsonb;\n  v_main uuid;\nbegin',
    E'  -- the country operation first: nothing is numbered and nothing is taken where it is not supported'];
  v_news text[] := array[
    E'  v_goods jsonb;\n  v_main uuid;\n  v_sess public.counter_till_sessions;\nbegin',
    E'  -- the session of the sale, share-locked: a close (for update) waits for this transaction, and a session closed first refuses it\n  if public.feature_effective(p_workspace_id, \'counterTillSessions\') then\n    select * into v_sess from public.counter_till_sessions s where s.id = v_rec.till_session_id for share;\n    if v_sess.id is null or v_sess.state <> \'open\' then\n      raise exception \'open the till first\' using errcode = \'DKL12\',\n        detail = jsonb_build_object(\'reason\', case when v_sess.id is null then \'till_open_first\' else \'closed\' end, \'till_id\', v_sess.till_id)::text;\n    end if;\n  end if;\n  -- the country operation first: nothing is numbered and nothing is taken where it is not supported'];
begin
  for k in 1 .. array_length(v_olds, 1) loop
    if pg_temp.occurrences(v_def, v_olds[k]) <> 1 then
      raise exception '0908: anchor % not found exactly once in counter_receipt_finalize_v1', k using errcode = 'P0001';
    end if;
    v_next := replace(v_next, v_olds[k], v_news[k]);
  end loop;
  execute v_next;
end
$patch$;

-- restates 0895
do $patch$
declare
  v_def text := pg_get_functiondef('public.counter_refund_v1(uuid, uuid, uuid, jsonb)'::regprocedure);
  v_next text := v_def;
  v_olds text[] := array[
    E'  v_given bigint;\n  v_part int;\n  v_result jsonb;\nbegin',
    E'  perform public.counter_require_operation(p_workspace_id, \'reconcile_tender\');\n  for v_t in select value from jsonb_array_elements(p_refunds) loop',
    E'    insert into public.counter_refunds (workspace_id, receipt_id, part, kind, amount_minor, request_id, refunded_by_member_id)\n    values (p_workspace_id, v_rec.id, v_part, v_t ->> \'kind\', (v_t ->> \'amount_minor\')::bigint, p_request_id, v_me);'];
  v_news text[] := array[
    E'  v_given bigint;\n  v_part int;\n  v_result jsonb;\n  v_session uuid;\nbegin',
    E'  perform public.counter_require_operation(p_workspace_id, \'reconcile_tender\');\n  for v_t in select value from jsonb_array_elements(p_refunds) loop',
    E'    -- cash comes out of a drawer: with the sessions on, each cash part names a till that has an open session, share-locked\n    v_session := null;\n    if v_t ->> \'kind\' = \'cash\' and public.feature_effective(p_workspace_id, \'counterTillSessions\') then\n      v_session := public.counter_open_session(p_workspace_id, v_t ->> \'till_id\');\n    end if;\n    insert into public.counter_refunds (workspace_id, receipt_id, part, kind, amount_minor, request_id, refunded_by_member_id, till_session_id)\n    values (p_workspace_id, v_rec.id, v_part, v_t ->> \'kind\', (v_t ->> \'amount_minor\')::bigint, p_request_id, v_me, v_session);'];
begin
  for k in 1 .. array_length(v_olds, 1) loop
    if pg_temp.occurrences(v_def, v_olds[k]) <> 1 then
      raise exception '0908: anchor % not found exactly once in counter_refund_v1', k using errcode = 'P0001';
    end if;
    v_next := replace(v_next, v_olds[k], v_news[k]);
  end loop;
  execute v_next;
end
$patch$;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(908);
