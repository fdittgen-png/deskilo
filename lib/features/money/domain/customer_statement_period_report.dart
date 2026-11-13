// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3839 — what the period statement prints, in one currency: the customer
// in the address window, the period, the opening balance, each movement on
// the day it counted (with its own day when that differs), and the closing
// balance with who owes it; a period without a movement says so, and a
// period before the match history says its earlier balances are
// reconstructed. Pure: the words live in the bands
// (report_defaults_customer_statement.dart), amounts and days are written
// in the reader's locale, and every figure is the server's
// (customer_statement_period_v1).
library;

import 'package:intl/intl.dart';

import '../../../core/i18n/money_format.dart';
import 'customer_statement_period.dart';
import 'customer_statement_report.dart';

/// The data of [statement] for the `customer_statement_period` kind,
/// addressed by [letter], over [period], with amounts and days written in
/// [locale] and the statement's own currency.
Map<String, Object?> customerStatementPeriodReportData(
  PeriodCurrency statement,
  StatementLetter letter, {
  required CustomerStatementPeriod period,
  required String locale,
}) {
  final money = moneyFormat(statement.currency, locale: locale).formatMinor;
  final date = DateFormat.yMMMd(locale).format;
  String owedBy(int cents) => switch (cents) {
    > 0 => 'customer',
    < 0 => 'business',
    _ => 'none',
  };
  return {
    ...letter.letterhead,
    'client_name': letter.customerName,
    'client_address': letter.customerAddress,
    'from': date(period.from),
    'to': date(period.to),
    'issued': date(letter.issued),
    'issued_by': letter.issuedBy,
    'currency': statement.currency,
    'reconstructed': period.reconstructedBefore,
    'history_from': switch (period.historyFrom) {
      final from? => date(from),
      null => '',
    },
    // A balance is said with who owes it; the figure is its size.
    'opening': money(statement.openingCents.abs()),
    'opening_owed_by': owedBy(statement.openingCents),
    'rows': [
      for (final m in statement.movements)
        {
          'on': date(m.decidedOn),
          'what': m.what.wire,
          'label': m.label,
          'own': m.datedApart ? date(m.ownOn!) : '',
          'amount': money(m.amountCents),
        },
    ],
    'no_movement': statement.movements.isEmpty,
    'closing': money(statement.closingCents.abs()),
    'closing_owed_by': owedBy(statement.closingCents),
  };
}
