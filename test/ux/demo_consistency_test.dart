// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2327 — the demo workspace is what the guide's screenshots and every
// first visitor see, so its pages must agree with each other and settle.
// One test per finding, each against the real Demo composition or the
// fixture it is built from.
import 'package:deskilo/core/demo/data/connected_installations.dart';
import 'package:deskilo/core/demo/data/device_prefs.dart';
import 'package:deskilo/core/demo/data/kpi_repositories.dart';
import 'package:deskilo/core/demo/demo_clock.dart';
import 'package:deskilo/core/demo/demo_finance_projection.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/i18n/money_format.dart';
import 'package:deskilo/core/ui/loading_view.dart';
import 'package:deskilo/features/directory/domain/messenger.dart';
import 'package:deskilo/features/kiosk/presentation/screens/kiosk_screen.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/visits/domain/guest_participation.dart';
import 'package:deskilo/features/workspace/domain/workspace_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/demo_owed.dart';
import '../helpers/screens/demo_journeys.dart' show pumpDemo;

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
    await pumpDemo(tester);
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

    final overview = demoFinanceForUser(journey.fixture.personalSpaces, journey.fixture.auth.currentUserId);
    expect(
      overview.invoices,
      isNotEmpty,
      reason: 'the member has invoices on the workspace Money page',
    );
    final mine = [
      for (final space in journey.fixture.personalSpaces)
        for (final member in [space.workspaces.myMember, ...space.workspaces.otherMembers])
          if (member.userId == journey.fixture.auth.currentUserId && !member.isKiosk)
            for (final i in space.money.invoices)
              if (i.memberId == member.id && !i.isVoided && i.settledByInvoiceId == null) i,
    ];
    expect(
      overview.invoices.map((i) => i.id).toSet(),
      mine.map((i) => i.id).toSet(),
    );
    expect(
      _shows('Nothing to pay — you are up to date.'),
      overview.outstanding.isEmpty,
    );
  });

  testWidgets('Me shows one amount to pay per currency on Finances and '
      'the home glance', (
    tester,
  ) async {
    final journey = await pumpDemo(tester, persona: DemoPersona.member);
    final owed = demoOwedFromTheSpaces(journey.fixture);
    expect(owed.keys.toSet(), {'EUR', 'CHF', 'GBP', 'USD'});

    await _go(tester, '/account-activity');
    final summary = find.byKey(const ValueKey('finances-summary'));
    for (final e in owed.entries) {
      expect(
        find.descendant(
          of: summary,
          // #3599 — Me names a currency without doubt: the dollars read USD.
          matching: find.text(
            MoneyFormat(
              e.key,
              locale: null,
              spaceAlphabetic: true,
              distinct: true,
            ).formatMinor(e.value),
          ),
        ),
        findsOneWidget,
        reason: 'the ${e.key} amount to pay, in the summary',
      );
    }

    await _go(tester, '/me');
    for (final currency in owed.keys) {
      expect(
        find.byKey(ValueKey('me-home-finance-glance-amount-$currency'),
            skipOffstage: false),
        findsOneWidget,
        reason: 'the $currency amount on the Me home glance',
      );
    }
  });

  testWidgets('Workspace status reads the demo\'s own invoices', (
    tester,
  ) async {
    final journey = await pumpDemo(tester);
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
      await pumpDemo(tester);
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
    final journey = await pumpDemo(tester);
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
    final journey = await pumpDemo(tester);
    await _go(tester, '/me');

    final listed = {for (final c in journey.fixture.directory.cards) c.id};
    const labels = {
      GuestVisitStatus.confirmed: 'Confirmed',
      GuestVisitStatus.requested: 'Requested',
    };
    expect(journey.fixture.guests.visits.map((v) => v.status).toSet(),
        labels.keys.toSet());
    final scrollable = find.descendant(
      of: find.byKey(const ValueKey('me-home-list')),
      matching: find.byType(Scrollable),
    ).first;
    for (final visit in journey.fixture.guests.visits) {
      expect(listed, contains(visit.workspaceId), reason: visit.id);
      final card = find.byKey(ValueKey('me-visit-${visit.id}'));
      // The finance and space sections can put visits below the fold.
      await tester.scrollUntilVisible(card, 300, scrollable: scrollable);
      await tester.pump();
      expect(card.hitTestable(), findsOneWidget, reason: visit.id);
      expect(find.descendant(of: card,
        matching: find.text(visit.workspaceName)).hitTestable(), findsOneWidget);
      expect(find.descendant(of: card,
        matching: find.text(labels[visit.status]!)).hitTestable(), findsOneWidget);
    }
  });

  testWidgets('Business analytics offers the team\'s saved views', (
    tester,
  ) async {
    await pumpDemo(tester);
    await _go(tester, '/bi');
    expect(find.byType(LoadingView), findsNothing);

    await tester.tap(find.byKey(const ValueKey('bi-views')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(_shows('Finance against last year'), isTrue);
    expect(_shows('Quarter by quarter'), isTrue);
  });

  // ── #2405: a second space a visitor can follow to the end ──────────

  Future<void> openListed(WidgetTester tester, String id) async {
    await _go(tester, '/discover');
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    // The list is the first face; View opens the space's page.
    final view = find.byKey(
      ValueKey('directory-view-$kDemoServerOrigin/$id'),
      skipOffstage: false,
    );
    await tester.ensureVisible(view);
    await tester.tap(view);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('the second space ends inside the demo: its page, its '
      'conditions, a request to join and a message to its hosts', (
    tester,
  ) async {
    final journey = await pumpDemo(tester, persona: DemoPersona.member);
    await openListed(tester, 'demo-quai');

    expect(_shows('Le Quai Numérique'), isTrue);
    expect(find.textContaining('Day pass €18'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('portal-request-membership')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(journey.fixture.directory.requests, ['demo-quai']);
    expect(find.textContaining('Request sent'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('write-to-hosts')));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(_shows('Inès Caradec'), isTrue, reason: 'the hosts are named '
        'before anything is written');
    await tester.enterText(
      find.byKey(const ValueKey('inquiry-body')),
      'Could I visit on Thursday?',
    );
    await tester.tap(find.byKey(const ValueKey('inquiry-send')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    final sent = journey.fixture.messenger.inboxRows.where(
      (row) => row['workspace_id'] == 'demo-quai',
    );
    expect(sent, hasLength(1), reason: 'the inquiry lands in the fixture');
    expect(sent.single['context_kind'], MessageContextKind.inquiryOut.wire);
    expect(journey.fixture.outward.nothingLeft, isTrue);
    // The thread's capture shield asks the platform with a 5 s deadline,
    // on the way in and on the way out.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('the space\'s own card offers to enter it, not to join it', (
    tester,
  ) async {
    await pumpDemo(tester);
    await openListed(tester, 'ws-1');

    expect(find.byKey(const ValueKey('portal-enter')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('portal-request-membership')),
      findsNothing,
    );
  });

  test('a stranger\'s visit request reaches the hosts, not the members',
      () async {
    final fixture = DemoFixture.build();
    Future<bool> listed() async => (await fixture.messenger.inbox()).any(
          (row) => row['context_id'] == 'demo-inquiry-visit',
        );
    for (final persona in DemoPersona.values) {
      fixture.becomePersona(persona);
      expect(
        await listed(),
        persona == DemoPersona.owner || persona == DemoPersona.admin,
        reason: persona.name,
      );
    }
  });

  testWidgets('Me › Messages holds a message request from the applicant', (
    tester,
  ) async {
    await pumpDemo(tester);
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
    final journey = await pumpDemo(tester);
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

  // ---- #3601: the Demo tells one story ----------------------------------

  test('a subscription is priced once: the live band is the invoiced plan '
      'price, and the statement charges it once', () async {
    final f = DemoFixture.build();
    final lastMonth = DateTime(f.seededAt.year, f.seededAt.month - 1);
    final bandFees = {for (final b in f.money.feeBands) b.feeCents};
    final subscriptions = f.money.invoices.where(
      (i) =>
          i.number.startsWith('F-') &&
          i.issuedAt.year == lastMonth.year &&
          i.issuedAt.month == lastMonth.month,
    );
    expect(subscriptions, isNotEmpty);
    for (final invoice in subscriptions) {
      expect(bandFees, contains(invoice.totalCents),
          reason: '${invoice.number}: a plan invoiced at a price no band '
              'charges');
    }
    final period = '${f.seededAt.year}-'
        '${f.seededAt.month.toString().padLeft(2, '0')}';
    final statement = await f.money.fetchStatement('member-1', period);
    final others = f.money.ledger
        .where((e) =>
            e.memberId == 'member-1' &&
            e.period == period &&
            e.category != LedgerCategory.subscription)
        .fold(0, (n, e) => n + (e.kind == LedgerKind.credit ? e.amountCents : -e.amountCents));
    expect(statement.balanceCents,
        others - statement.feeCents - statement.overageCents,
        reason: 'the subscription is in the balance once, as the fee');
  });

  test('every invoice names the member it belongs to', () {
    final f = DemoFixture.build();
    for (final invoice in f.money.invoices) {
      expect(invoice.memberName, f.workspaces.memberNames[invoice.memberId],
          reason: '${invoice.number} (${invoice.memberId})');
    }
  });

  test('capacity offers no seat-hour on a closure day', () async {
    final f = DemoFixture.build();
    final from = DateTime(f.seededAt.year, f.seededAt.month);
    final to = DateTime(f.seededAt.year, f.seededAt.month + 1);
    final repo = DemoCapacityKpiRepository(
      plan: f.floorPlan,
      reservations: f.reservations,
      now: f.seededAt,
      closureDays: f.workspaces.closureDays,
    );
    final kpi = await repo.seatCapacity('ws-1', from: from, to: to);
    final closed = {
      for (final c in f.workspaces.closureDays)
        if (c.workspaceId == 'ws-1') DateTime(c.day.year, c.day.month, c.day.day),
    };
    var open = 0;
    for (var d = from; d.isBefore(to); d = d.add(const Duration(days: 1))) {
      if (d.weekday <= DateTime.friday &&
          !closed.contains(DateTime(d.year, d.month, d.day))) {
        open++;
      }
    }
    expect(kpi.offeredSeatHours, kpi.seats * open * 9.0);
    final withoutClosures = await DemoCapacityKpiRepository(
      plan: f.floorPlan,
      reservations: f.reservations,
      now: f.seededAt,
    ).seatCapacity('ws-1', from: from, to: to);
    expect(kpi.offeredSeatHours, lessThan(withoutClosures.offeredSeatHours),
        reason: 'the fixture seeds closure days inside the month');
  });

  testWidgets('the Demo bar names the date the demo is fixed at', (tester) async {
    await pumpDemo(tester);
    expect(find.byKey(const ValueKey('demo-bar-date')), findsOneWidget);
    expect(find.textContaining('2026'), findsWidgets);
    final text = tester.widget<Text>(find.byKey(const ValueKey('demo-bar-date')));
    expect(text.data, startsWith('Demo · '));
    expect(text.data, contains('May'));
  });

  test("the register's newest rows and its first open invoice are not the "
      "owner's own", () {
    final f = DemoFixture.build();
    final register = [...f.money.invoices.where((i) => !i.isVoided)]
      ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
    // The newest month has four invoices of other members; they lead it.
    expect(
      register.take(4).map((i) => i.memberId),
      everyElement(isNot('member-1')),
      reason: 'the owner is a paying member, not the first thing a visitor '
          'reads in the register',
    );
    final firstOpen = register.firstWhere(
      (i) => i.totalCents > 0 && !f.money.invoiceMatchesStore.containsKey(i.id),
    );
    expect(firstOpen.memberId, isNot('member-1'));
    final owner = register.where((i) => i.memberId == 'member-1');
    expect(owner, isNotEmpty, reason: 'her own invoices stay');
  });

  test('the Demo opens in the language the app is shown in', () {
    final store = InMemoryLocaleStore()..adopt('fr');
    expect(store.languageCode, 'fr');
    store.adopt('de');
    expect(store.languageCode, 'fr', reason: 'a choice in the Demo is kept');
    final none = InMemoryLocaleStore()..adopt(null);
    expect(none.languageCode, isNull, reason: 'the device decides then');
  });
}
