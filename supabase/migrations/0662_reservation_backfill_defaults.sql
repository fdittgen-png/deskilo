-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (workspaces.role_permissions: the admin list 0661 wrote out is completed,
-- and explicit co-owner lists of people who book gain makeReservations)
--
-- 0662 (#3269) -- two corrections to 0661's compatibility backfill, found in
-- review. 0661 itself is applied and never changes.
--
-- 1. The admin defaults. When a workspace has no 'admin' list, an admin holds
--    the defaults the SERVER FUNCTIONS grant, and those are two lists:
--    member_has_permission (14 entries) and has_permission_raw (16: it also
--    grants paymentTermsEdit and viewAnalytics, and it is the one the RPC
--    guards ask). 0661 wrote out the first, so an admin of a backfilled
--    workspace would have lost paymentTermsEdit and viewAnalytics in the RPC
--    guards. The list 0661 wrote is recognisable exactly (its 14 defaults and
--    makeReservations, in that order); it becomes has_permission_raw's 16 and
--    makeReservations. The union of the two is has_permission_raw's list, so
--    nothing an admin held through either function is lost; through
--    member_has_permission an admin would also report those two entries,
--    which no migration asks that function of an admin.
--
-- 2. Co-owners. An ACTIVE co-owner holds the whole catalogue unless the
--    workspace has an explicit 'co_owner' list (member_has_permission and
--    has_permission_raw alike). A co-owner who already holds a reservation
--    while an explicit list lacks makeReservations could book yesterday and
--    would not today: the right is added to that list. A co-owner without an
--    explicit list is unaffected (they hold it), and a co-owner who is also an
--    admin is covered by the co_owner list, which the functions read first.
--
-- Idempotent: the repair needs the exact 0661 list, the second pass finds
-- nobody lacking the right.

do $backfill$
declare
  r record;
  v_old jsonb := to_jsonb(array[
    'manageMembers','manageDocuments','manageServices','approveExpenses','viewFinances',
    'viewNegotiations','manageNegotiations','manageSites','manageReservations','operateKiosk',
    'exportData','viewPersonalData','deployToDev','accessProd','makeReservations']);
  v_new jsonb := to_jsonb(array[
    'manageMembers','manageDocuments','manageServices','approveExpenses','viewFinances',
    'viewNegotiations','manageNegotiations','paymentTermsEdit','manageSites','manageReservations',
    'operateKiosk','exportData','viewPersonalData','deployToDev','accessProd','viewAnalytics',
    'makeReservations']);
begin
  -- 1. The admin list 0661 wrote out, completed.
  update public.workspaces w
     set role_permissions = jsonb_set(w.role_permissions, '{admin}', v_new, false)
   where jsonb_typeof(w.role_permissions) = 'object'
     and w.role_permissions->'admin' = v_old;

  -- 2. Explicit co-owner lists of co-owners who already book.
  for r in
    select distinct m.workspace_id
      from public.members m
      join public.workspaces w on w.id = m.workspace_id
     where m.status = 'active'
       and not m.is_owner
       and m.co_owner = 'active'
       and jsonb_typeof(w.role_permissions->'co_owner') = 'array'
       and exists (select 1 from public.reservations x where x.member_id = m.id)
       and not public.member_has_permission(m.id, 'makeReservations')
  loop
    update public.workspaces w
       set role_permissions = jsonb_set(w.role_permissions, '{co_owner}',
             (w.role_permissions->'co_owner') || '["makeReservations"]'::jsonb, false)
     where w.id = r.workspace_id;
  end loop;
end
$backfill$;

select public.set_deskilo_schema_version(662);
