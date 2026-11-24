// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3614 — the sales hub's links, as entries of the Sales group: the guest
// passes and the register, each asking what its page asks.
import 'package:flutter/material.dart';

import '../../features/workspace/domain/business_entries.dart';
import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/domain/workspace_permission.dart';
import 'shell_drawer_entries.dart';

/// The Sales group's entries beside the invoices.
extension SalesEntries on DrawerEntries {
  /// The guest passes and the invoice register.
  List<DrawerEntry> salesPages() {
    final sales = features.contains(WorkspaceFeature.invoicing);
    // #4168 — one rule for the menu and for the overview of a business.
    final own = businessEntriesFor(features, permissions);
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
      // #4366 — the till: a sale at the counter on a receipt of its own.
      if (features.contains(WorkspaceFeature.counterReceipts) && may(WorkspacePermission.issueInvoices))
        DrawerEntry(
          'drawer-till',
          Icons.point_of_sale_outlined,
          l10n.tillTitle,
          () => go('/till'),
          route: '/till',
        ),
      // #4367 — the cash drawer of the tills: open with a float, count and close.
      if (features.contains(WorkspaceFeature.counterTillSessions) &&
          (may(WorkspacePermission.issueInvoices) || may(WorkspacePermission.viewFinances)))
        DrawerEntry(
          'drawer-till-drawer',
          Icons.account_balance_wallet_outlined,
          l10n.tillDrawerManage,
          () => go('/till/drawer'),
          route: '/till/drawer',
        ),
      // #4166 — the quotes: an offer to a billing customer before an invoice.
      if (own.contains(BusinessEntry.quotes))
        DrawerEntry(
          'drawer-quotes',
          Icons.request_quote_outlined,
          l10n.quotesTitle,
          () => go('/money/quotes'),
          route: '/money/quotes',
        ),
      // #4178 — the services ordered, followed ordered, started, done.
      if (own.contains(BusinessEntry.engagements))
        DrawerEntry(
          'drawer-engagements',
          Icons.assignment_turned_in_outlined,
          l10n.engagementsTitle,
          () => go('/money/engagements'),
          route: '/money/engagements',
        ),
      // #4164 — the people and businesses invoiced, with or without an account.
      if (own.contains(BusinessEntry.customers))
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
