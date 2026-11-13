// SPDX-License-Identifier: AGPL-3.0-or-later
// The commercial examples are operable through the same ports as the screens:
// approval creates a supplier payable; a confirmed sale is invoiced and paid.
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_link.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/events/providers/event_providers.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/providers/customer_statement_providers.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final (slug, id, prefix, currency, percent) in [
    ('zurich', 'ws-5', 'ch', 'CHF', 8.1),
    ('milan', 'ws-6', 'it', 'EUR', 22.0),
  ]) {
    test('$slug enters commerce and completes a purchase and a sale', () async {
      final fixture = DemoFixture.build(now: DateTime.utc(2027, 1, 18, 10));
      final country = slug == 'zurich' ? fixture.zurich : fixture.milan;
      final other = slug == 'zurich' ? fixture.milan : fixture.zurich;
      final otherInvoices = other.money.invoices.length;
      final otherLedger = other.money.ledger.length;
      final container = ProviderContainer(overrides: demoOverrides(fixture))
        ..listen(currentWorkspaceProvider, (_, _) {});
      addTearDown(container.dispose);
      await container.read(currentWorkspaceProvider.future);
      await container.read(activeWorkspaceIdProvider.notifier).select(id);
      await container.read(currentWorkspaceProvider.future);
      container.listen(myPermissionsProvider, (_, _) {});
      await container.read(myMemberProvider.future);
      expect(container.read(enabledFeaturesSyncProvider),
        isNot(contains(WorkspaceFeature.placeBooking)));
      final link = DemoLink.parse({'space': slug});
      expect(link.workspaceId, id);
      expect(link.to, slug == 'zurich' ? '/money/purchases' : '/invoices');
      expect(DemoLink.parse(link.toQuery()).toQuery(), link.toQuery());

      final purchases = container.read(purchaseRepositoryProvider);
      final pending = await purchases.fetchDetail(id, '$prefix-bill-pending');
      expect(pending.summary.currency, currency);
      expect(pending.lines.single.taxRatePercent, percent);
      expect(pending.lines.single.description, 'Stationery sets restock');
      expect(pending.lines.single.serviceId, '$prefix-service-3');
      expect(country.money.services[3].name, 'Stationery sets');
      expect(country.money.services.first.name, 'Postcard sets');
      await purchases.decideBill(id, pending.summary.id, pending.revision,
        approve: true, reason: '', requestId: '$id-approve');
      final approved = await purchases.fetchDetail(id, pending.summary.id);
      final payable = approved.obligations.single;
      expect(payable.creditorId, '$prefix-stock');
      final paid = await purchases.recordReimbursement(id, ReimbursementCommand(
        obligationId: payable.id, amountCents: payable.remainingCents,
        revision: payable.revision, requestId: '$id-pay',
        creditorKind: CreditorKind.supplier, paidOn: fixture.seededAt,
        reference: 'Demo supplier transfer'));
      expect(paid.remainingCents, 0);
      expect(paid.paidCents, pending.grossCents);
      final foreign = await purchases.fetchDetail(id, '$prefix-bill-foreign');
      expect(foreign.summary.currency, currency == 'CHF' ? 'EUR' : 'CHF');
      expect(await purchases.fetchExchangeRate(id, foreign.summary.id), isNotNull);

      Future<void> viewAs(DemoPersona persona) async {
        fixture.becomePersona(persona);
        await pumpEventQueue();
        await container.read(activeWorkspaceIdProvider.future);
        await container.read(activeWorkspaceIdProvider.notifier).select(id);
        expect((await container.read(currentWorkspaceProvider.future))?.id, id);
        container.invalidate(myMemberProvider);
        await container.read(myMemberProvider.future);
        expect(container.read(moneyRepositoryProvider), same(country.money));
      }
      await viewAs(DemoPersona.member);
      final accounts = container.read(memberAccountCommandsProvider);
      final events = container.read(eventRepositoryProvider);
      final period = yearMonth(fixture.seededAt.year, fixture.seededAt.month);
      final service = country.money.services.first;
      await accounts.recordServiceCharge(workspaceId: id,
        subjectMemberId: 'member-2', serviceId: service.id, quantity: 2,
        period: period);
      final charge = country.events.events.last;
      expect(charge.status, EventStatus.pending);
      await viewAs(DemoPersona.owner);
      await events.respond(charge.id, accept: true);
      final invoices = container.read(invoiceCommandsProvider);
      final invoiceId = await invoices.createInvoice(workspaceId: id,
        memberId: 'member-2', period: period);
      final invoice = country.money.invoices.singleWhere((i) => i.id == invoiceId);
      expect(invoice.currency, currency);
      expect(invoice.memberName, country.workspaces.memberNames['member-2']);
      expect(invoice.workspaceName, country.spec.name);
      expect(invoice.sellerParty?.country, country.spec.country);
      expect(invoice.issuerName, country.workspaces.memberNames['member-1']);
      expect(invoice.issuedAt, fixture.seededAt);
      expect(invoice.lines.every((line) => line.vatPercent == percent), isTrue);
      final statement = await container.read(customerStatementReaderProvider)
        .read(id, 'member-2', fixture.seededAt);
      expect(statement.currencies.expand((c) => c.lines)
        .map((line) => line.invoiceId), contains(invoice.id));
      expect(statement.currencies.map((c) => c.currency).toSet(), {currency});
      await viewAs(DemoPersona.member);
      final payment = await accounts.recordPayment(workspaceId: id,
        memberId: 'member-2', amountCents: invoice.totalCents,
        paidOn: fixture.seededAt, period: period);
      await viewAs(DemoPersona.owner);
      await events.respond(payment, accept: true);
      final credit = country.money.ledger.lastWhere((e) =>
        e.memberId == 'member-2' && e.kind == LedgerKind.credit &&
        e.category == LedgerCategory.payment);
      final applied = await invoices.applyPaymentToInvoices(workspaceId: id,
        paymentLedgerId: credit.id,
        allocations: [(invoiceId: invoice.id, amountCents: invoice.totalCents)]);
      expect(applied.leftCents, 0);
      expect(country.money.invoiceMatchesStore[invoice.id]?.paidCents,
        invoice.totalCents);
      expect(other.money.invoices, hasLength(otherInvoices));
      expect(other.money.ledger, hasLength(otherLedger));
    });
  }
}
