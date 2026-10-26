-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- #2380 — the bank's statements read into the space, and each movement
-- matched by a person to what it settles.
--
--   bank_statements        one row per imported file: the format, the
--                          account, its currency, the bank's statement id,
--                          the booked balances the file states, the sha256
--                          of the file's bytes and who imported it. The
--                          source is kept: nothing deletes a statement.
--   bank_statement_lines   one row per movement: booking and value day, the
--                          signed amount (money in positive), currency, the
--                          bank's own transaction id, counterparty name and
--                          IBAN, structured reference (QRR or RF), end-to-end
--                          id, remittance text, and the sha256 of those
--                          financial fields (line_hash). Once matched, the
--                          member payment it became (payment_ledger_id) and
--                          the invoice it was confirmed against, or the
--                          reported outgoing payment it reconciles.
--
-- Importing (import_bank_statement_v1) is idempotent: the same file bytes
-- import nothing a second time, and a movement whose bank transaction id is
-- already known for the account is not created again. A movement WITHOUT a
-- bank id whose financial fields equal a line of another statement is kept
-- in state `review`: two genuine payments may share day, amount and
-- reference, so the hash never collapses them; a person decides
-- (review_bank_line_v1). Within one file two equal movements without ids are
-- both kept: the bank listed them twice. The number of lines is bounded by
-- the setting bank.import_max_lines, and a file is refused whole.
--
-- Matching (match_bank_line_v1) is a person's confirmation of a suggestion:
-- the money in becomes ONE payment credit of the invoice's member, booked on
-- the value day, and the existing match_invoice files the match under the
-- invoice_payment validation, with the same exact / over / under
-- resolutions. A match the validators reject leaves the payment recorded and
-- the movement free to be matched again, never a second payment. Money out
-- reconciles a payment already reported as made
-- (reconcile_bank_line_out_v1): it creates no payment, no expense, no
-- posting; the outgoing payment moves from reported to reconciled, which
-- only a bank line can do (outgoing_payments_guard, 0467's, restated).
--
-- Every client entry point needs the bankImport flag (child of invoicing),
-- refuses an assistant's delegated token, and asks the permission matrix:
-- issueInvoices to import and match, recordOutgoingPayments to reconcile,
-- viewFinances or issueInvoices to read.

-- ── the feature registry knows it (dart run tool/build_feature_registry_sql.dart) ──
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
    "adminSeatBlocking": {"parent": null, "default": false, "core": false},
    "levelBooking": {"parent": null, "default": false, "core": false},
    "adminLevelAssign": {"parent": "levelBooking", "default": false, "core": false},
    "kioskMode": {"parent": null, "default": true, "core": false},
    "nfcBadges": {"parent": "kioskMode", "default": true, "core": false},
    "membersDirectory": {"parent": null, "default": true, "core": true},
    "whatsappIntegration": {"parent": "membersDirectory", "default": true, "core": false},
    "spaceQrCodes": {"parent": null, "default": true, "core": true},
    "coOwner": {"parent": null, "default": true, "core": false},
    "autoCheckInOut": {"parent": null, "default": false, "core": false},
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
    "planObjectDelete": {"parent": null, "default": true, "core": true},
    "notificationGrouping": {"parent": "eventsTab", "default": true, "core": true},
    "bookingPolicies": {"parent": null, "default": true, "core": true},
    "bookingGate": {"parent": "bookingPolicies", "default": true, "core": true},
    "nfcSeatTags": {"parent": null, "default": true, "core": false},
    "qrBadges": {"parent": "kioskMode", "default": true, "core": false},
    "kioskMemberPhotos": {"parent": "kioskMode", "default": true, "core": false},
    "subscriptionInvoices": {"parent": "invoicing", "default": true, "core": false},
    "usageInvoices": {"parent": "invoicing", "default": true, "core": false},
    "invoiceSettlement": {"parent": "invoicing", "default": true, "core": false},
    "invoiceJourney": {"parent": "invoicing", "default": true, "core": false},
    "messageGestures": {"parent": null, "default": true, "core": true},
    "uniqueMonograms": {"parent": null, "default": true, "core": true},
    "planMemberPhotos": {"parent": null, "default": true, "core": false},
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
    "multiSite": {"parent": null, "default": false, "core": false},
    "siteDocuments": {"parent": "multiSite", "default": false, "core": false},
    "vatGroups": {"parent": "vatManagement", "default": false, "core": false},
    "vatRateHistory": {"parent": "vatManagement", "default": false, "core": false},
    "vatCounterparty": {"parent": "vatManagement", "default": false, "core": false},
    "environmentPairs": {"parent": null, "default": true, "core": false},
    "deployments": {"parent": "environmentPairs", "default": true, "core": false},
    "managedProfileAccess": {"parent": "managedProfiles", "default": false, "core": false},
    "seatDayTimeline": {"parent": null, "default": true, "core": true},
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
    "singleRoomLevelNames": {"parent": null, "default": true, "core": true},
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
    "placeFeedback": {"parent": null, "default": true, "core": true},
    "spaceInquiries": {"parent": null, "default": true, "core": true},
    "messageForwarding": {"parent": "memberNotifications", "default": true, "core": true},
    "captureProtection": {"parent": "memberNotifications", "default": true, "core": true},
    "holidayImport": {"parent": "publicHolidays", "default": false, "core": false},
    "capacityKpi": {"parent": null, "default": false, "core": false},
    "accountingBook": {"parent": "invoicing", "default": false, "core": false},
    "roleAssignment": {"parent": "roleManagement", "default": true, "core": true},
    "taskRecorder": {"parent": null, "default": false, "core": false},
    "guestParticipation": {"parent": null, "default": false, "core": true},
    "messageMentions": {"parent": "memberNotifications", "default": true, "core": true},
    "supplyClassification": {"parent": "vatManagement", "default": true, "core": false},
    "viesVerification": {"parent": "supplyClassification", "default": true, "core": false},
    "recapitulativeStatement": {"parent": "vatDeclarations", "default": true, "core": false, "countries": ["@eu"]},
    "inputVat": {"parent": "vatDeclarations", "default": true, "core": false},
    "configurableSettings": {"parent": null, "default": true, "core": false},
    "salesTax": {"parent": "invoicing", "default": true, "core": false},
    "meetingRooms": {"parent": null, "default": false, "core": false},
    "parking": {"parent": null, "default": false, "core": false},
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
    "bankImport": {"parent": "invoicing", "default": false, "core": false}
  }'::jsonb
