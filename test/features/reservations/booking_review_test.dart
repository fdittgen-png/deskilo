// SPDX-License-Identifier: AGPL-3.0-or-later
// The booking decision names its resource, person and exact window before
// ratings; mode changes are visible, and confirmation stays reachable.
import 'package:deskilo/features/reservations/presentation/widgets/booking_sheet.dart';
import 'package:deskilo/features/reservations/presentation/widgets/place_feedback_bar.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'reserve_hub_test.dart';

void main() {
  testWidgets(
    'real seat entry names its context before feedback and keeps confirm visible',
    (tester) async {
      await pumpHub(tester, size: const Size(360, 640));
      await tester.tapAt(seatCenter(tester));
      await tester.pumpAndSettle();
      final resource = find.byKey(const ValueKey('booking-review-resource'));
      final text = tester.widget<Text>(resource).data!;
      expect(text, contains('Ground floor'));
      expect(text, contains('Window desk'));
      expect(text, contains('A1'));
      expect(
        find.byKey(const ValueKey('booking-charge-context')),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(resource).dy,
        lessThan(tester.getTopLeft(find.byType(PlaceFeedbackBar)).dy),
      );
      final confirm = find.byKey(const ValueKey('booking-confirm'));
      expect(tester.getRect(confirm).bottom, lessThanOrEqualTo(640));
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.byType(BookingSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'future/now switching reviews the actual window and the chosen person',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final now = DateTime(2026, 5, 13, 10);
      final future = DateTime(2026, 5, 14, 8);
      BookingChoice? choice;
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                child: const Text('open'),
                onPressed: () async {
                  choice = await showModalBottomSheet<BookingChoice>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => BookingSheet(
                      seatName: 'Room 1',
                      resourceContext: const ['Demo', 'Ground floor'],
                      timezone: 'Europe/Berlin',
                      start: future,
                      initialEnd: DateTime(2026, 5, 14, 12),
                      cap: null,
                      capped: false,
                      walkUp: false,
                      now: now,
                      fixedEnd: true,
                      granularity: BookingGranularity.halfDay,
                      walkUpOption: (
                        start: now,
                        end: DateTime(2026, 5, 13, 12),
                        cap: null,
                        capped: false,
                      ),
                      myMemberId: 'flo',
                      members: const [
                        (id: 'flo', name: 'Flo'),
                        (id: 'ana', name: 'Ana'),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      String summary() => tester
          .widget<Text>(find.byKey(const ValueKey('booking-window-summary')))
          .data!;
      expect(summary(), contains('Tomorrow'));
      await tester.tap(find.byKey(const ValueKey('booking-mode-check-in')));
      await tester.pumpAndSettle();
      expect(summary(), contains('Today'));
      await tester.tap(find.byKey(const ValueKey('booking-mode-reserve')));
      await tester.pumpAndSettle();
      expect(summary(), contains('Tomorrow'));
      final member = find.byKey(const ValueKey('booking-for-member'));
      await tester.ensureVisible(member);
      await tester.tap(member);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ana').last);
      await tester.pumpAndSettle();
      expect(find.text('Booking for: Ana'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('booking-confirm')));
      await tester.pumpAndSettle();
      expect(choice?.forMemberId, 'ana');
      expect(choice?.start, future);
      expect(choice?.walkUp, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
