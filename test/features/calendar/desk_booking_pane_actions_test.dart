// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3843 — a booking beside the desk calendar carries its own actions where
// the booking's sheet offers them (the booking's own member): edit, cancel
// and stay longer stand in the pane. Cancel asks as a short task, nothing
// closes, the grid and the pane read again; a refusal is said in the pane.
// Someone else's booking has no row.
import 'package:deskilo/app/desk_calendar/desk_booking_pane.dart';
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

Future<DemoJourney> _open(WidgetTester tester, String id) async {
  final journey = await pumpDeskCalendar(tester);
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
}
