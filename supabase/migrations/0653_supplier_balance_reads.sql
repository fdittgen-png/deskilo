-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- #3070: complete supplier balances and a supplier-scoped payable page.
-- The existing obligation serializer is the sole source of remaining amounts.

create or replace function public.supplier_balances_v1(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_rows jsonb;
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not coalesce(public.has_permission(p_workspace_id, 'viewFinances')
                     or public.has_permission(p_workspace_id, 'managePurchases'), false) then
    raise exception using errcode = '42501', message = 'supplier payables are not available';
  end if;
  if public.feature_effective(p_workspace_id, 'purchases') is not true then
    raise exception using errcode = '42501', message = 'supplier payables are not available';
  end if;
  with claims as materialized (
    select o.creditor_supplier_id as supplier_id, o.currency, o.state,
           (public.purchase_obligation_json(o)->>'remaining_cents')::bigint as remaining
      from public.purchase_obligations o
     where o.workspace_id = p_workspace_id and o.creditor_kind = 'supplier'
  ), totals as (
    select supplier_id, currency, sum(remaining) as remaining_cents,
           coalesce(sum(remaining) filter (where state = 'held'), 0) as held_cents
      from claims group by supplier_id, currency
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'supplier_id', supplier_id, 'currency', currency,
           'remaining_cents', remaining_cents, 'held_cents', held_cents
         ) order by supplier_id, currency), '[]'::jsonb)
    into v_rows from totals;
  return jsonb_build_object('rows', v_rows);
end;
$fn$;
revoke execute on function public.supplier_balances_v1(uuid) from public, anon;
grant execute on function public.supplier_balances_v1(uuid) to authenticated;

create or replace function public.supplier_payables_page_v1(
  p_workspace_id uuid, p_supplier_id uuid,
  p_after_created timestamptz default null, p_after_id uuid default null,
  p_limit int default 100
) returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_limit int := least(greatest(coalesce(p_limit, 100), 1), 200);
  v_rows jsonb;
  v_count int;
  v_last_c timestamptz;
  v_last_i uuid;
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not coalesce(public.has_permission(p_workspace_id, 'viewFinances')
                     or public.has_permission(p_workspace_id, 'managePurchases'), false) then
    raise exception using errcode = '42501', message = 'supplier payables are not available';
  end if;
  if public.feature_effective(p_workspace_id, 'purchases') is not true then
    raise exception using errcode = '42501', message = 'supplier payables are not available';
  end if;
  if (p_after_created is null) <> (p_after_id is null) then
    raise exception using errcode = '22023', message = 'both cursor fields are required';
  end if;
  if not exists (select 1 from public.suppliers s
                  where s.workspace_id = p_workspace_id and s.id = p_supplier_id) then
    raise exception using errcode = '22023', message = 'unknown supplier';
  end if;
  with q as (
    select jsonb_build_object(
             'obligation', public.purchase_obligation_json(o),
             'purchase', jsonb_build_object(
               'kind', d.kind, 'state', d.state, 'category', d.category,
               'original_reference', d.original_reference, 'received_on', d.received_on,
               'legacy', d.legacy_qualification <> 'none')) as j,
           o.created_datetime as c, o.id as i,
           row_number() over (order by o.created_datetime desc, o.id desc) as rn
      from public.purchase_obligations o
      join public.purchase_documents d on d.workspace_id = o.workspace_id and d.id = o.purchase_id
     where o.workspace_id = p_workspace_id and o.creditor_kind = 'supplier'
       and o.creditor_supplier_id = p_supplier_id
       and (p_after_created is null or (o.created_datetime, o.id) < (p_after_created, p_after_id))
     order by o.created_datetime desc, o.id desc
     limit v_limit + 1
  )
  select coalesce(jsonb_agg(j order by rn) filter (where rn <= v_limit), '[]'::jsonb),
         count(*)::int,
         (array_agg(c order by rn) filter (where rn = v_limit))[1],
         (array_agg(i order by rn) filter (where rn = v_limit))[1]
    into v_rows, v_count, v_last_c, v_last_i from q;
  return jsonb_build_object('rows', v_rows,
    'next', case when v_count > v_limit then jsonb_build_object('created', v_last_c, 'id', v_last_i) end);
end;
$fn$;
revoke execute on function public.supplier_payables_page_v1(uuid, uuid, timestamptz, uuid, int) from public, anon;
grant execute on function public.supplier_payables_page_v1(uuid, uuid, timestamptz, uuid, int) to authenticated;

select public.set_deskilo_schema_version(0653);
