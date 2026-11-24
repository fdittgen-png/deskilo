// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4432 (G18) -- "Every movement of this lot" on a movement's page: the steps in order with their places, pieces and
// documents; a document the reader may not see is said, never left out; the current movement is marked and the
// others open their own page; a cut-short chain says so; a failed read is asked again and is never an empty chain.
// The answer of 0923 is read as the server writes it. At phone and desk width.
import 'package:deskilo/features/stock/domain/stock_trace_chain.dart';
import 'package:deskilo/features/stock/presentation/stock_chain_section.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

/// What 0923 answers for a lot received against an order, moved, then sold at the counter.
const _answer = {
  'subject': 'movement',
  'lot': {'id': 'lot-1', 'code': 'L-24'},
  'steps': [
    {'movement_id': 'm-1', 'at': '2026-11-20T09:00:00Z', 'reason': 'receipt', 'quantity': 3,
     'from': {'code': 'SUPPLIER', 'kind': 'supplier'}, 'to': {'code': 'MAIN', 'kind': 'store'}, 'pieces': 3,
     'document': {'kind': 'delivery', 'id': 'r-1', 'label': 'PO-0007', 'supplier': 'Alpha'}},
    {'movement_id': 'm-2', 'at': '2026-11-21T09:00:00Z', 'reason': 'transfer', 'quantity': 2,
     'from': {'code': 'MAIN'}, 'to': {'code': 'FLOOR'}, 'pieces': 2},
    {'movement_id': 'm-3', 'at': '2026-11-22T09:00:00Z', 'reason': 'sale', 'quantity': 1,
     'from': {'code': 'FLOOR'}, 'to': {'code': 'CUSTOMER'}, 'pieces': 1,
     'document': {'kind': 'counter_receipt', 'state': 'unavailable'}},
  ],
  'truncated': true,
};

class _Reader implements StockTraceChainReader {
  _Reader({this.fail = false});

  bool fail;
  int calls = 0;

  @override
  Future<TraceChain> chain(String workspaceId, {String? lotId, String? pieceId, String? movementId}) async {
    calls++;
    if (fail) throw StateError('offline');
    return TraceChain.fromJson(_answer);
  }
}

Future<void> _pump(WidgetTester tester, _Reader reader, Size size) => pumpApp(
  tester,
  const Scaffold(body: SingleChildScrollView(child: StockChainSection(workspaceId: 'ws-1', movementId: 'm-2'))),
  size: size,
  overrides: [stockTraceChainReaderProvider.overrideWithValue(reader)],
);

void main() {
  test('the answer of 0923 is read with its places, pieces, documents and the cut-short flag', () {
    final chain = TraceChain.fromJson(_answer);
    expect(chain.lotCode, 'L-24');
    expect(chain.steps.map((s) => '${s.reason} ${s.fromCode}>${s.toCode} ${s.quantity.text} ${s.pieces}'),
        ['receipt SUPPLIER>MAIN 3 3', 'transfer MAIN>FLOOR 2 2', 'sale FLOOR>CUSTOMER 1 1']);
    expect(chain.steps.first.document!.label, 'PO-0007');
    expect(chain.steps.last.document!.available, isFalse, reason: 'a document the reader may not see is still named by its kind');
    expect(chain.truncated, isTrue);
  });

  for (final (name, size) in [('phone', const Size(390, 1600)), ('desk', const Size(1440, 1600))]) {
    group('on a $name', () {
      testWidgets('the chain lists every step with its words, and what may not be seen is said', (tester) async {
        await _pump(tester, _Reader(), size);
        await tester.pumpAndSettle();
        expect(find.text('${_en.stockMoveReasonReceipt} · SUPPLIER → MAIN · 3'), findsOneWidget);
        expect(find.textContaining(_en.stockChainDelivery('PO-0007', 'Alpha')), findsOneWidget);
        expect(find.textContaining(_en.stockChainPieces(2)), findsOneWidget);
        expect(find.textContaining(_en.stockChainUnavailable), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-chain-truncated')), findsOneWidget);
        expect(tester.widget<ListTile>(find.byKey(const ValueKey('stock-chain-step-m-2'))).selected, isTrue,
            reason: 'the movement on screen is marked');
        expect(tester.widget<ListTile>(find.byKey(const ValueKey('stock-chain-step-m-2'))).onTap, isNull);
        expect(tester.widget<ListTile>(find.byKey(const ValueKey('stock-chain-step-m-1'))).onTap, isNotNull);
      });

      testWidgets('a failed read is asked again, never shown as an empty chain', (tester) async {
        final reader = _Reader(fail: true);
        await _pump(tester, reader, size);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('stock-chain-failed')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-chain-empty')), findsNothing);
        reader.fail = false;
        await tester.tap(find.byKey(const ValueKey('stock-chain-retry')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('stock-chain-step-m-3')), findsOneWidget);
        expect(reader.calls, 2);
      });
    });
  }
}
