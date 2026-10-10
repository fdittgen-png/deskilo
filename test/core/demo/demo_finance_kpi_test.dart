// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The demo's Activity analysis sums its own invoices and matches with
// the predicates of kpi_finance_summary (0351), instead of answering
// "no server in this mode": void and settlement invoices left out,
// credit notes named apart, collected by the month of the match.
import 'package:deskilo/core/demo/data/finance_kpi_repository.dart';
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/core/demo/data/workspace_repository.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/workspace/domain/kpi_contract.dart';
import 'package:flutter_test/flutter_test.dart';

Invoice _invoice(
  String id,
  String period,
  int cents, {
  DateTime? voidedAt,
  InvoiceKind kind = InvoiceKind.full,
}) => Invoice(
  id: id,
  workspaceId: 'ws-1',
  memberId: 'member-1',
  number: 'INV-$id',
  issuedAt: DateTime(2026, 4, 2),
  period: period,
  title: period,
  lines: const [],
  totalCents: cents,
  currency: 'EUR',
  memberName: 'Ana Martin',
  memberAddress: '',
  workspaceName: 'Test Space',
  workspaceAddress: '',
  issuerName: 'Flo',
  signature: 'f' * 64,
  voidedAt: voidedAt,
  kind: kind,
);

InvoiceMatch _match(
  String invoiceId,
  int cents,
  DateTime on, {
  String? ledger,
}) => InvoiceMatch(
  invoiceId: invoiceId,
  paidCents: cents,
  resolution: 'exact',
  paymentLedgerId: ledger,
  matchedAt: on,
);

void main() {
  test('sums the months with the server predicates', () async {
    final money = FakeMoneyRepository()
      ..invoices.addAll([
        _invoice('a', '2026-03', 10000),
        _invoice('b', '2026-03', 5000),
        _invoice('void', '2026-03', 7000, voidedAt: DateTime(2026, 3, 9)),
        _invoice('settle', '2026-03', 15000, kind: InvoiceKind.settlement),
        _invoice('credit', '2026-03', -2500),
        _invoice('april', '2026-04', 9900),
      ])
      ..invoiceMatchesStore.addAll({
        'a': _match('a', 10000, DateTime(2026, 3, 20, 12), ledger: 'p-a'),
        // Matched in April: collected in April, not in March.
        'b': _match('b', 5000, DateTime(2026, 4, 2, 12), ledger: 'p-b'),
        // A refunded credit note consumed no payment.
        'credit': _match('credit', 2500, DateTime(2026, 3, 21, 12)),
      });
    final repo = DemoFinanceKpiRepository(
      money: money,
      workspaces: FakeWorkspaceRepository.withWorkspace(),
      now: DateTime(2026, 5, 13, 10),
    );

    final march = await repo.summary(
      'ws-1',
      fromMonth: '2026-03',
      toMonth: '2026-03',
    );
    expect(march.currency, 'EUR');
    expect(march.invoicedMinor, 15000);
    expect(march.invoices, 2);
    expect(march.creditNotesMinor, 2500);
    expect(march.collectedMinor, 10000);
    expect(march.matches, 1);
    expect(march.quality, isEmpty, reason: 'March is over');

    final april = await repo.summary(
      'ws-1',
      fromMonth: '2026-04',
      toMonth: '2026-05',
    );
    expect(april.invoicedMinor, 9900);
    expect(april.collectedMinor, 5000);
    expect(april.quality, {KpiQuality.partial});
    expect(april.reasons, ['period_not_over']);
  });

  test('the seeded demo has figures to show', () async {
    final fixture = DemoFixture.build();
    final repo = DemoFinanceKpiRepository(
      money: fixture.money,
      workspaces: fixture.workspaces,
      now: fixture.seededAt,
    );
    final last = DateTime(fixture.seededAt.year, fixture.seededAt.month - 1);
    final month = '${last.year}-${last.month.toString().padLeft(2, '0')}';
    final k = await repo.summary(
      fixture.workspaces.workspaces.first.id,
      fromMonth: month,
      toMonth: month,
    );
    expect(k.invoicedMinor, greaterThan(0));
    expect(k.collectedMinor, greaterThan(0));
    expect(k.quality, isNot(contains(KpiQuality.unavailable)));
  });
}
