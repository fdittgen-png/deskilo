// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3673 — what the customer statement prints, in one currency: the
// customer in the address window, the cutoff, each open document with its
// allocated parts under it and what is still due, the credits not yet
// applied, and the balance. Pure: the words live in the bands
// (report_defaults_customer_statement.dart) and the formats come in. No
// arithmetic happens here: every figure is the server's
// (customer_statement_v1).
library;

import 'customer_statement.dart';

/// How the document writes an amount (minor units of the statement's
/// currency) and a day, in the reader's locale.
typedef CustomerStatementFormats = ({
  String Function(int minor) money,
  String Function(DateTime day) date,
});

/// The data of [statement] for the `customer_statement` kind, for
/// [customerName] at [customerAddress], as of [asOf], under [letterhead]
/// (the space's name and address).
///
/// `rows` is one flat list, so the bands need no nested loop: a `document`
/// row, then its `part` rows, then its `due` row; then one `credit` row per
/// credit not yet applied.
Map<String, Object?> customerStatementReportData(
  StatementCurrency statement, {
  required String customerName,
  required String customerAddress,
  required DateTime asOf,
  required DateTime issued,
  required String issuedBy,
  required CustomerStatementFormats format,
  Map<String, Object?> letterhead = const {},
}) {
  String day(DateTime? d) => d == null ? '' : format.date(d);
  return {
    ...letterhead,
    'client_name': customerName,
    'client_address': customerAddress,
    'as_of': format.date(asOf),
    'issued': format.date(issued),
    'issued_by': issuedBy,
    'currency': statement.currency,
    'rows': [
      for (final line in statement.lines) ...[
        {
          'kind': 'document',
          'number': line.number,
          'issued': day(line.issuedAt),
          'due': day(line.dueOn),
          'amount': format.money(line.totalCents),
          'state': line.state.wire,
        },
        for (final part in line.allocations)
          {
            'kind': 'part',
            'on': day(part.on),
            'amount': format.money(part.amountCents),
            'waiting': part.awaitingApproval,
          },
        {
          'kind': 'due',
          'number': line.number,
          // A credit note's is owed by the business: its words say so,
          // the figure is its size.
          'amount': format.money(line.stillDueCents.abs()),
          'state': line.state.wire,
        },
      ],
      for (final credit in statement.credits)
        {
          'kind': 'credit',
          'label': credit.description,
          'on': day(credit.on),
          'amount': format.money(credit.leftCents),
        },
    ],
    'has_credits': statement.credits.isNotEmpty,
    'still_due_total': format.money(statement.stillDueCents),
    'unapplied_total': format.money(statement.unappliedCents),
    // The balance is said with who owes it; the figure is its size.
    'balance': format.money(statement.balanceCents.abs()),
    'balance_owed_by': switch (statement.balanceCents) {
      > 0 => 'customer',
      < 0 => 'business',
      _ => 'none',
    },
  };
}
