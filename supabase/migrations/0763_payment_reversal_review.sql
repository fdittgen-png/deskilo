-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0763 (#3925) -- a payment the provider reversed (0757) asks a person to
-- correct the books: the roles that see the finances are told, and say when
-- they have looked at it.
--
--  * `reversal_reviewed_at`: when a person who sees the finances marked the
--    reversal as looked at. A reversed payment without it is what the
--    decision surface counts. Only the time is kept: who looked is no
--    business fact of the payment.
--  * `review_payment_reversal_v1`: marks one reversed payment looked at, for
--    the matrix pair that reads payment intents (viewFinances, issueInvoices,
--    0216); once, and only a reversed payment.
--  * `my_financial_activity` (0304), restated whole: a member's own payments
--    list a reversed one beside a pending and a failed one.

alter table public.payment_intents add column if not exists reversal_reviewed_at timestamptz;
comment on column public.payment_intents.reversal_reviewed_at is
  '#3925 -- when a person who sees the finances marked this reversal as looked at; null while it waits';

create or replace function public.review_payment_reversal_v1(p_intent_id uuid)
returns timestamptz language plpgsql security definer set search_path = public as $fn$
declare
  v_intent public.payment_intents;
begin
  select * into v_intent from public.payment_intents where id = p_intent_id;
  if v_intent.id is null then
    raise exception 'unknown payment' using errcode = '22023';
  end if;
  if not (v_intent.workspace_id in
          (select public.workspaces_permitting(array['viewFinances', 'issueInvoices']))) then
    raise exception 'not allowed to review the payments of this workspace' using errcode = '42501';
  end if;
  if v_intent.status <> 'reversed' then
    raise exception 'only a reversed payment is reviewed' using errcode = '22023';
  end if;
  update public.payment_intents
     set reversal_reviewed_at = coalesce(reversal_reviewed_at, now())
   where id = p_intent_id
  returning reversal_reviewed_at into v_intent.reversal_reviewed_at;
  return v_intent.reversal_reviewed_at;
end;
$fn$;
revoke execute on function public.review_payment_reversal_v1(uuid) from public, anon;
grant execute on function public.review_payment_reversal_v1(uuid) to authenticated;

-- A member's own financial history (0304), restated whole: a reversed
-- payment is listed as a pending and a failed one are.
create or replace function public.my_financial_activity(
  p_kind text,p_before_at timestamptz default null,p_before_id uuid default null
) returns jsonb language plpgsql stable security definer set search_path=public as $$
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated' using errcode = '42501'; end if;
  if p_kind is null or p_kind not in ('invoices','payments','usage') then
    raise exception 'invalid activity kind' using errcode = '22023';
  end if;
  if (p_before_at is null)<>(p_before_id is null) then
    raise exception 'invalid cursor' using errcode = '22023';
  end if;
  return coalesce((select jsonb_agg(page order by page.occurred_at desc,page.id desc) from (
    select activity.* from (
      select i.id,i.workspace_id,w.name as workspace_name,i.issued_at as occurred_at,
        i.number as reference,i.title as description,i.total_cents as amount_cents,i.currency,
        null::integer as minutes,
        case when i.voided_at is not null then 'voided'
          when i.settled_by_invoice_id is not null then 'regrouped' else 'issued' end as status
      from public.invoices i join public.members m on m.id=i.member_id
        join public.workspaces w on w.id=i.workspace_id
      where p_kind='invoices' and m.user_id=auth.uid()
      union all
      select l.id,l.workspace_id,w.name,l.created_at,''::text,l.description,l.amount_cents,w.currency_code,
        null::integer,'confirmed'::text
      from public.ledger_entries l join public.members m on m.id=l.member_id
        join public.workspaces w on w.id=l.workspace_id
      where p_kind='payments' and m.user_id=auth.uid() and l.category='payment' and l.kind='credit'
      union all
      -- Captures appear exactly once, through the settled ledger credit above;
      -- #3925: a reversed one is listed beside it, as the provider reversed it.
      select p.id,p.workspace_id,w.name,coalesce(p.reversed_at,p.created_at),p.reference,p.provider,
        p.amount_cents,p.currency,null::integer,p.status
      from public.payment_intents p join public.members m on m.id=p.member_id
        join public.workspaces w on w.id=p.workspace_id
      where p_kind='payments' and m.user_id=auth.uid() and p.status in ('created','failed','reversed')
      union all
      select u.id,u.workspace_id,w.name,u.reserved_from,''::text,u.space_label,null::integer,w.currency_code,
        u.counted_minutes,u.basis
      from public.usage_records u join public.members m on m.id=u.member_id
        join public.workspaces w on w.id=u.workspace_id
      where p_kind='usage' and m.user_id=auth.uid()
    ) activity
    where p_before_at is null or (activity.occurred_at,activity.id)<(p_before_at,p_before_id)
    order by activity.occurred_at desc,activity.id desc limit 50
  ) page),'[]'::jsonb);
end;
$$;
revoke execute on function public.my_financial_activity(text,timestamptz,uuid) from public,anon;
grant execute on function public.my_financial_activity(text,timestamptz,uuid) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(763);
