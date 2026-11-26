// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4366 / #4436 -- the seller chooses the lot a till line is sold from: the line sends the lot it was given (a line of
// named pieces sends its pieces, never a lot) and keeps it through a new quantity; the chooser lists the lots on hand
// with the one past its date shown and not offered, sets the lot chosen, and "the first to expire" leaves the choice to
// the server again; an item with no lot says so.
import 'dart:async';

import 'package:deskilo/core/demo/data/demo_till.dart';
import 'package:deskilo/core/demo/data/demo_till_lots.dart';
import 'package:deskilo/features/money/domain/counter_till.dart';
import 'package:deskilo/features/money/presentation/till_lot_choice.dart';
import 'package:deskilo/features/money/presentation/till_session.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();
const _lot = TillLot(id: 'lot-12', code: 'MILK-12', quantity: '6');

Future<TillSession> _open(WidgetTester tester, String itemId) async {
  final session = TillSession(port: DemoTill(country: 'FR', currency: 'EUR', vatPercent: 20), workspaceId: 'ws-1');
  await pumpApp(
    tester,
    Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          key: const ValueKey('choose'),
          onPressed: () => unawaited(chooseTillLot(context, DemoTillLots(clock: () => DateTime(2026, 11, 25)), session, 0)),
          child: const Text('choose'),
        ),
      ),
    ),
    overrides: standardTestOverrides(),
  );
  unawaited(session.add(itemId: itemId, name: itemId == 'demo-item-milk' ? 'Oat milk' : 'Mugs', unit: 'l'));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return session;
}

void main() {
  test('the line sends the lot it was given, keeps it, and a line of pieces sends its pieces', () {
    const line = TillLine(itemId: 'i', name: 'Oat milk', quantity: '1', unit: 'l');
    expect(line.withLot(_lot).toJson(), {'item_id': 'i', 'quantity': '1', 'lot_id': 'lot-12'});
    expect(line.withLot(_lot).withQuantity('2').toJson()['lot_id'], 'lot-12');
    expect(line.withLot(_lot).withLot(null).toJson().containsKey('lot_id'), isFalse);
    expect(line.withLot(_lot).withPiece('TAG-1').toJson().containsKey('lot_id'), isFalse, reason: 'a piece names its own lot');
    final read = tillLotsOf({'unit': 'l', 'lots': [{'lot_id': 'a', 'code': 'MILK-09', 'expires_on': '2026-11-19', 'expired': true, 'quantity': '2'}]});
    expect([read.single.code, read.single.expired, read.single.quantity, read.single.expiresOn], ['MILK-09', true, '2', DateTime(2026, 11, 19)]);
  });

  testWidgets('the chooser shows the lot past its date without offering it, and sets the one chosen', (tester) async {
    final session = await _open(tester, 'demo-item-milk');
    await tester.tap(find.byKey(const ValueKey('choose')));
    await tester.pumpAndSettle();
    expect(tester.widget<ListTile>(find.byKey(const ValueKey('till-lot-demo-lot-milk-09'))).enabled, isFalse);
    expect(find.textContaining(_en.tillLotExpired('Nov 19, 2026')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('till-lot-demo-lot-milk-12')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(session.state.value.lines.single.lot?.code, 'MILK-12');

    await tester.tap(find.byKey(const ValueKey('choose')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('till-lot-first')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(session.state.value.lines.single.lot, isNull, reason: 'the stock chooses again');
  });

  testWidgets('an item with no lot says so', (tester) async {
    await _open(tester, 'demo-item-mugs');
    await tester.tap(find.byKey(const ValueKey('choose')));
    await tester.pumpAndSettle();
    expect(find.text(_en.tillLotNone('Mugs')), findsOneWidget);
  });
}