$registry$;
revoke execute on function public.feature_registry() from public, anon;
grant execute on function public.feature_registry() to authenticated;

-- ── the books level of the tax process carries it (dart run tool/build_setup_steps.dart) ──
create or replace function public.setup_level_catalogue()
returns jsonb language sql immutable set search_path = public as $fn$
  select $json${"processes":[{"process":"bookings","levels":[{"level":"simple","features":["seriesBooking","bookForOthers","spaceQrCodes","workingHours","planObjectDelete","bookingPolicies","seatDayTimeline","bookingGate","calendarFileExport"],"needs":[]},{"level":"resources","features":["adminSeatBlocking","levelBooking","adminLevelAssign","multiSite","publicHolidays","holidayImport","meetingRooms","parking","externalRooms"],"needs":[]},{"level":"measured","features":["kioskMode","nfcBadges","autoCheckInOut","nfcSeatTags","qrBadges","kioskMemberPhotos","badgeSignIn","capacityKpi"],"needs":[]}]},{"process":"community","levels":[{"level":"basic","features":["calendarTab","eventsTab","pushNotifications","membersDirectory","memberNotifications","deletionRequests","roleManagement","notificationGrouping","calendarHub","richMessageRefs","personalInfo","messageGestures","calendarViews","messagesHub","memberPage","messageForwarding","captureProtection","roleAssignment","messageMentions"],"needs":[]},{"level":"organised","features":["whatsappIntegration","coOwner","validationScopes","validationChain","calendarValidations","managedProfiles","managedProfileAccess","memberOrigin","customRoles","customFields","guestParticipation"],"needs":[]}]},{"process":"money","levels":[{"level":"none","features":[],"needs":[]},{"level":"statements","features":["moneyTab","services","accessorySupplements","memberReports","dataAccessLog","financeFaces","priceNegotiations"],"needs":[]},{"level":"invoices","features":["invoicing","adminInvoicing","invoicePdfTemplate","invoiceAddressWindow","dunning","paymentReminders","usageRecords","reportDesignExchange","reportLayouts","numberSequences","workspaceStatus","memberPaymentTerms","reportTexts","usageReport","letterStandard","subscriptionInvoices","usageInvoices","invoiceSettlement","invoiceJourney","reportDesigner","invoicingWizard","settlementFold","carnets"],"needs":[]}]},{"process":"payments","levels":[{"level":"off","features":[],"needs":[]},{"level":"online","features":["onlinePayments"],"needs":[{"process":"money","level":"statements"}]}]},{"process":"tax","levels":[{"level":"none","features":[],"needs":[]},{"level":"vat","features":["vatManagement","vatDeclarations","vatGroups","vatRateHistory","vatCounterparty","vatReport","supplyClassification","viesVerification","recapitulativeStatement","inputVat","salesTax"],"needs":[{"process":"money","level":"invoices"}]},{"level":"books","features":["einvoiceCustomerDelivery","accountingBook","accountingPeriods","accountingConnectors","bankImport"],"needs":[{"process":"money","level":"invoices"}]}]},{"process":"purchases","levels":[{"level":"none","features":[],"needs":[]},{"level":"expenses","features":["supplyExpenses","expenseRepartitionWizard","scheduledExpenses","expenseRepartition"],"needs":[{"process":"money","level":"invoices"}]},{"level":"full","features":["purchases","premisesLease","assetRegister","purchaseAnalytics","foreignCurrencyPurchases"],"needs":[{"process":"money","level":"invoices"}]}]},{"process":"presentation","levels":[{"level":"basic","features":["planMemberPhotos","uniqueMonograms","singleRoomLevelNames"],"needs":[]},{"level":"branded","features":["workspaceVocabulary","workspaceBranding"],"needs":[]},{"level":"public","features":["publicListings","spaceInquiries"],"needs":[]}]},{"process":"operations","levels":[{"level":"basic","features":["pdfExport","dataExport","documents","formHelpHints","uiAnimations","regionalFormats","memberDataExport","navigationStyle","demoMode","memberAccountMenu","memberGettingStarted","placeFeedback","setupGuide","dataReport"],"needs":[]},{"level":"insight","features":["decisionSurface","biReportDesigner","workspaceOverview"],"needs":[]},{"level":"advanced","features":["environmentPairs","deployments","configurationTransfer","instanceWizard","memberEnvironments","workspaceLibrary","configurableSettings"],"needs":[]}]},{"process":"assistant","levels":[{"level":"off","features":[],"needs":[]},{"level":"on","features":["recordingPrivacy","mcpAccess","taskRecorder","webMcp"],"needs":[]}]}],"presets":[{"preset":"essentiel","levels":[{"process":"bookings","level":"simple"},{"process":"community","level":"basic"},{"process":"money","level":"statements"},{"process":"payments","level":"off"},{"process":"tax","level":"none"},{"process":"purchases","level":"none"},{"process":"presentation","level":"basic"},{"process":"operations","level":"basic"},{"process":"assistant","level":"off"}]},{"preset":"standard","levels":[{"process":"bookings","level":"resources"},{"process":"community","level":"organised"},{"process":"money","level":"invoices"},{"process":"payments","level":"off"},{"process":"tax","level":"none"},{"process":"purchases","level":"expenses"},{"process":"presentation","level":"branded"},{"process":"operations","level":"insight"},{"process":"assistant","level":"off"}]},{"preset":"complet","levels":[{"process":"bookings","level":"measured"},{"process":"community","level":"organised"},{"process":"money","level":"invoices"},{"process":"payments","level":"online"},{"process":"tax","level":"books"},{"process":"purchases","level":"full"},{"process":"presentation","level":"public"},{"process":"operations","level":"advanced"},{"process":"assistant","level":"off"}]}]}$json$::jsonb;
