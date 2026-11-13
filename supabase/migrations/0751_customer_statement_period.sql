-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0751 (#3839, L2 of #3787) -- a customer's statement for a period: the
-- opening balance, every movement of the period in date order, and the
-- closing balance, per currency, never a mixed total.
--
--   * customer_statement_items: the open-items rules of 0731/0750 item by
--     item (what each document still owes, what each credit leaves
--     unapplied, negative). customer_statement_v1 is restated to add them
--     up: its answer does not change.
--   * customer_statement_period_v1(p_workspace_id, p_member_id, p_from,
--     p_to): the opening is the open-items balance at the start of p_from,
--     the closing the one at the end of p_to (= customer_statement_v1 of
--     p_to). In between, the items are read again just after every instant
--     at which something of this customer changed -- a document issued,
--     voided or settled, a payment or credit recorded or moved, a match
--     created, approved, released, undone or written off -- and each
--     difference is a movement at that instant. So opening + movements =
--     closing by construction.
--   * A movement belongs to the period in which it changed the balance:
--     the decision that made it count (an approval, a release, a
--     write-off). Its line also carries the document's or the payment's
--     own date when that differs ("payment of 28 Oct, confirmed 3 Nov").
--   * reconstructed_before is true when the period starts before the
--     business's match history (0750): its balances before history_from
--     are reconstructed from today's records, and the document says so.
--   * The same readers as customer_statement_v1: the customer, and
--     whoever views finances or issues invoices; never an assistant's
--     delegated session.
--   * The match history (0750) names the function that acted also when the
--     API layer quotes it ("public"."match_invoice").

-- ── one customer's open items at a cutoff ───────────────────────────────
-- The rules of 0731/0750, item by item: each open document with what it
-- still owes (positive) and each unapplied credit (negative), so the
-- balance is their sum. The open-items statement adds them up; the period
-- statement compares them from one change to the next.
create or replace function public.customer_statement_items(
  p_workspace_id uuid, p_member_id uuid, p_cutoff timestamptz)
returns table (currency text, kind text, item_id uuid, amount_cents bigint,
               sort_at timestamptz, sort_key text, line jsonb)
language sql stable security definer set search_path = public as $fn$
    with docs as (
      select i.id, i.number, i.currency, i.issued_at, i.total_cents,
             (select mt.due_on from public.invoice_maturities mt where mt.invoice_id = i.id) as due_on,
             (i.voided_at is not null and i.voided_at < p_cutoff)
             or exists (select 1 from public.invoices s
                         where s.id = i.settled_by_invoice_id and s.issued_at < p_cutoff) as closed
        from public.invoices i
       where i.workspace_id = p_workspace_id and i.member_id = p_member_id
         and i.issued_at < p_cutoff and i.total_cents <> 0
    ),
    -- The parts allocated by the cutoff, and whether each awaits approval.
    parts as (
      select p.invoice_id, p.payment_ledger_id, p.amount_cents, p.matched_at,
             coalesce(public.invoice_match_event_status_at(p.event_id, p_cutoff) = 'pending', false) as waiting
        from public.invoice_match_payments_at(p_workspace_id, p_cutoff) p
    ),
    due as (
      select d.*,
             case
               when d.closed then 0
               when m.id is null then d.total_cents
               when m.status = 'pending' then d.total_cents
               when m.resolution = 'under_accepted'
                    and (m.writeoff_at is null or m.writeoff_at >= p_cutoff)
                 then d.total_cents - coalesce((select sum(pt.amount_cents) from parts pt
                                                 where pt.invoice_id = d.id and not pt.waiting), 0)
               else 0
             end as still_due,
             case
               when d.total_cents < 0 then 'credit_note'
               when m.id is not null and m.status = 'pending'
                 then 'awaiting_approval'
               when m.id is not null then 'partly_paid'
               else 'open'
             end as state
        from docs d
        left join public.invoice_matches_at(p_workspace_id, p_cutoff) m on m.invoice_id = d.id
    ),
    credits as (
      select le.id, le.category, le.description, le.occurred_on, le.created_at,
             le.amount_cents - coalesce((select sum(pt.amount_cents) from parts pt
                                          where pt.payment_ledger_id = le.id), 0) as left_cents
        from public.ledger_entries le
       where le.workspace_id = p_workspace_id and le.member_id = p_member_id
         and le.kind = 'credit' and le.category in ('payment', 'adjustment')
         and le.created_at < p_cutoff
         and not exists (select 1 from public.ledger_credit_moves cm
                          where (cm.from_credit_id = le.id or cm.reversal_ledger_id = le.id)
                            and cm.created_datetime < p_cutoff)
         and not exists (select 1 from public.invoices i
                          where i.workspace_id = p_workspace_id and i.member_id = p_member_id
                            and i.period = le.period and i.issued_at > le.created_at
                            and i.issued_at < p_cutoff
                            and (i.voided_at is null or i.voided_at >= p_cutoff))
    )
  select d.currency, 'invoice', d.id, d.still_due::bigint, d.issued_at, d.number,
         jsonb_build_object(
           'invoice_id', d.id, 'number', d.number, 'issued_at', d.issued_at,
           'due_on', d.due_on, 'total_cents', d.total_cents,
           'still_due_cents', d.still_due, 'state', d.state,
           'allocations', coalesce((
             select jsonb_agg(jsonb_build_object(
                      'payment_id', pt.payment_ledger_id, 'on', pt.matched_at,
                      'amount_cents', pt.amount_cents, 'awaiting_approval', pt.waiting)
                      order by pt.matched_at, pt.payment_ledger_id)
               from parts pt where pt.invoice_id = d.id), '[]'::jsonb))
    from due d where d.still_due <> 0
  union all
  select w.currency_code, 'credit', c.id, -c.left_cents::bigint, c.created_at, c.id::text,
         jsonb_build_object(
           'ledger_id', c.id, 'category', c.category, 'description', c.description,
           'on', coalesce(c.occurred_on, c.created_at::date), 'left_cents', c.left_cents)
    from credits c, public.workspaces w
   where w.id = p_workspace_id and c.left_cents > 0;
$fn$;
revoke execute on function public.customer_statement_items(uuid, uuid, timestamptz) from public, anon, authenticated;

-- 0750, restated on the items: its answer does not change.
create or replace function public.customer_statement_v1(
  p_workspace_id uuid, p_member_id uuid, p_as_of date
) returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_member public.members;
  v_ws public.workspaces;
  v_cutoff timestamptz;
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select * into v_member from public.members
   where id = p_member_id and workspace_id = p_workspace_id;
  if v_member.id is null or not public.may_view_member_finances(p_member_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_as_of is null then
    raise exception 'a statement names its date' using errcode = '22023';
  end if;
  select * into v_ws from public.workspaces where id = p_workspace_id;
  v_cutoff := ((p_as_of + 1)::timestamp at time zone coalesce(nullif(v_ws.timezone, ''), 'UTC'));
  return (
    with items as (
      select * from public.customer_statement_items(p_workspace_id, p_member_id, v_cutoff)
    ),
    currencies as (select distinct i.currency from items i)
    select jsonb_build_object(
             'member_id', v_member.id,
             'as_of', p_as_of,
             'cutoff', v_cutoff,
             'history_from', public.invoice_match_history_from(p_workspace_id),
             'currencies', coalesce(jsonb_agg(jsonb_build_object(
               'currency', c.currency,
               'still_due_cents', coalesce((select sum(i.amount_cents) from items i
                                             where i.currency = c.currency and i.kind = 'invoice'), 0),
               'unapplied_cents', coalesce(-(select sum(i.amount_cents) from items i
                                              where i.currency = c.currency and i.kind = 'credit'), 0),
               'balance_cents', coalesce((select sum(i.amount_cents) from items i where i.currency = c.currency), 0),
               'invoices', coalesce((select jsonb_agg(i.line order by i.sort_at, i.sort_key) from items i
                                      where i.currency = c.currency and i.kind = 'invoice'), '[]'::jsonb),
               'credits', coalesce((select jsonb_agg(i.line order by i.sort_at, i.item_id) from items i
                                     where i.currency = c.currency and i.kind = 'credit'), '[]'::jsonb))
             order by c.currency), '[]'::jsonb))
      from currencies c
  );
end;
$fn$;
revoke execute on function public.customer_statement_v1(uuid, uuid, date) from public, anon;
grant execute on function public.customer_statement_v1(uuid, uuid, date) to authenticated;

-- The movements between two readings of the items, at instant p_at: what
-- changed, by how much (its effect on the balance), and what it was.
create or replace function public.customer_statement_moves(
  p_workspace_id uuid, p_member_id uuid, p_prev jsonb, p_next jsonb, p_at timestamptz, p_tz text)
returns jsonb language sql stable security definer set search_path = public as $fn$
  with keys as (
    select k from jsonb_object_keys(p_prev) k union select k from jsonb_object_keys(p_next) k
  ),
  ch as (
    select coalesce(p_next -> k, p_prev -> k) as it,
           coalesce((p_prev -> k ->> 'amount_cents')::bigint, 0) as pa,
           coalesce((p_next -> k ->> 'amount_cents')::bigint, 0) as na
      from keys
  ),
  moved as (
    select ch.*, it ->> 'currency' as currency, it ->> 'kind' as kind, (it ->> 'item_id')::uuid as id
      from ch where ch.pa <> ch.na
  ),
  named as (
    select m.*,
      case m.kind
        when 'invoice' then
          case
            when m.pa = 0 and i.issued_at = p_at then case when i.total_cents < 0 then 'credit_note' else 'invoice' end
            when m.na = 0 and i.voided_at = p_at then 'voided'
            when m.na = 0 and exists (select 1 from public.invoices s
                                       where s.id = i.settled_by_invoice_id and s.issued_at = p_at) then 'settled'
            when abs(m.na) > abs(m.pa) then 'reopened'
            when exists (select 1 from public.invoice_matches_at(p_workspace_id, p_at + interval '1 microsecond') x
                          where x.invoice_id = m.id and x.writeoff_at is not null)
             and not exists (select 1 from public.invoice_matches_at(p_workspace_id, p_at) x
                              where x.invoice_id = m.id and x.writeoff_at is not null) then 'written_off'
            else 'paid'
          end
        else
          case
            when m.pa = 0 and le.created_at = p_at then case le.category when 'payment' then 'payment' else 'credit' end
            when exists (select 1 from public.ledger_credit_moves cm
                          where (cm.from_credit_id = m.id or cm.reversal_ledger_id = m.id) and cm.created_datetime = p_at) then 'moved'
            when exists (select 1 from public.invoices x
                          where x.workspace_id = p_workspace_id and x.member_id = p_member_id
                            and x.period = le.period and x.issued_at = p_at) then 'applied'
            when abs(m.na) > abs(m.pa) then 'freed'
            else 'allocated'
          end
      end as what,
      case m.kind
        when 'invoice' then
          coalesce(case when m.na < m.pa and i.total_cents > 0 then (
                     select max(coalesce(pl.occurred_on, (pl.created_at at time zone p_tz)::date))
                       from public.invoice_match_payments_at(p_workspace_id, p_at + interval '1 microsecond') pt
                       join public.ledger_entries pl on pl.id = pt.payment_ledger_id
                      where pt.invoice_id = m.id) end,
                   (i.issued_at at time zone p_tz)::date)
        else coalesce(le.occurred_on, (le.created_at at time zone p_tz)::date)
      end as own_on,
      coalesce(m.it -> 'line' ->> 'number', m.it -> 'line' ->> 'description', '') as label
      from moved m
      left join public.invoices i on m.kind = 'invoice' and i.id = m.id
      left join public.ledger_entries le on m.kind = 'credit' and le.id = m.id
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'at', p_at, 'decided_on', (p_at at time zone p_tz)::date, 'own_on', n.own_on,
           'currency', n.currency, 'kind', n.kind, 'item_id', n.id, 'label', n.label,
           'what', n.what, 'amount_cents', n.na - n.pa)
           order by n.kind desc, n.label, n.id), '[]'::jsonb)
    from named n;
