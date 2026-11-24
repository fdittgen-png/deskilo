// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4434 (G19) -- "Where is it" as a person uses it, at a phone (390) and a desk (1440) width, over the Demo ledger: the places
// that hold the mugs add up to what the item holds, the goods on the road say from where to where, the pieces of the gift
// basket are listed with their tag, a past day is replayed from the movements (and says the pieces are not shown yet), and a
// failed read says so and can be asked again. The read itself: the answer is parsed as it comes and balances.
// #4432: a piece opens "Every movement of this piece", asked of the chain by the piece and nothing else.
import 'package:deskilo/core/demo/data/demo_stock_config_commands.dart';
import 'package:deskilo/core/demo/data/demo_stock_ledger.dart';
import 'package:deskilo/core/demo/data/demo_stock_tags.dart';
import 'package:deskilo/core/demo/data/demo_stock_where_is.dart';
import 'package:deskilo/features/stock/domain/stock_trace_chain.dart';
import 'package:deskilo/features/stock/domain/stock_where_is.dart';
import 'package:deskilo/features/stock/presentation/stock_where_is_screen.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

class _Failing implements StockWhereIs {
  int calls = 0;

  @override
  Future<WhereIsAnswer> whereIs(String workspaceId, String itemId, {String? lotId, DateTime? at}) async {
    calls++;
    throw StateError('unreachable');
  }
}

class _Chain implements StockTraceChainReader {
  final asked = <String>[];

  @override
  Future<TraceChain> chain(String workspaceId, {String? lotId, String? pieceId, String? movementId}) async {
    asked.add('lot=$lotId piece=$pieceId movement=$movementId');
    return const TraceChain(subject: 'piece', steps: []);
  }
}

Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

DemoStockWhereIs _demo() {
  final config = DemoStockConfigCommands('ws-1');
  return DemoStockWhereIs(DemoStockLedger('ws-1', config), DemoStockTags());
}

Future<void> _open(WidgetTester tester, StockWhereIs port, String itemId, Size size, {_Chain? chain}) async {
  await pumpApp(
    tester,
    StockWhereIsScreen(itemId: itemId),
    size: size,
    overrides: [
      ...standardTestOverrides(),
      stockWhereIsProvider.overrideWithValue(port),
      stockTraceChainReaderProvider.overrideWithValue(chain ?? _Chain()),
    ],
  );
  await _frames(tester);
}

