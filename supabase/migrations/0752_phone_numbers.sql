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

alter table public.profiles
  add column if not exists whatsapp_typed text not null default ''
    check (char_length(whatsapp_typed) <= 40);
comment on column public.profiles.whatsapp_typed is
  '#3650: the WhatsApp number as its owner typed it; whatsapp is its validated international form.';

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(752);
