-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
-- (the feature registry and the setup level catalogue are restated; four tables; no stored flag moves)
--
-- #4435 (G20, first of four files) -- handling units. Goods move in the unit they were received in (a pallet, a carton, a crate)
-- or in the store's own repackaged units, and stay traceable through the repack. Off with the feature `stockHandlingUnits`
-- (under stock management, off by default).
--   * `stock_handling_units`: a unit has a code of the store's own (unique in the business), optionally the supplier's label
--     (an SSCC), a kind, a place, a state (open, unpacked, retired) and a revision that every move, unpack or repack raises (two
--     people moving one unit at once: the second is told the new place). One level of nesting: a pallet of cartons.
--   * `stock_handling_unit_lines`: what a unit holds, one line per item, variant and lot, with a quantity. It is a breakdown of
--     the ledger, never a second balance: the ledger (`stock_balances`, written by the one stock path) stays the authority.
--   * `stock_handling_unit_pieces`: the pieces of a line of an item tracked piece by piece; a piece is in at most one unit.
--   * `stock_movement_handling_units`: the unit a movement moved, so the trace shows "in carton X".
--   * `stock_repacks` and `stock_repack_lines`: what a repack took out of which units (or loose stock) and what it put into
--     which units, one row each, append-only: a lot followed through a repack is found on both sides.
-- The commands follow in 0929 (receive, move, unpack), 0930 (repack, reads); 0931 carries the template restate.
-- restates 0921
create or replace function public.feature_registry()
returns jsonb
language sql
immutable
set search_path = public
as $registry$
  select '{
    "calendarTab": {"parent": null, "default": true, "core": true},
    "eventsTab": {"parent": null, "default": true, "core": true},
    "moneyTab": {"parent": null, "default": true, "core": true},
    "services": {"parent": "moneyTab", "default": true, "core": true},
    "accessorySupplements": {"parent": "moneyTab", "default": false, "core": false},
    "onlinePayments": {"parent": "moneyTab", "default": false, "core": false},
    "invoicing": {"parent": "moneyTab", "default": true, "core": true},
    "adminInvoicing": {"parent": "invoicing", "default": false, "core": false},
    "pdfExport": {"parent": null, "default": true, "core": true},
    "seriesBooking": {"parent": null, "default": true, "core": true},
    "bookForOthers": {"parent": null, "default": true, "core": true},
    "pushNotifications": {"parent": null, "default": true, "core": true},
    "adminSeatBlocking": {"parent": "placeBooking", "default": false, "core": false},
    "levelBooking": {"parent": "placeBooking", "default": false, "core": false},
    "adminLevelAssign": {"parent": "levelBooking", "default": false, "core": false},
    "kioskMode": {"parent": "placeBooking", "default": true, "core": false},
    "nfcBadges": {"parent": "kioskMode", "default": true, "core": false},
    "membersDirectory": {"parent": null, "default": true, "core": true},
    "whatsappIntegration": {"parent": "membersDirectory", "default": true, "core": false},
    "spaceQrCodes": {"parent": "placeBooking", "default": true, "core": true},
    "coOwner": {"parent": null, "default": true, "core": false},
    "autoCheckInOut": {"parent": "placeBooking", "default": false, "core": false},
    "dataExport": {"parent": null, "default": true, "core": true},
    "workingHours": {"parent": null, "default": true, "core": true},
    "invoicePdfTemplate": {"parent": "invoicing", "default": true, "core": false},
    "invoiceAddressWindow": {"parent": "invoicing", "default": true, "core": false},
    "memberNotifications": {"parent": null, "default": true, "core": true},
    "documents": {"parent": null, "default": true, "core": true},
    "dunning": {"parent": "invoicing", "default": true, "core": false},
    "memberReports": {"parent": "moneyTab", "default": true, "core": false},
    "deletionRequests": {"parent": null, "default": true, "core": true},
    "roleManagement": {"parent": null, "default": true, "core": true},
    "vatManagement": {"parent": "invoicing", "default": true, "core": false},
    "vatDeclarations": {"parent": "vatManagement", "default": true, "core": false},
    "einvoiceCustomerDelivery": {"parent": "invoicing", "default": true, "core": false},
    "planObjectDelete": {"parent": "placeBooking", "default": true, "core": true},
    "notificationGrouping": {"parent": "eventsTab", "default": true, "core": true},
    "bookingPolicies": {"parent": null, "default": true, "core": true},
    "bookingGate": {"parent": "bookingPolicies", "default": true, "core": true},
    "nfcSeatTags": {"parent": "placeBooking", "default": true, "core": false},
    "qrBadges": {"parent": "kioskMode", "default": true, "core": false},
    "kioskMemberPhotos": {"parent": "kioskMode", "default": true, "core": false},
    "subscriptionInvoices": {"parent": "invoicing", "default": true, "core": false},
    "usageInvoices": {"parent": "invoicing", "default": true, "core": false},
    "invoiceSettlement": {"parent": "invoicing", "default": true, "core": false},
    "invoiceJourney": {"parent": "invoicing", "default": true, "core": false},
    "messageGestures": {"parent": null, "default": true, "core": true},
    "uniqueMonograms": {"parent": null, "default": true, "core": true},
    "planMemberPhotos": {"parent": "placeBooking", "default": true, "core": false},
    "regionalFormats": {"parent": null, "default": true, "core": true},
    "calendarHub": {"parent": "calendarTab", "default": true, "core": true},
    "calendarViews": {"parent": "calendarHub", "default": true, "core": true},
    "messagesHub": {"parent": null, "default": true, "core": true},
    "reportDesigner": {"parent": "invoicePdfTemplate", "default": true, "core": false},
    "memberPage": {"parent": "membersDirectory", "default": true, "core": true},
    "invoicingWizard": {"parent": "invoicing", "default": true, "core": false},
    "expenseRepartition": {"parent": "invoicing", "default": true, "core": false},
    "settlementFold": {"parent": "invoiceSettlement", "default": true, "core": false},
    "configurationTransfer": {"parent": "dataExport", "default": true, "core": false},
    "navigationStyle": {"parent": null, "default": true, "core": true},
    "demoMode": {"parent": null, "default": true, "core": false},
    "instanceWizard": {"parent": null, "default": true, "core": false},
    "dataAccessLog": {"parent": "moneyTab", "default": true, "core": false},
    "memberDataExport": {"parent": null, "default": true, "core": true},
    "financeFaces": {"parent": "moneyTab", "default": true, "core": true},
    "paymentReminders": {"parent": "dunning", "default": true, "core": false},
    "supplyExpenses": {"parent": "services", "default": true, "core": false},
    "validationScopes": {"parent": null, "default": true, "core": false},
    "validationChain": {"parent": null, "default": true, "core": false},
    "richMessageRefs": {"parent": "memberNotifications", "default": true, "core": true},
    "calendarValidations": {"parent": "calendarHub", "default": true, "core": false},
    "usageRecords": {"parent": "invoicing", "default": true, "core": false},
    "reportDesignExchange": {"parent": "reportDesigner", "default": true, "core": false},
    "reportLayouts": {"parent": "reportDesigner", "default": true, "core": false},
    "personalInfo": {"parent": null, "default": true, "core": true},
    "managedProfiles": {"parent": "membersDirectory", "default": true, "core": false},
    "numberSequences": {"parent": "invoicing", "default": false, "core": false},
    "workspaceStatus": {"parent": "invoicing", "default": false, "core": false},
    "expenseRepartitionWizard": {"parent": "expenseRepartition", "default": false, "core": false},
    "multiSite": {"parent": "placeBooking", "default": false, "core": false},
    "vatGroups": {"parent": "vatManagement", "default": false, "core": false},
    "vatRateHistory": {"parent": "vatManagement", "default": false, "core": false},
    "vatCounterparty": {"parent": "vatManagement", "default": false, "core": false},
    "environmentPairs": {"parent": null, "default": true, "core": false},
    "deployments": {"parent": "environmentPairs", "default": true, "core": false},
    "managedProfileAccess": {"parent": "managedProfiles", "default": false, "core": false},
    "seatDayTimeline": {"parent": "placeBooking", "default": true, "core": true},
    "memberPaymentTerms": {"parent": "invoicing", "default": true, "core": false},
    "usageReport": {"parent": "usageRecords", "default": true, "core": false},
    "reportTexts": {"parent": "reportDesigner", "default": true, "core": false},
    "letterStandard": {"parent": "reportLayouts", "default": true, "core": false},
    "vatReport": {"parent": "vatDeclarations", "default": true, "core": false},
    "priceNegotiations": {"parent": "moneyTab", "default": true, "core": false},
    "scheduledExpenses": {"parent": "moneyTab", "default": true, "core": false},
    "badgeSignIn": {"parent": "nfcBadges", "default": false, "core": false},
    "formHelpHints": {"parent": null, "default": true, "core": true},
    "uiAnimations": {"parent": null, "default": true, "core": true},
    "memberOrigin": {"parent": "membersDirectory", "default": false, "core": false},
    "memberEnvironments": {"parent": "environmentPairs", "default": false, "core": false},
    "workspaceLibrary": {"parent": null, "default": false, "core": false},
    "singleRoomLevelNames": {"parent": "placeBooking", "default": true, "core": true},
    "publicHolidays": {"parent": null, "default": false, "core": false},
    "workspaceVocabulary": {"parent": null, "default": false, "core": false},
    "carnets": {"parent": "invoicing", "default": false, "core": false},
    "publicListings": {"parent": null, "default": false, "core": true},
    "workspaceBranding": {"parent": null, "default": false, "core": false},
    "customRoles": {"parent": null, "default": false, "core": false},
    "customFields": {"parent": null, "default": false, "core": false},
    "decisionSurface": {"parent": null, "default": false, "core": false},
    "recordingPrivacy": {"parent": null, "default": false, "core": false},
    "memberAccountMenu": {"parent": null, "default": false, "core": false},
    "mcpAccess": {"parent": null, "default": false, "core": false},
    "calendarFileExport": {"parent": null, "default": true, "core": true},
    "memberGettingStarted": {"parent": null, "default": true, "core": true},
    "placeFeedback": {"parent": "placeBooking", "default": true, "core": true},
    "spaceInquiries": {"parent": null, "default": true, "core": true},
    "messageForwarding": {"parent": "memberNotifications", "default": true, "core": true},
    "captureProtection": {"parent": "memberNotifications", "default": true, "core": true},
    "holidayImport": {"parent": "publicHolidays", "default": false, "core": false},
    "capacityKpi": {"parent": "placeBooking", "default": false, "core": false},
    "accountingBook": {"parent": "invoicing", "default": false, "core": false},
    "roleAssignment": {"parent": "roleManagement", "default": true, "core": true},
    "taskRecorder": {"parent": null, "default": false, "core": false},
    "guestParticipation": {"parent": "placeBooking", "default": false, "core": true},
    "messageMentions": {"parent": "memberNotifications", "default": true, "core": true},
    "supplyClassification": {"parent": "vatManagement", "default": true, "core": false},
    "viesVerification": {"parent": "supplyClassification", "default": true, "core": false},
    "recapitulativeStatement": {"parent": "vatDeclarations", "default": true, "core": false, "countries": ["@eu"]},
    "inputVat": {"parent": "vatDeclarations", "default": true, "core": false},
    "configurableSettings": {"parent": null, "default": true, "core": false},
    "salesTax": {"parent": "invoicing", "default": true, "core": false},
    "meetingRooms": {"parent": "placeBooking", "default": false, "core": false},
    "parking": {"parent": "placeBooking", "default": false, "core": false},
    "webMcp": {"parent": "mcpAccess", "default": false, "core": false},
    "purchases": {"parent": "moneyTab", "default": false, "core": false},
    "premisesLease": {"parent": "scheduledExpenses", "default": false, "core": false},
    "assetRegister": {"parent": "purchases", "default": false, "core": false},
    "externalRooms": {"parent": "levelBooking", "default": false, "core": false},
    "accountingPeriods": {"parent": "accountingBook", "default": false, "core": false},
    "biReportDesigner": {"parent": null, "default": false, "core": false},
    "purchaseAnalytics": {"parent": "purchases", "default": false, "core": false},
    "workspaceOverview": {"parent": null, "default": false, "core": false},
    "setupGuide": {"parent": null, "default": true, "core": true},
    "dataReport": {"parent": "dataExport", "default": true, "core": true},
    "personalShell": {"parent": null, "default": false, "core": false},
    "foreignCurrencyPurchases": {"parent": "purchases", "default": false, "core": false},
    "accountingConnectors": {"parent": "accountingBook", "default": false, "core": false},
    "bankImport": {"parent": "invoicing", "default": false, "core": false},
    "planDecor": {"parent": "placeBooking", "default": true, "core": true},
    "mtdSubmission": {"parent": "vatDeclarations", "default": false, "core": false, "countries": ["GB"]},
    "purchaseOrders": {"parent": "purchases", "default": false, "core": false},
    "guestPasses": {"parent": "invoicing", "default": false, "core": false},
    "placeBooking": {"parent": null, "default": true, "core": true},
    "reminderEmail": {"parent": "dunning", "default": false, "core": false},
    "invoiceEmail": {"parent": "invoicing", "default": false, "core": false},
    "standaloneInvoicing": {"parent": "invoicing", "default": false, "core": false},
    "kioskEnrolment": {"parent": "kioskMode", "default": true, "core": false},
    "quickSearch": {"parent": null, "default": true, "core": true},
    "stockManagement": {"parent": "services", "default": false, "core": false},
    "stockLots": {"parent": "stockManagement", "default": false, "core": false},
    "stockReceiving": {"parent": "stockManagement", "default": false, "core": false},
    "stockTakeOut": {"parent": "stockManagement", "default": false, "core": false},
    "stockReorder": {"parent": "stockManagement", "default": false, "core": false},
    "stockReturns": {"parent": "stockManagement", "default": false, "core": false},
    "stockCounts": {"parent": "stockManagement", "default": false, "core": false},
    "stockCycleCounts": {"parent": "stockCounts", "default": false, "core": false},
    "stockItemGroups": {"parent": "stockManagement", "default": false, "core": false},
    "stockTags": {"parent": "stockManagement", "default": false, "core": false},
    "stockScanning": {"parent": "stockManagement", "default": false, "core": false},
    "counterReceipts": {"parent": "standaloneInvoicing", "default": false, "core": false},
    "counterTillSessions": {"parent": "counterReceipts", "default": false, "core": false},
    "stockTagReads": {"parent": "stockTags", "default": false, "core": false},
    "stockExpiryReport": {"parent": "stockManagement", "default": false, "core": false},
    "stockHandlingUnits": {"parent": "stockManagement", "default": false, "core": false},
    "organisation": {"parent": null, "default": true, "core": true},
    "billingCustomers": {"parent": "invoicing", "default": false, "core": false},
    "customerQuotes": {"parent": "invoicing", "default": false, "core": false},
    "serviceFulfilment": {"parent": "billingCustomers", "default": false, "core": false}
  }'::jsonb
