// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The seeded year at German rates as a DATEV request, and a parser for the
// files the DATEV package writes: shared by the DATEV package tests.
import 'package:deskilo/features/money/domain/datev.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:flutter_test/flutter_test.dart';

import 'seeded_export_year.dart';

const _bom = '\u{FEFF}';

/// [i] at German rates (19 % and 7 %), with the buyer as frozen at issue.
Invoice datevGerman(Invoice i, {String number = 'M-0042', String site = ''}) =>
    i.copyWith(
      lines: [
        for (final l in i.lines)
          l.copyWith(
            vatPercent: switch (l.vatPercent) {
              20 => 19,
              5.5 => 7,
              final p => p,
            },
          ),
      ],
      buyerParty: InvoiceParty(
        name: 'Ana Kowalczyk',
        memberNumber: number,
        street: 'Leopoldstraße 1',
        postalCode: '80802',
        city: 'München',
        country: 'DE',
      ),
      sellerParty: seededCompany.copyWith(site: site),
    );

List<Invoice> get datevYear => [
  for (final i in SeededExportYear.acceptanceInvoices)
    datevGerman(i, site: i.number == 'INV-2' ? 'Schwabing' : ''),
];

DatevRequest datevTestRequest({
  List<Invoice>? invoices,
  DatevAccounts accounts = const DatevAccounts(),
  String consultant = '1234567',
  String client = '54321',
  String currency = 'EUR',
  int accountLength = 4,
}) => DatevRequest(
  invoices: invoices ?? datevYear,
  matches: SeededExportYear.acceptanceMatches,
  accounts: accounts,
  from: DateTime(2026),
  to: DateTime(2026, 12, 31),
  generatedAt: DateTime(2027, 1, 5, 9),
  consultantNumber: consultant,
  clientNumber: client,
  detail: const DatevDetail(defaultCostCentre: 'Cowork', voucherLinks: true),
  currency: currency,
  accountLength: accountLength,
  batchName: 'Bürogemeinschaft München Schwabing Nord',
  ledger: [
    for (final e in SeededExportYear.ledger)
      if (e.createdAt.year == 2026) e,
  ],
);

/// A parsed Buchungsstapel: its header fields and its rows' fields.
typedef DatevTestBatch = ({List<String> header, List<List<String>> rows});

DatevTestBatch datevTestParse(String file) {
  expect(file.startsWith(_bom), isTrue, reason: 'the BOM comes first');
  final lines = file.substring(1).split('\r\n');
  expect(lines.last, isEmpty, reason: 'CRLF after the last row');
  return (
    header: datevTestFields(lines[0]),
    rows: [
      for (final l in lines.skip(2).where((l) => l.isNotEmpty)) datevTestFields(l),
    ],
  );
}

/// The fields of one line; a quoted field may hold doubled quotes.
List<String> datevTestFields(String line) {
  final out = <String>[];
  final b = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') {
      if (quoted && i + 1 < line.length && line[i + 1] == '"') {
        b.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (c == ';' && !quoted) {
      out.add(b.toString());
      b.clear();
    } else {
      b.write(c);
    }
  }
  out.add(b.toString());
  return out;
}
