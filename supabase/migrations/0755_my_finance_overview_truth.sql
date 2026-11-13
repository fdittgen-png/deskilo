-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0755 — #3877 + #3878: Me's overview states the server's own figures and
-- leaves out nothing still owed. my_finance_overview (0736, restated whole):
--
--   * each invoice also answers `still_due_cents`, the server's own still-due
--     (`invoice_still_due_cents`, 0718: its total less what its matches paid
--     and less the further parts awaiting approval), and `awaiting_cents`, the
--     parts whose approval is pending (a pending match without a part of its
--     own counts its paid amount). A partial of 40 waiting on an invoice of
--     100 is then 40 being validated and 60 still due, and a confirmed 40 with
--     a further 60 waiting is 60 being validated and nothing still due;
--   * every document still owed or in the person's favour is answered however
--     old; the settled ones come by their newest page of 300, and
--     `settled_cut` says when older settled ones were left out.
--
-- The other fields, the reminders, the order and the grants are 0736's.

create or replace function public.my_finance_overview()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_invoices jsonb;
  v_cut boolean;
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated' using errcode = '42501'; end if;
  with mine as (
    select i.id, i.workspace_id, w.name as workspace_name, w.timezone as workspace_timezone,
           i.number, i.issued_at,
           (select max(mat.due_on) from public.invoice_maturities mat where mat.invoice_id = i.id) as due_on,
           i.total_cents, i.currency, coalesce(m.paid_cents, 0) as paid_cents,
           case when m.id is null then 'open'
                when m.status = 'pending' then 'awaiting_validation'
                when m.resolution = 'refunded' then 'refunded'
                when m.resolution = 'under_accepted'
                     then case when m.writeoff_at is null then 'partially_paid' else 'closed' end
                else 'paid' end as state,
           public.invoice_still_due_cents(i.id) as still_due_cents,
           coalesce((select sum(p.amount_cents) from public.invoice_match_payments p
                       join public.events e on e.id = p.event_id
                      where p.invoice_id = i.id and e.status = 'pending'), 0)
             + case when m.status = 'pending'
                     and not exists (select 1 from public.invoice_match_payments p
                                      where p.invoice_id = i.id and p.event_id = m.event_id)
                    then coalesce(m.paid_cents, 0) else 0 end as awaiting_cents,
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
  ),
  owed as (
    select * from mine where state in ('open', 'awaiting_validation', 'partially_paid')
  ),
  settled as (
    select * from mine where state not in ('open', 'awaiting_validation', 'partially_paid')
     order by issued_at desc, id desc
     limit 301
  ),
  answered as (
    select * from owed
    union all
    select * from (select * from settled order by issued_at desc, id desc limit 300) s
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', a.id, 'workspace_id', a.workspace_id, 'workspace_name', a.workspace_name,
           'workspace_timezone', a.workspace_timezone, 'number', a.number,
           'issued_at', a.issued_at, 'due_on', a.due_on, 'total_cents', a.total_cents,
           'currency', a.currency, 'paid_cents', a.paid_cents, 'state', a.state,
           'still_due_cents', a.still_due_cents, 'awaiting_cents', a.awaiting_cents,
           'reminder_count', a.reminder_count, 'last_reminder_at', a.last_reminder_at)
         order by a.issued_at desc, a.id desc), '[]'::jsonb),
         (select count(*) from settled) > 300
    into v_invoices, v_cut
    from answered a;
  return jsonb_build_object(
    'invoices', v_invoices,
    'settled_cut', v_cut,
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

select public.set_deskilo_schema_version(755);
