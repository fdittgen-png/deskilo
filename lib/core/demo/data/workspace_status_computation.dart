// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2327 — the demonstration's workspace status, computed from the fake's
// own invoices and ledger the way `workspace_status` (0167) computes them,
// so the demo's status agrees with its money pages instead of reading zero.
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/domain/workspace_status.dart';

import 'money_repository.dart';

WorkspaceStatus demoWorkspaceStatus(
  FakeMoneyRepository money,
  String from,
  String to,
) {
  final invoices = money.invoices;
  final ledger = money.ledger;
  bool inRange(String? period) =>
      period != null &&
      period.compareTo(from) >= 0 &&
      period.compareTo(to) <= 0;
  final counted = invoices.where(
    (i) =>
        i.voidedAt == null &&
        i.kind != InvoiceKind.settlement &&
        inRange(i.period),
  );
  int ledgerSum(
    LedgerKind kind,
    LedgerCategory? category, [
    String? memberId,
  ]) => ledger
      .where(
        (l) =>
            l.kind == kind &&
            (category == null || l.category == category) &&
            (memberId == null || l.memberId == memberId) &&
            inRange(l.period),
      )
      .fold(0, (sum, l) => sum + l.amountCents);
  String month(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';
  final names = <String, String>{
    for (final i in invoices) i.memberId: i.memberName,
  };
  final memberIds = {
    ...counted.map((i) => i.memberId),
    ...ledger.where((l) => inRange(l.period)).map((l) => l.memberId),
  }.toList()..sort();
  return WorkspaceStatus(
    from: from,
    to: to,
    currency: 'EUR',
    invoicedCents: counted
        .where((i) => i.totalCents > 0)
        .fold(0, (sum, i) => sum + i.totalCents),
    creditNotesCents: -counted
        .where((i) => i.totalCents < 0)
        .fold(0, (sum, i) => sum + i.totalCents),
    byKind: {for (final i in counted) i.kind.name: 0}
      ..updateAll(
        (kind, _) => counted
            .where((i) => i.kind.name == kind)
            .fold(0, (sum, i) => sum + i.totalCents),
      ),
    paymentsMatchedCents: money.invoiceMatchesStore.values
        .where((m) => inRange(month(m.matchedAt)))
        .fold(0, (sum, m) => sum + m.paidCents),
    paymentsReceivedCents: ledgerSum(LedgerKind.credit, LedgerCategory.payment),
    reimbursedCents: ledgerSum(LedgerKind.credit, LedgerCategory.expense),
    repartitionedCents: money.repartitions
        .where((r) => r.status == 'confirmed' && inRange(r.period))
        .fold(0, (sum, r) => sum + r.amountCents),
    creditsGrantedCents: ledgerSum(
      LedgerKind.credit,
      LedgerCategory.adjustment,
    ),
    members: [
      for (final id in memberIds)
        StatusMemberRow(
          memberId: id,
          name: names[id] ?? '',
          invoicedCents: counted
              .where((i) => i.memberId == id)
              .fold(0, (sum, i) => sum + i.totalCents),
          paidCents: ledgerSum(LedgerKind.credit, LedgerCategory.payment, id),
          reimbursedCents: ledgerSum(
            LedgerKind.credit,
            LedgerCategory.expense,
            id,
          ),
          creditsCents: ledgerSum(
            LedgerKind.credit,
            LedgerCategory.adjustment,
            id,
          ),
          chargedCents: ledgerSum(LedgerKind.charge, null, id),
        ),
    ],
  );
}
