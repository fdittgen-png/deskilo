// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1247 — the UX score, as a build output.
//
// The issue asks for the counterweight to the rest of the #1225
// programme: the backend gets more sophisticated, the interface gets
// LESS. And it names the measurement itself —
//
//   "count the taps from app open to booked, and from app open to a
//    decision made. Those two numbers are the UX score."
//
// So here they are, counted rather than estimated, and ratcheted: a
// number may go DOWN freely and may only go up with a reason in the diff.
// That is the same mechanism as `file_length_test` and `_pairBudget`,
// pointed at the thing a member actually experiences.
//
// A design pass comes before the decision surface the issue proposes
// (and this file is not it). What this does is establish what the paths
// cost TODAY, so the redesign has a number to beat instead of an
// impression to argue with.
import 'package:deskilo/features/reservations/presentation/widgets/booking_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deskilo/app/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/events/events_screen_test.dart' show pumpEvents, event;
import '../helpers/fake_event_repository.dart';
import '../helpers/fake_money_repository.dart';
import '../helpers/mock_providers.dart';
import '../features/reservations/reserve_hub_test.dart'
    show pumpHub, seatCenter;
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/domain/money_face.dart';
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import '../features/money/money_faces_test.dart' show pumpFaces, openInvoice;
import '../features/workspace/onboarding_flow_test.dart'
    show pumpWithoutWorkspace;

/// Counts the taps a path costs.
///
/// Every deliberate touch is one, whether it lands on a widget or at a
/// point on the canvas — a member does not care which. Scrolling is not
/// counted: it is a cost, but it is not a decision, and conflating the
/// two would let a redesign "win" by replacing three taps with a long
/// scroll.
class Taps {
  int count = 0;

  Future<void> at(WidgetTester tester, Offset point) async {
    count++;
    await tester.tapAt(point);
    await tester.pumpAndSettle();
  }

  Future<void> on(WidgetTester tester, Finder finder) async {
    count++;
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }
}

