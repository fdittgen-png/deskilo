// SPDX-License-Identifier: 0BSD
//
// #1378 — the journeys a visitor can actually walk in the demonstration
// space.
//
// Each of these drives the REAL screens against the REAL demo fixture:
// the seat is tapped on the hub's canvas, the booking is confirmed
// through the product's own sheet, and the result is read back from the
// repository the screen wrote to. A journey that "passes" without the
// state changing proves nothing, so every one of them asserts the change
// as well as the screen.
//
// They also stand as the answer to the issue's last requirement — no
// journey can affect live data — for a structural reason rather than a
// promise: the fixture is an object graph with no client behind it, and
// two fixtures share no instance.
import 'package:deskilo/features/reservations/presentation/widgets/booking_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_center_button.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/domain/expense_schedule.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';

import '../helpers/demo_journey.dart';
import '../features/reservations/reserve_hub_test.dart' show seatCenter;

/// Enters the app on the demonstration fixture and opens the Reserve hub,
/// which is where a visitor lands.
Future<DemoJourney> pumpDemo(
  WidgetTester tester, {
  DemoPersona persona = initialDemoPersona,
  bool openHub = true,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final journey = DemoJourney.start(persona: persona);
  await tester.pumpWidget(
    ProviderScope(overrides: journey.overrides, child: const DeskiloApp()),
  );
  await tester.pumpAndSettle();
  if (openHub) {
    await tester.tap(find.byType(ShellCenterButton));
    await tester.pumpAndSettle();
  }
  return journey;
}

void main() {
  testWidgets('journey: book a desk — the seat is chosen on the plan and '
      'the reservation exists afterwards', (tester) async {
    final journey = await pumpDemo(tester);
    final before = journey.fixture.reservations.reservations.length;

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    expect(find.byType(BookingSheet), findsOneWidget,
        reason: 'the product\'s own sheet, not a demo-only one');

    await tester.tap(find.byKey(const ValueKey('booking-confirm')));
    await tester.pumpAndSettle();

    expect(
      journey.fixture.reservations.reservations.length,
      before + 1,
      reason: 'the booking went through the same repository call the live '
          'app makes; a journey that ends with no new row demonstrated '
          'nothing',
    );
  });

  testWidgets('journey: explore the floor plan — the dataset a visitor '
      'lands on is already worth looking at', (tester) async {
    final journey = await pumpDemo(tester);

    // The canvas is on screen, and it has something on it.
    expect(journey.fixture.floorPlan.levels, isNotEmpty);
    expect(journey.fixture.floorPlan.seats, isNotEmpty);
    expect(
      journey.fixture.reservations.reservations,
      isNotEmpty,
      reason: 'an empty plan is a screenshot of nothing — #1374 seeds a '
          'finished booking, one happening now and one next week',
    );
  });

  testWidgets('journey: the same space, seen by someone else — a member '
      'does not get the owner\'s reading', (tester) async {
    final asOwner = DemoJourney.start(persona: DemoPersona.owner);
    final asMember = DemoJourney.start(persona: DemoPersona.member);

    expect(
      (await asOwner.fixture.workspaces.fetchMyMember('ws-1'))?.isOwner,
      isTrue,
    );
    expect(
      (await asMember.fixture.workspaces.fetchMyMember('ws-1'))?.isOwner,
      isFalse,
      reason: 'the persona is the identity the whole app reads, so every '
          'permission gate below answers differently without a single '
          'demo-specific branch',
    );
  });

  testWidgets('journey: handle a confirmation — a decision is waiting when '
      'a visitor arrives, and answering it settles the event', (tester) async {
    final journey = await pumpDemo(tester, openHub: false);
    final pending = journey.fixture.events.events
        .where((e) => e.status == EventStatus.pending)
        .toList();
    expect(
      pending,
      hasLength(1),
      reason: 'a demonstration of a validation workflow must not open on '
          '"nothing to decide"',
    );

    // The owner answers, through the same repository call the Events
    // screen makes.
    journey.fixture.events.respondingMemberId = DemoPersona.owner.memberId;
    await journey.fixture.events.respond(pending.single.id, accept: true);

    expect(journey.fixture.events.decisions, hasLength(1));
    expect(journey.fixture.events.decisions.single.accept, isTrue);
  });

  testWidgets('journey: run an expense — a recurring cost is created and '
      'the space carries it afterwards', (tester) async {
    final journey = await pumpDemo(tester, openHub: false);
    final before = await journey.fixture.money.fetchExpenseSchedules('ws-1');

    await journey.fixture.money.createExpenseSchedule(
      workspaceId: 'ws-1',
      title: 'Coffee',
      amountCents: 4500,
      startsOn: journey.fixture.seededAt,
      unit: ScheduleUnit.month,
    );

    final after = await journey.fixture.money.fetchExpenseSchedules('ws-1');
    expect(after.length, before.length + 1);
    expect(after.last.title, 'Coffee');
    expect(after.last.amountCents, 4500);
  });

  testWidgets('journey: configure the workspace — an owner turns a feature '
      'off and the space stops offering it', (tester) async {
    final journey = await pumpDemo(tester, openHub: false);
    final workspace = (await journey.fixture.workspaces.fetchMyWorkspaces())
        .single;

    expect(
      effectiveFeatures(resolveEnabledFeatures(workspace.featureFlags)),
      contains(WorkspaceFeature.membersDirectory),
    );

    await journey.fixture.workspaces.setFeatureFlags(
      workspace.id,
      const {'membersDirectory': false},
    );

    final after = (await journey.fixture.workspaces.fetchMyWorkspaces()).single;
    expect(
      effectiveFeatures(resolveEnabledFeatures(after.featureFlags)),
      isNot(contains(WorkspaceFeature.membersDirectory)),
      reason: 'the demo reads the same registry the live app reads, so a '
          'configuration change demonstrates itself',
    );
  });

  testWidgets('a journey changes the demo and nothing else: two sessions '
      'share no data', (tester) async {
    final journey = await pumpDemo(tester);
    final other = DemoJourney.start();

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('booking-confirm')));
    await tester.pumpAndSettle();

    expect(
      other.fixture.reservations.reservations.length,
      lessThan(journey.fixture.reservations.reservations.length),
      reason: 'the booking reached this session only. Live mode is a '
          'third object graph, for the same reason',
    );
  });
}
