// SPDX-License-Identifier: 0BSD
//
// The properties an accounting export has to hold, whatever is in it.
//
// The formats each have their own tests and those tests are good — the
// DDMM trap, the S/H flag, Festschreibung, the 18 FEC columns. What none
// of them asserted is the property the whole file stands or falls on.
// `fec_test.dart` has a case called "books the receivable against the
// revenue, BALANCED" and it checks two string values on a two-line
// entry: it would pass on a file where every other entry was out by
// thousands.
//
// So this file sums. Over the shapes a real coworking year contains —
// several VAT rates on one document, credit notes, payments netted on
// the invoice and payments matched afterwards, an exempt association,
// reverse charge — and it checks the bytes, which is where two of these
// formats were actually wrong.
import 'dart:convert';

import 'package:deskilo/core/country/country_catalog.dart';
import 'package:deskilo/features/money/domain/accounting_format.dart';
import 'package:deskilo/features/money/domain/datev.dart';
import 'package:deskilo/features/money/domain/fec.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/invoice_line_text.dart';
import 'package:deskilo/features/money/domain/report_strings.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:flutter_test/flutter_test.dart';

const _company = InvoiceParty(
  name: 'pezenas1',
  street: '2 Place du Marché',
  city: 'Pézenas',
  postalCode: '34120',
  country: 'FR',
  legalId: '812345678',
);

Invoice _inv({
  required String number,
  required List<InvoiceLine> lines,
  required int total,
  List<InvoiceVatTotal> vatTotals = const [],
  String replacesNumber = '',
  DateTime? issuedAt,
  String memberName = 'Ana Martin',
}) =>
    Invoice(
      id: 'i-$number',
      workspaceId: 'ws',
      memberId: 'm1',
      number: number,
      issuedAt: issuedAt ?? DateTime(2026, 7, 2),
      period: '2026-06',
      title: 'Coworking',
      lines: lines,
      totalCents: total,
      currency: 'EUR',
      memberName: memberName,
      memberAddress: '1 Rue du Test',
      workspaceName: 'pezenas1',
      workspaceAddress: '2 Place du Marché',
      issuerName: 'Flo',
      signature: 'f' * 64,
      sellerParty: _company,
      replacesNumber: replacesNumber,
      vatTotals: vatTotals,
    );

/// A year with every shape in it that a coworking actually issues.
///
/// Deliberately not one tidy invoice: the arithmetic that breaks is the
/// arithmetic on the document nobody wrote a fixture for.
List<Invoice> _aRealYear() => [
      // No VAT at all — an association under the French franchise.
      _inv(
        number: 'A1',
        issuedAt: DateTime(2026, 1, 8),
        lines: const [
          InvoiceLine(kind: 'subscription', label: '100', amountCents: 25000),
        ],
        total: 25000,
      ),
      // Two rates on one document: a desk at 20 %, lunch at 10 %. The
      // case that turns one entry into five lines.
      _inv(
        number: 'A2',
        issuedAt: DateTime(2026, 2, 3),
        lines: const [
          InvoiceLine(
              kind: 'subscription', label: 'desk', amountCents: 24000,
              vatPercent: 20),
          InvoiceLine(
              kind: 'service', label: 'lunch', amountCents: 5500,
              vatPercent: 10),
        ],
        total: 29500,
        vatTotals: const [
          InvoiceVatTotal(
              percent: 20, category: 'S', grossCents: 24000,
              netCents: 20000, vatCents: 4000),
          InvoiceVatTotal(
              percent: 10, category: 'S', grossCents: 5500,
              netCents: 5000, vatCents: 500),
        ],
      ),
      // A payment netted ON the document — the receivable stays gross.
      _inv(
        number: 'A3',
        issuedAt: DateTime(2026, 3, 5),
        lines: const [
          InvoiceLine(kind: 'subscription', label: '100', amountCents: 30000),
          InvoiceLine(kind: 'payment', label: 'Virement', amountCents: -12000),
        ],
        total: 18000,
      ),
      // Reverse charge: an intra-EU B2B member, no VAT collected (ADR
      // 0016). Nothing may reach the 44571 account.
      _inv(
        number: 'A4',
        issuedAt: DateTime(2026, 4, 9),
        memberName: 'Kowalczyk sp. z o.o.',
        lines: const [
          InvoiceLine(
              kind: 'subscription', label: 'desk', amountCents: 40000),
        ],
        total: 40000,
        vatTotals: const [
          InvoiceVatTotal(
              percent: 0, category: 'AE', grossCents: 40000,
              netCents: 40000, vatCents: 0),
        ],
      ),
      // A credit note against the two-rate invoice — every slice
      // reversed on its own.
      _inv(
        number: 'A5',
        issuedAt: DateTime(2026, 5, 11),
        replacesNumber: 'A2',
        lines: const [
          InvoiceLine(
              kind: 'subscription', label: 'desk', amountCents: -24000,
              vatPercent: 20),
        ],
        total: -24000,
        vatTotals: const [
          InvoiceVatTotal(
              percent: 20, category: 'S', grossCents: -24000,
              netCents: -20000, vatCents: -4000),
        ],
      ),
      // An odd amount: 33,33 € at 20 % does not divide cleanly, which is
      // exactly where a rounding bug hides.
      _inv(
        number: 'A6',
        issuedAt: DateTime(2026, 6, 17),
        lines: const [
          InvoiceLine(
              kind: 'service', label: 'printing', amountCents: 3333,
              vatPercent: 20),
        ],
        total: 3333,
        vatTotals: const [
          InvoiceVatTotal(
              percent: 20, category: 'S', grossCents: 3333,
              netCents: 2778, vatCents: 555),
        ],
      ),
    ];

