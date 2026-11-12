// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3603 — the groups of the business's navigation, as data: the drawer and
// the desk's sidebar open a group in place, the desk's rail as a flyout.
// One table (#2313, #3071), rendered three ways; never a second one.
import 'package:flutter/material.dart';

import 'shell_drawer_entries.dart';

/// One titled group of entries, with its sub-groups.
@immutable
class NavGroup {
  const NavGroup(
    this.id,
    this.title,
    this.icon,
    this.entries, {
    this.sub = const [],
  });

  final String id;
  final String title;
  final IconData icon;
  final List<DrawerEntry> entries;
  final List<NavGroup> sub;

  /// No entry here or in a sub-group: the group is not shown.
  bool get isEmpty => entries.isEmpty && sub.every((g) => g.isEmpty);
}

/// The groups after the destinations, in menu order: reporting, people,
/// sales, purchases, finance (with accounting and VAT inside), workspace.
/// Each holds only the entries [entries] offers this person; a financial
/// permission does not depend on an unrelated administration door.
List<NavGroup> navGroupsOf(
  DrawerEntries entries, {
  required List<DrawerEntry> administration,
  required List<DrawerEntry> reporting,
}) {
  final labels = entries.l10n;
  final accounting = entries.accounting();
  final all = [...entries.money(), ...administration];
  NavGroup pick(
    String id,
    String title,
    IconData icon,
    List<DrawerEntry> from,
    Set<String> keys, {
    List<NavGroup> sub = const [],
  }) => NavGroup(id, title, icon, [
    for (final e in from)
      if (keys.contains(e.key)) e,
  ], sub: sub);
  return [
    NavGroup(
      'reporting',
      labels.uxNavReporting,
      Icons.analytics_outlined,
      reporting,
    ),
    pick('people', labels.uxNavPeople, Icons.group_outlined, administration, {
      'drawer-members',
      'drawer-roles',
      'drawer-nfc-config',
    }),
    pick('sales', labels.uxNavSales, Icons.sell_outlined, all, {
      'drawer-sales',
      'drawer-invoices',
      'drawer-services',
      'drawer-accessories',
      'drawer-billing',
      'drawer-payment-methods',
      'drawer-payment-config',
    }),
    pick(
      'purchases',
      labels.navPurchasesGroup,
      Icons.shopping_cart_outlined,
      all,
      {
        'drawer-purchases',
        'drawer-suppliers',
        // #3603 — built since #3307, never placed in a group until now.
        'drawer-purchase-orders',
        'drawer-purchase-approvals',
        'drawer-purchases-to-pay',
      },
    ),
    pick(
      'finance',
      labels.uxNavFinance,
      Icons.receipt_long_outlined,
      all,
      {'drawer-cash'},
      sub: [
        NavGroup(
          'accounting',
          labels.hubAccountingTitle,
          Icons.menu_book_outlined,
          accounting,
        ),
      ],
    ),
    pick(
      'workspace',
      labels.uxNavWorkspace,
      Icons.business_outlined,
      administration,
      {'drawer-setup-guide', 'drawer-availability'},
    ),
  ];
}
