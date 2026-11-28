-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
--
-- #4519 (E05) -- what a till board reads under a cashier's lease, through the embedded-till function's `command` with
-- the lease's business and till (never ones the board names), as the cashier:
--   * counter_board_catalogue_v1   the till's published layout (null without one) and the sellable items its keys
--                                  name, or the business's first sellable items by their order when it has none
--   * counter_board_open_draft_v1  the till's newest open draft: its id, revision, currency and lines
-- A board's command acts only on its own till's receipts (1001): the open draft is one of the till's sessions.
-- audience: all row readers (who may sell reads, through their board, what they could read in the app)

create or replace function public.counter_board_catalogue_v1(p_workspace_id uuid, p_till_id uuid, p_max int)
returns jsonb language plpgsql stable security definer set search_path = '' as $fn$
declare
  v_layout jsonb;
  v_ids uuid[];
  v_max int := least(32, greatest(1, coalesce(p_max, 8)));
begin
  perform public.command_actor(p_workspace_id, 'issueInvoices', 'counterEmbeddedTerminal',
    'only who sells in this business sells on its till boards', 'till boards are off in this business');
  if p_till_id is null or not exists (select 1 from public.counter_tills t where t.workspace_id = p_workspace_id and t.id = p_till_id) then
    perform public.refuse('DKL02', '{"reason": "till"}'::jsonb, 'a board sells on the till of its lease');
  end if;
  select l.layout into v_layout from public.till_layouts l
   where l.till_id = p_till_id and l.status = 'published'
     and public.feature_effective(p_workspace_id, 'counterTillLayout');
  if v_layout is not null then
    v_ids := array(select distinct (x #>> '{}')::uuid
                     from jsonb_path_query(v_layout, '$.pages[*].grids.*.cells[*] ? (@.kind == "item_key").params.item_id') x
                    where (x #>> '{}') ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');
  end if;
  return jsonb_build_object(
    'layout', v_layout,
    'items', coalesce((
      select jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name, 'price_cents', s.price_cents) order by s.sort_order nulls last, s.name, s.id)
        from (select s.* from public.services s
               where s.workspace_id = p_workspace_id and s.active and s.sellable
                 and (v_ids is null or s.id = any (v_ids))
               order by s.sort_order nulls last, s.name, s.id
               limit case when v_ids is null then v_max else 64 end) s), '[]'::jsonb));
end;
$fn$;
revoke execute on function public.counter_board_catalogue_v1(uuid, uuid, int) from public, anon;
grant execute on function public.counter_board_catalogue_v1(uuid, uuid, int) to authenticated;

create or replace function public.counter_board_open_draft_v1(p_workspace_id uuid, p_till_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $fn$
declare
  v_rec public.counter_receipts;
begin
  perform public.command_actor(p_workspace_id, 'issueInvoices', 'counterEmbeddedTerminal',
    'only who sells in this business sells on its till boards', 'till boards are off in this business');
  select r.* into v_rec from public.counter_receipts r
    join public.counter_till_sessions s on s.workspace_id = r.workspace_id and s.id = r.till_session_id
   where r.workspace_id = p_workspace_id and s.till_id = p_till_id and r.state = 'draft' and r.kind = 'sale'
   order by r.modified_datetime desc, r.id limit 1;
  if v_rec.id is null then return null; end if;
  return jsonb_build_object('id', v_rec.id, 'revision', v_rec.revision, 'currency', v_rec.currency,
    'lines', coalesce((select jsonb_agg(jsonb_build_object('line_no', l.line_no, 'quantity', l.quantity, 'gross_minor', l.gross_minor,
                                                           'label', l.frozen ->> 'label') order by l.line_no)
                         from public.counter_receipt_lines l where l.receipt_id = v_rec.id), '[]'::jsonb));
end;
$fn$;
revoke execute on function public.counter_board_open_draft_v1(uuid, uuid) from public, anon;
grant execute on function public.counter_board_open_draft_v1(uuid, uuid) to authenticated;

select public.set_deskilo_schema_version(1004);
