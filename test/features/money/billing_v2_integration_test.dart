// SPDX-License-Identifier: MIT
//
// Billing v2 integration coverage (#134, epic #121): edge matrices and
// end-to-end-through-fakes flows that tie the money and events surfaces
// together — regressions any single-widget test would miss.
import 'dart:io';
import 'dart:typed_data';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/domain/bill_pdf.dart';
import 'package:deskilo/features/money/domain/bill_sections.dart';
import 'package:deskilo/features/money/domain/fee_band.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/domain/statement.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../helpers/fake_event_repository.dart';
import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

/// The band whose `(fromPct, toPct]` interval contains [pct] — the same
/// inclusive-upper lookup the statement SQL uses to pick a member's fee.
FeeBand bandFor(int pct, List<FeeBand> bands) =>
    bands.firstWhere((b) => pct > b.fromPct && pct <= b.toPct);

FeeBand band(int fromPct, int toPct, {int feeCents = 1000}) => FeeBand(
      id: 'b-$fromPct-$toPct',
      workspaceId: 'ws-1',
      fromPct: fromPct,
      toPct: toPct,
      feeCents: feeCents,
      overageFeeCents: 100,
    );

Future<FakeMoneyRepository> pumpMoney(
  WidgetTester tester, {
  FakeMoneyRepository? money,
  FakeEventRepository? events,
  List<Override>? overrides,
}) async {
  money ??= FakeMoneyRepository();
  // Tall surface: the whole bill plus the action buttons stay in the
  // viewport, so no scrolling choreography between assertions.
  tester.view.physicalSize = const Size(600, 2400);
  tester.view.devicePixelRatio = 1.5;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides:
          overrides ?? standardTestOverrides(money: money, events: events),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Money'));
  await tester.pumpAndSettle();
  return money;
}

Statement statement({
  int subscriptionPct = 50,
  int feeCents = 15000,
  required int includedHalfDays,
  required int openDays,
  required int usedHalfDays,
  int extraHalfDays = 0,
  int overageCents = 0,
}) =>
    Statement(
      period: '2026-07',
      subscriptionPct: subscriptionPct,
      feeCents: feeCents,
      includedHalfDays: includedHalfDays,
      openDays: openDays,
      usedHalfDays: usedHalfDays,
      extraHalfDays: extraHalfDays,
      overageCents: overageCents,
      creditsCents: feeCents,
      balanceCents: -overageCents,
    );

LedgerEntry ledgerEntry({
  required String id,
  required LedgerKind kind,
  required LedgerCategory category,
  required int amountCents,
  String description = '',
  required String period,
}) =>
    LedgerEntry(
      id: id,
      memberId: 'member-1',
      kind: kind,
      category: category,
      amountCents: amountCents,
      description: description,
      period: period,
      createdAt: DateTime(2026, 7, 5),
    );

WorkspaceEvent pendingEvent({
  required String id,
  required EventType type,
  required Map<String, dynamic> payload,
}) =>
    WorkspaceEvent(
      id: id,
      workspaceId: 'ws-1',
      type: type,
      action: EventAction.submitted,
      actorMemberId: 'member-1',
      subjectMemberId: 'member-1',
      payload: payload,
      status: EventStatus.pending,
      createdAt: DateTime(2026, 7, 6),
    );

/// The one seed the cross-surface tests share: two confirmed service
/// charges (300 + 80 = 380 cents) and one confirmed payment credit.
List<LedgerEntry> crossSurfaceLedger(String period) => [
      ledgerEntry(
        id: 'l-coffee',
        kind: LedgerKind.charge,
        category: LedgerCategory.service,
        amountCents: 300,
        description: 'Coffee x2',
        period: period,
      ),
      ledgerEntry(
        id: 'l-printing',
        kind: LedgerKind.charge,
        category: LedgerCategory.service,
        amountCents: 80,
        description: 'Printing x4',
        period: period,
      ),
      ledgerEntry(
        id: 'l-payment',
        kind: LedgerKind.credit,
        category: LedgerCategory.payment,
        amountCents: 15000,
        description: 'Bank transfer',
        period: period,
      ),
    ];

