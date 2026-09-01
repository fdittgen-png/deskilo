// SPDX-License-Identifier: 0BSD
//
// #812 — the journey of an invoice: Issued → Payment → Confirmation →
// Closed, ONE derivation behind the issuers' hub, the member's Invoices
// face and the detail sheet. Each step is done, current or still to
// come, and the journey names whose move it is — the member pays, an
// admin confirms the declared payment, the issuer matches the registered
// one, the validators decide, the workspace refunds, nobody (closed).
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/domain/dunning.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/money_face.dart';
import 'package:deskilo/features/money/presentation/invoice_journey.dart';
import 'package:deskilo/features/money/presentation/invoice_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_event_repository.dart';
import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/test_clock.dart';

Invoice _invoice({
  String id = 'inv-1',
  int totalCents = 25000,
  DateTime? issuedAt,
  bool voided = false,
  String? settledBy,
}) =>
    Invoice(
      id: id,
      workspaceId: 'ws-1',
      memberId: 'member-1',
      number: 'INV-$id',
      issuedAt: issuedAt ?? kTestNow,
      period: kTestPeriod,
      title: kTestPeriod,
      lines: const [],
      totalCents: totalCents,
      currency: 'EUR',
      memberName: 'Flo',
      memberAddress: '',
      workspaceName: 'Space',
      workspaceAddress: '',
      issuerName: 'Owner',
      signature: 'sig',
      voidedAt: voided ? kTestNow : null,
      settledByInvoiceId: settledBy,
    );

InvoiceMatch _match({
  int paidCents = 25000,
  String resolution = 'exact',
  String status = 'confirmed',
  DateTime? writeoffAt,
  DateTime? matchedAt,
}) =>
    InvoiceMatch(
      invoiceId: 'inv-1',
      paidCents: paidCents,
      resolution: resolution,
      status: status,
      matchedAt: matchedAt ?? kTestNow,
      writeoffAt: writeoffAt,
    );

WorkspaceEvent _payment({
  required String id,
  required EventStatus status,
  int amountCents = 25000,
  String actor = 'member-1',
  DateTime? createdAt,
}) =>
    WorkspaceEvent(
      id: id,
      workspaceId: 'ws-1',
      type: EventType.payment,
      action: EventAction.created,
      actorMemberId: actor,
      subjectMemberId: 'member-1',
      payload: {'amount_cents': amountCents, 'period': kTestPeriod},
      status: status,
      createdAt: createdAt ?? kTestNow.add(const Duration(hours: 1)),
    );

const _rules = DunningRules(levels: 3, firstAfterDays: 14, betweenDays: 14);

InvoiceJourney _journey(
  Invoice invoice, {
  InvoiceMatch? match,
  ({int count, DateTime last})? reminder,
  List<WorkspaceEvent> events = const [],
  DateTime? now,
  String replacedBy = '',
}) =>
    InvoiceJourney.of(
      invoice: invoice,
      match: match,
      reminder: reminder,
      rules: _rules,
      now: now ?? kTestNow,
      facts: journeyFactsOf(invoice, match, events),
      replacedByNumber: replacedBy,
    );

