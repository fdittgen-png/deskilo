// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3673 — the customer statement's golden, in two languages (fr, de) and two
// currencies (EUR, and JPY, which has no decimals). The data map is written
// by customerStatementReportData from one statement: a part-paid invoice
// with its payment part, one awaiting approval, a credit note, a payment
// not yet applied. A golden changes only when the document is MEANT to
// change: regenerate with --dart-define=WRITE_GOLDEN=true and say so.
// The bands are then rendered in the same language: each line's words are
// there, and nothing is computed on the way (the figures are the server's).
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/money/domain/customer_statement.dart';
import 'package:deskilo/features/money/domain/customer_statement_report.dart';
import 'package:deskilo/features/money/domain/invoice_report.dart';
import 'package:deskilo/features/money/presentation/report_defaults_customer_statement.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo/l10n/app_localizations_de.dart';
import 'package:deskilo/l10n/app_localizations_fr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const _write = bool.fromEnvironment('WRITE_GOLDEN');

final _day = DateTime(2026, 10);

/// One statement in [currency], its amounts scaled by [unit] (100 for the
/// euro's cents, 1 for the yen).
StatementCurrency _statement(String currency, int unit) => StatementCurrency(
  currency: currency,
  stillDueCents: 75 * unit,
  unappliedCents: 10 * unit,
  balanceCents: 65 * unit,
  lines: [
    StatementLine(
      invoiceId: 'a',
      number: 'F-2026-0101',
      totalCents: 100 * unit,
      stillDueCents: 60 * unit,
      state: StatementLineState.partlyPaid,
      issuedAt: DateTime(2026, 9, 2),
      dueOn: DateTime(2026, 10, 2),
      allocations: [
        StatementAllocation(
          paymentId: 'p',
          amountCents: 40 * unit,
          on: DateTime(2026, 9, 20),
        ),
      ],
    ),
    StatementLine(
      invoiceId: 'c',
      number: 'F-2026-0103',
      totalCents: 30 * unit,
      stillDueCents: 30 * unit,
      state: StatementLineState.awaitingApproval,
      issuedAt: DateTime(2026, 9, 5),
      allocations: [
        StatementAllocation(
          paymentId: 'q',
          amountCents: 30 * unit,
          on: DateTime(2026, 9, 25),
          awaitingApproval: true,
        ),
      ],
    ),
    StatementLine(
      invoiceId: 'd',
      number: 'AV-2026-0004',
      totalCents: -15 * unit,
      stillDueCents: -15 * unit,
      state: StatementLineState.creditNote,
      issuedAt: DateTime(2026, 9, 8),
    ),
  ],
  credits: [
    StatementCredit(
      ledgerId: 'p',
      leftCents: 10 * unit,
      category: 'payment',
      description: 'Virement septembre',
      on: DateTime(2026, 9, 20),
    ),
  ],
);

Map<String, Object?> _data(String currency, int unit, String locale) =>
    customerStatementReportData(
      _statement(currency, unit),
      StatementLetter(
        customerName: 'Ana Martin',
        customerAddress: '12 rue des Lilas\n75011 Paris',
        issued: _day,
        issuedBy: 'Camille Owner',
        letterhead: const {
          'workspace': 'Test Space',
          'workspace_address': '1 place du Marché\n69001 Lyon',
        },
      ),
      asOf: _day,
      locale: locale,
    );

/// The report's words, one block per line.
String _words(InvoiceReport report) => [
  for (final b in [...report.header, ...report.body, ...report.footer])
    switch (b) {
      ReportHeading(:final text) ||
      ReportSubheading(:final text) ||
      ReportText(:final text) ||
      ReportMuted(:final text) => text,
      ReportTableRow(:final cells) => cells.join(' | '),
      _ => '',
    },
].join('\n');

void main() {
  setUpAll(initializeDateFormatting);
  final words = <String, AppLocalizations>{
    'fr': AppLocalizationsFr(),
    'de': AppLocalizationsDe(),
  };

  for (final locale in words.keys) {
    for (final (currency, unit) in const [('EUR', 100), ('JPY', 1)]) {
      final name =
          'customer_statement_report_data_${locale}_${currency.toLowerCase()}';
      test('$name is byte-identical to its golden', () {
        final encoded = const JsonEncoder.withIndent('  ')
            .convert(_data(currency, unit, locale));
        final file = File('test/features/money/goldens/$name.json');
        if (_write) {
          file.writeAsStringSync('$encoded\n');
          return;
        }
        expect(encoded, file.readAsStringSync().trimRight());
      });
    }

    test('the $locale bands say what each line is, in $locale', () {
      final l10n = words[locale]!;
      final report = renderReportBands(
        bands: customerStatementBands(l10n),
        data: _data('EUR', 100, locale),
      )!;
      final text = _words(report);
      expect(text, contains('F-2026-0101'));
      expect(text, contains(l10n.customerStatementStillDue));
      expect(text, contains(l10n.customerStatementOwedToYou));
      expect(text, contains(l10n.customerStatementAwaiting));
      expect(text, contains(l10n.customerStatementUnapplied));
      expect(text, contains(l10n.customerStatementBalanceDue));
      expect(text, isNot(contains('{{')));
    });
  }

  test('the yen keeps no decimals and the euro two', () {
    expect(_data('JPY', 1, 'fr')['balance'], isNot(contains(',')));
    expect(_data('EUR', 100, 'fr')['balance'], contains('65,00'));
  });
}
