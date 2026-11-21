// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3614 — the sales hub's links, as entries of the Sales group: the guest
// passes and the register, each asking what its page asks.
import 'package:flutter/material.dart';

import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/domain/workspace_permission.dart';
import 'shell_drawer_entries.dart';

/// The Sales group's entries beside the invoices.
extension SalesEntries on DrawerEntries {
  /// The guest passes and the invoice register.
  List<DrawerEntry> salesPages() {
    final sales = features.contains(WorkspaceFeature.invoicing);
    return <DrawerEntry>[
      // #3863 — a pass is a day at a place: the entry asks what its route
      // asks, the places too.
      if (features.contains(WorkspaceFeature.placeBooking) &&
          features.contains(WorkspaceFeature.guestPasses) &&
          (may(WorkspacePermission.issueInvoices) ||
              may(WorkspacePermission.manageServices)))
        DrawerEntry(
          'drawer-guest-passes',
          Icons.confirmation_number_outlined,
          l10n.guestPassesTitle,
          () => go('/money/guest-passes'),
          route: '/money/guest-passes',
        ),
      if (sales &&
          (may(WorkspacePermission.viewFinances) ||
              may(WorkspacePermission.issueInvoices)))
        DrawerEntry(
          'drawer-invoice-register',
          Icons.table_rows_outlined,
          l10n.invoiceRegisterTitle,
          () => go('/invoice-register'),
          route: '/invoice-register',
        ),
      // #4166 — the quotes: an offer to a billing customer before an invoice.
      if (sales &&
          features.contains(WorkspaceFeature.customerQuotes) &&
          (may(WorkspacePermission.viewFinances) ||
              may(WorkspacePermission.issueInvoices)))
        DrawerEntry(
          'drawer-quotes',
          Icons.request_quote_outlined,
          l10n.quotesTitle,
          () => go('/money/quotes'),
          route: '/money/quotes',
        ),
      // #4178 — the services ordered, followed ordered, started, done.
      if (sales &&
          features.contains(WorkspaceFeature.serviceFulfilment) &&
          (may(WorkspacePermission.viewFinances) ||
              may(WorkspacePermission.issueInvoices)))
        DrawerEntry(
          'drawer-engagements',
          Icons.assignment_turned_in_outlined,
          l10n.engagementsTitle,
          () => go('/money/engagements'),
          route: '/money/engagements',
        ),
      // #4164 — the people and businesses invoiced, with or without an account.
      if (sales &&
          features.contains(WorkspaceFeature.billingCustomers) &&
          (may(WorkspacePermission.manageBillingCustomers) ||
              may(WorkspacePermission.viewFinances) ||
              may(WorkspacePermission.issueInvoices)))
        DrawerEntry(
          'drawer-billing-customers',
          Icons.groups_outlined,
          l10n.billingCustomersTitle,
          () => go('/money/customers'),
          route: '/money/customers',
        ),
    ];
  }
}
