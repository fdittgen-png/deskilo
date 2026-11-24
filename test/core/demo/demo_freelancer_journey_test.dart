// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4168 (B) -- Kessler Conseil, the Demo's freelancer, PERFORMED: Bruno owns the
// business (and nobody else is in it), his customers have no account, the quote
// the customer accepted is converted into its one invoice through the real
// invoicing of his own business, a payment of EUR 300.00 is recorded against
// it, and what is left owed to him and by him reads as the scenario states:
// EUR 642.00 invoiced, EUR 342.00 left on it, EUR 60.00 on the other open
// invoice (EUR 402.00 to collect in all), the paid one gone from the list, and
// the printer's EUR 120.00 to pay. The figures are arithmetic fixtures, not a
// tax treatment of any jurisdiction.
import 'package:deskilo/app/router.dart';
import 'package:deskilo/core/demo/data/fake_business_payables.dart';
import 'package:deskilo/core/demo/data/fake_business_receivables.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/demo/demo_space_fulfilments.dart';
import 'package:deskilo/core/demo/demo_space_ids.dart';
import 'package:deskilo/core/demo/demo_space_stores.dart';
import 'package:deskilo/core/demo/demo_spaces.dart';
import 'package:deskilo/features/money/application/customer_quote_commands.dart';
import 'package:deskilo/features/money/application/receivables_answers.dart';
import 'package:deskilo/features/money/domain/business_receivables.dart';
import 'package:deskilo/features/money/domain/customer_quote.dart';
import 'package:deskilo/features/money/domain/dunning.dart';
import 'package:deskilo/features/money/domain/service_fulfilment.dart';
import 'package:deskilo/features/money/presentation/invoice_journey.dart';
import 'package:deskilo/features/money/presentation/invoicing/receivables_adapter.dart';
import 'package:deskilo/features/money/providers/business_receivables_providers.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/demo_journeys.dart' show pumpDemo;

