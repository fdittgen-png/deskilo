// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4173 (G6, client): goods traced to their documents and the operational value, as a person uses
// them at a phone and a desk width. "Where this came from" on a movement: the receipt, the order, the
// bills linked to it, what each owes and how it was settled (a payment AND its reversal); a layer the
// reader may not see says so and is never "unpaid", a layer with nothing recorded says "not linked",
// a failed read says so and can be asked again, never an empty trace. The stock value totals the known
// costs, says it is not complete while goods of unknown cost are on hand and lists them, and is shown
// only to a reader who may see what goods cost.
import 'package:deskilo/features/stock/domain/stock_page.dart';
import 'package:deskilo/features/stock/domain/stock_queries.dart';
import 'package:deskilo/features/stock/domain/stock_trace.dart';
import 'package:deskilo/features/stock/presentation/stock_document_goods_block.dart';
import 'package:deskilo/features/stock/presentation/stock_movement_screen.dart';
import 'package:deskilo/features/stock/presentation/stock_value_screen.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

StockMovementRow _move() => StockMovementRow(
  workspaceId: 'w',
  id: 'm-1',
  itemId: 'i-Water',
  itemName: 'Water',
  lotId: 'l-1',
  lotCode: null,
  fromLocationId: 'p-SUPPLIER',
  fromLocationCode: 'SUPPLIER',
  toLocationId: 'p-MAIN',
  toLocationCode: 'MAIN',
  quantity: ExactQuantity.parse('24'),
  unit: 'piece',
  enteredQuantity: ExactQuantity.parse('2'),
  enteredUnit: 'carton',
  occurredAt: DateTime.utc(2026, 3, 3, 9),
  reason: 'receipt',
  unitCost: null,
  causes: const {},
);

class _Stock implements StockQueries {
  @override
  Future<StockMovementRow?> movement(String workspaceId, String movementId) async => _move();

