// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3331 closure rows, through `SaveVatFilingFile` (the saving seam the screen
// calls) and the installed add-ons:
//  1. a country with no add-on is refused as unsupported, the file saver is
//     never called, and the generic VAT return is still available;
//  2. every invalid fixture is refused with the same problem and the same
//     sentence as the direct writer, and nothing is saved;
//  3. the digest of the artifact is the SHA-256 of exactly the bytes the saver
//     was given (ES: ISO-8859-1 accents; GB: CRLF);
//  4. A/B/A with two reference snapshots: the add-ons that still read the
//     application's installed tax reference (through `vatFormBoxes`) write the
//     same bytes when the first snapshot is installed again, and different
//     ones under the second -- the dependency is real and stated, and it does
//     not drift (the French add-on carries its boxes in its input from #3332).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:deskilo/core/jurisdiction/jurisdiction_resolver.dart';
import 'package:deskilo/core/vat/tax_reference.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/application/jurisdiction/filing_context_builder.dart';
import 'package:deskilo/features/money/application/jurisdiction/installed_vat_filings.dart';
import 'package:deskilo/features/money/application/save_vat_filing_file.dart';
import 'package:deskilo/features/money/domain/vat_declaration.dart';
import 'package:deskilo/features/money/domain/vat_filing_files.dart';
import 'package:deskilo/features/money/domain/vat_form_catalogue.dart';
import 'package:deskilo/features/money/presentation/vat_filing_file_actions.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 10, 2, 12);

VatDeclarationLine _line(
  double percent,
  int net,
  int vat, {
  String direction = 'output',
}) => VatDeclarationLine(
  percent: percent,
  category: 'S',
  grossCents: net + vat,
  netCents: net,
  vatCents: vat,
  invoiceCount: 1,
  direction: direction,
);

VatDeclaration _declaration(DateTime start, DateTime end, double rate) =>
    VatDeclaration(
      id: 'd',
      workspaceId: 'w',
      periodStart: start,
      periodEnd: end,
      status: 'prepared',
      lines: [
        _line(rate, 100000, (100000 * rate / 100).round()),
        _line(rate, 40000, (40000 * rate / 100).round(), direction: 'input'),
      ],
      totalNetCents: 0,
      totalVatCents: 0,
      currency: 'EUR',
      invoiceCount: 1,
      createdAt: DateTime.utc(2026, 10, 2),
      number: 'ROW-1',
    );

VatDeclaration _month(double rate) =>
    _declaration(DateTime(2026, 3), DateTime(2026, 3, 31), rate);

VatFilingParty _party(
  String country, {
  String name = 'Space',
  String vatId = '',
  String legalId = '',
}) => VatFilingParty(
  countryCode: country,
  name: name,
  street: 'Main street 1',
  postalCode: '10115',
  city: 'City',
  vatId: vatId,
  legalId: legalId,
);

class _Saver {
  final calls = <({Uint8List bytes, String fileName})>[];

  Future<String?> call({
    required Uint8List bytes,
    required String fileName,
  }) async {
    calls.add((bytes: bytes, fileName: fileName));
    return 'saved';
  }
}

SaveVatFilingFile _save(_Saver saver, VatFilingParty? party) =>
    SaveVatFilingFile(saver.call, () => _now, party: party);

CapabilityResolution resolveFor(VatFilingParty party) => resolveCapability(
  JurisdictionOperation.vatFiling,
  LegalContext(countryCode: party.countryCode),
  installedVatFilings,
);

String _sha(List<int> bytes) => crypto.sha256.convert(bytes).toString();

