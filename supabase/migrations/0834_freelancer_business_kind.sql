-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (two columns and a trigger on business_kinds, one new kind row; no workspace's
-- stored flags or settings move, and the other kinds' profiles are not changed)
--
-- #4168 (A1) -- a freelancer is a kind of business of its own, and a kind's
-- profile has a version.
--
--  * business_kinds.profile_version / profile_digest identify the particular
--    profile an owner reviewed: the digest is the sha256 of the profile, the
--    version rises when the profile changes. A confirmation names the kind, its
--    version and its digest, so a profile that changed after the review is
--    reviewed again, and a later change never silently reapplies to a business
--    that already confirmed an earlier one. The trigger keeps both in step with
--    feature_profile, so a migration that edits a profile cannot forget them.
--  * 'freelancer' (sort 45, between salon and service) proposes the money tab,
--    services, invoicing, billing customers, customer quotes and purchases, and
--    switches the places off. It does not propose online payments (a provider),
--    subscriptions, messages, a public page, stock or anything a studio
--    schedules: a freelancer who wants them turns them on. The generic 'service'
--    kind is unchanged.

alter table public.business_kinds
  add column if not exists profile_version integer not null default 1 check (profile_version >= 1);
alter table public.business_kinds
  add column if not exists profile_digest text not null default '';

create or replace function public.business_kinds_profile_version()
returns trigger language plpgsql set search_path = public as $fn$
begin
  new.profile_digest := encode(sha256(convert_to(new.feature_profile::text, 'UTF8')), 'hex');
  if tg_op = 'UPDATE' and new.feature_profile is distinct from old.feature_profile then
    new.profile_version := old.profile_version + 1;
  end if;
  return new;
end;
$fn$;
revoke execute on function public.business_kinds_profile_version() from public, anon, authenticated;

drop trigger if exists business_kinds_profile_version on public.business_kinds;
create trigger business_kinds_profile_version
  before insert or update of feature_profile on public.business_kinds
  for each row execute function public.business_kinds_profile_version();

-- the rows that exist get their digest (the version stays 1: nothing changed)
update public.business_kinds set feature_profile = feature_profile;

insert into public.business_kinds (code, sort_order) values ('freelancer', 45)
on conflict (code) do nothing;
update public.business_kinds
   set feature_profile = '{"placeBooking": false, "moneyTab": true, "services": true, "invoicing": true, "billingCustomers": true, "customerQuotes": true, "purchases": true}'::jsonb
 where code = 'freelancer' and feature_profile = '{}'::jsonb;

select public.set_deskilo_schema_version(834);
