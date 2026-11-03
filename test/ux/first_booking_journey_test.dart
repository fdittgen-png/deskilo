// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3062 -- a new owner reaches a member's first booking, through the app's
// own screens over the suite's fake repositories, which keep the server's
// rules. The setup status is the Demo's repository, which reads every step
// from what the repositories HOLD (seats, the members' right, bookings), not
// from a route visit. The database half over the real schema is
// supabase/tests/database/345.
//
//   1. A clean workspace is created through the first-run screens; the guide
//      opens on it and names ONE next action: the places.
//   2. The next action opens the canonical setup page of that step, not a
//      personal settings screen.
//   3. The resource is created and the app is started afresh over the same
//      repositories (the "reload"): the places are done, the progress made
//      stays, and the booking right is still open -- nothing completes
//      falsely. The next action is now the right.
//   4. The right is granted: the "Take bookings" outcome is reached, the
//      booking step is open.
//   5. A member books a valid slot; the owner reads the same booking, and
//      the booking step is done. The later outcomes remain listed.
import 'dart:collection';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/core/demo/data/demo_setup_repository.dart';
import 'package:deskilo/core/demo/data/event_repository.dart';
import 'package:deskilo/core/demo/data/floor_plan_repository.dart';
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/core/demo/data/reservation_repository.dart';
import 'package:deskilo/features/plan/domain/half_day_windows.dart';
import 'package:deskilo/features/workspace/domain/setup_status.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_guide_screen.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_providers.dart';

/// Every workspace id reads the same sources: the one clean space under test.
class _OneSpace extends MapBase<String, DemoSetupSources> {
  _OneSpace(this._sources);
  final DemoSetupSources _sources;
  @override
  DemoSetupSources? operator [](Object? key) => _sources;
  @override
  void operator []=(String key, DemoSetupSources value) {}
  @override
  void clear() {}
  @override
  Iterable<String> get keys => const [];
  @override
  DemoSetupSources? remove(Object? key) => null;
}

/// The persisted state of one space: what survives an app start.
class _Space {
  _Space() {
    setup = DemoSetupRepository(
      rows: workspace,
      spaces: _OneSpace(
        DemoSetupSources(
          space: workspace,
          plan: plan,
          reservations: reservations,
          money: money,
          events: events,
        ),
      ),
    );
  }

  final events = FakeEventRepository();
  final workspace = FakeWorkspaceRepository();
  final plan = FakeFloorPlanRepository();
  // What a device keeps between two starts: the space last used.
  final activeWorkspace = InMemoryActiveWorkspaceStore();
  final defaultWorkspace = InMemoryDefaultWorkspaceStore();
  late final money = FakeMoneyRepository(events: events);
  String bookingMember = 'member-1';
  late final reservations = FakeReservationRepository(
    actor: () => bookingMember,
  );
  late final DemoSetupRepository setup;

  Future<SetupStatus> status() =>
      setup.setupStatus(workspace.workspaces.single.id);

  Future<SetupStepState> step(String id) async =>
      (await status()).steps.singleWhere((s) => s.step == id).state;

  Future<bool> reached(String milestone) async => (await status()).milestones
      .singleWhere((m) => m.milestone == milestone)
      .reached;

  /// The app, started over this space's repositories.
  Widget app() => ProviderScope(
    overrides: standardTestOverrides(
      workspace: workspace,
      floorPlan: plan,
      reservations: reservations,
      money: money,
      events: events,
      localSetup: setup,
      activeWorkspace: activeWorkspace,
      defaultWorkspace: defaultWorkspace,
    ),
    child: const DeskiloApp(),
  );
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(DeskiloApp)));

String _path(WidgetTester tester) => _container(
  tester,
).read(routerProvider).routeInformationProvider.value.uri.path;

/// Starts the app afresh over [space] and opens the setup guide.
Future<void> _reloadIntoGuide(WidgetTester tester, _Space space) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(space.app());
  await tester.pumpAndSettle();
  _container(tester).read(routerProvider).go('/setup');
  await tester.pumpAndSettle();
  expect(find.byType(SetupGuideScreen), findsOneWidget);
}

const _next = 'setup-guide-next';