void main() {
  final l10n = AppLocalizationsEn();

  group('row 1: a country with no add-on', () {
    for (final country in ['ZZ', 'NO', 'US', '']) {
      test('"$country" is refused as unsupported, saves nothing, and the '
          'generic VAT return stays available', () async {
        final saver = _Saver();
        final save = _save(saver, _party(country));
        expect(save.country, isNull, reason: 'the screen offers no file');
        expect(() => save(_month(19)), throwsA(isA<UnsupportedError>()));
        expect(saver.calls, isEmpty);
        final generic = genericVatForm(_month(19).lines);
        expect(
          generic.boxes,
          isNotEmpty,
          reason: 'the return itself still has its per-rate boxes',
        );
      });
    }
  });

  // The stable problem each invalid fixture has always been refused with (the
  // writers left the dispatcher for their packages, #3332/#3333, so the
  // reference is this table, not a call).
  const expectedProblem = {
    'DE year': VatFilingFileProblem.period,
    'DE no tax number': VatFilingFileProblem.taxNumber,
    'GB no VRN': VatFilingFileProblem.vatNumber,
    'CH bad UID': VatFilingFileProblem.uid,
    'CA bad business number': VatFilingFileProblem.businessNumber,
    'ES no VAT id': VatFilingFileProblem.vatNumber,
    'IT no fiscal code': VatFilingFileProblem.fiscalCode,
  };

  group('row 2: an invalid fixture is refused with its stable problem', () {
    final fixtures =
        <
          String,
          ({VatFilingParty party, VatDeclaration d, VatFilingFacts facts})
        >{
          'DE year': (
            party: _party('DE', vatId: 'DE123456789'),
            d: _declaration(DateTime(2026), DateTime(2026, 12, 31), 19),
            facts: const VatFilingFacts(taxNumber: '21/815/08150'),
          ),
          'DE no tax number': (
            party: _party('DE', vatId: 'DE123456789'),
            d: _month(19),
            facts: const VatFilingFacts(),
          ),
          'GB no VRN': (
            party: _party('GB'),
            d: _month(20),
            facts: const VatFilingFacts(),
          ),
          'CH bad UID': (
            party: _party('CH', vatId: 'CHE-123.456.789'),
            d: _month(8.1),
            facts: const VatFilingFacts(),
          ),
          'CA bad business number': (
            party: _party('CA', vatId: '123456789'),
            d: _month(5),
            facts: const VatFilingFacts(),
          ),
          'ES no VAT id': (
            party: _party('ES'),
            d: _month(21),
            facts: const VatFilingFacts(),
          ),
          'IT no fiscal code': (
            party: _party('IT', vatId: 'IT12345678903'),
            d: _month(22),
            facts: const VatFilingFacts(),
          ),
        };
    for (final MapEntry(key: name, value: f) in fixtures.entries) {
      test(name, () async {
        final expected = expectedProblem[name];
        expect(expected, isNotNull, reason: 'the fixture really is invalid');
        final saver = _Saver();
        VatFilingFileException? thrown;
        try {
          await _save(saver, f.party)(f.d, facts: f.facts);
        } on VatFilingFileException catch (e) {
          thrown = e;
        }
        expect(thrown, isNotNull, reason: 'refused, not saved');
        expect(thrown!.problem, expected);
        expect(saver.calls, isEmpty);
        // the screen words the problem it is given: the same sentence
        expect(
          vatFilingProblemText(l10n, thrown.problem),
          vatFilingProblemText(l10n, expected!),
        );
        expect(vatFilingProblemText(l10n, thrown.problem), isNotEmpty);
      });
    }
  });

  group('row 3: the digest is the hash of exactly the saved bytes', () {
    Future<void> check(
      VatFilingParty party,
      VatDeclaration d,
      VatFilingFacts facts,
      void Function(Uint8List bytes) expectBytes,
    ) async {
      final saver = _Saver();
      await _save(saver, party)(d, facts: facts);
      expect(saver.calls, hasLength(1));
      final bytes = saver.calls.single.bytes;
      final contribution = (resolveFor(party) as Resolved).contribution;
      final context = filingContextOf(
        declaration: d,
        party: party,
        now: _now,
        facts: facts,
      );
      final artifact = contribution.build(
        contribution.validate(context).filing!,
      );
      expect(artifact.sha256, _sha(bytes));
      expect(artifact.bytes, bytes);
      expect(artifact.fileName, saver.calls.single.fileName);
      expectBytes(bytes);
    }

    test('ES: ISO-8859-1, one byte per accented letter', () async {
      await check(
        _party('ES', name: 'Espacio Peñíscola, S.L.', vatId: 'ESB12345678'),
        _month(21),
        const VatFilingFacts(),
        (bytes) {
          // the register upper-cases the name: Ñ and Í are one byte each
          expect(bytes, contains(0xD1), reason: 'Ñ is one byte in latin1');
          expect(
            bytes,
            isNot(contains(0xC3)),
            reason: 'no UTF-8 lead byte: it was not written as UTF-8',
          );
        },
      );
    });

    test('GB: the CSV keeps its CRLF', () async {
      await check(
        _party('GB', vatId: 'GB123456789'),
        _month(20),
        const VatFilingFacts(),
        (bytes) {
          final text = latin1.decode(bytes);
          expect(text, contains('\r\n'));
          expect(
            text.replaceAll('\r\n', ''),
            isNot(contains('\n')),
            reason: 'every line break is CRLF',
          );
        },
      );
    });
  });

  group('row 4: A/B/A with two reference snapshots', () {
    late TaxReferenceSet a;
    late TaxReferenceSet b;

    setUp(() {
      a = ActiveTaxReference.current;
      // B: the same reference without the form boxes of the countries below,
      // as another installation (or another revision) would hold it.
      final rows = [
        for (final r in jsonDecode(
          File('assets/instance/tax_reference.json').readAsStringSync(),
        ) as List)
          if (!((r as Map)['domain'] == 'form_box' &&
              const {'FR', 'DE'}.contains(r['country'])))
            r,
      ];
      b = TaxReferenceSet.parse(rows, origin: TaxReferenceOrigin.bundle);
    });
    tearDown(() => ActiveTaxReference.install(a));

    Uint8List write(
      String country,
      VatFilingParty party,
      VatFilingFacts facts,
    ) {
      final d = _month(country == 'FR' ? 20 : 19);
      final contribution = (resolveFor(party) as Resolved).contribution;
      final checked = contribution.validate(
        filingContextOf(declaration: d, party: party, now: _now, facts: facts),
      );
      return contribution.build(checked.filing!).bytes;
    }

    for (final (country, party, facts) in [
      (
        'FR',
        _party('FR', vatId: 'FR12123456789', legalId: '12345678900012'),
        const VatFilingFacts(),
      ),
      (
        'DE',
        _party('DE', vatId: 'DE123456789'),
        const VatFilingFacts(taxNumber: '21/815/08150'),
      ),
    ]) {
      test('$country: A, B, A', () {
        final first = write(country, party, facts);
        ActiveTaxReference.install(b);
        expect(
          () => write(country, party, facts),
          throwsA(isA<TaxReferenceUnavailable>()),
          reason:
              'the add-on reads the installed reference (stated): the '
              'snapshot without its form boxes cannot be filed from',
        );
        ActiveTaxReference.install(a);
        final again = write(country, party, facts);
        expect(
          again,
          first,
          reason: 'the first snapshot writes the same bytes again',
        );
      });
    }
  });
}
