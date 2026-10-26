-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (tax_reference_valid, expense_vat_payload, vat_input_amounts,
-- vat_return_lines and vat_return_summary restated whole; one function and
-- two rows of the tax reference store added; no table, no policy; a filed
-- return is untouched)
--
-- 0605 (#2360) -- the two Ziffern of the Swiss MWST return the lines did not
-- carry yet:
--
--   * 205, the supplies opted for under art. 22 MWSTG. A Swiss invoice
--     freezes whether its letting is bare (`land_taxation.bare_letting`,
--     0421); a property line of such an invoice that is taxed was taxed
--     because the option was in force. `vat_return_summary` (0425) states
--     on each taxed sales line the base of that part, `opted_net_cents`,
--     in the share the property lines have of the invoice at that rate.
--     The line itself is unchanged: 205 is part of 200 and of 303.
--   * 383, the acquisition tax (Bezugsteuer, art. 45-49 MWSTG): a service
--     bought from a supplier abroad carries no Swiss VAT, so the space owes
--     it on the amount it paid and deducts it as input tax. An expense says
--     so (`vat.acquisition`, kept by `expense_vat_payload`, 0413); then
--     `vat_input_amounts` (0587) returns its deductible share on the amount
--     as base (`vat_acquisition_split`) and the tax owed under the category
--     `acquisition`, which `vat_return_lines` (0413) files among the tax
--     due. The summary's turnover and document count leave it out: it is
--     tax owed on a purchase, not a sale.
--   * the `form_box` rows of both boxes (unconfirmed, with their source);
--     a `form_box` row learns `categories`, the lines a box adds beyond the
--     rated sales (`tax_reference_valid`, 0600, restated whole). The 383
--     row carries `acquisition`, and `expense_vat_payload` refuses the flag
--     in a space whose country has no such row in force: no other return
--     declares the tax it would owe.
--
-- Not here: a purchase document (a member's receipt, a supplier bill) does
-- not say it was bought abroad -- a supplier bill reaches no return yet; the
-- posting of the acquisition tax in the books (the accounting handoff).

-- ── the expense says it was bought from abroad ─────────────────────────
create or replace function public.expense_vat_payload(
  p_workspace_id uuid, p_vat jsonb
) returns jsonb
language plpgsql stable security definer set search_path = public as $fn$
declare
  v_percent numeric;
  v_share numeric;
begin
  if p_vat is null or jsonb_typeof(p_vat) <> 'object' then
    return null;
  end if;
  if not public.feature_effective(p_workspace_id, 'inputVat') then
    raise exception 'input VAT is switched off in this space';
  end if;
  v_percent := (p_vat ->> 'percent')::numeric;
  v_share := coalesce((p_vat ->> 'deductible_pct')::numeric, 100);
  if v_percent is null or v_percent <= 0 or v_percent > 100 then
    raise exception 'the VAT rate of an expense lies between 0 and 100';
  end if;
  if v_share < 0 or v_share > 100 then
    raise exception 'the deductible share lies between 0 and 100';
  end if;
  if coalesce((p_vat ->> 'acquisition')::boolean, false) and not exists (
       select 1 from public.workspaces w
        cross join lateral (select (now() at time zone coalesce(nullif(w.timezone, ''), 'UTC'))::date as d) today
        join public.tax_reference r
          on r.domain = 'form_box' and r.country = upper(btrim(coalesce(w.country_code, '')))
         and r.valid_from <= today.d and (r.valid_to is null or r.valid_to > today.d)
        where w.id = p_workspace_id and coalesce(r.value -> 'categories' ? 'acquisition', false)) then
    raise exception 'this space''s return has no acquisition tax box';
  end if;
  return jsonb_build_object('percent', trim_scale(v_percent),
                            'deductible_pct', trim_scale(v_share))
         || case when coalesce((p_vat ->> 'asset')::boolean, false)
                 then jsonb_build_object('asset', true) else '{}'::jsonb end
         -- A service bought from a supplier abroad, the tax not on its
         -- invoice: the space owes it itself (CH Bezugsteuer, art. 45 MWSTG)
         -- and deducts the share it may; the amount is then the base.
         || case when coalesce((p_vat ->> 'acquisition')::boolean, false)
                 then jsonb_build_object('acquisition', true) else '{}'::jsonb end;
end;
$fn$;
revoke execute on function public.expense_vat_payload(uuid, jsonb)
  from public, anon, authenticated;

-- The acquisition tax of a service bought abroad for [p_net] at
-- [p_percent], and the share [p_share] of it the space may deduct, both
-- rounded half away from zero (the Dart twin is `vatAcquisitionSplit`).
create or replace function public.vat_acquisition_split(
  p_net bigint, p_percent numeric, p_share numeric
) returns table (tax_cents bigint, deductible_cents bigint)
language sql immutable set search_path = public as $fn$
  select t, round(t::numeric * greatest(0, least(100, p_share)) / 100)::bigint
    from (select round(p_net::numeric * p_percent / 100)::bigint as t) x;
$fn$;
revoke execute on function public.vat_acquisition_split(bigint, numeric, numeric)
  from public, anon, authenticated;

-- ── the return: the input tax and the tax owed ─────────────────────────
-- 0587's amounts; an acquisition gives its deductible share on the amount
-- as base, and the tax owed.
create or replace function public.vat_input_amounts(
  p_workspace_id uuid, p_start date, p_end date
) returns table (expense_id uuid, tax_point date, percent numeric,
                 category text, gross_cents bigint, net_cents bigint)
language sql stable security definer set search_path = public as $fn$
  with w as (
    select coalesce(nullif(ws.timezone, ''), 'UTC') as tz
      from public.workspaces ws where ws.id = p_workspace_id
  ), ev as (
    select e.id, e.workspace_id, e.actor_member_id, e.payload,
           (e.decided_at at time zone w.tz)::date as tax_point
      from public.events e cross join w
     where e.workspace_id = p_workspace_id
       and e.type = 'expense' and e.status = 'confirmed'
       and e.decided_at is not null
       and (e.decided_at at time zone w.tz)::date between p_start and p_end
       and public.feature_effective(p_workspace_id, 'inputVat')
  )
  , paid as (
    select ev.*,
           (ev.payload ->> 'amount_cents')::bigint as amount,
           (ev.payload #>> '{vat,percent}')::numeric as rate,
           coalesce((ev.payload #>> '{vat,deductible_pct}')::numeric, 100) as share,
           coalesce((ev.payload #>> '{vat,acquisition}')::boolean, false) as acquisition
      from ev
     where coalesce((ev.payload #>> '{vat,percent}')::numeric, 0) > 0
  )
  -- The deductible tax: of the VAT the amount included, or of the
  -- acquisition tax owed on an amount that is the base.
  select p.id, p.tax_point, trim_scale(p.rate),
         case when coalesce((p.payload #>> '{vat,asset}')::boolean, false)
              then 'asset' else 'S' end,
         s.net_cents + s.deductible_cents, s.net_cents
    from paid p
    cross join lateral (
      select v.net_cents, v.deductible_cents
        from public.vat_input_split(p.amount, p.rate, p.share) v
       where not p.acquisition
      union all
      select p.amount, q.deductible_cents
        from public.vat_acquisition_split(p.amount, p.rate, p.share) q
       where p.acquisition
    ) s
  union all
  -- The acquisition tax owed: the amount is its base (`vat_return_lines`
  -- files it among the tax due).
  select p.id, p.tax_point, trim_scale(p.rate), 'acquisition',
         p.amount + q.tax_cents, p.amount
    from paid p
    cross join lateral public.vat_acquisition_split(p.amount, p.rate, p.share) q
   where p.acquisition
  union all
  -- The receipt's own lines, once: the event that filed it states no rate.
  select ev.id, ev.tax_point, trim_scale(l.tax_rate_percent),
         case when l.recognition_kind = 'asset' then 'asset' else 'S' end,
         sum(l.net_cents + l.recoverable_tax_cents)::bigint, sum(l.net_cents)::bigint
    from ev
    join public.purchase_sources ps
      on ps.workspace_id = ev.workspace_id and ps.source_kind = 'expense_event'
     and ps.source_id = ev.id and ps.role = 'origin'
    join public.purchase_documents d
      on d.workspace_id = ps.workspace_id and d.id = ps.purchase_id
     and d.kind = 'member_receipt' and d.submitter_member_id = ev.actor_member_id
    join public.purchase_lines l on l.workspace_id = d.workspace_id and l.purchase_id = d.id
   where ev.payload #>> '{vat,source}' = 'lines'
     and l.tax_rate_percent > 0 and l.tax_cents > 0 and l.recoverable_tax_cents is not null
   group by ev.id, ev.tax_point, trim_scale(l.tax_rate_percent),
            case when l.recognition_kind = 'asset' then 'asset' else 'S' end;
$fn$;
revoke execute on function public.vat_input_amounts(uuid, date, date)
  from public, anon, authenticated;

-- 0413's lines; the acquisition tax is filed among the tax due.
create or replace function public.vat_return_lines(
  p_workspace_id uuid, p_start date, p_end date
) returns table (direction text, invoice_id uuid, tax_point date,
                 percent numeric, category text, credit_note boolean,
                 correction boolean, corrects uuid, gross_cents bigint,
                 net_cents bigint)
language sql stable security definer set search_path = public as $fn$
  with locks as (
    select d.id, d.period_start, d.period_end,
           coalesce(d.submitted_at, d.created_at) as filed_at
      from public.vat_declarations d
     where d.workspace_id = p_workspace_id and d.status = 'filed'
  ), earlier as (
    select l.* from locks l where l.period_end < p_start
  ), span as (
    select min(e.period_start) as s, max(e.period_end) as e from earlier e
  ), amounts_now as (
    select 'output'::text as direction, a.invoice_id, a.tax_point, a.percent,
           a.category, a.credit_note, a.gross_cents, a.net_cents
      from span
      cross join lateral public.vat_return_amounts(p_workspace_id, span.s, span.e) a
     where span.s is not null
    union all
    select case when i.category = 'acquisition' then 'output' else 'input' end,
           i.expense_id, i.tax_point, i.percent, i.category, false,
           i.gross_cents, i.net_cents
      from span
      cross join lateral public.vat_input_amounts(p_workspace_id, span.s, span.e) i
     where span.s is not null
  ), ledger as (
    select a.* from amounts_now a
     where exists (select 1 from earlier l
                    where a.tax_point between l.period_start and l.period_end)
    union all
    select r.direction, r.invoice_id, r.tax_point, r.percent, r.category,
           r.credit_note, -r.gross_cents, -r.net_cents
      from public.vat_return_entries r
     where r.workspace_id = p_workspace_id
       and exists (select 1 from earlier l
                    where r.tax_point between l.period_start and l.period_end)
  ), delta as (
    select g.direction, g.invoice_id, g.tax_point, g.percent, g.category,
           g.credit_note,
           sum(g.gross_cents)::bigint as gross, sum(g.net_cents)::bigint as net
      from ledger g
     group by g.direction, g.invoice_id, g.tax_point, g.percent, g.category,
              g.credit_note
    having sum(g.gross_cents) <> 0 or sum(g.net_cents) <> 0
  ), own as (
    select 'output'::text as direction, a.invoice_id, a.tax_point, a.percent,
           a.category, a.credit_note, a.gross_cents, a.net_cents
      from public.vat_return_amounts(p_workspace_id, p_start, p_end) a
    union all
    select case when i.category = 'acquisition' then 'output' else 'input' end,
           i.expense_id, i.tax_point, i.percent, i.category, false,
           i.gross_cents, i.net_cents
      from public.vat_input_amounts(p_workspace_id, p_start, p_end) i
  )
  select o.direction, o.invoice_id, o.tax_point, o.percent, o.category,
         o.credit_note, false, null::uuid, o.gross_cents, o.net_cents
    from own o
   where not exists (select 1 from locks l
                      where o.tax_point between l.period_start and l.period_end
                        and (l.period_start, l.period_end) <> (p_start, p_end))
  union all
  select d.direction, d.invoice_id, d.tax_point, d.percent, d.category,
         d.credit_note, true,
         (select l.id from earlier l
           where d.tax_point between l.period_start and l.period_end
           order by l.filed_at, l.id limit 1),
         d.gross, d.net
    from delta d;
$fn$;
revoke execute on function public.vat_return_lines(uuid, date, date)
  from public, anon, authenticated;

-- 0425's summary; a taxed sales line states the part opted for, and the
-- turnover and the document count are the sales'.
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
  ), op as (
    -- The part of a taxed sale that is an exempt letting the seller opted
    -- to tax (CH art. 22 MWSTG: the bare letting frozen on the invoice,
    -- taxed): its rows' base in the share the property lines have of the
    -- invoice's lines at that rate.
    select a.correction, a.corrects, a.percent,
           sum(round(a.net_cents * s.share))::bigint as opted
      from a
      join public.invoices i on i.id = a.invoice_id
      cross join lateral (
        select sum((x.l ->> 'amount_cents')::numeric)
                 filter (where coalesce(x.l ->> 'supply', 'property') <> 'general')
               / nullif(sum((x.l ->> 'amount_cents')::numeric), 0) as share
          from jsonb_array_elements(case when jsonb_typeof(i.lines) = 'array'
                                         then i.lines else '[]'::jsonb end) x(l)
         where coalesce((x.l ->> 'vat_percent')::numeric, 0) = a.percent
      ) s
     where a.direction = 'output' and a.category = 'S'
       and coalesce((i.legal_snapshot #>> '{land_taxation,bare_letting}')::boolean, false)
     group by a.correction, a.corrects, a.percent
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
                     || coalesce((
                          select jsonb_build_object('opted_net_cents', o.opted)
                            from op o
                           where j.direction = 'output' and j.category = 'S' and o.opted <> 0
                             and (o.correction, o.corrects, o.percent)
                                 is not distinct from (j.correction, j.corrects, j.percent)
                        ), '{}'::jsonb)
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
         coalesce((select sum(l.net) from l
                    where l.direction = 'output' and l.category <> 'acquisition'), 0)::int,
         coalesce((select sum(case when l.direction = 'output' then l.gross - l.net
                                   else l.net - l.gross end) from l), 0)::int,
         (select count(distinct a.invoice_id) from a
           where a.direction = 'output' and a.category <> 'acquisition')::int;
$fn$;

revoke execute on function public.vat_return_summary(uuid, date, date) from public, anon;

-- ── the boxes ──────────────────────────────────────────────────────────
-- 0600's shapes; a return box may name the line categories it adds.
create or replace function public.tax_reference_valid(p_domain text, p_value jsonb)
returns boolean language plpgsql immutable set search_path = public as $fn$
declare
  v_allowed text[];
begin
  -- A missing key makes a comparison NULL, and a CHECK passes on NULL: every
  -- answer is coalesced to false (the shapes of 0427 and 0430 had the hole).
  if p_value is null or jsonb_typeof(p_value) <> 'object' then return false; end if;
  case p_domain
    when 'rate' then
      v_allowed := array['label', 'percent', 'group', 'category', 'exemption_reason', 'position'];
      if exists (select 1 from jsonb_object_keys(p_value) k where k <> all (v_allowed)) then return false; end if;
      if jsonb_typeof(p_value -> 'label') is distinct from 'string'
         or btrim(p_value ->> 'label') = '' then return false; end if;
      if jsonb_typeof(p_value -> 'percent') is distinct from 'number' then return false; end if;
      if (p_value ->> 'percent')::numeric < 0 or (p_value ->> 'percent')::numeric > 99.999 then return false; end if;
      if jsonb_typeof(p_value -> 'group') is distinct from 'string'
         or (p_value ->> 'group') <> all (array['standard', 'intermediate', 'reduced', 'super_reduced',
                                               'zero', 'exempt', 'not_subject', 'deposit', 'excise']) then
        return false;
      end if;
      if jsonb_typeof(p_value -> 'category') is distinct from 'string'
         or (p_value ->> 'category') <> all (array['S', 'Z', 'E', 'O']) then return false; end if;
      if p_value ? 'exemption_reason' and jsonb_typeof(p_value -> 'exemption_reason') <> 'string' then return false; end if;
      if p_value ? 'position' and (jsonb_typeof(p_value -> 'position') <> 'number'
                                   or (p_value ->> 'position') !~ '^[0-9]+$') then return false; end if;
      return true;
    when 'eu_member' then
      -- A member state ({}), or another spelling of one ({alias_of}).
      return coalesce(p_value = '{}'::jsonb
          or (p_value ? 'alias_of'
              and not exists (select 1 from jsonb_object_keys(p_value) k where k <> 'alias_of')
              and jsonb_typeof(p_value -> 'alias_of') = 'string'
              and (p_value ->> 'alias_of') ~ '^[A-Z]{2}$'), false);
    when 'catalogue_note' then
      if exists (select 1 from jsonb_object_keys(p_value) k where k <> 'text') then return false; end if;
      return coalesce(jsonb_typeof(p_value -> 'text') = 'string' and btrim(p_value ->> 'text') <> '', false);
    when 'group_example' then
      if exists (select 1 from jsonb_object_keys(p_value) k where k <> all (array['group', 'text', 'position'])) then return false; end if;
      if jsonb_typeof(p_value -> 'group') is distinct from 'string'
         or (p_value ->> 'group') <> all (array['standard', 'intermediate', 'reduced', 'super_reduced',
                                               'zero', 'exempt', 'not_subject', 'deposit', 'excise']) then
        return false;
      end if;
      if p_value ? 'position' and (jsonb_typeof(p_value -> 'position') <> 'number'
                                   or (p_value ->> 'position') !~ '^[0-9]+$') then return false; end if;
      return coalesce(jsonb_typeof(p_value -> 'text') = 'string' and btrim(p_value ->> 'text') <> '', false);
    when 'threshold' then
      if exists (select 1 from jsonb_object_keys(p_value) k where k <> all (array['cents', 'effect', 'currency', 'charge_cents'])) then return false; end if;
      return coalesce(jsonb_typeof(p_value -> 'cents') = 'number' and (p_value ->> 'cents') ~ '^[1-9][0-9]*$'
         and (p_value ->> 'effect') = any (array['next_year', 'immediate', 'annual_operations', 'simplified_invoice', 'stamp_duty'])
         and jsonb_typeof(p_value -> 'currency') = 'string' and (p_value ->> 'currency') ~ '^[A-Z]{3}$'
         and (not p_value ? 'charge_cents'
              or (jsonb_typeof(p_value -> 'charge_cents') = 'number'
                  and (p_value ->> 'charge_cents') ~ '^[1-9][0-9]*$')), false);
    when 'tax_point' then
      if exists (select 1 from jsonb_object_keys(p_value) k
                  where k <> all (array['standard', 'invoice_option', 'cash_option', 'cash_backstop'])) then return false; end if;
      return coalesce((p_value ->> 'standard') = any (array['invoice', 'receipt', 'service_period', 'earlier_of'])
         and jsonb_typeof(p_value -> 'invoice_option') = 'boolean'
         and jsonb_typeof(p_value -> 'cash_option') = 'boolean'
         and (p_value ->> 'cash_backstop') = any (array['none', 'end_of_following_year', 'one_year_after_issue']), false);
    when 'mandate' then
      if exists (select 1 from jsonb_object_keys(p_value) k where k <> all (array['duty', 'from'])) then return false; end if;
      if (p_value ->> 'duty') <> all (array['receive_all', 'issue_large', 'issue_all', 'e_reporting', 'invoice_records'])
         or (p_value ->> 'duty') is null then return false; end if;
      begin
        return coalesce(jsonb_typeof(p_value -> 'from') = 'string'
           and to_char((p_value ->> 'from')::date, 'YYYY-MM-DD') = (p_value ->> 'from'), false);
      exception when others then
        return false;
      end;
    when 'issuing_gate' then
      if exists (select 1 from jsonb_object_keys(p_value) k
                  where k <> all (array['supported', 'requires_tax_number', 'national_channel_required', 'currency', 'tax_system',
                           'outside_vat_postal_codes'])) then return false; end if;
      return coalesce(jsonb_typeof(p_value -> 'supported') = 'boolean'
         and jsonb_typeof(p_value -> 'requires_tax_number') = 'boolean'
         and jsonb_typeof(p_value -> 'national_channel_required') = 'boolean'
         and (not p_value ? 'currency'
              or (jsonb_typeof(p_value -> 'currency') = 'string' and (p_value ->> 'currency') ~ '^[A-Z]{3}$'))
         and (not p_value ? 'tax_system'
              or (jsonb_typeof(p_value -> 'tax_system') = 'string'
                  and (p_value ->> 'tax_system') = any (array['vat', 'sales_tax'])))
         and (not p_value ? 'outside_vat_postal_codes'
              or (jsonb_typeof(p_value -> 'outside_vat_postal_codes') = 'array'
                  and not exists (select 1 from jsonb_array_elements(p_value -> 'outside_vat_postal_codes') e
                                   where jsonb_typeof(e) <> 'string'
                                      or (e #>> '{}') !~ '^[0-9A-Z]{1,5}$'))), false);
    when 'exemption_text' then
      if exists (select 1 from jsonb_object_keys(p_value) k where k <> all (array['regime', 'text'])) then return false; end if;
      return coalesce(jsonb_typeof(p_value -> 'regime') = 'string' and btrim(p_value ->> 'regime') <> ''
         and jsonb_typeof(p_value -> 'text') = 'string' and btrim(p_value ->> 'text') <> '', false);
    when 'vat_id_pattern' then
      if exists (select 1 from jsonb_object_keys(p_value) k where k <> 'pattern') then return false; end if;
      if jsonb_typeof(p_value -> 'pattern') is distinct from 'string' or btrim(p_value ->> 'pattern') = '' then return false; end if;
      -- A pattern the database cannot compile is not a pattern.
      begin
        perform '' ~ (p_value ->> 'pattern');
      exception when others then
        return false;
      end;
      return true;
    when 'form_box' then
      -- A rated box of a return form: the wording it prints and the fiscal
      -- groups it adds up (or, for a catch-all box, every group but these).
      if exists (select 1 from jsonb_object_keys(p_value) k
                  where k <> all (array['label', 'groups', 'exclude_groups', 'categories'])) then return false; end if;
      -- The line categories a box adds beyond the rated sales (CH 383: the
      -- acquisition tax), each one the return lines know.
      if p_value ? 'categories' and (
           jsonb_typeof(p_value -> 'categories') <> 'array'
           or jsonb_array_length(p_value -> 'categories') = 0
           or exists (select 1 from jsonb_array_elements(p_value -> 'categories') e
                       where jsonb_typeof(e) <> 'string'
                          or (e #>> '{}') <> all (array['S', 'Z', 'E', 'O', 'AE', 'G', 'asset', 'acquisition']))) then
        return false;
      end if;
      if jsonb_typeof(p_value -> 'label') is distinct from 'string'
         or btrim(p_value ->> 'label') = '' then return false; end if;
      declare
        v_known text[] := array['standard', 'intermediate', 'reduced', 'super_reduced',
                                'zero', 'exempt', 'not_subject', 'deposit', 'excise'];
        v_take text[] := '{}';
        v_left text[] := '{}';
      begin
        if p_value ? 'groups' then
          if jsonb_typeof(p_value -> 'groups') <> 'array'
             or exists (select 1 from jsonb_array_elements(p_value -> 'groups') e
                         where jsonb_typeof(e) <> 'string') then return false; end if;
          select coalesce(array_agg(e #>> '{}'), '{}') into v_take
            from jsonb_array_elements(p_value -> 'groups') e;
        end if;
        if p_value ? 'exclude_groups' then
          if jsonb_typeof(p_value -> 'exclude_groups') <> 'array'
             or exists (select 1 from jsonb_array_elements(p_value -> 'exclude_groups') e
                         where jsonb_typeof(e) <> 'string') then return false; end if;
          select coalesce(array_agg(e #>> '{}'), '{}') into v_left
            from jsonb_array_elements(p_value -> 'exclude_groups') e;
        end if;
        -- A box that selects nothing, a group nobody knows, or a group both
        -- taken and excluded is not a selector.
        return cardinality(v_take) + cardinality(v_left) > 0
           and v_take <@ v_known and v_left <@ v_known
           and not v_take && v_left;
      end;
    when 'account_map' then
      -- A default an accounting export or the chart preview proposes: an
      -- account number (or a chart's code) and/or the export's tax code.
      if exists (select 1 from jsonb_object_keys(p_value) k
                  where k <> all (array['format', 'role', 'account', 'tax_code', 'label'])) then return false; end if;
      if (p_value ->> 'format') is null
         or (p_value ->> 'format') <> all (array['coa', 'fec', 'datev', 'sage', 'saf_t', 'ch_kmu']) then return false; end if;
      if jsonb_typeof(p_value -> 'role') is distinct from 'string'
         or btrim(p_value ->> 'role') = '' then return false; end if;
      if p_value ? 'label' and jsonb_typeof(p_value -> 'label') <> 'string' then return false; end if;
      if p_value ? 'account' and (jsonb_typeof(p_value -> 'account') <> 'string'
                                  or btrim(p_value ->> 'account') = '') then return false; end if;
      if p_value ? 'tax_code' and (jsonb_typeof(p_value -> 'tax_code') <> 'string'
                                   or btrim(p_value ->> 'tax_code') = '') then return false; end if;
      return p_value ? 'account' or p_value ? 'tax_code';
    when 'sales_tax' then
      -- The tax a postal code carries, one component per jurisdiction.
      if exists (select 1 from jsonb_object_keys(p_value) k where k <> all (array['state', 'components'])) then return false; end if;
      if jsonb_typeof(p_value -> 'state') is distinct from 'string'
         or (p_value ->> 'state') !~ '^[A-Z]{2}$' then return false; end if;
      if jsonb_typeof(p_value -> 'components') is distinct from 'array'
         or jsonb_array_length(p_value -> 'components') = 0 then return false; end if;
      if exists (select 1 from jsonb_array_elements(p_value -> 'components') c
                  where jsonb_typeof(c) <> 'object') then return false; end if;
      if exists (select 1 from jsonb_array_elements(p_value -> 'components') c
                  where exists (select 1 from jsonb_object_keys(c) k
                                 where k <> all (array['level', 'label', 'percent']))) then return false; end if;
      if exists (select 1 from jsonb_array_elements(p_value -> 'components') c
                  where jsonb_typeof(c -> 'level') is distinct from 'string'
                     or (c ->> 'level') <> all (array['state', 'county', 'city', 'district'])
                     or jsonb_typeof(c -> 'label') is distinct from 'string'
                     or btrim(c ->> 'label') = ''
                     or jsonb_typeof(c -> 'percent') is distinct from 'number') then return false; end if;
      return not exists (select 1 from jsonb_array_elements(p_value -> 'components') c
                          where (c ->> 'percent')::numeric < 0 or (c ->> 'percent')::numeric > 20);
    when 'retention' then
      -- How long a kind of record is kept, and from when the clock runs.
      if exists (select 1 from jsonb_object_keys(p_value) k where k <> all (array['years', 'from'])) then return false; end if;
      if jsonb_typeof(p_value -> 'years') is distinct from 'number'
         or (p_value ->> 'years') !~ '^[0-9]+$' then return false; end if;
      if (p_value ->> 'years')::int < 1 or (p_value ->> 'years')::int > 100 then return false; end if;
      return jsonb_typeof(p_value -> 'from') = 'string'
         and (p_value ->> 'from') = any (array['fiscal_year_end', 'document_date']);
    when 'rate_component' then
      -- The taxes inside a combined rate: they add up to the rate.
      if exists (select 1 from jsonb_object_keys(p_value) k where k <> all (array['percent', 'components'])) then return false; end if;
      if jsonb_typeof(p_value -> 'percent') is distinct from 'number' then return false; end if;
      if (p_value ->> 'percent')::numeric <= 0 or (p_value ->> 'percent')::numeric > 99.999 then return false; end if;
      if jsonb_typeof(p_value -> 'components') is distinct from 'array'
         or jsonb_array_length(p_value -> 'components') = 0 then return false; end if;
      if exists (select 1 from jsonb_array_elements(p_value -> 'components') c
                  where jsonb_typeof(c) <> 'object') then return false; end if;
      if exists (select 1 from jsonb_array_elements(p_value -> 'components') c
                  where exists (select 1 from jsonb_object_keys(c) k
                                 where k <> all (array['scheme', 'authority', 'percent']))) then return false; end if;
      if exists (select 1 from jsonb_array_elements(p_value -> 'components') c
                  where jsonb_typeof(c -> 'scheme') is distinct from 'string'
                     or btrim(c ->> 'scheme') = ''
                     or jsonb_typeof(c -> 'authority') is distinct from 'string'
                     or btrim(c ->> 'authority') = ''
                     or jsonb_typeof(c -> 'percent') is distinct from 'number') then return false; end if;
      if exists (select 1 from jsonb_array_elements(p_value -> 'components') c
                  where (c ->> 'percent')::numeric <= 0) then return false; end if;
      return (select abs(sum((c ->> 'percent')::numeric) - (p_value ->> 'percent')::numeric) < 0.0000001
                from jsonb_array_elements(p_value -> 'components') c);
    when 'taxability' then
      -- Whether a kind of line is taxed in a state.
      if exists (select 1 from jsonb_object_keys(p_value) k where k <> 'status') then return false; end if;
      return coalesce(jsonb_typeof(p_value -> 'status') = 'string'
         and (p_value ->> 'status') = any (array['taxable', 'exempt', 'not_applicable']), false);
    else
      return false;
  end case;
end;
$fn$;
revoke execute on function public.tax_reference_valid(text, jsonb) from public, anon, authenticated;

-- BEGIN GENERATED SEED (dart run tool/build_tax_reference_seed.dart)
insert into public.tax_reference
  (domain, country, key, valid_from, value, source, confirmed)
values
('form_box', 'CH', 'mwst/205', '2024-01-01', '{"label":"In Ziffer 200 enthaltene Entgelte aus nach Art. 21 von der Steuer ausgenommenen Leistungen, für welche nach Art. 22 optiert wird","groups":["standard","reduced","intermediate"]}'::jsonb, 'ESTV MWST-Abrechnung (effektive Methode, ab 2024), Ziffer 205: in Ziffer 200 enthaltene Entgelte aus nach Art. 21 MWSTG von der Steuer ausgenommenen Leistungen, für welche nach Art. 22 MWSTG optiert wird; eCH-0217 v2 element `opted` (#2360). The groups are every rate the option taxes at. Wording not yet re-verified against the printed form', false),
('form_box', 'CH', 'mwst/383', '2024-01-01', '{"label":"Bezugsteuer (Art. 45-49)","groups":["standard","reduced","intermediate"],"categories":["acquisition"]}'::jsonb, 'ESTV MWST-Abrechnung (effektive Methode, ab 2024), Ziffer 383: Bezugsteuer (Art. 45-49 MWSTG) auf Leistungen von Unternehmen mit Sitz im Ausland, ab 1.1.2024 (382 holds the amounts up to 2023); eCH-0217 v2 element `acquisitionTax`, per rate (#2360). The groups are every rate an acquisition is taxed at; the category `acquisition` is the tax owed on services bought from abroad, which only a country with this box lets an expense carry. Wording not yet re-verified against the printed form', false)
on conflict (domain, country, key, valid_from) do nothing;
-- END GENERATED SEED

select public.set_deskilo_schema_version(605);
