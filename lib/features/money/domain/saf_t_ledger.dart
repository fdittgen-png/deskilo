// SPDX-License-Identifier: AGPL-3.0-or-later
import 'invoice.dart';
import 'invoice_line_cash.dart';
import 'posting.dart';

/// The four accounts the derived postings book to (#669).
///
/// Deliberately the same four the FEC, DATEV and Sage ask for, because
/// they are the same four postings — one mapping, asked for once, and no
/// second opinion about which account revenue lands in.
class SafTLedgerAccounts {
  const SafTLedgerAccounts({
    required this.customers,
    required this.revenue,
    required this.bank,
    required this.vat,
    this.writeOff = '',
  });

  final String customers;
  final String revenue;
  final String bank;
  final String vat;

  /// #2365 -- the loss account of a written-off rest; empty means unmapped,
  /// and then no write-off is posted (an invented account would look complete).
  final String writeOff;
}

/// One posting line of a SAF-T ledger transaction. Exactly one of
/// [debit] and [credit] is positive.
class SafTLedgerLine {
  const SafTLedgerLine(this.account, this.debit, this.credit, this.text);

  final String account;
  final int debit;
  final int credit;
  final String text;
}

/// One SAF-T ledger transaction (#669): a journal entry that balances by
/// construction, so the totals the file states before its entries are the
/// sums of the lines written after them.
class SafTLedgerTransaction {
  const SafTLedgerTransaction({
    required this.id,
    required this.date,
    required this.description,
    required this.lines,
  });

  final String id;
  final DateTime date;
  final String description;
  final List<SafTLedgerLine> lines;

  int get debitTotal => lines.fold(0, (s, l) => s + l.debit);
  int get creditTotal => lines.fold(0, (s, l) => s + l.credit);
}

/// The sales journal. An invoice debits the customers at what it charges
/// and credits revenue net of tax with the VAT beside it, one pair per
/// rate. A credit note (#2365) is the same sale reversed: revenue and VAT
/// debited, the customers credited the sum, every amount positive.
List<SafTLedgerTransaction> safTSalesTransactions(
  Iterable<Invoice> invoices,
  SafTLedgerAccounts accounts,
) => [
  for (final invoice in invoices)
    if (invoice.isCreditNote)
      _creditNote(invoice, accounts)
    else
      SafTLedgerTransaction(
        id: invoice.number,
        date: invoice.issuedAt,
        description: invoice.title,
        lines: [
          SafTLedgerLine(
            accounts.customers,
            invoice.chargesCents,
            0,
            invoice.number,
          ),
          if (invoice.vatTotals.isEmpty)
            SafTLedgerLine(
              accounts.revenue,
              0,
              invoice.chargesCents,
              invoice.number,
            )
          else
            for (final total in invoice.vatTotals) ...[
              SafTLedgerLine(
                accounts.revenue,
                0,
                total.netCents,
                invoice.number,
              ),
              if (total.vatCents > 0)
                SafTLedgerLine(accounts.vat, 0, total.vatCents, invoice.number),
            ],
        ],
      ),
];

SafTLedgerTransaction _creditNote(Invoice invoice, SafTLedgerAccounts a) {
  final debits = <SafTLedgerLine>[
    if (invoice.vatTotals.isEmpty)
      SafTLedgerLine(a.revenue, -invoice.totalCents, 0, invoice.number)
    else
      for (final total in invoice.vatTotals) ...[
        if (total.netCents != 0)
          SafTLedgerLine(a.revenue, total.netCents.abs(), 0, invoice.number),
        if (total.vatCents != 0)
          SafTLedgerLine(a.vat, total.vatCents.abs(), 0, invoice.number),
      ],
  ];
  final sum = debits.fold(0, (s, l) => s + l.debit);
  return SafTLedgerTransaction(
    id: invoice.number,
    date: invoice.issuedAt,
    description: invoice.title,
    lines: [...debits, SafTLedgerLine(a.customers, 0, sum, invoice.number)],
  );
}

