// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4168 (B) -- Kessler Conseil's customers read their own invoices, each from
// their own login, under the grant the business issued (#4164): Ada reads
// Lindner Beratung's, the practice she runs, because she accepted its code
// and not because she owns that practice; Chiara Bernard, a customer in her
// own name, reads hers from her personal account; Bruno, the seller, reads
// neither as a customer. The rows are the invoices the business issued, so
// the seller's figures and the customer's never disagree, and a revocation
// ends the reading and erases nothing.
import 'package:deskilo/core/demo/demo_finances.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_space_ids.dart';
import 'package:deskilo/core/demo/demo_spaces.dart';
import 'package:deskilo/core/demo/seed/demo_freelancer_seed.dart'
    show demoKesslerChiaraId, demoKesslerLindnerId;
import 'package:deskilo/core/failure/app_failure.dart';
import 'package:deskilo/features/money/application/customer_quote_commands.dart';
import 'package:deskilo/features/money/domain/billing_access.dart';
import 'package:deskilo/features/money/domain/customer_quote.dart';
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DemoFixture fixture;

  setUp(() => fixture = DemoFixture.build());

  List<BilledSubject> kessler() => [
    for (final g in demoFinanceOverview(fixture).billedGroups)
      if (g.workspaceId == demoFreelancerSpaceId) g,
  ];

  test('Ada reads the invoices Kessler Conseil made out to Lindner Beratung, '
      'apart from what she owes herself: EUR 108.00, paid', () {
    fixture.becomePersona(DemoPersona.owner);
    final groups = kessler();

    expect(groups.map((g) => g.subjectId), [demoKesslerLindnerId]);
    expect(groups.single.workspaceName, 'Kessler Conseil');
    final invoice = groups.single.invoices.single;
    expect(invoice.number, 'KC-2026-0003');
    expect(invoice.totalCents, 10800);
    expect(invoice.state, FinanceState.paid);
    expect(groups.single.openByCurrency, isEmpty, reason: 'nothing is open');
    expect(invoice.paidCents, 10800);
    expect(invoice.payable, isFalse, reason: 'paid in full: nothing to pay');
    expect(
      demoFinanceOverview(fixture).invoices
          .where((i) => i.workspaceId == demoFreelancerSpaceId),
      isEmpty,
      reason: 'she is no member of the business: nothing is hers to owe there',
    );
  });

  test('Chiara reads her EUR 60.00 from her personal account; Ada does not '
      'read it, and Bruno, the seller, reads no customer of his', () {
    fixture.becomePersona(DemoPersona.admin);
    final chiara = kessler();
    expect(chiara.map((g) => g.subjectId), [demoKesslerChiaraId]);
    expect(chiara.single.invoices.single.number, 'KC-2026-0002');
    expect(chiara.single.openByCurrency, {'EUR': 6000});
    final sixty = chiara.single.invoices.single;
    expect(sixty.claimEventId, isNotNull, reason: 'she declared paying it');
    expect(
      sixty.payable,
      isFalse,
      reason: 'her declaration waits for Bruno: it is not paid twice',
    );

    fixture.becomePersona(DemoPersona.owner);
    expect(
      kessler().map((g) => g.subjectId),
      isNot(contains(demoKesslerChiaraId)),
    );

    fixture.becomePersona(DemoPersona.member);
    expect(kessler(), isEmpty);
  });

  test(
    'converting the accepted quote of Domaine des Aires adds nothing to '
    'what Ada or Chiara read: each customer reads their own debts only',
    () async {
      fixture.becomePersona(DemoPersona.member);
      final quotes = fixture.stores.at(DemoSpaceKey.freelancer).customerQuotes;
      final commands = CustomerQuoteCommands(quotes);
      final quote = (await quotes.quotes(demoFreelancerSpaceId)).single;
      final prep = await commands.prepareConversion(
        demoFreelancerSpaceId,
        quote.id,
        serviceDate: fixture.seededAt,
        dueOn: fixture.seededAt.add(const Duration(days: 30)),
      );
      final converted = await commands.convert(
        demoFreelancerSpaceId,
        quote.id,
        draftRevision:
            (prep as CommandDone<QuoteConversionPrep>).value.draftRevision,
        requestId: 'reads-1',
      );
      expect(converted, isA<CommandDone<QuoteConverted>>());

      fixture.becomePersona(DemoPersona.owner);
      expect(
        [
          for (final g in kessler())
            for (final i in g.invoices) i.number,
        ],
        ['KC-2026-0003'],
      );
      fixture.becomePersona(DemoPersona.admin);
      expect(
        [
          for (final g in kessler())
            for (final i in g.invoices) i.number,
        ],
        ['KC-2026-0002'],
      );
    },
  );

  test("Ada's code is no one else's: another account is refused, and a "
      'second invitation she accepts answers the grant she holds', () async {
    final access = fixture.stores.home.billingAccess;
    fixture.becomePersona(DemoPersona.member);
    expect(
      () => access.accept('LINDNER2026'),
      throwsA(
        isA<BillingAccessRefusal>().having(
          (e) => e.kind,
          'kind',
          BillingAccessRefusalKind.codeUnusable,
        ),
      ),
    );
    final again = await access.invite(
      demoFreelancerSpaceId,
      demoKesslerLindnerId,
      'reads-invite-2',
    );

    fixture.becomePersona(DemoPersona.owner);
    final accepted = await access.accept(again.code);
    expect(accepted.replayed, isTrue, reason: 'one live grant per account');
    expect(kessler(), hasLength(1));
  });

  test(
    'Bruno revokes the grant: Ada reads nothing of Kessler Conseil any '
    'more, the grant stays as history and Lindner stays his customer',
    () async {
      final access = fixture.stores.home.billingAccess;
      fixture.becomePersona(DemoPersona.member);
      final grant = (await access.grantsOf(
        demoFreelancerSpaceId,
        demoKesslerLindnerId,
      )).single;
      expect(grant.stateAt(fixture.seededAt), BillingGrantState.active);
      await access.revoke(grant.id, reason: 'contract ended');

      fixture.becomePersona(DemoPersona.owner);
      expect(kessler(), isEmpty);
      expect(
        demoFinanceOverview(fixture).billedGroups.map((g) => g.workspaceId),
        isNot(contains(demoFreelancerSpaceId)),
      );
      fixture.becomePersona(DemoPersona.member);
      final after = (await access.grantsOf(
        demoFreelancerSpaceId,
        demoKesslerLindnerId,
      )).single;
      expect(after.stateAt(fixture.seededAt), BillingGrantState.revoked);
      expect(
        fixture.stores
            .at(DemoSpaceKey.freelancer)
            .billingCustomers
            .of(demoFreelancerSpaceId)
            .any((c) => c.subjectId == demoKesslerLindnerId),
        isTrue,
      );
    },
  );

  test(
    'an answer lost on the way grants nothing; the same code accepted again '
    'reads the invoice, once',
    () async {
      final access = fixture.stores.home.billingAccess;
      fixture.becomePersona(DemoPersona.member);
      final grant = (await access.grantsOf(
        demoFreelancerSpaceId,
        demoKesslerLindnerId,
      )).single;
      await access.revoke(grant.id, reason: 'new contact');
      final invitation = await access.invite(
        demoFreelancerSpaceId,
        demoKesslerLindnerId,
        'reads-invite-3',
      );

      fixture.becomePersona(DemoPersona.owner);
      access.failNext = Exception('the connection dropped');
      await expectLater(access.accept(invitation.code), throwsException);
      expect(kessler(), isEmpty, reason: 'nothing was accepted');

      final accepted = await access.accept(invitation.code);
      expect(accepted.replayed, isFalse);
      expect(
        [
          for (final g in kessler())
            for (final i in g.invoices) i.number,
        ],
        ['KC-2026-0003'],
      );
      expect((await access.accept(invitation.code)).replayed, isTrue);
      expect(kessler(), hasLength(1));
    },
  );
}