$fn$;
revoke execute on function public.setup_level_catalogue() from public, anon, authenticated;

-- ── settings ──────────────────────────────────────────────────────────────
-- BEGIN GENERATED SEED (dart run tool/build_settings_seed.dart)
insert into public.setting_definitions
  (key, type, default_value, min_value, max_value, unit, group_key, scopes,
   edit_permission, floor_value, editable, choices, source, note)
values
('bank.import_max_bytes', 'int', '5242880'::jsonb, 65536, 20971520, 'bytes', 'billing', array['platform'], 'workspaceSettings', null, true, null, 'bank statement import (#2380)', 'The largest bank statement file this server reads, in bytes. A larger file is refused whole before it is read, and nothing is imported.'),
('bank.import_max_lines', 'int', '5000'::jsonb, 100, 20000, 'rows', 'billing', array['platform'], 'workspaceSettings', null, true, null, 'import_bank_statement_v1 (#2380)', 'The most movements one imported bank statement may hold. The app and import_bank_statement_v1 refuse a file with more, whole; split it by period at the bank.'),
('bank.match_window_days', 'int', '60'::jsonb, 1, 366, 'days', 'billing', array['platform', 'workspace'], 'workspaceSettings', null, true, null, 'bank statement matching (#2380)', 'How many days before a movement an invoice may have been issued to be suggested for it by its amount and payer alone, when the movement carries no reference. A suggestion is always confirmed by a person.')
on conflict (key) do nothing;
-- END GENERATED SEED

-- ── the tables ────────────────────────────────────────────────────────────
create table public.bank_statements (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  format text not null check (format in ('camt053', 'camt054', 'mt940', 'coda', 'ofx', 'csv')),
  account text not null check (char_length(account) between 1 and 64),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  statement_ref text not null default '' check (char_length(statement_ref) <= 140),
  source_sha256 text not null check (source_sha256 ~ '^[0-9a-f]{64}$'),
  file_name text not null default '' check (char_length(file_name) <= 255),
  period_from date not null,
  period_to date not null,
  opening_cents bigint,
  closing_cents bigint,
  imported_by_member_id uuid references public.members(id) on delete set null,
  imported_at timestamptz not null default now(),
  check (period_to >= period_from),
  constraint bank_statements_source unique (workspace_id, source_sha256)
);
select public.ensure_system_columns('bank_statements');
create index bank_statements_account on public.bank_statements (workspace_id, account, period_from);