/// The money the invoices themselves netted (#2365): each credit line that
/// is cash (`isMoneyIn`) is a receipt on the invoice's date — bank debited,
/// customers credited — exactly as the FEC's bank journal books it.
List<SafTLedgerTransaction> safTNettedReceipts(
  Iterable<Invoice> invoices,
  SafTLedgerAccounts accounts,
) => [
  for (final invoice in invoices)
    if (!invoice.isCreditNote)
      for (final (i, line) in invoice.lines.where((l) => l.isMoneyIn).indexed)
        SafTLedgerTransaction(
          id: '${invoice.number}-C${i + 1}',
          date: invoice.issuedAt,
          description: 'Payment ${invoice.number}',
          lines: [
            SafTLedgerLine(accounts.bank, -line.amountCents, 0, invoice.number),
            SafTLedgerLine(
              accounts.customers,
              0,
              -line.amountCents,
              invoice.number,
            ),
          ],
        ),
];

/// The bank journal's settlements. Dated when the money MOVED (0070), not
/// when it was recorded, or the ledger disagrees with the bank statement it
/// is reconciled against. #2365 -- a refunded credit note is money OUT: the
/// receivable it opened is cleared against the bank, the other way round.
List<SafTLedgerTransaction> safTSettlements(
  Iterable<({Invoice invoice, InvoiceMatch match})> settled,
  SafTLedgerAccounts accounts,
) => [
  for (final e in settled)
    SafTLedgerTransaction(
      id: '${e.invoice.number}-P',
      date: e.match.matchedAt,
      description: refundedCents(e.invoice, e.match) > 0
          ? 'Refund ${e.invoice.number}'
          : 'Payment ${e.invoice.number}',
      lines: refundedCents(e.invoice, e.match) > 0
          ? [
              SafTLedgerLine(
                accounts.customers,
                e.match.paidCents,
                0,
                e.invoice.number,
              ),
              SafTLedgerLine(
                accounts.bank,
                0,
                e.match.paidCents,
                e.invoice.number,
              ),
            ]
          : [
              SafTLedgerLine(
                accounts.bank,
                e.match.paidCents,
                0,
                e.invoice.number,
              ),
              SafTLedgerLine(
                accounts.customers,
                0,
                e.match.paidCents,
                e.invoice.number,
              ),
            ],
    ),
];

/// #2365 -- what the owner gave up of an invoice: the unpaid rest leaves the
/// customers for the loss account, on the write-off day, at the gross amount.
/// Without a mapped loss account nothing is posted.
List<SafTLedgerTransaction> safTWriteOffs(
  Iterable<({Invoice invoice, InvoiceMatch match})> settled,
  SafTLedgerAccounts accounts,
) => [
  if (accounts.writeOff.isNotEmpty)
    for (final e in settled)
      if (e.match.writeoffAt case final day? when e.invoice.totalCents > e.match.paidCents)
        SafTLedgerTransaction(
          id: '${e.invoice.number}-W',
          date: day,
          description: 'Write-off ${e.invoice.number}',
          lines: [
            SafTLedgerLine(accounts.writeOff, e.invoice.totalCents - e.match.paidCents, 0, e.invoice.number),
            SafTLedgerLine(accounts.customers, 0, e.invoice.totalCents - e.match.paidCents, e.invoice.number),
          ],
        ),
];

const _postedJournalNames = {
  PostingJournal.sales: 'Sales',
  PostingJournal.bank: 'Bank',
  PostingJournal.purchases: 'Purchases',
  PostingJournal.other: 'Other operations',
};

/// #2365 — a local book's postings (`compute_postings`) as SAF-T journals,
/// in the engine's order: every journal it booked, one transaction per
/// posting, its lines on the book's own accounts. A transaction is named by
/// the document it books, `-2`, `-3`... for a second one in the journal.
List<(String id, String name, List<SafTLedgerTransaction> transactions)>
safTPostedJournals(List<Posting> postings) {
  final seen = <String, int>{};
  return [
    for (final journal in PostingJournal.values)
      if (postings.any((p) => p.journal == journal))
        (
          journal.code,
          _postedJournalNames[journal]!,
          [
            for (final p in postings)
              if (p.journal == journal)
                SafTLedgerTransaction(
                  id: () {
                    final base = '${journal.code}-${p.documentNumber}';
                    final n = seen[base] = (seen[base] ?? 0) + 1;
                    return n == 1 ? base : '$base-$n';
                  }(),
                  date: p.date,
                  description: '${p.kind.wire} ${p.documentNumber}',
                  lines: [
                    for (final l in p.lines)
                      SafTLedgerLine(
                        l.accountCode,
                        l.debit.minor,
                        l.credit.minor,
                        l.role.wire,
                      ),
                  ],
                ),
          ],
        ),
  ];
}
