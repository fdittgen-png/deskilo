// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3926 — at the desk, cash is a menu group: the cash page's doors are
// entries of Finance's Cash group, each asking what its page or sheet asks.
// What is still to pay is the Purchases group's; a phone keeps the page.
import 'package:flutter/material.dart';

import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/domain/workspace_permission.dart';
import 'shell_drawer_entries.dart';

/// The Cash group's entries.
extension CashEntries on DrawerEntries {
  /// Money in and out (what `/money/status` asks, MoneyToolRights.status)
  /// and the bank statements (the sheet, for who may read them), at the
  /// desk only.
  List<DrawerEntry> cashPages() => [
    if (permanent &&
        features.contains(WorkspaceFeature.workspaceStatus) &&
        may(WorkspacePermission.viewFinances))
      DrawerEntry(
        'drawer-cash-in-out',
        Icons.account_balance_outlined,
        l10n.cashHubInOut,
        () => go('/money/status'),
        route: '/money/status',
      ),
    if (openBankStatements case final open? when permanent)
      DrawerEntry(
        'drawer-bank-statements',
        Icons.account_balance_wallet_outlined,
        l10n.bankStatementsTitle,
        open,
      ),
  ];
}