$fn$;
revoke execute on function public.customer_statement_moves(uuid, uuid, jsonb, jsonb, timestamptz, text) from public, anon, authenticated;

-- The items at a cutoff, keyed for comparing: currency|kind|item.
create or replace function public.customer_statement_items_keyed(
  p_workspace_id uuid, p_member_id uuid, p_cutoff timestamptz)
returns jsonb language sql stable security definer set search_path = public as $fn$
  select coalesce(jsonb_object_agg(i.currency || '|' || i.kind || '|' || i.item_id, jsonb_build_object(
           'currency', i.currency, 'kind', i.kind, 'item_id', i.item_id,
           'amount_cents', i.amount_cents, 'line', i.line)), '{}'::jsonb)
    from public.customer_statement_items(p_workspace_id, p_member_id, p_cutoff) i;
$fn$;
revoke execute on function public.customer_statement_items_keyed(uuid, uuid, timestamptz) from public, anon, authenticated;

create or replace function public.customer_statement_period_v1(
  p_workspace_id uuid, p_member_id uuid, p_from date, p_to date
) returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_member public.members;
  v_ws public.workspaces;
  v_tz text;
  v_a timestamptz;
  v_b timestamptz;
  v_open jsonb;
  v_prev jsonb;
  v_next jsonb;
  v_close jsonb;
  v_moves jsonb := '[]'::jsonb;
  v_history timestamptz;
  t timestamptz;
