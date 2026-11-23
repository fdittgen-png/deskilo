-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
-- (three new functions, one function patched)
--
-- #4164 B1 -- the customer's own reads recognise the billing-access grant (0910). An account reaches the debts of
-- the subjects it is (its member rows, as before) and of the subjects it holds a live grant for -- nothing else.
--
--   * `my_finance_subjects()`: that set of financial subjects, for the caller. Internal.
--   * `my_finance_overview_v2()` and `my_financial_activity_v2(kind, before_at, before_id)`: the v1 readers over
--     that set, each row carrying its `financial_subject_id` (and the overview's `access`: member or billing_grant),
--     so a reader keeps two debtors of one seller and one currency apart. The v1 readers are unchanged: an older
--     app, which groups by seller and currency only, never receives a granted subject's rows.
--   * `my_personal_workspace_refs_v1` gains a `billing_sources` key: the sellers this account holds a live grant
--     for on this installation (seller, subject, grant). An older reader ignores the key. A source is discovery
--     only: every read re-checks the grant. Sellers on another installation are not discovered here.
--
-- A grant-reached subject is not an acting member: `claim_can_continue` stays false and `claim_payment_state`
-- 'unavailable' for it until the payment commands accept the grant (#4165).

create or replace function public.my_finance_subjects()
returns setof uuid language sql stable security definer set search_path = public as $fn$
  select m.id from public.members m where auth.uid() is not null and m.user_id = auth.uid()
  union
  select g.financial_subject_id from public.billing_access_grants g
   where auth.uid() is not null and g.principal_user_id = auth.uid() and g.revoked_at is null;
$fn$;
revoke execute on function public.my_finance_subjects() from public, anon, authenticated;

create or replace function public.my_finance_overview_v2()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $fn$
declare
  v_invoices jsonb;
  v_cut boolean;
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated' using errcode = '42501'; end if;
  with claimed as (
    -- #3556 — the open claims of each of the person's businesses, read once.
    select o.invoice_id
      from (select distinct i.workspace_id from public.invoices i
              join public.members mem on mem.id = i.member_id
             where i.member_id in (select public.my_finance_subjects())) ws
     cross join lateral public.open_claim_invoices(ws.workspace_id) o
  ),
  mine as (
    select i.id, i.workspace_id, w.name as workspace_name, w.timezone as workspace_timezone,
           -- #4164 -- whose debt it is, and how this account reaches it.
           i.member_id as financial_subject_id,
           case when mem.user_id = auth.uid() then 'member' else 'billing_grant' end as access,
           i.number, i.issued_at, i.period,
           (select max(mat.due_on) from public.invoice_maturities mat where mat.invoice_id = i.id) as due_on,
           i.total_cents, i.currency, coalesce(m.paid_cents, 0) as paid_cents,
           case when m.id is null then 'open'
                when m.status = 'pending' then 'awaiting_validation'
                when m.resolution = 'refunded' then 'refunded'
                when m.resolution = 'under_accepted'
                     then case when m.writeoff_at is null then 'partially_paid' else 'closed' end
                else 'paid' end as state,
           public.invoice_still_due_cents(i.id) as still_due_cents,
           -- #3556 — the invoice is in a payment being processed (an online
           -- payment or a declared one that names it): not for another.
           exists (select 1 from claimed c where c.invoice_id = i.id) as in_payment,
           -- #3556 (1b) — the online payment whose open claim names it: the
           -- one its member may withdraw. Null for a declared payment.
           oc.id as claim_payment_id,
           coalesce(mem.status = 'active' and public.payment_claim_resume_state(oc) = 'ready', false)
             as claim_can_continue,
           case when mem.status <> 'active' then 'unavailable'
                else public.payment_claim_resume_state(latest_payment) end as claim_payment_state,
           -- #4140 — the declared payment waiting for the business whose
           -- claim names it: the one its member may take back
           -- (withdraw_payment_declaration). Null for an online one.
           od.id as claim_event_id,
           oc.handed_at as claim_handed_at,
           coalesce(oc.handed_at > now() - public.payment_read_after(oc.provider), false)
             as claim_settling,
           -- Its money arrived and waits for a person to match it (6c).
           pr.received as payment_received,
           -- What a payment may name: the invoice takes a match now (the
           -- rule its settlement follows), is in the business's currency
           -- (a payment is taken in it), is in no open claim and has no
           -- payment waiting to be matched to it.
           public.invoice_match_blocker(i.id) is null
             and upper(i.currency) = upper(w.currency_code)
             and not exists (select 1 from claimed c where c.invoice_id = i.id)
             and not pr.received as payable,
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
      cross join lateral (select public.invoice_payment_received(i.id) as received) pr
      left join lateral (
        select pi.* from public.payment_intents pi
         where pi.workspace_id = i.workspace_id and pi.member_id = i.member_id
           and i.id = any (pi.claimed_invoice_ids)
           and public.payment_intent_claim_open(pi)
         order by pi.created_at desc, pi.id
         limit 1
      ) oc on true
      left join lateral (
        select pi.* from public.payment_intents pi
         where pi.workspace_id = i.workspace_id and pi.member_id = i.member_id
           and i.id = any (pi.claimed_invoice_ids)
         order by pi.created_at desc, pi.id
         limit 1
      ) latest_payment on true
      left join lateral (
        select e.id from public.events e
         where e.workspace_id = i.workspace_id and e.subject_member_id = i.member_id
           and e.type = 'payment' and e.status = 'pending'
           and jsonb_typeof(e.payload -> 'claim') = 'array'
           and e.payload -> 'claim' @> jsonb_build_array(jsonb_build_object('invoice_id', i.id))
         order by e.created_at desc, e.id
         limit 1
      ) od on true
     where i.member_id in (select public.my_finance_subjects())
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
           'financial_subject_id', a.financial_subject_id, 'access', a.access,
           'workspace_timezone', a.workspace_timezone, 'number', a.number,
           'issued_at', a.issued_at, 'period', a.period, 'due_on', a.due_on, 'total_cents', a.total_cents,
           'currency', a.currency, 'paid_cents', a.paid_cents, 'state', a.state,
           'still_due_cents', a.still_due_cents, 'awaiting_cents', a.awaiting_cents,
           'in_payment', a.in_payment, 'claim_payment_id', a.claim_payment_id,
           'claim_can_continue', a.claim_can_continue, 'claim_payment_state', a.claim_payment_state,
           'claim_event_id', a.claim_event_id,
           'claim_handed_at', a.claim_handed_at, 'claim_settling', a.claim_settling,
           'payment_received', a.payment_received,
           'payable', a.payable,
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
         where i.member_id in (select public.my_finance_subjects()) and i.voided_at is null
         order by r.sent_at desc, r.id desc
         limit 100
      ) q2), '[]'::jsonb));
