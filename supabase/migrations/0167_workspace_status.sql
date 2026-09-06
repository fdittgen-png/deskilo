-- SPDX-License-Identifier: 0BSD
-- 0167 — #934: the workspace's own status, and a remembered repartition
-- rule.
--
-- member_statement aggregates ONE member's month. Nothing aggregated the
-- workspace: what it invoiced, what it collected, what it reimbursed,
-- what it shared out — the treasurer's view. workspace_status is that,
-- for a range of periods, admins and owners only, computed here so the
-- screen and the printed report read the same numbers:
--
--   revenue   invoices issued (non-void, settlements transparent since
--             they regroup invoices already counted), positive totals as
--             invoiced, negative ones as credit notes, and the shares of
--             repartitioned costs charged back to members;
--   payments  matched to invoices (by the month of the match, on the
--             workspace clock) and received on the ledger;
--   expenses  reimbursed to members, shared out (confirmed repartitions),
--             still awaiting a member or a validation, and credits
--             granted as adjustments;
--   members   the same, per active non-kiosk member, with their
--             subscription share — the input of the repartition wizard.
--
-- The repartition rule (method + per-member weights + excluded members)
-- lives in billing_rules->'repartition', beside the other billing rules,
-- so the next month proposes what the owner last decided.
create or replace function public.set_repartition_rule(p_workspace_id uuid, p_rule jsonb)
returns void language plpgsql volatile security definer set search_path = public as $$
begin
  if not public.is_admin_of(p_workspace_id) then raise exception 'admins only'; end if;
  if p_rule is null or jsonb_typeof(p_rule) <> 'object' then raise exception 'rule must be an object'; end if;
  if coalesce(p_rule->>'method', 'subscription') not in ('equal','subscription','usage','custom') then
    raise exception 'unknown method';
  end if;
  update public.workspaces
     set billing_rules = coalesce(billing_rules, '{}'::jsonb) || jsonb_build_object('repartition', p_rule)
   where id = p_workspace_id;
end;
$$;
revoke execute on function public.set_repartition_rule(uuid, jsonb) from public, anon;
grant execute on function public.set_repartition_rule(uuid, jsonb) to authenticated;

create or replace function public.workspace_status(p_workspace_id uuid, p_from text, p_to text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_out jsonb; v_currency text;
begin
  if not public.is_admin_of(p_workspace_id) then raise exception 'admins only'; end if;
  if p_from !~ '^[0-9]{4}-[0-9]{2}$' or p_to !~ '^[0-9]{4}-[0-9]{2}$' or p_from > p_to then
    raise exception 'periods must be YYYY-MM, from <= to';
  end if;
  select currency_code into v_currency from public.workspaces where id = p_workspace_id;
  select jsonb_build_object(
    'from', p_from, 'to', p_to, 'currency', coalesce(v_currency, 'EUR'),
    'revenue', jsonb_build_object(
      'invoiced_cents', coalesce((select sum(total_cents) from public.invoices i
         where i.workspace_id = p_workspace_id and i.voided_at is null and i.kind <> 'settlement'
           and i.period between p_from and p_to and i.total_cents > 0), 0),
      'credit_notes_cents', coalesce((select -sum(total_cents) from public.invoices i
         where i.workspace_id = p_workspace_id and i.voided_at is null and i.kind <> 'settlement'
           and i.period between p_from and p_to and i.total_cents < 0), 0),
      'by_kind', coalesce((select jsonb_object_agg(k, t) from (select i.kind k, sum(i.total_cents) t from public.invoices i
         where i.workspace_id = p_workspace_id and i.voided_at is null and i.kind <> 'settlement'
           and i.period between p_from and p_to group by i.kind) q), '{}'::jsonb),
      'repartition_charges_cents', coalesce((select sum(amount_cents) from public.ledger_entries l
         where l.workspace_id = p_workspace_id and l.kind = 'charge' and l.category = 'adjustment'
           and l.period between p_from and p_to
           and exists (select 1 from public.expense_repartitions r where r.event_id = l.event_id)), 0)),
    'payments', jsonb_build_object(
      'matched_cents', coalesce((select sum(mp.amount_cents) from public.invoice_match_payments mp
         where mp.workspace_id = p_workspace_id
           and to_char(mp.matched_at at time zone coalesce((select timezone from public.workspaces where id = p_workspace_id), 'UTC'), 'YYYY-MM') between p_from and p_to), 0),
      'received_cents', coalesce((select sum(amount_cents) from public.ledger_entries l
         where l.workspace_id = p_workspace_id and l.kind = 'credit' and l.category = 'payment'
           and l.period between p_from and p_to), 0)),
    'expenses', jsonb_build_object(
      'reimbursed_cents', coalesce((select sum(amount_cents) from public.ledger_entries l
         where l.workspace_id = p_workspace_id and l.kind = 'credit' and l.category = 'expense'
           and l.period between p_from and p_to), 0),
      'repartitioned_cents', coalesce((select sum(amount_cents) from public.expense_repartitions r
         where r.workspace_id = p_workspace_id and r.status = 'confirmed' and r.period between p_from and p_to), 0),
      'awaiting_cents', coalesce((select sum(o.amount_cents) from public.expense_occurrences o
         where o.workspace_id = p_workspace_id and o.status in ('awaiting_member','pending_validation')
           and to_char(o.due_on, 'YYYY-MM') between p_from and p_to), 0),
      'credits_granted_cents', coalesce((select sum(amount_cents) from public.ledger_entries l
         where l.workspace_id = p_workspace_id and l.kind = 'credit' and l.category = 'adjustment'
           and l.period between p_from and p_to), 0)),
    'members', coalesce((select jsonb_agg(jsonb_build_object(
        'member_id', m.id, 'member_number', m.member_number,
        'name', coalesce(nullif(m.managed_name, ''), nullif(public.profile_full_name(p), ''), p.display_name, ''),
        'subscription_pct', coalesce(m.subscription_pct, 100),
        'invoiced_cents', coalesce((select sum(total_cents) from public.invoices i where i.member_id = m.id and i.voided_at is null and i.kind <> 'settlement' and i.period between p_from and p_to), 0),
        'paid_cents', coalesce((select sum(amount_cents) from public.ledger_entries l where l.member_id = m.id and l.kind = 'credit' and l.category = 'payment' and l.period between p_from and p_to), 0),
        'reimbursed_cents', coalesce((select sum(amount_cents) from public.ledger_entries l where l.member_id = m.id and l.kind = 'credit' and l.category = 'expense' and l.period between p_from and p_to), 0),
        'credits_cents', coalesce((select sum(amount_cents) from public.ledger_entries l where l.member_id = m.id and l.kind = 'credit' and l.category = 'adjustment' and l.period between p_from and p_to), 0),
        'charged_cents', coalesce((select sum(amount_cents) from public.ledger_entries l where l.member_id = m.id and l.kind = 'charge' and l.period between p_from and p_to), 0)
      ) order by m.member_number)
      from public.members m left join public.profiles p on p.id = m.user_id
      where m.workspace_id = p_workspace_id and m.status = 'active' and not m.is_kiosk), '[]'::jsonb)
  ) into v_out;
  return v_out;
end;
$$;
grant execute on function public.workspace_status(uuid, text, text) to authenticated;
