// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2327 — the demo workspace is what the guide's screenshots and every
// first visitor see, so its pages must agree with each other and settle.
// One test per finding, each against the real Demo composition or the
// fixture it is built from.
import 'package:deskilo/core/demo/demo_clock.dart';
import 'package:deskilo/core/demo/demo_finances.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/features/kiosk/presentation/screens/kiosk_screen.dart';
import 'package:deskilo/core/ui/loading_view.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/workspace/domain/workspace_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'demo_journeys_test.dart' show pumpDemo;

Future<void> _go(WidgetTester tester, String route) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(route);
  // Bounded pumps, not pumpAndSettle: a card that never settles is the
  // failure under test, and pumpAndSettle would only time out.
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

bool _shows(String text) => find.text(text).evaluate().isNotEmpty;

void main() {
  testWidgets('Documents lists the seeded library', (tester) async {
    await pumpDemo(tester, persona: DemoPersona.owner);
    await _go(tester, '/documents');

    expect(_shows('House rules'), isTrue);
    expect(_shows('Wi-Fi and printer guide'), isTrue);
    expect(_shows('Insurance certificate'), isTrue);
  });

  test('every seeded document sits on a shelf the app knows', () {
    final fixture = DemoFixture.build();
    for (final d in fixture.workspaces.documents) {
      expect(WorkspaceDocument.categories, contains(d.category), reason: d.id);
    }
  });

  testWidgets('Me › Finances shows the member\'s own invoices', (tester) async {
    final journey = await pumpDemo(tester);
    await _go(tester, '/account-activity');

    final overview = demoFinanceOverview(journey.fixture);
    expect(
      overview.invoices,
      isNotEmpty,
      reason: 'the member has invoices on the workspace Money page',
    );
    final mine = journey.fixture.money.invoices.where(
      (i) =>
          i.memberId == journey.fixture.actor.memberId &&
          i.voidedAt == null &&
          i.kind != InvoiceKind.settlement &&
          i.totalCents > 0,
    );
    expect(
      overview.invoices.map((i) => i.id).toSet(),
      mine.map((i) => i.id).toSet(),
    );
    expect(
      _shows('Nothing to pay — you are up to date.'),
      overview.outstanding.isEmpty,
    );
  });

  testWidgets('Workspace status reads the demo\'s own invoices', (
    tester,
  ) async {
    final journey = await pumpDemo(tester, persona: DemoPersona.owner);
    await _go(tester, '/money/status');

    final status = await journey.fixture.money.fetchWorkspaceStatus(
      'ws-1',
      '2026-03',
      '2026-05',
    );
    expect(status.invoicedCents, greaterThan(0));
    expect(_shows('€0.00'), isTrue, reason: 'some lines are genuinely zero');
    expect(
      tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => t.data == '€0.00')
          .length,
      lessThan(8),
      reason: 'every figure read zero although the demo has invoices',
    );
  });

  test('no two places on a level overlap', () {
    final plan = DemoFixture.build().floorPlan;
    final byDesk = {for (final d in plan.desks) d.id: d};
    for (final level in plan.levels) {
      final seats = [
        for (final s in plan.seats)
          if (byDesk[s.deskId] != null &&
              plan.offices.any(
                (o) =>
                    o.id == byDesk[s.deskId]!.officeId && o.levelId == level.id,
              ))
            s,
      ];
      for (var i = 0; i < seats.length; i++) {
        for (var j = i + 1; j < seats.length; j++) {
          final a = seats[i].footprint, b = seats[j].footprint;
          final overlap =
              a.x < b.x + b.w &&
              b.x < a.x + a.w &&
              a.y < b.y + b.h &&
              b.y < a.y + a.h;
          expect(
            overlap,
            isFalse,
            reason: '${seats[i].name} and ${seats[j].name} overlap',
          );
        }
      }
    }
  });

  test('every seeded booking starts and ends on the same day, on the '
      "space's clock", () {
    final fixture = DemoFixture.build();
    for (final r in fixture.reservations.reservations) {
      expect(
        demoDateOf(r.startsAt),
        demoDateOf(r.endsAt),
        reason: '${r.id}: ${r.startsAt} – ${r.endsAt}',
      );
    }
  });

  test("the demo's now is ten o'clock in the space, on any device", () {
    final now = DemoFixture.build().seededAt;
    expect(demoAt(now.year, now.month, now.day, 10), now);
  });

  testWidgets('the space keeps one colour from one boot to the next', (
    tester,
  ) async {
    Future<int> primaryOnMoney() async {
      await pumpDemo(tester, persona: DemoPersona.owner);
      await _go(tester, '/money');
      return Theme.of(tester.element(find.byType(Scaffold).last))
          .colorScheme
          .primary
          .toARGB32();
    }

    final first = await primaryOnMoney();
    await tester.pumpWidget(const SizedBox());
    final second = await primaryOnMoney();
    expect(second, first);
  });
  // ── #2327 item 8: the processes that were not demonstrable ──────────

  testWidgets('the public directory lists the space and its neighbours', (
    tester,
  ) async {
    final journey = await pumpDemo(tester, persona: DemoPersona.owner);
    await _go(tester, '/discover');

    expect(journey.fixture.directory.cards, hasLength(3));
    for (final card in journey.fixture.directory.cards) {
      expect(_shows(card.name), isTrue, reason: card.name);
    }
    expect(journey.fixture.directory.pages['ws-1']?['published'], isTrue);
  });

  testWidgets('Me › Home shows the guest visits, in listed spaces', (
    tester,
  ) async {
    final journey = await pumpDemo(tester, persona: DemoPersona.owner);
    await _go(tester, '/me');

    final listed = {for (final c in journey.fixture.directory.cards) c.id};
    for (final visit in journey.fixture.guests.visits) {
      expect(listed, contains(visit.workspaceId), reason: visit.id);
      expect(
        find.byKey(ValueKey('me-visit-${visit.id}'), skipOffstage: false),
        findsOneWidget,
      );
    }
    expect(_shows('Confirmed'), isTrue);
    expect(_shows('Requested'), isTrue);
  });

  testWidgets('Business analytics offers the team\'s saved views', (
    tester,
  ) async {
    await pumpDemo(tester, persona: DemoPersona.owner);
    await _go(tester, '/bi');
    expect(find.byType(LoadingView), findsNothing);

    await tester.tap(find.byKey(const ValueKey('bi-views')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(_shows('Finance against last year'), isTrue);
    expect(_shows('Quarter by quarter'), isTrue);
  });

  testWidgets('Me › Messages holds a message request from the applicant', (
    tester,
  ) async {
    await pumpDemo(tester, persona: DemoPersona.owner);
    await _go(tester, '/me?tab=messages');

    expect(find.byKey(const ValueKey('message-requests')), findsOneWidget);
    expect(_shows('Dov Meir'), isTrue);
    expect(
      find.byKey(const ValueKey('request-accept-demo-request-dov')),
      findsOneWidget,
    );
  });

  testWidgets('the kiosk tablet asks, then shows the plan to check in at', (
    tester,
  ) async {
    final journey = await pumpDemo(
      tester,
      persona: DemoPersona.kiosk,
      openHub: false,
    );
    expect(journey.fixture.workspaces.myMember.isKiosk, isTrue);
    expect(find.byKey(const ValueKey('kiosk-gate-title')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('kiosk-gate-start')));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(KioskScreen), findsOneWidget);
    expect(find.byType(LoadingView), findsNothing);
  });

  testWidgets('the development twin: deployable, with its journal', (
    tester,
  ) async {
    final journey = await pumpDemo(tester, persona: DemoPersona.owner);
    await _go(tester, '/deployment');

    expect(find.byKey(const ValueKey('deploy-list')), findsOneWidget);
    expect(find.byKey(const ValueKey('deploy-no-twin')), findsNothing);
    expect(find.byKey(const ValueKey('deploy-not-allowed')), findsNothing);
    final list = find.descendant(
      of: find.byKey(const ValueKey('deploy-list')),
      matching: find.byType(Scrollable),
    );
    for (final d in journey.fixture.deployments.journalRows) {
      final row = find.byKey(ValueKey('deploy-journal-${d.id}'));
      await tester.scrollUntilVisible(row, 200, scrollable: list.first);
      await tester.pump();
      expect(row, findsOneWidget);
      expect(d.actorName, 'Ada Lindqvist');
    }
    expect(find.textContaining('Ada Lindqvist'), findsWidgets);
  });
}