create table public.bank_statement_lines (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  statement_id uuid not null references public.bank_statements(id) on delete cascade,
  account text not null check (char_length(account) between 1 and 64),
  position int not null check (position >= 1),
  booking_date date not null,
  value_date date not null,
  -- ledger_entries.amount_cents is an int: a movement it cannot carry is refused
  amount_cents bigint not null check (amount_cents <> 0 and abs(amount_cents) <= 2147483647),
  currency text not null check (currency ~ '^[A-Z]{3}$'),
  transaction_id text not null default '' check (char_length(transaction_id) <= 140),
  counterparty_name text not null default '' check (char_length(counterparty_name) <= 140),
  counterparty_iban text not null default '' check (counterparty_iban ~ '^[A-Z0-9]{0,34}$'),
  reference text not null default '' check (reference ~ '^[A-Z0-9]{0,35}$'),
  end_to_end_id text not null default '' check (char_length(end_to_end_id) <= 35),
  remittance text not null default '' check (char_length(remittance) <= 1000),
  line_hash text not null check (line_hash ~ '^[0-9a-f]{64}$'),
  state text not null default 'open' check (state in ('open', 'review', 'duplicate')),
  -- the line of another statement this one looked like when it was imported
  resembles_line_id uuid references public.bank_statement_lines(id) on delete set null,
  reviewed_by_member_id uuid references public.members(id) on delete set null,
  reviewed_at timestamptz,
  payment_ledger_id uuid references public.ledger_entries(id) on delete set null,
  invoice_id uuid references public.invoices(id) on delete set null,
  outgoing_payment_id uuid references public.outgoing_payments(id) on delete set null,
  matched_by_member_id uuid references public.members(id) on delete set null,
  matched_at timestamptz,
  check (state <> 'review' or resembles_line_id is not null),
  check (payment_ledger_id is null or amount_cents > 0),
  check (outgoing_payment_id is null or amount_cents < 0),
  constraint bank_statement_lines_position unique (statement_id, position)
);
select public.ensure_system_columns('bank_statement_lines');
-- A bank's own id names one movement of one account, once.
create unique index bank_statement_lines_transaction
  on public.bank_statement_lines (workspace_id, account, transaction_id) where transaction_id <> '';
create index bank_statement_lines_hash on public.bank_statement_lines (workspace_id, account, line_hash);
create unique index bank_statement_lines_payment
  on public.bank_statement_lines (payment_ledger_id) where payment_ledger_id is not null;
create unique index bank_statement_lines_outgoing
  on public.bank_statement_lines (outgoing_payment_id) where outgoing_payment_id is not null;
create index bank_statement_lines_statement on public.bank_statement_lines (statement_id, position);

-- ── who reads them ────────────────────────────────────────────────────────
create or replace function public.bank_statement_reader(p_workspace_id uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select public.is_owner_of(p_workspace_id)
      or p_workspace_id in (select public.workspaces_permitting(array['viewFinances', 'issueInvoices']));
$fn$;
revoke execute on function public.bank_statement_reader(uuid) from public, anon;
grant execute on function public.bank_statement_reader(uuid) to authenticated;

alter table public.bank_statements enable row level security;
alter table public.bank_statement_lines enable row level security;
revoke all on public.bank_statements, public.bank_statement_lines from public, anon, authenticated;
grant select on public.bank_statements, public.bank_statement_lines to authenticated;
create policy bank_statements_select on public.bank_statements for select to authenticated
  using (public.bank_statement_reader(workspace_id));
create policy bank_statement_lines_select on public.bank_statement_lines for select to authenticated
  using (public.bank_statement_reader(workspace_id));
create policy mcp_delegated_deny on public.bank_statements as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());
create policy mcp_delegated_deny on public.bank_statement_lines as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- ── the client's doors ────────────────────────────────────────────────────
-- The active member acting in [p_workspace_id] once the flag is on and the
-- right is held ('read' = a reader of the statements); raises otherwise.
create or replace function public.bank_import_actor(p_workspace_id uuid, p_permission text)
returns uuid language plpgsql stable security definer set search_path = public as $fn$
declare
  v_me uuid;
begin
  if auth.uid() is null then raise exception 'not signed in' using errcode = '42501'; end if;
  if public.mcp_is_delegated() then
    raise exception 'an assistant may not do this for the bank statements' using errcode = '42501';
  end if;
  select m.id into v_me from public.members m
   where m.workspace_id = p_workspace_id and m.user_id = auth.uid() and m.status = 'active';
  if v_me is null then raise exception 'not an active member' using errcode = '42501'; end if;
  if not public.feature_effective(p_workspace_id, 'bankImport') then
    raise exception 'bank statements are switched off in this space' using errcode = '0A000';
  end if;
  if p_permission = 'read' then
    if not public.bank_statement_reader(p_workspace_id) then
      raise exception 'you may not read the bank statements' using errcode = '42501';
    end if;
  elsif not public.has_permission(p_workspace_id, p_permission) then
    raise exception 'you may not do this for the bank statements' using errcode = '42501';
  end if;
  return v_me;
