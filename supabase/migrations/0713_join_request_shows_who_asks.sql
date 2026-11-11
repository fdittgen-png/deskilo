-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (two functions restated with the same signatures; no table, column or
-- policy changes)
--
-- #3594 (GHSA-6m6w-2j3m-rm75) -- a join request shows who asks:
--
--  * a person whose membership is pending appears to the holders of
--    manageMembers in that space with the community view (name and photo;
--    the rest follows the person's own settings);
--  * member_emails answers the e-mail address of members only, never of a
--    pending request.

create or replace function public.member_profile_purposes(p_workspace uuid, p_subject uuid)
returns text[]
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_me uuid := auth.uid();
  v_purposes text[] := '{}';
begin
  if v_me is null or p_subject is null then return v_purposes; end if;
  if p_subject = v_me then return array['community', 'operational', 'birthday']; end if;
  if p_workspace is null then return v_purposes; end if;
  if not exists (select 1 from public.members m
                  where m.workspace_id = p_workspace and m.user_id = v_me
                    and m.status in ('active', 'paused')) then
    return v_purposes;
  end if;
  -- A pending request: who asks, for whoever decides the requests.
  if exists (select 1 from public.members m
              where m.workspace_id = p_workspace and m.user_id = p_subject
                and m.status = 'pending')
     and not exists (select 1 from public.members m
                      where m.workspace_id = p_workspace and m.user_id = p_subject
                        and m.status in ('active', 'paused')) then
    if public.has_permission(p_workspace, 'manageMembers') then
      return array['community'];
    end if;
    return v_purposes;
  end if;
  if not exists (select 1 from public.members m
                  where m.workspace_id = p_workspace and m.user_id = p_subject
                    and m.status in ('active', 'paused')) then
    return v_purposes;
  end if;
  v_purposes := array['community'];
  if public.has_permission(p_workspace, 'viewPersonalData')
     or public.has_permission(p_workspace, 'issueInvoices') then
    v_purposes := array_append(v_purposes, 'operational');
  end if;
  -- #3278: the birthday is for the person, personal-data readers and the
  -- privacy admin, not for whoever only issues invoices.
  if public.has_permission(p_workspace, 'viewPersonalData')
     or public.has_permission(p_workspace, 'managePrivacy') then
    v_purposes := array_append(v_purposes, 'birthday');
  end if;
  return v_purposes;
end;
$fn$;
revoke execute on function public.member_profile_purposes(uuid, uuid)
  from public, anon, authenticated;

create or replace function public.member_emails(p_workspace_id uuid)
returns table(member_id uuid, email text)
language sql
stable
security definer
set search_path = public
as $fn$
  select m.id, coalesce(u.email::text, '')
  from public.members m
  join auth.users u on u.id = m.user_id
  where m.workspace_id = p_workspace_id
    and m.status <> 'pending'
    and public.has_permission(p_workspace_id, 'viewPersonalData');
$fn$;
revoke execute on function public.member_emails(uuid) from public, anon;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(713);
