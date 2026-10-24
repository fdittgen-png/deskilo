-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- Additive: one private helper restated whole (0570's
-- personal_directory_relationships). No table, no policy, no grant change;
-- my_personal_message_directory_v1 is unchanged and reads the helper.
--
-- #2472 (P) -- the new discussion's directory names a workspace of another
-- installation by the caller's own membership fact (#2563 C2, 0574), under
-- my_personal_workspace_refs_v1's rule:
--   * only the fact about the caller (the helper reads p_user's facts, and
--     the reader passes auth.uid()); another person's fact about the same
--     workspace never names it for me;
--   * only a live fact: status active, never a tombstone (which carries no
--     name anyway);
--   * only while its source is enrolled, enabled, under the epoch the fact
--     arrived under; a revoked or re-enrolled source names nothing.
-- A workspace this database hosts keeps its own name, as before. The
-- search of the workspaces section therefore also finds a remote workspace
-- by the name its own fact asserted, to the person it is about.

-- My relationships, local and verified: one row per workspace network id,
-- fresh while it can authorize anything. Private: only the reader asks.
create or replace function public.personal_directory_relationships(p_user uuid)
returns table (network_id text, permitted_name text, fresh boolean)
language sql
stable
security definer
set search_path = public
as $fn$
  select w.network_id, w.name, true
    from public.members m
    join public.workspaces w on w.id = m.workspace_id
   where m.user_id = p_user and m.status = 'active'
     and public.feature_effective(w.id, 'membersDirectory')
  union
  select f.network_id,
         case when exists (select 1 from public.enrolled_installations e
                            where e.installation_id = f.source_installation_id
                              and e.enabled and e.enrolled_at = f.enrolment_epoch)
              then f.workspace_name end,
         public.membership_fact_in_force(p_user, f.network_id, array['active'])
    from public.membership_facts f
   where f.user_id = p_user and f.status = 'active'
     and not exists (select 1 from public.workspaces w where w.network_id = f.network_id);
$fn$;
revoke execute on function public.personal_directory_relationships(uuid)
  from public, anon, authenticated, service_role;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(575);
