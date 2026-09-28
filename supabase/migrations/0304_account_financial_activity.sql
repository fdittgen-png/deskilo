-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- #1791: account-owned history across workspaces, including departed profiles.
-- This is a projection, not a second ledger. Amounts keep their own currencies.
create function public.my_financial_activity(
  p_kind text,p_before_at timestamptz default null,p_before_id uuid default null
) returns jsonb language plpgsql stable security definer set search_path=public as $$
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if p_kind is null or p_kind not in ('invoices','payments','usage') then raise exception 'invalid activity kind'; end if;
  if (p_before_at is null)<>(p_before_id is null) then raise exception 'invalid cursor'; end if;
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
      -- Captures appear exactly once, through the settled ledger credit above.
      select p.id,p.workspace_id,w.name,p.created_at,p.reference,p.provider,p.amount_cents,p.currency,
        null::integer,p.status
      from public.payment_intents p join public.members m on m.id=p.member_id
        join public.workspaces w on w.id=p.workspace_id
      where p_kind='payments' and m.user_id=auth.uid() and p.status in ('created','failed')
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

-- A preferred checkout provider is a personal convenience, never payment proof
-- or a provider secret. Existing workspace overrides and reset semantics apply.
do $preferences$
declare v_def text; v_keys text := '''preferred_locale'',''ui_locale'',''theme''';
  v_check text := $a$if (k='clock' and$a$;
begin
  v_def:=pg_get_functiondef('public.set_personal_preferences(jsonb,uuid,uuid)'::regprocedure);
  if position(v_keys in v_def)=0 or position(v_check in v_def)=0 then raise exception '0304: preferences anchor missing'; end if;
  v_def:=replace(v_def,v_keys,v_keys||',''payment_provider''');
  v_def:=replace(v_def,v_check,$a$if (k='payment_provider' and v #>> '{}' not in ('','paypal','stripe','mollie','wero'))
       or (k='clock' and$a$);
  execute v_def;
end;
$preferences$;
notify pgrst,'reload schema';
select public.set_deskilo_schema_version(304);
