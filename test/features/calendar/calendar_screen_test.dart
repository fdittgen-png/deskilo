// SPDX-License-Identifier: MIT
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_reservation_repository.dart';
import '../../helpers/mock_providers.dart';

Reservation todayReservation({
  String id = 'res-1',
  String memberId = 'member-1',
  String? seriesId,
  int startHour = 9,
}) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day, startHour);
  return Reservation(
    id: id,
    workspaceId: 'ws-1',
    seatId: 'seat-4',
    memberId: memberId,
    startsAt: start,
    endsAt: start.add(const Duration(hours: 2)),
    status: ReservationStatus.reserved,
    seriesId: seriesId,
  );
}

Future<FakeReservationRepository> pumpCalendar(
  WidgetTester tester, {
  List<Reservation> seed = const [],
  Member? member,
}) async {
  final plans = FakeFloorPlanRepository()..seedSmallPlan();
  final reservations = FakeReservationRepository()
    ..reservations.addAll(seed);
  final workspace = FakeWorkspaceRepository.withWorkspace()
    ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'};
  if (member != null) workspace.myMember = member;
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        floorPlan: plans,
        reservations: reservations,
        workspace: workspace,
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Calendar'));
  await tester.pumpAndSettle();
  return reservations;
}

void main() {
  testWidgets(
      'landscape splits the month + controls into a side panel (no overflow)',
      (tester) async {
    // Phone-landscape: the split engages and the day list fills the rest.
    // A RenderFlex overflow would fail this test.
    tester.view.physicalSize = const Size(760, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpCalendar(tester, seed: [todayReservation()]);

    expect(find.byType(VerticalDivider), findsOneWidget);
    // The month grid and the day's reservation both render.
    expect(find.text('July 2026'), findsOneWidget);
    expect(find.textContaining('A1'), findsOneWidget);
  });

  testWidgets('today is preselected and lists my reservation with seat name',
      (tester) async {
    await pumpCalendar(tester, seed: [todayReservation()]);

    expect(find.textContaining('09:00'), findsOneWidget);
    expect(find.textContaining('A1'), findsOneWidget);
  });

  testWidgets('month markers are red for my days and blue for others',
      (tester) async {
    // Admin so the Everyone switch is available.
    await pumpCalendar(
      tester,
      seed: [
        todayReservation(),
        todayReservation(id: 'res-x', memberId: 'member-2', startHour: 14),
      ],
    );

    Iterable<Color?> dotColors() => tester
        .widgetList<Icon>(find.byIcon(Icons.circle))
        .where((i) => i.size == 5)
        .map((i) => i.color);

    // Mine tab: only my booking today → a red marker, no blue.
    expect(dotColors(), contains(const Color(0xFFEF5350)));
    expect(dotColors(), isNot(contains(const Color(0xFF42A5F5))));

    // Everyone: my day still red (I have a booking that day), never blue —
    // the red-for-me rule wins when I have any booking on the day.
    await tester.tap(find.text('Everyone'));
    await tester.pumpAndSettle();
    expect(dotColors(), contains(const Color(0xFFEF5350)));
  });

  testWidgets("admins can switch to everyone's reservations", (tester) async {
    await pumpCalendar(
      tester,
      seed: [todayReservation(id: 'res-x', memberId: 'member-2')],
    );

    expect(find.text('No reservations on this day.'), findsOneWidget);

    await tester.tap(find.text('Everyone'));
    await tester.pumpAndSettle();

    // The card's location line carries both the seat and the occupant in
    // Everyone mode ("A1 · Ana").
    expect(find.textContaining('A1'), findsOneWidget);
    expect(find.textContaining('Ana'), findsOneWidget);
  });

  testWidgets('workers get no everyone toggle', (tester) async {
    await pumpCalendar(
      tester,
      member: const Member(
        id: 'member-1',
        workspaceId: 'ws-1',
        userId: 'user-1',
        isAdmin: false,
        isOwner: false,
        status: MemberStatus.active,
      ),
    );

    expect(find.text('Everyone'), findsNothing);
  });

  testWidgets('cancel this-and-following stops the series from that instance',
      (tester) async {
    final now = DateTime.now();
    final seed = [
      todayReservation(id: 'res-a', seriesId: 'series-1'),
      todayReservation(id: 'res-b', seriesId: 'series-1')
          .copyWith(
        startsAt: DateTime(now.year, now.month, now.day, 9)
            .add(const Duration(days: 7)),
        endsAt: DateTime(now.year, now.month, now.day, 11)
            .add(const Duration(days: 7)),
      ),
    ];
    final repo = await pumpCalendar(tester, seed: seed);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel this and following'));
    await tester.pumpAndSettle();

    expect(
      repo.reservations
          .where((r) => r.status == ReservationStatus.cancelled)
          .length,
      2,
    );
  });

  testWidgets('pull-to-refresh surfaces bookings made elsewhere (#111)',
      (tester) async {
    final repo = await pumpCalendar(tester);
    expect(find.text('No reservations on this day.'), findsOneWidget);

    // A booking lands after the calendar cached its month (e.g. on the
    // Plan tab of another device) — the user pulls to refresh.
    repo.reservations.add(todayReservation());
    // The EmptyState (#209) centers the text; its center can sit outside
    // the viewport — fling the day list's scrollable itself instead.
    await tester.fling(
      find
          .descendant(
            of: find.byType(RefreshIndicator),
            matching: find.byType(Scrollable),
          )
          .first,
      const Offset(0, 300),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text('No reservations on this day.'), findsNothing);
    expect(find.textContaining('09:00'), findsOneWidget);
  });
}