end;
$fn$;
revoke execute on function public.my_finance_overview_v2() from public, anon;
grant execute on function public.my_finance_overview_v2() to authenticated;

create or replace function public.my_financial_activity_v2(p_kind text, p_before_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_before_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $fn$
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
          when i.settled_by_invoice_id is not null then 'regrouped' else 'issued' end as status,
        i.member_id as financial_subject_id
      from public.invoices i join public.members m on m.id=i.member_id
        join public.workspaces w on w.id=i.workspace_id
      where p_kind='invoices' and m.id in (select public.my_finance_subjects())
      union all
      select l.id,l.workspace_id,w.name,l.created_at,''::text,l.description,l.amount_cents,w.currency_code,
        null::integer,'confirmed'::text,l.member_id
      from public.ledger_entries l join public.members m on m.id=l.member_id
        join public.workspaces w on w.id=l.workspace_id
      where p_kind='payments' and m.id in (select public.my_finance_subjects()) and l.category='payment' and l.kind='credit'
      union all
      -- Captures appear exactly once, through the settled ledger credit above;
      -- #3925: a reversed one is listed beside it, as the provider reversed it.
      select p.id,p.workspace_id,w.name,coalesce(p.reversed_at,p.created_at),p.reference,p.provider,
        p.amount_cents,p.currency,null::integer,p.status,p.member_id
      from public.payment_intents p join public.members m on m.id=p.member_id
        join public.workspaces w on w.id=p.workspace_id
      where p_kind='payments' and m.id in (select public.my_finance_subjects()) and p.status in ('created','failed','reversed')
      union all
      select u.id,u.workspace_id,w.name,u.reserved_from,''::text,u.space_label,null::integer,w.currency_code,
        u.counted_minutes,u.basis,u.member_id
      from public.usage_records u join public.members m on m.id=u.member_id
        join public.workspaces w on w.id=u.workspace_id
      where p_kind='usage' and m.id in (select public.my_finance_subjects())
    ) activity
    where p_before_at is null or (activity.occurred_at,activity.id)<(p_before_at,p_before_id)
    order by activity.occurred_at desc,activity.id desc limit 50
  ) page),'[]'::jsonb);
end;
$fn$;
revoke execute on function public.my_financial_activity_v2(text, timestamptz, uuid) from public, anon;
grant execute on function public.my_financial_activity_v2(text, timestamptz, uuid) to authenticated;

-- The sellers this account reaches through a grant, as a key of its own (discovery only).
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_pattern text;
  v_out text;
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  v_out := regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'), 'g');
  return case when v_out = p_def then null else v_out end;
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $patch$
declare
  v_def text;
  v_new text;
begin
  select pg_get_functiondef('public.my_personal_workspace_refs_v1()'::regprocedure) into v_def;
  v_new := pg_temp.anchor_replace(v_def,
    E'''home'', public.personal_home_descriptor(),',
    E'''home'', public.personal_home_descriptor(),\n'
    || E'    ''billing_sources'', coalesce((\n'
    || E'      select jsonb_agg(jsonb_build_object(\n'
    || E'               ''network_id'', w.network_id, ''workspace_id'', w.id, ''workspace_name'', w.name,\n'
    || E'               ''financial_subject_id'', g.financial_subject_id, ''grant_id'', g.id,\n'
    || E'               ''purpose'', g.purpose, ''accepted_at'', g.accepted_at)\n'
    || E'             order by w.name, g.accepted_at, g.id)\n'
    || E'        from public.billing_access_grants g\n'
    || E'        join public.workspaces w on w.id = g.workspace_id\n'
    || E'       where g.principal_user_id = v_me and g.revoked_at is null), ''[]''::jsonb),');
  if v_new is null then raise exception '0911: my_personal_workspace_refs_v1 anchor missing' using errcode = 'P0001'; end if;
  execute v_new;
end;
$patch$;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(911);
