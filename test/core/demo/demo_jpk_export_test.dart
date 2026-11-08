// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2379 — Demo's real approved foreign-currency bill reaches the existing
// posting engine; a Polish JPK attempt refuses rather than inventing PLN or
// statutory facts. This is a refusal scenario, not a filing simulation.
import 'package:deskilo/core/demo/data/book_profile_repository.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/seed/demo_purchase_seed.dart';
import 'package:deskilo/core/demo/seed/demo_setup_seed.dart';
import 'package:deskilo/core/vat/tax_reference.dart';
import 'package:deskilo/features/money/domain/book_chart.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/jpk_kr_pd_gap.dart';
import 'package:deskilo/features/money/domain/saf_t_financial.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Demo posted bill refuses a Polish export without Polish facts',
    () async {
      final demo = DemoFixture.build();
      final purchasing = seedDemoPurchasing(demo.seededAt, money: demo.money);
      await purchasing.purchases.decideBill(
        'ws-1',
        'demo-bill-licence-chf',
        1,
        approve: true,
        reason: '',
        requestId: 'demo-jpk',
      );
      final profile = demoBookProfile(demo.seededAt);
      final books = FakeBookProfileRepository(
        money: demo.money,
        purchases: purchasing.purchases,
      );
      for (final (role, code, type) in [
        (BookRole.expenses, '606', AccountType.expense),
        (BookRole.suppliers, '401', AccountType.liability),
      ]) {
        books.accounts.add(
          BookAccount(
            id: 'acc-$code',
            workspaceId: 'ws-1',
            issuerSiteId: profile.issuerSiteId,
            code: code,
            name: code,
            type: type,
            isPosting: true,
            origin: AccountOrigin.manual,
            revision: 1,
          ),
        );
        books.mappings.add(
          BookMapping(
            id: role.wire,
            workspaceId: 'ws-1',
            issuerSiteId: profile.issuerSiteId,
            role: role,
            accountId: 'acc-$code',
            effectiveFrom: DateTime(2020),
            revision: 1,
          ),
        );
      }
      final set = await books.fetchPostings(
        'ws-1',
        profile.issuerSiteId,
        demo.seededAt.subtract(const Duration(days: 60)),
        demo.seededAt,
      );
      final bill = set.postings.singleWhere(
        (p) =>
            p.documentId == 'demo-bill-licence-chf' &&
            p.kind == PostingKind.supplierBill,
      );
      final result = buildSafTFinancial(
        SafTFinancialRequest(
          profile: SafTFinancialProfile.poland,
          period: FiscalYear.calendar(demo.seededAt.year),
          opening: const [],
          postings: [bill],
          accountNames: const {'606': 'Expenses', '401': 'Suppliers'},
          accountTypes: const {},
          parties: const {},
          partyDetails: const {},
          company: const InvoiceParty(),
          contact: const SafTContact(firstName: '', lastName: ''),
          currency: profile.functionalCurrency,
          softwareVersion: 'demo',
          createdAt: demo.seededAt,
          reference: const TaxReferenceSet([]),
        ),
      );
      expect(result, isA<SafTFinancialRefused>());
      final codes = (result as SafTFinancialRefused).gaps.map(
        (gap) => gap.polish?.code,
      );
      expect(codes, contains(JpkKrPdGapCode.currencyNotPln));
      expect(codes, contains(JpkKrPdGapCode.sectionReconciliation));
    },
  );
}
