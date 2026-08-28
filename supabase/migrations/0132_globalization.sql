-- SPDX-License-Identifier: 0BSD
-- 0132 — globalization (#711): the member's format preferences, and the
-- workspace's currency and clock validated instead of trusted.
--
-- THE WORKSPACE OWNS THE MONEY AND THE CLOCK; THE MEMBER OWNS HOW THEY
-- READ THEM. Three columns on the profile say how: the locale numbers
-- and dates are written in, the clock (24h / 12h / whatever that locale
-- does), and whether a bare instant shows in the workspace's zone or
-- the device's. On the PROFILE, not the device — a preference that
-- follows the phone and not the person is one you set three times.
--
-- And two things the workspace row accepted as free text since day
-- one: `currency_code` and `timezone`. A typo in either shipped —
-- `Europe/Pairs` made every booking window silently fall back to the
-- device clock, and `EURO` would have reached an invoice. The app's
-- pickers now only offer valid values; this makes the row refuse the
-- rest, whatever wrote it.

-- ---------------------------------------------------------------- 1
-- Member preferences.

alter table public.profiles
  add column if not exists format_locale text not null default '',
  add column if not exists clock text not null default 'auto',
  add column if not exists time_zone_mode text not null default 'workspace';

alter table public.profiles
  drop constraint if exists profiles_clock_check,
  add constraint profiles_clock_check
    check (clock in ('auto', '24h', '12h')),
  drop constraint if exists profiles_time_zone_mode_check,
  add constraint profiles_time_zone_mode_check
    check (time_zone_mode in ('workspace', 'device')),
  -- '' or a language_REGION tag. The client offers a fixed list; this
  -- only keeps garbage out.
  drop constraint if exists profiles_format_locale_check,
  add constraint profiles_format_locale_check
    check (format_locale = '' or format_locale ~ '^[a-z]{2}_[A-Z]{2}$');

-- ---------------------------------------------------------------- 2
-- The currency code: three capitals, as ISO 4217 spells them. Existing
-- rows are normalised first so the constraint can be added at all.

update public.workspaces
   set currency_code = upper(btrim(currency_code))
 where currency_code is distinct from upper(btrim(currency_code));

alter table public.workspaces
  drop constraint if exists workspaces_currency_code_check,
  add constraint workspaces_currency_code_check
    check (currency_code ~ '^[A-Z]{3}$');

-- ---------------------------------------------------------------- 3
-- The time zone: a name PostgreSQL itself knows. Not a CHECK — a
-- subquery is not allowed there — but a trigger that asks
-- pg_timezone_names, which is the same table the app's picker is drawn
-- from (via the timezone package's copy of the IANA database).

create or replace function public.validate_workspace_timezone()
returns trigger language plpgsql as $$
begin
  if not exists (select 1 from pg_timezone_names where name = new.timezone) then
    raise exception 'unknown time zone: %', new.timezone
      using hint = 'use an IANA name such as Europe/Paris';
  end if;
  return new;
end;
$$;

drop trigger if exists workspaces_validate_timezone on public.workspaces;
create trigger workspaces_validate_timezone
  before insert or update of timezone on public.workspaces
  for each row execute function public.validate_workspace_timezone();

notify pgrst, 'reload schema';
