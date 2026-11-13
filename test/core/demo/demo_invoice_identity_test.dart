// SPDX-License-Identifier: AGPL-3.0-or-later
// Issued demo documents snapshot the selected workspace and buyer, on the
// session clock. A later identity change never rewrites the archived invoice.
import 'package:deskilo/core/demo/data/money/demo_invoice_identity.dart';
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an approved sale keeps the rate recorded with the request', () async {
    final fixture = DemoFixture.build(now: DateTime.utc(2027, 2, 9, 10))
      ..becomePersona(DemoPersona.member);
    final city = fixture.zurich;
    final money = city.money;
    final service = money.services.first;
    final original = money.vatRates.singleWhere((r) => r.isDefault);
    await money.recordServiceCharge(
      workspaceId: city.spec.workspaceId,
      subjectMemberId: DemoPersona.member.memberId,
      serviceId: service.id,
      quantity: 2,
      period: '2027-02',
    );
    final request = city.events.events.last;
    money.vatRates = [original.copyWith(percent: 19)];
    fixture.becomePersona(DemoPersona.admin);
    await city.events.respond(request.id, accept: true);
    final id = await money.createInvoice(
      workspaceId: city.spec.workspaceId,
      memberId: DemoPersona.member.memberId,
      period: '2027-02',
      kind: InvoiceKind.usage,
    );
    final invoice = money.invoices.firstWhere((i) => i.id == id);
    expect(invoice.lines, hasLength(1));
    expect(invoice.totalCents, service.priceCents * 2);
    expect(invoice.lines.single.vatPercent, original.percent);
    expect(invoice.vatTotals.single.percent, original.percent);
  });

  test(
    'Swiss and Italian issue uses the member statement and configured VAT',
    () async {
      final fixture = DemoFixture.build(now: DateTime.utc(2027, 2, 9, 10));
      for (final (city, rate) in [
        (fixture.zurich, 8.1),
        (fixture.milan, 22.0),
      ]) {
        const period = '2027-03';
        final money = city.money;
        final member = city.workspaces.myMember;
        money.ledger.add(
          LedgerEntry(
            id: 'sale-charge',
            memberId: member.id,
            kind: LedgerKind.charge,
            category: LedgerCategory.service,
            amountCents: 500,
            description: 'Two catalogue items',
            period: period,
            createdAt: fixture.seededAt,
          ),
        );
        final statement = await money.fetchStatement(member.id, period);
        final id = await money.createInvoice(
          workspaceId: member.workspaceId,
          memberId: member.id,
          period: period,
        );
        final invoice = money.invoices.firstWhere((i) => i.id == id);
        expect(invoice.totalCents, statement.feeCents + 500);
        expect(invoice.lines.where((l) => l.kind == 'overage'), isEmpty);
        expect(invoice.lines.map((l) => l.vatPercent).toSet(), {rate});
        expect(invoice.vatTotals, isNotEmpty);
        final expectedNet = invoice.lines.fold<int>(
          0,
          (sum, line) => sum + (line.amountCents * 100 / (100 + rate)).round(),
        );
        expect(
          invoice.vatTotals.fold<int>(0, (n, t) => n + t.netCents),
          expectedNet,
        );
        expect(
          invoice.vatTotals.fold<int>(0, (n, t) => n + t.vatCents),
          invoice.totalCents - expectedNet,
        );
      }
    },
  );

  test(
    'issue, replacement and void use the injected parties and actor',
    () async {
      final now = DateTime.utc(2027, 2, 9, 10);
      final money = FakeMoneyRepository(clock: () => now)
        ..invoiceCommands.currency = 'CHF';
      var issuer = 'Demo operator';
      DemoInvoiceIdentity parties(String workspaceId, String memberId) => (
        memberName: 'Swiss customer',
        memberAddress: 'Buyer address',
        workspaceName: 'Swiss workshop',
        workspaceAddress: 'Zurich address',
        issuerName: issuer,
        seller: const InvoiceParty(name: 'Swiss workshop', country: 'CH'),
        buyer: const InvoiceParty(name: 'Swiss customer', country: 'CH'),
      );
      money.invoiceIdentity = parties;
      final id = await money.createInvoice(
        workspaceId: 'ch',
        memberId: 'buyer',
        period: '2027-02',
      );
      final issued = money.invoices.single;
      expect(issued.id, id);
      expect(issued.memberName, 'Swiss customer');
      expect(issued.memberAddress, 'Buyer address');
      expect(issued.workspaceName, 'Swiss workshop');
      expect(issued.workspaceAddress, 'Zurich address');
      expect(issued.issuerName, issuer);
      expect(issued.currency, 'CHF');
      expect(issued.issuedAt, now);
      expect(issued.buyerParty?.country, 'CH');
      expect(issued.sellerParty?.country, 'CH');
      issuer = 'Second operator';
      await money.voidInvoice(id);
      expect(money.invoices.single.issuerName, 'Demo operator');
      expect(money.invoices.single.voidedByName, issuer);
      final replacement = await money.createInvoice(
        workspaceId: 'ch',
        memberId: 'buyer',
        period: '2027-02',
        replacesId: id,
      );
      expect(
        money.invoices.firstWhere((i) => i.id == replacement).issuerName,
        issuer,
      );
      final current = money.invoices.firstWhere((i) => i.id == replacement);
      final payment = money.seedPayment(
        'buyer',
        current.totalCents,
        period: '2027-02',
      );
      expect(money.ledger.last.createdAt, now);
      await money.matchInvoice(
        invoiceId: replacement,
        paymentLedgerId: payment,
        resolution: 'exact',
      );
      expect(money.invoiceMatchesStore[replacement]?.byName, issuer);
      money.invoices.add(current.copyWith(id: 'credit', totalCents: -500));
      await money.settleCreditInvoice('credit');
      expect(money.invoiceMatchesStore['credit']?.byName, issuer);
      money.invoices.addAll([
        current.copyWith(id: 'first-source'),
        current.copyWith(id: 'second-source'),
      ]);
      final settlement = await money.settleInvoices(
        workspaceId: 'ch',
        memberId: 'buyer',
        invoiceIds: ['first-source', 'second-source'],
      );
      expect(
        money.invoices.firstWhere((i) => i.id == settlement).issuerName,
        issuer,
      );
    },
  );
}
