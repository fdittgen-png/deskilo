// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4171 (B) -- what the stock adds to the order pane (the seam of
// money/presentation/purchase_order_stock_seam.dart): for a buyer who also
// manages the stock, with the goods ledger and the receiving asked for, each
// delivery's lines say what is put away and what is still to put away, with a
// button for what remains, and the delivery form may also put the goods away
// in the same command.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show ExactQuantity, isoDay;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/form_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../../money/domain/purchase_order.dart';
import '../../money/domain/purchase_order_receipt.dart';
import '../../money/presentation/purchase_order_stock_seam.dart';
import '../../money/providers/purchase_order_providers.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/domain/workspace_permission.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/put_away_progress.dart';
import '../domain/stock_receiving.dart';
import '../providers/stock_providers.dart';
import 'purchase_order_putaway.dart';
import 'stock_config_text.dart';
import 'stock_document_goods_block.dart';

/// Whether a buyer who also manages the stock may put a delivery away here:
/// the goods ledger and the receiving asked for, and the right to manage it.
bool _allowed(WidgetRef ref) {
  final features = ref.watch(enabledFeaturesSyncProvider);
  return features.contains(WorkspaceFeature.stockManagement) &&
      features.contains(WorkspaceFeature.stockReceiving) &&
      ref.watch(myPermissionsProvider).contains(WorkspacePermission.manageStock);
}

/// What the put-away reads from the providers.
PutAwayServices _services(WidgetRef ref) => PutAwayServices(
  commands: ref.read(stockReceivingCommandsProvider),
  config: ref.read(stockConfigCommandsProvider),
  queries: ref.read(stockQueriesProvider),
  currency: ref.read(currentWorkspaceProvider).value?.currencyCode ?? '',
);

class StockPurchaseOrderSeam implements PurchaseOrderStockSeam {
  const StockPurchaseOrderSeam();

  @override
  Widget? deliveryActions(
    BuildContext context,
    WidgetRef ref, {
    required String workspaceId,
    required PurchaseOrder order,
  }) => _allowed(ref) ? _DeliveryActions(workspaceId: workspaceId, order: order) : null;

  @override
  Widget? goodsOfDocument(
    BuildContext context,
    WidgetRef ref, {
    required String workspaceId,
    required String kind,
    required String id,
  }) {
    final held = ref.watch(myPermissionsProvider);
    final reads = held.contains(WorkspacePermission.viewStock) || held.contains(WorkspacePermission.manageStock);
    return reads && ref.watch(enabledFeaturesSyncProvider).contains(WorkspaceFeature.stockManagement)
        ? StockDocumentGoodsBlock(workspaceId: workspaceId, kind: kind, id: id)
        : null;
  }

  @override
  Future<ReceiptPutAway?> receiptPutAway(
    BuildContext context,
    WidgetRef ref, {
    required String workspaceId,
    required PurchaseOrder order,
  }) async {
    if (!_allowed(ref)) return null;
    final lines = [
      for (final l in order.lines)
        if (l.remaining > 0)
          DeliveredLineProgress(
            lineNo: l.lineNo,
            description: l.description,
            unit: l.unit,
            serviceId: l.serviceId,
            received: exactOfReceived(l.remaining),
            putAway: ExactQuantity.zero,
          ),
    ];
    final loaded = await loadPutAwayContext(context, _services(ref), workspaceId: workspaceId, lines: lines);
    if (loaded == null) return null;
    return _ReceiptPutAway(
      PutAwayDraft(loaded, order, lines, followsDelivery: true),
      ref.read(stockReceivingCommandsProvider),
    );
  }
}

/// The put-away that travels with a delivery being recorded.
class _ReceiptPutAway implements ReceiptPutAway {
  _ReceiptPutAway(this._draft, this._commands);

  final PutAwayDraft _draft;
  final StockReceivingCommands _commands;

  @override
  bool get also => _draft.also;

  @override
  List<Widget> buildAlso(BuildContext context, VoidCallback refresh) => _draft.buildAlso(context, refresh);

  @override
  FieldErrors validate(AppLocalizations l10n, Map<int, double> delivered) => !_draft.also
      ? const {}
      : {..._draft.validate(l10n), ..._draft.validateAgainst(l10n, delivered)};

  @override
  Future<String?> record(
    AppLocalizations l10n,
    String workspaceId,
    PurchaseOrder order,
    ReceiptDelivery delivery,
  ) async {
    try {
      await _commands.recordAndPutAway(
        workspaceId,
        DeliveryDraft(
          orderId: order.id,
          orderRevision: order.revision,
          receivedOn: isoDay(delivery.receivedOn),
          lines: [
            for (final e in delivery.delivered.entries)
              if (e.value > 0) (lineNo: e.key, quantity: exactOfReceived(e.value).text),
          ],
          note: delivery.note.trim(),
        ),
        _draft.toAllocations(delivered: delivery.delivered),
        _draft.requestId,
      );
      return null;
    } on Object catch (e, st) {
      TraceLogger.instance.warn('stock', 'a delivery and its put-away were not recorded: $e', stackTrace: st);
      return stockSaveProblem(l10n, e);
    }
  }

  @override
  void dispose() => _draft.dispose();
}

/// One delivery's lines with what is put away, and the way to put away what
/// remains.
class _DeliveryActions extends ConsumerWidget {
  const _DeliveryActions({required this.workspaceId, required this.order});

  final String workspaceId;
  final PurchaseOrder order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final deliveries = [
      for (final r in ref.watch(purchaseOrderReceiptsProvider(workspaceId)).value ?? const <PurchaseOrderReceipt>[]) // empty-ok: an unread list shows no delivery to put away
        if (r.orderId == order.id) r,
    ];
    final allocations = ref.watch(orderPutAwayProvider((workspaceId: workspaceId, orderId: order.id))).value ?? const <ReceiptAllocation>[]; // empty-ok: an unread put-away shows what is still to put away, never a fake done
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final delivery in deliveries) ..._delivery(context, ref, l10n, delivery, allocations),
      ],
    );
  }

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
          l10n.stockPutAwayProgress(p.description, p.putAway.text, p.remaining.text),
          key: ValueKey('purchase-order-putaway-${order.reference}-${delivery.id}-${p.lineNo}'),
        ),
      if (lines.any((p) => p.remaining > ExactQuantity.zero))
        TextButton.icon(
          key: ValueKey('purchase-order-putaway-${order.reference}-${delivery.id}'),
          onPressed: () => showPutAwaySheet(
            context,
            _services(ref),
            workspaceId: workspaceId,
            order: order,
            receipt: delivery,
            lines: lines,
            onDone: () => ref.invalidate(orderPutAwayProvider((workspaceId: workspaceId, orderId: order.id))),
          ),
          icon: const Icon(Icons.move_to_inbox_outlined),
          label: Text(l10n.stockPutAwayRemaining),
        ),
    ];
  }
}
