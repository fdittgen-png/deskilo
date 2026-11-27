// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3842 — the purchase orders at the desk: a records table (#3606) of
// number, supplier, state, expected date and total, the chip Open, the
// footer adding the total per currency, never across; on a phone a card per
// order with the same words (#4492). A row opens its order
// at its address, `/money/purchase-orders/order/<id>`, beside the table on a
// large window and as a page of its own below it (#3607). The segment before
// the id keeps the order's form (`/new`, a pushed long task) from being
// read as an order.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/navigation/list_detail_route.dart';
import '../../../../core/storage/pane_width_store.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/kit/list_detail_scaffold.dart';
import '../../../../core/ui/kit/records_table.dart';
import '../../domain/purchase_order.dart';
import '../../providers/purchase_order_providers.dart';
import '../widgets/purchase_order_record.dart';

/// The orders list's address.
const String _ordersPath = '/money/purchase-orders';

/// Where an order opens: `/money/purchase-orders/order/<id>`.
const String _orderPath = '/money/purchase-orders/order';

/// The most a card gives its total and state, so the reference and the
/// supplier keep the rest of a phone's width.
// content-fit: a total and a state word beside the card's title
const double _cardStateWidth = 160;

/// The orders table (cards on a phone), with the open order beside it on a
/// large window.
class PurchaseOrdersDesk extends ConsumerWidget {
  const PurchaseOrdersDesk({required this.workspaceId, super.key});

  final String workspaceId;

  /// The table's least width beside an open order: its number, supplier and
  /// total stay readable as columns.
  // content-fit: the columns that stay beside an open order, side by side
  static const double listMinWidth = 560;

  @override
  Widget build(BuildContext context, WidgetRef ref) => OpenRecord(
    listPath: _orderPath,
    builder: (context, id) => ListDetailScaffold(
      id: 'purchase-orders',
      paneStore: ref.watch(paneWidthStoreProvider),
      listMin: listMinWidth,
      list: _list(context, ref),
      selected: recordBesideList(context) ? id : null,
      onClose: () => context.go(_ordersPath),
      onMove: (id) => moveToRecord(context, _orderPath, id),
      detail: (context, id) => PurchaseOrderRecord(
        key: ValueKey('purchase-order-record-$id'),
        orderId: id,
        onClose: () => context.go(_ordersPath),
      ),
    ),
  );

  Widget _list(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(purchaseOrdersProvider(workspaceId));
    return _OrdersTable(
      orders: orders.value ?? const <PurchaseOrder>[], // empty-ok: the table shows loading or failed while it is not read
      state: switch (orders) {
        AsyncData() => RecordsState.ready,
        AsyncError() => RecordsState.failed,
        _ => RecordsState.loading,
      },
      error: orders.error,
      onRetry: () => ref.invalidate(purchaseOrdersProvider(workspaceId)),
      onOpen: (id) => openRecord(context, _orderPath, id),
    );
  }
}

class _OrdersTable extends StatelessWidget {
  const _OrdersTable({
    required this.orders,
    required this.state,
    this.error,
    required this.onRetry,
    required this.onOpen,
  });

  final List<PurchaseOrder> orders;
  final RecordsState state;

  /// #4097 — why the read failed, for the table to tell a refusal.
  final Object? error;
  final VoidCallback onRetry;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final format = appFormatOf(context);
    final dates = format.dates(DateShape.numeric);
    String total(PurchaseOrder o) =>
        format.moneyIn(o.currency).formatMinor(o.totalCents);
    return RecordsTable<PurchaseOrder>(
      tableId: 'purchase-orders',
      rows: orders,
      state: state,
      error: error,
      onRetry: onRetry,
      keyOf: (o) => o.id,
      searchText: (o) => '${o.reference} ${o.supplierName}',
      onOpen: (o) => onOpen(o.id),
      empty: EmptyState(
        key: const ValueKey('purchase-orders-empty'),
        icon: Icons.local_shipping_outlined,
        title: l.purchaseOrdersEmpty,
      ),
      initialQuery: const RecordsQuery(sortColumn: 'number', ascending: false),
      chips: [
        RecordChip(
          id: 'open',
          label: l.invoicingFilterOpen,
          keeps: (o) => o.state.open,
        ),
      ],
      amountOf: (o) => (currency: o.currency, minor: o.totalCents),
      formatAmount: (c, m) => format.moneyIn(c).formatMinor(m),
      columns: [
        RecordColumn(
          id: 'number',
          label: l.invoiceRegisterNumber,
          flex: 2,
          hideable: false,
          sortKey: (o) => o.reference,
          cell: (_, o) => Text(o.reference),
        ),
        RecordColumn(
          id: 'supplier',
          label: l.purchaseOrderSupplier,
          flex: 4,
          sortKey: (o) => o.supplierName.toLowerCase(),
          cell: (_, o) => Text(o.supplierName, overflow: TextOverflow.ellipsis),
        ),
        RecordColumn(
          id: 'state',
          label: l.invoicingColStatus,
          staysBeside: false,
          flex: 3,
          sortKey: (o) => o.state.index,
          cell: (_, o) => Align(
            alignment: AlignmentDirectional.centerStart,
            child: purchaseOrderStateChip(l, o),
          ),
        ),
        RecordColumn(
          id: 'expected',
          label: l.purchaseOrderExpected,
          staysBeside: false,
          flex: 3,
          sortKey: (o) => o.expectedOn ?? DateTime(0),
          cell: (_, o) =>
              Text(o.expectedOn == null ? '' : dates.format(o.expectedOn!)),
        ),
        RecordColumn(
          id: 'total',
          label: l.purchasesTotal,
          numeric: true,
          flex: 3,
          sortKey: (o) => o.totalCents,
          cell: (_, o) => Text(total(o)),
        ),
      ],
      // The card says what the row says: number, supplier, the day it is
      // expected, the total and, under it, the state in its chip.
      cardBuilder: (context, o) => ListTile(
        key: ValueKey('purchase-order-${o.reference}'),
        title: Text(o.reference),
        subtitle: Text(
          [
            o.supplierName,
            if (o.expectedOn case final day?) dates.format(day),
          ].join(' · '),
        ),
        // A state this app does not know is said with the server's text,
        // which may be long: the chip keeps to its share and is cut there.
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _cardStateWidth),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [Text(total(o)), purchaseOrderStateChip(l, o)],
          ),
        ),
      ),
    );
  }
}
