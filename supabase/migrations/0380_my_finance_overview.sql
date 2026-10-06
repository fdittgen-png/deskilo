-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0380 — Me › Finances: ONE read of what I owe and what I paid, across every
-- workspace I belong to — outstanding and paid invoices, and the reminders
-- I received. A member's own documents only (their member rows, their
-- user id); never another member's, never an operator view. Issuing and
-- chasing invoices stays a workspace process.
--
-- State follows the invoice lifecycle (0067/0068, #504): no match = open;
-- a pending match = awaiting validation; refunded; under-accepted is partly
-- paid until its remainder is written off (closed); anything else = paid.
-- Erroneous (voided) and regrouped invoices are left out: the replacement
-- or the settlement invoice is the document that counts.

create or replace function public.my_finance_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $fn$
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  return jsonb_build_object(
    'invoices', coalesce((
      select jsonb_agg(q order by q.issued_at desc, q.id desc) from (
        select i.id, i.workspace_id, w.name as workspace_name, i.number, i.issued_at,
               (select max(mat.due_on) from public.invoice_maturities mat where mat.invoice_id = i.id) as due_on,
               i.total_cents, i.currency, coalesce(m.paid_cents, 0) as paid_cents,
               case when m.id is null then 'open'
                    when m.status = 'pending' then 'awaiting_validation'
                    when m.resolution = 'refunded' then 'refunded'
                    when m.resolution = 'under_accepted'
                         then case when m.writeoff_at is null then 'partially_paid' else 'closed' end
                    else 'paid' end as state,
               (select count(*) from public.invoice_reminders r where r.invoice_id = i.id) as reminder_count,
               (select max(r.sent_at) from public.invoice_reminders r where r.invoice_id = i.id) as last_reminder_at
          from public.invoices i
          join public.members mem on mem.id = i.member_id
          join public.workspaces w on w.id = i.workspace_id
          left join lateral (
            select x.* from public.invoice_matches x
             where x.invoice_id = i.id order by x.matched_at desc limit 1
          ) m on true
         where mem.user_id = auth.uid()
           and i.voided_at is null and i.settled_by_invoice_id is null
         order by i.issued_at desc, i.id desc
         limit 300
      ) q), '[]'::jsonb),
    'reminders', coalesce((
      select jsonb_agg(q2 order by q2.sent_at desc, q2.id desc) from (
        select r.id, r.invoice_id, i.number as invoice_number, w.name as workspace_name,
               r.sent_at, r.level, r.automatic
          from public.invoice_reminders r
          join public.invoices i on i.id = r.invoice_id
          join public.members mem on mem.id = i.member_id
          join public.workspaces w on w.id = i.workspace_id
         where mem.user_id = auth.uid() and i.voided_at is null
         order by r.sent_at desc, r.id desc
         limit 100
      ) q2), '[]'::jsonb));
end;
$fn$;

revoke execute on function public.my_finance_overview() from public, anon;
grant execute on function public.my_finance_overview() to authenticated;

select public.set_deskilo_schema_version(380);
