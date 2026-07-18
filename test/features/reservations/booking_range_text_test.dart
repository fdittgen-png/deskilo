// SPDX-License-Identifier: MIT
//
// Booking ranges as humans read them (field report: a full-day booking
// showed as '00:00 – 00:00') and the repetition modality (0034).
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/plan/domain/half_day_windows.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/presentation/widgets/reservation_detail_sheet.dart';
import 'package:deskilo/features/reservations/presentation/widgets/booking_range_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reserve_hub_test.dart' show pumpHub;

void main() {
  tearDown(WorkspaceTime.reset);

  group('bookingRangeText', () {
    final day = DateTime(2026, 7, 21);

    test('a full-day window reads Full day — never 00:00 – 00:00', () {
      WorkspaceTime.install('Europe/Paris');
      final w = HalfDayWindows.fullDay(day);
      expect(bookingRangeText(null, w.start, w.end), 'Full day');
    });

    test('the halves carry their names and a 24:00 end', () {
      WorkspaceTime.install('Europe/Paris');
      final am = HalfDayWindows.morning(day);
      final pm = HalfDayWindows.afternoon(day);
      expect(bookingRangeText(null, am.start, am.end),
          'Morning · 00:00 – 13:00');
      expect(bookingRangeText(null, pm.start, pm.end),
          'Afternoon · 13:00 – 24:00');
    });

    test('free ranges read from–to; an exact next-midnight end reads '
        '24:00', () {
      final nine = DateTime(2026, 7, 21, 9);
      final eleven = DateTime(2026, 7, 21, 11);
      expect(bookingRangeText(null, nine, eleven), '09:00 – 11:00');
      expect(
        bookingRangeText(null, nine, DateTime(2026, 7, 22)),
        '09:00 – 24:00',
      );
    });
  });

  group('repeatLabelText', () {
    test('stored patterns get their labels; unknown stays generic', () {
      expect(repeatLabelText(null, 'daily'), 'Every day');
      expect(repeatLabelText(null, 'weekdays'), 'Every weekday');
      expect(repeatLabelText(null, 'weekly'), 'Weekly');
      expect(repeatLabelText(null, null), 'Recurring booking');
    });
  });

  testWidgets('the detail sheet shows the date, the labeled window and '
      'the repetition modality', (tester) async {
    WorkspaceTime.install('Europe/Berlin');
    final now = DateTime.now();
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

    await tester.tap(find.text('Day'));
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