end;
$fn$;
revoke execute on function public.bank_import_actor(uuid, text) from public, anon, authenticated;

-- The financial fields of a movement, as one digest: what two copies of the
-- same movement share. It flags a resemblance; it never decides one.
create or replace function public.bank_line_hash(
  p_account text, p_booking date, p_value date, p_amount bigint, p_currency text,
  p_reference text, p_end_to_end text, p_iban text, p_remittance text)
returns text language sql immutable set search_path = public as $fn$
  select encode(sha256(convert_to(concat_ws('|', p_account, p_booking::text, p_value::text,
    p_amount::text, p_currency, p_reference, p_end_to_end, p_iban, p_remittance), 'UTF8')), 'hex');
$fn$;
revoke execute on function public.bank_line_hash(text, date, date, bigint, text, text, text, text, text)
  from public, anon, authenticated;

-- ── import ────────────────────────────────────────────────────────────────
-- [p_statement]: format, account, currency, statement_ref, source_sha256,
-- file_name, opening_cents, closing_cents. [p_lines]: the parsed movements
-- (BankLine.toJson). Answers the statement id and what became of the lines.
create or replace function public.import_bank_statement_v1(
  p_workspace_id uuid, p_statement jsonb, p_lines jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_me uuid;
  v_max int;
  v_n int;
  v_existing uuid;
  v_id uuid;
  v_account text := upper(btrim(coalesce(p_statement ->> 'account', '')));
  v_currency text := coalesce(p_statement ->> 'currency', '');
  v_sha text := coalesce(p_statement ->> 'source_sha256', '');
  v_line jsonb;
  v_pos int := 0;
  v_booking date;
  v_value date;
  v_amount bigint;
  v_tx text;
  v_hash text;
  v_like uuid;
  v_created int := 0;
  v_known int := 0;
  v_review int := 0;
begin
  v_me := public.bank_import_actor(p_workspace_id, 'issueInvoices');
  if jsonb_typeof(p_lines) is distinct from 'array' then
    raise exception 'the statement has no movements' using errcode = '22023';
  end if;
  v_n := jsonb_array_length(p_lines);
  v_max := (public.setting_value(p_workspace_id, 'bank.import_max_lines') #>> '{}')::int;
  if v_n = 0 then raise exception 'the statement has no movements' using errcode = '22023'; end if;
  if v_n > v_max then
    raise exception 'the statement has % movements, more than the % one import takes', v_n, v_max
      using errcode = '22023';
  end if;
  if v_sha !~ '^[0-9a-f]{64}$' then raise exception 'the file digest is not a sha256' using errcode = '22023'; end if;
  if v_currency !~ '^[A-Z]{3}$' then raise exception 'the statement names no currency' using errcode = '22023'; end if;
  if v_account = '' then raise exception 'the statement names no account' using errcode = '22023'; end if;

  -- One import per account at a time: the bank ids and the resemblances are
  -- read and written under the same lock.
  perform pg_advisory_xact_lock(hashtext('bank_statement:' || p_workspace_id::text || ':' || v_account));

  select s.id into v_existing from public.bank_statements s
   where s.workspace_id = p_workspace_id and s.source_sha256 = v_sha;
  if v_existing is not null then
    return jsonb_build_object('statement_id', v_existing, 'repeated', true,
      'created', 0, 'known', v_n, 'review', 0);
  end if;

  insert into public.bank_statements
    (workspace_id, format, account, currency, statement_ref, source_sha256, file_name,
     period_from, period_to, opening_cents, closing_cents, imported_by_member_id)
  select p_workspace_id, p_statement ->> 'format', v_account, v_currency,
         coalesce(p_statement ->> 'statement_ref', ''), v_sha,
         left(coalesce(p_statement ->> 'file_name', ''), 255),
         min((l ->> 'booking_date')::date), max((l ->> 'booking_date')::date),
         (p_statement ->> 'opening_cents')::bigint, (p_statement ->> 'closing_cents')::bigint, v_me
    from jsonb_array_elements(p_lines) l
  returning id into v_id;

  for v_line in select value from jsonb_array_elements(p_lines) loop
    v_pos := v_pos + 1;
    if coalesce(v_line ->> 'currency', '') <> v_currency then
      raise exception 'movement % is in another currency than its statement', v_pos using errcode = '22023';
    end if;
    v_booking := (v_line ->> 'booking_date')::date;
    v_value := coalesce((v_line ->> 'value_date')::date, v_booking);
    v_amount := (v_line ->> 'amount_cents')::bigint;
    v_tx := btrim(coalesce(v_line ->> 'transaction_id', ''));
    if v_tx <> '' and exists (
      select 1 from public.bank_statement_lines b
       where b.workspace_id = p_workspace_id and b.account = v_account and b.transaction_id = v_tx) then
      v_known := v_known + 1;
      continue;
    end if;
    v_hash := public.bank_line_hash(v_account, v_booking, v_value, v_amount, v_currency,
      coalesce(v_line ->> 'reference', ''), coalesce(v_line ->> 'end_to_end_id', ''),
      coalesce(v_line ->> 'counterparty_iban', ''), coalesce(v_line ->> 'remittance', ''));
    v_like := null;
    if v_tx = '' then
      select b.id into v_like from public.bank_statement_lines b
       where b.workspace_id = p_workspace_id and b.account = v_account
         and b.line_hash = v_hash and b.statement_id <> v_id
       order by b.created_datetime limit 1;
    end if;
    insert into public.bank_statement_lines
      (workspace_id, statement_id, account, position, booking_date, value_date, amount_cents,
       currency, transaction_id, counterparty_name, counterparty_iban, reference,
       end_to_end_id, remittance, line_hash, state, resembles_line_id)
    values
      (p_workspace_id, v_id, v_account, v_pos, v_booking, v_value, v_amount, v_currency, v_tx,
       coalesce(v_line ->> 'counterparty_name', ''), coalesce(v_line ->> 'counterparty_iban', ''),
       coalesce(v_line ->> 'reference', ''), coalesce(v_line ->> 'end_to_end_id', ''),
       coalesce(v_line ->> 'remittance', ''), v_hash,
       case when v_like is null then 'open' else 'review' end, v_like);
    if v_like is null then v_created := v_created + 1; else v_review := v_review + 1; end if;
  end loop;

  return jsonb_build_object('statement_id', v_id, 'repeated', false,
    'created', v_created, 'known', v_known, 'review', v_review);
end;
$fn$;
revoke execute on function public.import_bank_statement_v1(uuid, jsonb, jsonb) from public, anon;
grant execute on function public.import_bank_statement_v1(uuid, jsonb, jsonb) to authenticated;

-- ── reads ─────────────────────────────────────────────────────────────────
-- Where a movement stands: reconciled (money out, with its reported payment),
-- matched or pending (its payment settles an invoice, confirmed or awaiting
-- the validators), recorded (its payment exists and settles nothing yet),
-- else its own state (open, review, duplicate).
create or replace function public.bank_line_status(l public.bank_statement_lines)
returns text language sql stable security definer set search_path = public as $fn$
  select case
    when l.outgoing_payment_id is not null then 'reconciled'
    when l.payment_ledger_id is not null then coalesce(
      (select case when e.status = 'pending' then 'pending' else 'matched' end
         from public.invoice_match_payments imp
         left join public.events e on e.id = imp.event_id
        where imp.payment_ledger_id = l.payment_ledger_id), 'recorded')
    else l.state end;
$fn$;
revoke execute on function public.bank_line_status(public.bank_statement_lines) from public, anon, authenticated;

create or replace function public.bank_statements_v1(p_workspace_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
begin
  perform public.bank_import_actor(p_workspace_id, 'read');
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', s.id, 'format', s.format, 'account', s.account, 'currency', s.currency,
      'statement_ref', s.statement_ref, 'file_name', s.file_name,
      'period_from', s.period_from, 'period_to', s.period_to,
      'opening_cents', s.opening_cents, 'closing_cents', s.closing_cents,
      'imported_at', s.imported_at,
      'lines', (select count(*) from public.bank_statement_lines l where l.statement_id = s.id),
      'open', (select count(*) from public.bank_statement_lines l
                where l.statement_id = s.id
                  and public.bank_line_status(l) in ('open', 'review', 'recorded')))
      order by s.period_to desc, s.imported_at desc)
      from public.bank_statements s where s.workspace_id = p_workspace_id), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.bank_statements_v1(uuid) from public, anon;
