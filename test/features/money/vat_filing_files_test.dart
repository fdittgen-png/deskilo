// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2357 — the filing-ready files of a prepared return. The ELSTER UStVA
// names the year, the month or quarter, the tax number and every
// Kennzahl the form filled (bases in whole euros, tax with cents, Kz 83
// always), and refuses an annual period or a missing tax number. The
// EDI-TVA CA3 is a structurally valid EDIFACT interchange: service
// string advice, envelope, a segment count that matches, released
// special characters, one LIN per CA3 line with its amounts in whole
// euros. The declarations screen saves the file of the space's country.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/features/money/domain/vat_declaration.dart';
import 'package:deskilo/features/money/domain/vat_filing_files.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:xml/xml.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

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
  List<VatDeclarationLine> lines, {
  String number = '',
}) => VatDeclaration(
  id: 'd1',
  workspaceId: 'ws-1',
  periodStart: start,
  periodEnd: end,
  status: 'prepared',
  lines: lines,
  totalNetCents: 0,
  totalVatCents: 0,
  currency: 'EUR',
  invoiceCount: 1,
  createdAt: DateTime.utc(2026, 10, 2),
  number: number,
);

final _german = [
  _line(19, 100099, 19019),
  _line(0, 20099, 0, category: 'AE'),
  _line(20, 69468, 13199, direction: 'input'),
];

String _elster(VatDeclaration d, {String taxNumber = '21/815/08150'}) =>
    elsterUstvaXml(
      declaration: d,
      taxNumber: taxNumber,
      name: 'Raum GmbH',
      street: 'Hauptstr. 1',
      postalCode: '10115',
      city: 'Berlin',
      createdOn: DateTime(2026, 10, 2),
    );