void main() {
  late DemoFixture fixture;
  late DemoSpaceParts space;
  late DemoSpaceStores stores;
  late CustomerQuoteCommands commands;
  late DateTime today;

  setUp(() {
    fixture = DemoFixture.build()..becomePersona(DemoPersona.member);
    space = fixture.space(DemoSpaceKey.freelancer);
    stores = fixture.stores.at(DemoSpaceKey.freelancer);
    commands = CustomerQuoteCommands(stores.customerQuotes);
    today = fixture.seededAt;
  });

  Future<CustomerQuote> theQuote() async =>
      (await stores.customerQuotes.quotes(demoFreelancerSpaceId)).single;

  test('Bruno owns the business and its other members are customers without an account', () {
    final owner = DemoPersona.member.person;

    expect(space.workspaces.myMember.id, owner.memberId);
    expect(space.workspaces.myMember.isOwner, isTrue);
    expect(
      [for (final m in space.workspaces.otherMembers) m.isAdmin || m.isOwner],
      everyElement(isFalse),
      reason: 'the others are customers with no account and no right here',
    );
    expect([
      for (final m in space.workspaces.otherMembers) m.userId,
    ], everyElement(isEmpty));
    expect(
      [
        for (final m in [
          space.workspaces.myMember,
          ...space.workspaces.otherMembers,
        ])
          m.id,
      ],
      isNot(contains(DemoPersona.owner.person.memberId)),
      reason:
          'Ada, who owns the main space, is no member here: ownership is '
          'the membership of this business, never a global persona',
    );
    expect(space.workspaces.myMember.status, MemberStatus.active);
  });

  test(
    'the customer accepted revision 2 of the quote: 1.5 h at 90.00 and a '
    'training at 400.00, EUR 535.00 net and EUR 642.00 with 20 % VAT',
    () async {
      final quote = await theQuote();

      expect(quote.status, QuoteStatus.accepted);
      expect(quote.current!.revision, 2);
      expect(quote.decision!.accepted, isTrue);
      expect(quote.decision!.revision, 2);
      expect(quote.current!.totals!.totalCents, 64200);
      expect(
        [for (final l in quote.current!.lines) l.description],
        ['Consulting', 'Training day'],
      );
      expect(
        [for (final a in quote.current!.amounts) a.netCents],
        [13500, 40000],
      );
    },
  );

  test('converting the accepted quote issues the real invoice into the '
      'business: EUR 642.00, one invoice however many requests', () async {
    final quote = await theQuote();
    final prep = await commands.prepareConversion(
      demoFreelancerSpaceId,
      quote.id,
      serviceDate: today,
      dueOn: today.add(const Duration(days: 30)),
    );
    final ready = (prep as QuoteDone<QuoteConversionPrep>).value;
    expect(ready.issuable, isTrue);
    expect(ready.wouldBeTotalCents, 64200);
    expect(ready.contextChanged, isFalse, reason: 'it is what was accepted');

    final first = await commands.convert(
      demoFreelancerSpaceId,
      quote.id,
      draftRevision: ready.draftRevision,
      requestId: 'request-1',
    );
    final second = await commands.convert(
      demoFreelancerSpaceId,
      quote.id,
      draftRevision: ready.draftRevision,
      requestId: 'request-2',
    );

    final issued = (first as QuoteDone<QuoteConverted>).value;
    expect(issued.replayed, isFalse);
    expect(
      (second as QuoteDone<QuoteConverted>).value.invoiceId,
      issued.invoiceId,
    );
    expect(second.value.replayed, isTrue, reason: 'one quote, one invoice');
    final invoices = [
      for (final i in space.money.invoices)
        if (i.id == issued.invoiceId) i,
    ];
    expect(invoices, hasLength(1));
    expect(invoices.single.totalCents, 64200);
    expect(invoices.single.memberName, 'Domaine des Aires');
    expect((await theQuote()).status, QuoteStatus.converted);
  });

  test('the training engagement is done before its invoice, and the invoice, '
      'the payment and a credit are read beside it and add nothing to it', () async {
    final before = (await demoServiceFulfilments(fixture, DemoSpaceKey.freelancer).fulfilments(demoFreelancerSpaceId)).single;
    expect(before.scope.description, 'Training day');
    expect(before.state, FulfilmentState.done);
    expect(before.history.map((h) => h.to), [FulfilmentState.ordered, FulfilmentState.started, FulfilmentState.done]);
    expect(before.invoices, isEmpty, reason: 'nothing was invoiced when the work was done');

    final quote = await theQuote();
    final prep = await commands.prepareConversion(
      demoFreelancerSpaceId,
      quote.id,
      serviceDate: today,
      dueOn: today.add(const Duration(days: 30)),
    );
    final ready = (prep as QuoteDone<QuoteConversionPrep>).value;
    final issued =
        ((await commands.convert(
                  demoFreelancerSpaceId,
                  quote.id,
                  draftRevision: ready.draftRevision,
                  requestId: 'request-engagement',
                ))
                as QuoteDone<QuoteConverted>)
            .value;
    space.money.ledger.add(
      LedgerEntry(
        id: 'ledger-engagement-300',
        memberId: quote.subjectId,
        kind: LedgerKind.credit,
        category: LedgerCategory.payment,
        amountCents: 30000,
        description: 'Bank transfer',
        period: '2026-05',
        createdAt: today,
        occurredOn: today,
      ),
    );
    await space.money.matchInvoice(
      invoiceId: issued.invoiceId,
      paymentLedgerId: 'ledger-engagement-300',
      resolution: 'under_accepted',
      note: 'first instalment',
      amountCents: 30000,
    );

    final after = (await demoServiceFulfilments(fixture, DemoSpaceKey.freelancer).fulfilments(demoFreelancerSpaceId)).single;
    expect(after.id, before.id, reason: 'the invoice made no second engagement');
    expect(after.history, hasLength(3), reason: 'neither the invoice nor the payment added a step');
    expect(after.state, FulfilmentState.done);
    expect(after.invoices.single.invoiceId, issued.invoiceId);
    expect(after.invoices.single.paidCents, 30000);
    expect(after.quote?.status, 'converted');
    final fromInvoice = await demoServiceFulfilments(fixture, DemoSpaceKey.freelancer).openFromLine(
      demoFreelancerSpaceId,
      requestId: 'open-from-invoice',
      kind: 'invoice',
      id: issued.invoiceId,
      lineId: after.source.lineId,
    );
    expect(fromInvoice.fulfilment.id, before.id, reason: 'the invoice resolves to the same engagement');
    expect(fromInvoice.created, isFalse);
  });

  test('a quote that is not accepted is refused, and an interrupted answer '
      'leaves nothing issued, to be tried again', () async {
    final quote = await theQuote();
    final before = space.money.invoices.length;
    stores.customerQuotes.failNext = StateError('connection lost');

    final lost = await commands.prepareConversion(
      demoFreelancerSpaceId,
      quote.id,
      serviceDate: today,
      dueOn: today.add(const Duration(days: 30)),
    );

    expect(lost, isA<QuoteUnreached<QuoteConversionPrep>>());
    expect(space.money.invoices.length, before, reason: 'nothing was issued');
    final again = await commands.prepareConversion(
      demoFreelancerSpaceId,
      quote.id,
      serviceDate: today,
      dueOn: today.add(const Duration(days: 30)),
    );
    expect(again, isA<QuoteDone<QuoteConversionPrep>>());
  });

  test('after EUR 300.00 is paid on it, EUR 342.00 is left on the new '
      'invoice and Bruno\'s business is owed EUR 402.00; the paid invoice is '
      'not owed and the printer is owed EUR 120.00', () async {
    final quote = await theQuote();
    final prep = (await commands.prepareConversion(
      demoFreelancerSpaceId,
      quote.id,
      serviceDate: today,
      dueOn: today.add(const Duration(days: 30)),
    )) as QuoteDone<QuoteConversionPrep>;
    final issued = ((await commands.convert(
      demoFreelancerSpaceId,
      quote.id,
      draftRevision: prep.value.draftRevision,
      requestId: 'request-1',
    )) as QuoteDone<QuoteConverted>).value;
    // the customer's transfer, registered and matched to the invoice in part
    space.money.ledger.add(
      LedgerEntry(
        id: 'ledger-aires-300',
        memberId: 'kessler-customer-aires',
        kind: LedgerKind.credit,
        category: LedgerCategory.payment,
        amountCents: 30000,
        description: 'Bank transfer',
        period: '${today.year}-${today.month.toString().padLeft(2, '0')}',
        createdAt: today,
        occurredOn: today,
      ),
    );
    await space.money.matchInvoice(
      invoiceId: issued.invoiceId,
      paymentLedgerId: 'ledger-aires-300',
      resolution: 'under_accepted',
      note: 'first instalment',
      amountCents: 30000,
    );

    final receivables = FakeBusinessReceivablesRepository(
      (id) => id == demoFreelancerSpaceId ? space.money : null,
    );
    final summary = await receivables.summary(demoFreelancerSpaceId);
    final payables = FakeBusinessPayablesRepository(
      (id) => id == demoFreelancerSpaceId ? stores.buying.purchases : null,
    );
    final owed = await payables.supplierBalances(demoFreelancerSpaceId);

    expect(summary.rows.single.currency, 'EUR');
    expect(
      summary.rows.single.toCollectCents,
      34200,
      reason: 'what is left of the converted quote',
    );
    expect(
      summary.rows.single.declaredCents,
      6000,
      reason: 'Chiara declared her payment; Bruno has not confirmed it',
    );
    expect(
      summary.rows.single.receivableCents,
      34200 + 6000,
      reason: 'the 402.00 Me shows to collect, the declared 60.00 included',
    );
    expect(
      summary.rows.single.invoices,
      2,
      reason: 'the paid invoice is not owed',
    );
    expect(owed.single.remainingCents, 12000);
    expect(owed.single.currency, 'EUR');
  });

  test("Chiara's declared EUR 60 is to confirm on the invoicing home: one invoice, "
      'EUR 60.00, the event Bruno decides', () async {
    final money = space.money;
    final events = space.events.events;
    final reader = ReceivablesReader(
      matches: await money.fetchInvoiceMatches(demoFreelancerSpaceId),
      reminders: const {},
      rules: DunningRules.defaults,
      now: today,
      dayOf: (instant) => DateTime.utc(instant.year, instant.month, instant.day),
      eventFactsOf: (invoice, match) => (
        journey: journeyFactsOf(invoice, match, events),
        declaration: declarationOf(invoice, events),
      ),
    );
    final receivables = reader.read(money.invoices);
    final toConfirm = [
      for (final r in receivables)
        if (owedBucketOf(r, today) == OwedBucket.toConfirm) r,
    ];

    expect(toConfirm.map((r) => r.number), ['KC-2026-0002']);
    expect(toConfirm.single.openMinor, 6000);
    expect(toConfirm.single.declaredEventId, 'evt-payment-kessler-a2');
    expect(
      receivables.where((r) => r.number == 'KC-2026-0003').single.paymentPending,
      isFalse,
      reason: 'the paid invoice is not on its way',
    );
  });

  test('Me counts what Bruno may read: his business, and London through the one '
      'finance-read role he holds there; every other business refuses', () async {
    final container = ProviderContainer(overrides: demoOverrides(fixture))
      ..listen(currentWorkspaceProvider, (_, _) {});
    addTearDown(container.dispose);
    await container.read(currentWorkspaceProvider.future);

    final sources = await container.read(myBusinessReceivablesProvider.future);
    final answered = {
      for (final s in sources.whereType<BusinessReceivablesAnswered>())
        s.workspaceId: s.summary,
    };
    final refused = {
      for (final s in sources.whereType<BusinessReceivablesRefused>())
        s.workspaceId,
    };

    // his business, the shop he also owns (#4365), and London's finance-read role
    expect(answered.keys.toSet(), {demoFreelancerSpaceId, demoShopSpaceId, demoLondonSpaceId});
    expect(
      refused,
      isNot(contains(demoFreelancerSpaceId)),
      reason: 'a refusal is never a zero, and his own business is no refusal',
    );
    expect(refused, isNotEmpty, reason: 'a plain member reads no finances');
    final london = answered[demoLondonSpaceId]!.rows.single;
    expect(london.currency, 'GBP', reason: 'pounds are counted apart from euros');
    final londonMoney = fixture.space(DemoSpaceKey.london).money;
    expect(
      london.toCollectCents,
      [
        for (final i in londonMoney.invoices)
          if (!i.isVoided && i.settledByInvoiceId == null && i.totalCents > 0)
            i.totalCents - (londonMoney.invoiceMatchesStore[i.id]?.paidCents ?? 0),
      ].where((c) => c > 0).fold<int>(0, (a, b) => a + b),
      reason: "London's own unpaid invoices, whatever they come to",
    );
    final own = answered[demoFreelancerSpaceId]!.rows.single;
    expect([own.currency, own.declaredCents], ['EUR', 6000]);
  });

  testWidgets('Me names Kessler Conseil with the kind its owner set, beside '
      'the country and currency', (tester) async {
    await pumpDemo(tester, persona: DemoPersona.member, openHub: false);
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
        .read(routerProvider)
        .go('/me');
    await tester.pumpAndSettle();

    final row = find.textContaining('Kessler Conseil');
    expect(row, findsWidgets);
    expect(
      find.textContaining(AppLocalizationsEn().businessKindNameFreelancer),
      findsOneWidget,
    );
  });
}