grant execute on function public.bank_statements_v1(uuid) to authenticated;

-- The movements of one statement, each with where it stands, the invoice
-- it settles, and for money out still open the reported payments of the
-- same amount and currency it may reconcile.
create or replace function public.bank_statement_lines_v1(p_statement_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $fn$
declare
  v_ws uuid;
begin
  select s.workspace_id into v_ws from public.bank_statements s where s.id = p_statement_id;
  if v_ws is null then raise exception 'unknown statement' using errcode = '22023'; end if;
  perform public.bank_import_actor(v_ws, 'read');
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', l.id, 'position', l.position, 'booking_date', l.booking_date,
      'value_date', l.value_date, 'amount_cents', l.amount_cents, 'currency', l.currency,
      'transaction_id', l.transaction_id, 'counterparty_name', l.counterparty_name,
      'counterparty_iban', l.counterparty_iban, 'reference', l.reference,
      'end_to_end_id', l.end_to_end_id, 'remittance', l.remittance,
      'status', public.bank_line_status(l),
      'resembles_line_id', l.resembles_line_id,
      'invoice_id', l.invoice_id,
      'invoice_number', (select i.number from public.invoices i where i.id = l.invoice_id),
      'outgoing_candidates', case
        when l.amount_cents < 0 and l.outgoing_payment_id is null and l.state = 'open' then
          coalesce((select jsonb_agg(jsonb_build_object(
                     'id', p.id, 'amount_cents', p.amount_cents, 'paid_on', p.reported_paid_on,
                     'reference', p.reference,
                     'payee', coalesce(
                        (select pr.display_name from public.members m
                           join public.profiles pr on pr.id = m.user_id
                          where m.id = p.payee_member_id),
                        (select su.name from public.suppliers su where su.id = p.payee_supplier_id), ''))
                     order by p.reported_paid_on desc)
                     from public.outgoing_payments p
                    where p.workspace_id = l.workspace_id and p.state = 'reported'
                      and p.currency = l.currency and p.amount_cents = -l.amount_cents), '[]'::jsonb)
        else '[]'::jsonb end)
      order by l.position)
      from public.bank_statement_lines l where l.statement_id = p_statement_id), '[]'::jsonb);
