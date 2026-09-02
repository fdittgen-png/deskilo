// SPDX-License-Identifier: 0BSD
//
// #827 — the invoicing wizard: the run the date calls for, the period
// and kind of a run, the plans derived from what the workspace holds,
// and the guided screen — issue in one batch, remind in one tap, decide
// a declared payment, register a bank payment, the summary's tally and
// the to-do of whose move is left.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/dunning.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoicing_wizard.dart';
import 'package:deskilo/features/money/presentation/screens/invoicing_wizard_screen.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_event_repository.dart';
import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import 'invoices_test.dart' show pumpInvoices, seededMoney;

Invoice _invoice(
  String id, {
  String member = 'member-1',
  String period = '2026-08',
  int total = 10000,
  InvoiceKind kind = InvoiceKind.full,
  DateTime? issuedAt,
  DateTime? voidedAt,
  String? settledBy,
}) =>
    Invoice(
      id: id,
      workspaceId: 'ws-1',
      memberId: member,
      number: id.toUpperCase(),
      issuedAt: issuedAt ?? DateTime.utc(2026, 8, 1),
      period: period,
      title: period,
      lines: const [],
      totalCents: total,
      currency: 'EUR',
      memberName: member,
      memberAddress: '',
      workspaceName: 'ws',
      workspaceAddress: '',
      issuerName: 'Flo',
      signature: '',
      voidedAt: voidedAt,
      kind: kind,
      settledByInvoiceId: settledBy,
    );

InvoiceMatch _match(String invoiceId,
        {String resolution = 'exact', String status = 'confirmed'}) =>
    InvoiceMatch(
      invoiceId: invoiceId,
      paidCents: 10000,
      resolution: resolution,
      status: status,
      matchedAt: DateTime.utc(2026, 8, 2),
    );

WorkspaceEvent _payment(String id, {String actor = 'member-2'}) =>
    WorkspaceEvent(
      id: id,
      workspaceId: 'ws-1',
      type: EventType.payment,
      action: EventAction.created,
      actorMemberId: actor,
      subjectMemberId: actor,
      payload: const {'amount_cents': 4200, 'method': 'bank_transfer'},
      status: EventStatus.pending,
      createdAt: DateTime.utc(2026, 9, 1),
    );

Future<
    ({
      FakeMoneyRepository money,
      FakeEventRepository events,
    })> _pumpWizard(
  WidgetTester tester, {
  WizardRun run = WizardRun.startOfMonth,
  FakeMoneyRepository? money,
  List<WorkspaceEvent> events = const [],
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final m = money ?? await seededMoney(matched: false);
  final e = FakeEventRepository()..events.addAll(events);
  final workspace = FakeWorkspaceRepository.withWorkspace()
    ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'}
    ..otherMembers.add(const Member(
      id: 'member-2',
      workspaceId: 'ws-1',
      userId: 'user-2',
      isAdmin: false,
      isOwner: false,
      status: MemberStatus.active,
    ));
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        workspace: workspace,
        money: m,
        events: e,
      ),
      child: MaterialApp(home: InvoicingWizardScreen(initialRun: run)),
    ),
  );
  await tester.pumpAndSettle();
  return (money: m, events: e);
}

Future<void> _goTo(WidgetTester tester, WizardStep step) async {
  await tester.ensureVisible(find.byKey(ValueKey('wizard-step-${step.name}')));
  await tester.tap(find.byKey(ValueKey('wizard-step-${step.name}')));
  await tester.pumpAndSettle();
}