void main() {
  group('ELSTER UStVA', () {
    test('a month: the period, the tax number and the filled Kennzahlen', () {
      final xml = XmlDocument.parse(
        _elster(
          _declaration(DateTime(2026, 9), DateTime(2026, 9, 30), _german),
        ),
      );
      String text(String name) => xml.findAllElements(name).single.innerText;
      expect(xml.rootElement.name.local, 'Elster');
      expect(
        xml.rootElement.getAttribute('xmlns'),
        'http://www.elster.de/elsterxml/schema/v11',
      );
      expect(text('Jahr'), '2026');
      expect(text('Zeitraum'), '09');
      expect(text('Steuernummer'), '2181508150');
      expect(text('Kz81'), '1000', reason: 'a base in whole euros, cut');
      expect(text('Kz21'), '200');
      expect(text('Kz66'), '131.99', reason: 'a tax amount keeps its cents');
      expect(text('Kz83'), '58.20');
      expect(
        xml.findAllElements('Anmeldungssteuern').single.getAttribute('art'),
        'UStVA',
      );
    });

    test('a quarter is 41–44', () {
      final xml = _elster(
        _declaration(DateTime(2026, 7), DateTime(2026, 9, 30), _german),
      );
      expect(xml, contains('<Zeitraum>43</Zeitraum>'));
    });

    test('a credit is a negative Kz 83', () {
      final xml = _elster(
        _declaration(DateTime(2026, 9), DateTime(2026, 9, 30), [
          _line(19, 1000, 190),
          _line(19, 5000, 950, direction: 'input'),
        ]),
      );
      expect(xml, contains('<Kz83>-7.60</Kz83>'));
    });

    test('a year is not a UStVA period, and the tax number is required', () {
      expect(
        () => _elster(
          _declaration(DateTime(2026), DateTime(2026, 12, 31), _german),
        ),
        throwsA(
          isA<VatFilingFileException>().having(
            (e) => e.problem,
            'problem',
            VatFilingFileProblem.period,
          ),
        ),
      );
      expect(
        () => _elster(
          _declaration(DateTime(2026, 9), DateTime(2026, 9, 30), _german),
          taxNumber: '',
        ),
        throwsA(
          isA<VatFilingFileException>().having(
            (e) => e.problem,
            'problem',
            VatFilingFileProblem.taxNumber,
          ),
        ),
      );
    });
  });

  group('EDI-TVA CA3', () {
    String edi({
      String name = "L'Atelier + Co",
      String siren = '123 456 789',
    }) => ediTvaCa3(
      declaration: _declaration(DateTime(2026, 9), DateTime(2026, 9, 30), [
        _line(20, 100010, 20002),
        _line(20, 15750, 3150, direction: 'input'),
      ], number: 'DECL-2026-0007'),
      siren: siren,
      vatId: 'FR12123456789',
      name: name,
      street: '1 rue de la Paix',
      postalCode: '34120',
      city: 'Pézenas',
      createdAt: DateTime.utc(2026, 10, 2, 9, 30),
    );

    test('an envelope whose counts hold', () {
      final segments = edi().split('\n');
      expect(segments.first, "UNA:+.? '");
      expect(
        segments[1],
        "UNB+UNOC:3+123456789:ZZ+DGFIP:ZZ+261002:0930+DECL20260007'",
      );
      expect(segments.last, "UNZ+1+DECL20260007'");
      final unh = segments.indexWhere((s) => s.startsWith('UNH+'));
      final unt = segments.indexWhere((s) => s.startsWith('UNT+'));
      expect(
        segments[unt],
        "UNT+${unt - unh + 1}+1'",
        reason: 'UNT counts the message from UNH to UNT',
      );
      for (final s in segments.skip(1)) {
        expect(s.endsWith("'"), isTrue, reason: s);
      }
    });

    test('the declarant, released, and each CA3 line with its amounts', () {
      final text = edi();
      expect(text, contains("NAD+FR+123456789::107++L?'Atelier ?+ Co+"));
      expect(text, contains("RFF+VA:FR12123456789'"));
      expect(text, contains("DTM+194:20260901:102'"));
      expect(text, contains("DTM+206:20260930:102'"));
      expect(text, contains("LIN+2++08:0207:ZZ'\nMOA+125:1000'\nMOA+124:200'"));
      expect(
        text,
        contains(':0702:ZZ\'\nMOA+124:32\''),
        reason: 'line 20, deductible VAT 31,50 rounded up',
      );
      expect(
        text,
        contains(':8901:ZZ\'\nMOA+124:168\''),
        reason: 'line 28, VAT due 200 − 32',
      );
    });

    test('the SIREN: the registration number, else an FR VAT number', () {
      expect(frenchSiren(legalId: '123 456 789 00012', vatId: ''), '123456789');
      expect(frenchSiren(legalId: '', vatId: 'FR12123456789'), '123456789');
      expect(frenchSiren(legalId: '', vatId: ''), '');
    });

    test('a SIREN has nine digits', () {
      expect(() => edi(siren: '12'), throwsA(isA<VatFilingFileException>()));
    });
  });

  testWidgets('a German space saves the ELSTER file of a prepared return', (
    tester,
  ) async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    workspace.workspaces[0] = workspace.workspaces[0].copyWith(
      vatRegime: 'vat_registered',
      countryCode: 'DE',
      legalId: '21/815/08150',
    );
    final money = FakeMoneyRepository()
      ..vatDeclarations.add(
        _declaration(DateTime(2026, 9), DateTime(2026, 9, 30), _german),
      );
    final saved = <String, List<int>>{};
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...standardTestOverrides(money: money, workspace: workspace),
          fileSaverProvider.overrideWithValue(({
            required List<int> bytes,
            required String fileName,
          }) async {
            saved[fileName] = bytes;
            return '/tmp/$fileName';
          }),
        ],
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    unawaited(GoRouter.of(context).push('/vat-declarations'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('vat-decl-filing-d1')));
    await tester.pumpAndSettle();
    // The Steuernummer is asked, the registration number prefilled.
    expect(find.text('21/815/08150'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('vat-filing-tax-number-ok')));
    await tester.pumpAndSettle();
    expect(saved.keys, ['ustva-2026-09-01.xml']);
    expect(
      String.fromCharCodes(saved.values.single),
      contains('<Steuernummer>2181508150</Steuernummer>'),
    );
  });
}