$registry$;
revoke execute on function public.feature_registry() from public, anon;

-- restates 0921
create or replace function public.setup_level_catalogue()
returns jsonb language sql immutable set search_path = public as $fn$
  select $json${"processes":[{"process":"bookings","levels":[{"level":"none","features":[],"needs":[]},{"level":"simple","features":["seriesBooking","bookForOthers","spaceQrCodes","workingHours","planObjectDelete","bookingPolicies","seatDayTimeline","bookingGate","singleRoomLevelNames","calendarFileExport","placeFeedback","planDecor","placeBooking"],"needs":[]},{"level":"resources","features":["adminSeatBlocking","levelBooking","adminLevelAssign","planMemberPhotos","multiSite","publicHolidays","holidayImport","guestParticipation","meetingRooms","parking","externalRooms"],"needs":[]},{"level":"measured","features":["kioskMode","nfcBadges","autoCheckInOut","nfcSeatTags","qrBadges","kioskMemberPhotos","badgeSignIn","capacityKpi","kioskEnrolment"],"needs":[]}]},{"process":"community","levels":[{"level":"basic","features":["calendarTab","eventsTab","pushNotifications","membersDirectory","memberNotifications","deletionRequests","roleManagement","notificationGrouping","calendarHub","richMessageRefs","personalInfo","messageGestures","calendarViews","messagesHub","memberPage","messageForwarding","captureProtection","roleAssignment","messageMentions"],"needs":[]},{"level":"organised","features":["whatsappIntegration","coOwner","validationScopes","validationChain","calendarValidations","managedProfiles","managedProfileAccess","memberOrigin","customRoles","customFields"],"needs":[]}]},{"process":"money","levels":[{"level":"none","features":[],"needs":[]},{"level":"statements","features":["moneyTab","services","accessorySupplements","memberReports","dataAccessLog","financeFaces","priceNegotiations"],"needs":[]},{"level":"invoices","features":["invoicing","adminInvoicing","invoicePdfTemplate","invoiceAddressWindow","dunning","paymentReminders","usageRecords","reportDesignExchange","reportLayouts","numberSequences","workspaceStatus","memberPaymentTerms","reportTexts","usageReport","letterStandard","subscriptionInvoices","usageInvoices","invoiceSettlement","invoiceJourney","reportDesigner","invoicingWizard","settlementFold","carnets","guestPasses","reminderEmail","invoiceEmail","standaloneInvoicing","billingCustomers","customerQuotes","serviceFulfilment"],"needs":[]}]},{"process":"payments","levels":[{"level":"off","features":[],"needs":[]},{"level":"online","features":["onlinePayments"],"needs":[{"process":"money","level":"statements"}]}]},{"process":"tax","levels":[{"level":"none","features":[],"needs":[]},{"level":"vat","features":["vatManagement","vatDeclarations","vatGroups","vatRateHistory","vatCounterparty","vatReport","supplyClassification","viesVerification","recapitulativeStatement","inputVat","salesTax"],"needs":[{"process":"money","level":"invoices"}]},{"level":"books","features":["einvoiceCustomerDelivery","accountingBook","accountingPeriods","accountingConnectors","bankImport","mtdSubmission"],"needs":[{"process":"money","level":"invoices"}]}]},{"process":"purchases","levels":[{"level":"none","features":[],"needs":[]},{"level":"expenses","features":["supplyExpenses","expenseRepartitionWizard","scheduledExpenses","expenseRepartition"],"needs":[{"process":"money","level":"invoices"}]},{"level":"full","features":["purchases","premisesLease","assetRegister","purchaseAnalytics","foreignCurrencyPurchases","purchaseOrders","stockManagement","stockLots","stockReceiving","stockTakeOut","stockReorder","stockReturns","stockCounts","stockCycleCounts","stockItemGroups","stockTags","stockScanning","counterReceipts","counterTillSessions","stockTagReads","stockExpiryReport","stockHandlingUnits"],"needs":[{"process":"money","level":"invoices"}]}]},{"process":"presentation","levels":[{"level":"basic","features":["uniqueMonograms"],"needs":[]},{"level":"branded","features":["workspaceVocabulary","workspaceBranding"],"needs":[]},{"level":"public","features":["publicListings","spaceInquiries"],"needs":[]}]},{"process":"operations","levels":[{"level":"basic","features":["pdfExport","dataExport","documents","formHelpHints","uiAnimations","regionalFormats","memberDataExport","navigationStyle","demoMode","memberAccountMenu","memberGettingStarted","setupGuide","dataReport","quickSearch","organisation"],"needs":[]},{"level":"insight","features":["decisionSurface","biReportDesigner","workspaceOverview"],"needs":[]},{"level":"advanced","features":["environmentPairs","deployments","configurationTransfer","instanceWizard","memberEnvironments","workspaceLibrary","configurableSettings"],"needs":[]}]},{"process":"assistant","levels":[{"level":"off","features":[],"needs":[]},{"level":"on","features":["recordingPrivacy","mcpAccess","taskRecorder","webMcp"],"needs":[]}]}],"presets":[{"preset":"essentiel","levels":[{"process":"bookings","level":"simple"},{"process":"community","level":"basic"},{"process":"money","level":"statements"},{"process":"payments","level":"off"},{"process":"tax","level":"none"},{"process":"purchases","level":"none"},{"process":"presentation","level":"basic"},{"process":"operations","level":"basic"},{"process":"assistant","level":"off"}]},{"preset":"standard","levels":[{"process":"bookings","level":"resources"},{"process":"community","level":"organised"},{"process":"money","level":"invoices"},{"process":"payments","level":"off"},{"process":"tax","level":"none"},{"process":"purchases","level":"expenses"},{"process":"presentation","level":"branded"},{"process":"operations","level":"insight"},{"process":"assistant","level":"off"}]},{"preset":"complet","levels":[{"process":"bookings","level":"measured"},{"process":"community","level":"organised"},{"process":"money","level":"invoices"},{"process":"payments","level":"online"},{"process":"tax","level":"books"},{"process":"purchases","level":"full"},{"process":"presentation","level":"public"},{"process":"operations","level":"advanced"},{"process":"assistant","level":"off"}]}]}$json$::jsonb;
