// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 — what arrived of an order, on its card: each line received so far
// against what was ordered, and, for a buyer, "record a delivery" on a sent
// or partly received order — the day it arrived (today by default, never
// later), how much of each line (what is left by default) and a note. The
// server records it and moves the order (0684).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/decimal_input.dart';
import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/form_kit.dart';
import '../../application/purchase_order_commands.dart';
import '../../domain/purchase_order.dart';
import '../../domain/purchase_order_receipt.dart';

/// A quantity as a person types it: no trailing ".0".
String _qty(double q) => q == q.roundToDouble() ? q.toStringAsFixed(0) : '$q';

class PurchaseOrderReceiptActions extends ConsumerWidget {
  const PurchaseOrderReceiptActions({
    required this.order,
    required this.workspaceId,
    required this.canWrite,
    super.key,
  });

  final PurchaseOrder order;
  final String workspaceId;
  final bool canWrite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final shown =
        order.state != PurchaseOrderState.draft &&
        order.state != PurchaseOrderState.cancelled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (shown || order.lines.any((l) => l.receivedQuantity > 0))
          for (final l in order.lines)
            Text(
              l10n.purchaseOrderLineReceived(
                l.description,
                _qty(l.receivedQuantity),
                _qty(l.quantity),
              ),
              key: ValueKey(
                'purchase-order-received-${order.reference}-${l.lineNo}',
              ),
            ),
        if (canWrite && order.receivable)
          OutlinedButton.icon(
            key: ValueKey('purchase-order-receive-${order.reference}'),
            onPressed: () =>
                _ReceiptSheet(context, ref).open(workspaceId, order),
            icon: const Icon(Icons.inventory_2_outlined),
            label: Text(l10n.purchaseOrderReceive),
          ),
      ],
    );
  }
}

/// The "record a delivery" sheet of one order.
class _ReceiptSheet {
  _ReceiptSheet(this.context, this.ref);

  final BuildContext context;
  final WidgetRef ref;

  Future<void> open(String workspaceId, PurchaseOrder order) async {
    final l10n = context.l10n;
    final today = ref.read(clockProvider).now();
    var day = DateTime(today.year, today.month, today.day);
    final fields = FormControllers({
      for (final l in order.lines)
        if (l.remaining > 0) 'line-${l.lineNo}': _qty(l.remaining),
    });
    final requestId = newRequestId();
    PurchaseOrderReceiptDraft draft() => PurchaseOrderReceiptDraft(
      order: order,
      receivedOn: day,
      note: fields.text('note'),
      quantities: {
        for (final l in order.lines)
          l.lineNo:
              parseDecimalInput(
                fields.text('line-${l.lineNo}'),
                grouping: false,
              )?.toDouble() ??
              (fields.text('line-${l.lineNo}').isEmpty ? 0 : -1),
      },
    );
    await showAppFormSheet(
      context,
      AppFormSheet(
        title: l10n.purchaseOrderReceiveTitle(order.reference),
        submitLabel: l10n.purchaseOrderReceive,
        submitKey: const ValueKey('purchase-order-receive-confirm'),
        onDispose: fields.dispose,
        validate: () {
          // The day cannot be later than today: the picker ends there.
          final problems = draft().problemsOn(ref.read(clockProvider).now());
          return {
            if (problems.contains(PurchaseOrderReceiptProblem.tooMany))
              for (final l in order.lines)
                'line-${l.lineNo}': l10n.purchaseOrderReceiveTooMany
            else if (problems.contains(PurchaseOrderReceiptProblem.nothing))
              'line-${order.lines.first.lineNo}':
                  l10n.purchaseOrderReceiveNothing,
          };
        },
        onSubmit: () async {
          final ok = await runGuarded(
            context,
            domain: 'money',
            message: 'purchase order receipt failed',
            errorText: l10n.purchaseOrderRefused,
            action: () async {
              await ref
                  .read(purchaseOrderCommandsProvider)
                  .recordReceipt(workspaceId, requestId, draft());
            },
          );
          return ok ? null : l10n.purchaseOrderRefused;
        },
        builder: (context, refresh) => [
          OutlinedButton.icon(
            key: const ValueKey('purchase-order-receive-day'),
            icon: const Icon(Icons.event_outlined),
            label: Text(
              l10n.labelWithValue(
              l10n.purchaseOrderReceivedOn,
              MaterialLocalizations.of(context).formatMediumDate(day),
            ),
            ),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: day,
                firstDate: DateTime(2000),
                lastDate: today,
                helpText: l10n.purchaseOrderReceivedOn,
              );
              if (picked != null) {
                day = picked;
                refresh();
              }
            },
          ),
          for (final l in order.lines)
            AppTextField(
              key: ValueKey('purchase-order-receive-line-${l.lineNo}'),
              controller: fields['line-${l.lineNo}'],
              fieldKey: 'line-${l.lineNo}',
              label: l10n.purchaseOrderReceiveLine(
                l.description,
                _qty(l.remaining),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          AppTextField(
            key: const ValueKey('purchase-order-receive-note'),
            controller: fields['note'],
            fieldKey: 'note',
            label: l10n.purchaseOrderReceiveNote,
            maxLength: 500,
          ),
        ],
      ),
    );
  }
}
