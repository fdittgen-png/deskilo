// SPDX-License-Identifier: AGPL-3.0-or-later
import 'invoice.dart';
import 'invoice_line_cash.dart';

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
  });

  final String customers;
  final String revenue;
  final String bank;
  final String vat;
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