$fn$;
revoke execute on function public.setup_level_catalogue() from public, anon, authenticated;
revoke execute on function public.setup_level_catalogue() from public, anon, authenticated;

-- ── the units ───────────────────────────────────────────────────────────
create table public.stock_handling_units (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  code text not null check (btrim(code) <> '' and length(code) <= 64),
  label_code text check (label_code is null or (btrim(label_code) <> '' and length(label_code) <= 64)),
  kind text not null default 'other' check (kind in ('pallet', 'carton', 'crate', 'box', 'other')),
  state text not null default 'open' check (state in ('open', 'unpacked', 'retired')),
  location_id uuid not null,
  parent_unit_id uuid,
  receipt_line_id uuid,
  revision int not null default 1 check (revision >= 1),
  unique (workspace_id, id),
  foreign key (workspace_id, location_id) references public.stock_locations (workspace_id, id),
  foreign key (workspace_id, parent_unit_id) references public.stock_handling_units (workspace_id, id),
  check (parent_unit_id is distinct from id)
);
select public.ensure_system_columns('stock_handling_units');
create unique index stock_handling_units_code on public.stock_handling_units (workspace_id, lower(code));
create unique index stock_handling_units_label on public.stock_handling_units (workspace_id, lower(label_code)) where label_code is not null;
create index stock_handling_units_place on public.stock_handling_units (workspace_id, location_id) where state = 'open';
create index stock_handling_units_parent on public.stock_handling_units (workspace_id, parent_unit_id) where parent_unit_id is not null;

