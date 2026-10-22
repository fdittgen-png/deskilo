-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0518 (#2365) -- the posting engine: the entries the books receive for one
-- issuer and one period, computed once on the server so every exporter, the
-- VAT return and the KPIs read the same postings to the cent. The rules are
-- the Dart reference `posting_rules.dart`, held to the same seeded year:
--
--   * invoice (issued in the period, neither voided nor a settlement): Dr
--     customers the taxed gross; Cr `revenue:<group>` the net and Cr
--     `vat_output:<group>` the tax per VAT total (the group is the tax
--     reference `rate` row of the issuer's country). A credit note mirrors.
--     A credit netted on it is its own entry on the invoice day: a payment
--     Dr bank / Cr customers, an expense Dr expenses / Cr customers.
--   * receipt (a confirmed match dated in the period, a settlement's
--     payment allocated to its sources oldest first): Dr bank / Cr
--     customers; a negative match mirrors it (refund).
--   * write-off (`writeoff_at` in the period): the open rest split over the
--     VAT totals by their gross (the last takes the rounding), each part into
--     net and tax by its own ratio: Dr `write_off` the net, Dr
--     `vat_output:<group>` the tax / Cr customers the rest.
--
-- A qualified role resolves first and falls back to its base (0517); a base
-- with no mapping, or a mapped account that cannot take the role, is a
-- blocker with the role named and its lines are left out. Nothing is guessed,
-- nothing is written. Definer, gated by viewFinances: the book tables are
-- never read directly (0338).

create or replace function public.posting_account(
  p_issuer_site_id uuid, p_role text, p_qualifier text, p_day date
) returns table (code text, problem text) language sql stable security definer set search_path = public as $fn$
  with pick as (
    select m.account_id
      from public.book_mappings m
     where m.issuer_site_id = p_issuer_site_id
       and m.effective_from <= p_day
       and (m.role = p_role || ':' || coalesce(nullif(p_qualifier, ''), '-') or m.role = p_role)
     order by (m.role = p_role) asc, m.effective_from desc
     limit 1
  )
  select a.code,
         case when (select account_id from pick) is null then 'unmappedRole'
              when a.id is null or a.issuer_site_id <> p_issuer_site_id or not a.is_posting
                   or a.account_type <> public.book_role_account_type(p_role) then 'badAccount'
         end
    from (select 1) one
    left join pick on true
    left join public.book_accounts a on a.id = pick.account_id;
$fn$;
revoke execute on function public.posting_account(uuid, text, text, date) from public, anon, authenticated;

-- The rate group of a VAT total in [p_country] on [p_day], '' when no rate
-- row has it (the base roles then answer).
create or replace function public.posting_rate_group(
  p_country text, p_percent numeric, p_category text, p_day date
) returns text language sql stable security definer set search_path = public as $fn$
  select coalesce((
    select r.value ->> 'group'
      from public.tax_reference r
     where r.domain = 'rate' and r.country = upper(btrim(p_country))
       and r.value ->> 'category' = p_category
       and abs((r.value ->> 'percent')::numeric - p_percent) < 0.000001
     order by (r.valid_from <= p_day and (r.valid_to is null or r.valid_to > p_day)) desc,
              r.valid_from desc
     limit 1), '');
$fn$;
revoke execute on function public.posting_rate_group(text, numeric, text, date) from public, anon, authenticated;

-- One line of [p_amount] on [p_role]: a positive amount on the debit side
-- when [p_debit_side], a negative one mirrored, zero none; a role that does
-- not resolve is a `blocked` marker naming it, never a guessed account.
create or replace function public.posting_line(
  p_issuer_site_id uuid, p_role text, p_qualifier text, p_day date, p_amount bigint, p_debit_side boolean
) returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  a record;
  v_on_debit boolean := (p_amount > 0) = p_debit_side;
begin
  if p_amount = 0 then return '[]'::jsonb; end if;
  select * into a from public.posting_account(p_issuer_site_id, p_role, p_qualifier, p_day);
  if a.problem is not null then
    return jsonb_build_array(jsonb_build_object('blocked',
      jsonb_build_object('block', a.problem, 'subject', p_role)));
  end if;
  return jsonb_build_array(jsonb_build_object(
    'role', p_role, 'qualifier', nullif(p_qualifier, ''), 'account_code', a.code,
    'debit_cents', case when v_on_debit then abs(p_amount) else 0 end,
    'credit_cents', case when v_on_debit then 0 else abs(p_amount) end));
end;
$fn$;
revoke execute on function public.posting_line(uuid, text, text, date, bigint, boolean) from public, anon, authenticated;

create or replace function public.posting_entry(
  p_journal text, p_kind text, p_day date, p_document_id uuid, p_number text, p_currency text, p_lines jsonb
) returns jsonb language sql immutable set search_path = public as $fn$
  select jsonb_build_array(jsonb_build_object(
    'journal', p_journal, 'kind', p_kind, 'date', p_day, 'document_id', p_document_id,
    'document_number', p_number, 'currency', p_currency, 'lines', p_lines));
$fn$;
revoke execute on function public.posting_entry(text, text, date, uuid, text, text, jsonb) from public, anon, authenticated;

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
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if not public.has_permission(p_workspace_id, 'viewFinances') then
    raise exception 'you may not read the books' using errcode = '42501';
  end if;
  if p_from is null or p_to is null or p_to < p_from then
    raise exception 'a period runs from a day to a later one' using errcode = '22023';
  end if;
  select s.country_code into v_country from public.sites s
   where s.id = p_issuer_site_id and s.workspace_id = p_workspace_id;
  if not found then raise exception 'unknown issuer' using errcode = '22023'; end if;

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
        v_lines := v_lines || public.posting_line(p_issuer_site_id, 'vat_output', t.grp, v_day, t.vat, false);
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
    if v_spent <> 0 then
      v_postings := v_postings || public.posting_entry('purchases', 'expense', v_day, i.id, i.number, i.currency,
        public.posting_line(p_issuer_site_id, 'expenses', null, v_day, v_spent, true)
        || public.posting_line(p_issuer_site_id, 'customers', null, v_day, v_spent, false));
    end if;
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
        v_lines := v_lines
          || public.posting_line(p_issuer_site_id, 'write_off', null, v_day, v_part - v_tax, true)
          || public.posting_line(p_issuer_site_id, 'vat_output', t.grp, v_day, v_tax, true);
      end loop;
      if v_k = 0 then
        v_lines := public.posting_line(p_issuer_site_id, 'write_off', null, v_day, v_rest, true);
      end if;
      v_lines := v_lines || public.posting_line(p_issuer_site_id, 'customers', null, v_day, v_rest, false);
      v_postings := v_postings || public.posting_entry('other', 'write_off', v_day, m.id, m.number, m.currency, v_lines);
    end if;
  end loop;

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

select public.set_deskilo_schema_version(518);