begin
  if auth.uid() is null or public.mcp_is_delegated() then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select * into v_member from public.members
   where id = p_member_id and workspace_id = p_workspace_id;
  if v_member.id is null or not public.may_view_member_finances(p_member_id) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if p_from is null or p_to is null or p_from > p_to or p_to - p_from > 3660 then
    raise exception 'a period statement names its first and last day, at most ten years apart'
      using errcode = '22023';
  end if;
  select * into v_ws from public.workspaces where id = p_workspace_id;
  v_tz := coalesce(nullif(v_ws.timezone, ''), 'UTC');
  v_a := p_from::timestamp at time zone v_tz;
  v_b := (p_to + 1)::timestamp at time zone v_tz;
  v_open := public.customer_statement_items_keyed(p_workspace_id, p_member_id, v_a);
  v_prev := v_open;
  -- Every instant at which something of this customer changed.
  for t in
    select distinct x from (
      select i.issued_at from public.invoices i
       where i.workspace_id = p_workspace_id and i.member_id = p_member_id
      union all
      select i.voided_at from public.invoices i
       where i.workspace_id = p_workspace_id and i.member_id = p_member_id
      union all
      select le.created_at from public.ledger_entries le
       where le.workspace_id = p_workspace_id and le.member_id = p_member_id and le.kind = 'credit'
      union all
      select cm.created_datetime from public.ledger_credit_moves cm
       where cm.workspace_id = p_workspace_id and cm.from_member_id = p_member_id
      union all
      select h.at from public.invoice_match_history h
       where h.workspace_id = p_workspace_id
         and h.invoice_id in (select i.id from public.invoices i
                               where i.workspace_id = p_workspace_id and i.member_id = p_member_id)
    ) s(x)
    where x >= v_a and x < v_b
    order by 1
  loop
    v_next := public.customer_statement_items_keyed(p_workspace_id, p_member_id, t + interval '1 microsecond');
    v_moves := v_moves || public.customer_statement_moves(p_workspace_id, p_member_id, v_prev, v_next, t, v_tz);
    v_prev := v_next;
  end loop;
  v_close := public.customer_statement_items_keyed(p_workspace_id, p_member_id, v_b);
  -- Nothing changes after the last instant; were it to, it is still shown.
  v_moves := v_moves || public.customer_statement_moves(p_workspace_id, p_member_id, v_prev, v_close,
                                                         v_b - interval '1 microsecond', v_tz);
  v_history := public.invoice_match_history_from(p_workspace_id);
  return (
    with opening as (
      select e.value ->> 'currency' as currency, sum((e.value ->> 'amount_cents')::bigint) as cents
        from jsonb_each(v_open) e group by 1
    ),
    closing as (
      select e.value ->> 'currency' as currency, sum((e.value ->> 'amount_cents')::bigint) as cents
        from jsonb_each(v_close) e group by 1
    ),
    moves as (select m.value as mv, m.value ->> 'currency' as currency from jsonb_array_elements(v_moves) m),
    currencies as (
      select currency from opening union select currency from closing union select currency from moves
    )
    select jsonb_build_object(
             'member_id', v_member.id,
             'from', p_from,
             'to', p_to,
             'history_from', v_history,
             'reconstructed_before', v_a < v_history,
             'currencies', coalesce(jsonb_agg(jsonb_build_object(
               'currency', c.currency,
               'opening_cents', coalesce((select o.cents from opening o where o.currency = c.currency), 0),
               'closing_cents', coalesce((select l.cents from closing l where l.currency = c.currency), 0),
               'movements', coalesce((select jsonb_agg(m.mv order by m.mv ->> 'at', m.mv ->> 'kind' desc, m.mv ->> 'label')
                                        from moves m where m.currency = c.currency), '[]'::jsonb))
             order by c.currency), '[]'::jsonb))
      from currencies c
  );
