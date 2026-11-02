// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The bank report renders its rows without a false book-ledger claim.
import 'package:deskilo/features/money/domain/invoice_report.dart';
import 'package:deskilo/features/money/presentation/report_defaults.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('bank report designer renders its own rows without a ledger claim', () {
    final bands = defaultBandsForDoc(
      'bank_reconciliation',
      AppLocalizationsEn(),
    );
    final report = renderReportBands(
      bands: bands,
      data: {
        'workspace': 'Test workspace',
        'workspace_address': '',
        'book_period': 'Stored movement dates: 1 – 31 January',
        'book_rows': [
          {'label': 'Line', 'detail': 'Named unmatched', 'balance': '42 CHF'},
          {
            'label': 'Difference against books',
            'detail': '',
            'balance': 'Unavailable',
          },
        ],
      },
    );
    expect(report, isNotNull);
    final rows = report!.body
        .whereType<ReportTableRow>()
        .map((row) => row.cells.join(' '))
        .join('\n');
    expect(rows, contains('Named unmatched'));
    expect(rows, contains('Unavailable'));
    expect(bands.footer, isNot(contains('FEC')));
    expect(bands.footer, isNot(contains('postings')));
  });
}
