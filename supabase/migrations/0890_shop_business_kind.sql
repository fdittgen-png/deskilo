-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- (one new kind row and two registry rows; no workspace's stored flags or settings move, and the
-- other kinds' profiles are not changed)
--
-- #4365 (G16) -- a shop is a kind of business of its own: an épicerie, a bakery, a butcher, a
-- florist, a corner shop. Like the freelancer (0834) it is a row of `business_kinds` with a
-- profile; the trigger of 0834 gives it its version and digest, so an owner's confirmation names
-- exactly what was reviewed.
--
--  * 'shop' (sort 47, between freelancer and service) proposes the stock (management, receiving,
--    take-out, lots, reorder), services as the catalogue, purchases and purchase orders, and
--    switches the places off. It proposes no provider, no public page and nothing a studio
--    schedules. Scanning and item groups join the profile when their features exist; RFID tags
--    are offered, not proposed; the counter sale joins when its flag exists.
--  * `business.shop_type` (grocery, bakery, butcher, florist, corner_shop) is the owner's choice
--    of type: it changes words and examples, never the logic.
--  * `stock.weighed_goods` (bool, off): the business sells by weight, so a new item is proposed in
--    kilograms.

insert into public.business_kinds (code, sort_order) values ('shop', 47)
on conflict (code) do nothing;
update public.business_kinds
   set feature_profile = '{"placeBooking": false, "moneyTab": true, "services": true, "invoicing": true, "purchases": true, "purchaseOrders": true, "stockManagement": true, "stockReceiving": true, "stockTakeOut": true, "stockLots": true, "stockReorder": true, "stockItemGroups": true, "stockScanning": true}'::jsonb
 where code = 'shop' and feature_profile = '{}'::jsonb;

-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('business.shop_type', 'enum', '"grocery"'::jsonb, null, null, '', 'business', array['workspace'], 'manageConfiguration', null, true, '["grocery","bakery","butcher","florist","corner_shop"]'::jsonb, 'shop business kind (#4365)', 'The type of shop a business of the kind shop is: grocery (an épicerie, a small supermarket), bakery, butcher, florist or corner shop. It changes the words and the examples the app shows, never what the app does.'),
('stock.weighed_goods', 'bool', 'false'::jsonb, null, null, '', 'business', array['workspace'], 'workspaceSettings', null, true, null, 'shop business kind (#4365)', 'Whether the business sells goods by weight (a butcher, a bakery, a grocery counter). On: a new stock item is proposed in kilograms instead of pieces; an item can still be given any unit. Off: pieces.')
on conflict (key) do nothing;
-- END GENERATED SEED

select public.set_deskilo_schema_version(890);
