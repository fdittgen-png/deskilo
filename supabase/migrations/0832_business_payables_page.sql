-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- #4167 (detail): the obligation rows behind a business's payables, for one
-- currency and optionally one creditor kind (a supplier, or a member the business
-- owes an expense back), keyset-paged on (created, id) so every row is reachable
-- once. It reads through the one obligation serializer, so a row's remainder is the
-- one the aggregates (0653, 0831) sum, and it carries the creditor's kind and id
-- so the two directions never blur. Same right as the aggregates, refused for an
-- assistant; a denied read is an error, never an empty list. Nothing is written.

create or replace function public.business_payables_page_v1(
  p_workspace_id uuid, p_currency text, p_creditor_kind text default null,
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
                     or public.has_permission(p_workspace_id, 'managePurchases'), false)
     or public.feature_effective(p_workspace_id, 'purchases') is not true then
    raise exception using errcode = '42501', message = 'business payables are not available';
  end if;
  if (p_after_created is null) <> (p_after_id is null) then
    raise exception using errcode = '22023', message = 'both cursor fields are required';
  end if;
  if p_creditor_kind is not null and p_creditor_kind not in ('supplier', 'member') then
    raise exception using errcode = '22023', message = 'unknown creditor kind';
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
     where o.workspace_id = p_workspace_id and o.currency = p_currency
       and o.state <> 'cancelled'
       and (p_creditor_kind is null or o.creditor_kind = p_creditor_kind)
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
revoke execute on function public.business_payables_page_v1(uuid, text, text, timestamptz, uuid, int) from public, anon;
grant execute on function public.business_payables_page_v1(uuid, text, text, timestamptz, uuid, int) to authenticated;

select public.set_deskilo_schema_version(832);
