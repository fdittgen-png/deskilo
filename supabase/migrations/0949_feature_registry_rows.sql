-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- apps: additive
-- (the feature registry changes from a function body to rows read by the same function; the answer is unchanged; four
-- immutable readers become stable)
--
-- #4396 -- the feature registry is ROWS. `feature_registry()` was restated whole by every migration that added a
-- feature (13 times in one week, 169 to 182 lines each, for a net change of a few lines). It is now a reader of
-- `feature_registry_entries`, filled by this migration from the manifest (`dart run tool/build_feature_registry_sql.dart`),
-- and never restated again: a lane that adds a feature carries the one row it adds, between the same markers
-- (feature_registry_sql_test accumulates every block, in migration order, and requires the manifest).
--
--   * `feature_registry_entries(feature_key, parent, default_on, core, countries)`: global configuration, readable by
--     every signed-in role, written only by migrations. `countries` is null for a feature offered everywhere.
--   * `feature_registry()` answers the same jsonb as before (`{key: {parent, default, core[, countries]}}`); it is
--     `stable`, not `immutable`: it reads a table. It runs with the caller's rights (no new definer function): a
--     signed-in role reads the rows under the table's select policy, and the server functions that call it run with
--     their owner's rights as before. A delegated assistant session that called it directly would meet the table's
--     restrictive delegated policy and read an empty registry -- every feature off, which is the safe way to fail.
--   * the functions that call it and were declared `immutable` (`feature_raw`, `feature_effective_in`,
--     `resolved_feature_flags`, `imported_feature_flags`) are declared `stable` too: an immutable function over a
--     stable one could keep a folded answer in a cached plan after a later migration adds a row. None of them is in an
--     index, a default, a generated column, a constraint or a policy (checked on the dev project).

create table public.feature_registry_entries (
  feature_key text primary key check (feature_key ~ '^[A-Za-z][A-Za-z0-9]*$'),
  parent text check (parent is null or parent <> feature_key),
  default_on boolean not null,
  core boolean not null,
  countries text[] check (countries is null or cardinality(countries) > 0)
);
select public.ensure_system_columns('feature_registry_entries');
alter table public.feature_registry_entries enable row level security;
revoke all on table public.feature_registry_entries from public, anon, authenticated;
grant select on table public.feature_registry_entries to authenticated;
create policy feature_registry_entries_select on public.feature_registry_entries for select to authenticated using (true);
create policy mcp_delegated_deny on public.feature_registry_entries as restrictive for all to authenticated
  using (not public.mcp_is_delegated()) with check (not public.mcp_is_delegated());