void main() {
  group('runs and periods (#827)', () {
    test('the period and the kind follow the run', () {
      final now = DateTime(2026, 9, 2);
      expect(wizardPeriod(WizardRun.startOfMonth, now), '2026-10');
      expect(wizardPeriod(WizardRun.endOfMonth, now), '2026-08');
      expect(wizardKind(WizardRun.startOfMonth), InvoiceKind.subscription);
      expect(wizardKind(WizardRun.endOfMonth), InvoiceKind.usage);
      expect(wizardNextPeriod(DateTime(2026, 12, 15)), '2027-01');
      expect(wizardPreviousPeriod(DateTime(2026, 1, 15)), '2025-12');
    });

    test('the date suggests the run: the advance window before the month '
        'turns is the start run, the first days after are the end run', () {
      const rules = BillingRules(subscriptionAdvanceDays: 5);
      expect(suggestedRun(DateTime(2026, 9, 2), rules), WizardRun.endOfMonth);
      expect(suggestedRun(DateTime(2026, 9, 19), rules), WizardRun.endOfMonth);
      expect(suggestedRun(DateTime(2026, 9, 20), rules), WizardRun.startOfMonth);
      expect(suggestedRun(DateTime(2026, 9, 28), rules), WizardRun.startOfMonth);
      // A long advance window opens the start run earlier.
      expect(
          suggestedRun(DateTime(2026, 9, 16),
              const BillingRules(subscriptionAdvanceDays: 20)),
          WizardRun.startOfMonth);
    });

    test('a line belongs to a kind the way the server splits them', () {
      const fee = InvoiceLine(kind: 'subscription', label: '', amountCents: 1);
      const day = InvoiceLine(kind: 'overage', label: '', amountCents: 1);
      expect(lineBelongsTo(fee, InvoiceKind.subscription), isTrue);
      expect(lineBelongsTo(day, InvoiceKind.subscription), isFalse);
      expect(lineBelongsTo(day, InvoiceKind.usage), isTrue);
      expect(lineBelongsTo(fee, InvoiceKind.full), isTrue);
    });
  });

  group('plans (#827)', () {
    test('the issue plan narrows the previews to the run\'s kind and marks a '
        'member already covered — by that kind or by a full invoice', () {
      final previews = {
        'member-1': (
          lines: const [
            InvoiceLine(kind: 'subscription', label: '', amountCents: 5000),
            InvoiceLine(kind: 'overage', label: '', amountCents: 700),
          ],
          totalCents: 5700,
        ),
        'member-2': (
          lines: const [
            InvoiceLine(kind: 'overage', label: '', amountCents: 300),
          ],
          totalCents: 300,
        ),
        'member-3': (
          lines: const [
            InvoiceLine(kind: 'subscription', label: '', amountCents: 8000),
          ],
          totalCents: 8000,
        ),
      };
      final members = [
        (id: 'member-1', name: 'Flo'),
        (id: 'member-2', name: 'Ana'),
        (id: 'member-3', name: 'Ben'),
      ];
      final plan = issuePlan(
        members: members,
        previews: previews,
        invoices: [_invoice('inv-ben', member: 'member-3', period: '2026-10')],
        period: '2026-10',
        kind: InvoiceKind.subscription,
      );
      // Ana has no subscription line: not in the plan at all.
      expect(plan.map((i) => i.memberId), ['member-3', 'member-1']);
      final flo = plan.firstWhere((i) => i.memberId == 'member-1');
      expect(flo.totalCents, 5000);
      expect(flo.done, isFalse);
      expect(plan.firstWhere((i) => i.memberId == 'member-3').done, isTrue);
    });

    test('open means issued, positive, not voided, not settled, not paid; a '
        'partial payment keeps it open', () {
      final invoices = [
        _invoice('a'),
        _invoice('b', voidedAt: DateTime.utc(2026, 8, 3)),
        _invoice('c', settledBy: 'x'),
        _invoice('d', total: -500),
        _invoice('e'),
        _invoice('f'),
      ];
      final matches = {
        'e': _match('e'),
        'f': _match('f', resolution: 'under_accepted'),
      };
      expect(openInvoicesOf(invoices, matches).map((i) => i.id), ['a', 'f']);
    });

    test('the remind plan follows the dunning rules, skips a pending match, '
        'and keeps chasing a remainder', () {
      final now = DateTime.utc(2026, 9, 1);
      final invoices = [
        _invoice('old', issuedAt: now.subtract(const Duration(days: 20))),
        _invoice('fresh', issuedAt: now.subtract(const Duration(days: 3))),
        _invoice('waiting', issuedAt: now.subtract(const Duration(days: 30))),
        _invoice('partial', issuedAt: now.subtract(const Duration(days: 40))),
      ];
      final plan = remindPlan(
        invoices: invoices,
        matches: {
          'waiting': _match('waiting', status: 'pending'),
          'partial': _match('partial', resolution: 'under_accepted'),
        },
        reminders: {
          'partial': (count: 1, last: now.subtract(const Duration(days: 15))),
        },
        rules: DunningRules.defaults,
        now: now,
      );
      expect(plan.map((i) => '${i.invoice.id}:${i.level}'),
          ['partial:2', 'old:1']);
    });

    test('the close plan groups what one member can regroup, what can be '
        'written off, and the credit notes to refund', () {
      final invoices = [
        _invoice('a1', member: 'ana'),
        _invoice('a2', member: 'ana'),
        _invoice('b1', member: 'ben'),
        _invoice('b2', member: 'ben'),
        _invoice('cn', member: 'cara', total: -900),
      ];
      final plan = closePlan(
        invoices: invoices,
        matches: {'b2': _match('b2', resolution: 'under_accepted')},
      );
      final ana = plan.groups.firstWhere((g) => g.memberId == 'ana');
      expect(ana.canSettle, isTrue);
      expect(ana.open.length, 2);
      final ben = plan.groups.firstWhere((g) => g.memberId == 'ben');
      expect(ben.canSettle, isFalse);
      expect(ben.partial.map((i) => i.id), ['b2']);
      expect(plan.refunds.map((i) => i.id), ['cn']);
    });

    test('the tally adds up', () {
      const t = WizardTally(issued: 2, reminded: 1, matched: 3);
      expect(t.total, 6);
      expect(t.copyWith(settled: 1).total, 7);
    });
  });

  testWidgets('the hub offers the wizard (button and card) when the flag '
      'is on, and the wizard opens on its rail', (tester) async {
    await pumpInvoices(tester, money: await seededMoney());
    // The card sits on the To-invoice tab.
    await tester.tap(find.byKey(const ValueKey('invoice-tab-todo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('invoice-wizard-card')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('invoice-wizard-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('invoicing-wizard')), findsOneWidget);
    for (final step in WizardStep.values) {
      expect(find.byKey(ValueKey('wizard-step-${step.name}')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('wizard-period')), findsOneWidget);
  });

  testWidgets('with the flag off neither the button nor the card shows',
      (tester) async {
    await pumpInvoices(
      tester,
      money: await seededMoney(),
      workspace: FakeWorkspaceRepository.withWorkspace(
          featureFlags: const {'invoicingWizard': false}),
    );
    await tester.tap(find.byKey(const ValueKey('invoice-tab-todo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('invoice-wizard-card')), findsNothing);
    expect(find.byKey(const ValueKey('invoice-wizard-button')), findsNothing);
  });

  testWidgets('START run: the review counts the members to issue, one tap '
      'issues them all as SUBSCRIPTION invoices, the rows turn done, the '
      'summary counts them', (tester) async {
    final r = await _pumpWizard(tester);
    expect(find.byKey(const ValueKey('wizard-run-chip')), findsOneWidget);
    expect(find.text('Start of month'), findsWidgets);

    await _goTo(tester, WizardStep.issue);
    expect(find.byKey(const ValueKey('wizard-issue-member-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('wizard-issue-member-2')), findsOneWidget);
    // Leave Ana out of this batch.
    await tester.tap(find.byKey(const ValueKey('wizard-issue-member-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wizard-issue-all')));
    await tester.pumpAndSettle();

    final issued = r.money.invoices
        .where((i) => i.kind == InvoiceKind.subscription)
        .toList();
    expect(issued.map((i) => i.memberId), ['member-1']);
    expect(issued.single.lines.every((l) => l.kind == 'subscription'), isTrue);
    expect(find.byKey(const ValueKey('wizard-issued-member-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('wizard-issue-member-2')), findsOneWidget);

    // Send lists the run's invoice; the summary carries the count.
    await _goTo(tester, WizardStep.send);
    expect(find.byKey(ValueKey('wizard-send-${issued.single.id}')),
        findsOneWidget);
    await _goTo(tester, WizardStep.summary);
    expect(find.byKey(const ValueKey('wizard-tally')), findsOneWidget);
    expect(find.text('Invoices issued'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('a step with nothing to do says so instead of going blank',
      (tester) async {
    await _pumpWizard(tester, money: await seededMoney());
    await _goTo(tester, WizardStep.remind);
    expect(find.byKey(const ValueKey('wizard-nothing-remind')), findsOneWidget);
    await _goTo(tester, WizardStep.match);
    expect(find.byKey(const ValueKey('wizard-nothing-match')), findsOneWidget);
    await _goTo(tester, WizardStep.close);
    expect(find.byKey(const ValueKey('wizard-nothing-close')), findsOneWidget);
  });

  testWidgets('REMIND: an overdue invoice is listed with its level and one '
      'tap records every reminder', (tester) async {
    final money = FakeMoneyRepository();
    money.invoices.add(_invoice('inv-old',
        issuedAt: kTestNow.subtract(const Duration(days: 20))));
    final r = await _pumpWizard(tester, run: WizardRun.endOfMonth, money: money);
    await _goTo(tester, WizardStep.remind);
    expect(find.byKey(const ValueKey('wizard-remind-row-inv-old')),
        findsOneWidget);
    expect(find.textContaining('reminder 1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wizard-remind-all')));
    await tester.pumpAndSettle();
    expect(r.money.invoiceReminders['inv-old'], hasLength(1));
    expect(find.byKey(const ValueKey('wizard-nothing-remind')), findsOneWidget);
  });

  testWidgets('PAYMENTS: a declared payment is confirmed from the step; a '
      'bank payment is registered for a member through the new sheet',
      (tester) async {
    final r = await _pumpWizard(tester, events: [_payment('ev-pay')]);
    await _goTo(tester, WizardStep.payments);
    expect(find.byKey(const ValueKey('wizard-payment-ev-pay')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wizard-payment-accept-ev-pay')));
    await tester.pumpAndSettle();
    expect(r.events.decisions.single.eventId, 'ev-pay');

    await tester.tap(find.byKey(const ValueKey('wizard-register-payment')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('register-payment-member')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('register-payment-member-member-2')).last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('register-payment-amount')), '42.50');
    await tester.pumpAndSettle();
    await tester.ensureVisible(
        find.byKey(const ValueKey('register-payment-submit')));
    await tester.tap(find.byKey(const ValueKey('register-payment-submit')));
    await tester.pumpAndSettle();
    expect(r.money.recordedPayments.single.amountCents, 4250);

    await _goTo(tester, WizardStep.summary);
    expect(find.text('Payments confirmed or rejected'), findsOneWidget);
    expect(find.text('Payments registered'), findsOneWidget);
  });

  testWidgets('MATCH and CLOSE: an open invoice with credit on the account '
      'is ready to match; a member with two open invoices can regroup; the '
      'summary names whose move is left', (tester) async {
    final money = FakeMoneyRepository();
    money.invoices.addAll([
      _invoice('inv-a', member: 'member-2', total: 3000),
      _invoice('inv-b', member: 'member-2', total: 2000),
    ]);
    // An older month: the account leaves the running month's payments out.
    money.seedPayment('member-2', 3000, period: '2026-01');
    await _pumpWizard(tester, run: WizardRun.endOfMonth, money: money);
    await _goTo(tester, WizardStep.match);
    expect(find.byKey(const ValueKey('wizard-match-inv-a')), findsOneWidget);
    expect(find.textContaining('Credit available'), findsWidgets);

    await _goTo(tester, WizardStep.close);
    expect(find.byKey(const ValueKey('wizard-settle-member-2')), findsOneWidget);
    expect(find.text('Regroup 2'), findsOneWidget);

    await _goTo(tester, WizardStep.summary);
    expect(find.byKey(const ValueKey('wizard-todo-inv-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('wizard-todo-inv-b')), findsOneWidget);
  });

  testWidgets('Back and Next walk the rail; Finish leaves', (tester) async {
    await _pumpWizard(tester, money: await seededMoney());
    expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('wizard-back')))
            .onPressed,
        isNull);
    await tester.tap(find.byKey(const ValueKey('wizard-next')));
    await tester.pumpAndSettle();
    expect(find.text('2 / 8'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('wizard-back')));
    await tester.pumpAndSettle();
    expect(find.text('1 / 8'), findsOneWidget);
    await _goTo(tester, WizardStep.summary);
    expect(find.byKey(const ValueKey('wizard-next')), findsNothing);
    expect(find.byKey(const ValueKey('wizard-finish')), findsOneWidget);
  });

  testWidgets('the app route is registered behind the flag', (tester) async {
    // The DeskiloApp boots; the route exists (pin) — the page itself is
    // covered above without a router.
    await tester.pumpWidget(ProviderScope(
      overrides: standardTestOverrides(
          workspace: FakeWorkspaceRepository.withWorkspace()),
      child: const DeskiloApp(),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(DeskiloApp), findsOneWidget);
  });
}
