// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4431 (G17) -- the expiry report's golden, in two languages (fr, de): the data map written by stockExpiryReportData from one
// list (a lot expired six days ago, a lot expiring today, one in nine days, and a piece with its tag), byte-identical to its
// golden; a golden changes only when the document is MEANT to change: regenerate with --dart-define=WRITE_GOLDEN=true and say
// so. The bands are then rendered in the same language: each line's words are there, an empty list says so, and nothing is
// computed on the way.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/money/domain/invoice_report.dart';
import 'package:deskilo/features/money/domain/stock_expiry_report.dart';
import 'package:deskilo/features/money/presentation/report_defaults_stock_expiry.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo/l10n/app_localizations_de.dart';
import 'package:deskilo/l10n/app_localizations_fr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const _write = bool.fromEnvironment('WRITE_GOLDEN');

final _asOf = DateTime(2026, 11, 22);

final _lines = [
  StockExpiryLine(item: 'Lait', lot: 'L-09', expiresOn: DateTime(2026, 11, 16), days: -6, quantity: '2 l', place: 'MAIN · Magasin'),
  StockExpiryLine(item: 'Yaourt', variant: 'Nature', lot: 'Y-12', expiresOn: _asOf, days: 0, quantity: '12 pièce', place: 'MAIN · Magasin'),
  StockExpiryLine(item: 'Panier', lot: 'P-1', tag: 'E2801160600002054AF3E001', expiresOn: DateTime(2026, 12), days: 9, quantity: '1 pièce', place: 'BACK · Réserve'),
];

Map<String, Object?> _data(List<StockExpiryLine> lines, String locale, {String scope = 'both'}) => stockExpiryReportData(
  lines: lines,
  asOf: _asOf,
  scope: scope,
  locale: locale,
  letter: (workspace: 'Test Space', address: '1 place du Marché', issuedBy: 'Camille Owner', issued: DateTime(2026, 11, 22)),
);

String _words(InvoiceReport report) => [
  for (final b in [...report.header, ...report.body, ...report.footer])
    switch (b) {
      ReportHeading(:final text) || ReportSubheading(:final text) || ReportText(:final text) || ReportMuted(:final text) => text,
      ReportTableRow(:final cells) => cells.join(' | '),
      _ => '',
    },
].join('\n');

void main() {
  setUpAll(initializeDateFormatting);
  final words = <String, AppLocalizations>{'fr': AppLocalizationsFr(), 'de': AppLocalizationsDe()};

  for (final locale in words.keys) {
    final name = 'stock_expiry_report_data_$locale';
    test('$name is byte-identical to its golden', () {
      final encoded = const JsonEncoder.withIndent('  ').convert(_data(_lines, locale));
      final file = File('test/features/money/goldens/$name.json');
      if (_write) {
        file.writeAsStringSync('$encoded\n');
        return;
      }
      expect(encoded, file.readAsStringSync().trimRight());
    });

    test('the $locale bands say the title, the date, each line and how far it is from the date, in $locale', () {
      final l10n = words[locale]!;
      final text = _words(renderReportBands(bands: stockExpiryBands(l10n), data: _data(_lines, locale))!);
      expect(text, contains(l10n.reportDocStockExpiry));
      expect(text, contains(l10n.stockExpiryScopeBoth));
      expect(text, contains('Lait'));
      expect(text, contains('Nature'));
      expect(text, contains('E2801160600002054AF3E001'));
      expect(text, contains(l10n.stockExpiryDaysPast('6')));
      expect(text, contains(l10n.taskRecorderValueToday));
      expect(text, contains(l10n.stockExpiryDaysAhead('9')));
      expect(text, isNot(contains(l10n.stockExpiryNone)));
      expect(text, isNot(contains('{{')));
    });

    test('a $locale report with nothing to list says so', () {
      final l10n = words[locale]!;
      final data = _data(const [], locale, scope: 'expired');
      expect(data['no_rows'], isTrue);
      final text = _words(renderReportBands(bands: stockExpiryBands(l10n), data: data)!);
      expect(text, contains(l10n.stockExpiryNone));
      expect(text, contains(l10n.stockExpiryScopeExpired));
    });
  }

  test('a line is expired below zero, today at zero and expiring above it, and shows the size of the gap', () {
    final rows = (_data(_lines, 'fr')['rows']! as List).cast<Map<String, Object?>>();
    expect(rows.map((r) => (r['state'], r['days'])), [('expired', '6'), ('today', '0'), ('expiring', '9')]);
  });
}
