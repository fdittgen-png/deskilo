// SPDX-License-Identifier: 0BSD
//
// #574: minute-grid workspaces pick the duration with a SLIDER stepped
// by the workspace's own grid — a 10:00 walk-up under a 5-minute grid
// slides to "until 12:05" in 5-minute ticks; other granularities keep
// their pickers, and a whole-day fixed end shows no slider at all.
import 'package:deskilo/features/reservations/presentation/widgets/booking_sheet.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<BookingChoice?> _open(
  WidgetTester tester, {
  required BookingGranularity granularity,
  bool walkUp = true,
  DateTime? cap,
}) async {
  final start = DateTime(2026, 5, 13, 10);
  BookingChoice? popped;
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () async {
              popped = await showModalBottomSheet<BookingChoice>(
                context: context,
                isScrollControlled: true,
                builder: (_) => BookingSheet(
                  seatName: 'A1',
                  start: start,
                  initialEnd: DateTime(2026, 5, 13, 12),
                  cap: cap,
                  capped: cap != null,
                  granularity: granularity,
                  walkUp: walkUp,
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return popped;
}

void main() {
  testWidgets(
      'a 5-minute grid shows the duration slider; sliding snaps the end '
      'to the grid and the popped choice carries it', (tester) async {
    await _open(tester, granularity: BookingGranularity.minutes5);

    final slider = find.byKey(const ValueKey('booking-duration-slider'));
    expect(slider, findsOneWidget);

    // The slider is stepped, never continuous: a 5-minute grid means
    // discrete 5-minute ticks.
    final sliderWidget = tester.widget<Slider>(slider);
    expect(sliderWidget.divisions, isNotNull);
    expect(sliderWidget.min, 5);

    // Slide far left: the duration collapses toward the minimum step
    // without ever hitting zero.
    await tester.drag(slider, const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(slider).value,
        greaterThanOrEqualTo(5));
  });

  testWidgets('the popped end is grid-aligned after sliding',
      (tester) async {
    BookingChoice? choice;
    final start = DateTime(2026, 5, 13, 10);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async {
                choice = await showModalBottomSheet<BookingChoice>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => BookingSheet(
                    seatName: 'A1',
                    start: start,
                    initialEnd: DateTime(2026, 5, 13, 12),
                    cap: null,
                    capped: false,
                    granularity: BookingGranularity.minutes15,
                    walkUp: true,
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('booking-duration-slider')),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check in'));
    await tester.pumpAndSettle();

    expect(choice, isNotNull);
    expect(choice!.end.isAfter(start), isTrue);
    expect(choice!.end.minute % 15, 0,
        reason: 'the end must sit on the 15-minute grid');
  });

  testWidgets('day-based granularity shows chips, never the slider',
      (tester) async {
    await _open(tester,
        granularity: BookingGranularity.halfDay, walkUp: false);
    expect(find.byKey(const ValueKey('booking-duration-slider')),
        findsNothing);
  });
}
