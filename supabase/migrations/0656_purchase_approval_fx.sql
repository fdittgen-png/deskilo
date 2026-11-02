-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- #3070: the recorded rate of the same eligible bill, read-only. The
-- decision eligibility, general purchase reads and all writes are unchanged.
create or replace function public.purchase_approval_detail_v1(p_workspace_id uuid, p_purchase_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_member uuid := public.purchase_approval_actor(p_workspace_id);
  d public.purchase_documents;
  v_approve boolean;
  v_reject boolean;
  v_detail jsonb;
  v_fx jsonb;
begin
  select e.can_approve, e.can_reject into v_approve, v_reject
    from public.purchase_approval_eligible(p_workspace_id, v_member) e where e.id = p_purchase_id;
  if not found then
    raise exception using errcode = '42501', message = 'purchase approval is not available';
  end if;
  select * into d from public.purchase_documents
   where workspace_id = p_workspace_id and id = p_purchase_id;
  -- Only fields rendered for this pending decision: no source identifiers,
  -- hashes, snapshots, personal member data or unrelated obligations.
  v_detail := jsonb_build_object(
    'id', d.id, 'kind', d.kind, 'state', d.state, 'revision', d.revision,
    'category', d.category, 'currency', d.currency,
    'original_reference', d.original_reference, 'due_on', d.due_on,
    'legacy_qualification', d.legacy_qualification,
    'supplier', (select jsonb_build_object('supplier_number', s.supplier_number,
                                           'name', s.name)
                   from public.suppliers s where s.workspace_id = p_workspace_id and s.id = d.supplier_id),
    'lines', coalesce((select jsonb_agg(jsonb_build_object(
        'line_no', l.line_no, 'description', l.description,
        'gross_cents', l.gross_cents, 'tax_cents', l.tax_cents,
        'recoverable_tax_cents', l.recoverable_tax_cents,
        'recognition_kind', l.recognition_kind, 'place_name', public.purchase_place_name(l))
        order by l.line_no)
        from public.purchase_lines l where l.workspace_id = p_workspace_id and l.purchase_id = d.id), '[]'::jsonb),
    'sources', '[]'::jsonb, 'obligations', '[]'::jsonb);
  -- A recorded rate is disclosed only for this same eligible bill. Keep its
  -- exact numeric representation as text; no base amount is calculated here.
  select case
    when x.id is not null then jsonb_build_object(
      'status', 'recorded', 'currency', x.currency,
      'functional_currency', x.functional_currency, 'rate', x.rate::text,
      'rate_date', x.rate_date, 'source', x.source)
    when d.currency = w.currency_code then jsonb_build_object(
      'status', 'same_currency', 'currency', d.currency,
      'functional_currency', w.currency_code)
    else jsonb_build_object(
      'status', 'missing', 'currency', d.currency,
      'functional_currency', w.currency_code)
    end into v_fx
    from public.workspaces w
    left join public.document_exchange_rates x
      on x.workspace_id = p_workspace_id and x.document_kind = 'purchase'
     and x.document_id = p_purchase_id
   where w.id = p_workspace_id;
  return jsonb_build_object('detail', v_detail, 'can_approve', v_approve,
                            'can_reject', v_reject, 'fx', v_fx);
end;
$fn$;

revoke execute on function public.purchase_approval_detail_v1(uuid, uuid) from public, anon;
grant execute on function public.purchase_approval_detail_v1(uuid, uuid) to authenticated;

select public.set_deskilo_schema_version(656);