void main() {
  // The two numbers. Lower them when a path gets shorter; raising one
  // needs a sentence in the pull request saying what the member got in
  // exchange.
  //
  // Both counts EXCLUDE the tap that opens the destination from the
  // shell, because the pump helpers do it — and the app boots onto the
  // hub anyway, so for booking it is not a real tap at all. Each test
  // says what it is counting.
  const bookingBudget = 2;
  const decisionBudget = 1;

  testWidgets('app open to booked: the member takes the default window '
      'and taps the seat', (tester) async {
    // pumpHub boots the app and presses Reserve — the destination the
    // app already opens on.
    final repo = await pumpHub(tester);
    final taps = Taps();

    await taps.at(tester, seatCenter(tester));
    expect(find.byType(BookingSheet), findsOneWidget,
        reason: 'tapping a free seat opens the sheet');

    await taps.on(tester, find.byKey(const ValueKey('booking-confirm')));

    expect(repo.reservations, hasLength(1),
        reason: 'the booking was actually made — a tap budget over a path '
            'that does not complete measures nothing');
    expect(
      taps.count,
      lessThanOrEqualTo(bookingBudget),
      reason: 'booking a seat for the default window took ${taps.count} '
          'taps, budget $bookingBudget. This is the path the app exists '
          'for and the first number of the UX score (#1247). Lower the '
          'budget when it gets shorter; raising it needs a sentence '
          'saying what the member got in exchange.',
    );
  });

  testWidgets('app open to a decision made: the pending thing is pinned, '
      'and deciding it is one tap', (tester) async {
    // pumpEvents boots the app and opens the alerts face — where the
    // bell badge already sends somebody who has something waiting.
    final repo = await pumpEvents(
      tester,
      seed: [
        event(
          actor: 'member-2',
          subject: 'member-1',
          status: EventStatus.pending,
        ),
      ],
    );
    final taps = Taps();

    expect(find.text('Waiting for your confirmation'), findsOneWidget,
        reason: 'the thing needing a decision is PINNED rather than found '
            '— that is what makes the next tap the last one');

    await taps.on(tester, find.text('Accept'));

    expect(repo.events.single.status, EventStatus.confirmed,
        reason: 'the decision actually took effect');
    expect(
      taps.count,
      lessThanOrEqualTo(decisionBudget),
      reason: 'deciding a pending request took ${taps.count} taps, budget '
          '$decisionBudget. This is the second number of the UX score '
          '(#1247): what an administrator has to do to clear the thing '
          'that was waiting on them.',
    );
  });

  testWidgets('#1306 — the association case: the events bell is OFF, and a '
      'pending decision is still reachable and decided in the budget',
      (tester) async {
    // Red before #1306 S2: with eventsTab off there was no path to a
    // decision at all — the bell was gone and /events redirected away.
    final events = FakeEventRepository()
      ..events.add(event(
        actor: 'member-2',
        subject: 'member-1',
        status: EventStatus.pending,
      ));
    await tester.pumpWidget(ProviderScope(
      overrides: standardTestOverrides(
        events: events,
        workspace: FakeWorkspaceRepository.withWorkspace(featureFlags: const {
          'eventsTab': false,
          'calendarTab': true,
          'calendarHub': true,
          'calendarValidations': true,
        }),
      ),
      child: const DeskiloApp(),
    ));
    await tester.pumpAndSettle();
    const bothDecisionBudget = 2;
    final taps = Taps();

    expect(find.byKey(const ValueKey('shell-events-bell')), findsNothing,
        reason: 'the bell really is off');
    // The Calendar destination carries the count it opens on.
    expect(
      find.descendant(
          of: find.byType(Badge), matching: find.byIcon(Icons.calendar_month_outlined)),
      findsOneWidget,
      reason: 'the pending decision badges the Calendar destination',
    );

    await taps.on(tester, find.text('Calendar'));
    expect(find.byKey(const ValueKey('pending-decisions')), findsOneWidget,
        reason: 'the badge opens the content it counts');

    await taps.on(tester, find.text('Accept'));
    expect(events.events.single.status, EventStatus.confirmed,
        reason: 'the decision actually took effect');
    expect(taps.count, lessThanOrEqualTo(bothDecisionBudget),
        reason: 'with the bell off, deciding took ${taps.count} taps from '
            'launch, budget $bothDecisionBudget (#1306): one to reach the '
            'Calendar, one to decide.');
  });

  // #1247 — the three journeys that were not measured. Each counts from
  // the screen the app is on at launch, and each asserts the journey
  // actually arrived. docs/ux/JOURNEYS.md is the table.

  testWidgets('app open to an invoice explained: the member sees its lines '
      'and total', (tester) async {
    const explainBudget = 3;
    final money = FakeMoneyRepository();
    final id = await openInvoice(money, ageDays: 3);
    // pumpFaces boots the app AND taps the Money destination; that tap is
    // part of this journey, so it is counted by hand.
    await pumpFaces(tester, money: money, admin: false);
    final taps = Taps()..count = 1;

    await taps.on(tester, find.byKey(ValueKey('money-face-${MoneyFace.invoices.name}')));
    await taps.on(tester, find.byKey(ValueKey('my-invoice-$id')));

    expect(find.byKey(const ValueKey('invoice-detail-total')), findsOneWidget,
        reason: 'the explanation is on screen: what it adds up to');
    expect(find.byKey(const ValueKey('invoice-detail-line-0')), findsOneWidget,
        reason: 'and why: the first line of what was charged');
    expect(taps.count, lessThanOrEqualTo(explainBudget),
        reason: 'explaining an invoice took ${taps.count} taps, budget '
            '$explainBudget (#1247): Money, Invoices, the invoice.');
  });

  testWidgets('app open to a workspace setting changed: opening a day of the '
      'week', (tester) async {
    const settingBudget = 3;
    final workspace = FakeWorkspaceRepository.withWorkspace();
    await tester.pumpWidget(ProviderScope(
      overrides: standardTestOverrides(workspace: workspace),
      child: const DeskiloApp(),
    ));
    await tester.pumpAndSettle();
    final taps = Taps();

    await taps.on(tester, find.byTooltip('Settings'));
    final tile = find.text('Availability');
    await tester.scrollUntilVisible(tile, 200,
        scrollable: find.byType(Scrollable).first);
    await taps.on(tester, tile);
    final before = List.of(workspace.openWeekdays['ws-1'] ?? const <int>[]);
    await taps.on(tester, find.text('Sat'));

    expect(workspace.openWeekdays['ws-1'], isNot(equals(before)),
        reason: 'the setting was actually saved');
    expect(taps.count, lessThanOrEqualTo(settingBudget),
        reason: 'changing an opening day took ${taps.count} taps, budget '
            '$settingBudget (#1247): Settings, Availability, the day.');
  });

  testWidgets('onboarding to a usable workspace: a name, the suggested '
      'settings, and Create', (tester) async {
    // 1 → 2 (#1303 S2): the second tap is the confirm step — a person sees
    // the country, the pair and the template before anything is created.
    const onboardingBudget = 2;
    final repo = await pumpWithoutWorkspace(tester);
    final taps = Taps();

    // Typing the name is input, not a decision the counter charges for.
    await tester.enterText(find.byType(TextFormField).first, 'Kraftwerk');
    await tester.pump();
    await taps.on(tester, find.byKey(const ValueKey('onboarding-use-suggested')));
    final create = find.text('Create workspace');
    await tester.ensureVisible(create);
    await taps.on(tester, create);

    expect(repo.workspaces, hasLength(1));
    expect(repo.createRequests.single.templateId, isNotNull,
        reason: 'usable means a room to book, not an empty space');
    expect(find.byType(ShellBottomBar), findsOneWidget);
    expect(taps.count, lessThanOrEqualTo(onboardingBudget),
        reason: 'reaching a usable workspace took ${taps.count} taps, budget '
            '$onboardingBudget (#1247).');
  });

  // #1339 — a test asserting `bookingBudget > 0` against a constant
  // declared eleven lines above it used to close this file. It could
  // not fail for any change to the product, and it could not fail for a
  // vacuous budget either: a budget of zero fails the real measurements
  // above, which count two taps and one. What keeps those honest is
  // that each asserts the journey ARRIVED — a reservation in the
  // repository, an event that changed status — and they are the
  // assertions that would go red if the path stopped completing.
}
