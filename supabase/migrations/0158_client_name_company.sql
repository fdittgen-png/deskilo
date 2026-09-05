-- SPDX-License-Identifier: 0BSD
-- 0158 — #910: a client is not always a person.
--
-- `profile_full_name` returned '' for a client holding nothing but a
-- COMPANY — which an admin-managed profile is allowed to be (0153 asks
-- for one of first name, last name or company). create_invoice then
-- froze member_name = '' and buyer.name = '', so the document named
-- nobody and every surface that interpolated the name printed an orphan
-- separator, while the company sat unread in the address block.
--
-- The company now stands in for the missing name, and the postal block
-- drops it when it does — printing "SASU KaloA" as the addressee and
-- again as the first line of its own address is not an address. Both
-- functions are mirrored line for line by PersonalInfo.fullName /
-- postalBlock in Dart and pinned equal by test.

-- 1. The name: "Prénom NOM", the surviving half, else the company.
create or replace function public.profile_full_name(p public.profiles)
returns text language sql immutable as $$
  select coalesce(nullif(case
    when btrim(coalesce(p.first_name, '')) = '' then upper(btrim(coalesce(p.last_name, '')))
    when btrim(coalesce(p.last_name, ''))  = '' then btrim(p.first_name)
    else btrim(p.first_name) || ' ' || upper(btrim(p.last_name))
  end, ''), btrim(coalesce(p.company, '')));
$$;

-- 2. The block, without the company when the company IS the name above
--    it. Everything else is unchanged from 0152.
create or replace function public.profile_postal_block(
  p public.profiles, p_workspace_country text default ''
) returns text language sql immutable as $$
  select array_to_string(array_remove(array[
    case when btrim(coalesce(p.first_name, '')) <> ''
           or btrim(coalesce(p.last_name, '')) <> ''
         then nullif(btrim(coalesce(p.company, '')), '') end,
    nullif(btrim(coalesce(p.street, '')), ''),
    nullif(btrim(concat_ws(' ', nullif(btrim(coalesce(p.postal_code, '')), ''),
                                nullif(upper(btrim(coalesce(p.city, ''))), ''))), ''),
    case when btrim(coalesce(p.country_code, '')) <> ''
          and btrim(coalesce(p_workspace_country, '')) <> ''
          and upper(btrim(p.country_code)) <> upper(btrim(p_workspace_country))
         then upper(btrim(p.country_code)) end
  ], null), E'\n');
$$;
