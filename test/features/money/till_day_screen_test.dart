// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4367 (CS5) -- the day close at a phone and at a desk: refused while a till is open (naming it), then one numbered report
// with each session's difference and reason, listed afterwards among the closed days and opened again from the list.
import 'package:deskilo/core/demo/data/demo_till_drawer.dart';
import 'package:deskilo/features/money/domain/till_drawer.dart';
import 'package:deskilo/features/money/presentation/till_drawer/till_day_screen.dart';
import 'package:deskilo/features/money/providers/till_drawer_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.tap(find.byKey(ValueKey(key)));
  await _settle(tester);
}

void main() {
  for (final size in const [Size(390, 844), Size(1440, 900)]) {
    testWidgets('the day close at ${size.width.toInt()}: refused while a till is open, then reported', (tester) async {
      final drawer = DemoTillDrawer()..canSeeFinances = () => true;
      final open = await drawer.openSession('ws-1', requestId: 'o', tillId: 'demo-till-front', floatMinor: 10000);
      await pumpApp(
        tester,
        const TillDayScreen(workspaceId: 'ws-1', currency: 'EUR'),
        size: size,
        overrides: [tillDrawerPortProvider.overrideWithValue(drawer)],
      );
      await _settle(tester);
      expect(find.byKey(const ValueKey('day-none')), findsOneWidget);
      await _tap(tester, 'day-close');
      expect(find.text(_en.tillDayRefusalTillOpen('Front counter')), findsOneWidget);

      await drawer.closeSession('ws-1', requestId: 'c', sessionId: open.sessionId, count: const DrawerCount(countedMinor: 9900, differenceReason: 'counting_error', bankedMinor: 0));
      await _tap(tester, 'day-close');
      expect(find.byKey(const ValueKey('day-report')), findsOneWidget);
      expect(find.byKey(const ValueKey('day-session-Front counter')), findsOneWidget);
      expect(find.text(_en.tillDaySessionReason(_en.tillCashReasonCountingError)), findsOneWidget);
      expect(find.textContaining('-€1.00'), findsWidgets);
      await _tap(tester, 'day-report-close');
      expect(find.byKey(const ValueKey('day-none')), findsNothing);

      // the closed day is listed and opens again from the list
      await tester.tap(find.byType(ListTile).first);
      await _settle(tester);
      expect(find.byKey(const ValueKey('day-report')), findsOneWidget);
    });
  }
}