create table public.stock_handling_unit_lines (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  unit_id uuid not null,
  item_id uuid not null,
  variant_id uuid,
  lot_id uuid,
  quantity numeric(18, 6) not null check (quantity > 0),
  unique (workspace_id, id),
  foreign key (workspace_id, unit_id) references public.stock_handling_units (workspace_id, id) on delete cascade,
  foreign key (workspace_id, item_id) references public.services (workspace_id, id) on delete cascade,
  foreign key (workspace_id, variant_id) references public.item_variants (workspace_id, id),
  foreign key (workspace_id, lot_id) references public.stock_lots (workspace_id, id) on delete cascade
);
select public.ensure_system_columns('stock_handling_unit_lines');
create unique index stock_handling_unit_lines_content on public.stock_handling_unit_lines
  (unit_id, item_id, coalesce(variant_id, '00000000-0000-0000-0000-000000000000'::uuid), coalesce(lot_id, '00000000-0000-0000-0000-000000000000'::uuid));
create index stock_handling_unit_lines_item on public.stock_handling_unit_lines (workspace_id, item_id);

create table public.stock_handling_unit_pieces (
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  unit_line_id uuid not null,
  piece_id uuid not null,
  primary key (piece_id),
  foreign key (workspace_id, unit_line_id) references public.stock_handling_unit_lines (workspace_id, id) on delete cascade,
  foreign key (workspace_id, piece_id) references public.stock_tagged_units (workspace_id, id) on delete cascade
);
select public.ensure_system_columns('stock_handling_unit_pieces');
create index stock_handling_unit_pieces_line on public.stock_handling_unit_pieces (workspace_id, unit_line_id);

