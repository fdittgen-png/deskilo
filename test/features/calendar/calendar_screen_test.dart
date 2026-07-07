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
  testWidgets('today is preselected and lists my reservation with seat name',
      (tester) async {
    await pumpCalendar(tester, seed: [todayReservation()]);

    expect(find.textContaining('09:00'), findsOneWidget);
    expect(find.textContaining('A1'), findsOneWidget);
  });

  testWidgets("admins can switch to everyone's reservations", (tester) async {
    await pumpCalendar(
      tester,
      seed: [todayReservation(id: 'res-x', memberId: 'member-2')],
    );

    expect(find.text('No reservations on this day.'), findsOneWidget);

    await tester.tap(find.text('Everyone'));
    await tester.pumpAndSettle();

    expect(find.textContaining('A1'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
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
}
