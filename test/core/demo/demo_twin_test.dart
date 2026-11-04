// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3302 — the main space's development twin can be entered from Me and is
// a workspace of its own, as 0185 and ADR 0019 make it: the production's
// configuration copied once, every production member also its member
// (prod ⊆ dev), its bookings, requests and money its own, and the pair's
// deployment journal readable from both sides. Before, the Demo's routing
// knew four spaces and every per-space provider was in error there.
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/demo/demo_session.dart';
import 'package:deskilo/core/demo/seed/demo_twin_seed.dart';
import 'package:deskilo/features/calendar/providers/calendar_providers.dart';
import 'package:deskilo/features/events/providers/event_providers.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/features/money/providers/supplier_providers.dart';
import 'package:deskilo/features/plan/domain/half_day_windows.dart';
import 'package:deskilo/features/plan/providers/floor_plan_providers.dart';
import 'package:deskilo/features/reservations/providers/reservation_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/providers/deployment_providers.dart';
import 'package:deskilo/features/workspace/providers/local_setup_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DemoFixture fixture;
  late ProviderContainer container;

  setUp(() {
    fixture = DemoFixture.build();
    container = ProviderContainer(overrides: demoOverrides(fixture))
      ..listen(currentWorkspaceProvider, (_, _) {});
  });
  tearDown(() => container.dispose());

  Future<void> enter(String space) async {
    await container.read(currentWorkspaceProvider.future);
    container.read(activeWorkspaceIdProvider.notifier).activate(space);
    expect((await container.read(currentWorkspaceProvider.future))?.id, space);
    container.listen(myPermissionsProvider, (_, _) {});
    await container.read(myMemberProvider.future);
  }

  test('Me lists the twin as one of the persona\'s spaces, with the '
      'persona as its member', () async {
    final mine = await fixture.workspaces.fetchMyWorkspaces();
    final twin = mine.singleWhere((w) => w.id == demoTwinSpaceId);
    final production = mine.singleWhere((w) => w.id == 'ws-1');
    expect(twin.isDevelopment, isTrue);
    expect(twin.pairId, production.pairId, reason: 'one pair');
    expect((await fixture.workspaces.fetchMyMember(demoTwinSpaceId))?.id, DemoPersona.owner.memberId);
  });

  test('entering the twin resolves every per-space provider, each to the '
      'twin\'s own store, never production\'s', () async {
    await enter('ws-1');
    final production = <String, Object>{
      'workspace': container.read(workspaceRepositoryProvider),
      'plan': container.read(floorPlanRepositoryProvider),
      'reservations': container.read(reservationRepositoryProvider),
      'events': container.read(eventRepositoryProvider),
      'calendar': container.read(calendarRepositoryProvider),
      'money': container.read(moneyRepositoryProvider),
      'purchases': container.read(purchaseRepositoryProvider),
      'suppliers': container.read(supplierRepositoryProvider),
    };
    await enter(demoTwinSpaceId);
    final twin = <String, Object>{
      'workspace': container.read(workspaceRepositoryProvider),
      'plan': container.read(floorPlanRepositoryProvider),
      'reservations': container.read(reservationRepositoryProvider),
      'events': container.read(eventRepositoryProvider),
      'calendar': container.read(calendarRepositoryProvider),
      'money': container.read(moneyRepositoryProvider),
      'purchases': container.read(purchaseRepositoryProvider),
      'suppliers': container.read(supplierRepositoryProvider),
    };
    for (final key in production.keys) {
      expect(identical(twin[key], production[key]), isFalse, reason: '$key: the twin has its own');
    }
    expect(twin['workspace'], same(fixture.twin.workspaces));
    expect(twin['reservations'], same(fixture.twin.reservations));
    expect(twin['money'], same(fixture.twin.money));
  });

  test('the twin carries its production\'s plan, copied, and its whole '
      'cast; its activity starts empty', () async {
    await enter(demoTwinSpaceId);
    final plan = container.read(floorPlanRepositoryProvider);
    final devLevels = await plan.fetchLevels(demoTwinSpaceId);
    final prodLevels = await fixture.floorPlan.fetchLevels('ws-1');
    expect(devLevels.map((l) => l.name), prodLevels.map((l) => l.name));
    final devMembers = await container.read(workspaceRepositoryProvider).fetchMembers(demoTwinSpaceId);
    final prodMembers = await fixture.workspaces.fetchMembers('ws-1');
    expect(devMembers.map((m) => m.id).toSet(), containsAll(prodMembers.map((m) => m.id)),
        reason: 'every production member is a member of the twin (0185, prod ⊆ dev)');
    expect(fixture.twin.reservations.reservations, isEmpty);
    expect(fixture.twin.events.events, isEmpty);
    expect(fixture.twin.money.invoices, isEmpty);
  });

  test('what is tried in the twin stays in the twin', () async {
    final prodBookings = fixture.reservations.reservations.length;
    final prodLedger = fixture.money.ledger.length;
    final prodSeats = fixture.floorPlan.seats.length;
    await enter(demoTwinSpaceId);
    final seat = fixture.twin.floorPlan.seats.first.id;
    final w = HalfDayWindows.morning(fixture.seededAt.add(const Duration(days: 7)));
    final id = await container
        .read(reservationRepositoryProvider)
        .create(workspaceId: demoTwinSpaceId, seatId: seat, startsAt: w.start, endsAt: w.end);
    fixture.twin.floorPlan.seats.removeLast();

    expect(fixture.twin.reservations.reservations.map((r) => r.id), [id]);
    expect(fixture.reservations.reservations, hasLength(prodBookings), reason: 'production unchanged');
    expect(fixture.reservations.reservations.where((r) => r.id == id && r.workspaceId == demoTwinSpaceId), isEmpty);
    expect(fixture.money.ledger, hasLength(prodLedger));
    expect(fixture.floorPlan.seats, hasLength(prodSeats), reason: 'a plan edit in the twin is not production\'s');
  });

  test('the pair\'s deployment journal and the twin\'s setup guide are '
      'readable from the twin', () async {
    await enter(demoTwinSpaceId);
    final twin = (await container.read(currentWorkspaceProvider.future))!;
    final journal = await container.read(deploymentRepositoryProvider).journal(twin.pairId);
    expect(journal, isNotEmpty, reason: 'the pair shares one journal');
    final status = await container.read(localSetupRepositoryProvider).setupStatus(demoTwinSpaceId);
    expect(status.steps, isNotEmpty, reason: 'the twin has a guide of its own');
  });

  test('the twin follows the persona like its production, and a reset '
      'empties it again', () async {
    final session = ProviderContainer();
    addTearDown(session.dispose);
    final controller = session.read(demoSessionControllerProvider.notifier);
    final f = session.read(demoSessionControllerProvider).fixture;
    final seat = f.twin.floorPlan.seats.first.id;
    final w = HalfDayWindows.morning(f.seededAt.add(const Duration(days: 7)));
    await f.twin.reservations.create(workspaceId: demoTwinSpaceId, seatId: seat, startsAt: w.start, endsAt: w.end);

    // The twin follows the persona as its production does: Bruno is a
    // production member, so the twin is his space too, with him as member.
    controller.viewAs(DemoPersona.member);
    expect((await f.workspaces.fetchMyWorkspaces()).where((w) => w.id == demoTwinSpaceId), hasLength(1));
    expect((await f.workspaces.fetchMyMember(demoTwinSpaceId))?.id, DemoPersona.member.memberId);
    expect(f.twin.workspaces.myMember.id, DemoPersona.member.memberId);

    controller.reset();
    expect(session.read(demoSessionControllerProvider).fixture.twin.reservations.reservations, isEmpty);
  });
}
