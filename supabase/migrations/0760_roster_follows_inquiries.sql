-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0760 (#3868) -- the hosts' roster follows the inquiries switch. A business
-- that switched `spaceInquiries` off lists nobody to write to, so its page
-- says that nobody answers messages before a word is written; the send
-- (start_space_inquiry_v1, 0721) refuses a new inquiry the same way.

-- The roster (0316), restated whole.
create or replace function public.space_host_roster(p_workspace uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  perform public.mcp_require_native();
  if auth.uid() is null
     or not exists (select 1 from public.public_workspace_cards where workspace_id = p_workspace) then
    raise exception 'workspace not published' using errcode = '55000';
  end if;
  if not public.feature_operation_allowed(p_workspace, 'spaceInquiries', 'accept_new') then
    return '[]'::jsonb;
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'name', coalesce(nullif(p.display_name, ''), m.managed_name, ''),
             'role', case when m.is_owner then 'owner' else 'admin' end)
           order by m.is_owner desc, coalesce(p.display_name, ''), m.id)
      from public.members m
      left join public.profiles p on p.id = m.user_id
     where m.workspace_id = p_workspace and m.user_id is not null
       and public.inquiry_host(p_workspace, m.user_id)), '[]'::jsonb);
end;
$$;
revoke execute on function public.space_host_roster(uuid) from public, anon;
grant execute on function public.space_host_roster(uuid) to authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(760);
