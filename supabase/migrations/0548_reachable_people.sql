-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- #2472 — who I can write to, by workspace, before I type a letter.
--
-- The people of every workspace I am an active member of, whose reachability
-- allows me: the SAME rule as search_available_accounts (0315) — a blocked
-- account (0387) is never reachable, either way, and I am not listed. One row
-- per person per shared workspace, so the screen can group by workspace.
-- Reads only; nothing is granted that the search did not already allow.
-- Listing a space's people is that space's decision: a workspace whose
-- community directory (membersDirectory) is off contributes nobody.

create or replace function public.my_reachable_people()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $fn$
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  return coalesce((select jsonb_agg(to_jsonb(x) order by x.workspace_name, x.name, x.id) from (
    select w.id as workspace_id, w.name as workspace_name,
           p.id, p.display_name as name
      from public.members me
      join public.workspaces w on w.id = me.workspace_id
      join public.members other
        on other.workspace_id = me.workspace_id
       and other.status = 'active'
       and other.user_id is not null
       and other.user_id <> auth.uid()
      join public.profiles p on p.id = other.user_id
     where me.user_id = auth.uid()
       and me.status = 'active'
       and public.feature_effective(w.id, 'membersDirectory')
       and public.account_field_visible_to(p.id, 'reachability', auth.uid())
     order by w.name, p.display_name, p.id
     limit 1000) x), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.my_reachable_people() from public, anon;
grant execute on function public.my_reachable_people() to authenticated;

select public.set_deskilo_schema_version(548);
