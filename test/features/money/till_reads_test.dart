// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4492 — the tills' page and the day close answer a failed read as every
// other page does: the failure worded by its kind with Try again, which
// reads again; never the page of a business with no tills, and never "no
// day has been closed yet".
import 'dart:io';

import 'package:deskilo/features/money/domain/till_day.dart';
import 'package:deskilo/features/money/domain/till_drawer.dart';
import 'package:deskilo/features/money/presentation/till_drawer/till_day_screen.dart';
import 'package:deskilo/features/money/presentation/till_drawer/till_drawer_screen.dart';
import 'package:deskilo/features/money/providers/till_drawer_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/read_probe.dart';

final _en = AppLocalizationsEn();
const _failure = ValueKey('read-failure');

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('the tills that could not be read say so and are read again', (
    tester,
  ) async {
    final tills = ReadProbe<List<DrawerTill>>();
    await pumpStateScreen(
      tester,
      const TillDrawerScreen(workspaceId: 'ws-1', currency: 'EUR', canManage: false),
      overrides: [
        ...standardTestOverrides(),
        tillDrawerProvider.overrideWith((ref, workspaceId) => tills()),
      ],
    );
    await tester.pump();
    tills.fail(const SocketException('no route'));
    await _settle(tester);
    expect(find.byKey(_failure), findsOneWidget);
    expect(find.text(_en.readStateOffline), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('drawer-retry')));
    await tester.pump();
    expect(tills.calls, 2, reason: 'Try again reads the tills again');
    tills.answer(const []);
    await _settle(tester);
    // The page's own failure is gone (a part of the page reads for itself).
    expect(find.byKey(const ValueKey('drawer-retry')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the closed days that could not be read are not "no day has '
      'been closed yet"', (tester) async {
    final days = ReadProbe<List<DayCloseRow>>();
    await pumpStateScreen(
      tester,
      const TillDayScreen(workspaceId: 'ws-1', currency: 'EUR'),
      overrides: [
        ...standardTestOverrides(),
        dayClosesProvider.overrideWith((ref, workspaceId) => days()),
      ],
    );
    await tester.pump();
    days.fail(const SocketException('no route'));
    await _settle(tester);
    expect(find.byKey(_failure), findsOneWidget);
    expect(find.byKey(const ValueKey('day-none')), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('day-closes-retry')));
    await tester.tap(find.byKey(const ValueKey('day-closes-retry')));
    await tester.pump();
    expect(days.calls, 2, reason: 'Try again reads the closed days again');
    days.answer(const []);
    await _settle(tester);
    expect(find.byKey(_failure), findsNothing);
    expect(find.byKey(const ValueKey('day-none')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
