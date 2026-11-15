// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4009 — in the Demo's organisation a member of the head asks to join a
// house, is let in as that house's welcome says, and books there. Bruno, a
// member of Atelier du Marché, asks the house in Kraków once Ada has added
// it and given it a place. Where the house welcomes the organisation's
// members he is a member at once and his booking is the house's own: held by
// its reservations, never by the head's. Where it does not, he waits for
// the house and booking there is refused until it decides.
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/demo/demo_space_ids.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/plan/domain/grid_geometry.dart';
import 'package:deskilo/features/plan/domain/half_day_windows.dart';
import 'package:deskilo/features/plan/domain/seat.dart';
import 'package:deskilo/features/reservations/domain/reservation.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/organisation.dart';
import 'package:deskilo/features/workspace/providers/organisation_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

void main() {
  late DemoFixture fixture;
  late ProviderContainer container;
  late String seat;

  /// Ada adds the house and its first place; then Bruno looks through.
  Future<void> setUpHouse({required bool welcomes}) async {
    fixture = DemoFixture.build()
      ..becomePersona(DemoPersona.owner)
      ..revealHouse();
    final plan = fixture.house.floorPlan;
    final level = await plan.createLevel(demoHouseSpaceId, 'Ground floor', 0);
    final office = await plan.createOffice(
      workspaceId: demoHouseSpaceId,
      levelId: level.id,
      name: 'Hall',
      color: 0,
      bookableAsWhole: false,
      rect: const GridRect(x: 0, y: 0, w: 10, h: 10),
    );
    final desk = await plan.createDesk(
      workspaceId: demoHouseSpaceId,
      officeId: office.id,
      name: 'Desk 1',
      rect: const GridRect(x: 1, y: 1, w: 2, h: 1),
    );
    seat = (await plan.createSeat(
      workspaceId: demoHouseSpaceId,
      deskId: desk.id,
      name: 'Seat 1',
      x: 1,
      y: 1,
      orientation: SeatOrientation.n,
    )).id;
    if (welcomes) fixture.houseWelcomes.add(demoHouseSpaceId);
    fixture.becomePersona(DemoPersona.member);
    container = ProviderContainer(overrides: demoOverrides(fixture));
    addTearDown(container.dispose);
  }

  Member? houseMember() => fixture.listings
      .firstWhere((l) => l.id == demoHouseSpaceId)
      .memberOf(fixture.actor.memberId);

  Future<void> enterHouse() async {
    container.listen(currentWorkspaceProvider, (_, _) {});
    await container.read(authStateProvider.future);
    await container.read(currentWorkspaceProvider.future);
    container
        .read(activeWorkspaceIdProvider.notifier)
        .activate(demoHouseSpaceId);
    expect(
      (await container.read(currentWorkspaceProvider.future))?.id,
      demoHouseSpaceId,
    );
    container.listen(myPermissionsProvider, (_, _) {});
    await container.read(myMemberProvider.future);
  }

  HalfDayWindow freeMorning() => [
    for (var d = 3; d < 40; d++)
      HalfDayWindows.morning(fixture.seededAt.add(Duration(days: d))),
  ].firstWhere((w) => w.start.weekday <= DateTime.friday);

  test('Bruno asks a welcoming house, is a member at once, and books '
      'there: the booking is the house\'s own', () async {
    await setUpHouse(welcomes: true);
    final repo = container.read(organisationRepositoryProvider);
    final joinable = await repo.joinableHouses();
    expect(joinable.map((h) => h.workspaceId), [demoHouseSpaceId]);
    expect(joinable.single.welcome, isTrue);

    final answer = await repo.askToJoin(demoHouseSpaceId);
    expect(answer.refused, isNull);
    expect(answer.joined, HouseJoin.member);
    expect(houseMember()?.status, MemberStatus.active);

    await enterHouse();
    final w = freeMorning();
    final id = await container
        .read(reservationRepositoryProvider)
        .create(
          workspaceId: demoHouseSpaceId,
          seatId: seat,
          startsAt: w.start,
          endsAt: w.end,
        );
    final held = fixture.house.reservations.reservations.where(
      (r) => r.id == id,
    );
    expect(held, hasLength(1));
    expect(held.single.workspaceId, demoHouseSpaceId);
    expect(held.single.memberId, fixture.actor.memberId);
    expect(held.single.status, isNot(ReservationStatus.cancelled));
    expect(
      fixture.reservations.reservations.where((r) => r.id == id),
      isEmpty,
      reason: 'the head never holds the house\'s booking',
    );
  });

  test('a house that does not welcome waits for its decision: asked, not a '
      'member, and booking there is refused', () async {
    await setUpHouse(welcomes: false);
    final repo = container.read(organisationRepositoryProvider);
    final answer = await repo.askToJoin(demoHouseSpaceId);
    expect(answer.joined, HouseJoin.asked);
    expect(houseMember()?.status, MemberStatus.pending);

    await enterHouse();
    final w = freeMorning();
    await expectLater(
      container
          .read(reservationRepositoryProvider)
          .create(
            workspaceId: demoHouseSpaceId,
            seatId: seat,
            startsAt: w.start,
            endsAt: w.end,
          ),
      throwsA(isA<PostgrestException>()),
    );
    expect(
      fixture.house.reservations.reservations.where(
        (r) => r.memberId == fixture.actor.memberId,
      ),
      isEmpty,
    );
  });
}
