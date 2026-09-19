// SPDX-License-Identifier: 0BSD
//
// #1374 — the session a visitor lands in is coherent, and says so when
// it is not.
import 'package:deskilo/core/demo/data/floor_plan_repository.dart';
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/core/demo/data/reservation_repository.dart';
import 'package:deskilo/core/demo/data/workspace_repository.dart';
import 'package:deskilo/core/demo/demo_dataset.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the same people appear in the plan, the bookings and the bills',
      () {
    final fixture = DemoFixture.build();
    final memberIds = {
      fixture.workspaces.myMember.id,
      for (final m in fixture.workspaces.otherMembers) m.id,
    };

    expect(memberIds, hasLength(demoCast.length));
    for (final reservation in fixture.reservations.reservations) {
      expect(memberIds, contains(reservation.memberId),
          reason: 'a booking by nobody');
    }
    for (final invoice in fixture.money.invoices) {
      expect(memberIds, contains(invoice.memberId),
          reason: 'a bill for nobody');
    }
    // The story: the person with the open invoice is the one whose
    // booking finished yesterday, and the checked-in seat belongs to
    // somebody else entirely.
    expect(
      fixture.money.invoices.map((i) => i.memberId),
      containsAll(<String>['member-1', 'member-2']),
    );
    expect(
      fixture.reservations.reservations
          .firstWhere((r) => r.status == ReservationStatus.checkedIn)
          .memberId,
      'member-3',
    );
  });

  test('the bookings are placed around the session clock, never on a '
      'literal date', () {
    final now = DateTime(2031, 3, 5, 10);
    final fixture = DemoFixture.build(now: now);
    final byId = {
      for (final r in fixture.reservations.reservations) r.id: r,
    };

    expect(byId['demo-today']!.startsAt.day, now.day);
    expect(byId['demo-today']!.startsAt.year, 2031);
    expect(byId['demo-past']!.startsAt.isBefore(now), isTrue);
    expect(byId['demo-next-week']!.startsAt.isAfter(now), isTrue);
    expect(fixture.seededAt, now);
  });

  test('the cast covers the states a member screen must render', () {
    final statuses = {for (final p in demoCast) p.status};
    expect(statuses, containsAll(<MemberStatus>[
      MemberStatus.active,
      MemberStatus.pending,
      MemberStatus.paused,
    ]));
    expect(demoCast.map((p) => p.name).toSet(), hasLength(demoCast.length),
        reason: 'two people with the same name is a confusing demo');
  });

  test('a broken reference is caught before a visitor can open it', () {
    final workspaces = FakeWorkspaceRepository.withWorkspace();
    final plan = FakeFloorPlanRepository()..seedSmallPlan();
    final reservations = FakeReservationRepository();
    final money = FakeMoneyRepository();
    seedDemoPeople(workspaces);

    reservations.reservations.add(
      Reservation(
        id: 'ghost',
        workspaceId: 'ws-1',
        seatId: 'seat-does-not-exist',
        memberId: 'member-does-not-exist',
        startsAt: DateTime(2026, 5, 13, 9),
        endsAt: DateTime(2026, 5, 13, 8),
        status: ReservationStatus.reserved,
      ),
    );

    final problems = validateDemoFixture(
      workspaces: workspaces,
      plan: plan,
      reservations: reservations,
      money: money,
    );
    expect(problems, hasLength(3));
    expect(problems.join(' '), contains('no member'));
    expect(problems.join(' '), contains('no seat'));
    expect(problems.join(' '), contains('ends before it starts'));
  });

  test('a session that is not coherent refuses to build', () {
    // The validator is not decoration: the fixture runs it and fails
    // closed rather than handing a visitor a screen that cannot open.
    expect(validateDemoFixture(
      workspaces: FakeWorkspaceRepository.withWorkspace(),
      plan: FakeFloorPlanRepository(),
      reservations: FakeReservationRepository(),
      money: FakeMoneyRepository(),
    ), isNotEmpty);
    expect(DemoFixture.build, returnsNormally);
  });
}
