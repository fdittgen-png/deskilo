// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1301 S2 — Day, Week and Month live behind the Reserve hub's View menu.
// Opens it and chooses [view] ('plan', 'day', 'week', 'month'); the caller
// settles afterwards, exactly as it did after tapping a segment.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pickReserveView(WidgetTester tester, String view) async {
  await tester.tap(find.byKey(const ValueKey('reserve-view-switch')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('reserve-view-$view')).last);
}