create table public.stock_movement_handling_units (
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  movement_id uuid not null,
  unit_id uuid not null,
  primary key (movement_id, unit_id),
  foreign key (workspace_id, unit_id) references public.stock_handling_units (workspace_id, id) on delete cascade
);
select public.ensure_system_columns('stock_movement_handling_units');
create index stock_movement_handling_units_unit on public.stock_movement_handling_units (workspace_id, unit_id);

create table public.stock_repacks (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  request_id uuid not null,
  made_by uuid not null,
  made_at timestamptz not null default now(),
  unique (workspace_id, id),
  unique (workspace_id, request_id)
);
select public.ensure_system_columns('stock_repacks');

create table public.stock_repack_lines (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  repack_id uuid not null,
  direction text not null check (direction in ('out', 'in')),
  unit_id uuid,
  item_id uuid not null,
  variant_id uuid,
  lot_id uuid,
  quantity numeric(18, 6) not null check (quantity > 0),
  piece_id uuid,
  foreign key (workspace_id, repack_id) references public.stock_repacks (workspace_id, id) on delete cascade,
  foreign key (workspace_id, unit_id) references public.stock_handling_units (workspace_id, id),
  foreign key (workspace_id, item_id) references public.services (workspace_id, id) on delete cascade
);
select public.ensure_system_columns('stock_repack_lines');
create index stock_repack_lines_repack on public.stock_repack_lines (workspace_id, repack_id);
create index stock_repack_lines_lot on public.stock_repack_lines (workspace_id, item_id, lot_id) where lot_id is not null;

-- ── who reads, who writes ───────────────────────────────────────────────
-- Read like the ledger (viewStock or manageStock, the feature on); written by the commands only. An assistant never reads or writes.
do $rls$
declare
  t text;
begin
  foreach t in array array['stock_handling_units', 'stock_handling_unit_lines', 'stock_handling_unit_pieces',
                           'stock_movement_handling_units', 'stock_repacks', 'stock_repack_lines'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated', t);
    execute format('grant select on public.%I to authenticated', t);
    execute format($p$create policy %I on public.%I for select to authenticated
      using (workspace_id in (select public.workspaces_permitting(array['viewStock', 'manageStock']))
             and public.feature_effective(workspace_id, 'stockHandlingUnits'))$p$, t || '_select', t);
    execute format($p$create policy mcp_delegated_deny on public.%I as restrictive for all to authenticated
      using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated())$p$, t);
  end loop;
end;
$rls$;

select public.set_deskilo_schema_version(928);
