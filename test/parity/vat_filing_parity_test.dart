// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3330 (of #3328) -- the parity baseline of the VAT filing files, captured
// BEFORE any writer moves into a jurisdiction package. Each case runs the one
// dispatcher (`vatFilingFile`) on a fixed declaration, party and clock and
// compares the BYTES of the file (in the encoding its channel reads) and its
// name with a golden under `test/parity/golden/vat_filing/`. The refusals are
// part of the contract too: `refusals.txt` holds, per case, the problem a
// writer raises (its stable name) or the unsupported-country message.
//
// The goldens live outside the code that will move, so moving it cannot move
// or regenerate them. They are rewritten only with
// `UPDATE_PARITY_GOLDENS=1` -- never under CI -- and the change is a
// reviewer-visible diff of the files.
import 'dart:convert';
import 'dart:typed_data';

import 'package:deskilo/features/money/application/save_vat_filing_file.dart';
import 'package:deskilo/features/money/domain/vat_declaration.dart';
import 'package:deskilo/features/money/domain/vat_filing_files.dart';
import 'package:flutter_test/flutter_test.dart';

import 'parity_golden.dart';

const _dir = 'test/parity/golden/vat_filing';

/// The fixed moment every file is generated at.
final _now = DateTime.utc(2026, 10, 2, 12);

VatDeclarationLine _line(
  double percent,
  int net,
  int vat, {
  String category = 'S',
  String direction = 'output',
}) => VatDeclarationLine(
  percent: percent,
  category: category,
  grossCents: net + vat,
  netCents: net,
  vatCents: vat,
  invoiceCount: 1,
  direction: direction,
);

VatDeclaration _declaration(
  DateTime start,
  DateTime end,
  List<VatDeclarationLine> lines,
) => VatDeclaration(
  id: 'parity-declaration',
  workspaceId: 'parity-workspace',
  periodStart: start,
  periodEnd: end,
  status: 'prepared',
  lines: lines,
  totalNetCents: 0,
  totalVatCents: 0,
  currency: 'EUR',
  invoiceCount: 1,
  createdAt: DateTime.utc(2026, 10, 2),
  number: 'PARITY-1',
);

/// A country's party, its facts and the rates its ledger holds.
typedef _Country = ({
  VatFilingParty party,
  VatFilingFacts facts,
  List<double> rates,
});

final _countries = <String, _Country>{
  'DE': (
    party: const VatFilingParty(
      countryCode: 'DE',
      name: 'Raum GmbH',
      street: 'Hauptstr. 1',
      postalCode: '10115',
      city: 'Berlin',
      vatId: 'DE123456789',
      legalId: 'HRB 12345',
    ),
    facts: const VatFilingFacts(taxNumber: '21/815/08150'),
    rates: [19, 7],
  ),
  'FR': (
    party: const VatFilingParty(
      countryCode: 'FR',
      name: 'Espace & Cie',
      street: '1 rue du Pilote',
      postalCode: '34120',
      city: 'Pézenas',
      vatId: 'FR12345678901',
      legalId: '12345678900012',
    ),
    facts: const VatFilingFacts(),
    rates: [20, 10, 5.5],
  ),
  'GB': (
    party: const VatFilingParty(
      countryCode: 'GB',
      name: 'Space Ltd',
      street: '1 High Street',
      postalCode: 'EC1A 1BB',
      city: 'London',
      vatId: 'GB123456789',
      legalId: '01234567',
    ),
    facts: const VatFilingFacts(),
    rates: [20, 5],
  ),
  'CH': (
    party: const VatFilingParty(
      countryCode: 'CH',
      name: 'Raum AG',
      street: 'Bahnhofstrasse 1',
      postalCode: '8001',
      city: 'Zürich',
      vatId: 'CHE-116.281.710',
      legalId: 'CHE-116.281.710',
    ),
    facts: const VatFilingFacts(),
    rates: [8.1, 2.6],
  ),
  'CA': (
    party: const VatFilingParty(
      countryCode: 'CA',
      name: 'Espace Inc.',
      street: '1 rue Saint-Jean',
      postalCode: 'H2X 1Y1',
      city: 'Montréal',
      vatId: '123456789RT0001',
      legalId: '123456789',
    ),
    facts: const VatFilingFacts(),
    rates: [5],
  ),
  'ES': (
    party: const VatFilingParty(
      countryCode: 'ES',
      name: 'Espacio Coworking Peñíscola, S.L.',
      street: 'Calle Mayor 1',
      postalCode: '12598',
      city: 'Peñíscola',
      vatId: 'ESB12345678',
      legalId: 'B12345678',
    ),
    facts: const VatFilingFacts(),
    rates: [21, 10, 4],
  ),
  'IT': (
    party: const VatFilingParty(
      countryCode: 'IT',
      name: 'Spazio Srl',
      street: 'Via Roma 1',
      postalCode: '00100',
      city: 'Roma',
      vatId: 'IT12345678903',
      legalId: '12345678903',
    ),
    facts: const VatFilingFacts(),
    rates: [22, 10, 4],
  ),
};

