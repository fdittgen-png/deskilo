// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2380 — the DATEV row of a receipt reconciled with a bank statement line
// carries the line's value date and reference as Beleginfo pairs, after the
// document's own (Rechnungsnummer, Belegdatum, Fälligkeit). Its Belegdatum
// stays the match day: it decides the row's Buchungsstapel. The facts come
// from the accounting source's match rows (0641); a row without them is
// byte-identical to what it was. Expectations by hand.
import 'package:deskilo/core/data/json_reader.dart';
import 'package:deskilo/features/money/domain/datev.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_match_row.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/datev_collective.dart';
import 'support/seeded_export_year.dart';

List<String> _datev(Map<String, InvoiceMatch> matches) => buildDatevFile(
  DatevRequest(
    currency: 'EUR',
    detail: datevCollective,
    invoices: SeededExportYear.acceptanceInvoices,
    matches: matches,
    accounts: const DatevAccounts(),
    from: DateTime(2026),
    to: DateTime(2026, 12, 31),
    generatedAt: DateTime(2027, 1, 5),
    consultantNumber: '1001',
    clientNumber: '20002',
    ledger: SeededExportYear.ledger,
  ),
).split('\r\n');

/// The Beleginfo pairs (fields 21 to 36) of [row], as (Art, Inhalt).
List<(String, String)> _info(String row) {
  final f = row.split(';');
  return [
    for (var k = 0; k < 8; k++)
      if (f[20 + 2 * k].isNotEmpty) (f[20 + 2 * k], f[21 + 2 * k]),
  ];
}

Map<String, InvoiceMatch> _withFacts({String? reference}) {
  final m = SeededExportYear.acceptanceMatches;
  final inv1 = SeededExportYear.inv1.id;
  final cn = SeededExportYear.creditNote.id;
  return {
    ...m,
    inv1: m[inv1]!.copyWith(
      valueDate: DateTime(2026, 3, 17),
      bankReference: reference,
    ),
    cn: m[cn]!.copyWith(valueDate: DateTime(2026, 6, 9)),
  };
}

void main() {
  final plain = _datev(SeededExportYear.acceptanceMatches);

  String receipt(List<String> rows) => rows.singleWhere(
    (l) => l.contains('"Zahlung INV-1"') && l.split(';')[9] == '2003',
  );

  test('the receipt row carries the value date and the reference after '
      'the document\'s own Beleginfo', () {
    final row = receipt(_datev(_withFacts(reference: 'RF18539007547034')));
    final info = _info(row);
    expect(info.sublist(info.length - 2), [
      ('"Valutadatum"', '"17.03.2026"'),
      ('"Bankreferenz"', '"RF18539007547034"'),
    ]);
    expect(info.first, ('"Rechnungsnummer"', '"INV-1"'));
    expect(row.split(';')[9], '2003', reason: 'Belegdatum stays the match day');
  });

  test('a line without a reference gives the value date alone', () {
    final info = _info(receipt(_datev(_withFacts())));
    expect(info.last, ('"Valutadatum"', '"17.03.2026"'));
    expect(info.where((p) => p.$1 == '"Bankreferenz"'), isEmpty);
  });

  test('a refund paid out through a line carries its value date too', () {
    final row = _datev(_withFacts())
        .singleWhere((l) => l.contains('"Erstattung CN-1"'));
    expect(_info(row).last, ('"Valutadatum"', '"09.06.2026"'));
  });

  test('only the rows of the reconciled money change; the rest are '
      'byte-identical', () {
    final facts = _datev(_withFacts(reference: 'R'));
    expect(facts, hasLength(plain.length));
    final changed = [
      for (var i = 0; i < plain.length; i++)
        if (plain[i] != facts[i]) i,
    ];
    expect(changed, hasLength(2));
    expect(plain.where((l) => l.contains('Valutadatum')), isEmpty);
    // The changed rows differ in their Beleginfo cells alone.
    for (final i in changed) {
      final a = plain[i].split(';');
      final b = facts[i].split(';');
      for (var f = 0; f < a.length; f++) {
        if (f >= 20 && f < 36) continue;
        expect(b[f], a[f], reason: 'field ${f + 1} of row $i');
      }
    }
  });

  test('the source\'s match row is read with its facts, and without them '
      'when it has none', () {
    final row = {
      'invoice_id': 'i1',
      'paid_cents': 12000,
      'resolution': 'exact',
      'matched_at': '2026-03-20T10:00:00+00:00',
    };
    final bare = invoiceMatchOf(JsonReader.of(row, context: 't'));
    expect(bare.valueDate, isNull);
    expect(bare.bankReference, isNull);
    final full = invoiceMatchOf(
      JsonReader.of({
        ...row,
        'value_date': '2026-03-17',
        'bank_reference': 'RF1',
      }, context: 't'),
    );
    expect(full.valueDate, DateTime(2026, 3, 17));
    expect(full.bankReference, 'RF1');
  });
}