void main() {
  group('the derivation', () {
    test('a fresh open invoice: the member pays, by issue + term', () {
      final j = _journey(_invoice());
      expect(j.move, InvoiceMove.memberPays);
      expect(j.move.who, InvoiceMover.member);
      expect(j.steps[InvoiceStep.issued], InvoiceStepState.done);
      expect(j.steps[InvoiceStep.payment], InvoiceStepState.current);
      expect(j.steps[InvoiceStep.confirmation], InvoiceStepState.todo);
      expect(j.steps[InvoiceStep.closed], InvoiceStepState.todo);
      expect(j.remainingCents, 25000);
      expect(j.dueOn, kTestNow.add(const Duration(days: 14)));
      expect(j.daysToTerm, 14);
      expect(j.overdue, isFalse);
      expect(j.reminderDue, isNull);
    });

    test('past the term it is overdue and reminder 1 is due', () {
      final j = _journey(
        _invoice(issuedAt: kTestNow.subtract(const Duration(days: 20))),
      );
      expect(j.move, InvoiceMove.memberPays);
      expect(j.overdue, isTrue);
      expect(j.daysToTerm, -6);
      expect(j.reminderDue, 1);
    });

    test('a payment the member DECLARED waits for another admin', () {
      final j = _journey(
        _invoice(),
        events: [_payment(id: 'e1', status: EventStatus.pending)],
      );
      expect(j.move, InvoiceMove.adminConfirmsPayment);
      expect(j.move.who, InvoiceMover.issuer);
      expect(j.facts.declaredCents, 25000);
      expect(j.steps[InvoiceStep.payment], InvoiceStepState.done);
      expect(j.steps[InvoiceStep.confirmation], InvoiceStepState.current);
      // Not overdue while the money is on its way, however old.
      expect(j.overdue, isFalse);
    });

    test('a payment an ADMIN recorded for the member waits for the member',
        () {
      final j = _journey(
        _invoice(),
        events: [
          _payment(id: 'e1', status: EventStatus.pending, actor: 'admin-2'),
        ],
      );
      expect(j.move, InvoiceMove.memberConfirmsPayment);
      expect(j.move.who, InvoiceMover.member);
      expect(j.facts.recordedForMemberCents, 25000);
    });

    test('a CONFIRMED payment booked after issue waits for its match', () {
      final j = _journey(
        _invoice(),
        events: [_payment(id: 'e1', status: EventStatus.confirmed)],
      );
      expect(j.move, InvoiceMove.issuerMatchesPayment);
      expect(j.facts.registeredCents, 25000);
    });

    test('a payment booked BEFORE issue was netted into the document', () {
      final j = _journey(
        _invoice(),
        events: [
          _payment(
            id: 'e1',
            status: EventStatus.applied,
            createdAt: kTestNow.subtract(const Duration(days: 3)),
          ),
        ],
      );
      expect(j.move, InvoiceMove.memberPays);
      expect(j.facts.registeredCents, 0);
    });

    test('registered beats declared beats waiting', () {
      final j = _journey(
        _invoice(),
        events: [
          _payment(id: 'e1', status: EventStatus.pending, amountCents: 100),
          _payment(id: 'e2', status: EventStatus.confirmed, amountCents: 200),
        ],
      );
      expect(j.move, InvoiceMove.issuerMatchesPayment);
    });

    test('a pending match waits for the validators', () {
      final j = _journey(_invoice(), match: _match(status: 'pending'));
      expect(j.move, InvoiceMove.validatorsDecideMatch);
      expect(j.move.who, InvoiceMover.validators);
      expect(j.steps[InvoiceStep.confirmation], InvoiceStepState.current);
      expect(j.remainingCents, 25000);
    });

    test('a partial payment: the member pays the rest, at the remainder',
        () {
      final j = _journey(
        _invoice(),
        match: _match(paidCents: 10000, resolution: 'under_accepted'),
      );
      expect(j.lifecycle, InvoiceLifecycle.partiallyPaid);
      expect(j.move, InvoiceMove.memberPaysRemainder);
      expect(j.remainingCents, 15000);
      expect(j.steps[InvoiceStep.payment], InvoiceStepState.current);
    });

    test('a partial with a pending write-off waits for the validators', () {
      final j = _journey(
        _invoice(),
        match: _match(paidCents: 10000, resolution: 'under_accepted'),
        events: [
          WorkspaceEvent(
            id: 'w1',
            workspaceId: 'ws-1',
            type: EventType.invoiceWriteoff,
            action: EventAction.submitted,
            actorMemberId: 'member-1',
            subjectMemberId: 'member-1',
            payload: const {'invoice_id': 'inv-1'},
            status: EventStatus.pending,
            createdAt: kTestNow,
          ),
        ],
      );
      expect(j.move, InvoiceMove.validatorsDecideWriteoff);
      expect(j.facts.writeoffPending, isTrue);
    });

    test('a partial only counts payments booked AFTER its match', () {
      final matchedAt = kTestNow.add(const Duration(days: 2));
      final j = _journey(
        _invoice(),
        match: _match(
          paidCents: 10000,
          resolution: 'under_accepted',
          matchedAt: matchedAt,
        ),
        events: [
          // The one the partial match consumed.
          _payment(
            id: 'old',
            status: EventStatus.confirmed,
            amountCents: 10000,
            createdAt: kTestNow.add(const Duration(days: 1)),
          ),
        ],
        now: kTestNow.add(const Duration(days: 3)),
      );
      expect(j.move, InvoiceMove.memberPaysRemainder);
    });

    test('a credit note is the WORKSPACE\'s move: refund and record', () {
      final j = _journey(_invoice(totalCents: -5000));
      expect(j.move, InvoiceMove.issuerRefunds);
      expect(j.move.who, InvoiceMover.issuer);
      expect(j.reminderDue, isNull);
      expect(j.overdue, isFalse);
    });

    test('paid: every step done, nobody moves', () {
      final j = _journey(_invoice(), match: _match());
      expect(j.move, InvoiceMove.none);
      expect(j.closed, isTrue);
      for (final step in InvoiceStep.values) {
        expect(j.steps[step], InvoiceStepState.done);
      }
      expect(j.remainingCents, 0);
    });

    test('remainder cancelled and refunded read closed', () {
      expect(
        _journey(
          _invoice(),
          match: _match(
            paidCents: 10000,
            resolution: 'under_accepted',
            writeoffAt: kTestNow,
          ),
        ).move,
        InvoiceMove.none,
      );
      expect(
        _journey(
          _invoice(totalCents: -5000),
          match: _match(paidCents: 5000, resolution: 'refunded'),
        ).move,
        InvoiceMove.none,
      );
    });

    test('erroneous: the issuer replaces it, until it is replaced', () {
      final j = _journey(_invoice(voided: true));
      expect(j.move, InvoiceMove.issuerReplaces);
      expect(j.steps[InvoiceStep.closed], InvoiceStepState.cancelled);
      expect(j.steps[InvoiceStep.payment], InvoiceStepState.todo);
      expect(
        _journey(_invoice(voided: true), replacedBy: 'INV-2').move,
        InvoiceMove.none,
      );
    });

    test('regrouped into a settlement (#804): closed here, no reminder', () {
      final j = _journey(
        _invoice(
          settledBy: 'inv-9',
          issuedAt: kTestNow.subtract(const Duration(days: 40)),
        ),
      );
      expect(j.settled, isTrue);
      expect(j.move, InvoiceMove.none);
      expect(j.remainingCents, 0);
      expect(j.reminderDue, isNull);
    });

    test('the stage counts split the open list by whose move it is', () {
      final counts = stageCountsOf(
        toIssue: 6,
        closed: 12,
        open: [
          _journey(_invoice(id: 'a')),
          _journey(
            _invoice(
              id: 'b',
              issuedAt: kTestNow.subtract(const Duration(days: 30)),
            ),
          ),
          _journey(
            _invoice(id: 'c'),
            events: [_payment(id: 'e', status: EventStatus.pending)],
          ),
          _journey(_invoice(id: 'd'), match: _match(status: 'pending')),
          _journey(_invoice(id: 'e', totalCents: -1000)),
          _journey(_invoice(id: 'f', voided: true)),
        ],
      );
      expect(counts.toIssue, 6);
      expect(counts.toCollect, 2);
      expect(counts.toCollectCents, 50000);
      expect(counts.overdue, 1);
      expect(counts.toConfirm, 3);
      expect(counts.closed, 12);
    });
  });

  group('on screen', () {
    Future<
        ({
          FakeMoneyRepository money,
          FakeEventRepository events,
        })> pump(
      WidgetTester tester, {
      required FakeMoneyRepository money,
      FakeEventRepository? events,
      Map<String, dynamic> flags = const {},
      bool hub = true,
    }) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      events ??= FakeEventRepository();
      final workspace =
          FakeWorkspaceRepository.withWorkspace(featureFlags: flags);
      await tester.pumpWidget(
        ProviderScope(
          overrides: standardTestOverrides(
            money: money,
            workspace: workspace,
            events: events,
          ),
          child: const DeskiloApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Money'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('money-face-invoices')));
      await tester.pumpAndSettle();
      if (hub) {
        await tester
            .ensureVisible(find.byKey(const ValueKey('invoices-button')));
        await tester.tap(find.byKey(const ValueKey('invoices-button')));
        await tester.pumpAndSettle();
      }
      return (money: money, events: events);
    }

    /// An OPEN invoice for me, issued [ageDays] ago.
    Future<String> openInvoice(
      FakeMoneyRepository money, {
      int ageDays = 0,
    }) async {
      final id = await money.createInvoice(
        workspaceId: 'ws-1',
        memberId: 'member-1',
        period: kTestPeriod,
      );
      final i = money.invoices.indexWhere((x) => x.id == id);
      money.invoices[i] = money.invoices[i].copyWith(
        issuedAt: kTestNow.subtract(Duration(days: ageDays)),
      );
      return id;
    }

    testWidgets(
        'the hub: a stage strip over the tabs, the journey bar and the '
        'move on every open card, and no labelled button while the '
        'issuer has nothing to do', (tester) async {
      final money = FakeMoneyRepository();
      final id = await openInvoice(money);
      await pump(tester, money: money);

      // The four stages, with their counts.
      for (final stage in ['issue', 'collect', 'confirm', 'closed']) {
        expect(find.byKey(ValueKey('invoice-stage-$stage')), findsOneWidget);
      }
      expect(find.textContaining('outstanding'), findsOneWidget);

      // Tapping To collect lands on the Open tab.
      await tester.tap(find.byKey(const ValueKey('invoice-stage-collect')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('invoice-open-$id')), findsOneWidget);
      expect(find.byKey(const ValueKey('invoice-journey-bar')), findsOneWidget);
      expect(find.byKey(const ValueKey('invoice-move-line')), findsOneWidget);
      expect(find.textContaining("Waiting for"), findsOneWidget);
      expect(find.textContaining('due'), findsWidgets);
      // Nothing is expected from the issuer yet: icons only.
      expect(find.text('Send a reminder'), findsNothing);
      expect(find.text('Mark as paid'), findsNothing);
      expect(find.byKey(ValueKey('invoice-match-$id')), findsOneWidget);
      expect(find.byKey(ValueKey('invoice-remind-$id')), findsOneWidget);
    });

    testWidgets(
        'past the term the expected move is the reminder: ONE labelled '
        'button with the reminder\'s level, same key, and it records',
        (tester) async {
      final money = FakeMoneyRepository();
      final id = await openInvoice(money, ageDays: 20);
      await pump(tester, money: money);
      await tester.tap(find.byKey(const ValueKey('invoice-tab-open')));
      await tester.pumpAndSettle();

      expect(find.textContaining('overdue by 6 days'), findsOneWidget);
      expect(find.text('Send reminder 1'), findsOneWidget);
      // The strip counts it as overdue.
      expect(find.text('1 overdue'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(ValueKey('invoice-remind-$id')));
        await tester.pumpAndSettle();
      });
      await tester.pumpAndSettle();
      expect(money.invoiceReminders[id]?.length, 1);
    });

    testWidgets(
        'a payment the member declared: the card says another admin '
        'confirms it and offers Events; the strip counts it To confirm',
        (tester) async {
      final money = FakeMoneyRepository();
      final id = await openInvoice(money);
      final events = FakeEventRepository()
        ..events.add(_payment(id: 'e1', status: EventStatus.pending));
      await pump(tester, money: money, events: events);
      expect(find.byKey(const ValueKey('invoice-stage-confirm')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('invoice-tab-open')));
      await tester.pumpAndSettle();
      expect(find.textContaining('another admin confirms'), findsOneWidget);
      expect(find.byKey(ValueKey('invoice-events-$id')), findsOneWidget);
      expect(find.text('Open Events'), findsOneWidget);
    });

    testWidgets(
        'a registered payment: Mark as paid becomes the labelled move',
        (tester) async {
      final money = FakeMoneyRepository();
      final id = await openInvoice(money);
      final events = FakeEventRepository()
        ..events.add(_payment(id: 'e1', status: EventStatus.confirmed));
      await pump(tester, money: money, events: events);
      await tester.tap(find.byKey(const ValueKey('invoice-tab-open')));
      await tester.pumpAndSettle();
      expect(find.textContaining('match it to this invoice'), findsOneWidget);
      expect(find.text('Mark as paid'), findsOneWidget);
      expect(find.byKey(ValueKey('invoice-match-$id')), findsOneWidget);
    });

    testWidgets('How invoicing works: four steps, both sides, from the hub',
        (tester) async {
      final money = FakeMoneyRepository();
      await pump(tester, money: money);
      await tester.tap(find.byKey(const ValueKey('invoice-process-help')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('invoice-process-sheet')), findsOneWidget);
      for (final step in InvoiceStep.values) {
        expect(
          find.byKey(ValueKey('invoice-process-step-${step.name}')),
          findsOneWidget,
        );
      }
      expect(find.text('Workspace'), findsNWidgets(4));
      expect(find.text('Member'), findsNWidgets(4));
    });

    testWidgets(
        'the detail sheet opens on the journey: the bar, the move, and the '
        'expected action first', (tester) async {
      final money = FakeMoneyRepository();
      final id = await openInvoice(money, ageDays: 20);
      await pump(tester, money: money);
      await tester.tap(find.byKey(const ValueKey('invoice-tab-open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('invoice-open-$id')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('invoice-detail-number')), findsOneWidget);
      expect(find.byKey(const ValueKey('invoice-journey-bar')), findsWidgets);
      expect(find.byKey(const ValueKey('invoice-move-line')), findsWidgets);
      // The reminder is due, so it leads the actions: above the PDF.
      final remind = tester.getTopLeft(
        find.byKey(const ValueKey('invoice-remind-action')),
      );
      final download = tester.getTopLeft(
        find.byKey(ValueKey('invoice-download-$id')),
      );
      expect(remind.dy, lessThan(download.dy));
    });

    testWidgets(
        'the member\'s Invoices face: the bar and "your move" on the row, '
        'and How it works from the summary card', (tester) async {
      final money = FakeMoneyRepository();
      final id = await openInvoice(money);
      await pump(tester, money: money, hub: false);

      expect(find.byKey(ValueKey('my-invoice-$id')), findsOneWidget);
      expect(find.byKey(const ValueKey('invoice-journey-bar')), findsOneWidget);
      expect(find.textContaining('Your move: pay'), findsOneWidget);
      expect(find.byKey(const ValueKey('invoice-journey-step-payment')),
          findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('money-invoice-process')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('invoice-process-sheet')), findsOneWidget);
    });

    testWidgets('the member reads the workspace\'s side after declaring',
        (tester) async {
      final money = FakeMoneyRepository();
      await openInvoice(money);
      final events = FakeEventRepository()
        ..events.add(_payment(id: 'e1', status: EventStatus.pending));
      await pump(tester, money: money, events: events, hub: false);
      expect(find.textContaining('the workspace is confirming it'),
          findsOneWidget);
      expect(find.textContaining('Your move'), findsNothing);
    });

    testWidgets('flag OFF: the plain chips, no bar, no strip, no explainer',
        (tester) async {
      final money = FakeMoneyRepository();
      final id = await openInvoice(money);
      await pump(
        tester,
        money: money,
        flags: const {'invoiceJourney': false},
        hub: false,
      );
      expect(find.byKey(ValueKey('my-invoice-$id')), findsOneWidget);
      expect(find.byKey(const ValueKey('invoice-journey-bar')), findsNothing);
      expect(find.byKey(const ValueKey('money-invoice-process')), findsNothing);
      expect(find.textContaining('Due in'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey('invoices-button')));
      await tester.tap(find.byKey(const ValueKey('invoices-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('invoice-process-help')), findsNothing);
      expect(find.byKey(const ValueKey('invoice-stage-collect')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('invoice-tab-open')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('invoice-move-line')), findsNothing);
      expect(find.byKey(ValueKey('invoice-match-$id')), findsOneWidget);
    });
  });

  test('MoneyFace stays a four-face enum the deep link resolves', () {
    expect(MoneyFace.fromWire('invoices'), MoneyFace.invoices);
  });
}
