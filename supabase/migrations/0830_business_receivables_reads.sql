-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- #4167 (A): what a business is still owed, as a bounded server read.
--
--   * `business_receivable_rows(workspace)` is the one definition: an issued,
--     unvoided, unsettled invoice (a draft, a quote and a replaced source are
--     not invoices of this table or are excluded here) with its still-due
--     amount, the amount awaiting approval and the state it is in. It is not
--     executable by a client; the two reads below are its only callers, so the
--     total and the detail cannot name different filters.
--   * `business_receivables_summary_v1(workspace)` answers per currency, never
--     across: still to collect, declared or being paid online (awaiting
--     confirmation), received and not yet matched, awaiting approval, and
--     customer refunds due. The first four make the receivable; a refund due
--     is the business's debt to the customer and is never netted against it.
--   * `business_receivables_page_v1(...)` pages the supporting invoices with a
--     keyset cursor (issued_at, id), for one currency and optionally one state.
--
-- Both need the finance right of the business and its invoicing feature, and
-- refuse a delegated (assistant) session: a denied read is an error, never a
-- zero. They read invoices and their matches only; nothing is written.

create or replace function public.business_receivable_rows(p_workspace_id uuid)
returns table (
  id uuid, number text, issued_at timestamptz, due_on date, member_id uuid,
  member_name text, currency text, total_cents bigint, still_due_cents bigint,
  awaiting_cents bigint, bucket text)
language sql stable security definer set search_path = public as $fn$
  with claimed as materialized (
    select distinct o.invoice_id from public.open_claim_invoices(p_workspace_id) o
  ), base as (
    select i.id, i.number, i.issued_at,
           (select max(mat.due_on) from public.invoice_maturities mat
             where mat.invoice_id = i.id) as due_on,
           i.member_id, i.member_name, i.currency, i.total_cents::bigint as total_cents,
           (m.id is null) as unmatched,
           public.invoice_still_due_cents(i.id) as still_due,
           (coalesce((select sum(p.amount_cents) from public.invoice_match_payments p
                        join public.events e on e.id = p.event_id
                       where p.invoice_id = i.id and e.status = 'pending'), 0)
            + case when m.status = 'pending'
                    and not exists (select 1 from public.invoice_match_payments p
                                     where p.invoice_id = i.id and p.event_id = m.event_id)
                   then coalesce(m.paid_cents, 0) else 0 end)::bigint as awaiting,
           exists (select 1 from claimed c where c.invoice_id = i.id) as in_claim,
           public.invoice_payment_received(i.id) as received
      from public.invoices i
      left join lateral (
        select x.* from public.invoice_matches x
         where x.invoice_id = i.id order by x.matched_at desc limit 1
      ) m on true
     where i.workspace_id = p_workspace_id
       and i.voided_at is null and i.settled_by_invoice_id is null
  )
  select b.id, b.number, b.issued_at, b.due_on, b.member_id, b.member_name,
         b.currency, b.total_cents,
         case when b.total_cents < 0 then -b.total_cents
              else greatest(b.still_due, 0) end::bigint,
         case when b.total_cents < 0 then 0 else b.awaiting end::bigint,
         case when b.total_cents < 0 then 'refund_due'
              when b.received then 'received_unmatched'
              when b.in_claim then 'declared'
              when b.still_due > 0 then 'to_collect'
              else 'awaiting' end
    from base b
   where (b.total_cents < 0 and b.unmatched)
      or (b.total_cents >= 0 and (b.still_due > 0 or b.awaiting > 0));
$fn$;
revoke execute on function public.business_receivable_rows(uuid) from public, anon, authenticated;

