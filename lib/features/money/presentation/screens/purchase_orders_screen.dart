// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 — the space's purchase orders (`/money/purchase-orders`): the list,
// the latest first, each with its supplier, state and total; a buyer
// (managePurchases) drafts, edits, prints, marks sent and cancels; a
// finance reader reads and prints. The server decides every write.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/purchase_order_commands.dart';
import '../../domain/purchase.dart';
import '../../domain/purchase_order.dart';
import '../../providers/purchase_order_providers.dart';
import '../purchase_order_print.dart';
import '../widgets/purchase_order_sheet.dart';
import 'money_view_data.dart';

/// The words of an order's [state].
String _stateLabel(AppLocalizations l10n, PurchaseOrderState state) =>
    switch (state) {
      PurchaseOrderState.draft => l10n.purchaseOrderStateDraft,
      PurchaseOrderState.sent => l10n.purchaseOrderStateSent,
      PurchaseOrderState.partlyReceived =>
        l10n.purchaseOrderStatePartlyReceived,
      PurchaseOrderState.received => l10n.purchaseOrderStateReceived,
      PurchaseOrderState.cancelled => l10n.purchaseOrderStateCancelled,
    };

class PurchaseOrdersScreen extends ConsumerWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final workspace = MoneyViewData.gates(ref).workspace;
    final canWrite = MoneyViewData.purchasePermissionNames(ref)
        .contains(purchaseManagePermission);
    final orders = workspace == null
        ? null
        : ref.watch(purchaseOrdersProvider(workspace.id));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.purchaseOrdersTitle)),
      floatingActionButton: workspace == null || !canWrite
          ? null
          : FloatingActionButton.extended(
              key: const ValueKey('purchase-order-new'),
              onPressed: () => PurchaseOrderSheet(
                context,
                ref,
              ).open(workspaceId: workspace.id),
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
              _OrderTile(
                order: o,
                workspaceId: workspace!.id,
                canWrite: canWrite,
                letterhead: (name: workspace.name, address: workspace.address),
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

class _OrderTile extends ConsumerWidget {
  const _OrderTile({
    required this.order,
    required this.workspaceId,
    required this.canWrite,
    required this.letterhead,
  });

  final PurchaseOrder order;
  final String workspaceId;
  final bool canWrite;

  /// The space's name and address, printed at the top of the order.
  final ({String name, String address}) letterhead;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final reason = FormControllers();
    final requestId = newRequestId();
    await showAppFormSheet(
      context,
      AppFormSheet(
        title: l10n.purchaseOrderCancel,
        submitLabel: l10n.purchaseOrderCancel,
        submitKey: const ValueKey('purchase-order-cancel-confirm'),
        onDispose: reason.dispose,
        validate: () => reason.values['reason']!.isEmpty
            ? {'reason': l10n.purchaseOrderCancelReason}
            : const {},
        onSubmit: () async {
          final ok = await runGuarded(
            context,
            domain: 'money',
            message: 'purchase order cancel failed',
            errorText: l10n.purchaseOrderRefused,
            action: () async {
              await ref
                  .read(purchaseOrderCommandsProvider)
                  .cancel(
                    workspaceId,
                    order,
                    reason.values['reason']!,
                    requestId,
                  );
            },
          );
          return ok ? null : l10n.purchaseOrderRefused;
        },
        builder: (context, refresh) => [
          AppTextField(
            key: const ValueKey('purchase-order-cancel-reason'),
            controller: reason['reason'],
            fieldKey: 'reason',
            label: l10n.purchaseOrderCancelReason,
            maxLength: 300,
          ),
        ],
      ),
    );
  }

  Future<void> _markSent(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final requestId = newRequestId();
    await runGuarded(
      context,
      domain: 'money',
      message: 'purchase order mark sent failed',
      errorText: l10n.purchaseOrderRefused,
      action: () async {
        await ref
            .read(purchaseOrderCommandsProvider)
            .markSent(workspaceId, order, requestId);
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final total = moneyFormat(
      order.currency,
      locale: locale,
    ).formatMinor(order.totalCents);
    final draft = order.state == PurchaseOrderState.draft;
    return Card(
      key: ValueKey('purchase-order-${order.reference}'),
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.reference,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  key: ValueKey('purchase-order-state-${order.reference}'),
                  label: Text(_stateLabel(l10n, order.state)),
                ),
              ],
            ),
            Text(l10n.purchaseOrderSummary(order.supplierName, total)),
            if (order.expectedOn case final d?)
              Text(
                '${l10n.purchaseOrderExpected}: '
                '${MaterialLocalizations.of(context).formatMediumDate(d)}',
              ),
            const FormGap.small(),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                OutlinedButton.icon(
                  key: ValueKey('purchase-order-print-${order.reference}'),
                  onPressed: () => PurchaseOrderPrint(context, ref).show(
                    workspaceId: workspaceId,
                    order: order,
                    letterhead: letterhead,
                  ),
                  icon: const Icon(Icons.print_outlined),
                  label: Text(l10n.purchaseOrderPrint),
                ),
                if (canWrite && draft) ...[
                  OutlinedButton.icon(
                    key: ValueKey('purchase-order-edit-${order.reference}'),
                    onPressed: () => PurchaseOrderSheet(
                      context,
                      ref,
                    ).open(workspaceId: workspaceId, order: order),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(l10n.purchaseOrderEdit),
                  ),
                  OutlinedButton.icon(
                    key: ValueKey('purchase-order-sent-${order.reference}'),
                    onPressed: () => _markSent(context, ref),
                    icon: const Icon(Icons.outbox_outlined),
                    label: Text(l10n.purchaseOrderMarkSent),
                  ),
                ],
                if (canWrite && order.state.open)
                  TextButton(
                    key: ValueKey('purchase-order-cancel-${order.reference}'),
                    onPressed: () => _cancel(context, ref),
                    child: Text(l10n.purchaseOrderCancel),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
