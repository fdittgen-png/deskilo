// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 — the space's purchase orders (`/money/purchase-orders`): the list,
// the latest first, each with its supplier, state and total; a buyer
// (managePurchases) drafts, edits, prints, marks sent, records what
// arrived and cancels; a
// finance reader reads and prints. The server decides every write.
// #3842 — the orders are a records table and an order is a record at its
// own address (purchase_orders_desk.dart).
// #4492 — on a phone too: the table's cards, the same failed, loading and
// empty answers, and the same worded main action in the bar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/navigation/routes.dart';
import '../../../../core/shortcuts/app_shortcuts.dart';
import '../../../../core/shortcuts/shortcut_scope.dart';
import '../../../../core/ui/kit/page_bar.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../domain/purchase.dart';
import '../widgets/purchase_order_sheet.dart';
import 'money_view_data.dart';
import 'purchase_orders_desk.dart';

class PurchaseOrdersScreen extends ConsumerWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final workspace = MoneyViewData.gates(ref).workspace;
    final canWrite = MoneyViewData.purchasePermissionNames(ref)
        .contains(purchaseManagePermission);
    void add() =>
        PurchaseOrderSheet(context, ref).open(workspaceId: workspace!.id);
    final mayAdd = workspace != null && canWrite;
    final actions = [
      // #3307 — how the space e-mails its orders, for its billing
      // manager. #3673: the business's one sender is set in its own
      // settings; this opens them.
      if (workspace != null &&
          MoneyViewData.purchasePermissionNames(ref).contains('manageBilling'))
        IconButton(
          key: const ValueKey('purchase-order-mail-settings'),
          tooltip: l10n.businessMailSenderWhere,
          icon: const Icon(Icons.forward_to_inbox_outlined),
          onPressed: () => context.push(Routes.workspaceSettings),
        ),
      if (mayAdd)
        pageBarAction(
          key: const ValueKey('purchase-order-new'),
          label: l10n.purchaseOrderNew,
          onPressed: add,
        ),
    ];
    return ShortcutScope(
      handlers: {if (mayAdd) AppShortcutId.newRecord: add},
      child: Scaffold(
        appBar: AppBar(
          title: PageTitle(l10n.purchaseOrdersTitle),
          actions: actions,
        ),
        body: workspace == null
            ? const SizedBox.shrink()
            : PurchaseOrdersDesk(workspaceId: workspace.id),
      ),
    );
  }
}
