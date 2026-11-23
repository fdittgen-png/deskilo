// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4359 (G10) -- a scanner that types, in the Demo's goods business through the real routed app at a phone and a
// desk width: the owner opens a move, a handheld scans the place the goods are taken from, the place they go to,
// then an item by its barcode and again by its carton code (12 pieces), and the move that results is the one the
// sheet's own button makes. The scans are simulated keyboard input: every character at once, then Enter.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/core/demo/demo_link.dart';
import 'package:deskilo/core/demo/demo_space_ids.dart';
import 'package:deskilo/features/stock/providers/stock_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_journey.dart';

final _en = AppLocalizationsEn();

Future<ProviderContainer> _open(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final journey = DemoJourney.start();
  addTearDown(journey.dispose);
  journey.root.read(pendingDemoLinkProvider.notifier).hold(DemoLink.parse({'space': 'pezenas', 'persona': 'owner', 'to': '/stock'}));
  await tester.pumpWidget(UncontrolledProviderScope(container: journey.root, child: const DeskiloRoot()));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(DeskiloApp)));
}

Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _scan(WidgetTester tester, String code) async {
  for (final ch in code.split('')) {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA, character: ch);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
  }
  await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
  await _frames(tester);
}

void main() {
  for (final (name, size) in [('phone', const Size(390, 2400)), ('desk', const Size(1440, 2400))]) {
    testWidgets('on a $name: scan the place, the next place, then the items: a carton counts 12 pieces', (tester) async {
      final container = await _open(tester, size);
      container.read(routerProvider).go('/stock/transfers');
      await _frames(tester);
      await tester.tap(find.byKey(const ValueKey('stock-move-open')));
      await _frames(tester);
      await _scan(tester, 'MAIN');
      await _scan(tester, 'SHELF-A');
      expect(find.byKey(const ValueKey('stock-scan-place')), findsOneWidget);
      await _scan(tester, '4006381333931');
      await _scan(tester, 'MUG-CARTON');
      expect(find.text(_en.stockScanLast('Mugs', '13', 'piece')), findsOneWidget, reason: 'a piece and a carton of twelve');
      final before = (await container.read(stockQueriesProvider).movementsPage(demoFirstSpaceId)).rows.length;
      await tester.ensureVisible(find.byKey(const ValueKey('stock-move-submit')));
      await tester.tap(find.byKey(const ValueKey('stock-move-submit')));
      await _frames(tester);
      final moves = (await container.read(stockQueriesProvider).movementsPage(demoFirstSpaceId)).rows;
      expect(moves.length, greaterThan(before), reason: 'the sheet moved the goods the scans filled in');
      expect(moves.first.reason, 'transfer');
    });
  }
}