/// Output sales at every rate, a zero-rated acquisition and some input VAT.
List<VatDeclarationLine> _owing(List<double> rates) => [
  for (final (i, r) in rates.indexed)
    _line(r, 100000 + i * 20000, ((100000 + i * 20000) * r / 100).round()),
  _line(0, 30000, 0, category: 'AE'),
  _line(
    rates.first,
    40000,
    (40000 * rates.first / 100).round(),
    direction: 'input',
  ),
];

/// More VAT deducted than due: a credit.
List<VatDeclarationLine> _credit(List<double> rates) => [
  _line(rates.first, 10000, (10000 * rates.first / 100).round()),
  _line(
    rates.first,
    90000,
    (90000 * rates.first / 100).round(),
    direction: 'input',
  ),
];

typedef _Case = ({
  String name,
  String country,
  VatDeclaration declaration,
  VatFilingParty party,
  VatFilingFacts facts,
});

List<_Case> _cases() {
  final cases = <_Case>[];
  for (final MapEntry(key: code, value: c) in _countries.entries) {
    void add(
      String name,
      VatDeclaration d, {
      VatFilingParty? party,
      VatFilingFacts? facts,
    }) {
      cases.add((
        name: '${code.toLowerCase()}_$name',
        country: code,
        declaration: d,
        party: party ?? c.party,
        facts: facts ?? c.facts,
      ));
    }

    final month = _declaration(
      DateTime(2026, 3),
      DateTime(2026, 3, 31),
      _owing(c.rates),
    );
    add('month', month);
    add(
      'quarter',
      _declaration(DateTime(2026, 7), DateTime(2026, 9, 30), _owing(c.rates)),
    );
    add(
      'credit',
      _declaration(DateTime(2026, 2), DateTime(2026, 2, 28), _credit(c.rates)),
    );
    add(
      'empty',
      _declaration(DateTime(2026, 4), DateTime(2026, 4, 30), const []),
    );
    // The refusals: the whole year is no monthly or quarterly period, and a
    // party with no identification at all.
    add(
      'year_refused',
      _declaration(DateTime(2026), DateTime(2026, 12, 31), _owing(c.rates)),
    );
    add(
      'unidentified_refused',
      month,
      party: VatFilingParty(
        countryCode: c.party.countryCode,
        name: c.party.name,
        street: c.party.street,
        postalCode: c.party.postalCode,
        city: c.party.city,
        vatId: '',
        legalId: '',
      ),
      facts: const VatFilingFacts(),
    );
  }
  // Targeted refusals the matrix above does not reach.
  VatFilingParty with_(VatFilingParty p, {String? vatId, String? legalId}) =>
      VatFilingParty(
        countryCode: p.countryCode,
        name: p.name,
        street: p.street,
        postalCode: p.postalCode,
        city: p.city,
        vatId: vatId ?? p.vatId,
        legalId: legalId ?? p.legalId,
        onReceipts: p.onReceipts,
      );
  final quarter = _declaration(
    DateTime(2026),
    DateTime(2026, 3, 31),
    _owing([22]),
  );
  final it = _countries['IT']!;
  cases.addAll([
    (
      name: 'it_no_fiscal_code_refused',
      country: 'IT',
      declaration: quarter,
      party: with_(it.party, legalId: ''),
      facts: it.facts,
    ),
    (
      name: 'it_unfinished_declarant_refused',
      country: 'IT',
      declaration: quarter,
      party: it.party,
      facts: const VatFilingFacts(declarantFiscalCode: 'RSSMRA80A01H501U'),
    ),
    (
      name: 'ch_bad_uid_refused',
      country: 'CH',
      declaration: quarter,
      party: with_(_countries['CH']!.party, vatId: 'CHE-123.456.789'),
      facts: const VatFilingFacts(),
    ),
    (
      name: 'ca_bad_business_number_refused',
      country: 'CA',
      declaration: quarter,
      party: with_(_countries['CA']!.party, vatId: '123456789'),
      facts: const VatFilingFacts(),
    ),
    (
      name: 'gb_bad_vrn_refused',
      country: 'GB',
      declaration: quarter,
      party: with_(_countries['GB']!.party, vatId: 'GB12'),
      facts: const VatFilingFacts(),
    ),
  ]);
  // A country without a file.
  final de = _countries['DE']!;
  cases.add((
    name: 'zz_unsupported_refused',
    country: 'ZZ',
    declaration: _declaration(
      DateTime(2026, 3),
      DateTime(2026, 3, 31),
      _owing([19]),
    ),
    party: VatFilingParty(
      countryCode: 'ZZ',
      name: de.party.name,
      street: de.party.street,
      postalCode: de.party.postalCode,
      city: de.party.city,
      vatId: '',
      legalId: '',
    ),
    facts: const VatFilingFacts(),
  ));
  return cases;
}

