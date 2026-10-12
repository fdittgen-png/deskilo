// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Booking ranges as humans read them (field report: a full-day booking
// showed as '00:00 – 00:00') and the repetition modality (0034).
import 'package:deskilo/core/i18n/app_format.dart';
import 'package:deskilo/core/i18n/format_prefs.dart';
import 'package:deskilo/core/l10n/context_l10n.dart';
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/plan/domain/half_day_windows.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/presentation/widgets/booking_range_text.dart';
import 'package:deskilo/features/reservations/presentation/widgets/reservation_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/reserve_view.dart';
import '../../helpers/test_clock.dart';
import 'reserve_hub_test.dart' show pumpHub;

void main() {
  tearDown(WorkspaceTime.reset);

  group('bookingRangeText', () {
    final day = DateTime(2026, 7, 21);

    test('a full-day window reads Full day — never 00:00 – 00:00', () {
      WorkspaceTime.install('Europe/Paris');
      final w = HalfDayWindows.fullDay(day);
      expect(bookingRangeText(null, const AppFormat(locale: 'en_US', currencyCode: 'EUR', clock: ClockPref.h24), englishL10n, w.start, w.end), 'Full day');
    });

    test('the halves carry their names and the configured working hours '
        '(#446 defaults)', () {
      WorkspaceTime.install('Europe/Paris');
      final am = HalfDayWindows.morning(day);
      final pm = HalfDayWindows.afternoon(day);
      expect(bookingRangeText(null, const AppFormat(locale: 'en_US', currencyCode: 'EUR', clock: ClockPref.h24), englishL10n, am.start, am.end),
          'Morning · 08:00 – 12:00');
      expect(bookingRangeText(null, const AppFormat(locale: 'en_US', currencyCode: 'EUR', clock: ClockPref.h24), englishL10n, pm.start, pm.end),
          'Afternoon · 12:00 – 17:00');
    });

    test('free ranges read from–to; an exact next-midnight end reads '
        '24:00', () {
      final nine = DateTime(2026, 7, 21, 9);
      final eleven = DateTime(2026, 7, 21, 11);
      expect(bookingRangeText(null, const AppFormat(locale: 'en_US', currencyCode: 'EUR', clock: ClockPref.h24), englishL10n, nine, eleven), '09:00 – 11:00');
      expect(
        bookingRangeText(null, const AppFormat(locale: 'en_US', currencyCode: 'EUR', clock: ClockPref.h24), englishL10n, nine, DateTime(2026, 7, 22)),
        '09:00 – 24:00',
      );
    });
  });

  group('repeatLabelText', () {
    test('stored patterns get their labels; unknown stays generic', () {
      expect(repeatLabelText(englishL10n, 'daily'), 'Every day');
      expect(repeatLabelText(englishL10n, 'weekdays'), 'Every weekday');
      expect(repeatLabelText(englishL10n, 'weekly'), 'Weekly');
      expect(repeatLabelText(englishL10n, null), 'Recurring booking');
    });
  });

  testWidgets('the detail sheet shows the date, the labeled window and '
      'the repetition modality', (tester) async {
    WorkspaceTime.install('Europe/Berlin');
    final now = kTestNow;
    final today = DateTime(now.year, now.month, now.day);
    final window = HalfDayWindows.fullDay(today);
    await pumpHub(tester, seed: [
      Reservation(
        id: 'res-own',
        workspaceId: 'ws-1',
        seatId: 'seat-4',
        memberId: 'member-1',
        seriesId: 'series-1',
        seriesPattern: 'weekly',
        startsAt: window.start,
        endsAt: window.end,
        status: ReservationStatus.reserved,
      ),
    ]);

    await pickReserveView(tester, 'day');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('timeline-block-res-own')));
    await tester.pumpAndSettle();

    // Period, never 00:00 – 00:00…
    expect(find.textContaining('Full day'), findsOneWidget);
    expect(find.textContaining('00:00 – 00:00'), findsNothing);
    // …and how it repeats.
    expect(find.byType(ReservationDetailSheet), findsOneWidget);
    expect(find.text('Weekly'), findsOneWidget);
  });
}
