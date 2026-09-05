-- SPDX-License-Identifier: 0BSD
-- 0152 — #886: a person's identity, structured, and the documents that
-- print it.
--
-- A profile carried a display name and one free-text address. An
-- invoice must name the buyer with an address; a letter needs a postal
-- block; the pilot association's reference sheet shows company, phone
-- and e-mail. The columns below are the fields the Personal-information
-- form edits; the two functions are the renderings every document
-- freezes at issue time — and they are mirrored line for line by
-- PersonalInfo.fullName / postalBlock in Dart, pinned equal by test.

-- 1. The fields. Free-text `address` stays as the legacy fallback.
alter table public.profiles
  add column if not exists first_name  text not null default '' check (char_length(first_name)  <= 120),
  add column if not exists last_name   text not null default '' check (char_length(last_name)   <= 120),
  add column if not exists company     text not null default '' check (char_length(company)     <= 160),
  add column if not exists street      text not null default '' check (char_length(street)      <= 200),
  add column if not exists postal_code text not null default '' check (char_length(postal_code) <= 16),
  add column if not exists city        text not null default '' check (char_length(city)        <= 120),
  add column if not exists phone       text not null default '' check (char_length(phone)       <= 40),
  add column if not exists email       text not null default '' check (char_length(email)       <= 254),
  add column if not exists legal_id    text not null default '' check (char_length(legal_id)    <= 40);

-- 2. "Prénom NOM" — family name in capitals; either half alone; '' when
--    neither. Falls back to nothing: the caller decides the fallback.
create or replace function public.profile_full_name(p public.profiles)
returns text language sql immutable as $$
  select case
    when btrim(coalesce(p.first_name, '')) = '' then upper(btrim(coalesce(p.last_name, '')))
    when btrim(coalesce(p.last_name, ''))  = '' then btrim(p.first_name)
    else btrim(p.first_name) || ' ' || upper(btrim(p.last_name))
  end;
$$;

-- 3. The postal block: company · street · "POSTAL CITY" · country code
--    when abroad relative to the workspace. One element per line; the
--    NAME is not part of it — documents print it on the line above.
create or replace function public.profile_postal_block(
  p public.profiles, p_workspace_country text default ''
) returns text language sql immutable as $$
  select array_to_string(array_remove(array[
    nullif(btrim(coalesce(p.company, '')), ''),
    nullif(btrim(coalesce(p.street, '')), ''),
    nullif(btrim(concat_ws(' ', nullif(btrim(coalesce(p.postal_code, '')), ''),
                                nullif(upper(btrim(coalesce(p.city, ''))), ''))), ''),
    case when btrim(coalesce(p.country_code, '')) <> ''
          and btrim(coalesce(p_workspace_country, '')) <> ''
          and upper(btrim(p.country_code)) <> upper(btrim(p_workspace_country))
         then upper(btrim(p.country_code)) end
  ], null), E'\n');
$$;

-- 4. create_invoice freezes the structured identity instead of the
--    display name and the free-text address. The body is long and owned
--    by 0142 + later patches, so it is taken from the catalogue and
--    patched at three asserted anchors — a silent no-op would ship an
--    invoice that still names nobody, which is the defect this fixes.
do $patch$
declare
  v_def text;
  v_new text;
  v_anchor text;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'create_invoice';
  if v_def is null then raise exception '0152: create_invoice not found'; end if;
  v_new := v_def;

  -- 4a. declarations: the extra buyer fields.
  v_anchor := E'  v_issuer_name text;\n';
  if position(v_anchor in v_new) = 0 then raise exception '0152: anchor A missing'; end if;
  v_new := replace(v_new, v_anchor, v_anchor
    || E'  v_member_company text := '''';\n'
    || E'  v_member_street text := '''';\n'
    || E'  v_member_postal text := '''';\n'
    || E'  v_member_city text := '''';\n'
    || E'  v_member_legal text := '''';\n'
    || E'  v_member_email text := '''';\n'
    || E'  v_member_phone text := '''';\n');

  -- 4b. the identity select: full name over display name, postal block
  --     over the free-text address, and the structured fields beside.
  v_anchor := E'  select coalesce(display_name, ''''), coalesce(address, ''''),\n'
           || E'         coalesce(country_code, ''''), coalesce(vat_id, '''')\n'
           || E'    into v_member_name, v_member_address, v_member_country, v_member_vat\n'
           || E'    from public.profiles where id = v_subject.user_id;\n';
  if position(v_anchor in v_new) = 0 then raise exception '0152: anchor B missing'; end if;
  v_new := replace(v_new, v_anchor,
       E'  select coalesce(nullif(public.profile_full_name(pr), ''''), pr.display_name, ''''),\n'
    || E'         coalesce(nullif(public.profile_postal_block(pr, v_workspace.country_code), ''''),\n'
    || E'                  pr.address, ''''),\n'
    || E'         coalesce(pr.country_code, ''''), coalesce(pr.vat_id, ''''),\n'
    || E'         coalesce(pr.company, ''''), coalesce(pr.street, ''''),\n'
    || E'         coalesce(pr.postal_code, ''''), coalesce(pr.city, ''''),\n'
    || E'         coalesce(pr.legal_id, ''''), coalesce(pr.email, ''''), coalesce(pr.phone, '''')\n'
    || E'    into v_member_name, v_member_address, v_member_country, v_member_vat,\n'
    || E'         v_member_company, v_member_street, v_member_postal, v_member_city,\n'
    || E'         v_member_legal, v_member_email, v_member_phone\n'
    || E'    from public.profiles pr where pr.id = v_subject.user_id;\n');

  -- 4c. the buyer party: structured (EN 16931 BT-44…BT-49), the street
  --     no longer carrying the whole address.
  v_anchor := E'    ''buyer'', jsonb_build_object(\n'
           || E'      ''name'', v_member_name,\n'
           || E'      ''street'', v_member_address,\n';
  if position(v_anchor in v_new) = 0 then raise exception '0152: anchor C missing'; end if;
  v_new := replace(v_new, v_anchor,
       E'    ''buyer'', jsonb_build_object(\n'
    || E'      ''name'', v_member_name,\n'
    || E'      ''company'', v_member_company,\n'
    || E'      ''street'', case when v_member_street <> '''' then v_member_street else v_member_address end,\n'
    || E'      ''postal_code'', v_member_postal,\n'
    || E'      ''city'', v_member_city,\n'
    || E'      ''legal_id'', v_member_legal,\n'
    || E'      ''email'', v_member_email,\n'
    || E'      ''phone'', v_member_phone,\n');

  -- The workspace row is read AFTER the identity select in the current
  -- body; the postal block needs its country first. Move the read up.
  v_anchor := E'  select * into v_workspace from public.workspaces where id = p_workspace_id;\n';
  if position(v_anchor in v_new) = 0 then raise exception '0152: anchor D missing'; end if;
  v_new := replace(v_new, v_anchor, '');
  v_anchor := E'  v_lines := public.invoice_lines_for(p_member_id, p_period, p_kind);\n';
  if position(v_anchor in v_new) = 0 then raise exception '0152: anchor E missing'; end if;
  v_new := replace(v_new, v_anchor,
       E'  select * into v_workspace from public.workspaces where id = p_workspace_id;\n'
    || v_anchor);

  execute v_new;
end
$patch$;
