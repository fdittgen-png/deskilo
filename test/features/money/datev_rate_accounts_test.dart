// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2365 (DATEV 3b) — a reduced-rate position is booked to its automatic
// revenue account (SKR03 8300), the standard rate to 8400, each at its own
// gross: DATEV derives the tax from the account, so the gross of two rates
// on one account would be taxed at the wrong rate. A document of one
// account is one booking, as before. Expectations by hand.
import 'package:deskilo/features/money/domain/datev.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/seeded_export_year.dart';

/// (amount, Konto, Gegenkonto) of every booking row of [invoices].
List<(String, String, String)> _rows(List<Invoice> invoices) => [
  for (final r in buildDatevFile(
    invoices: invoices,
    matches: const {},
    accounts: const DatevAccounts(),
    from: DateTime(2026),
    to: DateTime(2026, 12, 31),
    generatedAt: DateTime(2027, 1, 5),
    consultantNumber: '1001',
    clientNumber: '20002',
  ).split('\r\n').skip(2).where((l) => l.isNotEmpty).map((l) => l.split(';')))
    (r[0], r[6], r[7]),
];

void main() {
  final base = SeededExportYear.inv2;

  test('19 % to 8400 and 7 % to 8300, each at its gross', () {
    final mixed = base.copyWith(
      lines: const [
        InvoiceLine(label: 'Desk', amountCents: 11900, vatPercent: 19),
        InvoiceLine(label: 'Books', amountCents: 10700, vatPercent: 7),
      ],
      totalCents: 22600,
    );
    expect(_rows([mixed]), [
      ('119,00', '10000', '8400'),
      ('107,00', '10000', '8300'),
    ]);
  });

  test('a reduced-rate credit note reverses 8300', () {
    final note = base.copyWith(
      number: 'CN-7',
      lines: const [
        InvoiceLine(label: 'Books', amountCents: -10700, vatPercent: 7),
      ],
      totalCents: -10700,
    );
    expect(_rows([note]), [('107,00', '8300', '10000')]);
  });

  test('a document of one rate stays one booking on 8400', () {
    final single = base.copyWith(
      lines: const [
        InvoiceLine(label: 'Desk', amountCents: 11900, vatPercent: 19),
        InvoiceLine(label: 'Room', amountCents: 5950, vatPercent: 19),
      ],
      totalCents: 17850,
    );
    expect(_rows([single]), [('178,50', '10000', '8400')]);
  });
}
