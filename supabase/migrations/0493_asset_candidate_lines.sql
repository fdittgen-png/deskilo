-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0493 (#2576, C1b) -- the screen's two doors on the register.
--
--   asset_candidate_lines_v1(workspace)         the purchase lines classified as
--       long-lasting equipment that nobody has registered yet, newest first
--       (managePurchases): what the person registering equipment chooses from;
--   register_asset_candidate_v1(workspace, purchase, line_no, description, request)
--       the same registration as the line-id form of 0491, for a client that
--       knows a purchase and a line number, not the line's own id.
-- Nothing else changes: the rules of 0491 apply to both forms.

create or replace function public.asset_candidate_lines_v1(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  perform public.asset_actor(p_workspace_id, false);
  return jsonb_build_object('lines', coalesce((
    select jsonb_agg(x.j order by x.sort_at desc, x.line_no)
      from (select jsonb_build_object(
                     'purchase_id', d.id, 'line_no', l.line_no, 'description', l.description,
                     'gross_cents', l.gross_cents, 'currency', d.currency,
                     'recoverable_tax_cents', l.recoverable_tax_cents,
                     'supplier_name', (select s.name from public.suppliers s
                                        where s.workspace_id = d.workspace_id and s.id = d.supplier_id),
                     'original_reference', d.original_reference, 'original_date', d.original_date) as j,
                   coalesce(d.original_date::timestamptz, d.created_datetime) as sort_at,
                   l.line_no
              from public.purchase_lines l
              join public.purchase_documents d on d.id = l.purchase_id and d.workspace_id = l.workspace_id
             where l.workspace_id = p_workspace_id and l.recognition_kind = 'asset'
               and d.state not in ('rejected', 'cancelled')
               and not exists (select 1 from public.workspace_assets a
                                where a.purchase_line_id = l.id and a.workspace_id = l.workspace_id)
             order by sort_at desc, l.line_no
             limit 100) x), '[]'::jsonb));
end;
$fn$;
revoke execute on function public.asset_candidate_lines_v1(uuid) from public, anon;
grant execute on function public.asset_candidate_lines_v1(uuid) to authenticated;

create or replace function public.register_asset_candidate_v1(
  p_workspace_id uuid, p_purchase_id uuid, p_line_no int, p_description text, p_request_id uuid
) returns jsonb language plpgsql security definer set search_path = public as $fn$
declare v_line uuid;
begin
  perform public.asset_actor(p_workspace_id, false);
  select l.id into v_line from public.purchase_lines l
   where l.workspace_id = p_workspace_id and l.purchase_id = p_purchase_id and l.line_no = p_line_no;
  if v_line is null then raise exception 'unknown purchase line'; end if;
  return public.register_asset_candidate_v1(p_workspace_id, v_line, p_description, p_request_id);
end;
$fn$;
revoke execute on function public.register_asset_candidate_v1(uuid, uuid, int, text, uuid) from public, anon;
grant execute on function public.register_asset_candidate_v1(uuid, uuid, int, text, uuid) to authenticated;

select public.set_deskilo_schema_version(493);
