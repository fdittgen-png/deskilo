-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0377 -- the mandatory base role.
--
-- Every member holds EXACTLY ONE base role: user, admin, co-owner or owner.
-- It is derived, so it can never be missing; what the schema can still do
-- is refuse two at once, which is what this adds: a member cannot be the
-- owner and an active co-owner. Every other role (the workspace's own,
-- 0247) adds to the base role's permissions and never takes any away --
-- has_permission already unions them, and the pgTAP file beside this
-- migration proves it.

alter table public.members
  add constraint members_one_base_role
  check (not (is_owner and co_owner = 'active'));

create or replace function public.member_base_role(p_member uuid)
returns text
language sql stable security definer set search_path = public as $fn$
  select case
           when m.is_owner then 'owner'
           when m.co_owner = 'active' then 'co_owner'
           when m.is_admin then 'admin'
           else 'user' end
    from public.members m
   where m.id = p_member
     and (public.is_member_of(m.workspace_id) or m.user_id = auth.uid());
$fn$;
revoke execute on function public.member_base_role(uuid) from public, anon;
grant execute on function public.member_base_role(uuid) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(377);