const pdfStrings = BillPdfStrings(
  title: 'Monthly bill',
  subscription: 'Subscription 50%',
  entitlement: '24 of 22 half-days used (22 open days)',
  overage: '2 extra half-days',
  accessorySupplements: 'Accessory supplements',
  services: 'Consumed services',
  servicesTotal: 'Services total',
  serviceFallback: 'Service',
  openPositions: 'Open positions',
  pendingBadge: 'pending validation',
  paymentsCredits: 'Payments & credits',
  paymentFallback: 'Payment',
  expenseFallback: 'Expense reimbursement',
  adjustmentFallback: 'Adjustment',
  eventPayment: 'Payment',
  eventExpense: 'Expense',
  eventAdjustment: 'Adjustment',
  balance: 'Balance',
  settled: 'Settled',
  outstanding: 'Outstanding',
);

pw.Font ttf(String path) => pw.Font.ttf(
      ByteData.sublistView(File(path).readAsBytesSync()),
    );

void main() {
  group('band selection — inclusive-upper (fromPct, toPct] edges', () {
    // Guards the client-side mirror of the statement SQL's band pick: a
    // member's pct must land in exactly one band, boundaries included
    // upward, never downward.
    final seeded = FakeMoneyRepository().feeBands;

    test('pct 1 lands in the first band', () {
      expect(bandFor(1, seeded).fromPct, 0);
    });

    test('a pct exactly on a boundary lands in the LOWER band', () {
      // 25 belongs to (0,25], not (25,50] — the inclusive-upper rule.
      expect(bandFor(25, seeded).toPct, 25);
      expect(bandFor(26, seeded).fromPct, 25);
    });

    test('pct 100 lands in the last band', () {
      expect(bandFor(100, seeded).fromPct, 50);
      expect(bandFor(100, seeded).toPct, 100);
    });

    test('a single full-width band catches every pct from 1 to 100', () {
      final single = [band(0, 100)];
      for (final pct in [1, 50, 100]) {
        expect(bandFor(pct, single).id, 'b-0-100', reason: 'pct $pct');
      }
    });
  });

  group('replaceFeeBands contiguity guard (mirror of the RPC)', () {
    // Guards the fake's contract staying in lockstep with the
    // replace_fee_bands RPC: only sets tiling (0,100] are accepted, and a
    // rejection must leave the stored bands untouched.
    test('a contiguous set replaces the bands, even when sent unsorted',
        () async {
      final money = FakeMoneyRepository();
      await money.replaceFeeBands(
        'ws-1',
        [band(40, 100), band(0, 40)],
      );
      expect(money.feeBands, hasLength(2));
      expect(await money.fetchFeeBands('ws-1'), [
        money.feeBands.firstWhere((b) => b.fromPct == 0),
        money.feeBands.firstWhere((b) => b.fromPct == 40),
      ]);
    });

    test('a single full-width band is a valid set', () async {
      final money = FakeMoneyRepository();
      await money.replaceFeeBands('ws-1', [band(0, 100)]);
      expect(money.feeBands.single.fromPct, 0);
      expect(money.feeBands.single.toPct, 100);
    });

    Future<void> expectRejected(List<FeeBand> bands) async {
      final money = FakeMoneyRepository();
      final before = List.of(money.feeBands);
      await expectLater(
        money.replaceFeeBands('ws-1', bands),
        throwsStateError,
      );
      expect(money.feeBands, before, reason: 'a rejection must not mutate');
    }

    test('a gap between bands is rejected without mutating', () async {
      await expectRejected([band(0, 30), band(40, 100)]);
    });

    test('overlapping bands are rejected without mutating', () async {
      await expectRejected([band(0, 30), band(20, 100)]);
    });

    test('a set not starting at 0 is rejected', () async {
      await expectRejected([band(10, 100)]);
    });

    test('a set not reaching 100 is rejected', () async {
      await expectRejected([band(0, 90)]);
    });
  });

  group('entitlement vs availability display', () {
    // The included-half-days rule (ceil(open_days × 2 × pct / 100)) is
    // computed server-side; these pin that the bill renders the server's
    // edge values coherently instead of re-deriving (and rounding) them.
    testWidgets(
        'a fractional entitlement shows the server ceil: 23 open days at '
        '25% = 12, and full use of it is NOT overage', (tester) async {
      final money = FakeMoneyRepository()
        ..statement = statement(
          subscriptionPct: 25,
          feeCents: 0,
          includedHalfDays: 12, // ceil(23 × 2 × 25 / 100) = ceil(11.5)
          openDays: 23,
          usedHalfDays: 12,
        );
      await pumpMoney(tester, money: money);

      expect(find.text('Subscription 25%'), findsOneWidget);
      expect(
        find.text('12 of 12 half-days used (23 open days)'),
        findsOneWidget,
      );
      // The overage LINE ('N extra half-days') must be absent — the
      // Money tab's 'Request extra half-days' button always matches a
      // bare substring (0031).
      expect(find.textContaining(RegExp(r'^\d+ extra half-days')), findsNothing);
    });

    testWidgets(
        'the overage line appears exactly when used exceeds included '
        '(100% subscription across two periods)', (tester) async {
      final money = FakeMoneyRepository()
        ..statement = statement(
          subscriptionPct: 100,
          feeCents: 25000,
          includedHalfDays: 44,
          openDays: 22,
          usedHalfDays: 44,
        );
      final now = DateTime.now();
      final previousMonth = DateTime(now.year, now.month - 1);
      final previous = '${previousMonth.year}-'
          '${previousMonth.month.toString().padLeft(2, '0')}';
      money.statements[previous] = statement(
        subscriptionPct: 100,
        feeCents: 25000,
        includedHalfDays: 44,
        openDays: 22,
        usedHalfDays: 46,
        extraHalfDays: 2,
        overageCents: 1600,
      ).copyWith(period: previous);
      await pumpMoney(tester, money: money);

      // Fully used entitlement: no overage line yet.
      expect(
        find.text('44 of 44 half-days used (22 open days)'),
        findsOneWidget,
      );
      // The overage LINE ('N extra half-days') must be absent — the
      // Money tab's 'Request extra half-days' button always matches a
      // bare substring (0031).
      expect(find.textContaining(RegExp(r'^\d+ extra half-days')), findsNothing);

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      // Two half-days beyond it: the overage line with its charge.
      expect(
        find.text('46 of 44 half-days used (22 open days)'),
        findsOneWidget,
      );
      expect(find.text('2 extra half-days'), findsOneWidget);
      expect(find.text('−€16.00'), findsOneWidget);
    });

    testWidgets(
        'a fully closed month (0 open days) shows a zero entitlement and '
        'every use as overage', (tester) async {
      final money = FakeMoneyRepository()
        ..statement = statement(
          includedHalfDays: 0,
          openDays: 0,
          usedHalfDays: 3,
          extraHalfDays: 3,
          overageCents: 2400,
        );
      await pumpMoney(tester, money: money);

      expect(
        find.text('3 of 0 half-days used (0 open days)'),
        findsOneWidget,
      );
      expect(find.text('3 extra half-days'), findsOneWidget);
      expect(find.text('−€24.00'), findsOneWidget);
    });
  });

  group('consumption → bill flow through wired fakes', () {
    testWidgets(
        'record → open position on the bill → accept on Events → the '
        'confirmed charge lands in Consumed services', (tester) async {
      final events = FakeEventRepository();
      final money = FakeMoneyRepository(events: events);
      final overrides = standardTestOverrides(money: money, events: events);
      await pumpMoney(tester, money: money, overrides: overrides);

      expect(find.text('Open positions'), findsNothing);
      expect(find.text('Consumed services'), findsNothing);

      // Record Coffee ×2 via the consumption sheet.
      await tester.tap(find.text('Add consumption'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      await tester.tap(find.text('Submit for confirmation'));
      await tester.pumpAndSettle();

      // The real invalidation chain (the sheet invalidates eventsProvider)
      // must surface the pending charge as an open position — no re-pump.
      expect(find.text('Open positions'), findsOneWidget);
      expect(find.text('Coffee ×2'), findsOneWidget);
      expect(find.text('−€3.00'), findsOneWidget);
      expect(find.text('Consumed services'), findsNothing);

      // Solo owner: the #107 escape hatch lets the reporter validate.
      // #230: the events feed is pushed by the app-bar bell, no longer a
      // tab — validate there, then pop back to the shell.
      await tester.tap(find.byTooltip('Events'));
      await tester.pumpAndSettle();
      expect(find.text('Coffee ×2 — €3.00 for Flo'), findsOneWidget);
      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      expect(events.events.single.status, EventStatus.confirmed);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Confirmation posts the ledger charge (the SQL trigger's job —
      // mirrored here by seeding what it would write).
      money.ledger.add(
        ledgerEntry(
          id: 'l-coffee',
          kind: LedgerKind.charge,
          category: LedgerCategory.service,
          amountCents: 300,
          description: 'Coffee ×2',
          period: currentPeriod(),
        ),
      );

      // Back on Money the accept's invalidation chain has already removed
      // the open position — the charge is no longer pending. (Popping the
      // feed landed on the Money tab whose title duplicates the nav label,
      // so tap the nav destination itself.)
      await tester.tap(
        find.descendant(
          of: find.byType(ShellBottomBar),
          matching: find.text('Money'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Open positions'), findsNothing);

      // The next session reads the confirmed state fresh from the backend:
      // the charge sits in Consumed services, not in open positions.
      // (Unmount first — pumping the same widget types would silently reuse
      // the old ProviderScope container and its caches.)
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        ProviderScope(overrides: overrides, child: const DeskiloApp()),
      );
      await tester.pumpAndSettle();
      // The restored session may already sit on the Money tab (its title
      // then duplicates the nav label) — tap the nav destination itself.
      await tester.tap(
        find.descendant(
          of: find.byType(ShellBottomBar),
          matching: find.text('Money'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Consumed services'), findsOneWidget);
      expect(find.text('Coffee ×2'), findsOneWidget);
      expect(find.text('−€3.00'), findsNWidgets(2)); // row + section total
      expect(find.text('Open positions'), findsNothing);
    });
  });

  group('PDF export breadth', () {
    test(
        'a maximal bill — every section populated, all three open-position '
        'money types — renders across all five locales', () async {
      await initializeDateFormatting();
      const period = '2026-07';
      const maximal = Statement(
        period: period,
        subscriptionPct: 50,
        feeCents: 15000,
        includedHalfDays: 22,
        openDays: 22,
        usedHalfDays: 24,
        extraHalfDays: 2,
        overageCents: 1600,
        creditsCents: 16700,
        balanceCents: -3300,
        // #170 — the maximal bill also carries an accessory supplement,
        // so every subscription-card line renders in every locale.
        accessorySupplementCents: 900,
      );
      final sections = buildBillSections(
        period: period,
        memberId: 'member-1',
        nowPeriod: period,
        ledger: [
          for (final (i, cents) in const [450, 200, 2500].indexed)
            ledgerEntry(
              id: 'l-service-$i',
              kind: LedgerKind.charge,
              category: LedgerCategory.service,
              amountCents: cents,
              description: i == 0 ? 'Coffee ×3' : '',
              period: period,
            ),
          ledgerEntry(
            id: 'l-payment',
            kind: LedgerKind.credit,
            category: LedgerCategory.payment,
            amountCents: 15000,
            description: 'Bank transfer',
            period: period,
          ),
          // Empty descriptions exercise the per-category fallback labels.
          ledgerEntry(
            id: 'l-expense',
            kind: LedgerKind.credit,
            category: LedgerCategory.expense,
            amountCents: 1200,
            period: period,
          ),
          ledgerEntry(
            id: 'l-adjustment',
            kind: LedgerKind.credit,
            category: LedgerCategory.adjustment,
            amountCents: 500,
            period: period,
          ),
        ],
        pendingEvents: [
          pendingEvent(
            id: 'evt-sc',
            type: EventType.serviceCharge,
            payload: const {
              'name': 'Printing',
              'quantity': 4,
              'amount_cents': 80,
              'period': period,
            },
          ),
          pendingEvent(
            id: 'evt-pay',
            type: EventType.payment,
            payload: const {'amount_cents': 5000},
          ),
          pendingEvent(
            id: 'evt-exp',
            type: EventType.expense,
            payload: const {'amount_cents': 1200},
          ),
        ],
      );
      // Precondition: this really is the maximal bill.
      expect(sections.serviceEntries, hasLength(3));
      expect(sections.openPositions, hasLength(3));
      expect(
        [for (final p in sections.openPositions) p.isCredit],
        [false, true, true],
      );
      expect(sections.creditEntries, hasLength(3));

      final base = ttf('assets/fonts/Roboto-Regular.ttf');
      final bold = ttf('assets/fonts/Roboto-Bold.ttf');
      for (final locale in ['en', 'de', 'fr', 'es', 'it']) {
        final bytes = await buildBillPdf(
          statement: maximal,
          sections: sections,
          currencyCode: 'EUR',
          workspaceName: 'Test Space',
          memberName: 'Flo',
          periodLabel: 'July 2026',
          strings: pdfStrings,
          baseFont: base,
          boldFont: bold,
          locale: locale,
        );
        expect(bytes, isNotEmpty, reason: 'empty PDF for $locale');
        expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-',
            reason: 'bad header for $locale');
      }
    });
  });

  group('cross-surface consistency', () {
    // Screen and PDF must show the same numbers because both consume
    // buildBillSections — these two tests break if either surface starts
    // computing its own totals from the raw ledger.
    testWidgets('the on-screen services total is the domain total',
        (tester) async {
      final money = FakeMoneyRepository()
        ..ledger.addAll(crossSurfaceLedger(currentPeriod()));
      await pumpMoney(tester, money: money);

      final sections = buildBillSections(
        period: currentPeriod(),
        memberId: 'member-1',
        nowPeriod: currentPeriod(),
        ledger: money.ledger,
        pendingEvents: const [],
      );
      expect(sections.servicesTotalCents, 380);
      expect(find.text('−€3.80'), findsOneWidget); // the section total
      expect(find.text('−€3.00'), findsOneWidget);
      expect(find.text('−€0.80'), findsOneWidget);
      expect(find.text('+€150.00'), findsOneWidget);
    });

    test('the same seed feeds the PDF the same sections', () async {
      const period = '2026-07';
      final sections = buildBillSections(
        period: period,
        memberId: 'member-1',
        nowPeriod: period,
        ledger: crossSurfaceLedger(period),
        pendingEvents: const [],
      );
      expect(sections.servicesTotalCents, 380);
      expect(sections.creditEntries, hasLength(1));

      final bytes = await buildBillPdf(
        statement: statement(
          includedHalfDays: 22,
          openDays: 22,
          usedHalfDays: 20,
        ),
        sections: sections,
        currencyCode: 'EUR',
        workspaceName: 'Test Space',
        memberName: 'Flo',
        periodLabel: 'July 2026',
        strings: pdfStrings,
        baseFont: ttf('assets/fonts/Roboto-Regular.ttf'),
        boldFont: ttf('assets/fonts/Roboto-Bold.ttf'),
        locale: 'en',
      );
      expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    });
  });
}
