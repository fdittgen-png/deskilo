// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 — the space's purchase orders (`/money/purchase-orders`): the list,
// the latest first, each with its supplier, state and total; a buyer
// (managePurchases) drafts, edits, prints, marks sent, records what
// arrived and cancels; a
// finance reader reads and prints. The server decides every write.
// #3842 — at the desk the orders are a records table and an order is a
// record at its own address (purchase_orders_desk.dart); a phone keeps one
// card per order.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/shortcuts/app_shortcuts.dart';
import '../../../../core/shortcuts/shortcut_scope.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/adaptive/window_class.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../../../core/ui/loading_view.dart';
import '../../domain/purchase.dart';
import '../../providers/purchase_order_providers.dart';
import '../widgets/purchase_order_record.dart';
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
    final desk = WindowClass.of(context).atLeast(WindowClass.expanded);
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
          onPressed: () => context.push('/workspace-settings'),
        ),
      if (desk && mayAdd)
        TextButton.icon(
          key: const ValueKey('purchase-order-new'),
          onPressed: add,
          icon: const Icon(Icons.add),
          label: Text(l10n.purchaseOrderNew),
        ),
    ];
    if (desk && workspace != null) {
      return ShortcutScope(
        handlers: {if (mayAdd) AppShortcutId.newRecord: add},
        child: Scaffold(
          appBar: AppBar(
            title: PageTitle(l10n.purchaseOrdersTitle),
            actions: actions,
          ),
          body: PurchaseOrdersDesk(workspaceId: workspace.id),
        ),
      );
    }
    final orders = workspace == null
        ? null
        : ref.watch(purchaseOrdersProvider(workspace.id));
    return Scaffold(
      appBar: AppBar(
        title: PageTitle(l10n.purchaseOrdersTitle),
        actions: actions,
      ),
      floatingActionButton: !mayAdd
          ? null
          : FloatingActionButton.extended(
              key: const ValueKey('purchase-order-new'),
              onPressed: add,
              icon: const Icon(Icons.add),
              label: Text(l10n.purchaseOrderNew),
            ),
      body: switch (orders) {
        null => const SizedBox.shrink(),
        AsyncValue(:final value?) when value.isEmpty => Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            l10n.purchaseOrdersEmpty,
            key: const ValueKey('purchase-orders-empty'),
          ),
        ),
        AsyncValue(:final value?) => ListView(
          padding: const EdgeInsets.only(bottom: kFabSafeBottom),
          children: [
            for (final o in value)
              Card(
                key: ValueKey('purchase-order-${o.reference}'),
                margin: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: PurchaseOrderDetails(
                    order: o,
                    workspaceId: workspace!.id,
                    canWrite: canWrite,
                    letterhead: (
                      name: workspace.name,
                      address: workspace.address,
                    ),
                  ),
                ),
              ),
          ],
        ),
        AsyncValue(:final error?) => Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(l10n.purchaseOrderRefused, semanticsLabel: '$error'),
        ),
        _ => const LoadingView(),
      },
    );
  }
}
