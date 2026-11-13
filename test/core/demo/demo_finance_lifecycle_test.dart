// SPDX-License-Identifier: AGPL-3.0-or-later
// Personal demo finance follows the invoice lifecycle: a confirmed write-off
// closes a debt, pending payment needs validation, and credits remain visible.
import 'package:deskilo/core/demo/demo_finance_projection.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Chiara\'s written-off seeded invoice is closed in My Space', () {
    final f = DemoFixture.build(now: DateTime.utc(2027, 2, 9, 10))
      ..becomePersona(DemoPersona.admin);
    const id = 'demo-usage-chiara-b';
    final match = f.money.invoiceMatchesStore[id]!;
    expect(match.resolution, 'under_accepted');
    expect(match.writeoffAt, isNotNull);
    final invoice = demoFinanceForUser(f.personalSpaces, f.auth.currentUserId).invoices
        .singleWhere((i) => i.id == id);
    expect(invoice.state, FinanceState.closed);
    expect(invoice.remainingCents, 0);
  });

  test(
    'personal invoices follow payment decisions, credits and regrouping',
    () {
      final f = DemoFixture.build(now: DateTime.utc(2027, 2, 9, 10));
      final original = f.money.invoices.first.copyWith(memberId: 'member-1');
      for (final space in f.personalSpaces) {
        space.money.invoices.clear();
        space.money.invoiceMatchesStore.clear();
      }
      final states = {
        'open': FinanceState.open,
        'pending': FinanceState.awaitingValidation,
        'partial': FinanceState.partiallyPaid,
        'written-off': FinanceState.closed,
        'paid': FinanceState.paid,
        'refunded': FinanceState.refunded,
        'credit': FinanceState.open,
        'settlement': FinanceState.open,
      };
      for (final id in states.keys) {
        f.money.invoices.add(
          original.copyWith(
            id: id,
            totalCents: id == 'credit' ? -200 : 1000,
            kind: id == 'settlement'
                ? InvoiceKind.settlement
                : InvoiceKind.full,
            settledByInvoiceId: null,
            voidedAt: null,
          ),
        );
      }
      for (final (id, resolution, paid, status) in [
        ('pending', 'exact', 1000, 'pending'),
        ('partial', 'under_accepted', 400, 'confirmed'),
        ('written-off', 'under_accepted', 400, 'confirmed'),
        ('paid', 'exact', 1000, 'confirmed'),
        ('refunded', 'refunded', 1000, 'confirmed'),
      ]) {
        f.money.invoiceMatchesStore[id] = InvoiceMatch(
          invoiceId: id,
          paidCents: paid,
          resolution: resolution,
          status: status,
          matchedAt: f.seededAt,
          writeoffAt: id == 'written-off' ? f.seededAt : null,
        );
      }
      f.money.invoices.addAll([
        original.copyWith(id: 'void', voidedAt: f.seededAt),
        original.copyWith(id: 'regrouped', settledByInvoiceId: 'settlement'),
        original.copyWith(id: 'other-person', memberId: 'member-2'),
      ]);

      final result = demoFinanceForUser(f.personalSpaces, f.auth.currentUserId);
      expect({for (final i in result.invoices) i.id: i.state}, states);
      expect(result.owedByCurrency, {'EUR': 2400});
      expect(result.beingValidatedByCurrency, {'EUR': 1000});
    },
  );

  test('one user can own different membership ids across workspaces', () {
    final f = DemoFixture.build();
    final city = f.london.workspaces;
    final before = city.myMember;
    expect(before.userId, f.auth.currentUserId);
    city.myMember = before.copyWith(id: 'london-local-owner');
    for (var n = 0; n < f.london.money.invoices.length; n++) {
      final invoice = f.london.money.invoices[n];
      if (invoice.memberId == before.id) {
        f.london.money.invoices[n] = invoice.copyWith(
          memberId: city.myMember.id,
        );
      }
    }
    final expected = f.london.money.invoices
        .where(
          (i) =>
              i.memberId == city.myMember.id &&
              !i.isVoided &&
              i.settledByInvoiceId == null,
        )
        .map((i) => i.id)
        .toSet();
    final actual = demoFinanceForUser(f.personalSpaces, f.auth.currentUserId).invoices
        .where((i) => i.workspaceId == city.myMember.workspaceId)
        .map((i) => i.id)
        .toSet();
    expect(expected, isNotEmpty);
    expect(actual, expected);
  });
}
