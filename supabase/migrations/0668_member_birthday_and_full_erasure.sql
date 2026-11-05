-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- #3278 (2 of 2) -- the member's birthday, and an erasure that leaves nothing of
-- the structured identity behind.
--
-- * profiles.birthday (a date, plausible: not before 1900, not in the future).
--   It is read by its person, by `viewPersonalData` and `managePrivacy` holders
--   of a shared workspace, and by nobody else: an invoicing clerk reads the
--   address but not the birthday. It is its own purpose group ('birthday'), so
--   the 'operational' group (documents) is unchanged.
-- * erase_my_membership cleared only the display name, WhatsApp, status,
--   legacy address, VAT id and photo of the last membership; the structured
--   identity (names, company, street, postcode, city, phone, e-mail, legal id,
--   courtesy, country) stayed. It now clears those and the birthday too, and
--   preview_my_erasure says so. The export (to_jsonb(profile)) already carries
--   every column, the new one included.
alter table public.profiles
  add column if not exists birthday date
  constraint profiles_birthday_plausible
    check (birthday is null or (birthday >= date '1900-01-01' and birthday <= current_date));

create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
declare
  v_pattern text;
  v_out text;
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  v_pattern := regexp_replace(btrim(p_old, E' \t\n'), '([.^$*+?()\[\]{}|\\])', '\\\1', 'g');
  v_pattern := regexp_replace(v_pattern, '\s+', '\\s*', 'g');
  v_out := regexp_replace(p_def, v_pattern, replace(btrim(p_new, E' \t\n'), '\', '\\'), 'g');
  return case when v_out = p_def then null else v_out end;
end
$f$;

revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $migration$
declare
  v_def text;
begin
  -- who may read which groups of a person
  select pg_get_functiondef('public.member_profile_purposes(uuid,uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$if p_subject = v_me then return array['community', 'operational']; end if;$a$,
    $a$if p_subject = v_me then return array['community', 'operational', 'birthday']; end if;$a$);
  if v_def is null then raise exception '0668: member_profile_purposes self anchor missing'; end if;
  v_def := pg_temp.anchor_replace(v_def,
    $a$v_purposes := array_append(v_purposes, 'operational');
  end if;$a$,
    $a$v_purposes := array_append(v_purposes, 'operational');
  end if;
  -- #3278: the birthday is for the person, personal-data readers and the
  -- privacy admin, not for whoever only issues invoices.
  if public.has_permission(p_workspace, 'viewPersonalData')
     or public.has_permission(p_workspace, 'managePrivacy') then
    v_purposes := array_append(v_purposes, 'birthday');
  end if;$a$);
  if v_def is null then raise exception '0668: member_profile_purposes group anchor missing'; end if;
  execute v_def;

  -- the group itself
  select pg_get_functiondef('public.member_profile_projection(uuid,text[])'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$    || case when 'operational' = any(p_purposes) then jsonb_build_object('operational',$a$,
    $a$    || case when 'birthday' = any(p_purposes) then jsonb_build_object('birthday',
         jsonb_build_object('birthday', p.birthday)) else '{}'::jsonb end
    || case when 'operational' = any(p_purposes) then jsonb_build_object('operational',$a$);
  if v_def is null then raise exception '0668: member_profile_projection anchor missing'; end if;
  execute v_def;

  -- what the person previews of themselves: the billing reader's view stays as it
  -- was, and the privacy admin's view (which also carries the birthday) is new
  select pg_get_functiondef('public.preview_my_member_profile(text)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$p_as not in ('space_mate', 'personal_data')$a$,
    $a$p_as not in ('space_mate', 'personal_data', 'privacy_admin')$a$);
  if v_def is null then raise exception '0668: preview_my_member_profile audience anchor missing'; end if;
  v_def := pg_temp.anchor_replace(v_def,
    $a$else array['community', 'operational'] end$a$,
    $a$when 'personal_data' then array['community', 'operational']
    else array['community', 'operational', 'birthday'] end$a$);
  if v_def is null then raise exception '0668: preview_my_member_profile case anchor missing'; end if;
  execute v_def;

  -- the erasure of the last membership
  select pg_get_functiondef('public.erase_my_membership(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$set display_name = '', whatsapp = '', status_text = '', address = '',
           vat_id = '', avatar_path = null$a$,
    $a$set display_name = '', whatsapp = '', status_text = '', address = '',
           vat_id = '', avatar_path = null, birthday = null,
           courtesy = '', first_name = '', last_name = '', company = '',
           street = '', postal_code = '', city = '', country_code = '',
           phone = '', email = '', legal_id = ''$a$);
  if v_def is null then raise exception '0668: erase_my_membership anchor missing'; end if;
  execute v_def;

  select pg_get_functiondef('public.preview_my_erasure(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $a$'name, photo, WhatsApp, status, address and VAT id are cleared'$a$,
    $a$'name, contact and identity details, address, birthday, photo, WhatsApp, status and VAT id are cleared'$a$);
  if v_def is null then raise exception '0668: preview_my_erasure anchor missing'; end if;
  execute v_def;
end
$migration$;

select public.set_deskilo_schema_version(668);
