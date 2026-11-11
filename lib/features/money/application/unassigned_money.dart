// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-f -- money received and not assigned, as ONE answer: which
// payments of each customer no invoice has taken. The home's To-do, the
// reminder queue's "check first", the customer page and Payments to match all
// read this one answer, so they cannot disagree about who is matched first.
//
// What counts as consumed is said once too (`consumedPaymentIdsOf`): the
// payment a match remembers, every payment of an aggregate match (the
// junction, #506), and the credits moved to another member (#3349). The
// match dialog reads the same set.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:meta/meta.dart';

import '../domain/invoice_queries.dart';
import '../domain/ledger_entry.dart';
import 'credit_move_commands.dart';
import 'payment_candidates.dart';
import 'receivables.dart';

/// The payments no invoice may take again: the one each match remembers
/// ([matched]), every payment an aggregate match consumed ([junction]) and
/// the credits moved to another member ([moved]).
Set<String> consumedPaymentIdsOf({
  required Iterable<String?> matched,
  required Set<String> junction,
  required Set<String> moved,
}) => {for (final id in matched) ?id, ...junction, ...moved};

/// Reads the consumed payments of [workspaceId] (`consumedPaymentIdsOf`):
/// one read of the junction and one of the moved credits.
Future<Set<String>> readConsumedPaymentIds({
  required InvoiceQueries invoices,
  required CreditMoveCommands moves,
  required String workspaceId,
  required Iterable<String?> matched,
}) async => consumedPaymentIdsOf(
  matched: matched,
  junction: await invoices.fetchConsumedPaymentIds(workspaceId),
  moved: await moves.movedCreditIds(workspaceId),
);

/// The payments of each customer that no invoice has taken
/// (`unmatchedPaymentsOf`), from one read of the whole [ledger].
Map<String, List<LedgerEntry>> unassignedPaymentsByCustomer({
  required List<LedgerEntry> ledger,
  required Set<String> consumed,
  required List<Invoice> invoices,
}) {
  final byMember = <String, List<LedgerEntry>>{};
  for (final e in ledger) {
    (byMember[e.memberId] ??= []).add(e);
  }
  final invoicesOf = <String, List<Invoice>>{};
  for (final i in invoices) {
    (invoicesOf[i.memberId] ??= []).add(i);
  }
  return {
    for (final MapEntry(key: member, value: entries) in byMember.entries)
      if (unmatchedPaymentsOf(
            memberId: member,
            ledger: entries,
            consumed: consumed,
            invoices: invoicesOf[member] ?? const [],
          )
          case final free when free.isNotEmpty)
        member: free,
  };
}

/// One payment waiting for an invoice, with what it could settle.
typedef PaymentToMatch = ({
  String customerId,
  String customerName,
  LedgerEntry payment,
  List<MatchCandidate> candidates,
});

/// The answer: per customer, the payments no invoice has taken. The ledger
/// is kept in the business's [currency].
@immutable
class UnassignedMoney {
  const UnassignedMoney({required this.currency, required this.paymentsOf});

  final String currency;

  /// customer id -> their payments no invoice has taken, newest first; a
  /// customer who holds nothing is absent.
  final Map<String, List<LedgerEntry>> paymentsOf;

  /// What [customerId] holds, per currency; a customer who holds nothing
  /// holds zero (read, and nothing), never "not read".
  Map<String, int> creditOf(String customerId) => {
    currency: creditMinorOf(paymentsOf[customerId] ?? const []),
  };

  /// The customers of [receivables] who hold money not assigned in a
  /// currency they owe in (`holdsUnassignedMoney`).
  Set<String> holdersAmong(List<Receivable> receivables) => {
    for (final c in paymentsOf.keys)
      if (holdsUnassignedMoney(
        credit: creditOf(c),
        customerInvoices: receivables.where((r) => r.customerId == c),
      ))
        c,
  };

  /// Payments to match: the payments of exactly the customers
  /// [holdersAmong] selects (only [customerId] when given), each with the
  /// open invoices in the business's currency it could settle.
  List<PaymentToMatch> toMatch(
    List<Receivable> receivables, {
    String? customerId,
  }) {
    final rows = <PaymentToMatch>[];
    final byCustomer = <String, List<Receivable>>{};
    for (final r in receivables) {
      (byCustomer[r.customerId] ??= []).add(r);
    }
    final holders =
        [
          for (final c in holdersAmong(receivables))
            if (customerId == null || c == customerId) c,
        ]..sort(
          (a, b) => byCustomer[a]!.first.customerName.compareTo(
            byCustomer[b]!.first.customerName,
          ),
        );
    for (final c in holders) {
      final theirs = byCustomer[c]!;
      for (final payment in paymentsOf[c]!) {
        final candidates = candidatesFor(
          paymentMinor: payment.amountCents,
          currency: currency,
          customerInvoices: theirs,
        );
        if (candidates.isEmpty) continue;
        rows.add((
          customerId: c,
          customerName: theirs.first.customerName,
          payment: payment,
          candidates: candidates,
        ));
      }
    }
    return rows;
  }
}
