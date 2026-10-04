// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Deleting a PAST or CHECKED-IN reservation is a REQUEST (#492): the
// member never deletes directly — the button says so, the dialog says
// who decides (and what the question is: forgotten check-in vs unused),
// and the pending event lands on the events spine for an owner/admin.

import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_clock.dart';
import '../../helpers/fake_event_repository.dart';
import '../calendar/reservation_detail_sheet_test.dart'
    show reservationAt, pumpCalendarApp;

void main() {
  setUpAll(() => WorkspaceTime.install('Europe/Berlin'));
  tearDownAll(WorkspaceTime.reset);

  Reservation pastReservation({ReservationStatus? status}) {
    final now = kTestNow;
    // Yesterday 09:00 — safely past.
    return reservationAt(
      WorkspaceTime.at(now.year, now.month, now.day - 1, 9),
      seatId: 'seat-4',
    ).copyWith(status: status ?? ReservationStatus.reserved);
  }

  Future<void> openSheet(WidgetTester tester, DateTime start) async {
    // Select yesterday in the month grid, then open the reservation.
    await tester.tap(find.text('${start.day}'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('09:00'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'a PAST un-checked-in reservation offers "Request deletion" — '
      'never a direct cancel — and files the pending event with the '
      'reason (#492)', (tester) async {
    final reservation = pastReservation();
    await pumpCalendarApp(tester, seed: [reservation]);
    await openSheet(tester, reservation.startsAt);

    // The direct actions are gone; the REQUEST wording is there.
    expect(find.byKey(const ValueKey('reservation-cancel')), findsNothing);
    expect(find.byKey(const ValueKey('reservation-edit')), findsNothing);
    final requestButton =
        find.byKey(const ValueKey('reservation-delete-request'));
    await tester.ensureVisible(requestButton);
    expect(requestButton, findsOneWidget);
    expect(find.text('Request deletion'), findsOneWidget);

    await tester.tap(requestButton);
    await tester.pumpAndSettle();
    // The dialog explains the decision an owner/admin will make.
    expect(find.textContaining('forgotten'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('reservation-delete-reason')),
      'Could not come that day',
    );
    await tester
        .tap(find.byKey(const ValueKey('reservation-delete-submit')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Deletion requested'), findsOneWidget);
  });

  testWidgets(
      'a CHECKED-IN reservation gets the request path too (#492)',
      (tester) async {
    final reservation =
        pastReservation(status: ReservationStatus.checkedIn);
    await pumpCalendarApp(tester, seed: [reservation]);
    await openSheet(tester, reservation.startsAt);

    expect(find.byKey(const ValueKey('reservation-cancel')), findsNothing);
    expect(find.byKey(const ValueKey('reservation-delete-request')),
        findsOneWidget);
  });

  testWidgets(
      'a FUTURE reserved booking keeps the direct cancel — no request '
      'wording (#492)', (tester) async {
    final now = kTestNow;
    final reservation = reservationAt(
      WorkspaceTime.at(now.year, now.month, now.day, 23),
      seatId: 'seat-4',
    );
    await pumpCalendarApp(tester, seed: [reservation]);
    await tester.tap(find.textContaining('23:00'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('reservation-cancel')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('reservation-delete-request')),
        findsNothing);
  });

  test('the deletion event needs ANOTHER person to decide (#492)', () {
    final event = WorkspaceEvent(
      id: 'e1',
      workspaceId: 'ws-1',
      type: EventType.reservationDelete,
      action: EventAction.submitted,
      actorMemberId: 'member-1',
      subjectMemberId: 'member-1',
      payload: const {'reservation_id': 'res-1'},
      status: EventStatus.pending,
      createdAt: kTestNow,
    );
    expect(event.needsAdminDecider, isTrue);
  });

  testWidgets(
      'RE-REQUESTING supersedes (#562): the second demand expires the '
      'pending event and files a fresh one — no error', (tester) async {
    final reservation = pastReservation();
    final events = FakeEventRepository();
    await pumpCalendarApp(tester, seed: [reservation], events: events);

    Future<void> request(String reason) async {
      await openSheet(tester, reservation.startsAt);
      final requestButton =
          find.byKey(const ValueKey('reservation-delete-request'));
      await tester.ensureVisible(requestButton);
      await tester.tap(requestButton);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('reservation-delete-reason')),
        reason,
      );
      await tester
          .tap(find.byKey(const ValueKey('reservation-delete-submit')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Deletion requested'), findsOneWidget);
      // The sheet popped on submit; let the snack expire so it never
      // occludes the next round's request button.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }

    await request('first try');
    await request('second try — nobody reacted');

    final deleteEvents = events.events
        .where((e) => e.type == EventType.reservationDelete)
        .toList();
    expect(deleteEvents, hasLength(2));
    expect(
        deleteEvents.where((e) => e.status == EventStatus.pending).single
            .payload['reason'],
        'second try — nobody reacted');
    expect(deleteEvents.where((e) => e.status == EventStatus.expired),
        hasLength(1));
  });

}