void main() {
  for (final (name, size) in [('phone', const Size(390, 844)), ('desk', const Size(1440, 900))]) {
    group('on a $name', () {
      testWidgets('the mugs: every place with its quantity, the road with its from and to, and what the places add up to', (tester) async {
        await _open(tester, _demo(), 'demo-item-mugs', size);
        expect(find.text('Mugs'), findsWidgets);
        expect(find.byKey(const ValueKey('stock-where-on-hand')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-where-now')), findsOneWidget);
        final answer = await _demo().whereIs('ws-1', 'demo-item-mugs');
        expect(answer.balances, isTrue, reason: 'the real places add up to what the item holds');
        expect(answer.places, isNotEmpty);
        for (final p in answer.real) {
          expect(find.byKey(ValueKey('stock-where-place-${p.locationId}--${p.lotId ?? ''}')), findsOneWidget);
        }
        expect(answer.transit, isNotEmpty, reason: 'six mugs are on the road in the Demo');
        expect(find.text(_en.stockWhereIsTransit), findsOneWidget);
        expect(find.text(_en.stockWhereIsTransitLine(answer.transit!.first.fromCode, answer.transit!.first.toCode)), findsOneWidget);
      });

      testWidgets('the gift basket: its pieces are listed with their tag', (tester) async {
        await _open(tester, _demo(), 'demo-item-basket', size);
        expect(find.text(_en.stockWhereIsPieces), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-where-piece-demo-piece-1')), findsOneWidget);
        expect(find.textContaining('E2801160600002054AF3E001'), findsOneWidget);
      });

      testWidgets('a piece opens every movement of that piece, asked by the piece alone', (tester) async {
        final chain = _Chain();
        await _open(tester, _demo(), 'demo-item-basket', size, chain: chain);
        final open = find.byKey(const ValueKey('stock-where-piece-chain-demo-piece-1'));
        await tester.ensureVisible(open);
        await tester.tap(open);
        await _frames(tester);
        expect(find.byKey(const ValueKey('stock-chain-sheet')), findsOneWidget);
        expect(find.text(_en.stockChainPieceTitle), findsOneWidget);
        expect(chain.asked, ['lot=null piece=demo-piece-1 movement=null']);
        expect(find.byKey(const ValueKey('stock-chain-empty')), findsOneWidget);
      });

      testWidgets('a failed read says so and asks again; it is never an empty list', (tester) async {
        final port = _Failing();
        await _open(tester, port, 'demo-item-mugs', size);
        expect(find.byKey(const ValueKey('stock-where-failed')), findsOneWidget);
        expect(find.byKey(const ValueKey('stock-where-nowhere')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('stock-where-retry')));
        await _frames(tester);
        expect(port.calls, 2);
      });
    });
  }

  test('a past day is replayed from the movements: before the first booking nothing is held, and the pieces are not claimed', () async {
    final port = _demo();
    final long = await port.whereIs('ws-1', 'demo-item-basket', at: DateTime(2000));
    expect(long.places, isEmpty);
    expect(long.onHand, isNotNull);
    expect(long.balances, isTrue);
    expect(long.pieces, isNull);
    expect(long.transit, isNull);
    final now = await port.whereIs('ws-1', 'demo-item-mugs');
    final today = await port.whereIs('ws-1', 'demo-item-mugs', at: DateTime.utc(2100));
    expect(today.onHand, now.onHand, reason: 'replayed at this moment the movements give the balances');
  });

  test('the answer of the server is read as it comes: places, road, documents, pieces, and the balance', () {
    final a = WhereIsAnswer.fromJson({
      'item': {'id': 'i1', 'name': 'Mugs', 'unit': 'piece'},
      'lot_id': null,
      'as_of': null,
      'on_hand': '9.000000',
      'places': [
        {'location_id': 'a', 'location_code': 'MAIN', 'location_name': '', 'location_kind': 'warehouse', 'virtual': false, 'variant_id': null, 'variant_label': null, 'lot_id': 'l1', 'lot_code': 'L-1', 'expires_on': null, 'quantity': '7.000000'},
        {'location_id': 'b', 'location_code': 'TRANSIT', 'location_name': '', 'location_kind': 'in_transit', 'virtual': false, 'variant_id': null, 'variant_label': null, 'lot_id': 'l1', 'lot_code': 'L-1', 'expires_on': null, 'quantity': '2.000000'},
        {'location_id': 'c', 'location_code': 'LOSS', 'location_name': '', 'location_kind': 'loss', 'virtual': true, 'variant_id': null, 'variant_label': null, 'lot_id': 'l1', 'lot_code': 'L-1', 'expires_on': null, 'quantity': '1.000000'},
      ],
      'transit': [
        {'transfer_id': 't', 'from_location_code': 'MAIN', 'to_location_code': 'ANNEX', 'variant_id': null, 'lot_id': 'l1', 'quantity': '2.000000'},
      ],
      'documents': [
        {'movement_id': 'm', 'reason': 'loss', 'occurred_at': '2026-11-22T10:00:00+00:00', 'from_location_code': 'MAIN', 'to_location_code': 'LOSS', 'quantity': '1.000000', 'invoice_id': null, 'event_id': null, 'receipt_line_id': null, 'purchase_line_id': null},
      ],
      'pieces': <Object?>[],
      'pieces_more': false,
    });
    expect(a.balances, isTrue);
    expect(a.real.length, 2);
    expect(a.transit!.single.toCode, 'ANNEX');
    expect(a.documents.single.reason, 'loss');
    expect(a.pieces, isEmpty);
  });
}
