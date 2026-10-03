-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
--
-- 0351 (#1833, checkpoint B) -- a space mate no longer reads another
-- person's `profiles` row; they read the 0319 projection.
--
-- 0002's profiles_select let every member of a space select every
-- co-member's whole row (postal address, VAT id, legal id, phone,
-- identity e-mail, document language), through PostgREST and through
-- Realtime, which delivers rows the subscriber's policy admits. The row
-- is now readable by:
--   * the person themselves;
--   * a reader holding viewPersonalData or issueInvoices in a space both
--     currently belong to -- the operational audience, which may already
--     read those fields through member_profiles. Released admin clients
--     (invoice preview, Excel, letters) keep working.
-- Everyone else gets nothing, so Realtime stops sending other people's
-- rows to space mates.
--
-- Released clients read space mates with `select * from profiles`. No
-- server-side version gate exists (an older app on a newer schema is
-- "supported"), so instead of silently answering them with an empty
-- directory, a DIRECT PostgREST read (GET/HEAD /profiles) of a space
-- mate's row is refused with SQLSTATE PT426, which PostgREST answers as
-- HTTP 426 Upgrade Required and a message naming the fix. Realtime and
-- definer functions never see that refusal: Realtime sets no request
-- path, and definer functions run as the table owner. Current clients
-- read other people only through member_profiles.

create or replace function public.profile_row_readable(p_subject uuid)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare v_me uuid := auth.uid();
begin
  if v_me is null or p_subject is null then return false; end if;
  if p_subject = v_me then return true; end if;
  if exists (
    select 1 from public.members a
      join public.members b on b.workspace_id = a.workspace_id
     where a.user_id = v_me and b.user_id = p_subject
       and a.status in ('active', 'paused') and b.status in ('active', 'paused')
       and (public.has_permission(a.workspace_id, 'viewPersonalData')
            or public.has_permission(a.workspace_id, 'issueInvoices'))) then
    return true;
  end if;
  if coalesce(current_setting('request.path', true), '') = '/profiles'
     and coalesce(current_setting('request.method', true), '') in ('GET', 'HEAD')
     and public.shares_workspace_with(p_subject) then
    raise exception 'client update required: space mates are read through member_profiles (#1833)'
      using errcode = 'PT426', hint = 'Update Deskilo to the current version.';
  end if;
  return false;
end;
$$;
revoke execute on function public.profile_row_readable(uuid) from public, anon;
grant execute on function public.profile_row_readable(uuid) to authenticated;

drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select
  using (id = (select auth.uid()) or public.profile_row_readable(id));

select public.set_deskilo_schema_version(351);
