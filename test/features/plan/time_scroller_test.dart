// SPDX-License-Identifier: MIT
import 'package:deskilo/core/theme/seat_state_colors.dart';
import 'package:deskilo/features/plan/presentation/widgets/floor_plan_painter.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'plan_screen_test.dart' show foreignReservation, pumpPlan, seatCenter;

/// Taps the header time chip [chipKey] ('plan-from-chip'/'plan-to-chip'),
/// switches the Material time picker to keyboard input mode (the reliable
/// widget-test path — dragging the clock dial is not) and enters the time.
/// [hour] is 24-hour; the dialog runs in 12-hour AM/PM mode under
/// flutter_test (the pumped tree's View resolves the real platform
/// dispatcher, so `alwaysUse24HourFormatTestValue` never reaches it) —
/// the helper converts and taps the meridiem button.
Future<void> pickChipTime(
  WidgetTester tester,
  String chipKey, {
  required String hour,
  required String minute,
}) async {
  await tester.tap(find.byKey(ValueKey(chipKey)));
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.keyboard_outlined));
  await tester.pumpAndSettle();
  final h24 = int.parse(hour);
  final isPm = h24 >= 12;
  var h12 = h24 % 12;
  if (h12 == 0) h12 = 12;
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.first, '$h12');
  await tester.enterText(fields.last, minute);
  await tester.tap(find.text(isPm ? 'PM' : 'AM'));
  await tester.pump();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

/// The painter of the live plan canvas.
FloorPlanPainter planPainter(WidgetTester tester) {
  final paint = tester
      .widget<CustomPaint>(find.byKey(const ValueKey('live-plan-canvas')));
  return paint.painter! as FloorPlanPainter;
}

/// Text currently shown on a header time chip.
String chipText(WidgetTester tester, String chipKey) {
  final chip = find.byKey(ValueKey(chipKey));
  final text = tester
      .widget<Text>(find.descendant(of: chip, matching: find.byType(Text)));
  return text.data!;
}

void main() {
  testWidgets('picking a future from time books a reservation, not a walk-up',
      (tester) async {
    final env = await pumpPlan(tester);

    // From-chip pick → browse mode; the default 4h window clamps to the
    // day's last slot: 23:00 → 23:45.
    await pickChipTime(tester, 'plan-from-chip', hour: '23', minute: '00');
    expect(chipText(tester, 'plan-from-chip'), '23:00');
    expect(chipText(tester, 'plan-to-chip'), '23:45');

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    expect(find.textContaining('Starts at 23:00'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Reserve'));
    await tester.pumpAndSettle();

    final created = env.reservations.reservations.single;
    expect(created.status, ReservationStatus.reserved);
    expect(created.checkedInAt, isNull);
    expect(created.startsAt.hour, 23);
    expect(created.startsAt.minute, 0);
    expect(created.endsAt.hour, 23);
    expect(created.endsAt.minute, 45);
  });

  testWidgets('Now snaps back to live mode', (tester) async {
    await pumpPlan(tester);

    await pickChipTime(tester, 'plan-from-chip', hour: '23', minute: '00');
    await tester.tap(find.text('Now'));
    await tester.pumpAndSettle();

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    expect(find.textContaining('Starts now'), findsOneWidget);
  });

  testWidgets('a to-chip pick from live mode enters browsing from snapped now',
      (tester) async {
    await pumpPlan(tester);

    await pickChipTime(tester, 'plan-to-chip', hour: '23', minute: '45');

    // Browse mode entered: the Now button is tappable again …
    final nowButton =
        tester.widget<TextButton>(find.widgetWithText(TextButton, 'Now'));
    expect(nowButton.onPressed, isNotNull);
    expect(chipText(tester, 'plan-to-chip'), '23:45');

    // … and a seat tap opens a future reservation, not a walk-up.
    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    expect(find.textContaining('Starts at'), findsOneWidget);
  });

  testWidgets('booking sheet opens on the browsed window end', (tester) async {
    await pumpPlan(tester);

    await pickChipTime(tester, 'plan-from-chip', hour: '9', minute: '00');
    await pickChipTime(tester, 'plan-to-chip', hour: '12', minute: '00');
    expect(chipText(tester, 'plan-to-chip'), '12:00');

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    expect(find.textContaining('Starts at 09:00'), findsOneWidget);
    final until = find.widgetWithText(ListTile, 'Until');
    expect(
      find.descendant(of: until, matching: find.text('12:00')),
      findsOneWidget,
    );
  });

  testWidgets('an end pick at/before the start is rejected with a snackbar',
      (tester) async {
    await pumpPlan(tester);

    await pickChipTime(tester, 'plan-from-chip', hour: '9', minute: '00');
    expect(chipText(tester, 'plan-to-chip'), '13:00');

    await pickChipTime(tester, 'plan-to-chip', hour: '8', minute: '00');

    expect(find.text('End must be after start.'), findsOneWidget);
    // The invalid pick did not apply — no silent next-day roll-over.
    expect(chipText(tester, 'plan-from-chip'), '09:00');
    expect(chipText(tester, 'plan-to-chip'), '13:00');
  });

  testWidgets(
      'a reservation 10:00–11:00 renders occupied for the 09:00–12:00 '
      'window but free for 11:00–12:00', (tester) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, 10);
    await pumpPlan(
      tester,
      seedReservations: (repo) => repo.reservations.add(
        Reservation(
          id: 'res-mid',
          workspaceId: 'ws-1',
          seatId: 'seat-4',
          memberId: 'member-2',
          startsAt: start,
          endsAt: start.add(const Duration(hours: 1)),
          status: ReservationStatus.checkedIn,
        ),
      ),
    );

    await pickChipTime(tester, 'plan-from-chip', hour: '9', minute: '00');
    await pickChipTime(tester, 'plan-to-chip', hour: '12', minute: '00');
    expect(planPainter(tester).seatStates?['seat-4'], SeatState.occupied);

    // Window starting exactly at the reservation end → free (end exclusive).
    await pickChipTime(tester, 'plan-from-chip', hour: '11', minute: '00');
    await pickChipTime(tester, 'plan-to-chip', hour: '12', minute: '00');
    expect(chipText(tester, 'plan-from-chip'), '11:00');
    expect(chipText(tester, 'plan-to-chip'), '12:00');
    expect(planPainter(tester).seatStates?['seat-4'], SeatState.free);
  });

  testWidgets('list view shows every seat with its live state (#104)',
      (tester) async {
    await pumpPlan(
      tester,
      seedReservations: (repo) =>
          repo.reservations.add(foreignReservation()),
    );

    await tester.tap(find.byIcon(Icons.list));
    await tester.pumpAndSettle();

    expect(find.text('A1'), findsOneWidget);
    expect(find.textContaining('Reserved by Ana Lima'), findsOneWidget);
  });

  testWidgets('list view shows free seats instead of an empty page',
      (tester) async {
    await pumpPlan(tester);

    await tester.tap(find.byIcon(Icons.list));
    await tester.pumpAndSettle();

    expect(find.text('A1'), findsOneWidget);
    expect(find.textContaining('Free'), findsOneWidget);
  });
}
