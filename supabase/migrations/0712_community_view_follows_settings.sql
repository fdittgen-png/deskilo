-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (member_profile_projection gains a defaulted viewer parameter, so the old
-- two-argument signature is dropped and its two callers are restated; no
-- table, column or policy changes)
--
-- #3594 (GHSA-6m6w-2j3m-rm75) -- the community view of a member follows the
-- person's own contact and presence settings, as the account view already
-- does:
--
--  * whatsapp                  is shown when the contact_channels audience
--                              admits the reader;
--  * status_text, last_seen_at are shown when the presence audience admits
--                              the reader.
--
-- A field the reader may not see keeps its key with the empty value ('' or
-- null), so every client parses the answer as before. The person themselves
-- always sees all of it. The preview of "how others see me" (no reader)
-- answers what a space mate receives: an audience of signed_in or my_spaces,
-- or chosen_spaces with at least one space chosen.

create or replace function public.community_field_shown(
  p_owner uuid, p_field text, p_viewer uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare v_audience text;
begin
  if p_viewer is not null then
    return public.account_field_visible_to(p_owner, p_field, p_viewer);
  end if;
  v_audience := public.account_audience_of(p_owner, p_field);
  return v_audience in ('signed_in', 'my_spaces')
    or (v_audience = 'chosen_spaces' and exists (
      select 1 from public.account_field_audience_spaces s
       where s.user_id = p_owner and s.field = p_field));
end;
$fn$;
revoke execute on function public.community_field_shown(uuid, text, uuid)
  from public, anon, authenticated;

drop function if exists public.member_profile_projection(uuid, text[]);

create or replace function public.member_profile_projection(
  p_subject uuid, p_purposes text[], p_viewer uuid default null)
returns jsonb
language sql
stable
security definer
set search_path = public
as $fn$
  select jsonb_build_object('id', p.id, 'purposes', to_jsonb(p_purposes))
    || case when 'community' = any(p_purposes) then jsonb_build_object('community',
         jsonb_build_object(
           'display_name', coalesce(p.display_name, ''),
           'avatar_path', p.avatar_path,
           'whatsapp', case when public.community_field_shown(p.id, 'contact_channels', p_viewer)
                            then coalesce(p.whatsapp, '') else '' end,
           'status_text', case when public.community_field_shown(p.id, 'presence', p_viewer)
                               then coalesce(p.status_text, '') else '' end,
           'last_seen_at', case when public.community_field_shown(p.id, 'presence', p_viewer)
                                then pr.last_seen_at end)) else '{}'::jsonb end
    || case when 'birthday' = any(p_purposes) then jsonb_build_object('birthday',
         jsonb_build_object('birthday',
           (select b.birthday from public.profile_birthdays b where b.user_id = p.id))) else '{}'::jsonb end
    || case when 'operational' = any(p_purposes) then jsonb_build_object('operational',
         jsonb_build_object(
           'courtesy', coalesce(p.courtesy, ''),
           'first_name', coalesce(p.first_name, ''),
           'last_name', coalesce(p.last_name, ''),
           'company', coalesce(p.company, ''),
           'street', coalesce(p.street, ''),
           'postal_code', coalesce(p.postal_code, ''),
           'city', coalesce(p.city, ''),
           'country_code', coalesce(p.country_code, ''),
           'phone', coalesce(p.phone, ''),
           'email', coalesce(p.email, ''),
           'vat_id', coalesce(p.vat_id, ''),
           'legal_id', coalesce(p.legal_id, ''),
           'address', coalesce(p.address, ''),
           'preferred_locale', coalesce(p.preferred_locale, ''))) else '{}'::jsonb end
  from public.profiles p
  left join public.presence pr on pr.user_id = p.id
  where p.id = p_subject;
$fn$;
revoke execute on function public.member_profile_projection(uuid, text[], uuid)
  from public, anon, authenticated;

create or replace function public.member_profiles(p_workspace_id uuid, p_user_ids uuid[])
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $fn$
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if coalesce(cardinality(p_user_ids), 0) > 5000 then raise exception 'too many profiles'; end if;
  return coalesce((
    select jsonb_agg(public.member_profile_projection(s.id, s.purposes, auth.uid()) order by s.id)
      from (select u.id, public.member_profile_purposes(p_workspace_id, u.id) as purposes
              from (select distinct x as id from unnest(p_user_ids) x where x is not null) u) s
      join public.profiles p on p.id = s.id
     where cardinality(s.purposes) > 0), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.member_profiles(uuid, uuid[]) from public, anon;

create or replace function public.preview_my_member_profile(p_as text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $fn$
begin
  perform public.mcp_require_native();
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if p_as is null or p_as not in ('space_mate', 'personal_data', 'privacy_admin') then
    raise exception 'unknown audience';
  end if;
  return public.member_profile_projection(auth.uid(), case p_as
    when 'space_mate' then array['community']
    when 'personal_data' then array['community', 'operational']
    else array['community', 'operational', 'birthday'] end, null);
end;
$fn$;
revoke execute on function public.preview_my_member_profile(text) from public, anon;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(712);