void main() {
  testWidgets('a clean workspace reaches a first booking, reload included', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final space = _Space();

    // 1. The first-run screens create the space; the guide opens on it.
    await tester.pumpWidget(space.app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('me-home-create')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Clean journey');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('onboarding-use-suggested')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create workspace'));
    await tester.tap(find.text('Create workspace'));
    await tester.pumpAndSettle();
    final id = space.workspace.workspaces.single.id;
    expect(space.workspace.workspaces.single.name, 'Clean journey');
    expect(_container(tester).read(currentWorkspaceProvider).value?.id, id);
    // The server starts a real space with an empty member matrix (0373).
    await space.workspace.setRolePermissions(id, 'member', const []);
    // The account's default space, which every later start opens (#89).
    await space.workspace.setDefaultWorkspaceId(id);

    await _reloadIntoGuide(tester, space);
    expect(find.textContaining('Take bookings · 2 of 4 done'), findsOneWidget);
    expect(await space.step('places'), SetupStepState.needsConfiguration);
    expect(
      await space.step('member_rights'),
      SetupStepState.needsConfiguration,
    );
    expect(await space.step('first_booking'), SetupStepState.blocked);
    expect(
      find.byKey(const ValueKey('$_next-places')),
      findsOneWidget,
      reason: 'ONE next action, and it is the places',
    );
    expect(find.byKey(const ValueKey('$_next-member_rights')), findsNothing);

    // 2. It opens the canonical setup page of the step.
    await tester.tap(find.byKey(const ValueKey('$_next-places')));
    await tester.pumpAndSettle();
    expect(_path(tester), '/setup/step/places');
    expect(_path(tester), isNot(startsWith('/settings')));

    // 3. The resource is created; the app starts afresh over the same data.
    space.plan.seedSmallPlan(workspaceId: id);
    await _reloadIntoGuide(tester, space);
    expect(find.textContaining('Take bookings · 3 of 4 done'), findsOneWidget);
    expect(await space.step('places'), SetupStepState.ready);
    expect(await space.step('hours'), SetupStepState.ready);
    expect(
      await space.step('member_rights'),
      SetupStepState.needsConfiguration,
      reason: 'nothing completed falsely',
    );
    expect(await space.step('first_booking'), SetupStepState.blocked);
    expect(find.byKey(const ValueKey('$_next-member_rights')), findsOneWidget);
    expect(find.byKey(const ValueKey('$_next-places')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('$_next-member_rights')));
    await tester.pumpAndSettle();
    expect(_path(tester), '/setup/step/member_rights');

    // 4. The right is granted: the outcome is reached, the booking is open.
    await space.workspace.setRolePermission(
      id,
      'member',
      'makeReservations',
      enabled: true,
    );
    await _reloadIntoGuide(tester, space);
    expect(await space.reached('bookable'), isTrue);
    expect(await space.step('member_rights'), SetupStepState.ready);
    expect(
      await space.step('first_booking'),
      SetupStepState.needsConfiguration,
    );
    expect(find.textContaining('Take bookings · Done'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('$_next-pricing')),
      findsOneWidget,
      reason: 'the next action moves on to the next outcome',
    );

    // 5. A member books; the owner reads the same booking.
    final seat = space.plan.seats.single;
    final window = HalfDayWindows.morning(kTestNow);
    space.bookingMember = 'member-2';
    final booking = await space.reservations.create(
      workspaceId: id,
      seatId: seat.id,
      startsAt: window.start,
      endsAt: window.end,
    );
    space.bookingMember = 'member-1';
    final seen = await space.reservations.fetchById(booking);
    expect(seen?.workspaceId, id);
    expect(seen?.seatId, seat.id);
    expect(seen?.memberId, 'member-2');
    expect(seen?.startsAt, window.start);
    expect(seen?.endsAt, window.end);
    await _reloadIntoGuide(tester, space);
    expect(await space.step('first_booking'), SetupStepState.ready);
    expect(await space.reached('bookable'), isTrue);

    // The owner is shown what remains: the later outcomes are not reached.
    expect(await space.reached('money'), isFalse);
    expect(find.textContaining('Take bookings · Done'), findsOneWidget);
    expect(find.textContaining('Ready for money · 5 of 7 done'), findsOneWidget);
    expect(find.textContaining('Live · 6 of 9 done'), findsOneWidget);
  });
}
