-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0454 (#2365 source tenure, #2587 C2) -- accounting_source_snapshot_v1 also
-- delivers the book-profile revisions of the workspace: every version of
-- every issuer's profile (fiscal-year start, functional currency, basis,
-- authority, revision), read in the SAME statement and so from the SAME
-- snapshot as the invoices, matches, ledger and repartitions, with a control
-- total (count and sum of revisions) computed from the delivered rows. The
-- consumer no longer asks for the profile in a second, later read.
--
-- The payload is extended, not forked: the version stays 1 and nothing is
-- removed. The function is replaced whole (0453 stays as applied); the
-- profiles come through public.book_profiles(workspace), a STABLE function,
-- which runs under the snapshot of this statement and applies its own
-- viewFinances/manageBilling check. Nothing is written.

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
    select m.* from public.invoice_matches m
     where m.workspace_id = p_workspace_id
       and m.invoice_id in (select id from inv)
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
  ), prof as (
    select e as p
      from jsonb_array_elements(public.book_profiles(p_workspace_id)) e
  ), n as (
    select (select count(*) from inv) as inv_n,
           (select count(*) from mat) as mat_n,
           (select count(*) from led) as led_n,
           (select count(*) from rep) as rep_n
  )
  select jsonb_build_object(
      'version', 1,
      'status', case when n.inv_n + n.mat_n + n.led_n + n.rep_n > c_max_rows
                     then 'refused' else 'ok' end,
      'workspace_id', p_workspace_id,
      'from', p_from,
      'to', p_to,
      'timezone', ws.tz,
      'principal', auth.uid(),
      'cutoff', pg_current_snapshot()::text,
      'at', transaction_timestamp()
    ) || case
      when n.inv_n + n.mat_n + n.led_n + n.rep_n > c_max_rows then
        jsonb_build_object(
          'reason', 'over_budget',
          'action', 'narrow_period',
          'rows', n.inv_n + n.mat_n + n.led_n + n.rep_n,
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
          'ledger', coalesce((select jsonb_agg(to_jsonb(l) order by l.id) from led l), '[]'::jsonb),
          'repartitions', coalesce((select jsonb_agg(to_jsonb(r) order by r.id) from rep r), '[]'::jsonb),
          'book_profiles', coalesce((select jsonb_agg(p order by p->>'issuer_site_id', p->>'effective_from') from prof), '[]'::jsonb),
          'totals', jsonb_build_object(
            'invoices', jsonb_build_object('count', n.inv_n,
              'total_cents', (select coalesce(sum(total_cents), 0) from inv)),
            'matches', jsonb_build_object('count', n.mat_n,
              'paid_cents', (select coalesce(sum(paid_cents), 0) from mat)),
            'ledger', jsonb_build_object('count', n.led_n,
              'sum_cents', (select coalesce(sum(amount_cents), 0) from led),
              'credit_cents', (select coalesce(sum(amount_cents) filter (where kind = 'credit'), 0) from led),
              'charge_cents', (select coalesce(sum(amount_cents) filter (where kind = 'charge'), 0) from led)),
            'repartitions', jsonb_build_object('count', n.rep_n,
              'amount_cents', (select coalesce(sum(amount_cents), 0) from rep)),
            'book_profiles', jsonb_build_object(
              'count', (select count(*) from prof),
              'revision_sum', (select coalesce(sum((p->>'revision')::bigint), 0) from prof))))
    end
    into v_out
    from ws, n;

  if v_out is null then
    raise exception 'accounting_source_snapshot_v1: unknown workspace'
      using errcode = '42501';
  end if;
  return v_out;
end;
$fn$;

revoke execute on function public.accounting_source_snapshot_v1(uuid, date, date) from public, anon;
grant execute on function public.accounting_source_snapshot_v1(uuid, date, date) to authenticated;

select public.set_deskilo_schema_version(454);
