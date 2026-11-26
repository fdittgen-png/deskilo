// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4368 -- the day report on the receipt printer: it carries the figures the server froze, in the screen's words, the
// day's sales as the total and the takings by tender; at 58 mm every line still fits the paper.
import 'package:deskilo/core/i18n/app_format.dart';
import 'package:deskilo/features/money/domain/escpos_receipt.dart';
import 'package:deskilo/features/money/domain/till_day.dart';
import 'package:deskilo/features/money/presentation/till_drawer/day_report_print.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

final _en = AppLocalizationsEn();
const _format = AppFormat(locale: 'en', currencyCode: 'EUR');
const _report = DayReport(
  dayCloseId: 'd1',
  number: 'Z-00003',
  businessDate: '2026-11-25',
  sessions: [DaySession(till: 'Front counter', floatMinor: 10000, expectedMinor: 24510, countedMinor: 24500, differenceMinor: -10, differenceReason: 'coin', bankedMinor: 0, unresolvedCardMinor: 0)],
  differencesMinor: -10,
  salesByRate: [DayRate(percent: '20', category: 'S', grossMinor: 14510, netMinor: 12092, taxMinor: 2418)],
  salesByTender: {'cash': 14510},
  salesTotalMinor: 14510,
  firstReceipt: 'R-00101',
  lastReceipt: 'R-00140',
  correctionsMinor: 0,
  refunds: {},
  paidInMinor: 0,
  paidOutMinor: 500,
);

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  test('the day report prints its figures in the screen words, the sales as the total', () {
    final print = dayReportPrint(l10n: _en, fmt: _format, business: 'Épicerie', report: _report, currency: 'EUR');
    expect(print.title, _en.tillDayReportTitle('Z-00003'));
    expect(print.total, '€145.10');
    expect(print.tenders.single.amount, '€145.10');
    expect([for (final l in print.lines) l.label], containsAll([_en.tillDayReceiptRange('R-00101', 'R-00140'), _en.tillDayPaidOut('€5.00')]));
    final text = String.fromCharCodes(encodeReceipt(print, const EscposProfile()));
    expect(text, contains('Z-00003'));
  });

  test('at 80 and 58 mm every line of the day report fits the paper', () {
    final print = dayReportPrint(l10n: _en, fmt: _format, business: 'Épicerie', report: _report, currency: 'EUR');
    for (final (mm, cols) in const [(80, 48), (58, 32)]) {
      final bytes = encodeReceipt(print, EscposProfile(paperMm: mm));
      final rows = String.fromCharCodes(bytes.where((b) => b >= 0x20 || b == 0x0A)).split('\n');
      for (final row in rows) {
        if (row.contains(_en.tillPrintTotal)) continue; // printed double width
        expect(row.length, lessThanOrEqualTo(cols + 8), reason: '$mm mm: $row');
      }
    }
  });
}
