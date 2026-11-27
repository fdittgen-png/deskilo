-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
--
-- #4448 -- a till back to the keys it generates from the items: its draft and its published layout removed, under a
-- request id. The till drawing the published layout keeps it until its next session (the app reads it once per screen).
--
--   till_layout_reset_v1   who may lay out the tills (configureTill), where till layouts are on (DKG01 off, DKN01 not
--                          allowed); another business's till is refused (DKL02); the same request answers again.

create or replace function public.till_layout_reset_v1(
  p_workspace_id uuid,
  p_request_id uuid,
  p_till_id uuid
) returns jsonb language plpgsql volatile security definer set search_path = public as $fn$
declare
  v_digest text := md5(p_till_id::text);
  v_done jsonb;
  v_removed integer;
begin
  perform public.command_actor(p_workspace_id, 'configureTill', 'counterTillLayout', 'not allowed to lay out the tills',
    'till layouts are off in this business', 'DKG01');
  v_done := public.request_begin(p_workspace_id, p_request_id, 'till_layout_reset', v_digest);
  if v_done is not null then
    return v_done || '{"replayed": true}'::jsonb;
  end if;
  if not exists (select 1 from public.counter_tills t where t.id = p_till_id and t.workspace_id = p_workspace_id) then
    raise exception 'no such till in this business' using errcode = 'DKL02', detail = '{"reason": "till"}';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('till_layout:' || p_till_id::text, 0));
  delete from public.till_layouts where till_id = p_till_id and workspace_id = p_workspace_id;
  get diagnostics v_removed = row_count;
  return public.request_finish(p_workspace_id, p_request_id, 'till_layout_reset', v_digest,
    jsonb_build_object('removed', v_removed)) || '{"replayed": false}'::jsonb;
end
$fn$;
revoke execute on function public.till_layout_reset_v1(uuid, uuid, uuid) from public, anon;
grant execute on function public.till_layout_reset_v1(uuid, uuid, uuid) to authenticated;

select public.set_deskilo_schema_version(962);
