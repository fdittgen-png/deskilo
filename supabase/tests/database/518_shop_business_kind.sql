-- SPDX-License-Identifier: AGPL-3.0-or-later
-- #4365 (G16, 0890): a shop is a kind of business of its own. It proposes the stock, the catalogue and the
-- purchases and switches the places off; it proposes no provider, public page or scheduling; no other kind's
-- profile moves; its profile has a version and the digest of its content. The type of shop and the weighed
-- goods are registry settings with their defaults. Rolled back.
begin;
select plan(12);

select is((select sort_order from public.business_kinds where code = 'shop'), 47, 'a shop sorts between freelancer and service');
select is((select feature_profile from public.business_kinds where code = 'shop'),
  '{"placeBooking": false, "moneyTab": true, "services": true, "invoicing": true, "purchases": true, "purchaseOrders": true, "stockManagement": true, "stockReceiving": true, "stockTakeOut": true, "stockLots": true, "stockReorder": true, "stockItemGroups": true, "stockScanning": true}'::jsonb,
  'the shop proposes the stock, the catalogue and the purchases, and switches the places off');
select is((select count(*)::int from public.business_kinds k, jsonb_object_keys(k.feature_profile) key
            where k.code = 'shop' and key in ('onlinePayments', 'messagesHub', 'publicListings', 'seriesBooking')
              and (k.feature_profile ->> key)::boolean),
  0, 'and proposes no provider, messages, public page or scheduling');
select is((select profile_version from public.business_kinds where code = 'shop'), 1, 'a new kind is at version 1');
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
