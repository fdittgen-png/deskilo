-- SPDX-License-Identifier: 0BSD
-- 0145 — #818: two more dated facts for the calendar hub.
--
--  * 'due'       — the payment term of an OPEN invoice: issued_at plus the
--                  workspace's reminder rules first delay (the same clock
--                  #726 and the client's InvoiceExposure read). Money-gated
--                  like the invoice itself; links to the invoice.
--  * 'scheduled' — a scheduled expense's occurrence falling due (#767),
--                  while it still awaits the member or the validators.
--                  Money-gated; links to the month on Finances.
--
-- calendar_items v2 = the 0133 body with the two kinds added to the
-- default set and to the money block. Patched IN PLACE (pg_get_functiondef
-- + replace, anchors asserted) — the body is long and the access rules in
-- it must not be retyped.
do $patch$
declare
  v_def text;
  v_old_want text := $o$  v_want := coalesce(p_kinds, array['reservation','checkin','checkout','event',
                                     'message','invoice','payment','consumption','reminder']);$o$;
  v_new_want text := $n$  v_want := coalesce(p_kinds, array['reservation','checkin','checkout','event',
                                     'message','invoice','payment','consumption','reminder',
                                     'due','scheduled']);$n$;
  v_old_money text := $o$  if v_want && array['invoice','payment','consumption'] then$o$;
  v_new_money text := $n$  if v_want && array['invoice','payment','consumption','due','scheduled'] then$n$;
  v_old_union text := $o$          from public.ledger_entries le
         where le.workspace_id = p_workspace_id and le.member_id = v_subject
           and coalesce(le.occurred_on::timestamptz, le.created_at) >= p_from
           and coalesce(le.occurred_on::timestamptz, le.created_at) < p_to
           and ((le.category = 'payment' and 'payment' = any(v_want))
             or (le.category <> 'payment' and 'consumption' = any(v_want)))
      ) s;$o$;
  v_new_union text := $n$          from public.ledger_entries le
         where le.workspace_id = p_workspace_id and le.member_id = v_subject
           and coalesce(le.occurred_on::timestamptz, le.created_at) >= p_from
           and coalesce(le.occurred_on::timestamptz, le.created_at) < p_to
           and ((le.category = 'payment' and 'payment' = any(v_want))
             or (le.category <> 'payment' and 'consumption' = any(v_want)))
        union all
        -- #818 — the payment term of an OPEN invoice (no match row, not
        -- voided, not regrouped): the day the money is expected.
        select jsonb_build_object(
          'kind', 'due', 'id', i.id || ':due',
          'at', i.issued_at + make_interval(days => least(greatest(coalesce((w.dunning_rules ->> 'first_after_days')::int, 14), 1), 365)),
          'member_id', i.member_id, 'title', i.number,
          'amount_cents', i.total_cents, 'currency', i.currency,
          'status', 'open',
          'link', jsonb_build_object('type','invoice','id', i.id))
          from public.invoices i
          join public.workspaces w on w.id = i.workspace_id
         where i.workspace_id = p_workspace_id and i.member_id = v_subject
           and i.voided_at is null and i.total_cents > 0
           and i.settled_by_invoice_id is null
           and not exists (select 1 from public.invoice_matches m where m.invoice_id = i.id)
           and i.issued_at + make_interval(days => least(greatest(coalesce((w.dunning_rules ->> 'first_after_days')::int, 14), 1), 365)) >= p_from
           and i.issued_at + make_interval(days => least(greatest(coalesce((w.dunning_rules ->> 'first_after_days')::int, 14), 1), 365)) < p_to
           and 'due' = any(v_want)
        union all
        -- #818 — a scheduled expense's occurrence still to be settled.
        select jsonb_build_object(
          'kind', 'scheduled', 'id', o.id,
          'at', (o.due_on::timestamp at time zone w.timezone),
          'member_id', o.member_id, 'title', s.title,
          'amount_cents', -o.amount_cents, 'currency', w.currency_code,
          'status', case o.status when 'awaiting_member' then 'pending'
                                  when 'pending_validation' then 'pending'
                                  else o.status end,
          'link', jsonb_build_object('type','ledger','period', to_char(o.due_on, 'YYYY-MM')))
          from public.expense_occurrences o
          join public.expense_schedules s on s.id = o.schedule_id
          join public.workspaces w on w.id = o.workspace_id
         where o.workspace_id = p_workspace_id and o.member_id = v_subject
           and o.status in ('awaiting_member','pending_validation')
           and (o.due_on::timestamp at time zone w.timezone) >= p_from
           and (o.due_on::timestamp at time zone w.timezone) < p_to
           and 'scheduled' = any(v_want)
      ) s;$n$;
  v_old_locked text := $o$      v_locked := v_locked || array['invoice','payment','consumption'];$o$;
  v_new_locked text := $n$      v_locked := v_locked || array['invoice','payment','consumption','due','scheduled'];$n$;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'calendar_items';
  if v_def is null then raise exception 'calendar_items missing (0133?)'; end if;
  if position($m$'due','scheduled'$m$ in v_def) > 0 then
    raise notice 'calendar_items already carries the due kinds';
    return;
  end if;
  if position(v_old_want in v_def) = 0 then raise exception '0145: want anchor not found'; end if;
  if position(v_old_money in v_def) = 0 then raise exception '0145: money anchor not found'; end if;
  if position(v_old_union in v_def) = 0 then raise exception '0145: union anchor not found'; end if;
  if position(v_old_locked in v_def) = 0 then raise exception '0145: locked anchor not found'; end if;
  v_def := replace(v_def, v_old_want, v_new_want);
  v_def := replace(v_def, v_old_money, v_new_money);
  v_def := replace(v_def, v_old_union, v_new_union);
  v_def := replace(v_def, v_old_locked, v_new_locked);
  execute v_def;
end $patch$;
