// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2495 — what the money feature caches, by table. Composed in
// lib/app/realtime_invalidations.dart.
import '../../../core/realtime/invalidation_registry.dart';
import 'money_providers.dart';
import 'purchase_approval_provider.dart';

final moneyInvalidations = [
  // Membership/feature changes and the existing resume resync clear both
  // the count and any open decision detail. No purchase-table feed is assumed.
  InvalidationContribution(const ['members', 'workspaces'], [
    purchaseApprovalPageProvider,
    purchaseApprovalDetailProvider,
  ]),
  InvalidationContribution(
    const ['ledger_entries', 'payment_intents', 'quota_extensions'],
    [
      myStatementProvider,
      myLedgerProvider,
      // #512 — every money change can move the cross-month position.
      myAccountProvider,
    ],
  ),
  InvalidationContribution(const ['invoices'], [invoicesProvider]),
  InvalidationContribution(
    const ['services'],
    [servicesProvider, allServicesProvider],
  ),
  InvalidationContribution(const ['fee_bands'], [feeBandsProvider]),
  InvalidationContribution(
    const ['packages'],
    [packagesProvider, allPackagesProvider],
  ),
  // A workspaces-row change reaches the money settings derived from it.
  InvalidationContribution(
    const ['workspaces'],
    [invoicePdfTemplateProvider, dunningRulesProvider],
  ),
];
