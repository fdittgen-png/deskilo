-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0752 (#3650, i18n I4) -- a phone number has two forms that are never
-- confused: what the person typed, kept as it is, and the validated
-- international form (E.164), present only when the app could validate it
-- for an explicit country. Links for calling and messaging are built from
-- the validated form only.
--
--   * profiles.whatsapp keeps holding the international form, under its
--     check. The app reads it as an international number, which is never
--     reinterpreted: a valid one opens its chat as before, and a legacy one
--     that is not valid (a national number stored with a + in front) is
--     shown, flagged for correction, and opens nothing until its owner
--     confirms or corrects it. Nothing is rewritten in bulk.
--   * profiles.whatsapp_typed: what the person typed for it.
--   * The identity phone (profiles.phone, and a managed identity's) stays as
--     typed: it prints as typed and no link is built from it. The app now
--     validates it when it is edited.
--   * Erasure clears both forms of the number: erase_my_membership (0323)
--     blanks whatsapp_typed beside whatsapp. The personal-data export reads
--     the profile row whole, so it carries what was typed.

alter table public.profiles
  add column if not exists whatsapp_typed text not null default ''
    check (char_length(whatsapp_typed) <= 40);
comment on column public.profiles.whatsapp_typed is
  '#3650: the WhatsApp number as its owner typed it; whatsapp is its validated international form.';

-- ── erasure clears both forms of the number ─────────────────────────────
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text language plpgsql as $f$
begin
  if position(p_old in p_def) > 0 then
    return replace(p_def, p_old, p_new);
  end if;
  return null;
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public;

do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef('public.erase_my_membership(uuid)'::regprocedure) into v_def;
  v_def := pg_temp.anchor_replace(v_def,
    $r$set display_name = '', whatsapp = '', status_text = '', address = '',$r$,
    $r$set display_name = '', whatsapp = '', whatsapp_typed = '', status_text = '', address = '',$r$);
  if v_def is null then
    raise exception '0752: erase_my_membership anchor missing' using errcode = 'P0001';
  end if;
  execute v_def;
end
$migration$;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(752);
