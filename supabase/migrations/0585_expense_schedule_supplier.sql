-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- A member's scheduled expense names the supplier it pays (#2567).
--
-- `expense_schedules.supplier_id` (0458) had no writer for a member's own
-- schedule: a lease or a rented room set it through their contract, and the
-- schedule form could not. `set_expense_schedule_supplier` is that writer,
-- with the guards of its VAT twin (0413) plus the supplier's own:
--   * the schedule's own active member, or whoever approves expenses;
--   * a schedule that still runs (pending or active);
--   * a member outlay only: a contract's schedule takes its supplier from
--     its contract, and changing it here would split the two;
--   * the suppliers switched on (`supplyExpenses`);
--   * naming a supplier needs the right to read the suppliers (viewFinances,
--     manageBilling or managePurchases), so a supplier id cannot be guessed
--     into a schedule by someone the picker shows none to;
--   * an ACTIVE supplier of the same workspace: an archived one is no longer
--     offered, another workspace's never.
-- Null clears the supplier. A supplier archived later stays on the schedules
-- that already name it: archiving hides it from pickers, not from records.

create or replace function public.set_expense_schedule_supplier(
  p_schedule_id uuid, p_supplier_id uuid
) returns void
language plpgsql security definer set search_path = public as $fn$
declare
  v_s public.expense_schedules;
  v_status text;
begin
  select * into v_s from public.expense_schedules where id = p_schedule_id;
  if v_s.id is null then raise exception 'unknown schedule'; end if;
  if not (exists (select 1 from public.members m
                   where m.id = v_s.member_id and m.user_id = auth.uid()
                     and m.status = 'active')
          or public.has_permission(v_s.workspace_id, 'approveExpenses')) then
    raise exception 'not allowed';
  end if;
  if v_s.status not in ('pending', 'active') then
    raise exception 'this schedule no longer runs';
  end if;
  if v_s.origin <> 'member_outlay' then
    raise exception 'a contract''s schedule takes its supplier from its contract';
  end if;
  if not public.feature_effective(v_s.workspace_id, 'supplyExpenses') then
    raise exception 'suppliers are switched off in this space';
  end if;
  if p_supplier_id is not null then
    if not (public.has_permission(v_s.workspace_id, 'viewFinances')
            or public.has_permission(v_s.workspace_id, 'manageBilling')
            or public.has_permission(v_s.workspace_id, 'managePurchases')) then
      raise exception 'not allowed to name a supplier';
    end if;
    select sp.status into v_status from public.suppliers sp
     where sp.id = p_supplier_id and sp.workspace_id = v_s.workspace_id;
    if v_status is null then raise exception 'unknown supplier'; end if;
    if v_status <> 'active' then
      raise exception 'an archived supplier cannot be named';
    end if;
  end if;
  update public.expense_schedules
     set supplier_id = p_supplier_id
   where id = v_s.id;
end;
$fn$;
revoke execute on function public.set_expense_schedule_supplier(uuid, uuid) from public, anon;
grant execute on function public.set_expense_schedule_supplier(uuid, uuid) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(585);
