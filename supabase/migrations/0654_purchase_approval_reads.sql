-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- #3070: actionable supplier bills for the approver, not wide purchase access.
-- Each page/count is a statement snapshot. A version detects changed rows
-- between pages but cannot make multiple requests one snapshot. Queues over
-- 100000 eligible bills fail explicitly instead of returning partial data.

create or replace function public.purchase_approval_actor(p_workspace_id uuid)
returns uuid language plpgsql stable security definer set search_path = public as $fn$
declare v_member uuid;
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or public.feature_effective(p_workspace_id, 'purchases') is not true
     or not coalesce(public.has_permission(p_workspace_id, 'approveExpenses'), false) then
    raise exception using errcode = '42501', message = 'purchase approvals are not available';
  end if;
  select id into v_member from public.members
   where workspace_id = p_workspace_id and user_id = auth.uid() and status = 'active';
  if v_member is null then
    raise exception using errcode = '42501', message = 'purchase approvals are not available';
  end if;
  return v_member;
end;
$fn$;
revoke execute on function public.purchase_approval_actor(uuid) from public, anon, authenticated;

-- Match decide_purchase_v1's 0483 maker/checker rule. Member receipts are
-- decided by expense validation, not by decide_purchase_v1.
create or replace function public.purchase_approval_eligible(p_workspace_id uuid, p_member_id uuid)
returns table (id uuid, created_datetime timestamptz, revision int, can_approve boolean, can_reject boolean, gross_cents bigint)
language sql stable security definer set search_path = public as $fn$
  select d.id, d.created_datetime, d.revision,
         (not maker.is_maker or totals.gross_cents < coalesce(
           (public.setting_value(p_workspace_id, 'purchase.single_approval_below_units') #>> '{}')::bigint, 0) * 100),
         not maker.is_maker, totals.gross_cents
    from public.purchase_documents d
    cross join lateral (select coalesce(sum(l.gross_cents), 0)::bigint as gross_cents
                          from public.purchase_lines l where l.purchase_id = d.id) totals
    cross join lateral (select coalesce(d.submitter_member_id = p_member_id, false)
                               or coalesce(d.submitted_by_member_id = p_member_id, false) as is_maker) maker
   where d.workspace_id = p_workspace_id and d.kind = 'bill' and d.state = 'pending'
     and (not maker.is_maker or totals.gross_cents < coalesce(
       (public.setting_value(p_workspace_id, 'purchase.single_approval_below_units') #>> '{}')::bigint, 0) * 100)
$fn$;
revoke execute on function public.purchase_approval_eligible(uuid, uuid) from public, anon, authenticated;

create or replace function public.purchase_approval_page_v1(
  p_workspace_id uuid, p_after_created timestamptz default null,
  p_after_id uuid default null, p_limit int default 100
) returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_member uuid := public.purchase_approval_actor(p_workspace_id);
  v_limit int := least(greatest(coalesce(p_limit, 100), 1), 200);
  v_rows jsonb; v_total bigint; v_version text; v_n int; v_created timestamptz; v_id uuid;
begin
  if (p_after_created is null) <> (p_after_id is null) then
    raise exception using errcode = '22023', message = 'both cursor fields are required';
  end if;
  with eligible as materialized (
    select * from public.purchase_approval_eligible(p_workspace_id, v_member) limit 100001
  ), page as (
    select e.*, row_number() over (order by e.created_datetime desc, e.id desc) as rn
      from eligible e
     where p_after_created is null or (e.created_datetime, e.id) < (p_after_created, p_after_id)
     order by e.created_datetime desc, e.id desc limit v_limit + 1
  )
  select (select count(*) from eligible),
         (select md5(coalesce(string_agg(id::text || ':' || revision::text || ':' ||
                   extract(epoch from created_datetime)::text || ':' || gross_cents::text || ':' ||
                   can_approve::text || ':' || can_reject::text, ',' order by id), '')) from eligible),
         coalesce(jsonb_agg(jsonb_build_object(
           'id', d.id, 'kind', d.kind, 'state', d.state, 'category', d.category,
           'original_reference', d.original_reference, 'currency', d.currency,
           'received_on', d.received_on, 'supplier_id', d.supplier_id,
           'purchase_lines', jsonb_build_array(jsonb_build_object('gross_cents', p.gross_cents))
         ) order by p.rn) filter (where p.rn <= v_limit), '[]'::jsonb),
         count(*)::int,
         (array_agg(p.created_datetime order by p.rn) filter (where p.rn = v_limit))[1],
         (array_agg(p.id order by p.rn) filter (where p.rn = v_limit))[1]
    into v_total, v_version, v_rows, v_n, v_created, v_id
    from page p join public.purchase_documents d on d.id = p.id and d.workspace_id = p_workspace_id;
  if v_total > 100000 then
    raise exception using errcode = '54000', message = 'purchase approval queue exceeds read limit';
  end if;
  return jsonb_build_object('count', v_total, 'version', v_version, 'rows', v_rows,
    'next', case when v_n > v_limit then jsonb_build_object('created', v_created, 'id', v_id) end);
end;
$fn$;
revoke execute on function public.purchase_approval_page_v1(uuid, timestamptz, uuid, int) from public, anon;
grant execute on function public.purchase_approval_page_v1(uuid, timestamptz, uuid, int) to authenticated;

-- Return detail only while the same eligibility predicate permits a decision.
create or replace function public.purchase_approval_detail_v1(p_workspace_id uuid, p_purchase_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_member uuid := public.purchase_approval_actor(p_workspace_id);
  d public.purchase_documents;
  v_approve boolean;
  v_reject boolean;
  v_detail jsonb;
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
  return jsonb_build_object('detail', v_detail, 'can_approve', v_approve, 'can_reject', v_reject);
end;
$fn$;
revoke execute on function public.purchase_approval_detail_v1(uuid, uuid) from public, anon;
grant execute on function public.purchase_approval_detail_v1(uuid, uuid) to authenticated;

select public.set_deskilo_schema_version(0654);
