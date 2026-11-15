// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3843 — a booking beside the desk calendar carries its own actions where
// the booking's sheet offers them (the booking's own member): edit, cancel
// and stay longer stand in the pane. Cancel asks as a short task, nothing
// closes, the grid and the pane read again; a refusal is said in the pane.
// Someone else's booking has no row. #4054 — every action is its own button,
// with no door to a sheet that only lists them: someone else's booking shows
// one, Show on plan. The week keeps its seven days beside the booking; where
// the window cannot hold both, the booking is a page, and closing it gives
// back the week as it was, its cell focused.
import 'package:deskilo/app/desk_calendar/desk_booking_chip.dart';
import 'package:deskilo/app/desk_calendar/desk_booking_pane.dart';
import 'package:deskilo/app/desk_calendar/desk_week_grid.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_journey.dart';
import '../../helpers/screens/desk_calendar.dart';

/// The Demo's own member's booking a week ahead, and another member's today.
const _mine = 'demo-next-week';
const _theirs = 'demo-today';

final _cancel = find.byKey(const ValueKey('desk-pane-cancel'));
final _cancelThisOne = find.byKey(
  const ValueKey('reservation-detail-sheet-plan-cancel-reservation-button'),
);

String _dayOf(String id, DemoJourney journey) {
  final r = journey.fixture.reservations.reservations.firstWhere(
    (r) => r.id == id,
  );
  final d = r.startsAt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

Future<DemoJourney> _open(
  WidgetTester tester,
  String id, {
  Size size = const Size(1440, 900),
}) async {
  final journey = await pumpDeskCalendar(tester, size: size);
  await goTo(tester, '/calendar?view=week&day=${_dayOf(id, journey)}&res=$id');
  expect(find.byType(DeskBookingPane), findsOneWidget);
  return journey;
}

ReservationStatus _status(DemoJourney journey, String id) => journey
    .fixture
    .reservations
    .reservations
    .firstWhere((r) => r.id == id)
    .status;

void main() {
  testWidgets('the own member\'s booking carries edit and cancel in the '
      'pane; cancel asks as a short task, the pane stays and the grid '
      'reads again', (tester) async {
    final journey = await _open(tester, _mine);
    expect(find.byKey(const ValueKey('desk-pane-edit')), findsOneWidget);
    expect(_cancel, findsOneWidget);

    await tester.tap(_cancel);
    await tester.pumpAndSettle();
    expect(_cancelThisOne, findsOneWidget, reason: 'the question');
    await tester.tap(_cancelThisOne);
    await tester.pumpAndSettle();

    expect(_status(journey, _mine), ReservationStatus.cancelled);
    expect(find.byType(DeskBookingPane), findsOneWidget, reason: 'stays');
    expect(locationOf(tester), contains('res=$_mine'));
    expect(_cancel, findsNothing, reason: 'a cancelled booking offers none');
    expect(find.byKey(const ValueKey('desk-pane-refusal')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a refusal is said in the pane, which stays', (tester) async {
    final journey = await _open(tester, _mine);
    // Cancelled meanwhile, elsewhere: the pane still offers it, the
    // server refuses.
    await journey.fixture.reservations.cancel(_mine);
    await tester.tap(_cancel);
    await tester.pumpAndSettle();
    await tester.tap(_cancelThisOne);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('desk-pane-refusal')), findsOneWidget);
    expect(find.byType(DeskBookingPane), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('someone else\'s booking has no actions row in the pane', (
    tester,
  ) async {
    await _open(tester, _theirs);
    expect(find.byKey(const ValueKey('desk-pane-edit')), findsNothing);
    expect(_cancel, findsNothing);
    expect(find.byKey(const ValueKey('desk-pane-extend')), findsNothing);
  });

  testWidgets('#4054 — the own booking\'s actions stand each as a button, '
      'and none promises a sheet of actions', (tester) async {
    await _open(tester, _mine);
    expect(find.byKey(const ValueKey('desk-pane-edit')), findsOneWidget);
    expect(_cancel, findsOneWidget);
    expect(
      find.byKey(const ValueKey('desk-pane-show-on-plan')),
      findsOneWidget,
    );
    expect(find.text('Change, cancel or show on plan'), findsNothing);
  });

  testWidgets('#4054 — someone else\'s booking offers one button: Show on '
      'plan', (tester) async {
    await _open(tester, _theirs);
    final buttons = find.descendant(
      of: find.byType(DeskBookingPane),
      matching: find.byWidgetPredicate(
        (w) => w is ButtonStyleButton && w.key is ValueKey<String>,
      ),
    );
    expect(
      [for (final e in buttons.evaluate()) (e.widget.key! as ValueKey<String>).value],
      ['desk-pane-show-on-plan'],
    );
  });

  for (final size in const [Size(1440, 900), Size(1024, 768)]) {
    testWidgets('#4054 — at ${size.width.toInt()} with the full sidebar the '
        'booking is a page; closing it gives back the week as it was, its '
        'cell focused', (tester) async {
      final journey = await _open(tester, _mine, size: size);
      expect(find.byKey(const ValueKey('desk-booking-page')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('desk-booking-pane-close')));
      await tester.pumpAndSettle();

      // Opened from its cell, as a person does, with the week scrolled.
      final cell = find.byKey(deskBookingKey(_mine));
      await tester.ensureVisible(cell);
      await tester.pumpAndSettle();
      double offset() => tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(deskWeekScrollKey),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .pixels;
      final scrolled = offset();
      final week = locationOf(tester);
      await tester.tap(cell);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('desk-booking-page')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('desk-booking-pane-close')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('desk-booking-page')), findsNothing);
      expect(locationOf(tester), week, reason: 'the same week and view');
      expect(offset(), scrolled, reason: 'the same scroll position');
      final focused = FocusManager.instance.primaryFocus?.context;
      expect(focused, isNotNull);
      expect(
        focused!.widget.key == deskBookingKey(_mine) ||
            find
                .ancestor(
                  of: find.byElementPredicate((e) => e == focused),
                  matching: cell,
                )
                .evaluate()
                .isNotEmpty,
        isTrue,
        reason: 'the booking\'s cell has the keyboard again',
      );
      expect(_dayOf(_mine, journey), isNotEmpty);
    });
  }

  testWidgets('#4054 — at 1920 the week keeps its seven days beside the '
      'booking', (tester) async {
    await _open(tester, _mine, size: const Size(1920, 1080));
    expect(find.byKey(const ValueKey('desk-booking-page')), findsNothing);
    expect(find.byType(DeskBookingPane), findsOneWidget);
  });
}