  @override
  Future<List<StockItem>> items(String workspaceId) async => const [
    StockItem(id: 'i-Water', name: 'Water', unit: 'piece'),
    StockItem(id: 'i-Biscuits', name: 'Biscuits', unit: 'piece'),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

TracePurchase _purchase({
  TraceState bills = TraceState.listed,
  TraceState settlement = TraceState.listed,
  bool paid = true,
}) => TracePurchase(
  state: TraceState.linked,
  receiptId: 'r-1',
  receivedOn: '2026-03-03',
  orderId: 'o-1',
  orderReference: '2026-0001',
  orderState: 'received',
  supplierName: 'Water Co',
  billsState: bills,
  billsTruncated: false,
  bills: bills != TraceState.listed
      ? const []
      : [
          TraceBill(
            id: 'b-1',
            kind: 'bill',
            state: 'approved',
            reference: 'INV-1',
            currency: 'EUR',
            obligationsTruncated: false,
            obligations: [
              TraceObligation(
                id: 'ob-1',
                state: 'open',
                amountCents: 1000,
                currency: 'EUR',
                settlementState: settlement,
                settlementTruncated: false,
                settlement: settlement != TraceState.listed || !paid
                    ? const []
                    : const [
                        TraceAllocation(id: 'a-1', reversal: false, amountCents: 600, paymentId: 'pay-1', paymentState: 'reported', method: 'bank_transfer', currency: 'EUR', reportedPaidOn: '2026-02-01'),
                        TraceAllocation(id: 'a-2', reversal: true, amountCents: -600, paymentId: 'pay-1', paymentState: 'reported', method: 'bank_transfer', currency: 'EUR', reportedPaidOn: '2026-02-03'),
                      ],
              ),
            ],
          ),
          const TraceBill(id: 'b-2', kind: 'bill', state: 'draft', reference: 'INV-2', currency: 'EUR', obligations: [], obligationsTruncated: false),
        ],
);

class _Trace implements StockTraceReader {
  _Trace({this.purchase, this.fail = false, this.valuationAnswer, this.valuationFail = false, this.pages = const [], this.docFail = false});

  /// The pages of goods a document answers, in order; the cursor is the page index.
  final List<DocumentGoods> pages;
  bool docFail;
  final asked = <Map<String, Object?>?>[];

  final TracePurchase? purchase;
  bool fail;
  final StockValuation? valuationAnswer;
  final bool valuationFail;
  int traceCalls = 0;
  int valuationCalls = 0;

  @override
  Future<StockTraceAnswer> trace(String workspaceId, String movementId) async {
    traceCalls++;
    if (fail) {
      fail = false;
      throw StateError('unreachable');
    }
    return StockTraceAnswer(
      truncated: false,
      traces: [
        StockTrace(
          movementId: movementId,
          quantity: ExactQuantity.parse('24'),
          reason: 'receipt',
          cost: const TraceCost(state: 'known', totalCostMinor: 2400),
          purchase: purchase ?? const TracePurchase(state: TraceState.notLinked, billsState: TraceState.notLinked, bills: [], billsTruncated: false),
        ),
      ],
    );
  }

  @override
  Future<DocumentGoods> documentGoods(String workspaceId, String kind, String id, {int limit = 50, Map<String, Object?>? after}) async {
    asked.add(after);
    if (docFail) {
      docFail = false;
      throw StateError('unreachable');
    }
    if (pages.isEmpty) return const DocumentGoods(state: TraceState.notLinked, rows: [], more: false);
    return pages[(after?['page'] as int?) ?? 0];
  }

  @override
  Future<StockValuation> valuation(String workspaceId, {DateTime? at}) async {
    valuationCalls++;
    if (valuationFail) throw StateError('unreachable');
    return valuationAnswer!;
  }
}

StockValuation _valuation({bool complete = false, bool truncated = false}) => StockValuation(
  cutoff: DateTime.utc(2026, 3, 4, 12),
  calculatedAt: DateTime.utc(2026, 3, 4, 12, 1),
  currency: 'EUR',
  movementsCounted: 5,
  knownTotalMinor: 2000,
  linesTruncated: truncated,
  uncostedTruncated: false,
  complete: complete,
  lines: [ValuationLine(itemId: 'i-Water', lotId: 'l-1', quantity: ExactQuantity.parse('20'), valueMinor: 2000)],
  uncosted: complete ? const [] : [UncostedGroup(itemId: 'i-Biscuits', quantity: ExactQuantity.parse('24'), noLot: false)],
);

DocumentGoodsRow _row(String id, String entered) => DocumentGoodsRow(
  movementId: id,
  itemId: 'i-Water',
  quantity: ExactQuantity.parse('24'),
  enteredQuantity: ExactQuantity.parse(entered),
  enteredUnit: 'carton',
  occurredAt: DateTime.utc(2026, 3, 3, 9),
);

const _phone = Size(390, 844);
const _desk = Size(1440, 900);

Future<void> _open(WidgetTester tester, Widget home, _Trace trace, Size size, {Set<WorkspacePermission>? held}) async {
  await pumpApp(
    tester,
    home,
    size: size,
    overrides: [
      ...standardTestOverrides(),
      stockQueriesProvider.overrideWithValue(_Stock()),
      stockTraceReaderProvider.overrideWithValue(trace),
      myPermissionsProvider.overrideWithValue(held ?? {WorkspacePermission.viewStock, WorkspacePermission.viewFinances, WorkspacePermission.managePurchases}),
    ],
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final (name, size) in [('phone', _phone), ('desk', _desk)]) {
    group('on a $name', () {
      testWidgets('a movement shows the receipt, the order, both bills, the owed amount, a payment and its reversal', (tester) async {
        await _open(tester, const StockMovementScreen(movementId: 'm-1'), _Trace(purchase: _purchase()), size);
        await tester.scrollUntilVisible(find.byKey(const ValueKey('stock-trace-allocation-a-2')), 200, scrollable: find.byType(Scrollable).first);
        expect(find.text(_en.stockTraceOrder('2026-0001', 'Water Co')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-trace-bill-b-1')), findsOneWidget, reason: 'an order with two bills lists both');
        expect(find.byKey(const ValueKey('stock-trace-bill-b-2')), findsOneWidget);
        expect(find.textContaining('10.00'), findsOneWidget, reason: 'what the bill owes');
        expect(find.byKey(const ValueKey('stock-trace-allocation-a-1')), findsOneWidget, reason: 'the payment');
        expect(find.byKey(const ValueKey('stock-trace-allocation-a-2')), findsOneWidget, reason: 'and its reversal, both shown');
        expect(find.text(_en.stockTraceNote), findsOneWidget);
      });

      testWidgets('payments the reader may not see are unavailable, never unpaid', (tester) async {
        await _open(tester, const StockMovementScreen(movementId: 'm-1'), _Trace(purchase: _purchase(settlement: TraceState.unavailable)), size);
        await tester.scrollUntilVisible(find.byKey(const ValueKey('stock-trace-payments-unavailable-ob-1')), 200, scrollable: find.byType(Scrollable).first);
        expect(find.text(_en.stockTracePaymentsUnavailable), findsOneWidget);
        expect(find.text(_en.stockTraceNoPayment), findsNothing);
      });

      testWidgets('a listed settlement with nothing recorded says no payment is recorded', (tester) async {
        await _open(tester, const StockMovementScreen(movementId: 'm-1'), _Trace(purchase: _purchase(paid: false)), size);
        await tester.scrollUntilVisible(find.byKey(const ValueKey('stock-trace-no-payment-ob-1')), 200, scrollable: find.byType(Scrollable).first);
        expect(find.byKey(const ValueKey('stock-trace-no-payment-ob-1')), findsOneWidget);
      });

      testWidgets('an order with no bill says no bill is linked; hidden bills are unavailable', (tester) async {
        await _open(tester, const StockMovementScreen(movementId: 'm-1'), _Trace(purchase: _purchase(bills: TraceState.notLinked)), size);
        await tester.scrollUntilVisible(find.byKey(const ValueKey('stock-trace-no-bill')), 200, scrollable: find.byType(Scrollable).first);
        expect(find.text(_en.stockTraceNoBill), findsOneWidget);
        await _open(tester, const StockMovementScreen(movementId: 'm-1'), _Trace(purchase: _purchase(bills: TraceState.unavailable)), size);
        await tester.scrollUntilVisible(find.byKey(const ValueKey('stock-trace-bills-unavailable')), 200, scrollable: find.byType(Scrollable).first);
        expect(find.text(_en.stockTraceNoBill), findsNothing);
      });

      testWidgets('the purchase side hidden from the reader, and no purchase recorded, are told apart', (tester) async {
        await _open(
          tester,
          const StockMovementScreen(movementId: 'm-1'),
          _Trace(purchase: const TracePurchase(state: TraceState.unavailable, billsState: TraceState.unavailable, bills: [], billsTruncated: false)),
          size,
        );
        await tester.scrollUntilVisible(find.byKey(const ValueKey('stock-trace-purchase-unavailable')), 200, scrollable: find.byType(Scrollable).first);
        expect(find.byKey(const ValueKey('stock-trace-not-linked')), findsNothing);
        await _open(tester, const StockMovementScreen(movementId: 'm-1'), _Trace(), size);
        await tester.scrollUntilVisible(find.byKey(const ValueKey('stock-trace-not-linked')), 200, scrollable: find.byType(Scrollable).first);
        expect(find.byKey(const ValueKey('stock-trace-purchase-unavailable')), findsNothing);
      });

      testWidgets('a failed read says so and asks again; it is never an empty trace', (tester) async {
        final trace = _Trace(purchase: _purchase(), fail: true);
        await _open(tester, const StockMovementScreen(movementId: 'm-1'), trace, size);
        await tester.scrollUntilVisible(find.byKey(const ValueKey('stock-trace-retry')), 200, scrollable: find.byType(Scrollable).first);
        await tester.ensureVisible(find.byKey(const ValueKey('stock-trace-retry')));
        await tester.pump();
        expect(find.byKey(const ValueKey('stock-trace-none')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('stock-trace-retry')));
        await tester.pumpAndSettle();
        expect(trace.traceCalls, 2);
        await tester.scrollUntilVisible(find.byKey(const ValueKey('stock-trace-order')), 200, scrollable: find.byType(Scrollable).first);
        expect(find.byKey(const ValueKey('stock-trace-order')), findsOneWidget);
      });

      testWidgets('the value totals the known cost, says it is not complete and lists the goods of unknown cost', (tester) async {
        await _open(tester, const StockValueScreen(), _Trace(valuationAnswer: _valuation()), size);
        expect(find.byKey(const ValueKey('stock-value-total')), findsOneWidget);
        expect(tester.widget<Text>(find.byKey(const ValueKey('stock-value-total'))).data, contains('20.00'));
        expect(find.byKey(const ValueKey('stock-value-incomplete')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-value-complete')), findsNothing);
        expect(find.byKey(const ValueKey('stock-value-uncosted-i-Biscuits-')), findsOneWidget, reason: 'listed by quantity, outside the total');
        expect(find.text(_en.stockValueBasis), findsOneWidget, reason: 'it says what it is');
      });

      testWidgets('a value with every cost known says it is complete', (tester) async {
        await _open(tester, const StockValueScreen(), _Trace(valuationAnswer: _valuation(complete: true)), size);
        expect(find.byKey(const ValueKey('stock-value-complete')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-value-incomplete')), findsNothing);
      });

      testWidgets('a list cut short says so', (tester) async {
        await _open(tester, const StockValueScreen(), _Trace(valuationAnswer: _valuation(truncated: true)), size);
        await tester.scrollUntilVisible(find.text(_en.stockTraceMore), 200, scrollable: find.byType(Scrollable).first);
        expect(find.text(_en.stockTraceMore), findsOneWidget);
      });

      testWidgets('a reader who may not see what goods cost is told so and nothing is read', (tester) async {
        final trace = _Trace(valuationAnswer: _valuation());
        await _open(tester, const StockValueScreen(), trace, size, held: {WorkspacePermission.viewStock});
        expect(find.byKey(const ValueKey('stock-value-needs-right')), findsOneWidget);
        expect(trace.valuationCalls, 0);
      });

      testWidgets('an order or bill lists the goods put away against it, a keyset page at a time', (tester) async {
        final trace = _Trace(pages: [
          DocumentGoods(state: TraceState.listed, rows: [_row('m-1', '1')], more: true, next: const {'page': 1}),
          DocumentGoods(state: TraceState.listed, rows: [_row('m-2', '1')], more: false),
        ]);
        await _open(tester, const Scaffold(body: StockDocumentGoodsBlock(workspaceId: 'w', kind: 'order', id: 'o-1')), trace, size);
        expect(find.byKey(const ValueKey('stock-goods-m-1')), findsOneWidget);
        expect(find.text(_en.stockGoodsRow('Water', _en.stockQuantityWithUnit('1', 'carton'), _en.stockQuantityWithUnit('24', 'piece'))), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-goods-m-2')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('stock-goods-more')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('stock-goods-m-2')), findsOneWidget);
        expect(trace.asked.last, {'page': 1}, reason: 'the cursor is sent back unchanged');
        expect(find.byKey(const ValueKey('stock-goods-more')), findsNothing);
      });

      testWidgets('goods the reader may not see are unavailable; a document with no recorded link says so', (tester) async {
        await _open(
          tester,
          const Scaffold(body: StockDocumentGoodsBlock(workspaceId: 'w', kind: 'bill', id: 'b-1')),
          _Trace(pages: [const DocumentGoods(state: TraceState.unavailable, rows: [], more: false)]),
          size,
        );
        expect(find.byKey(const ValueKey('stock-goods-unavailable')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-goods-none')), findsNothing);
        await _open(tester, const Scaffold(body: StockDocumentGoodsBlock(key: ValueKey('another'), workspaceId: 'w', kind: 'bill', id: 'b-2')), _Trace(), size);
        expect(find.byKey(const ValueKey('stock-goods-none')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-goods-unavailable')), findsNothing);
      });

      testWidgets('a failed goods read says so and asks again; it is never "no goods"', (tester) async {
        final trace = _Trace(docFail: true, pages: [DocumentGoods(state: TraceState.listed, rows: [_row('m-1', '1')], more: false)]);
        await _open(tester, const Scaffold(body: StockDocumentGoodsBlock(workspaceId: 'w', kind: 'order', id: 'o-1')), trace, size);
        expect(find.byKey(const ValueKey('stock-goods-failed')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-goods-none')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('stock-goods-retry')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('stock-goods-m-1')), findsOneWidget);
      });

      testWidgets('a failed value read says so and can be asked again', (tester) async {
        await _open(tester, const StockValueScreen(), _Trace(valuationFail: true), size);
        expect(find.byKey(const ValueKey('stock-value-failed')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-value-total')), findsNothing);
      });
    });
  }

  test('the model reads the server answer: states, cardinalities, truncation and exact amounts', () {
    final answer = StockTraceAnswer.fromJson({
      'truncated': true,
      'traces': [
        {
          'movement': {'movement_id': 'm', 'quantity': '24.000000', 'reason': 'receipt'},
          'lot': {'lot_id': 'l', 'lot_code': '', 'cost': {'state': 'unknown'}},
          'purchase': {
            'state': 'linked',
            'receipt': {'receipt_id': 'r', 'received_on': '2026-03-03'},
            'order': {'order_id': 'o', 'reference': '2026-0001', 'state': 'received', 'supplier_name': 'Water Co'},
            'bills': {
              'state': 'listed',
              'truncated': true,
              'items': [
                {
                  'bill_id': 'b',
                  'kind': 'bill',
                  'state': 'draft',
                  'original_reference': 'INV-1',
                  'currency': 'EUR',
                  'obligations_truncated': false,
                  'obligations': [
                    {
                      'obligation_id': 'ob',
                      'state': 'open',
                      'amount_cents': 1000,
                      'currency': 'EUR',
                      'settlement': {'state': 'unavailable', 'items': <Object?>[]},
                    },
                  ],
                },
              ],
            },
          },
        },
      ],
    });
    expect(answer.truncated, isTrue);
    final t = answer.traces.single;
    expect(t.quantity.text, '24');
    expect(t.cost?.state, 'unknown', reason: 'unknown is not zero');
    expect(t.purchase.state, TraceState.linked);
    expect(t.purchase.billsTruncated, isTrue);
    expect(t.purchase.bills.single.obligations.single.settlementState, TraceState.unavailable);
    expect(TraceState.of('nonsense'), TraceState.unknown, reason: 'a state this app does not know is no guess (#4401)');
    final v = StockValuation.fromJson({
      'cutoff': '2026-03-04T12:00:00Z',
      'calculated_at': '2026-03-04T12:01:00Z',
      'currency': 'EUR',
      'movements_counted': 5,
      'known_total_minor': 2000,
      'lines': const <Object?>[],
      'uncosted': [
        {'item_id': 'i', 'quantity': '24.000000', 'reason': 'no_lot'},
      ],
      'complete': false,
    });
    expect(v.knownTotalMinor, 2000);
    expect(v.uncosted.single.noLot, isTrue);
    expect(v.complete, isFalse);
  });
}
