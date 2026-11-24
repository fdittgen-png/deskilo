// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4165 (B2) -- paying invoices without a month in the Demo, through the
// Demo's own composition and the selection commands of My finances: two
// standalone invoices of the same customer are one selection apart from the
// monthly one (a mix is refused in the server's words), a declaration is one
// declaration that a retry after a lost answer does not repeat, an online
// payment whose answer was lost is found again under its request id and is
// never paid while pending, and the credit is posted once, in the month it
// arrived, spent only by the invoices that named it.
import 'package:deskilo/core/backend/operation_context.dart';
import 'package:deskilo/core/demo/data/money/demo_payment_gateway_repository.dart';
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/core/demo/demo_finances.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_space_ids.dart';
import 'package:deskilo/core/demo/demo_space_routing.dart' show kDemoInstallationId;
import 'package:deskilo/core/demo/demo_spaces.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/application/finance_selection_commands.dart';
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:deskilo/features/money/domain/finance_selection.dart';
import 'package:deskilo/features/money/domain/payment_claims.dart';
import 'package:deskilo/features/money/domain/payment_intent.dart';
import 'package:deskilo/features/money/domain/payment_provider.dart';
import 'package:deskilo/features/money/domain/standalone_invoice.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DemoFixture fixture;
  late FakeMoneyRepository money;
  late String subject;

  setUp(() {
    fixture = DemoFixture.build();
    money = fixture.space(DemoSpaceKey.home).money;
    subject = fixture.actor.memberId;
  });

  StandaloneDraft draft(String quantity) => StandaloneDraft(
    subjectMemberId: subject,
    serviceDate: fixture.seededAt,
    dueOn: fixture.seededAt.add(const Duration(days: 30)),
    lines: [
      StandaloneLine(
        description: 'Consulting',
        quantity: quantity,
        unitCode: 'hour',
        unitLabel: 'h',
        unEceCode: 'HUR',
        unitPrice: '80',
      ),
    ],
  );

  /// One standalone invoice of [subject], issued as the composer issues it.
  Future<String> issue(String quantity, String request) async {
    final commands = money.standaloneInvoiceCommands;
    final saved = await commands.saveDraft(
      workspaceId: demoFirstSpaceId,
      draft: draft(quantity),
    );
    final issued = await commands.issue(
      workspaceId: demoFirstSpaceId,
      draftId: saved.draftId,
      revision: saved.revision,
      requestId: request,
    );
    return issued.invoiceId;
  }

  /// The business's rows of Me, as the screen reads them.
  List<FinanceInvoice> rows() => [
    for (final i in demoFinanceOverview(fixture).invoices)
      if (i.workspaceId == demoFirstSpaceId) i.onInstallation(kDemoInstallationId),
  ];

  FinanceInvoice row(String id) => rows().firstWhere((i) => i.id == id);

  FinanceInvoice monthly() => rows().firstWhere(
    (i) => i.period != null && i.payable,
  );

  final target = WorkspaceTarget.local(
    installationId: kDemoInstallationId,
    workspaceId: demoFirstSpaceId,
  );

  FinanceSelectionCommands commands() => FinanceSelectionCommands(
    enter: (t) async => FinanceCommandTarget(
      target: t,
      memberId: subject,
      currency: 'EUR',
      commands: money.accountCommands,
      gateway: money.paymentGateway,
      isCurrent: () => true,
      release: () {},
      open: () async => true,
    ),
  );

  int paidOn(String id) => money.invoiceMatchesStore[id]?.paidCents ?? 0;

  List<LedgerEntry> credits() => [
    for (final e in money.ledger)
      if (e.memberId == subject &&
          e.kind == LedgerKind.credit &&
          e.category == LedgerCategory.payment &&
          e.allocationMode == 'explicit')
        e,
  ];

  test('two invoices without a month are one selection, and the monthly '
      'invoice of the same business cannot join it', () async {
    final a = await issue('1.5', 'req-a');
    final b = await issue('2', 'req-b');
    final first = row(a);
    expect(first.period, isNull);
    expect(first.isStandalone, isTrue);
    expect(FinanceSelection.selectable(first), isTrue);
    final selection = FinanceSelection.none.toggled(first).toggled(row(b));
    expect(selection.count, 2);
    expect(selection.isStandalone, isTrue);
    expect(selection.months, isEmpty);
    expect(
      selection.toggled(monthly()).count,
      2,
      reason: 'a mix of kinds is not offered',
    );
    expect(
      FinanceSelection.none.toggled(monthly()).toggled(first).count,
      1,
      reason: 'and the other way round',
    );
    expect(first.target, target);
  });

  test('a declaration is one declaration: a retry after a lost answer is the '
      'one already made, and the business accepting it pays both invoices '
      'once, posted in the month it was received', () async {
    final a = await issue('1.5', 'req-a');
    final b = await issue('2', 'req-b');
    final selection = FinanceSelection.none.toggled(row(a)).toggled(row(b));
    final due = selection.cents;
    expect(await commands().declare(selection), isTrue);
    expect(await commands().declare(selection), isTrue, reason: 'the retry');
    final events = fixture.space(DemoSpaceKey.home).events;
    final declared = events.events
        .where((e) => e.type == EventType.payment && e.payload['allocation_mode'] == 'explicit')
        .toList();
    expect(declared, hasLength(1), reason: 'never a second declaration');
    expect(declared.single.payload['amount_cents'], due);
    expect(money.claims[declared.single.id], unorderedEquals([a, b]));
    expect(paidOn(a) + paidOn(b), 0, reason: 'nothing is paid until decided');
    // the declaration is the customer's: the owner decides it
    final at = events.events.indexWhere((e) => e.id == declared.single.id);
    events.events[at] = events.events[at].copyWith(actorMemberId: 'member-2');
    await events.respond(declared.single.id, accept: true);
    expect(paidOn(a), row(a).totalCents);
    expect(paidOn(b), row(b).totalCents);
    final credit = credits().single;
    expect(credit.amountCents, due);
    expect(credit.period, '${fixture.seededAt.year}-${fixture.seededAt.month.toString().padLeft(2, '0')}');
  });

  test('a payment of the two invoices whose answer was lost is found again '
      'under its request id, shown once, and never paid while pending', () async {
    final a = await issue('1.5', 'req-a');
    final b = await issue('2', 'req-b');
    final selection = FinanceSelection.none.toggled(row(a)).toggled(row(b));
    final gateway = money.paymentGateway
      ..standIn = true
      ..loseNextAnswer = true;
    final claim = InvoiceClaim.standalone(
      amountCents: selection.cents,
      invoiceIds: [a, b],
    );
    Future<PaymentOrderStart> pay() => gateway.createClaimOrder(
      provider: PaymentProvider.stripe,
      workspaceId: demoFirstSpaceId,
      memberId: subject,
      currencyCode: 'EUR',
      claim: claim,
      requestId: 'pay-1',
    );
    List<PaymentIntent> mine() => [
      for (final p in money.paymentIntents)
        if (p.requestId == 'pay-1') p,
    ];
    await expectLater(pay, throwsA(isA<PaymentGatewayException>()));
    expect(mine(), hasLength(1), reason: 'the order was made');
    expect(mine().single.status, 'created');
    expect(mine().single.allocationMode, PaymentAllocationMode.explicit);
    expect(paidOn(a) + paidOn(b), 0, reason: 'pending is not paid');
    expect(row(a).inPayment, isTrue);
    expect(row(a).payable, isFalse, reason: 'in a payment, not for another');

    final again = await pay();
    expect(again.started, isTrue);
    expect(mine(), hasLength(1), reason: 'found again, not repeated');
    expect(again.orderId, mine().single.orderId);
    expect(gateway.requestIds, ['pay-1', 'pay-1']);

    await gateway.resolveOrder(again.orderId!, DemoPaymentOutcome.paid);
    await gateway.resolveOrder(again.orderId!, DemoPaymentOutcome.paid);
    expect(paidOn(a), row(a).totalCents);
    expect(paidOn(b), row(b).totalCents);
    expect(credits(), hasLength(1), reason: 'one credit, however often answered');
    expect(credits().single.period, '${fixture.seededAt.year}-${fixture.seededAt.month.toString().padLeft(2, '0')}');
  });

  test('a mixed payment is refused in the server\'s words, and nothing is '
      'recorded or charged', () async {
    final a = await issue('1.5', 'req-a');
    final m = monthly();
    final intents = money.paymentIntents.length;
    final claims = {...money.claims.keys};
    final gateway = money.paymentGateway..standIn = true;
    Future<void> refused(Future<Object?> Function() call, ClaimRefusal reason) async {
      await expectLater(
        call,
        throwsA(isA<ClaimRefused>().having((e) => e.reason, 'reason', reason)),
      );
    }

    await refused(
      () => gateway.createClaimOrder(
        provider: PaymentProvider.stripe,
        workspaceId: demoFirstSpaceId,
        memberId: subject,
        currencyCode: 'EUR',
        claim: InvoiceClaim.standalone(
          amountCents: m.remainingCents + row(a).remainingCents,
          invoiceIds: [a, m.id],
        ),
        requestId: 'mix-1',
      ),
      ClaimRefusal.monthlyInStandalone,
    );
    await refused(
      () => gateway.createClaimOrder(
        provider: PaymentProvider.stripe,
        workspaceId: demoFirstSpaceId,
        memberId: subject,
        currencyCode: 'EUR',
        claim: InvoiceClaim(
          period: m.period!,
          amountCents: m.remainingCents + row(a).remainingCents,
          invoiceIds: [m.id, a],
        ),
        requestId: 'mix-2',
      ),
      ClaimRefusal.standaloneInMonthly,
    );
    await refused(
      () => money.accountCommands.declareInvoicesPaid(
        workspaceId: demoFirstSpaceId,
        memberId: subject,
        claim: InvoiceClaim.standalone(
          amountCents: m.remainingCents,
          invoiceIds: [m.id],
        ),
      ),
      ClaimRefusal.monthlyInStandalone,
    );
    expect(money.paymentIntents, hasLength(intents));
    expect(money.claims.keys.toSet(), claims);
  });

  test('a payment function that does not say it takes invoices without a '
      'month is not used for them', () async {
    money.paymentGateway.takesStandalone = false;
    final config = await money.paymentGateway.fetchPaymentConfig(demoFirstSpaceId);
    expect(config.standalone, isFalse);
    expect(config.claims, isTrue);
  });
}
