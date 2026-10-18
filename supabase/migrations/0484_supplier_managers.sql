-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0484 (#2567, C1b) -- whoever manages the purchases manages the payees.
--
-- 0458 let only manageBilling write a supplier; #2573 introduced
-- managePurchases for the people who capture bills, and they need the payee
-- they capture a bill for. So:
--   * suppliers and the review candidates are read by viewFinances,
--     manageBilling or managePurchases (the supplier row carries no bank);
--   * a supplier is created, changed, archived, and a review candidate
--     resolved, by manageBilling or managePurchases;
--   * the PAYMENT DESTINATION (bank revisions) stays with manageBilling
--     alone: the person who captures a bill does not change where the money
--     goes, and the revisions stay unreadable to them.

create or replace function pg_temp.patch_function(p_proc regprocedure, p_old text[], p_new text[])
returns void
language plpgsql
as $f$
declare
  v_def text := pg_get_functiondef(p_proc);
  i int;
begin
  for i in 1 .. cardinality(p_old) loop
    if (length(v_def) - length(replace(v_def, p_old[i], ''))) <> length(p_old[i]) then
      raise exception '0484: anchor % is not present exactly once in %', i, p_proc;
    end if;
    v_def := replace(v_def, p_old[i], p_new[i]);
  end loop;
  execute v_def;
end
$f$;
revoke execute on function pg_temp.patch_function(regprocedure, text[], text[]) from public, anon;

select pg_temp.patch_function('public.supplier_guard(uuid)'::regprocedure,
  array[$a$  if auth.uid() is null or not public.has_permission(p_workspace_id, 'manageBilling') then$a$],
  array[$a$  if auth.uid() is null or not (public.has_permission(p_workspace_id, 'manageBilling')
                                         or public.has_permission(p_workspace_id, 'managePurchases')) then$a$]);

select pg_temp.patch_function('public.set_supplier_bank(uuid, text, text, text)'::regprocedure,
  array[$a$  v_member := public.supplier_guard(v_ws);$a$],
  array[$a$  v_member := public.supplier_guard(v_ws);
  if not public.has_permission(v_ws, 'manageBilling') then
    raise exception 'the payment destination is changed by whoever manages billing';
  end if;$a$]);

drop policy if exists suppliers_select on public.suppliers;
create policy suppliers_select on public.suppliers
  for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewFinances', 'manageBilling', 'managePurchases'])));

drop policy if exists supplier_review_candidates_select on public.supplier_review_candidates;
create policy supplier_review_candidates_select on public.supplier_review_candidates
  for select to authenticated
  using (workspace_id in (select public.workspaces_permitting(array['viewFinances', 'manageBilling', 'managePurchases'])));

select public.set_deskilo_schema_version(484);
