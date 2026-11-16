-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- #3649 (leaf 3a) -- the region of a person's address travels with it: the
-- member profile projection carries `subdivision` in the operational group,
-- beside the street, postal code and city. Who receives that group is
-- unchanged (0712): the region is shown wherever the address is shown, and
-- nowhere else. The function is restated whole from 0712.

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
           'subdivision', coalesce(p.subdivision, ''),
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

select public.set_deskilo_schema_version(788);
