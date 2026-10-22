// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2365 fix 6 — DATEV: the field limits, the SKR in the header and the
// fiscal-year start from the book profile.
import 'package:deskilo/features/money/domain/book_profile.dart';
import 'package:deskilo/features/money/domain/datev.dart';
import 'package:deskilo/features/money/domain/datev_fields.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/seeded_export_year.dart';

String _file({
  List<Invoice>? invoices,
  DatevAccounts accounts = const DatevAccounts(),
}) => buildDatevFile(DatevRequest(
  invoices: invoices ?? SeededExportYear.invoices,
  matches: SeededExportYear.matches,
  accounts: accounts,
  from: DateTime(2026),
  to: DateTime(2026, 12, 31),
  generatedAt: DateTime(2027, 1, 5),
  consultantNumber: '1001',
  clientNumber: '20002',
  ledger: SeededExportYear.ledger,
));

void main() {
  test('header field 27 is the SKR of the chart', () {
    final header = _file().split('\r\n').first.split(';');
    expect(header[26], '03');
    expect(
      _file(accounts: const DatevAccounts(chart: 'SKR04'))
          .split('\r\n')
          .first
          .split(';')[26],
      '04',
    );
  });

  test('header field 13 is the fiscal-year start of the book profile', () {
    final header = _file(
      accounts: const DatevAccounts().withFiscalYearStart(DateTime(2025, 4)),
    ).split('\r\n').first.split(';');
    expect(header[12], '20250401');
    expect(_file().split('\r\n').first.split(';')[12], '20260101');
  });

  test('Belegfeld 1 stops at 36 characters and Buchungstext at 60', () {
    final long = SeededExportYear.inv2.copyWith(
      number: 'INV-${'1234567890' * 5}',
    );
    final rows = _file(invoices: [long])
        .split('\r\n')
        .skip(2)
        .where((l) => l.isNotEmpty)
        .map((l) => l.split(';'));
    expect(rows, isNotEmpty);
    for (final r in rows) {
      expect(r[10].replaceAll('"', '').length, lessThanOrEqualTo(36));
      expect(r[13].replaceAll('"', '').length, lessThanOrEqualTo(60));
    }
    expect(
      rows.any(
        (r) =>
            r[10].replaceAll('"', '') ==
            'INV-${'1234567890' * 5}'.substring(0, 36),
      ),
      isTrue,
    );
  });

  BookProfile profile(String site, int month, int day, DateTime from) =>
      BookProfile(
        id: 'p-$site-$from',
        workspaceId: 'w1',
        issuerSiteId: site,
        authority: BookAuthority.localBook,
        externalSystem: '',
        functionalCurrency: 'EUR',
        fiscalYearStartMonth: month,
        fiscalYearStartDay: day,
        basis: AccountingBasis.accrual,
        effectiveFrom: from,
        revision: 1,
      );

  test('the fiscal-year start follows the profiles that agree', () {
    final from = DateTime(2026);
    final to = DateTime(2026, 12, 31);
    expect(datevProfileFiscalStart(const [], from, to), isNull);
    // April start: the year containing 1 January 2026 began 1 April 2025.
    expect(
      datevProfileFiscalStart([profile('a', 4, 1, DateTime(2020))], from, to),
      DateTime(2025, 4),
    );
    // The later version of an issuer wins; a version not yet in force is ignored.
    expect(
      datevProfileFiscalStart(
        [
          profile('a', 4, 1, DateTime(2020)),
          profile('a', 1, 1, DateTime(2025)),
          profile('a', 7, 1, DateTime(2027)),
        ],
        from,
        to,
      ),
      DateTime(2026),
    );
    // Issuers that disagree: no guess.
    expect(
      datevProfileFiscalStart(
        [
          profile('a', 4, 1, DateTime(2020)),
          profile('b', 1, 1, DateTime(2020)),
        ],
        from,
        to,
      ),
      isNull,
    );
  });
}