/// Payments that landed AFTER their invoice — the second cash path.
Map<String, InvoiceMatch> _matches() => {
      'i-A1': InvoiceMatch(
        invoiceId: 'i-A1',
        paidCents: 25000,
        status: 'confirmed',
        resolution: 'exact',
        // Deliberately later than invoices A2..A6, so an exporter that
        // wrote rows document by document produces an out-of-order file.
        matchedAt: DateTime(2026, 8, 20),
      ),
      'i-A6': InvoiceMatch(
        invoiceId: 'i-A6',
        paidCents: 3333,
        status: 'confirmed',
        resolution: 'exact',
        matchedAt: DateTime(2026, 6, 30),
      ),
    };

String _fec({List<Invoice>? invoices}) => buildFecFile(
      invoices: invoices ?? _aRealYear(),
      matches: _matches(),
      company: _company,
      accounts: const FecAccounts(),
      lineText: (line) => invoiceLineText(const ReportStrings(), line),
    );

List<Map<String, String>> _fecRows([String? file]) {
  final lines = (file ?? _fec()).split('\r\n').where((l) => l.isNotEmpty);
  final header = lines.first.split('\t');
  return [
    for (final line in lines.skip(1))
      Map.fromIterables(header, line.split('\t')),
  ];
}

int _cents(String amount) =>
    (double.parse(amount.replaceAll(',', '.')) * 100).round();

