-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0526 (#2365) -- the write-off of an invoice whose output tax waits for its
-- tax point (0521) clears the tax of the open rest from `vat_pending`, where
-- it still waits, instead of `vat_output`, which never received it. Held to
-- the Dart rules (`posting_rules.dart`).
--
-- `compute_postings` is restated whole.

create or replace function public.compute_postings(
  p_workspace_id uuid, p_issuer_site_id uuid, p_from date, p_to date
) returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_country text;
  v_postings jsonb := '[]'::jsonb;
  v_blockers jsonb := '{}'::jsonb;
  i record;
  m record;
  t record;
  v_lines jsonb;
  v_gross bigint;
  v_paid bigint;
  v_spent bigint;
  v_day date;
  v_rest bigint;
  v_left bigint;
  v_part bigint;
  v_tax bigint;
  v_n int;
  v_k int;
  d record;
  pl record;
  pay record;
  v_sign int;
  v_net bigint;
  v_rec bigint;
  v_grp text;
  v_default boolean;
  v_unqualified boolean;
  v_tz text;
  v_points jsonb;
  v_deferred uuid[];
  v_vat_role text;
  rel record;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if not public.has_permission(p_workspace_id, 'viewFinances') then
    raise exception 'you may not read the books' using errcode = '42501';
  end if;
  if p_from is null or p_to is null or p_to < p_from then
    raise exception 'a period runs from a day to a later one' using errcode = '22023';
  end if;
  select s.country_code, s.is_default into v_country, v_default from public.sites s
   where s.id = p_issuer_site_id and s.workspace_id = p_workspace_id;
  if not found then raise exception 'unknown issuer' using errcode = '22023'; end if;

  -- ── the tax points (0521) ─────────────────────────────────────────────
  -- The declaration's own engine (`vat_return_amounts`, 0402) dates the
  -- output tax of every invoice. Tax not exactly due on the invoice day
  -- waits on `vat_pending` and is released to `vat_output:<group>` on each
  -- tax point, as the FEC does it (`fec_writer.dart`).
  select coalesce(nullif(w.timezone, ''), 'UTC') into v_tz from public.workspaces w where w.id = p_workspace_id;
  select coalesce(jsonb_agg(jsonb_build_object('id', a.invoice_id, 'on', a.tax_point, 'percent', a.percent,
                                               'category', a.category, 'vat', a.gross_cents - a.net_cents)), '[]'::jsonb)
    into v_points
    from public.vat_return_amounts(p_workspace_id, '1900-01-01', '9999-12-31') a;
  with pts as (
    select (e ->> 'id')::uuid as id, (e ->> 'on')::date as d, (e ->> 'vat')::bigint as vat
      from jsonb_array_elements(v_points) e
  ), docs as (
    select inv.id, (inv.issued_at at time zone v_tz)::date as issued,
           coalesce((select sum((e ->> 'vat_cents')::bigint)
                       from jsonb_array_elements(coalesce(inv.vat_totals, '[]'::jsonb)) e), 0) as vat
      from public.invoices inv
     where inv.workspace_id = p_workspace_id
       and (inv.site_id = p_issuer_site_id or inv.site_id is null)
       and inv.voided_at is null and coalesce(inv.kind, '') <> 'settlement'
  )
  select coalesce(array_agg(docs.id), '{}') into v_deferred
    from docs
   where docs.vat <> 0
     and (exists (select 1 from pts where pts.id = docs.id and pts.vat <> 0 and pts.d <> docs.issued)
          or coalesce((select sum(pts.vat) from pts where pts.id = docs.id and pts.d = docs.issued), 0) <> docs.vat);

  -- ── the documents of the period ───────────────────────────────────────
  for i in
    select inv.* from public.invoices inv
     where inv.workspace_id = p_workspace_id
       and (inv.site_id = p_issuer_site_id or inv.site_id is null)
       and inv.voided_at is null
       and coalesce(inv.kind, '') <> 'settlement'
       and inv.issued_at::date between p_from and p_to
     order by inv.issued_at, inv.number
  loop
    v_day := i.issued_at::date;
    v_gross := coalesce((select sum((e ->> 'net_cents')::bigint + (e ->> 'vat_cents')::bigint)
                           from jsonb_array_elements(coalesce(i.vat_totals, '[]'::jsonb)) e), i.total_cents);
    if jsonb_array_length(coalesce(i.vat_totals, '[]'::jsonb)) = 0 then v_gross := i.total_cents; end if;
    select coalesce(sum(-(l ->> 'amount_cents')::bigint) filter (where l ->> 'kind' = 'payment'), 0),
           coalesce(sum(-(l ->> 'amount_cents')::bigint) filter (where l ->> 'kind' = 'expense'), 0)
      into v_paid, v_spent
      from jsonb_array_elements(coalesce(i.lines, '[]'::jsonb)) l
     where coalesce((l ->> 'vat_percent')::numeric, 0) = 0 and (l ->> 'amount_cents')::bigint < 0;
    if v_gross - v_paid - v_spent <> i.total_cents then
      v_blockers := v_blockers || jsonb_build_object('unbalanced:' || i.number,
        jsonb_build_object('block', 'unbalanced', 'subject', i.number));
      continue;
    end if;
    v_lines := public.posting_line(p_issuer_site_id, 'customers', null, v_day, v_gross, true);
    for t in
      select (e ->> 'net_cents')::bigint as net, (e ->> 'vat_cents')::bigint as vat,
             nullif(public.posting_rate_group(v_country, (e ->> 'percent')::numeric,
                                              coalesce(e ->> 'category', 'S'), v_day), '') as grp
        from jsonb_array_elements(coalesce(i.vat_totals, '[]'::jsonb)) with ordinality x(e, n)
       order by n
    loop
      v_lines := v_lines || public.posting_line(p_issuer_site_id, 'revenue', t.grp, v_day, t.net, false);
      if t.vat <> 0 then
        v_vat_role := case when i.id = any(v_deferred) then 'vat_pending' else 'vat_output' end;
        v_lines := v_lines || public.posting_line(p_issuer_site_id, v_vat_role,
          case when v_vat_role = 'vat_pending' then null else t.grp end, v_day, t.vat, false);
      end if;
    end loop;
    if jsonb_array_length(coalesce(i.vat_totals, '[]'::jsonb)) = 0 then
      v_lines := v_lines || public.posting_line(p_issuer_site_id, 'revenue', null, v_day, i.total_cents, false);
    end if;
    v_postings := v_postings || public.posting_entry('sales',
      case when i.total_cents < 0 then 'credit_note' else 'invoice' end, v_day, i.id, i.number, i.currency, v_lines);
    if v_paid <> 0 then
      v_postings := v_postings || public.posting_entry('bank', 'receipt', v_day, i.id, i.number, i.currency,
        public.posting_line(p_issuer_site_id, 'bank', null, v_day, v_paid, true)
        || public.posting_line(p_issuer_site_id, 'customers', null, v_day, v_paid, false));
    end if;
    -- A netted expense credit (v_spent) books nothing here (0524): the
    -- member's receipt booked the expense against the member's account
    -- when it was approved, and the netting only settles that account.
  end loop;

  -- ── receipts and write-offs dated in the period ───────────────────────
  -- A settlement's payment is allocated to its sources, oldest first and to
  -- the cent (accounting_view.dart); the settlement itself books nothing.
  for m in
    with own as (
      select inv.id, inv.number, inv.currency, inv.total_cents, inv.vat_totals, x.paid_cents::bigint as paid,
             x.matched_at, x.writeoff_at
        from public.invoices inv
        join public.invoice_matches x on x.invoice_id = inv.id and x.status = 'confirmed'
       where inv.workspace_id = p_workspace_id
         and (inv.site_id = p_issuer_site_id or inv.site_id is null)
         and inv.voided_at is null and coalesce(inv.kind, '') <> 'settlement'
    ), alloc as (
      select src.id, src.number, src.currency, src.total_cents, src.vat_totals,
             greatest(least(src.total_cents::bigint,
                            x.paid_cents - coalesce(sum(s.total) over (
                              partition by st.id order by s.n rows between unbounded preceding and 1 preceding), 0)),
                      0)::bigint as paid,
             x.matched_at, x.writeoff_at
        from public.invoices st
        join public.invoice_matches x on x.invoice_id = st.id and x.status = 'confirmed'
        cross join lateral (
          select (e ->> 'invoice_id')::uuid as invoice_id, (e ->> 'total_cents')::bigint as total, n
            from jsonb_array_elements(coalesce(st.settles, '[]'::jsonb)) with ordinality y(e, n)) s
        join public.invoices src on src.id = s.invoice_id
       where st.workspace_id = p_workspace_id and st.kind = 'settlement' and st.voided_at is null
    )
    select * from own union all select * from alloc where paid > 0
  loop
    if m.matched_at::date between p_from and p_to and m.paid <> 0 then
      v_day := m.matched_at::date;
      v_postings := v_postings || public.posting_entry('bank',
        case when m.paid < 0 then 'refund' else 'receipt' end, v_day, m.id, m.number, m.currency,
        public.posting_line(p_issuer_site_id, 'bank', null, v_day, m.paid, true)
        || public.posting_line(p_issuer_site_id, 'customers', null, v_day, m.paid, false));
    end if;
    v_rest := m.total_cents - m.paid;
    if m.writeoff_at is not null and m.writeoff_at::date between p_from and p_to and v_rest > 0 then
      v_day := m.writeoff_at::date;
      v_lines := '[]'::jsonb;
      v_n := greatest(jsonb_array_length(coalesce(m.vat_totals, '[]'::jsonb)), 1);
      v_gross := coalesce((select sum((e ->> 'net_cents')::bigint + (e ->> 'vat_cents')::bigint)
                             from jsonb_array_elements(coalesce(m.vat_totals, '[]'::jsonb)) e), 0);
      v_left := v_rest;
      v_k := 0;
      for t in
        select ((e ->> 'net_cents')::bigint + (e ->> 'vat_cents')::bigint) as gross,
               (e ->> 'vat_cents')::bigint as vat,
               nullif(public.posting_rate_group(v_country, (e ->> 'percent')::numeric,
                                                coalesce(e ->> 'category', 'S'), v_day), '') as grp
          from jsonb_array_elements(coalesce(m.vat_totals, '[]'::jsonb)) with ordinality x(e, n)
         order by n
      loop
        v_k := v_k + 1;
        v_part := case when v_k = v_n or v_gross = 0 then v_left else (v_rest * t.gross) / v_gross end;
        v_left := v_left - v_part;
        v_tax := case when t.gross = 0 then 0 else (v_part * t.vat) / t.gross end;
        -- A deferred invoice's unpaid tax never left vat_pending (0526).
        v_lines := v_lines
          || public.posting_line(p_issuer_site_id, 'write_off', null, v_day, v_part - v_tax, true)
          || case when m.id = any(v_deferred)
                  then public.posting_line(p_issuer_site_id, 'vat_pending', null, v_day, v_tax, true)
                  else public.posting_line(p_issuer_site_id, 'vat_output', t.grp, v_day, v_tax, true) end;
      end loop;
      if v_k = 0 then
        v_lines := public.posting_line(p_issuer_site_id, 'write_off', null, v_day, v_rest, true);
      end if;
      v_lines := v_lines || public.posting_line(p_issuer_site_id, 'customers', null, v_day, v_rest, false);
      v_postings := v_postings || public.posting_entry('other', 'write_off', v_day, m.id, m.number, m.currency, v_lines);
    end if;
  end loop;

  -- ── the output tax released on its tax points (0521) ──────────────────
  for rel in
    select (e ->> 'id')::uuid as id, (e ->> 'on')::date as d, inv.number, inv.currency,
           nullif(public.posting_rate_group(v_country, (e ->> 'percent')::numeric,
                                            coalesce(e ->> 'category', 'S'), (e ->> 'on')::date), '') as grp,
           sum((e ->> 'vat')::bigint)::bigint as vat
      from jsonb_array_elements(v_points) e
      join public.invoices inv on inv.id = (e ->> 'id')::uuid
     where (e ->> 'id')::uuid = any(v_deferred)
       and (e ->> 'on')::date between p_from and p_to
     group by 1, 2, 3, 4, 5
    having sum((e ->> 'vat')::bigint) <> 0
     order by 2, 3, 5
  loop
    v_postings := v_postings || public.posting_entry('other', 'vat_release', rel.d, rel.id, rel.number, rel.currency,
      public.posting_line(p_issuer_site_id, 'vat_pending', null, rel.d, rel.vat, true)
      || public.posting_line(p_issuer_site_id, 'vat_output', rel.grp, rel.d, rel.vat, false));
  end loop;

  -- ── purchases and the money paid on them (0519, 0524) ─────────────────
  -- A purchase document names no issuer: the workspace's default issuer
  -- books it. A supplier's bill is owed to `suppliers`; a member's receipt
  -- is credited to the member's account (`customers`), which an invoice
  -- later nets or a reimbursement pays.
  if v_default then
    for d in
      select pd.* from public.purchase_documents pd
       where pd.workspace_id = p_workspace_id and pd.state = 'approved'
         and (pd.kind = 'member_receipt'
              or (pd.kind in ('bill', 'credit_note')
                  and exists (select 1 from public.purchase_obligations o
                               where o.purchase_id = pd.id and o.creditor_kind = 'supplier')))
         and coalesce(pd.original_date, pd.received_on) between p_from and p_to
       order by coalesce(pd.original_date, pd.received_on), pd.original_reference
    loop
      v_day := coalesce(d.original_date, d.received_on);
      v_sign := case when d.kind = 'credit_note' then -1 else 1 end;
      v_lines := '[]'::jsonb;
      v_gross := 0;
      -- A taxed line whose deductible share is not qualified yet is never
      -- guessed: the bill waits, named.
      v_unqualified := exists (select 1 from public.purchase_lines q
                                where q.purchase_id = d.id and coalesce(q.tax_cents, 0) <> 0
                                  and q.recoverable_tax_cents is null);
      if v_unqualified then
        v_blockers := v_blockers || jsonb_build_object('unclassifiedTax:' || d.original_reference,
          jsonb_build_object('block', 'unclassifiedTax', 'subject', d.original_reference));
        continue;
      end if;
      for pl in select * from public.purchase_lines where purchase_id = d.id order by line_no loop
        v_tax := coalesce(pl.tax_cents, 0);
        v_rec := coalesce(pl.recoverable_tax_cents, 0);
        v_net := coalesce(pl.net_cents, pl.gross_cents - v_tax);
        v_gross := v_gross + pl.gross_cents;
        v_grp := case when pl.tax_rate_percent is null then null
                      else nullif(public.posting_rate_group(v_country, pl.tax_rate_percent, 'S', v_day), '') end;
        v_lines := v_lines || public.posting_line(p_issuer_site_id, 'expenses', null, v_day,
                                                  v_sign * (v_net + v_tax - v_rec), true);
        if v_rec <> 0 then
          v_lines := v_lines || public.posting_line(p_issuer_site_id, 'vat_input', v_grp, v_day, v_sign * v_rec, true);
        end if;
      end loop;
      v_lines := v_lines || public.posting_line(p_issuer_site_id,
        case when d.kind = 'member_receipt' then 'customers' else 'suppliers' end,
        null, v_day, v_sign * v_gross, false);
      v_postings := v_postings || public.posting_entry('purchases',
        case when d.kind = 'member_receipt' then 'member_receipt'
             when v_sign < 0 then 'supplier_credit_note' else 'supplier_bill' end,
        v_day, d.id, d.original_reference, d.currency, v_lines);
    end loop;

    for pay in
      select a.amount_cents::bigint as amount, pd.id, pd.original_reference, pd.currency,
             coalesce(p.reported_paid_on, (a.created_datetime at time zone 'UTC')::date) as paid_on,
             o.creditor_kind
        from public.purchase_settlement_allocations a
        join public.purchase_obligations o on o.id = a.obligation_id
        join public.purchase_documents pd on pd.id = o.purchase_id
        left join public.outgoing_payments p on p.workspace_id = a.workspace_id and p.id = a.payment_id
       where a.workspace_id = p_workspace_id and a.kind = 'payment'
         and pd.state = 'approved' and pd.kind in ('bill', 'credit_note', 'member_receipt')
         and not exists (select 1 from public.purchase_settlement_allocations r where r.original_allocation_id = a.id)
       order by 5, a.created_datetime, a.id
    loop
      if pay.paid_on between p_from and p_to then
        v_postings := v_postings || public.posting_entry('bank',
          case when pay.creditor_kind = 'member' then 'reimbursement' else 'supplier_payment' end,
          pay.paid_on, pay.id, pay.original_reference, pay.currency,
          public.posting_line(p_issuer_site_id,
            case when pay.creditor_kind = 'member' then 'customers' else 'suppliers' end,
            null, pay.paid_on, pay.amount, true)
          || public.posting_line(p_issuer_site_id, 'bank', null, pay.paid_on, pay.amount, false));
      end if;
    end loop;
  end if;

  -- ── what blocks, each named once ──────────────────────────────────────
  select v_blockers || coalesce(jsonb_object_agg(b ->> 'block' || ':' || (b ->> 'subject'), b), '{}'::jsonb)
    into v_blockers
    from jsonb_array_elements(v_postings) p, jsonb_array_elements(p -> 'lines') l,
         lateral (select l -> 'blocked' as b) q
   where l ? 'blocked';

  return jsonb_build_object(
    'period', jsonb_build_object('from', p_from, 'to', p_to),
    'postings', coalesce((
      select jsonb_agg(jsonb_set(p, '{lines}', coalesce((
               select jsonb_agg(l order by n) from jsonb_array_elements(p -> 'lines') with ordinality z(l, n)
                where not l ? 'blocked'), '[]'::jsonb))
             order by (p ->> 'date'), array_position(array['sales', 'bank', 'purchases', 'other'], p ->> 'journal'),
                      (p ->> 'document_number'))
        from jsonb_array_elements(v_postings) p), '[]'::jsonb),
    'blockers', coalesce((select jsonb_agg(v order by k) from jsonb_each(v_blockers) e(k, v)), '[]'::jsonb));
end;
$fn$;
revoke execute on function public.compute_postings(uuid, uuid, date, date) from public, anon;
grant execute on function public.compute_postings(uuid, uuid, date, date) to authenticated;


select public.set_deskilo_schema_version(526);
