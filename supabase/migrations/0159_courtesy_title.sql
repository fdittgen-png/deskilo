-- SPDX-License-Identifier: 0BSD
-- 0159 — #912: the company leads, the person follows, with their title.
--
-- A client that is an organisation is addressed as the organisation —
-- it is the organisation that owes the invoice — and the person inside
-- it belongs on the line beneath, greeted the way THEY asked to be:
--
--     SASU KaloA
--     Monsieur Guilhem MARTIN
--     209 rue Jean Bart, Immeuble AGORA 1B
--     31670 LABÈGE
--
-- The title is stored as a code and rendered per language, so a French
-- member's document reads "Monsieur" and a German reader's "Herr". The
-- frozen block resolves it once, in the workspace's language, because a
-- document that has been issued does not change afterwards.
--
-- Mirrored by PersonalInfo.fullName / postalBlock in Dart, pinned equal
-- by test, as 0152 and 0158 were.

-- 1. The choice. '' is a real answer: print the name alone.
alter table public.profiles
  add column if not exists courtesy text not null default ''
    check (courtesy in ('', 'mr', 'mrs'));

-- 2. It travels with a managed identity too.
create or replace function public.managed_identity_clean(p jsonb) returns jsonb
language sql immutable as $$
  select coalesce((
    select jsonb_object_agg(key, left(btrim(value), 254))
      from jsonb_each_text(coalesce(p, '{}'::jsonb))
     where key in ('courtesy','first_name','last_name','company','street',
                   'postal_code','city','country_code','phone','email',
                   'vat_id','legal_id')
       and btrim(value) <> ''), '{}'::jsonb);
$$;

-- 3. The title in a language. Unknown code or language falls back to
--    the English forms, which is what an unlocalized reader expects.
create or replace function public.courtesy_word(p_code text, p_lang text)
returns text language sql immutable as $$
  select case lower(coalesce(btrim(p_code), ''))
    when 'mr' then case lower(left(coalesce(btrim(p_lang), 'en'), 2))
      when 'fr' then 'Monsieur' when 'de' then 'Herr'
      when 'es' then 'Sr.' when 'it' then 'Sig.' else 'Mr' end
    when 'mrs' then case lower(left(coalesce(btrim(p_lang), 'en'), 2))
      when 'fr' then 'Madame' when 'de' then 'Frau'
      when 'es' then 'Sra.' when 'it' then 'Sig.ra' else 'Ms' end
    else '' end;
$$;

-- 4. The personal name alone — no company standing in for it.
create or replace function public.profile_person_name(p public.profiles)
returns text language sql immutable as $$
  select case
    when btrim(coalesce(p.first_name, '')) = '' then upper(btrim(coalesce(p.last_name, '')))
    when btrim(coalesce(p.last_name, ''))  = '' then btrim(p.first_name)
    else btrim(p.first_name) || ' ' || upper(btrim(p.last_name))
  end;
$$;

-- 5. The addressee: the COMPANY when there is one (#912 — it changes
--    the 0158 order deliberately: the organisation is the debtor), else
--    the person.
create or replace function public.profile_full_name(p public.profiles)
returns text language sql immutable as $$
  select coalesce(nullif(btrim(coalesce(p.company, '')), ''),
                  public.profile_person_name(p));
$$;

-- 6. The block under that line. The company is never in it — it IS the
--    line above whenever it exists; the person joins the block, with
--    their title, exactly when the company displaced them.
create or replace function public.profile_postal_block(
  p public.profiles, p_workspace_country text default '',
  p_lang text default ''
) returns text language sql immutable as $$
  select array_to_string(array_remove(array[
    case when btrim(coalesce(p.company, '')) <> ''
         then nullif(btrim(concat_ws(' ',
                nullif(public.courtesy_word(p.courtesy, p_lang), ''),
                nullif(public.profile_person_name(p), ''))), '') end,
    nullif(btrim(coalesce(p.street, '')), ''),
    nullif(btrim(concat_ws(' ', nullif(btrim(coalesce(p.postal_code, '')), ''),
                                nullif(upper(btrim(coalesce(p.city, ''))), ''))), ''),
    case when btrim(coalesce(p.country_code, '')) <> ''
          and btrim(coalesce(p_workspace_country, '')) <> ''
          and upper(btrim(p.country_code)) <> upper(btrim(p_workspace_country))
         then upper(btrim(p.country_code)) end
  ], null), E'\n');
$$;

-- 7. create_invoice freezes the person and the title beside the rest of
--    the buyer, so a reader in another language can still greet them
--    properly. Patched at asserted anchors, as 0152/0156/0157 were: a
--    silent no-op would ship a document that greets nobody.
do $patch$
declare
  v_def text;
  v_anchor text;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'create_invoice';
  if v_def is null then raise exception '0159: create_invoice not found'; end if;

  v_anchor := E'  v_member_company text := '''';\n';
  if position(v_anchor in v_def) = 0 then raise exception '0159: anchor A missing'; end if;
  v_def := replace(v_def, v_anchor, v_anchor
    || E'  v_member_person text := '''';\n'
    || E'  v_member_courtesy text := '''';\n');

  -- The postal block now needs the workspace language as well.
  v_anchor := E'public.profile_postal_block(pr, v_workspace.country_code)';
  if position(v_anchor in v_def) = 0 then raise exception '0159: anchor B missing'; end if;
  v_def := replace(v_def, v_anchor,
    E'public.profile_postal_block(pr, v_workspace.country_code, v_workspace.default_locale)');

  v_anchor := E'         coalesce(pr.legal_id, ''''), coalesce(pr.email, ''''), coalesce(pr.phone, '''')\n';
  if position(v_anchor in v_def) = 0 then raise exception '0159: anchor C missing'; end if;
  v_def := replace(v_def, v_anchor,
       E'         coalesce(pr.legal_id, ''''), coalesce(pr.email, ''''), coalesce(pr.phone, ''''),\n'
    || E'         coalesce(public.profile_person_name(pr), ''''), coalesce(pr.courtesy, '''')\n');

  v_anchor := E'         v_member_legal, v_member_email, v_member_phone\n';
  if position(v_anchor in v_def) = 0 then raise exception '0159: anchor D missing'; end if;
  v_def := replace(v_def, v_anchor,
       E'         v_member_legal, v_member_email, v_member_phone,\n'
    || E'         v_member_person, v_member_courtesy\n');

  v_anchor := E'      ''company'', v_member_company,\n';
  if position(v_anchor in v_def) = 0 then raise exception '0159: anchor E missing'; end if;
  v_def := replace(v_def, v_anchor, v_anchor
    || E'      ''person'', v_member_person,\n'
    || E'      ''courtesy'', v_member_courtesy,\n');

  execute v_def;
end
$patch$;