-- BEGIN FEATURE REGISTRY ROWS (dart run tool/build_feature_registry_sql.dart)
insert into public.feature_registry_entries (feature_key, parent, default_on, core, countries) values
('calendarTab', null, true, true, null),
('eventsTab', null, true, true, null),
('moneyTab', null, true, true, null),
('services', 'moneyTab', true, true, null),
('accessorySupplements', 'moneyTab', false, false, null),
('onlinePayments', 'moneyTab', false, false, null),
('invoicing', 'moneyTab', true, true, null),
('adminInvoicing', 'invoicing', false, false, null),
('pdfExport', null, true, true, null),
('seriesBooking', null, true, true, null),
('bookForOthers', null, true, true, null),
('pushNotifications', null, true, true, null),
('adminSeatBlocking', 'placeBooking', false, false, null),
('levelBooking', 'placeBooking', false, false, null),
('adminLevelAssign', 'levelBooking', false, false, null),
('kioskMode', 'placeBooking', true, false, null),
('nfcBadges', 'kioskMode', true, false, null),
('membersDirectory', null, true, true, null),
('whatsappIntegration', 'membersDirectory', true, false, null),
('spaceQrCodes', 'placeBooking', true, true, null),
('coOwner', null, true, false, null),
('autoCheckInOut', 'placeBooking', false, false, null),
('dataExport', null, true, true, null),
('workingHours', null, true, true, null),
('invoicePdfTemplate', 'invoicing', true, false, null),
('invoiceAddressWindow', 'invoicing', true, false, null),
('memberNotifications', null, true, true, null),
('documents', null, true, true, null),
('dunning', 'invoicing', true, false, null),
('memberReports', 'moneyTab', true, false, null),
('deletionRequests', null, true, true, null),
('roleManagement', null, true, true, null),
('vatManagement', 'invoicing', true, false, null),
('vatDeclarations', 'vatManagement', true, false, null),
('einvoiceCustomerDelivery', 'invoicing', true, false, null),
('planObjectDelete', 'placeBooking', true, true, null),
('notificationGrouping', 'eventsTab', true, true, null),
('bookingPolicies', null, true, true, null),
('bookingGate', 'bookingPolicies', true, true, null),
('nfcSeatTags', 'placeBooking', true, false, null),
('qrBadges', 'kioskMode', true, false, null),
('kioskMemberPhotos', 'kioskMode', true, false, null),
('subscriptionInvoices', 'invoicing', true, false, null),
('usageInvoices', 'invoicing', true, false, null),
('invoiceSettlement', 'invoicing', true, false, null),
('invoiceJourney', 'invoicing', true, false, null),
('messageGestures', null, true, true, null),
('uniqueMonograms', null, true, true, null),
('planMemberPhotos', 'placeBooking', true, false, null),
('regionalFormats', null, true, true, null),
('calendarHub', 'calendarTab', true, true, null),
('calendarViews', 'calendarHub', true, true, null),
('messagesHub', null, true, true, null),
('reportDesigner', 'invoicePdfTemplate', true, false, null),
('memberPage', 'membersDirectory', true, true, null),
('invoicingWizard', 'invoicing', true, false, null),
('expenseRepartition', 'invoicing', true, false, null),
('settlementFold', 'invoiceSettlement', true, false, null),
('configurationTransfer', 'dataExport', true, false, null),
('navigationStyle', null, true, true, null),
('demoMode', null, true, false, null),
('instanceWizard', null, true, false, null),
('dataAccessLog', 'moneyTab', true, false, null),
('memberDataExport', null, true, true, null),
('financeFaces', 'moneyTab', true, true, null),
('paymentReminders', 'dunning', true, false, null),
('supplyExpenses', 'services', true, false, null),
('validationScopes', null, true, false, null),
('validationChain', null, true, false, null),
('richMessageRefs', 'memberNotifications', true, true, null),
('calendarValidations', 'calendarHub', true, false, null),
('usageRecords', 'invoicing', true, false, null),
('reportDesignExchange', 'reportDesigner', true, false, null),
('reportLayouts', 'reportDesigner', true, false, null),
('personalInfo', null, true, true, null),
('managedProfiles', 'membersDirectory', true, false, null),
('numberSequences', 'invoicing', false, false, null),
('workspaceStatus', 'invoicing', false, false, null),
('expenseRepartitionWizard', 'expenseRepartition', false, false, null),
('multiSite', 'placeBooking', false, false, null),
('vatGroups', 'vatManagement', false, false, null),
('vatRateHistory', 'vatManagement', false, false, null),
('vatCounterparty', 'vatManagement', false, false, null),
('environmentPairs', null, true, false, null),
('deployments', 'environmentPairs', true, false, null),
('managedProfileAccess', 'managedProfiles', false, false, null),
('seatDayTimeline', 'placeBooking', true, true, null),
('memberPaymentTerms', 'invoicing', true, false, null),
('usageReport', 'usageRecords', true, false, null),
('reportTexts', 'reportDesigner', true, false, null),
('letterStandard', 'reportLayouts', true, false, null),
('vatReport', 'vatDeclarations', true, false, null),
('priceNegotiations', 'moneyTab', true, false, null),
('scheduledExpenses', 'moneyTab', true, false, null),
('badgeSignIn', 'nfcBadges', false, false, null),
('formHelpHints', null, true, true, null),
('uiAnimations', null, true, true, null),
('memberOrigin', 'membersDirectory', false, false, null),
('memberEnvironments', 'environmentPairs', false, false, null),
('workspaceLibrary', null, false, false, null),
('singleRoomLevelNames', 'placeBooking', true, true, null),
('publicHolidays', null, false, false, null),
('workspaceVocabulary', null, false, false, null),
('carnets', 'invoicing', false, false, null),
('publicListings', null, false, true, null),
('workspaceBranding', null, false, false, null),
('customRoles', null, false, false, null),
('customFields', null, false, false, null),
('decisionSurface', null, false, false, null),
('recordingPrivacy', null, false, false, null),
('memberAccountMenu', null, false, false, null),
('mcpAccess', null, false, false, null),
('calendarFileExport', null, true, true, null),
('memberGettingStarted', null, true, true, null),
('placeFeedback', 'placeBooking', true, true, null),
('spaceInquiries', null, true, true, null),
('messageForwarding', 'memberNotifications', true, true, null),
('captureProtection', 'memberNotifications', true, true, null),
('holidayImport', 'publicHolidays', false, false, null),
('capacityKpi', 'placeBooking', false, false, null),
('accountingBook', 'invoicing', false, false, null),
('roleAssignment', 'roleManagement', true, true, null),
('taskRecorder', null, false, false, null),
('guestParticipation', 'placeBooking', false, true, null),
('messageMentions', 'memberNotifications', true, true, null),
('supplyClassification', 'vatManagement', true, false, null),
('viesVerification', 'supplyClassification', true, false, null),
('recapitulativeStatement', 'vatDeclarations', true, false, array['@eu']),
('inputVat', 'vatDeclarations', true, false, null),
('configurableSettings', null, true, false, null),
('salesTax', 'invoicing', true, false, null),
('meetingRooms', 'placeBooking', false, false, null),
('parking', 'placeBooking', false, false, null),
('webMcp', 'mcpAccess', false, false, null),
('purchases', 'moneyTab', false, false, null),
('premisesLease', 'scheduledExpenses', false, false, null),
('assetRegister', 'purchases', false, false, null),
('externalRooms', 'levelBooking', false, false, null),
('accountingPeriods', 'accountingBook', false, false, null),
('biReportDesigner', null, false, false, null),
('purchaseAnalytics', 'purchases', false, false, null),
('workspaceOverview', null, false, false, null),
('setupGuide', null, true, true, null),
('dataReport', 'dataExport', true, true, null),
('personalShell', null, false, false, null),
('foreignCurrencyPurchases', 'purchases', false, false, null),
('accountingConnectors', 'accountingBook', false, false, null),
('bankImport', 'invoicing', false, false, null),
('planDecor', 'placeBooking', true, true, null),
('mtdSubmission', 'vatDeclarations', false, false, array['GB']),
('purchaseOrders', 'purchases', false, false, null),
('guestPasses', 'invoicing', false, false, null),
('placeBooking', null, true, true, null),
('reminderEmail', 'dunning', false, false, null),
('invoiceEmail', 'invoicing', false, false, null),
('standaloneInvoicing', 'invoicing', false, false, null),
('kioskEnrolment', 'kioskMode', true, false, null),
('quickSearch', null, true, true, null),
('stockManagement', 'services', false, false, null),
('stockLots', 'stockManagement', false, false, null),
('stockReceiving', 'stockManagement', false, false, null),
('stockTakeOut', 'stockManagement', false, false, null),
('stockReorder', 'stockManagement', false, false, null),
('stockReturns', 'stockManagement', false, false, null),
('stockCounts', 'stockManagement', false, false, null),
('stockCycleCounts', 'stockCounts', false, false, null),
('stockItemGroups', 'stockManagement', false, false, null),
('stockTags', 'stockManagement', false, false, null),
('stockScanning', 'stockManagement', false, false, null),
('counterReceipts', 'standaloneInvoicing', false, false, null),
('counterTillSessions', 'counterReceipts', false, false, null),
('stockTagReads', 'stockTags', false, false, null),
('stockExpiryReport', 'stockManagement', false, false, null),
('stockHandlingUnits', 'stockManagement', false, false, null),
('counterOfflineCash', 'counterTillSessions', false, false, null),
('organisation', null, true, true, null),
('billingCustomers', 'invoicing', false, false, null),
('customerQuotes', 'invoicing', false, false, null),
('serviceFulfilment', 'billingCustomers', false, false, null)
on conflict (feature_key) do update set parent = excluded.parent, default_on = excluded.default_on, core = excluded.core, countries = excluded.countries;
-- END FEATURE REGISTRY ROWS

