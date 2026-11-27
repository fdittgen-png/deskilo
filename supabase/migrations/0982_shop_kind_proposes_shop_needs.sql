-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
-- (one row of business_kinds gains three keys of its profile; no workspace's stored flags or settings move, and the
-- other kinds' profiles are not changed)
--
-- #4492 (row 11, D6) -- the shop kind proposes what a shop needs. The profile of 0890 proposed the stock, the catalogue
-- and the purchases; a grocery was left without the report of what expires, without the pallets and cartons its goods
-- arrive in, and without its till. The profile now also proposes:
--
--   * `stockExpiryReport` and `stockHandlingUnits`, both under stock management, which the profile already proposes;
--   * `counterReceipts`, the till. No fiscal rule is written here: where the till is offered is the feature registry's
--     (`feature_registry_entries.countries`, read by `feature_effective`), and what a country lets a till do stays
--     `counter_country_operations` -- a sale is refused where the country's operation is not supported, as before.
--     Till sessions and offline sales stay the owner's own choice.
--
-- As for the freelancer (0846), the trigger of 0834 raises the profile's version and recomputes its digest: a business
-- that confirmed version 1 keeps the switches it has and is offered version 2; nothing switches on by itself.
--
-- An app of the last release that does not know one of the three keys shows the proposal and does not apply it (the
-- rule for a key an app does not know); it goes on working with the switches the business has.

update public.business_kinds
   set feature_profile = feature_profile || '{"stockExpiryReport": true, "stockHandlingUnits": true, "counterReceipts": true}'::jsonb
 where code = 'shop';

select public.set_deskilo_schema_version(982);
