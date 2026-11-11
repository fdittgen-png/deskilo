// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #812 — the journey of an invoice: Issued → Payment → Confirmation →
// Closed, ONE derivation behind the issuers' hub, the member's Invoices
// face and the detail sheet. Each step is done, current or still to
// come, and the journey names whose move it is — the member pays, an
// admin confirms the declared payment, the issuer matches the registered
// one, the validators decide, the workspace refunds, nobody (closed).
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/ui/kit/kit_action_button.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/domain/dunning.dart';
import 'package:deskilo/features/money/domain/money_face.dart';
import 'package:deskilo/features/money/presentation/invoice_journey.dart';
import 'package:deskilo/features/money/presentation/invoice_status.dart';
import 'package:deskilo/features/money/presentation/widgets/invoice_journey_view.dart';
import 'package:deskilo/features/money/providers/money_face_controller.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_event_repository.dart';
import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/navigation.dart';
import '../../helpers/screens/invoices.dart' show invoicingRow;

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

const _rules = DunningRules();

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
      double width = 800,
    }) async {
      tester.view.physicalSize = Size(width, 1600);
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
      await tester.tap(find.text('My finances'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('money-face-invoices')));
      await tester.pumpAndSettle();
      if (hub) {
        await openMoneyWorkspaceTools(tester);
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

    /// #3587 — the home's line of [id] (one line per invoice), tapped:
    /// the invoice page (R1-d), where the story and the actions live now.
    Future<void> openFromHome(WidgetTester tester, String id) async {
      await tester.tap(await invoicingRow(tester, id));
      await tester.pumpAndSettle();
    }

    /// The owed card's legend line of [bucket], whatever the currency.
    Finder owedBucket(String bucket) => find.byWidgetPredicate((w) {
          final key = w.key;
          return key is ValueKey<String> &&
              key.value.startsWith('invoicing-owed-') &&
              key.value.endsWith('-$bucket');
        });

    testWidgets(
        'the home: an open invoice is owed, not yet due; its page tells '
        'the story and what is awaited, and has no main action while the '
        'issuer has nothing to do', (tester) async {
      final money = FakeMoneyRepository();
      final id = await openInvoice(money);
      await pump(tester, money: money);

      // #3587 — the owed card in place of the stage strip.
      expect(owedBucket('notYetDue'), findsOneWidget);
      expect(owedBucket('overdue'), findsNothing);
      expect(owedBucket('toConfirm'), findsNothing);

      await openFromHome(tester, id);
      // #3587 R1-d — the page's story, its last line what is awaited now.
      expect(find.byKey(const ValueKey('invoice-page-story')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('invoice-page-story')),
          matching: find.textContaining(RegExp('^(Waiting for payment|Due )')),
        ),
        findsOneWidget,
      );
      // Nothing is expected from the issuer yet: no main action under the
      // thumb, neither a reminder nor a match.
      expect(find.byKey(const ValueKey('invoice-page-remind')), findsNothing);
      expect(find.byKey(const ValueKey('invoice-page-match')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(ValueKey('invoice-page-$id')),
          matching: find.byType(FilledButton),
        ),
        findsNothing,
      );
    });

    testWidgets(
        'past the term the invoice is overdue: the customer line offers '
        'Remind, and it records the reminder', (tester) async {
      final money = FakeMoneyRepository();
      final id = await openInvoice(money, ageDays: 20);
      await pump(tester, money: money);

      // #3587 — the owed card counts it overdue (the strip's "1 overdue").
      expect(owedBucket('overdue'), findsOneWidget);
      final action = find.byKey(
        ValueKey('invoicing-customer-action-${money.invoices.single.memberId}'),
      );
      await tester.ensureVisible(action);
      expect(
        find.descendant(of: action, matching: find.text('Remind')),
        findsOneWidget,
      );

      await tester.runAsync(() async {
        await tester.tap(action);
        await tester.pumpAndSettle();
      });
      await tester.pumpAndSettle();
      expect(money.invoiceReminders[id]?.length, 1);
    });

    testWidgets(
        'a payment the member declared: the home counts it To confirm and '
        'its page offers Confirm and Not received', (tester) async {
      final money = FakeMoneyRepository();
      final id = await openInvoice(money);
      final events = FakeEventRepository()
        ..events.add(_payment(id: 'e1', status: EventStatus.pending));
      await pump(tester, money: money, events: events);
      // #3587 — the owed card's To confirm in place of the strip's.
      expect(owedBucket('toConfirm'), findsOneWidget);

      await openFromHome(tester, id);
      // #3587 R1-d — the story names the declaration; the bottom bar
      // decides it.
      expect(find.textContaining('says it is paid'), findsOneWidget);
      expect(find.text('Check your bank, then confirm'), findsOneWidget);
      expect(find.byKey(const ValueKey('invoice-page-confirm')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('invoice-page-not-received')),
          findsOneWidget);
    });

    testWidgets(
        'a registered payment: Match the payment becomes the main action',
        (tester) async {
      final money = FakeMoneyRepository();
      final id = await openInvoice(money);
      final events = FakeEventRepository()
        ..events.add(_payment(id: 'e1', status: EventStatus.confirmed));
      await pump(tester, money: money, events: events);
      await openFromHome(tester, id);
      expect(find.text('A payment is on the account: match it'),
          findsOneWidget);
      expect(
        tester.widget(find.byKey(const ValueKey('invoice-page-match'))),
        isA<KitActionButton>(),
        reason: 'the expected move is the bottom bar\'s filled button',
      );
    });

    testWidgets('How invoicing works: four steps, both sides, from the hub',
        (tester) async {
      final money = FakeMoneyRepository();
      await pump(tester, money: money);
      await tapInvoicingTool(tester, 'invoice-process-help');
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
        'the invoice page opens on its number, the story with what is due '
        'now, and the expected action in the bottom bar', (tester) async {
      final money = FakeMoneyRepository();
      final id = await openInvoice(money, ageDays: 20);
      await pump(tester, money: money);
      await openFromHome(tester, id);

      expect(find.text('Invoice ${money.invoices.single.number}'),
          findsOneWidget);
      expect(find.byKey(const ValueKey('invoice-page-story')), findsOneWidget);
      expect(find.text('Reminder 1 is due'), findsOneWidget);
      // The reminder is due, so it is the page's one main action; the PDF
      // stays in More.
      expect(
        tester.widget(find.byKey(const ValueKey('invoice-page-remind'))),
        isA<KitActionButton>(),
      );
      expect(find.byKey(const ValueKey('invoice-page-more')), findsOneWidget);
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

    testWidgets('#3285 — the member\'s detail leads with Pay, which opens '
        'Payments', (tester) async {
      final money = FakeMoneyRepository();
      final id = await openInvoice(money);
      await pump(tester, money: money, hub: false);
      await tester.tap(find.byKey(ValueKey('my-invoice-$id')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final pay = find.byKey(const ValueKey('invoice-detail-pay'));
      expect(pay, findsOneWidget);
      await tester.ensureVisible(pay);
      await tester.tap(pay);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(pay, findsNothing);
      final container =
          ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
      expect(container.read(moneyFaceControllerProvider), MoneyFace.payments);
    });

    // #3285 — at phone width the four steps fit: no sideways scroll, every
    // label wholly on screen (wrapping, never cut).
    for (final width in const [320.0, 390.0]) {
      testWidgets('the bar fits a ${width.toInt()} px phone', (tester) async {
        final money = FakeMoneyRepository();
        await openInvoice(money);
        await pump(tester, money: money, hub: false, width: width);
        // A phone shows one face at a time: open Invoices.
        ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
            .read(moneyFaceControllerProvider.notifier)
            .show(MoneyFace.invoices);
        await tester.pump();
        final bar = find.byKey(const ValueKey('invoice-journey-bar'));
        expect(bar, findsOneWidget);
        expect(
            find.ancestor(of: bar, matching: find.byType(SingleChildScrollView))
                .evaluate()
                .where((e) =>
                    (e.widget as SingleChildScrollView).scrollDirection ==
                    Axis.horizontal),
            isEmpty);
        for (final step in InvoiceStep.values) {
          final label = find.byKey(ValueKey('invoice-journey-step-${step.name}'));
          final rect = tester.getRect(label);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(width));
        }
        expect(tester.takeException(), isNull);
      });
    }

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

    testWidgets('flag OFF: the plain chips, no bar, no move, no explainer',
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

      await openMoneyWorkspaceTools(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('invoices-button')));
      await tester.tap(find.byKey(const ValueKey('invoices-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('invoicing-tools')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('invoice-process-help')), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await openFromHome(tester, id);
      // #3587 R1-d — the invoice still opens on its page, with its actions
      // in More; no journey bar, no move line.
      expect(find.byKey(ValueKey('invoice-page-$id')), findsOneWidget);
      expect(find.byKey(const ValueKey('invoice-move-line')), findsNothing);
      expect(find.byKey(const ValueKey('invoice-journey-bar')), findsNothing);
      expect(find.byKey(const ValueKey('invoice-page-more')), findsOneWidget);
    });
  });

  testWidgets('journey semantics use localized step states', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 250,
            child: InvoiceJourneyBar(journey: _journey(_invoice())),
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel(RegExp('Étape actuelle')), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Upcoming|todo|current')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  test('MoneyFace stays a four-face enum the deep link resolves', () {
    expect(MoneyFace.fromWire('invoices'), MoneyFace.invoices);
  });
}