end;
$fn$;
revoke execute on function public.bank_statement_lines_v1(uuid) from public, anon;
grant execute on function public.bank_statement_lines_v1(uuid) to authenticated;

-- ── a person's decisions ──────────────────────────────────────────────────
-- A movement that resembled another statement's: a second genuine movement
-- (kept, open) or the same one read twice (duplicate, settles nothing).
create or replace function public.review_bank_line_v1(p_line_id uuid, p_duplicate boolean)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_line public.bank_statement_lines;
  v_me uuid;
begin
  select * into v_line from public.bank_statement_lines where id = p_line_id for update;
  if v_line.id is null then raise exception 'unknown bank line' using errcode = '22023'; end if;
  v_me := public.bank_import_actor(v_line.workspace_id, 'issueInvoices');
  if v_line.state <> 'review' then
    raise exception 'this movement is not waiting for a review' using errcode = '22023';
  end if;
  update public.bank_statement_lines
     set state = case when p_duplicate then 'duplicate' else 'open' end,
         reviewed_by_member_id = v_me, reviewed_at = now()
   where id = p_line_id
  returning * into v_line;
  return jsonb_build_object('id', v_line.id, 'status', public.bank_line_status(v_line));
end;
$fn$;
revoke execute on function public.review_bank_line_v1(uuid, boolean) from public, anon;
grant execute on function public.review_bank_line_v1(uuid, boolean) to authenticated;

-- Money in confirmed against an invoice: one payment credit of the
-- invoice's member on the value day (created once, reused when a rejected
-- match is tried again), then match_invoice with the person's resolution.
create or replace function public.match_bank_line_v1(
  p_line_id uuid, p_invoice_id uuid, p_resolution text, p_note text default '')
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_line public.bank_statement_lines;
  v_invoice public.invoices;
  v_me uuid;
  v_ledger uuid;
  v_ledger_member uuid;
begin
  select * into v_line from public.bank_statement_lines where id = p_line_id for update;
  if v_line.id is null then raise exception 'unknown bank line' using errcode = '22023'; end if;
  v_me := public.bank_import_actor(v_line.workspace_id, 'issueInvoices');
  if v_line.state = 'review' then
    raise exception 'this movement resembles another statement''s: review it first' using errcode = '22023';
  end if;
  if v_line.state = 'duplicate' then
    raise exception 'a duplicate movement settles nothing' using errcode = '22023';
  end if;
  if v_line.amount_cents <= 0 then
    raise exception 'money out settles no invoice' using errcode = '22023';
  end if;
  if public.bank_line_status(v_line) in ('matched', 'pending') then
    raise exception 'this movement already settles an invoice' using errcode = '22023';
  end if;
  -- The invoice is locked too: two movements confirmed against it at once
  -- are measured one after the other against what is still due.
  select * into v_invoice from public.invoices where id = p_invoice_id for update;
  if v_invoice.id is null or v_invoice.workspace_id <> v_line.workspace_id then
    raise exception 'unknown invoice' using errcode = '22023';
  end if;
  if v_invoice.currency <> v_line.currency then
    raise exception 'the invoice is in another currency than the movement' using errcode = '22023';
  end if;
  v_ledger := v_line.payment_ledger_id;
  if v_ledger is null then
    insert into public.ledger_entries
      (workspace_id, member_id, kind, category, amount_cents, description, period, occurred_on)
    values
      (v_line.workspace_id, v_invoice.member_id, 'credit', 'payment', v_line.amount_cents::int,
       left(coalesce(nullif(v_line.reference, ''), nullif(v_line.end_to_end_id, ''),
                     nullif(v_line.remittance, ''), v_line.transaction_id), 200),
       to_char(v_line.value_date, 'YYYY-MM'), v_line.value_date)
    returning id into v_ledger;
  else
    select member_id into v_ledger_member from public.ledger_entries where id = v_ledger;
    if v_ledger_member is distinct from v_invoice.member_id then
      raise exception 'this movement is recorded as another member''s payment' using errcode = '22023';
    end if;
  end if;
  update public.bank_statement_lines
     set payment_ledger_id = v_ledger, invoice_id = p_invoice_id,
         matched_by_member_id = v_me, matched_at = now()
   where id = p_line_id;
  perform public.match_invoice(p_invoice_id, v_ledger, p_resolution, coalesce(p_note, ''));
  select * into v_line from public.bank_statement_lines where id = p_line_id;
  return jsonb_build_object('id', v_line.id, 'invoice_id', p_invoice_id,
    'payment_ledger_id', v_ledger, 'status', public.bank_line_status(v_line));
