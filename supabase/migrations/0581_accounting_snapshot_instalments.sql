-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 9999 (#2365, the handoff of #2587) -- every accounting export reads its
-- input from ONE response. The fiscal source (0453/0454/0533/0558) carried
-- the invoices, their matches, the ledger, the repartitions, the profiles
-- and the purchases, but an export still read two things on its own, at
-- another moment than the books:
--
--   instalments   the export's tax points (#2355: when each invoice's VAT
--                 falls due) were dated from a separate, whole-workspace
--                 read of invoice_match_payments. They now travel here, for
--                 the in-scope invoices, with control totals (count,
--                 amount_cents).
--   matches       the export's payment state came from the invoice list's
--                 matches, loaded before the source. The source's own
--                 matches now include those of the settlements that
--                 regroup an in-scope invoice, so the accountant's view
--                 (#831: a settlement's payment allocated to its sources)
--                 is built from this snapshot alone. Their totals stay the
--                 rows'.
--
-- Additive: version 1 keeps every key it had and gains `instalments` (rows
-- and totals); the instalment rows count against the row budget beside the
-- matches. Row policies still apply (invoker): invoice_match_payments is
-- readable by whoever reads the invoice matches. Replaced whole, as 0454,
-- 0533 and 0558 did; no anchored patch has ever touched it.

create or replace function public.accounting_source_snapshot_v1(
  p_workspace_id uuid,
  p_from date,
  p_to date
) returns jsonb
language plpgsql stable
set search_path = public
as $fn$
declare
  -- a technical bound on one response, not a business value: the producer
  -- refuses beyond it so no consumer can mistake a cut set for a whole one.
  c_max_rows constant int := 20000;
  v_out jsonb;
begin
  if auth.uid() is null
     or p_workspace_id is null
     or not public.has_permission(p_workspace_id, 'viewFinances') then
    raise exception 'accounting_source_snapshot_v1: not allowed'
      using errcode = '42501';
  end if;
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 366 then
    raise exception 'accounting_source_snapshot_v1: the period must be at most one year'
      using errcode = '22023';
  end if;

  -- ONE statement: every CTE below reads the same snapshot.
  with ws as (
    select w.id, coalesce(nullif(w.timezone, ''), 'UTC') as tz
      from public.workspaces w
     where w.id = p_workspace_id
  ), inv as (
    select i.* from public.invoices i, ws
     where i.workspace_id = ws.id
       and (i.issued_at at time zone ws.tz)::date between p_from and p_to
  ), mat as (
    -- 9999: the matches of the in-scope invoices AND of the settlements
    -- that regroup them (the export allocates a settlement's payment to
    -- its sources, #831), so no export reads them a second time.
    select m.* from public.invoice_matches m
     where m.workspace_id = p_workspace_id
       and (m.invoice_id in (select id from inv)
            or m.invoice_id in (select settled_by_invoice_id from inv
                                 where settled_by_invoice_id is not null))
  ), ins as (
    -- 9999: the instalments of the in-scope invoices (#2355), from which
    -- an export dates each invoice's tax points.
    select p.id, p.invoice_id, p.amount_cents, p.matched_at
      from public.invoice_match_payments p
     where p.workspace_id = p_workspace_id
       and p.invoice_id in (select id from inv)
  ), led as (
    select l.* from public.ledger_entries l, ws
     where l.workspace_id = ws.id
       and coalesce(l.occurred_on, (l.created_at at time zone ws.tz)::date)
           between p_from and p_to
  ), rep as (
    select r.* from public.expense_repartitions r, ws
     where r.workspace_id = ws.id
       and (coalesce(r.applied_at, r.created_at) at time zone ws.tz)::date
           between p_from and p_to
  ), pur as (
    -- #2573/#2587: the approved purchase documents of the period, by the
    -- date the document bears (the only date it knows), in the same
    -- snapshot as the sales side.
    select d.* from public.purchase_documents d
     where d.workspace_id = p_workspace_id and d.state = 'approved'
       and coalesce(d.original_date, d.received_on) between p_from and p_to
  ), pln as (
    select l.* from public.purchase_lines l
     where l.workspace_id = p_workspace_id
       and l.purchase_id in (select id from pur)
  ), prof as (
    select e as p
      from jsonb_array_elements(public.book_profiles(p_workspace_id)) e
  ), rev_settings as (
    -- #2564: the registry's meaning and bounds, and the versions in force
    -- for this workspace (the platform's and its own), as setting_value()
    -- resolves them. Data only: no id, no validity instant, no note.
    select md5(coalesce(string_agg(x.line, '|' order by x.ord, x.line), '')) as token
      from (
        select 0 as ord,
               jsonb_build_object('key', d.key, 'type', d.type,
                 'default', d.default_value, 'min', d.min_value, 'max', d.max_value,
                 'unit', d.unit, 'floor', d.floor_value, 'choices', d.choices,
                 'scopes', to_jsonb(d.scopes))::text as line
          from public.setting_definitions d
        union all
        select 1,
               jsonb_build_object('scope', s.scope, 'workspace_id', s.workspace_id,
                 'key', s.key, 'value', s.value)::text
          from public.setting_values s
         where s.valid_to is null
           and (s.scope = 'platform' or s.workspace_id = p_workspace_id)
      ) x
  ), rev_tax as (
    -- #2564: the version of the whole reference dataset (see the header).
    select md5(coalesce(string_agg(
             jsonb_build_object('domain', t.domain, 'country', t.country, 'key', t.key,
               'valid_from', t.valid_from, 'valid_to', t.valid_to, 'value', t.value,
               'source', t.source, 'confirmed', t.confirmed)::text,
             '|' order by t.domain, t.country, t.key, t.valid_from), '')) as token
      from public.tax_reference t
  ), rev_prof as (
    -- #2564: the delivered profile rows, id aside, in their delivered order.
    select md5(coalesce(string_agg((p - 'id')::text, '|'
             order by p->>'issuer_site_id', p->>'effective_from', (p->>'revision')::int), '')) as token
      from prof
  ), rev_cal as (
    -- #2564: the workspace calendar an export cuts and counts on, as
    -- stored: a rule the workspace never stated is null here, and the
    -- server default that then applies belongs to the schema version, not
    -- to the workspace's data.
    select md5(jsonb_build_object(
             'timezone', ws.tz,
             'country', w.country_code,
             'open_weekdays', w.booking_rules -> 'open_weekdays',
             'work_start_minutes', w.booking_rules -> 'work_start_minutes',
             'work_end_minutes', w.booking_rules -> 'work_end_minutes',
             'closures', coalesce((select jsonb_agg(jsonb_build_object('day', c.day, 'reason', c.reason)
                                                   order by c.day)
                                     from public.closure_days c
                                    where c.workspace_id = w.id), '[]'::jsonb))::text) as token
      from public.workspaces w, ws
     where w.id = ws.id
  ), n as (
    select (select count(*) from inv) as inv_n,
           (select count(*) from mat) + (select count(*) from ins) as mat_n,
           (select count(*) from led) as led_n,
           (select count(*) from rep) as rep_n,
           (select count(*) from pur) + (select count(*) from pln) as pur_n
  )
  select jsonb_build_object(
      'version', 1,
      'status', case when n.inv_n + n.mat_n + n.led_n + n.rep_n + n.pur_n > c_max_rows
                     then 'refused' else 'ok' end,
      'workspace_id', p_workspace_id,
      'from', p_from,
      'to', p_to,
      'timezone', ws.tz,
      'principal', auth.uid(),
      'cutoff', pg_current_snapshot()::text,
      'revisions', jsonb_build_object(
        'settings', rev_settings.token,
        'tax_reference', rev_tax.token,
        'book_profile', rev_prof.token,
        'calendar', rev_cal.token),
      'at', transaction_timestamp()
    ) || case
      when n.inv_n + n.mat_n + n.led_n + n.rep_n + n.pur_n > c_max_rows then
        jsonb_build_object(
          'reason', 'over_budget',
          'action', 'narrow_period',
          'rows', n.inv_n + n.mat_n + n.led_n + n.rep_n + n.pur_n,
          'max_rows', c_max_rows)
      else
        jsonb_build_object(
          'invoices', coalesce((select jsonb_agg(jsonb_build_object(
              'id', i.id, 'workspace_id', i.workspace_id, 'number', i.number,
              'issued_at', i.issued_at, 'total_cents', i.total_cents,
              'currency', i.currency, 'kind', i.kind, 'voided_at', i.voided_at,
              'member_id', i.member_id, 'issuer_member_id', i.issuer_member_id)
              order by i.id) from inv i), '[]'::jsonb),
          'matches', coalesce((select jsonb_agg(to_jsonb(m) order by m.id) from mat m), '[]'::jsonb),
          'instalments', coalesce((select jsonb_agg(to_jsonb(p) order by p.id) from ins p), '[]'::jsonb),
          'ledger', coalesce((select jsonb_agg(to_jsonb(l) order by l.id) from led l), '[]'::jsonb),
          'repartitions', coalesce((select jsonb_agg(to_jsonb(r) order by r.id) from rep r), '[]'::jsonb),
          'book_profiles', coalesce((select jsonb_agg(p order by p->>'issuer_site_id', p->>'effective_from') from prof), '[]'::jsonb),
          'purchases', coalesce((select jsonb_agg(jsonb_build_object(
              'id', d.id, 'kind', d.kind, 'supplier_id', d.supplier_id,
              'original_reference', d.original_reference,
              'original_date', d.original_date, 'received_on', d.received_on,
              'due_on', d.due_on, 'currency', d.currency, 'category', d.category,
              'payer_kind', d.payer_kind, 'payer_member_id', d.payer_member_id,
              'original_document_id', d.original_document_id,
              'lines', coalesce((select jsonb_agg(jsonb_build_object(
                  'id', l.id, 'line_no', l.line_no, 'description', l.description,
                  'net_cents', l.net_cents, 'tax_cents', l.tax_cents,
                  'gross_cents', l.gross_cents, 'tax_rate_percent', l.tax_rate_percent,
                  'recoverable_tax_cents', l.recoverable_tax_cents,
                  'nonrecoverable_tax_cents', l.nonrecoverable_tax_cents,
                  'recognition_kind', l.recognition_kind)
                  order by l.line_no) from pln l where l.purchase_id = d.id), '[]'::jsonb))
              order by d.id) from pur d), '[]'::jsonb),
          'totals', jsonb_build_object(
            'invoices', jsonb_build_object('count', n.inv_n,
              'total_cents', (select coalesce(sum(total_cents), 0) from inv)),
            'matches', jsonb_build_object('count', (select count(*) from mat),
              'paid_cents', (select coalesce(sum(paid_cents), 0) from mat)),
            'instalments', jsonb_build_object('count', (select count(*) from ins),
              'amount_cents', (select coalesce(sum(amount_cents), 0) from ins)),
            'ledger', jsonb_build_object('count', n.led_n,
              'sum_cents', (select coalesce(sum(amount_cents), 0) from led),
              'credit_cents', (select coalesce(sum(amount_cents) filter (where kind = 'credit'), 0) from led),
              'charge_cents', (select coalesce(sum(amount_cents) filter (where kind = 'charge'), 0) from led)),
            'repartitions', jsonb_build_object('count', n.rep_n,
              'amount_cents', (select coalesce(sum(amount_cents), 0) from rep)),
            'purchases', jsonb_build_object('count', (select count(*) from pur),
              'line_count', (select count(*) from pln),
              'gross_cents', (select coalesce(sum(gross_cents), 0) from pln)),
            'book_profiles', jsonb_build_object(
              'count', (select count(*) from prof),
              'revision_sum', (select coalesce(sum((p->>'revision')::bigint), 0) from prof))))
    end
    into v_out
    from ws, n, rev_settings, rev_tax, rev_prof, rev_cal;

  if v_out is null then
    raise exception 'accounting_source_snapshot_v1: unknown workspace'
      using errcode = '42501';
  end if;
  return v_out;
end;
$fn$;

revoke execute on function public.accounting_source_snapshot_v1(uuid, date, date) from public, anon;
grant execute on function public.accounting_source_snapshot_v1(uuid, date, date) to authenticated;

select public.set_deskilo_schema_version(581);
