-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0425 (#2361) — the return of a Canadian registrant by tax.
--
-- The GST/HST return (GST34) and Revenu Québec's FPZ-500 report different
-- taxes: GST/HST collected on line 103, QST collected on the QST part. A
-- line of the return at 14.975 % is both, so `vat_return_summary` now
-- carries, on each line whose taxes are known, the split
--
--   "components": [{"scheme": "GST", "authority": "CA", "percent": 5,
--                   "base_cents": ..., "tax_cents": ...}, ...]
--
--   * an OUTPUT line: the components frozen on the issued invoices (0423),
--     scaled to the part of each invoice the return takes (the whole of it
--     on an invoice-date basis), summed;
--   * an INPUT line: the split of the deductible tax at the same rates
--     (the GST/HST input tax credit and the QST input tax refund are
--     claimed apart), `vat_components_entry` on the workspace's country,
--     on the base the deductible share corresponds to;
--   * in both, the last component takes the rounding remainder so the
--     components always add up to the line's tax;
--   * a line is split only when EVERY row of it is: one that is not (an
--     invoice before 0423, a rate that is not split) carries no key.
-- A seller outside Canada gets exactly the lines it got before. The
-- declaration stores these lines, so a filed return keeps its split.

create or replace function public.vat_return_summary(p_workspace_id uuid, p_start date, p_end date)
returns table(lines jsonb, total_net_cents integer, total_vat_cents integer, invoice_count integer)
language sql stable security definer set search_path = public as $fn$
  with a as (
    select * from public.vat_return_lines(p_workspace_id, p_start, p_end)
  ), ac as (
    -- every row of the return with the taxes it is made of (ord null: none known)
    select a.direction, a.correction, a.corrects, a.percent, a.category,
           a.invoice_id, a.net_cents, k.ord, k.scheme, k.authority, k.cpercent, k.tax
      from a
      left join lateral (
        select o.ord, o.c ->> 'scheme' as scheme, o.c ->> 'authority' as authority,
               (o.c ->> 'percent')::numeric as cpercent,
               round((o.c ->> 'tax_cents')::numeric * a.net_cents
                     / nullif((t.t ->> 'net_cents')::numeric, 0))::bigint as tax
          from public.invoices i
          cross join lateral jsonb_array_elements(coalesce(i.vat_totals, '[]'::jsonb)) t(t)
          cross join lateral jsonb_array_elements(coalesce(t.t -> 'components', '[]'::jsonb))
               with ordinality o(c, ord)
         where a.direction = 'output' and i.id = a.invoice_id
           and (t.t ->> 'percent')::numeric = a.percent
           and coalesce(t.t ->> 'category', 'S') = a.category
        union all
        select o.ord, o.c ->> 'scheme', o.c ->> 'authority', (o.c ->> 'percent')::numeric,
               (o.c ->> 'tax_cents')::bigint
          from public.workspaces w
          cross join lateral jsonb_array_elements(coalesce(
                 public.vat_components_entry(w.country_code, a.percent,
                                             round((a.gross_cents - a.net_cents) * 100.0 / a.percent)::bigint,
                                             a.gross_cents - a.net_cents) -> 'components', '[]'::jsonb))
               with ordinality o(c, ord)
         where a.direction = 'input' and w.id = p_workspace_id
      ) k on true
  ), l as (
    select a.direction, a.correction, a.corrects, a.percent, a.category,
           sum(a.gross_cents)::bigint as gross, sum(a.net_cents)::bigint as net,
           count(distinct a.invoice_id)::int as n
      from a group by a.direction, a.correction, a.corrects, a.percent, a.category
  ), cg as (
    select ac.direction, ac.correction, ac.corrects, ac.percent, ac.category,
           ac.ord, ac.scheme, ac.authority, ac.cpercent, sum(ac.tax)::bigint as tax
      from ac where ac.ord is not null
     group by ac.direction, ac.correction, ac.corrects, ac.percent, ac.category,
              ac.ord, ac.scheme, ac.authority, ac.cpercent
  ), miss as (
    select ac.direction, ac.correction, ac.corrects, ac.percent, ac.category
      from ac where ac.ord is null
     group by ac.direction, ac.correction, ac.corrects, ac.percent, ac.category
  ), j as (
    select l.*, d.period_start as c_start, d.period_end as c_end
      from l left join public.vat_declarations d on d.id = l.corrects
  )
  select coalesce((select jsonb_agg(
                     jsonb_build_object(
                       'percent', j.percent, 'category', j.category,
                       'gross_cents', j.gross, 'net_cents', j.net,
                       'vat_cents', j.gross - j.net, 'invoice_count', j.n)
                     || case when j.direction = 'input'
                          then jsonb_build_object('direction', 'input')
                          else '{}'::jsonb end
                     || case when j.correction then jsonb_build_object(
                          'correction', true, 'corrects', j.corrects,
                          'corrects_start', j.c_start, 'corrects_end', j.c_end)
                        else '{}'::jsonb end
                     || coalesce((
                          select case when count(*) = 0 then null else jsonb_build_object('components', jsonb_agg(
                                   jsonb_build_object(
                                     'scheme', g.scheme, 'authority', g.authority,
                                     'percent', g.cpercent, 'base_cents', j.net,
                                     'tax_cents', case when g.ord = g.last_ord
                                       then (j.gross - j.net) - g.prior else g.tax end)
                                   order by g.ord)) end
                            from (
                              select x.*, max(x.ord) over () as last_ord,
                                     coalesce(sum(x.tax) over (order by x.ord
                                       rows between unbounded preceding and 1 preceding), 0) as prior
                                from cg x
                               where (x.direction, x.correction, x.corrects, x.percent, x.category)
                                     is not distinct from
                                     (j.direction, j.correction, j.corrects, j.percent, j.category)
                            ) g
                           where not exists (select 1 from miss m
                                              where (m.direction, m.correction, m.corrects, m.percent, m.category)
                                                    is not distinct from
                                                    (j.direction, j.correction, j.corrects, j.percent, j.category))
                        ), '{}'::jsonb)
                   order by j.direction desc, j.correction, j.c_start,
                            j.percent desc, j.category)
                     from j), '[]'::jsonb),
         coalesce((select sum(l.net) from l where l.direction = 'output'), 0)::int,
         coalesce((select sum(case when l.direction = 'output' then l.gross - l.net
                                   else l.net - l.gross end) from l), 0)::int,
         (select count(distinct a.invoice_id) from a where a.direction = 'output')::int;
$fn$;

revoke execute on function public.vat_return_summary(uuid, date, date) from public, anon;

select public.set_deskilo_schema_version(425);