void main() {
  group('the FEC balances — the property the file stands on', () {
    test('every accounting entry has equal debits and credits', () {
      final perEntry = <String, int>{};
      for (final row in _fecRows()) {
        perEntry[row['EcritureNum']!] = (perEntry[row['EcritureNum']] ?? 0) +
            _cents(row['Debit']!) -
            _cents(row['Credit']!);
      }

      final unbalanced = {
        for (final e in perEntry.entries)
          if (e.value != 0) e.key: e.value,
      };
      expect(
        unbalanced,
        isEmpty,
        reason: 'an unbalanced écriture is rejected outright — by the '
            'DGFiP\'s reader, by every accountant\'s software, and by '
            'anyone who adds up a column. Out by (cents): $unbalanced',
      );
    });

    test('and so does the file as a whole', () {
      var debit = 0;
      var credit = 0;
      for (final row in _fecRows()) {
        debit += _cents(row['Debit']!);
        credit += _cents(row['Credit']!);
      }
      expect(debit, credit, reason: 'Σ débit must equal Σ crédit');
      expect(debit, greaterThan(0), reason: 'an EMPTY file balances too');
    });

    test('each entry is one journal, one date and one document', () {
      // A single EcritureNum spanning two journals or two dates is not an
      // entry, it is two — and the DGFiP reads it as one.
      final journals = <String, Set<String>>{};
      final dates = <String, Set<String>>{};
      for (final row in _fecRows()) {
        (journals[row['EcritureNum']!] ??= {}).add(row['JournalCode']!);
        (dates[row['EcritureNum']!] ??= {}).add(row['EcritureDate']!);
      }
      expect(journals.values.every((j) => j.length == 1), isTrue,
          reason: 'entries spanning journals: '
              '${journals.entries.where((e) => e.value.length > 1)}');
      expect(dates.values.every((d) => d.length == 1), isTrue,
          reason: 'entries spanning dates: '
              '${dates.entries.where((e) => e.value.length > 1)}');
    });

    test('reverse charge collects no VAT — nothing reaches 44571', () {
      // ADR 0016: the customer owes the tax. A euro booked to the
      // collected-VAT account here is a euro the workspace would be
      // declaring it holds and does not.
      final rows = _fecRows(_fec(invoices: [_aRealYear()[3]]));
      expect(rows.where((r) => r['CompteNum'] == '445710'), isEmpty);
      expect(rows, hasLength(2), reason: 'receivable against revenue, '
          'and nothing else');
    });
  });

  group('the FEC reads as books that were kept in order', () {
    test('rows are chronological', () {
      // The rows are built document by document — an invoice, then the
      // cash that settled it — so a payment in August was written before
      // the invoices of March. Every entry was correct and the file read
      // as though the books had been kept out of order, which is the
      // first thing an auditor notices.
      final dates = [for (final r in _fecRows()) r['EcritureDate']!];
      final sorted = [...dates]..sort();
      expect(dates, sorted, reason: 'out of order: $dates');
    });

    test('a sale comes before the cash that settled it on the same day',
        () {
      // The tiebreak within a date is insertion order, which is document
      // by document. Ordering by journal CODE instead would put BQ ahead
      // of VE — the bank entry before the invoice that created it.
      final rows = _fecRows(_fec(invoices: [
        _inv(
          number: 'S1',
          issuedAt: DateTime(2026, 9, 1),
          lines: const [
            InvoiceLine(kind: 'subscription', label: '100', amountCents: 9000),
            InvoiceLine(kind: 'payment', label: 'Virement', amountCents: -9000),
          ],
          total: 0,
        ),
      ]));
      final journals = [for (final r in rows) r['JournalCode']!];
      expect(journals.first, 'VE',
          reason: 'the sale is booked first: $journals');
    });
  });

  group('the bytes, which is where two of these were wrong', () {
    test('the FEC carries NO byte-order mark', () {
      // The DGFiP's reader positions by column on the first line. A BOM
      // prefixes "JournalCode" and the first column stops being found.
      final bytes = utf8.encode(_fec());
      expect(bytes.take(3), isNot([0xEF, 0xBB, 0xBF]));
      expect(_fec().startsWith('JournalCode'), isTrue);
    });

    test('DATEV carries one, because without it every umlaut corrupts',
        () {
      // DATEV reads an unmarked file as Windows-1252. "Bürogemeinschaft
      // München" imports as "BÃ¼rogemeinschaft MÃ¼nchen" in the
      // accountant's books, and nothing errors anywhere.
      final file = buildDatevFile(
        invoices: _aRealYear(),
        matches: _matches(),
        accounts: const DatevAccounts(),
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
        generatedAt: DateTime(2026, 5, 1, 9),
        consultantNumber: '1234567',
        clientNumber: '54321',
      );
      final bytes = utf8.encode(file);
      expect(bytes.take(3).toList(), [0xEF, 0xBB, 0xBF],
          reason: 'the three bytes that decide whether a German '
              'accountant reads names or mojibake');
      expect(file.substring(1).startsWith('"EXTF"'), isTrue,
          reason: 'and the header still begins where DATEV expects it');
    });

    test('text outside Windows-1252 reaches the file intact', () {
      // Which is why the fix is a BOM rather than transcoding down to
      // Windows-1252: a Munich coworking is called Bürogemeinschaft and
      // bills members called Škoda, and that charset cannot spell the
      // second one. Transcoding would substitute or drop it silently.
      const name = 'Bürogemeinschaft Škoda';
      final file = buildDatevFile(
        invoices: const [],
        matches: const {},
        accounts: const DatevAccounts(),
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
        generatedAt: DateTime(2026, 5, 1),
        consultantNumber: '1',
        clientNumber: '2',
        batchName: name,
      );
      expect(file, contains(name));

      // And it is still there as bytes. `utf8.decode` strips a leading
      // BOM, so a decode-and-compare would quietly pass on a file that
      // had lost it — which is how the first version of this test
      // measured nothing.
      final bytes = utf8.encode(file);
      expect(bytes.take(3).toList(), [0xEF, 0xBB, 0xBF]);
      final needle = utf8.encode(name);
      expect(
        List.generate(bytes.length - needle.length + 1, (i) => i).any(
            (i) => List.generate(needle.length, (j) => bytes[i + j])
                .toString() == needle.toString()),
        isTrue,
        reason: 'the name must survive as UTF-8 bytes, not as question '
            'marks',
      );
    });
  });

  group('DATEV bookings are well formed, whatever is in them', () {
    late List<List<String>> rows;
    late List<String> header;

    setUp(() {
      final file = buildDatevFile(
        invoices: _aRealYear(),
        matches: _matches(),
        accounts: const DatevAccounts(),
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
        generatedAt: DateTime(2026, 5, 1, 9),
        consultantNumber: '1234567',
        clientNumber: '54321',
      );
      final lines =
          file.substring(1).split('\r\n').where((l) => l.isNotEmpty).toList();
      header = lines.first.split(';');
      rows = [for (final l in lines.skip(2)) l.split(';')];
    });

    test('the header is the 31 fields EXTF 700 defines', () {
      expect(header, hasLength(31));
      expect(header[0], '"EXTF"');
      expect(header[1], '700');
      expect(header[2], '21', reason: 'Formatkategorie: Buchungsstapel');
      expect(header[5].length, 17,
          reason: 'Erzeugt am is YYYYMMDDHHMMSSFFF');
    });

    test('every row carries the first 20 fields, no gaps', () {
      // DATEV positions by column and tolerates a truncated TAIL. It
      // does not tolerate a hole: one missing field shifts every
      // following column into the wrong meaning.
      expect(rows, isNotEmpty);
      for (final row in rows) {
        expect(row, hasLength(20), reason: 'row: $row');
      }
    });

    test('every amount is positive — direction lives in the S/H flag',
        () {
      for (final row in rows) {
        expect(row[0], isNot(startsWith('-')), reason: 'row: $row');
        expect(row[1], '"S"',
            reason: 'Konto holds the debit and Gegenkonto the credit, so '
                'the flag is always S. Writing the pair the other way '
                'with H posts the booking mirrored. Row: $row');
      }
    });

    test('a booking never posts an account against itself', () {
      // Konto == Gegenkonto is a no-op DATEV rejects, and it is what a
      // mis-wired default chart produces.
      for (final row in rows) {
        expect(row[6], isNot(row[7]), reason: 'row: $row');
        expect(row[6], isNotEmpty);
        expect(row[7], isNotEmpty);
      }
    });

    test('Belegdatum is four digits and no more', () {
      for (final row in rows) {
        expect(row[9], matches(RegExp(r'^\d{4}$')), reason: 'row: $row');
      }
    });

    test('Belegfeld 1 stays inside the 36 characters DATEV allows', () {
      for (final row in rows) {
        expect(row[10].replaceAll('"', '').length, lessThanOrEqualTo(36),
            reason: 'a longer document reference is truncated on import, '
                'and the booking stops naming the invoice it came from. '
                'Row: $row');
      }
    });
  });

  group('every country the app bills in can hand something over', () {
    test('no supported country is offered nothing at all', () {
      // The catalogue grew from 13 to 32 (#534). A format registry keyed
      // by country list can silently stop covering the ones added after
      // it was written, and the failure is invisible until an owner in
      // Warsaw opens the export sheet and finds it empty.
      final uncovered = [
        for (final country in CountryCatalog.countries)
          if (formatsFor(country.code).isEmpty) country.code,
      ];
      expect(uncovered, isEmpty,
          reason: 'these countries have no accounting export: $uncovered');
    });

    test('and every one of them gets a format that claims nothing it '
        'cannot back', () {
      // A country whose ONLY offer were a regulatory file would be a
      // country where an accountant who simply wants a readable ledger
      // has to take a tax filing instead. The generic exchange formats
      // exist for that and are offered everywhere; this pins it.
      for (final country in CountryCatalog.countries) {
        final exchange = formatsFor(country.code)
            .where((f) => f.claim == FormatClaim.exchange);
        expect(exchange, isNotEmpty,
            reason: '${country.code} has no exchange format');
      }
    });

    test('a regulatory claim is only ever made where an authority asked',
        () {
      // The one direction this registry must never drift. A format that
      // says `regulatory` is telling an owner the file satisfies an
      // obligation, and a wrong one is a false statement to a tax
      // authority — worse than shipping nothing.
      final regulatory = {
        for (final f in accountingFormats)
          if (f.claim == FormatClaim.regulatory) f.id: f.countries,
      };
      expect(regulatory, {
        'fec': {'FR'},
        'saft_pt': {'PT'},
      },
          reason: 'adding to this needs the authority\'s own published '
              'spec in hand, and docs/domain/ACCOUNTING_EXPORTS.md '
              'updated to say which obligation it meets');
    });
  });

  group('the two files agree with each other', () {
    test('what the FEC books as revenue, DATEV books as revenue', () {
      // Different charts, different shapes, one set of facts. They are
      // produced by separate code paths from the same invoices, and a
      // divergence means one of them is wrong about the year.
      final year = _aRealYear();
      final fecRevenue = _fecRows(_fec(invoices: year))
          .where((r) => r['CompteNum'] == '706000')
          .fold<int>(0, (sum, r) => sum + _cents(r['Credit']!) - _cents(r['Debit']!));

      // DATEV books the GROSS against revenue and lets the accountant's
      // BU-Schlüssel split the tax, so its revenue side carries the VAT
      // the FEC separates out. Compare like with like.
      final fecVat = _fecRows(_fec(invoices: year))
          .where((r) => r['CompteNum'] == '445710')
          .fold<int>(0, (sum, r) => sum + _cents(r['Credit']!) - _cents(r['Debit']!));

      final datev = buildDatevFile(
        invoices: year,
        matches: const {},
        accounts: const DatevAccounts(),
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
        generatedAt: DateTime(2026, 5, 1),
        consultantNumber: '1',
        clientNumber: '2',
      );
      final datevRevenue = datev
          .substring(1)
          .split('\r\n')
          .where((l) => l.isNotEmpty)
          .skip(2)
          .map((l) => l.split(';'))
          .fold<int>(0, (sum, f) {
        final amount = (double.parse(f[0].replaceAll(',', '.')) * 100).round();
        // Revenue credited when it is the Gegenkonto, debited when a
        // credit note makes it the Konto.
        if (f[7] == '8400') return sum + amount;
        if (f[6] == '8400') return sum - amount;
        return sum;
      });

      expect(
        datevRevenue,
        fecRevenue + fecVat,
        reason: 'the FEC splits net revenue from collected VAT; DATEV '
            'books the gross and lets the BU-Schlüssel split it. Their '
            'totals have to reconcile or one of them is lying about the '
            'year.',
      );
    });
  });
}
