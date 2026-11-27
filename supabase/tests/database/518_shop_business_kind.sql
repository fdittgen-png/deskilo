-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4365 (G16, 0890): a shop is a kind of business of its own. It proposes the stock, the catalogue and the
-- purchases and switches the places off; it proposes no provider, public page or scheduling; no other kind's
-- profile moves; its profile has a version and the digest of its content. The type of shop and the weighed
-- goods are registry settings with their defaults.
-- #4492 (0979): the shop also proposes the report of what expires, the handling units and the till; its profile is at
-- its second version; where the till is offered and what a country lets it do are not the profile's. Rolled back.
begin;
select plan(14);

select is((select sort_order from public.business_kinds where code = 'shop'), 47, 'a shop sorts between freelancer and service');
select is((select feature_profile from public.business_kinds where code = 'shop'),
  '{"placeBooking": false, "moneyTab": true, "services": true, "invoicing": true, "purchases": true, "purchaseOrders": true, "stockManagement": true, "stockReceiving": true, "stockTakeOut": true, "stockLots": true, "stockReorder": true, "stockItemGroups": true, "stockScanning": true, "stockExpiryReport": true, "stockHandlingUnits": true, "counterReceipts": true}'::jsonb,
  'the shop proposes the stock, the catalogue and the purchases, what expires, the handling units and the till, and switches the places off');
select is((select count(*)::int from public.business_kinds k, jsonb_object_keys(k.feature_profile) key
            where k.code = 'shop' and not exists (select 1 from public.feature_registry_entries e where e.feature_key = key)),
  0, 'every switch the shop proposes is a feature the registry knows: where each is offered is the registry''s to say');
select is((select count(*)::int from public.business_kinds k, jsonb_object_keys(k.feature_profile) key
            where k.code = 'shop' and key in ('counterTillSessions', 'counterOfflineCash')),
  0, 'till sessions and offline sales stay the owner''s own choice');
select is((select count(*)::int from public.business_kinds k, jsonb_object_keys(k.feature_profile) key
            where k.code = 'shop' and key in ('onlinePayments', 'messagesHub', 'publicListings', 'seriesBooking')
              and (k.feature_profile ->> key)::boolean),
  0, 'and proposes no provider, messages, public page or scheduling');
select is((select profile_version from public.business_kinds where code = 'shop'), 2,
  'the profile was extended once: a business that confirmed the first version is offered the second');
select is((select profile_digest from public.business_kinds where code = 'shop'),
  encode(sha256(convert_to((select feature_profile::text from public.business_kinds where code = 'shop'), 'UTF8')), 'hex'),
  'the digest is the sha256 of the profile');
select is((select feature_profile from public.business_kinds where code = 'freelancer'),
  '{"placeBooking": false, "moneyTab": true, "services": true, "invoicing": true, "billingCustomers": true, "customerQuotes": true, "purchases": true, "standaloneInvoicing": true, "serviceFulfilment": true}'::jsonb,
  'the freelancer keeps the profile it had');
select is((select profile_digest from public.business_kinds where code = 'freelancer'),
  encode(sha256(convert_to((select feature_profile::text from public.business_kinds where code = 'freelancer'), 'UTF8')), 'hex'),
  'and its digest still follows its profile');
select is((select count(*)::int from public.business_kinds where profile_digest = ''), 0, 'every kind has a digest');

select is((select default_value from public.setting_definitions where key = 'business.shop_type'), '"grocery"'::jsonb,
  'the type of shop is a grocery until the owner chooses');
select is((select choices from public.setting_definitions where key = 'business.shop_type'),
  '["grocery","bakery","butcher","florist","corner_shop"]'::jsonb, 'with the five types');
select is((select default_value from public.setting_definitions where key = 'stock.weighed_goods'), 'false'::jsonb,
  'goods are counted in pieces until the owner says they are weighed');
select ok(not has_table_privilege('authenticated', 'public.business_kinds', 'update'), 'no client edits a profile');

select * from finish();
rollback;