/// The encoding the country's channel reads: the Sede reads the Spanish 303
/// as ISO-8859-1, every other file is UTF-8.
Encoding _encodingOf(String country) => country == 'ES' ? latin1 : utf8;

void main() {
  test('the filing file of every case is byte-for-byte what it was', () async {
    final manifest = <String>[];
    final refusals = <String>[];
    final files = <String, List<int>>{};
    for (final c in _cases()) {
      // The product path: the seam the screen calls, which resolves the
      // installed add-on of the country (#3332: France is in its own package).
      final saved = <({List<int> bytes, String fileName})>[];
      final save = SaveVatFilingFile(
        ({required Uint8List bytes, required String fileName}) async {
          saved.add((bytes: bytes, fileName: fileName));
          return fileName;
        },
        () => _now,
        party: c.party,
      );
      try {
        await save(c.declaration, facts: c.facts);
        final file = saved.single;
        final encoding = _encodingOf(c.country);
        expect(
          encoding.decode(file.bytes),
          isNotEmpty,
          reason: '${c.name}: the bytes are in the encoding its channel reads',
        );
        files[c.name] = file.bytes;
        manifest.add(
          '${c.name} | ${file.fileName} | ${encoding.name} | '
          '${file.bytes.length}',
        );
      } on VatFilingFileException catch (e) {
        refusals.add('${c.name} | VatFilingFileException | ${e.problem.name}');
      } on UnsupportedError catch (e) {
        refusals.add('${c.name} | UnsupportedError | ${e.message}');
        expect(saved, isEmpty, reason: '${c.name}: a refusal saves nothing');
      }
    }
    final problems = VatFilingFileProblem.values.map((p) => p.name).join(',');
    expectParity(
      dir: _dir,
      text: {
        'manifest.txt': '${manifest.join('\n')}\n',
        'refusals.txt': '${refusals.join('\n')}\n\nproblems: $problems\n',
      },
      bytes: {for (final e in files.entries) '${e.key}.golden': e.value},
    );
  });
}
