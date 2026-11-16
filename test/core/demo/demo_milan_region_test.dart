// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4105 (step 4) -- the Demo performs what is told before an invoice is
// issued, in the Milan house, whose channel is the SdI: a customer without a
// province is refused (Italy's invoices require it), a customer in
// Switzerland without a VAT number is warned about (the e-invoice cannot be
// sent until it is added; the invoice can still be issued), and every other
// customer, with a real province, issues as before.
import 'package:deskilo/core/demo/data/money/demo_invoice_issue_drafts.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/seed/demo_trade_city_seed.dart';
import 'package:deskilo/core/jurisdiction/installed_postal_layouts.dart';
import 'package:deskilo/features/money/domain/einvoice_channel_check.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixture = DemoFixture.build(now: DateTime(2026, 11, 15, 10));
  final money = fixture.milan.money;
  final drafts = DemoInvoiceIssueDrafts(money.invoiceQueries);
  Future<List<String>> missing(String memberId) =>
      money.invoiceQueries.invoiceIssueReadiness(
        workspaceId: demoMilanSpaceId,
        memberId: memberId,
        period: '2026-10',
      );

  test('the house and its customers name real provinces', () {
    final provinces = postalLayoutOf('IT').region!.names;
    final milan = fixture.workspaces.workspaces.singleWhere(
      (w) => w.id == demoMilanSpaceId,
    );
    expect(provinces.keys, contains(milan.invoiceLegal['subdivision']));
    for (final member in fixture.milan.workspaces.otherMembers) {
      final customer = demoMilan.customerOf(member.id);
      if (customer.region.isEmpty) continue;
      expect(provinces.keys, contains(customer.region), reason: member.id);
    }
  });

  test('a customer without a province is refused before issuing', () async {
    expect(await missing('it-member-1'), contains('buyer_region'));
    final draft = await drafts.issueDraft(
      workspaceId: demoMilanSpaceId,
      memberId: 'it-member-1',
      period: '2026-10',
    );
    expect(draft.buyer, isNull, reason: 'a refused issue stores nothing');
  });

  test('a customer in Switzerland without a VAT number is warned about, not refused', () async {
    expect(await missing('it-member-2'), isNot(contains('buyer_region')));
    final draft = await drafts.issueDraft(
      workspaceId: demoMilanSpaceId,
      memberId: 'it-member-2',
      period: '2026-10',
    );
    final gaps = channelGapsFor(
      await money.fetchEInvoiceGateway(demoMilanSpaceId),
      seller: draft.seller!,
      buyer: draft.buyer!,
    );
    expect(gaps, [ChannelGap.buyerTaxId]);
  });

  test(
    'every other customer issues as before, with nothing to warn about',
    () async {
      expect(await missing('it-member-3'), isEmpty);
      final draft = await drafts.issueDraft(
        workspaceId: demoMilanSpaceId,
        memberId: 'it-member-3',
        period: '2026-10',
      );
      final gaps = channelGapsFor(
        await money.fetchEInvoiceGateway(demoMilanSpaceId),
        seller: draft.seller!,
        buyer: draft.buyer!,
      );
      expect(gaps, isEmpty);
    },
  );
}
