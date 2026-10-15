-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0439 (#2362) -- the sales-tax summary of a period, from the SQL function.
--
-- A seller in the United States files with each state's portal (or an SST /
-- Avalara service): none is reachable from here and the app files nothing. What
-- it can state is the figures the return is made of, from the invoices issued
-- in the period (voided ones left out, a credit note subtracting itself), as
-- the jurisdictions they were frozen with (0434):
--
--   taxable            per state: the taxed sales and the tax collected
--   tax                per state and jurisdiction (state, county, city,
--                      district): the base, the rate and the tax collected
--   exempt_statute     per state: the sales the state's law exempts
--   exempt_certificate per state: the sales a customer's certificate exempts
--   outside            per state: what is outside the tax (a licence to
--                      occupy space, a payment)
--
-- `sales_tax_return(workspace, from, to)` is read by whoever may view the
-- finances or export data of the workspace. The Dart worksheet writes it as a
-- CSV for the owner to key into the portal.

create or replace function public.sales_tax_return(p_workspace_id uuid, p_start date, p_end date)
returns table (state text, kind text, authority text, level text, name text, percent numeric,
               base_cents bigint, tax_cents bigint, invoice_count integer)
language plpgsql stable security definer set search_path = public as $fn$
begin
  if auth.uid() is null
     or not (public.has_permission(p_workspace_id, 'viewFinances')
             or public.has_permission(p_workspace_id, 'exportData')) then
    raise exception 'not allowed';
  end if;
  return query
  with inv as (
    select i.id, i.vat_totals
      from public.invoices i
      join public.workspaces w on w.id = i.workspace_id
     where i.workspace_id = p_workspace_id and i.voided_at is null
       and (i.issued_at at time zone w.timezone)::date between p_start and p_end
  ), e as (
    select inv.id, t.t
      from inv, lateral jsonb_array_elements(coalesce(inv.vat_totals, '[]'::jsonb)) t(t)
     where t.t ? 'jurisdiction'
  ), taxed as (
    select e.t ->> 'state' as st, 'taxable'::text as k, ''::text as au, ''::text as lv, ''::text as nm,
           0::numeric as pc, sum((e.t ->> 'net_cents')::bigint)::bigint as base,
           sum((e.t ->> 'vat_cents')::bigint)::bigint as tx, count(distinct e.id)::int as n
      from e where e.t ->> 'category' = 'S'
     group by 1
  ), tax as (
    select e.t ->> 'state', 'tax'::text, c.c ->> 'authority', c.c ->> 'level', c.c ->> 'name',
           (c.c ->> 'percent')::numeric,
           sum((c.c ->> 'base_cents')::bigint)::bigint, sum((c.c ->> 'tax_cents')::bigint)::bigint,
           count(distinct e.id)::int
      from e, lateral jsonb_array_elements(coalesce(e.t -> 'components', '[]'::jsonb)) c(c)
     where e.t ->> 'category' = 'S'
     group by 1, 3, 4, 5, 6
  ), other as (
    select e.t ->> 'state',
           case e.t ->> 'category'
             when 'E' then 'exempt_' || coalesce(nullif(e.t ->> 'exemption_basis', ''), 'statute')
             else 'outside' end,
           ''::text, ''::text, ''::text, 0::numeric,
           sum((e.t ->> 'net_cents')::bigint)::bigint, 0::bigint, count(distinct e.id)::int
      from e where e.t ->> 'category' in ('E', 'O')
     group by 1, 2
  )
  select x.*
    from (select * from taxed union all select * from tax union all select * from other) x
   order by 1, 2, 3, 5;
end;
$fn$;
revoke execute on function public.sales_tax_return(uuid, date, date) from public, anon;
grant execute on function public.sales_tax_return(uuid, date, date) to authenticated;

select public.set_deskilo_schema_version(439);