end;
$fn$;
revoke execute on function public.customer_statement_period_v1(uuid, uuid, date, date) from public, anon;
grant execute on function public.customer_statement_period_v1(uuid, uuid, date, date) to authenticated;

-- ── who acted, through the API layer too ────────────────────────────────
-- 0750 named the function from the statement's text with an unquoted
-- pattern; the API layer quotes its identifiers ("public"."match_invoice"),
-- so the history named no function on exactly the path people use. The
-- name is read in both spellings.
create or replace function public.invoice_match_history_function_of(p_query text)
returns text language sql immutable set search_path = public as $fn$
  select substring(p_query from '"?public"?\s*\.\s*"?([a-z_0-9]+)"?\s*\(');
$fn$;
revoke execute on function public.invoice_match_history_function_of(text) from public, anon, authenticated;

create or replace function public.invoice_match_history_write(
  p_workspace_id uuid, p_subject text, p_subject_id uuid, p_invoice_id uuid, p_op text, p_image jsonb)
returns void language plpgsql security definer set search_path = public as $fn$
begin
  insert into public.invoice_match_history
    (workspace_id, subject, subject_id, invoice_id, op, image, actor_member_id, actor_function)
  values (p_workspace_id, p_subject, p_subject_id, p_invoice_id, p_op, coalesce(p_image, '{}'::jsonb),
          (select m.id from public.members m
            where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active'),
          public.invoice_match_history_function_of(current_query()));
end;
$fn$;
revoke execute on function public.invoice_match_history_write(uuid, text, uuid, uuid, text, jsonb) from public, anon, authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(751);
