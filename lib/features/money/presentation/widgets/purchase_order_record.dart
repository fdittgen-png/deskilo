// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3842 — one purchase order: its reference, state, supplier and total, and
// what may be done with it (print, edit and mark sent while a draft, cancel
// while open, the send states of #3774 and the goods receipt). On a phone it
// is a card of the list; at the desk it is the record at its address,
// `/money/purchase-orders/order/<id>`, beside the orders table on a large
// window and a page of its own otherwise. The content is the card's, moved:
// the server still decides every write.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/format_controller.dart';
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
import '../screens/money_view_data.dart';
import 'purchase_order_receipt_actions.dart';
import 'purchase_order_send_actions.dart';
import 'purchase_order_sheet.dart';

/// The words of an order's [state].
String purchaseOrderStateLabel(
  AppLocalizations l10n,
  PurchaseOrderState state,
) => switch (state) {
  PurchaseOrderState.draft => l10n.purchasesStateDraft,
  PurchaseOrderState.sent => l10n.purchaseOrderStateSent,
  PurchaseOrderState.partlyReceived => l10n.purchaseOrderStatePartlyReceived,
  PurchaseOrderState.received => l10n.purchaseOrderStateReceived,
  PurchaseOrderState.cancelled => l10n.purchaseOrderStateCancelled,
};

/// The space's name and address, printed at the top of an order.
typedef OrderLetterhead = ({String name, String address});

/// The order [orderId] as a record: read from the space's orders, with the
/// writes the person holds. [onClose] is set when it stands beside the
/// table.
class PurchaseOrderRecord extends ConsumerWidget {
  const PurchaseOrderRecord({required this.orderId, this.onClose, super.key});

  final String orderId;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final workspace = MoneyViewData.gates(ref).workspace;
    final canWrite = MoneyViewData.purchasePermissionNames(ref)
        .contains(purchaseManagePermission);
    final orders = workspace == null
        ? null
        : ref.watch(purchaseOrdersProvider(workspace.id));
    final order = orders?.value
        ?.where((o) => o.id == orderId)
        .firstOrNull; // empty-ok: an order not read yet shows the loading view
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: onClose == null,
        actions: [
          if (onClose case final close?)
            CloseButton(
              key: const ValueKey('purchase-order-close'),
              onPressed: close,
            ),
        ],
      ),
      body: switch ((workspace, order, orders)) {
        (final w?, final o?, _) => ListView(
          key: ValueKey('purchase-order-panel-${o.reference}'),
          padding: AppSpacing.mdAll,
          children: [
            PurchaseOrderDetails(
              order: o,
              workspaceId: w.id,
              canWrite: canWrite,
              letterhead: (name: w.name, address: w.address),
            ),
          ],
        ),
        (_, _, AsyncValue(:final error?)) => Padding(
          padding: AppSpacing.lgAll,
          child: Text(l10n.purchaseOrderRefused, semanticsLabel: '$error'),
        ),
        (_, _, AsyncData()) => Padding(
          padding: AppSpacing.lgAll,
          child: Text(
            l10n.purchaseOrdersEmpty,
            key: const ValueKey('purchase-order-gone'),
          ),
        ),
        _ => const LoadingView(),
      },
    );
  }
}

/// What an order says and what may be done with it.
class PurchaseOrderDetails extends ConsumerWidget {
  const PurchaseOrderDetails({
    required this.order,
    required this.workspaceId,
    required this.canWrite,
    required this.letterhead,
    super.key,
  });

  final PurchaseOrder order;
  final String workspaceId;
  final bool canWrite;
  final OrderLetterhead letterhead;

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
    final total = appFormatOf(context)
        .moneyIn(order.currency)
        .formatMinor(order.totalCents);
    final draft = order.state == PurchaseOrderState.draft;
    return Column(
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
              label: Text(purchaseOrderStateLabel(l10n, order.state)),
            ),
          ],
        ),
        Text(l10n.purchaseOrderSummary(order.supplierName, total)),
        if (order.expectedOn case final d?)
          Text(
            l10n.labelWithValue(
              l10n.purchaseOrderExpected,
              MaterialLocalizations.of(context).formatMediumDate(d),
            ),
          ),
        const FormGap.small(),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
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
                ).open(workspaceId: workspaceId, orderId: order.id),
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
        PurchaseOrderSendActions(
          order: order,
          workspaceId: workspaceId,
          canWrite: canWrite,
          letterhead: letterhead,
        ),
        PurchaseOrderReceiptActions(
          order: order,
          workspaceId: workspaceId,
          canWrite: canWrite,
        ),
      ],
    );
  }
}
