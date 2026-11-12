// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3673 — what the customer statement prints, in one currency: the
// customer in the address window, the cutoff, each open document with its
// allocated parts under it and what is still due, the credits not yet
// applied, and the balance. Pure: the words live in the bands
// (report_defaults_customer_statement.dart), amounts and days are written
// in the reader's locale. No
// arithmetic happens here: every figure is the server's
// (customer_statement_v1).
library;

import 'package:intl/intl.dart';

import '../../../core/i18n/money_format.dart';
import 'customer_statement.dart';

/// Who the statement is for and who issues it: the customer in the
/// address window, the day and the person issuing, and the [letterhead]
/// (the space's name and address).
class StatementLetter {
  const StatementLetter({
    required this.customerName,
    required this.customerAddress,
    required this.issued,
    required this.issuedBy,
    this.letterhead = const {},
  });

  final String customerName;
  final String customerAddress;
  final DateTime issued;
  final String issuedBy;
  final Map<String, Object?> letterhead;
}

/// The data of [statement] for the `customer_statement` kind, addressed by
/// [letter], as of [asOf], with amounts and days written in [locale] and
/// the statement's own currency.
///
/// `rows` is one flat list, so the bands need no nested loop: a `document`
/// row, then its `part` rows, then its `due` row; then one `credit` row per
/// credit not yet applied.
Map<String, Object?> customerStatementReportData(
  StatementCurrency statement,
  StatementLetter letter, {
  required DateTime asOf,
  required String locale,
}) {
  final format = (
    money: moneyFormat(statement.currency, locale: locale).formatMinor,
    date: DateFormat.yMMMd(locale).format,
  );
  String day(DateTime? d) => d == null ? '' : format.date(d);
  return {
    ...letter.letterhead,
    'client_name': letter.customerName,
    'client_address': letter.customerAddress,
    'as_of': format.date(asOf),
    'issued': format.date(letter.issued),
    'issued_by': letter.issuedBy,
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
