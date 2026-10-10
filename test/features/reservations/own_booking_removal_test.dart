// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2328 — the plan's "your seat" sheet offered Cancel on a checked-in
// booking while the booking's detail sheet offered Request deletion. One
// rule now decides both, and both sheets are opened here for the same
// checked-in booking.
import 'package:deskilo/core/demo/data/calendar_repository.dart';
import 'package:deskilo/core/calendar/calendar_item.dart';
import 'package:deskilo/core/time/workspace_time.dart';
import 'package:deskilo/features/plan/presentation/widgets/check_in_sheets.dart';
import 'package:deskilo/features/reservations/domain/own_booking_removal.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/presentation/widgets/reservation_detail_sheet.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_accessory_repository.dart';
import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/mock_providers.dart';

Reservation _booking(
  ReservationStatus status, {
  Duration startsIn = const Duration(hours: -1),
}) {
  final start = kTestNow.add(startsIn);
  return Reservation(
    id: 'res-1',
    workspaceId: 'ws-1',
    seatId: 'seat-4',
    memberId: 'member-1',
    startsAt: start,
    endsAt: start.add(const Duration(hours: 4)),
    status: status,
  );
}

OwnBookingRemoval _rule(Reservation r, {bool requests = true}) =>
    ownBookingRemoval(r, now: kTestNow, deletionRequests: requests);

Future<void> _pumpApp(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final plans = FakeFloorPlanRepository()..seedSmallPlan();
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        floorPlan: plans,
        reservations: FakeReservationRepository(),
        accessories: FakeAccessoryRepository(),
      ),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: home),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => WorkspaceTime.install('Europe/Berlin'));
  tearDownAll(WorkspaceTime.reset);

  group('ownBookingRemoval', () {
    test('an upcoming booking is cancelled directly', () {
      final r = _booking(
        ReservationStatus.reserved,
        startsIn: const Duration(hours: 2),
      );
      expect(_rule(r), OwnBookingRemoval.cancel);
      expect(_rule(r, requests: false), OwnBookingRemoval.cancel);
    });

    test('a started, checked-in or completed booking is a request', () {
      for (final status in [
        ReservationStatus.reserved,
        ReservationStatus.checkedIn,
        ReservationStatus.completed,
      ]) {
        expect(
          _rule(_booking(status)),
          OwnBookingRemoval.requestDeletion,
          reason: status.name,
        );
        expect(
          _rule(_booking(status), requests: false),
          OwnBookingRemoval.none,
          reason: '${status.name} without deletion requests',
        );
      }
    });

    test('a cancelled or released booking offers nothing', () {
      for (final status in [
        ReservationStatus.cancelled,
        ReservationStatus.released,
      ]) {
        expect(
          _rule(_booking(status, startsIn: const Duration(hours: 2))),
          OwnBookingRemoval.none,
          reason: status.name,
        );
      }
    });
  });

  testWidgets('both sheets offer Request deletion on a checked-in booking', (
    tester,
  ) async {
    final checkedIn = _booking(ReservationStatus.checkedIn);
    final removal = _rule(checkedIn);
    final plans = FakeFloorPlanRepository()..seedSmallPlan();
    final seat = plans.seats.firstWhere((s) => s.id == 'seat-4');

    // The plan's "your seat" sheet, fed by the rule as the plan feeds it.
    await _pumpApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showMySeatSheet(
            context,
            seat: seat,
            mine: checkedIn,
            now: kTestNow,
            cancellable: removal == OwnBookingRemoval.cancel,
            deletionRequestable: removal == OwnBookingRemoval.requestDeletion,
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Request deletion'), findsOneWidget);
    expect(find.text('Cancel reservation'), findsNothing);

    // The booking's detail sheet, same booking, same answer.
    await _pumpApp(tester, ReservationDetailSheet(reservation: checkedIn));
    expect(
      find.byKey(const ValueKey('reservation-delete-request')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('reservation-cancel')), findsNothing);
  });

  testWidgets('both sheets offer Cancel on an upcoming booking', (
    tester,
  ) async {
    final upcoming = _booking(
      ReservationStatus.reserved,
      startsIn: const Duration(hours: 3),
    );
    final removal = _rule(upcoming);
    final plans = FakeFloorPlanRepository()..seedSmallPlan();
    final seat = plans.seats.firstWhere((s) => s.id == 'seat-4');

    await _pumpApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showMySeatSheet(
            context,
            seat: seat,
            mine: upcoming,
            now: kTestNow,
            cancellable: removal == OwnBookingRemoval.cancel,
            deletionRequestable: removal == OwnBookingRemoval.requestDeletion,
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel reservation'), findsOneWidget);
    expect(find.text('Request deletion'), findsNothing);

    await _pumpApp(tester, ReservationDetailSheet(reservation: upcoming));
    expect(find.byKey(const ValueKey('reservation-cancel')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reservation-delete-request')),
      findsNothing,
    );
  });

  test('"My bookings" in the demo is the caller\'s own bookings', () async {
    // The server answers a query without a member for the caller
    // (`coalesce(p_member_id, me)`); the demo's calendar now does too.
    CalendarItem item(String id, String member) => CalendarItem.fromRow({
      'kind': 'reservation',
      'id': id,
      'at': kTestNow.toUtc().toIso8601String(),
      'member_id': member,
      'title': '',
    });
    final calendar = FakeCalendarRepository(actor: () => 'member-1')
      ..items.addAll([item('mine', 'member-1'), item('theirs', 'member-2')]);
    final page = await calendar.fetchItems(
      'ws-1',
      CalendarQuery(
        from: kTestNow.subtract(const Duration(days: 1)),
        to: kTestNow.add(const Duration(days: 1)),
        kinds: const {CalendarKind.reservation},
      ),
    );
    expect(page.items.map((i) => i.id), ['mine']);
    expect(page.subjectMemberId, 'member-1');
  });
}
