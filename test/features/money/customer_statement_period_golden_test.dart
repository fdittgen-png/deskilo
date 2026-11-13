// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3839 — the period statement's golden, in two languages (fr, de) and two
// currencies (EUR, and JPY, which has no decimals). The data map is written
// by customerStatementPeriodReportData from one period: an invoice, a
// payment, its allocation, and the approval that counted in the period with
// the payment's own date on its line; the period starts before the match
// history, so it says its earlier balances are reconstructed. A golden
// changes only when the document is MEANT to change: regenerate with
// --dart-define=WRITE_GOLDEN=true and say so. The bands are then rendered in
// the same language: each line's words are there, and nothing is computed
// on the way (the figures are the server's).
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/money/domain/customer_statement_period.dart';
import 'package:deskilo/features/money/domain/customer_statement_period_report.dart';
import 'package:deskilo/features/money/domain/customer_statement_report.dart';
import 'package:deskilo/features/money/domain/invoice_report.dart';
import 'package:deskilo/features/money/presentation/report_defaults_customer_statement.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo/l10n/app_localizations_de.dart';
import 'package:deskilo/l10n/app_localizations_fr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const _write = bool.fromEnvironment('WRITE_GOLDEN');

final _day = DateTime(2026, 11, 2);

CustomerStatementPeriod _period(List<PeriodCurrency> currencies) =>
    CustomerStatementPeriod(
      memberId: 'm',
      from: DateTime(2026, 10),
      to: DateTime(2026, 10, 31),
      historyFrom: DateTime(2026, 10, 12),
      reconstructedBefore: true,
      currencies: currencies,
    );

/// One period in [currency], its amounts scaled by [unit] (100 for the
/// euro's cents, 1 for the yen).
PeriodCurrency _statement(String currency, int unit) => PeriodCurrency(
  currency: currency,
  openingCents: 20 * unit,
  closingCents: 20 * unit,
  movements: [
    PeriodMovement(
      decidedOn: DateTime(2026, 10, 3),
      ownOn: DateTime(2026, 10, 3),
      label: 'F-2026-0110',
      what: PeriodMovementWhat.invoice,
      amountCents: 100 * unit,
    ),
    PeriodMovement(
      decidedOn: DateTime(2026, 10, 28),
      ownOn: DateTime(2026, 10, 28),
      label: 'Virement octobre',
      what: PeriodMovementWhat.payment,
      amountCents: -100 * unit,
    ),
    PeriodMovement(
      decidedOn: DateTime(2026, 10, 29),
      ownOn: DateTime(2026, 10, 28),
      label: 'Virement octobre',
      what: PeriodMovementWhat.allocated,
      amountCents: 100 * unit,
    ),
    PeriodMovement(
      decidedOn: DateTime(2026, 10, 30),
      ownOn: DateTime(2026, 10, 28),
      label: 'F-2026-0110',
      what: PeriodMovementWhat.paid,
      amountCents: -100 * unit,
    ),
  ],
);

Map<String, Object?> _data(PeriodCurrency statement, String locale) =>
    customerStatementPeriodReportData(
      statement,
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
      period: _period([statement]),
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
          'customer_statement_period_report_data_${locale}_${currency.toLowerCase()}';
      test('$name is byte-identical to its golden', () {
        final encoded = const JsonEncoder.withIndent('  ')
            .convert(_data(_statement(currency, unit), locale));
        final file = File('test/features/money/goldens/$name.json');
        if (_write) {
          file.writeAsStringSync('$encoded\n');
          return;
        }
        expect(encoded, file.readAsStringSync().trimRight());
      });
    }

    test('the $locale bands say what each movement is, in $locale', () {
      final l10n = words[locale]!;
      final data = _data(_statement('EUR', 100), locale);
      final rows = (data['rows']! as List).cast<Map<String, Object?>>();
      final text = _words(
        renderReportBands(
          bands: customerStatementPeriodBands(l10n),
          data: data,
        )!,
      );
      expect(text, contains(l10n.customerStatementOpening));
      expect(text, contains(l10n.invoicePdfTitle));
      expect(text, contains(l10n.customerStatementMovePayment));
      expect(text, contains(l10n.customerStatementMoveAllocated));
      expect(text, contains(l10n.customerStatementMovePaid));
      expect(text, contains(l10n.customerStatementClosing));
      // The approval counted on the 30th; the payment is of the 28th. The
      // invoice counted on its own day: no second date.
      expect(rows.first['own'], '');
      expect(rows.last['own'], isNotEmpty);
      expect(
        text,
        contains(l10n.customerStatementDatedApart(rows.last['own']! as String)),
      );
      expect(
        text,
        contains(
          l10n.customerStatementReconstructed(data['history_from']! as String),
        ),
      );
      expect(text, isNot(contains(l10n.customerStatementNoMovement)));
      expect(text, isNot(contains('{{')));
    });

    test(
      'a $locale period without a movement says so, between two equal balances',
      () {
        final l10n = words[locale]!;
        const still = PeriodCurrency(
          currency: 'EUR',
          openingCents: 2000,
          closingCents: 2000,
        );
        final data = _data(still, locale);
        expect(data['no_movement'], isTrue);
        expect(data['opening'], data['closing']);
        final text = _words(
          renderReportBands(
            bands: customerStatementPeriodBands(l10n),
            data: data,
          )!,
        );
        expect(text, contains(l10n.customerStatementNoMovement));
      },
    );
  }

  test('the yen keeps no decimals and the euro two', () {
    expect(_data(_statement('JPY', 1), 'fr')['closing'], isNot(contains(',')));
    expect(_data(_statement('EUR', 100), 'fr')['closing'], contains('20,00'));
  });
}
