// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4168 -- the direct entries of a business that sells services: its customers,
// its quotes, its invoices, a new invoice for a customer. One rule says when each
// is offered, for the menu and for the overview that opens a business without
// places: a feature that is on and a right the page itself asks.
import 'workspace_feature.dart';
import 'workspace_permission.dart';

enum BusinessEntry { newInvoice, quotes, customers, invoices }

/// The entries [features] and [permissions] offer, in the order they are read.
List<BusinessEntry> businessEntriesFor(
  Set<WorkspaceFeature> features,
  Set<WorkspacePermission> permissions,
) {
  bool may(WorkspacePermission p) => permissions.contains(p);
  final sales = features.contains(WorkspaceFeature.invoicing);
  final reads = may(WorkspacePermission.viewFinances) || may(WorkspacePermission.issueInvoices);
  return [
    if (sales &&
        features.contains(WorkspaceFeature.moneyTab) &&
        features.contains(WorkspaceFeature.standaloneInvoicing) &&
        may(WorkspacePermission.issueInvoices))
      BusinessEntry.newInvoice,
    if (sales && features.contains(WorkspaceFeature.customerQuotes) && reads) BusinessEntry.quotes,
    if (sales &&
        features.contains(WorkspaceFeature.billingCustomers) &&
        (may(WorkspacePermission.manageBillingCustomers) || reads))
      BusinessEntry.customers,
    if (sales && features.contains(WorkspaceFeature.moneyTab) && reads) BusinessEntry.invoices,
  ];
}
