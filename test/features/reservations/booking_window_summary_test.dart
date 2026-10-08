// SPDX-License-Identifier: AGPL-3.0-or-later
// The selected booking window stays readable after a real period change,
// at narrow widths, and across workspace DST with personal timezone preferences.
import 'package:deskilo/core/i18n/app_format.dart';
import 'package:deskilo/core/i18n/format_controller.dart';
import 'package:deskilo/core/i18n/format_prefs.dart';
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/plan/domain/half_day_windows.dart';
import 'package:deskilo/features/reservations/presentation/widgets/booking_window_summary.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reserve_hub_test.dart';

void main() {
  testWidgets('period selection updates a visible date, name, hours and zone', (
    tester,
  ) async {
    await pumpHub(
      tester,
      granularity: BookingGranularity.halfDay,
      size: const Size(360, 800),
    );
    await tester.tap(find.byKey(const ValueKey('reserve-am-chip')));
    await tester.pumpAndSettle();
    final summary = tester
        .widget<Text>(find.byKey(const ValueKey('booking-window-summary')))
        .data!;
    expect(summary, contains('Today'));
    expect(summary, contains('Morning'));
    expect(summary, contains('Europe/Berlin'));
    await tester.tap(find.byKey(const ValueKey('reserve-pm-chip')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('booking-window-summary')))
          .data,
      contains('Afternoon'),
    );
    expect(tester.takeException(), isNull);
  });

  for (final day in [DateTime(2026, 3, 29), DateTime(2026, 10, 25)]) {
    testWidgets(
      'workspace DST window remains explicit with personal timezone on $day',
      (tester) async {
        WorkspaceTime.install('Europe/Berlin');
        addTearDown(WorkspaceTime.reset);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appFormatProvider.overrideWithValue(
                const AppFormat(
                  locale: 'en_US',
                  currencyCode: 'EUR',
                  clock: ClockPref.h24,
                  timeZoneMode: TimeZoneMode.device,
                ),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: BookingWindowSummary(
                  window: HalfDayWindows.morning(day),
                  today: DateTime(day.year, day.month, day.day - 1),
                  timezone: 'Europe/Berlin',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final summary = tester
            .widget<Text>(find.byKey(const ValueKey('booking-window-summary')))
            .data!;
        expect(summary, contains('Tomorrow'));
        expect(summary, contains('08:00–12:00'));
        expect(summary, contains('Workspace time'));
        expect(summary, contains('Europe/Berlin'));
        expect(summary, contains('Your time'));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
