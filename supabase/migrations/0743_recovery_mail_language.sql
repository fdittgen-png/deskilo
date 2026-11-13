-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- 0743 — #3812 (part of #3657, i18n I11d): the recovery e-mail reads in the
-- account's language. The e-mail is written by Auth, whose template sees the
-- account's metadata and nothing else, so the server writes the account's
-- language there whenever it changes: `raw_user_meta_data.locale`, one of
-- the five languages, the interface language first, the document language
-- otherwise, and no key at all when neither is set (the template then reads
-- in the installation's default language). The code is a language and
-- nothing more: no authorization reads it. A write that fails is logged as a
-- warning and never blocks the save that caused it; the next save writes it
-- again. Every existing account is written once below.

-- The account's language: one of the five, or null.
create or replace function public.account_auth_locale(p_user uuid)
returns text language sql stable security definer set search_path = '' as $fn$
  select l from (
    select coalesce(nullif(d.preferences ->> 'ui_locale', ''), nullif(p.preferred_locale, '')) as l
      from public.profiles p
      left join public.directory_people d on d.id = p.person_id
     where p.id = p_user) x
   where l in ('en', 'fr', 'de', 'es', 'it');
$fn$;
revoke execute on function public.account_auth_locale(uuid) from public, anon, authenticated;

-- Writes the account's language into its Auth metadata, when it changed.
create or replace function public.sync_auth_locale(p_user uuid)
returns void language plpgsql volatile security definer set search_path = '' as $fn$
declare v_locale text := public.account_auth_locale(p_user);
begin
  begin
    update auth.users
       set raw_user_meta_data = case
             when v_locale is null then coalesce(raw_user_meta_data, '{}'::jsonb) - 'locale'
             else coalesce(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object('locale', v_locale)
           end
     where id = p_user
       and (raw_user_meta_data ->> 'locale') is distinct from v_locale;
  exception when others then
    -- The save that changed the language stands; the next one writes it.
    raise warning 'the language of account % was not written to its Auth metadata: % (%)',
      p_user, sqlerrm, sqlstate;
  end;
end;
$fn$;
revoke execute on function public.sync_auth_locale(uuid) from public, anon, authenticated;

-- A person's interface language lives in their directory preferences.
create or replace function public.directory_people_auth_locale()
returns trigger language plpgsql security definer set search_path = '' as $fn$
begin
  if new.preferences ->> 'ui_locale' is distinct from old.preferences ->> 'ui_locale' then
    perform public.sync_auth_locale(p.id) from public.profiles p where p.person_id = new.id;
  end if;
  return new;
end;
$fn$;
revoke execute on function public.directory_people_auth_locale() from public, anon, authenticated;
drop trigger if exists directory_people_auth_locale on public.directory_people;
create trigger directory_people_auth_locale
  after update of preferences on public.directory_people
  for each row execute function public.directory_people_auth_locale();

-- The document language, and the person a profile belongs to, live on it.
create or replace function public.profiles_auth_locale()
returns trigger language plpgsql security definer set search_path = '' as $fn$
begin
  perform public.sync_auth_locale(new.id);
  return new;
end;
$fn$;
revoke execute on function public.profiles_auth_locale() from public, anon, authenticated;
drop trigger if exists profiles_auth_locale on public.profiles;
create trigger profiles_auth_locale
  after insert or update of preferred_locale, person_id on public.profiles
  for each row execute function public.profiles_auth_locale();

-- Every existing account, once.
select public.sync_auth_locale(p.id) from public.profiles p;

select public.set_deskilo_schema_version(743);
