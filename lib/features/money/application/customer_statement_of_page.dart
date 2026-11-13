// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3673, #3840 — the customer statement from the receivables and the
// unassigned payments of one customer, for the Demo, which has no server to
// answer customer_statement_v1. The customer page does not use it: the page
// reads the server's snapshot (customerStatementProvider), the Demo answers
// the same snapshot from here. Allocation detail is the server's; this side
// names the documents and the credits, not the parts.
import '../domain/customer_statement.dart';
import 'payment_candidates.dart';
import 'receivables.dart';

export '../domain/customer_statement.dart';

/// [customerId]'s statement as of [asOf], from the page's [receivables] and
/// the [unassigned] payments of that customer, which the ledger keeps in
/// [ledgerCurrency]. One statement per currency, by code.
CustomerStatement customerStatementOfPage({
  required String customerId,
  required DateTime asOf,
  required Iterable<Receivable> receivables,
  required Iterable<PaymentLeft> unassigned,
  required String ledgerCurrency,
}) {
  final lines = <String, List<StatementLine>>{};
  for (final r in receivables) {
    if (r.customerId != customerId || r.openMinor == 0) continue;
    final state = switch (r.stage) {
      ReceivableStage.refundOwed => StatementLineState.creditNote,
      ReceivableStage.open when r.awaitingSecondApproval =>
        StatementLineState.awaitingApproval,
      ReceivableStage.open => StatementLineState.open,
      ReceivableStage.partlyPaid => StatementLineState.partlyPaid,
      _ => null,
    };
    if (state == null) continue;
    (lines[r.currency] ??= []).add(
      StatementLine(
        invoiceId: r.invoiceId,
        number: r.number,
        totalCents: r.totalMinor,
        stillDueCents: state == StatementLineState.creditNote
            ? -r.openMinor
            : r.openMinor,
        state: state,
        issuedAt: r.issuedOn,
        dueOn: r.dueOn,
      ),
    );
  }
  final credits = [
    for (final p in unassigned)
      if (p.entry.memberId == customerId && p.leftCents > 0)
        StatementCredit(
          ledgerId: p.entry.id,
          leftCents: p.leftCents,
          category: p.entry.category.name,
          description: p.entry.description,
          on: p.entry.on,
        ),
  ];
  return CustomerStatement(
    memberId: customerId,
    asOf: asOf,
    currencies: statementCurrencies(
      lines: lines,
      credits: {if (credits.isNotEmpty) ledgerCurrency: credits},
    ),
  );
}
