// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 — what arrived of an order, on its card: each line received so far
// against what was ordered, and, for a buyer, "record a delivery" on a sent
// or partly received order — the day it arrived (today by default, never
// later), how much of each line (what is left by default) and a note. The
// server records it and moves the order (0684).
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show isoDay;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/decimal_input.dart';
import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../stock/domain/stock_receiving.dart';
import '../../../stock/presentation/stock_config_text.dart';
import '../../../stock/providers/stock_providers.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/domain/workspace_permission.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/purchase_order_commands.dart';
import '../../domain/purchase_order.dart';
import '../../domain/purchase_order_receipt.dart';
import '../../domain/put_away_progress.dart';
import '../../providers/purchase_order_providers.dart';
import 'purchase_order_putaway.dart';

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
    // #4171 -- what a delivery brought and what of it is in stock: asked for,
    // for a buyer who also manages the stock.
    final putAwayOn = canWrite && _putAwayAllowed(ref);
    final deliveries = !putAwayOn
        ? const <PurchaseOrderReceipt>[]
        : [
            for (final r in ref.watch(purchaseOrderReceiptsProvider(workspaceId)).value ?? const <PurchaseOrderReceipt>[]) // empty-ok: an unread list shows no delivery to put away
              if (r.orderId == order.id) r,
          ];
    final allocations = !putAwayOn
        ? const <ReceiptAllocation>[]
        : ref.watch(orderPutAwayProvider((workspaceId: workspaceId, orderId: order.id))).value ?? const <ReceiptAllocation>[]; // empty-ok: an unread put-away shows what is still to put away, never a fake done
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
        for (final delivery in deliveries) ..._delivery(context, ref, l10n, delivery, allocations),
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

/// Whether a buyer who also manages the stock may put a delivery away here:
/// the goods ledger and the receiving asked for, and the right to manage it.
bool _putAwayAllowed(WidgetRef ref) {
  final features = ref.watch(enabledFeaturesSyncProvider);
  return features.contains(WorkspaceFeature.stockManagement) &&
      features.contains(WorkspaceFeature.stockReceiving) &&
      ref.watch(myPermissionsProvider).contains(WorkspacePermission.manageStock);
}

extension on PurchaseOrderReceiptActions {
  /// One delivery: each line's progress and the way to put away what remains.
  List<Widget> _delivery(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    PurchaseOrderReceipt delivery,
    List<ReceiptAllocation> allocations,
  ) {
    final lines = progressOfDelivery(order, delivery, allocations);
    return [
      for (final p in lines)
        Text(
          l10n.stockPutAwayProgress(p.description, _qty(p.putAway), _qty(p.remaining)),
          key: ValueKey('purchase-order-putaway-${order.reference}-${delivery.id}-${p.lineNo}'),
        ),
      if (lines.any((p) => p.remaining > 0))
        TextButton.icon(
          key: ValueKey('purchase-order-putaway-${order.reference}-${delivery.id}'),
          onPressed: () => showPutAwaySheet(
            context,
            ref,
            workspaceId: workspaceId,
            order: order,
            receipt: delivery,
            lines: lines,
          ),
          icon: const Icon(Icons.move_to_inbox_outlined),
          label: Text(l10n.stockPutAwayRemaining),
        ),
    ];
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
    DateRead dayRead = (date: day, problem: null);
    final fields = FormControllers({
      for (final l in order.lines)
        if (l.remaining > 0) 'line-${l.lineNo}': _qty(l.remaining),
    });
    final requestId = newRequestId();
    // #4171 -- "also put away": the stock side is read first, so the form
    // opens with its places, variants and tracking.
    PutAwayDraft? put;
    if (_putAwayAllowed(ref)) {
      final lines = [
        for (final l in order.lines)
          if (l.remaining > 0)
            DeliveredLineProgress(
              lineNo: l.lineNo,
              description: l.description,
              unit: l.unit,
              serviceId: l.serviceId,
              received: l.remaining,
              putAway: 0,
            ),
      ];
      final loaded = await loadPutAwayContext(context, ref, workspaceId, lines);
      if (loaded != null && context.mounted) put = PutAwayDraft(loaded, order, lines, followsDelivery: true);
    }
    if (!context.mounted) return;
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
        onDispose: () {
          fields.dispose();
          put?.dispose();
        },
        validate: () {
          // The day cannot be later than today: the picker ends there.
          final problems = draft().problemsOn(ref.read(clockProvider).now());
          final dayProblem = dayRead.problem;
          return {
            if (dayProblem != null)
              'day': dateInputProblemText(l10n, dayProblem)
            else if (dayRead.date == null)
              'day': l10n.dateFieldRequired,
            if (put != null && put.also)
              ...put.validate(l10n),
            if (put != null && put.also)
              ...put.validateAgainst(l10n, draft().quantities),
            if (problems.contains(PurchaseOrderReceiptProblem.tooMany))
              for (final l in order.lines)
                'line-${l.lineNo}': l10n.purchaseOrderReceiveTooMany
            else if (problems.contains(PurchaseOrderReceiptProblem.nothing))
              'line-${order.lines.first.lineNo}':
                  l10n.purchaseOrderReceiveNothing,
          };
        },
        onSubmit: () async {
          if (put != null && put.also) {
            // The delivery and its put-away are one command: both, or neither.
            try {
              final d = draft();
              await ref.read(stockReceivingCommandsProvider).recordAndPutAway(
                workspaceId,
                DeliveryDraft(
                  orderId: order.id,
                  orderRevision: order.revision,
                  receivedOn: isoDay(d.receivedOn),
                  lines: [
                    for (final e in d.toLines()) (lineNo: e['line_no']! as int, quantity: _qty(e['quantity']! as double)),
                  ],
                  note: d.note.trim(),
                ),
                put.toAllocations(delivered: d.quantities),
                requestId,
              );
              ref
                ..invalidate(purchaseOrdersProvider(workspaceId))
                ..invalidate(purchaseOrderReceiptsProvider(workspaceId))
                ..invalidate(orderPutAwayProvider((workspaceId: workspaceId, orderId: order.id)));
              return null;
            } on Object catch (e, st) {
              TraceLogger.instance.warn('stock', 'a delivery and its put-away were not recorded: $e', stackTrace: st);
              return stockSaveProblem(l10n, e);
            }
          }
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
          AppDateField(
            key: const ValueKey('purchase-order-receive-day'),
            fieldKey: 'day',
            label: l10n.purchaseOrderReceivedOn,
            value: dayRead.date,
            first: DateTime(2000),
            last: today,
            pickerHelpText: l10n.purchaseOrderReceivedOn,
            isRequired: true,
            onChanged: (read) {
              dayRead = read;
              if (read.date case final date?) day = date;
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
          if (put != null) ...put.buildAlso(context, refresh),
        ],
      ),
    );
  }
}