-- restates 0936 (the last body of the registry): the same answer, read from the rows
create or replace function public.feature_registry()
returns jsonb
language sql
stable
set search_path = public
as $registry$
  select coalesce(jsonb_object_agg(e.feature_key,
           jsonb_build_object('parent', e.parent, 'default', e.default_on, 'core', e.core)
           || case when e.countries is null then '{}'::jsonb else jsonb_build_object('countries', to_jsonb(e.countries)) end),
         '{}'::jsonb)
    from public.feature_registry_entries e
$registry$;
revoke execute on function public.feature_registry() from public, anon;
grant execute on function public.feature_registry() to authenticated;

-- every immutable function that reads the registry, directly or through another, is declared stable
do $stable$
declare
  r record;
  v_changed boolean := true;
  v_names text[] := array['feature_registry'];
begin
  while v_changed loop
    v_changed := false;
    for r in
      select p.oid::regprocedure::text sig, p.proname
        from pg_proc p join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'public' and p.provolatile = 'i'
         and exists (select 1 from unnest(v_names) f where p.prosrc ~ ('\m' || f || '\('))
    loop
      execute format('alter function %s stable', r.sig);
      v_names := v_names || r.proname;
      v_changed := true;
    end loop;
  end loop;
end
$stable$;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(949);