end;
$fn$;
revoke execute on function public.match_bank_line_v1(uuid, uuid, text, text) from public, anon;
grant execute on function public.match_bank_line_v1(uuid, uuid, text, text) to authenticated;

-- Money out confirmed against a payment reported as made: the payment is
-- reconciled with the bank's days; nothing else is created.
create or replace function public.reconcile_bank_line_out_v1(p_line_id uuid, p_outgoing_payment_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $fn$
declare
  v_line public.bank_statement_lines;
  v_pay public.outgoing_payments;
  v_me uuid;
begin
  select * into v_line from public.bank_statement_lines where id = p_line_id for update;
  if v_line.id is null then raise exception 'unknown bank line' using errcode = '22023'; end if;
  v_me := public.bank_import_actor(v_line.workspace_id, 'recordOutgoingPayments');
  if v_line.state <> 'open' then
    raise exception 'this movement is not open' using errcode = '22023';
  end if;
  if v_line.amount_cents >= 0 then
    raise exception 'money in reconciles no payment out' using errcode = '22023';
  end if;
  if v_line.outgoing_payment_id is not null then
    raise exception 'this movement already reconciles a payment' using errcode = '22023';
  end if;
  select * into v_pay from public.outgoing_payments where id = p_outgoing_payment_id for update;
  if v_pay.id is null or v_pay.workspace_id <> v_line.workspace_id then
    raise exception 'unknown outgoing payment' using errcode = '22023';
  end if;
  if v_pay.state <> 'reported' then
    raise exception 'only a payment reported as made is reconciled' using errcode = '22023';
  end if;
  if v_pay.currency <> v_line.currency or v_pay.amount_cents <> -v_line.amount_cents then
    raise exception 'the payment and the movement differ in amount or currency' using errcode = '22023';
  end if;
  update public.bank_statement_lines
     set outgoing_payment_id = v_pay.id, matched_by_member_id = v_me, matched_at = now()
   where id = p_line_id
  returning * into v_line;
  update public.outgoing_payments
     set state = 'reconciled', booking_date = v_line.booking_date, value_date = v_line.value_date
   where id = v_pay.id;
  return jsonb_build_object('id', v_line.id, 'outgoing_payment_id', v_pay.id,
    'status', public.bank_line_status(v_line));
end;
$fn$;
revoke execute on function public.reconcile_bank_line_out_v1(uuid, uuid) from public, anon;
grant execute on function public.reconcile_bank_line_out_v1(uuid, uuid) to authenticated;

-- ── a reported payment is reconciled only by a bank line ──────────────────
-- 0467's guard, restated whole; the one change: reported → reconciled is
-- allowed when a bank statement line names the payment.
create or replace function public.outgoing_payments_guard()
returns trigger language plpgsql as $fn$
begin
  if tg_op = 'DELETE' then
    raise exception 'an outgoing payment is never removed; reverse it';
  end if;
  if new.workspace_id is distinct from old.workspace_id
     or new.payee_kind is distinct from old.payee_kind
     or new.payee_member_id is distinct from old.payee_member_id
     or new.payee_supplier_id is distinct from old.payee_supplier_id
     or new.currency is distinct from old.currency
     or new.amount_cents is distinct from old.amount_cents
     or new.method is distinct from old.method
     or new.reported_paid_on is distinct from old.reported_paid_on
     or new.reference is distinct from old.reference
     or new.actor_member_id is distinct from old.actor_member_id
     or new.request_id is distinct from old.request_id then
    raise exception 'an outgoing payment keeps what was reported';
  end if;
  if new.state is distinct from old.state
     and not (old.state = 'reported' and new.state = 'reversed')
     and not (old.state = 'reported' and new.state = 'reconciled'
              and exists (select 1 from public.bank_statement_lines b
                           where b.outgoing_payment_id = new.id)) then
    raise exception 'an outgoing payment moves only from reported to reversed, or to reconciled by a bank line';
  end if;
  return new;
end;
$fn$;
revoke execute on function public.outgoing_payments_guard() from public, anon, authenticated;

notify pgrst, 'reload schema';

select public.set_deskilo_schema_version(603);
