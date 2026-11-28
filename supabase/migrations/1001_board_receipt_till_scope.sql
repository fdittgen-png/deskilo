-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
--
-- #4517 -- a board's command acts only on its own till's receipts. A till board sells under a cashier's lease, which
-- names one till (0995); the embedded-till function calls these two functions with the lease's till, never one the
-- board sends.
--   * counter_board_receipt_draft_v1      a new draft of the lease's till, or a revision of a draft of that till
--   * counter_board_receipt_finalize_v1   the finalization of a draft of that till
-- A receipt of another till is answered as an unknown one (DKL04, "this receipt is not an open draft"): the board
-- learns nothing of another till's receipts. A receipt's till is its till session's (0907); a board always sells with
-- till sessions on, which till boards require. Each then calls the till's own function unchanged, as the cashier.
-- audience: all row readers (no read changes; the board's two commands are scoped to the lease's till)

-- Refuses [p_receipt_id] unless it is a receipt of [p_workspace_id] in a session of [p_till_id].
create or replace function public.counter_board_receipt_of_till(p_workspace_id uuid, p_till_id uuid, p_receipt_id uuid)
returns void language plpgsql stable security definer set search_path = '' as $fn$
begin
  if p_till_id is null or not exists (
       select 1 from public.counter_receipts r
         join public.counter_till_sessions s on s.workspace_id = r.workspace_id and s.id = r.till_session_id
        where r.id = p_receipt_id and r.workspace_id = p_workspace_id and s.till_id = p_till_id) then
    raise exception 'this receipt is not an open draft' using errcode = 'DKL04';
  end if;
end;
$fn$;
revoke execute on function public.counter_board_receipt_of_till(uuid, uuid, uuid) from public, anon, authenticated;

create or replace function public.counter_board_receipt_draft_v1(
  p_workspace_id uuid, p_till_id uuid, p_request_id uuid, p_receipt_id uuid, p_expected_revision int, p_lines jsonb)
returns jsonb language plpgsql volatile security definer set search_path = '' as $fn$
begin
  if p_till_id is null then
    perform public.refuse('DKL02', '{"reason": "till"}'::jsonb, 'a board sells on the till of its lease');
  end if;
  if p_receipt_id is not null then
    perform public.counter_board_receipt_of_till(p_workspace_id, p_till_id, p_receipt_id);
  end if;
  return public.counter_receipt_draft_v1(p_workspace_id, p_request_id, p_receipt_id, p_expected_revision,
    jsonb_build_object('lines', p_lines, 'till_id', p_till_id));
end;
$fn$;
revoke execute on function public.counter_board_receipt_draft_v1(uuid, uuid, uuid, uuid, int, jsonb) from public, anon;
grant execute on function public.counter_board_receipt_draft_v1(uuid, uuid, uuid, uuid, int, jsonb) to authenticated;

create or replace function public.counter_board_receipt_finalize_v1(
  p_workspace_id uuid, p_till_id uuid, p_request_id uuid, p_receipt_id uuid, p_expected_revision int, p_tenders jsonb)
returns jsonb language plpgsql volatile security definer set search_path = '' as $fn$
begin
  perform public.counter_board_receipt_of_till(p_workspace_id, p_till_id, p_receipt_id);
  return public.counter_receipt_finalize_v1(p_workspace_id, p_request_id, p_receipt_id, p_expected_revision, p_tenders);
end;
$fn$;
revoke execute on function public.counter_board_receipt_finalize_v1(uuid, uuid, uuid, uuid, int, jsonb) from public, anon;
grant execute on function public.counter_board_receipt_finalize_v1(uuid, uuid, uuid, uuid, int, jsonb) to authenticated;

select public.set_deskilo_schema_version(1001);