create or replace function public.business_receivables_summary_v1(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_rows jsonb;
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not coalesce(public.has_permission(p_workspace_id, 'viewFinances'), false)
     or public.feature_effective(p_workspace_id, 'invoicing') is not true then
    raise exception using errcode = '42501', message = 'business receivables are not available';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
           'currency', t.currency,
           'to_collect_cents', t.to_collect, 'declared_cents', t.declared,
           'received_unmatched_cents', t.received, 'awaiting_cents', t.awaiting,
           'refund_due_cents', t.refund,
           'receivable_cents', t.to_collect + t.declared + t.received + t.awaiting,
           'invoices', t.n) order by t.currency), '[]'::jsonb)
    into v_rows
    from (select r.currency,
                 coalesce(sum(r.still_due_cents) filter (where r.bucket = 'to_collect'), 0) as to_collect,
                 coalesce(sum(r.still_due_cents) filter (where r.bucket = 'declared'), 0) as declared,
                 coalesce(sum(r.still_due_cents) filter (where r.bucket = 'received_unmatched'), 0) as received,
                 coalesce(sum(r.awaiting_cents), 0) as awaiting,
                 coalesce(sum(r.still_due_cents) filter (where r.bucket = 'refund_due'), 0) as refund,
                 count(*) as n
            from public.business_receivable_rows(p_workspace_id) r
           group by r.currency) t;
  return jsonb_build_object('workspace_id', p_workspace_id, 'rows', v_rows);
end;
$fn$;
revoke execute on function public.business_receivables_summary_v1(uuid) from public, anon;
grant execute on function public.business_receivables_summary_v1(uuid) to authenticated;

create or replace function public.business_receivables_page_v1(
  p_workspace_id uuid, p_currency text, p_bucket text default null,
  p_after_issued timestamptz default null, p_after_id uuid default null,
  p_limit int default 100
) returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_limit int := least(greatest(coalesce(p_limit, 100), 1), 200);
  v_rows jsonb;
  v_count int;
  v_last_issued timestamptz;
  v_last_id uuid;
begin
  if auth.uid() is null or public.mcp_is_delegated()
     or not coalesce(public.has_permission(p_workspace_id, 'viewFinances'), false)
     or public.feature_effective(p_workspace_id, 'invoicing') is not true then
    raise exception using errcode = '42501', message = 'business receivables are not available';
  end if;
  if (p_after_issued is null) <> (p_after_id is null) then
    raise exception using errcode = '22023', message = 'both cursor fields are required';
  end if;
  if p_bucket is not null and p_bucket not in
     ('to_collect', 'declared', 'received_unmatched', 'awaiting', 'refund_due') then
    raise exception using errcode = '22023', message = 'unknown receivable state';
  end if;
  with q as (
    select r.*, row_number() over (order by r.issued_at desc, r.id desc) as rn
      from public.business_receivable_rows(p_workspace_id) r
     where r.currency = p_currency
       and (p_bucket is null or r.bucket = p_bucket)
       and (p_after_id is null or (r.issued_at, r.id) < (p_after_issued, p_after_id))
  ), page as (
    select * from q where rn <= v_limit order by rn
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'invoice_id', id, 'number', number, 'issued_at', issued_at, 'due_on', due_on,
           'member_id', member_id, 'member_name', member_name, 'currency', currency,
           'total_cents', total_cents, 'still_due_cents', still_due_cents,
           'awaiting_cents', awaiting_cents, 'state', bucket) order by rn), '[]'::jsonb),
         count(*), (array_agg(issued_at order by rn desc))[1], (array_agg(id order by rn desc))[1]
    into v_rows, v_count, v_last_issued, v_last_id
    from page;
  return jsonb_build_object(
    'rows', v_rows,
    'next', case when exists (select 1 from (
                 select 1 from public.business_receivable_rows(p_workspace_id) r
                  where r.currency = p_currency and (p_bucket is null or r.bucket = p_bucket)
                    and (r.issued_at, r.id) < (v_last_issued, v_last_id) limit 1) z)
                 and v_count = v_limit
            then jsonb_build_object('issued_at', v_last_issued, 'id', v_last_id) end);
end;
$fn$;
revoke execute on function public.business_receivables_page_v1(uuid, text, text, timestamptz, uuid, int)
  from public, anon;
grant execute on function public.business_receivables_page_v1(uuid, text, text, timestamptz, uuid, int)
  to authenticated;

select public.set_deskilo_schema_version(830);
