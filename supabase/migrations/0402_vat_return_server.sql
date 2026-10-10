-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0402 (#2357) — the server computes the VAT return; the client no
-- longer sends its figures, and nothing but the owner marks one filed.
--
-- Until now `save_vat_declaration` (0107) stored whatever lines and
-- totals the client sent, and the e-invoicing edge function stamped a
-- declaration `submitted` when an HTTP upload of its PDF came back 2xx —
-- with no DECL- number and from any endpoint the owner typed. No tax
-- authority accepts a PDF upload as a filing.
--
-- 1. `vat_return_amounts` is the SQL twin of the Dart tax-point engine
--    (`lib/features/money/domain/vat_tax_point.dart`, #2355): every
--    issued, non-voided, non-settlement document cut into dated amounts
--    per rate under its tax point — the seller country's rule or the
--    workspace's option, overridden by the exigibility the invoice froze
--    when it was issued (0349/0401) — with the same instalment
--    apportionment (cumulative, the remainder on the widest rate) and
--    the same cent rounding (net = gross x 100 / (100 + rate), halves
--    away from zero). A settlement is transparent: its confirmed payment
--    is allocated to its sources oldest first, as `accountingView` does.
--    `compute_vat_return` sums them per (rate, category, tax point, credit
--    note) for whoever may read the workspace's finances.
-- 2. `save_vat_declaration` ignores every figure the client sends and
--    stores the summary per (rate, category) the server computed; the
--    row is then `prepared`. Its arguments keep their old types, now
--    optional, so an older client still reaches it.
-- 3. The status model is draft (a row written by an older client, never
--    filed as such) -> prepared -> filed. `submitted` becomes `filed`.
--    A trigger refuses every direct change: figures come only from the
--    save (which recomputes), the filing only from
--    `mark_vat_declaration_submitted`, which takes a manual or export
--    channel and the authority's receipt reference, refuses `platform`,
--    and refuses a return whose period changed since it was prepared.
--    Both set a transaction-local writer token naming the row.

-- ============================================================ statuses
alter table public.vat_declarations
  drop constraint if exists vat_declarations_status_check;
update public.vat_declarations set status = 'filed' where status = 'submitted';
alter table public.vat_declarations
  add constraint vat_declarations_status_check
  check (status in ('draft', 'prepared', 'filed'));

-- ============================================================ the engine
-- vatSplit (vat_rate.dart): the net of a gross amount at a rate, halves
-- away from zero; a rate of zero or less leaves it whole.
create or replace function public.vat_split_net(p_gross bigint, p_percent numeric)
returns bigint
language sql immutable set search_path = public as $fn$
  select case when coalesce(p_percent, 0) <= 0 then p_gross
              else round(p_gross::numeric * 100 / (100 + p_percent))::bigint end;
$fn$;
revoke execute on function public.vat_split_net(bigint, numeric) from public, anon;

-- vatTaxPointPolicy: what one country allows.
create or replace function public.vat_tax_point_policy(p_country text)
returns table (standard text, invoice_option boolean, cash_option boolean,
               cash_backstop text)
language sql immutable set search_path = public as $fn$
  select case c when 'FR' then 'receipt'
                when 'DE' then 'service_period'
                when 'ES' then 'service_period'
                when 'IT' then 'earlier_of'
                when 'GB' then 'earlier_of'
                when 'UK' then 'earlier_of'
                when 'CH' then 'invoice'
                when 'CA' then 'earlier_of'
                else 'invoice' end,
         c = 'FR',
         c not in ('FR', 'CA'),
         case c when 'ES' then 'end_of_following_year'
                when 'IT' then 'one_year_after_issue'
                else 'none' end
    from (select upper(btrim(coalesce(p_country, ''))) as c) x;
$fn$;
revoke execute on function public.vat_tax_point_policy(text) from public, anon;

-- vatTaxPointBasis: the rule a seller in p_country declares on, given the
-- stored option (standard | invoice | cash | null).
create or replace function public.vat_tax_point_basis(p_country text, p_option text)
returns table (rule text, backstop text)
language sql immutable set search_path = public as $fn$
  select case when p_option = 'invoice' and p.invoice_option then 'invoice'
              when p_option = 'cash' and p.cash_option then 'receipt'
              else p.standard end,
         case when p_option = 'cash' and p.cash_option then p.cash_backstop
              else 'none' end
    from public.vat_tax_point_policy(p_country) p;
$fn$;
revoke execute on function public.vat_tax_point_basis(text, text) from public, anon;

-- Every dated amount of the workspace's documents whose tax point lies
-- in p_start..p_end — the ledger the Dart engine builds.
create or replace function public.vat_return_amounts(
  p_workspace_id uuid, p_start date, p_end date
) returns table (invoice_id uuid, tax_point date, percent numeric,
                 category text, credit_note boolean,
                 gross_cents bigint, net_cents bigint)
language plpgsql stable security definer set search_path = public as $fn$
#variable_conflict use_column
declare
  v_tz text;
  v_country text;
  v_legal jsonb;
  v_zero text;
  v_option text;
  v_ws_rule text;
  v_ws_backstop text;
  v_rule text;
  v_backstop text;
  v_policy record;
  inv record;
  ins record;
  v_rates numeric[];
  v_gross bigint[];
  v_net bigint[];
  v_total bigint;
  v_mag bigint;
  v_issued date;
  v_pay_on date[];
  v_pay_cents bigint[];
  v_want_on date[];
  v_want_cents bigint[];
  v_on date[];
  v_cents bigint[];
  v_left bigint;
  v_take bigint;
  v_stop date;
  v_day date;
  v_month text[];
  v_widest int;
  v_received bigint;
  v_complete boolean;
  v_cum bigint[];
  v_prev_g bigint[];
  v_prev_n bigint[];
  v_placed bigint;
  v_target bigint;
  v_cnet bigint;
  v_g bigint;
  v_n bigint;
  v_frozen text;
  i int;
  k int;
begin
  select coalesce(nullif(w.timezone, ''), 'UTC'),
         upper(btrim(coalesce(w.country_code, ''))),
         coalesce(w.invoice_legal, '{}'::jsonb),
         case w.vat_regime when 'vat_registered' then 'S'
                           when 'exempt' then 'E' else 'O' end
    into v_tz, v_country, v_legal, v_zero
    from public.workspaces w where w.id = p_workspace_id;
  if not found then return; end if;
  -- InvoiceLegal.fromJson: the stored option, else the #896 key.
  v_option := case
    when v_legal ->> 'vat_tax_point' in ('standard', 'invoice', 'cash')
      then v_legal ->> 'vat_tax_point'
    when v_legal ->> 'vat_exigibility' = 'invoice' then 'invoice'
    when v_legal ->> 'vat_exigibility' = 'payment' then 'cash'
  end;
  select b.rule, b.backstop into v_ws_rule, v_ws_backstop
    from public.vat_tax_point_basis(v_country, v_option) b;

  for inv in
    with settled as (
      -- allocateSettlementPayment: a confirmed settlement payment pays
      -- its sources in the snapshot's order, each up to what it owes.
      select s.id as sid, s.issued_at as s_issued, m.matched_at, e.n,
             nullif(e.v ->> 'invoice_id', '')::uuid as src,
             coalesce((e.v ->> 'total_cents')::numeric::bigint, 0) as owed,
             m.paid_cents
        from public.invoices s
        join public.invoice_matches m on m.invoice_id = s.id
             and m.status <> 'pending'
        cross join lateral jsonb_array_elements(
             case when jsonb_typeof(s.settles) = 'array' then s.settles
                  else '[]'::jsonb end) with ordinality e(v, n)
       where s.workspace_id = p_workspace_id and s.kind = 'settlement'
         and s.voided_at is null
    ), allocated as (
      select st.*,
             least(st.owed, st.paid_cents - coalesce(sum(greatest(st.owed, 0))
               over (partition by st.sid order by st.n
                     rows between unbounded preceding and 1 preceding), 0)) as take
        from settled st
    ), alloc as (
      -- The oldest settlement wins a source two of them name, as the
      -- view's newest-first walk leaves it.
      select distinct on (a.src) a.src, a.take, a.matched_at
        from allocated a
       where a.src is not null and a.owed > 0 and a.take > 0
       order by a.src, a.s_issued asc, a.sid desc
    )
    select i.id, i.issued_at, i.period, i.lines, i.total_cents,
           case when jsonb_typeof(i.vat_totals) = 'array' then i.vat_totals
                else '[]'::jsonb end as vat_totals,
           i.legal_snapshot,
           coalesce(al.take, m.paid_cents) as paid,
           coalesce(al.matched_at, m.matched_at) as matched_at,
           (al.src is not null or (m.id is not null and m.status <> 'pending'))
             as has_payment
      from public.invoices i
      left join public.invoice_matches m on m.invoice_id = i.id
      left join alloc al on al.src = i.id
     where i.workspace_id = p_workspace_id
       and i.kind <> 'settlement'
       and i.voided_at is null
     order by i.issued_at, i.id
  loop
    -- Gross and per-line net per rate, the rates highest first.
    select array_agg(x.r order by x.r desc), array_agg(x.g order by x.r desc),
           array_agg(x.n order by x.r desc)
      into v_rates, v_gross, v_net
      from (select coalesce((l ->> 'vat_percent')::numeric, 0) as r,
                   sum((l ->> 'amount_cents')::numeric::bigint)::bigint as g,
                   sum(public.vat_split_net((l ->> 'amount_cents')::numeric::bigint,
                       coalesce((l ->> 'vat_percent')::numeric, 0)))::bigint as n
              from jsonb_array_elements(
                     case when jsonb_typeof(inv.lines) = 'array' then inv.lines
                          else '[]'::jsonb end) l
             group by 1) x;
    continue when v_rates is null;

    v_total := 0;
    for k in 1 .. array_length(v_rates, 1) loop v_total := v_total + v_gross[k]; end loop;
    v_mag := abs(v_total);
    v_issued := (inv.issued_at at time zone v_tz)::date;

    -- The basis the invoice froze (frozenTaxPointBasis): the printed
    -- exigibility wins over the workspace's current choice.
    v_rule := v_ws_rule;
    v_backstop := v_ws_backstop;
    v_frozen := inv.legal_snapshot ->> 'vat_exigibility';
    select * into v_policy
      from public.vat_tax_point_policy(coalesce(inv.legal_snapshot ->> 'seller_country', ''));
    if v_frozen = 'payment' and v_rule <> 'receipt' then
      v_rule := 'receipt';
      v_backstop := v_policy.cash_backstop;
    elsif v_frozen = 'invoice' and v_rule = 'receipt' then
      v_rule := case when v_policy.standard = 'receipt' then 'invoice'
                     else v_policy.standard end;
      v_backstop := 'none';
    end if;

    -- paymentsOf: the instalments recorded one by one, capped at the
    -- confirmed aggregate; the aggregate alone when there are none.
    v_pay_on := '{}';
    v_pay_cents := '{}';
    if inv.has_payment then
      v_left := inv.paid;
      i := 0;
      for ins in
        select p.matched_at, p.amount_cents::bigint as cents
          from public.invoice_match_payments p
         where p.invoice_id = inv.id
         order by p.matched_at, p.id
      loop
        i := i + 1;
        exit when v_left <= 0;
        v_take := least(ins.cents, v_left);
        if v_take > 0 then
          v_pay_on := v_pay_on || (ins.matched_at at time zone v_tz)::date;
          v_pay_cents := v_pay_cents || v_take;
        end if;
        v_left := v_left - v_take;
      end loop;
      if i = 0 and inv.paid > 0 then
        v_pay_on := array[(inv.matched_at at time zone v_tz)::date];
        v_pay_cents := array[inv.paid::bigint];
      end if;
      -- The payments in day order.
      select coalesce(array_agg(d order by d, o), '{}'),
             coalesce(array_agg(c order by d, o), '{}')
        into v_pay_on, v_pay_cents
        from unnest(v_pay_on, v_pay_cents) with ordinality u(d, c, o);
    end if;

    -- _portions: what each rule asks for, then put() over it.
    v_want_on := '{}';
    v_want_cents := '{}';   -- null = whatever is left
    if inv.total_cents < 0 and v_rule <> 'receipt' then
      v_rule := 'invoice';  -- a credit note is due when issued
    end if;
    if v_mag = 0 then
      v_on := array[v_issued];
      v_cents := array[0::bigint];
    else
      if v_rule = 'invoice' then
        v_want_on := array[v_issued];
        v_want_cents := array[null::bigint];
      elsif v_rule = 'receipt' then
        v_stop := null;
        if inv.total_cents >= 0 and v_backstop = 'end_of_following_year' then
          v_month := regexp_match(coalesce(inv.period, ''), '^(\d{4})-(\d{2})');
          v_day := case when v_month is not null
                         and v_month[2]::int between 1 and 12
                        then (make_date(v_month[1]::int, v_month[2]::int, 1)
                              + interval '1 month' - interval '1 day')::date
                        else v_issued end;
          v_stop := make_date(extract(year from v_day)::int + 1, 12, 31);
        elsif inv.total_cents >= 0 and v_backstop = 'one_year_after_issue' then
          v_stop := make_date(extract(year from v_issued)::int + 1,
                              extract(month from v_issued)::int, 1)
                    + (extract(day from v_issued)::int - 1);
        end if;
        for k in 1 .. coalesce(array_length(v_pay_on, 1), 0) loop
          v_want_on := v_want_on || case when v_stop is not null and v_pay_on[k] > v_stop
                                          then v_stop else v_pay_on[k] end;
          v_want_cents := v_want_cents || v_pay_cents[k];
        end loop;
        if v_stop is not null then
          v_want_on := v_want_on || v_stop;
          v_want_cents := v_want_cents || null::bigint;
        end if;
      elsif v_rule = 'service_period' then
        v_month := regexp_match(coalesce(inv.period, ''), '^(\d{4})-(\d{2})');
        v_stop := case when v_month is not null and v_month[2]::int between 1 and 12
                       then (make_date(v_month[1]::int, v_month[2]::int, 1)
                             + interval '1 month' - interval '1 day')::date
                       else v_issued end;
        for k in 1 .. coalesce(array_length(v_pay_on, 1), 0) loop
          exit when v_pay_on[k] >= v_stop;
          v_want_on := v_want_on || v_pay_on[k];
          v_want_cents := v_want_cents || v_pay_cents[k];
        end loop;
        v_want_on := v_want_on || v_stop;
        v_want_cents := v_want_cents || null::bigint;
      else -- earlier_of
        for k in 1 .. coalesce(array_length(v_pay_on, 1), 0) loop
          exit when v_pay_on[k] >= v_issued;
          v_want_on := v_want_on || v_pay_on[k];
          v_want_cents := v_want_cents || v_pay_cents[k];
        end loop;
        v_want_on := v_want_on || v_issued;
        v_want_cents := v_want_cents || null::bigint;
      end if;
      v_on := '{}';
      v_cents := '{}';
      v_left := v_mag;
      for k in 1 .. coalesce(array_length(v_want_on, 1), 0) loop
        v_take := case when v_want_cents[k] is null then v_left
                       else least(v_want_cents[k], v_left) end;
        continue when v_take <= 0;
        i := coalesce(array_length(v_on, 1), 0);
        if i > 0 and v_on[i] = v_want_on[k] then
          v_cents[i] := v_cents[i] + v_take;
        else
          v_on := v_on || v_want_on[k];
          v_cents := v_cents || v_take;
        end if;
        v_left := v_left - v_take;
      end loop;
    end if;

    -- _slices: each portion over the rates, cumulatively; the rounding
    -- remainder of a step goes to the widest rate.
    v_widest := 1;
    for k in 2 .. array_length(v_rates, 1) loop
      if abs(v_gross[k]) > abs(v_gross[v_widest]) then v_widest := k; end if;
    end loop;
    v_prev_g := array_fill(0::bigint, array[array_length(v_rates, 1)]);
    v_prev_n := v_prev_g;
    v_received := 0;
    for i in 1 .. coalesce(array_length(v_on, 1), 0) loop
      v_received := v_received + v_cents[i];
      v_complete := v_mag = 0 or v_received >= v_mag;
      if v_complete then
        v_cum := v_gross;
      else
        v_cum := v_gross;
        v_placed := 0;
        for k in 1 .. array_length(v_rates, 1) loop
          v_cum[k] := round(v_gross[k]::numeric * v_received / v_mag)::bigint;
          v_placed := v_placed + v_cum[k];
        end loop;
        v_target := round(v_total::numeric * v_received / v_mag)::bigint;
        v_cum[v_widest] := v_cum[v_widest] + (v_target - v_placed);
      end if;
      for k in 1 .. array_length(v_rates, 1) loop
        v_cnet := case when v_complete then v_net[k]
                       else public.vat_split_net(v_cum[k], v_rates[k]) end;
        v_g := v_cum[k] - v_prev_g[k];
        v_n := v_cnet - v_prev_n[k];
        v_prev_g[k] := v_cum[k];
        v_prev_n[k] := v_cnet;
        continue when v_g = 0 and v_n = 0;
        continue when v_on[i] < p_start or v_on[i] > p_end;
        invoice_id := inv.id;
        tax_point := v_on[i];
        percent := trim_scale(v_rates[k]);
        category := coalesce(
          (select t ->> 'category' from jsonb_array_elements(inv.vat_totals) t
            where (t ->> 'percent')::numeric = v_rates[k]
              and coalesce(t ->> 'category', '') <> '' limit 1),
          case when v_rates[k] > 0 then 'S' else v_zero end);
        credit_note := inv.total_cents < 0;
        gross_cents := v_g;
        net_cents := v_n;
        return next;
      end loop;
    end loop;
  end loop;
end;
$fn$;
revoke execute on function public.vat_return_amounts(uuid, date, date)
  from public, anon, authenticated;

-- The period's return, line by line: one row per (rate, category, tax
-- point, credit note), for whoever may read the workspace's finances —
-- the same gate as the declarations themselves (0216).
create or replace function public.compute_vat_return(
  p_workspace uuid, p_start date, p_end date
) returns table (percent numeric, category text, tax_point date,
                 credit_note boolean, gross_cents bigint, net_cents bigint,
                 vat_cents bigint, invoice_count int)
language plpgsql stable security definer set search_path = public as $fn$
#variable_conflict use_column
begin
  if p_workspace is null or not exists (
       select 1 from public.workspaces_permitting(array['viewFinances']) w
        where w = p_workspace) then
    raise exception 'not allowed to read this workspace''s VAT';
  end if;
  if p_start is null or p_end is null or p_end < p_start then
    raise exception 'invalid period';
  end if;
  return query
    select a.percent, a.category, a.tax_point, a.credit_note,
           sum(a.gross_cents)::bigint, sum(a.net_cents)::bigint,
           (sum(a.gross_cents) - sum(a.net_cents))::bigint,
           count(distinct a.invoice_id)::int
      from public.vat_return_amounts(p_workspace, p_start, p_end) a
     group by a.percent, a.category, a.tax_point, a.credit_note
     order by a.percent desc, a.category, a.tax_point, a.credit_note;
end;
$fn$;
revoke execute on function public.compute_vat_return(uuid, date, date) from public, anon;
grant execute on function public.compute_vat_return(uuid, date, date) to authenticated;

-- What a declaration stores: the lines per (rate, category), the totals
-- and the documents behind them, counted once.
create or replace function public.vat_return_summary(
  p_workspace_id uuid, p_start date, p_end date
) returns table (lines jsonb, total_net_cents int, total_vat_cents int,
                 invoice_count int)
language sql stable security definer set search_path = public as $fn$
  with a as (
    select * from public.vat_return_amounts(p_workspace_id, p_start, p_end)
  ), l as (
    select a.percent, a.category, sum(a.gross_cents)::bigint as gross,
           sum(a.net_cents)::bigint as net, count(distinct a.invoice_id)::int as n
      from a group by a.percent, a.category
  )
  select coalesce((select jsonb_agg(jsonb_build_object(
                     'percent', l.percent, 'category', l.category,
                     'gross_cents', l.gross, 'net_cents', l.net,
                     'vat_cents', l.gross - l.net, 'invoice_count', l.n)
                   order by l.percent desc, l.category) from l), '[]'::jsonb),
         coalesce((select sum(l.net) from l), 0)::int,
         coalesce((select sum(l.gross - l.net) from l), 0)::int,
         (select count(distinct a.invoice_id) from a)::int;
$fn$;
revoke execute on function public.vat_return_summary(uuid, date, date)
  from public, anon, authenticated;

-- ============================================================ the writers
drop function if exists public.save_vat_declaration(
  uuid, date, date, jsonb, int, int, text, int);

-- Prepares (or prepares again) the return of a period from the server's
-- own figures. The figure arguments are accepted and ignored.
create function public.save_vat_declaration(
  p_workspace_id uuid,
  p_period_start date,
  p_period_end date,
  p_lines jsonb default null,
  p_total_net_cents int default null,
  p_total_vat_cents int default null,
  p_currency text default null,
  p_invoice_count int default null
) returns uuid
language plpgsql security definer set search_path = public as $fn$
declare
  v_actor public.members;
  v_existing public.vat_declarations;
  v_sum record;
  v_currency text;
  v_id uuid;
begin
  select * into v_actor from public.members
    where workspace_id = p_workspace_id
      and user_id = auth.uid() and status = 'active';
  if v_actor.id is null or not (v_actor.is_owner or coalesce(v_actor.co_owner, 'none') = 'active') then
    raise exception 'only the owner files VAT declarations';
  end if;
  if not public.workspace_charges_vat(p_workspace_id) then
    raise exception 'the workspace is not VAT registered';
  end if;
  if p_period_start is null or p_period_end is null
     or p_period_end < p_period_start then
    raise exception 'invalid period';
  end if;

  select * into v_sum
    from public.vat_return_summary(p_workspace_id, p_period_start, p_period_end);
  select coalesce(w.currency_code, '') into v_currency
    from public.workspaces w where w.id = p_workspace_id;

  select * into v_existing from public.vat_declarations
    where workspace_id = p_workspace_id
      and period_start = p_period_start and period_end = p_period_end
    for update;
  if v_existing.id is not null then
    if v_existing.status = 'filed' then
      raise exception 'declaration already filed for this period';
    end if;
    perform set_config('deskilo.vat_return_writer', 'compute:' || v_existing.id, true);
    update public.vat_declarations
       set status = 'prepared',
           lines = v_sum.lines,
           total_net_cents = v_sum.total_net_cents,
           total_vat_cents = v_sum.total_vat_cents,
           currency = v_currency,
           invoice_count = v_sum.invoice_count,
           created_at = now()
     where id = v_existing.id;
    perform set_config('deskilo.vat_return_writer', '', true);
    return v_existing.id;
  end if;

  v_id := gen_random_uuid();
  perform set_config('deskilo.vat_return_writer', 'compute:' || v_id, true);
  insert into public.vat_declarations
      (id, workspace_id, period_start, period_end, status, lines,
       total_net_cents, total_vat_cents, currency, invoice_count,
       created_by_name)
    values
      (v_id, p_workspace_id, p_period_start, p_period_end, 'prepared',
       v_sum.lines, v_sum.total_net_cents, v_sum.total_vat_cents,
       v_currency, v_sum.invoice_count,
       coalesce((select display_name from public.profiles
                  where id = auth.uid()), ''));
  perform set_config('deskilo.vat_return_writer', '', true);
  return v_id;
end;
$fn$;
revoke execute on function public.save_vat_declaration(
  uuid, date, date, jsonb, int, int, text, int) from public, anon;
grant execute on function public.save_vat_declaration(
  uuid, date, date, jsonb, int, int, text, int) to authenticated;

-- The owner filed the prepared return with the tax authority (by hand,
-- or by taking the exported file to its portal) and records the receipt
-- reference the authority gave. The only way a return becomes filed.
create or replace function public.mark_vat_declaration_submitted(
  p_declaration_id uuid,
  p_channel text,
  p_receipt text default ''
) returns void
language plpgsql security definer set search_path = public as $fn$
declare
  v_decl public.vat_declarations;
  v_actor public.members;
  v_sum record;
begin
  select * into v_decl from public.vat_declarations
    where id = p_declaration_id for update;
  if v_decl.id is null then raise exception 'unknown declaration'; end if;
  select * into v_actor from public.members
    where workspace_id = v_decl.workspace_id
      and user_id = auth.uid() and status = 'active';
  if v_actor.id is null or not (v_actor.is_owner or coalesce(v_actor.co_owner, 'none') = 'active') then
    raise exception 'only the owner files VAT declarations';
  end if;
  if v_decl.status = 'filed' then
    raise exception 'declaration already filed';
  end if;
  if coalesce(p_channel, '') not in ('manual', 'export') then
    raise exception 'unknown channel: a VAT return is filed by its owner with the tax authority';
  end if;
  if btrim(coalesce(p_receipt, '')) = '' then
    raise exception 'the receipt reference the tax authority gave is required';
  end if;
  if v_decl.status <> 'prepared' then
    raise exception 'prepare the return before filing it';
  end if;
  select * into v_sum
    from public.vat_return_summary(v_decl.workspace_id, v_decl.period_start,
                                   v_decl.period_end);
  if (v_sum.lines, v_sum.total_net_cents, v_sum.total_vat_cents, v_sum.invoice_count)
     is distinct from
     (v_decl.lines, v_decl.total_net_cents, v_decl.total_vat_cents, v_decl.invoice_count) then
    raise exception 'the period changed since this return was prepared: prepare it again';
  end if;
  perform set_config('deskilo.vat_return_writer', 'file:' || v_decl.id, true);
  update public.vat_declarations
     set status = 'filed',
         number = case when number = '' then public.next_document_number(workspace_id, 'vat_declaration') else number end,
         submitted_at = now(),
         submitted_channel = p_channel,
         submitted_receipt = left(btrim(p_receipt), 500)
   where id = p_declaration_id;
  perform set_config('deskilo.vat_return_writer', '', true);
end;
$fn$;
revoke execute on function public.mark_vat_declaration_submitted(
  uuid, text, text) from public, anon;

-- ============================================================ the guard
-- Nothing but the two writers above changes a return: its figures come
-- from the save, its filing from the mark, and a filed one never moves.
create or replace function public.vat_declarations_guard()
returns trigger
language plpgsql set search_path = public as $fn$
declare
  v_writer text := coalesce(current_setting('deskilo.vat_return_writer', true), '');
begin
  if tg_op = 'INSERT' then
    if new.status = 'filed' then
      raise exception 'a VAT return is filed only through mark_vat_declaration_submitted';
    end if;
    if new.status = 'prepared' and v_writer <> 'compute:' || new.id then
      raise exception 'the figures of a VAT return come only from compute_vat_return';
    end if;
    return new;
  end if;
  if old.status = 'filed'
     and (new.workspace_id, new.period_start, new.period_end, new.status,
          new.lines, new.total_net_cents, new.total_vat_cents, new.currency,
          new.invoice_count, new.number, new.submitted_at,
          new.submitted_channel, new.submitted_receipt)
     is distinct from
         (old.workspace_id, old.period_start, old.period_end, old.status,
          old.lines, old.total_net_cents, old.total_vat_cents, old.currency,
          old.invoice_count, old.number, old.submitted_at,
          old.submitted_channel, old.submitted_receipt) then
    raise exception 'a filed VAT return is immutable';
  end if;
  if (new.number, new.submitted_at, new.submitted_channel, new.submitted_receipt)
     is distinct from
     (old.number, old.submitted_at, old.submitted_channel, old.submitted_receipt)
     or new.status is distinct from old.status then
    if not (new.status = 'filed' and v_writer = 'file:' || old.id)
       and not (new.status = 'prepared' and v_writer = 'compute:' || old.id
                and (new.number, new.submitted_at, new.submitted_channel,
                     new.submitted_receipt)
                    is not distinct from
                    (old.number, old.submitted_at, old.submitted_channel,
                     old.submitted_receipt)) then
      raise exception 'a VAT return is filed only through mark_vat_declaration_submitted';
    end if;
  end if;
  if (new.workspace_id, new.period_start, new.period_end, new.lines,
      new.total_net_cents, new.total_vat_cents, new.currency, new.invoice_count)
     is distinct from
     (old.workspace_id, old.period_start, old.period_end, old.lines,
      old.total_net_cents, old.total_vat_cents, old.currency, old.invoice_count)
     and v_writer <> 'compute:' || old.id then
    raise exception 'the figures of a VAT return come only from compute_vat_return';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.vat_declarations_guard() from public, anon, authenticated;

drop trigger if exists vat_declarations_guard on public.vat_declarations;
create trigger vat_declarations_guard
  before insert or update on public.vat_declarations
  for each row execute function public.vat_declarations_guard();

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(402);
