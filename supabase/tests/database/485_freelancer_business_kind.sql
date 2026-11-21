-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4168 (A1, 0834): a freelancer is a kind of business of its own, and a kind's
-- profile has a version and a digest. The freelancer proposes the money side of a
-- one-person service business and switches the places off, and does not propose a
-- provider, subscriptions, messages, a public page, stock or anything a studio
-- schedules; the generic service kind keeps its profile. A profile's digest follows
-- its content and its version rises with a change (never with a no-op), so a
-- proposal that named an earlier version is known to be out of date. Rolled back.
begin;
select plan(11);

select is((select feature_profile from public.business_kinds where code = 'freelancer'),
  '{"placeBooking": false, "moneyTab": true, "services": true, "invoicing": true, "billingCustomers": true, "customerQuotes": true, "purchases": true, "standaloneInvoicing": true, "serviceFulfilment": true}'::jsonb,
  'the freelancer proposes the money side, the invoice a quote ends in, and switches the places off');
select is((select count(*)::int from public.business_kinds k, jsonb_object_keys(k.feature_profile) key
            where k.code = 'freelancer' and key in ('onlinePayments', 'messagesHub', 'publicListings', 'stockManagement', 'seriesBooking')),
  0, 'and proposes no provider, messages, public page, stock or scheduling');
select is((select feature_profile from public.business_kinds where code = 'service'),
  '{"placeBooking": false, "moneyTab": true, "services": true, "invoicing": true, "onlinePayments": true, "messagesHub": true, "publicListings": true}'::jsonb,
  'the generic service kind keeps the profile it had');
select is((select sort_order from public.business_kinds where code = 'freelancer'), 45, 'a freelancer sorts between salon and service');
select is((select profile_digest from public.business_kinds where code = 'freelancer'),
  encode(sha256(convert_to((select feature_profile::text from public.business_kinds where code = 'freelancer'), 'UTF8')), 'hex'),
  'the digest is the sha256 of the profile');
select is((select count(*)::int from public.business_kinds where profile_digest = ''), 0, 'every kind has a digest');
select is((select profile_version from public.business_kinds where code = 'studio'), 1, 'a kind nobody changed is at version 1');

update public.business_kinds set feature_profile = feature_profile where code = 'studio';
select is((select profile_version from public.business_kinds where code = 'studio'), 1, 'a write that changes nothing does not raise the version');
create temp table before_digest as select profile_digest d from public.business_kinds where code = 'studio';
update public.business_kinds set feature_profile = '{"placeBooking": false, "services": true}'::jsonb where code = 'studio';
select is((select profile_version from public.business_kinds where code = 'studio'), 2, 'a changed profile is the next version');
select isnt((select profile_digest from public.business_kinds where code = 'studio'), (select d from before_digest),
  'and has the digest of its new content');

select ok(not has_table_privilege('authenticated', 'public.business_kinds', 'update'), 'no client edits a profile or its version');

select * from finish();
rollback;
