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
import 'package:deskilo/features/money/domain/vat_filing_ech0217.dart';
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

final _british = [
  _line(20, 100099, 20020),
  _line(20, 69468, 13894, direction: 'input'),
];

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
  group('eCH-0217 (CH)', () {
    final d = _declaration(DateTime(2026, 7), DateTime(2026, 9, 30), [
      _line(8.1, 100049, 8104),
      _line(2.6, 20000, 520),
      _line(0, 20050, 0, category: 'E'),
      _line(0, 5000, 0, category: 'G'),
      _line(8.1, 6000, 486, direction: 'input'),
      _line(8.1, 3000, 243, direction: 'input', category: 'asset'),
    ]);
    String text({
      bool onReceipts = false,
      String uid = 'CHE-109.322.551 MWST',
    }) => ech0217Xml(
      declaration: d,
      uid: uid,
      organisationName: 'Cowork AG',
      onReceipts: onReceipts,
      generatedAt: DateTime.utc(2026, 10, 13, 8, 5, 9),
    );

    test('the declaration: header, turnover, the rates, the tax to pay', () {
      final root = XmlDocument.parse(text()).rootElement;
      expect(root.name.local, 'VATDeclaration');
      expect(root.getAttribute('xmlns'), 'http://www.ech.ch/xmlns/eCH-0217/2');
      String at(String path) {
        var node = root;
        for (final part in path.split('/')) {
          node = node.getElement(part)!;
        }
        return node.innerText;
      }

      expect(
        text(),
        contains('<eCH-0058:manufacturer>DesKilo</eCH-0058:manufacturer>'),
        reason: 'the application block lives in the eCH-0058 namespace',
      );
      expect(at('generalInformation/uid'), 'CHE109322551');
      expect(at('generalInformation/generationTime'), '2026-10-13T08:05:09');
      expect(at('generalInformation/reportingPeriodFrom'), '2026-07-01');
      expect(at('generalInformation/reportingPeriodTill'), '2026-09-30');
      expect(at('generalInformation/typeOfSubmission'), '1');
      expect(at('generalInformation/formOfReporting'), '1');
      expect(at('turnoverComputation/totalConsideration'), '1450.99');
      expect(at('turnoverComputation/suppliesToForeignCountries'), '50.00');
      expect(at('turnoverComputation/suppliesExemptFromTax'), '200.50');
      expect(
        root.getElement('turnoverComputation')!.getElement('suppliesAbroad'),
        isNull,
        reason: 'a zero amount is omitted, never sent empty',
      );
      final method = root.getElement('effectiveReportingMethod')!;
      expect(method.getElement('grossOrNet')!.innerText, '1');
      final rates = method
          .findElements('suppliesPerTaxRate')
          .map(
            (XmlElement e) => (
              e.getElement('taxRate')!.innerText,
              e.getElement('turnover')!.innerText,
            ),
          )
          .toList();
      expect(rates, [('8.10', '1000.49'), ('2.60', '200.00')]);
      expect(
        method.getElement('inputTaxMaterialAndServices')!.innerText,
        '4.86',
      );
      expect(method.getElement('inputTaxInvestments')!.innerText, '2.43');
      // 8.1 % of 1000.49 + 2.6 % of 200.00 - 4.86 - 2.43, summed unrounded.
      expect(root.getElement('payableTax')!.innerText, '78.95');
    });

    test('a space on the received consideration says so', () {
      expect(
        text(onReceipts: true, uid: 'CHE109322551'),
        contains('<formOfReporting>2</formOfReporting>'),
      );
    });

    test('a UID without a valid check digit gives no file', () {
      expect(
        () => text(uid: 'CHE-109.322.552 MWST'),
        throwsA(
          isA<VatFilingFileException>().having(
            (e) => e.problem,
            'problem',
            VatFilingFileProblem.uid,
          ),
        ),
      );
    });
  });

  group('MTD bridging file (GB)', () {
    final lines = [
      _line(20, 100099, 20020),
      _line(0, 20099, 0, category: 'Z'),
      _line(20, 69468, 13894, direction: 'input'),
    ];
    final d = _declaration(DateTime(2026, 7), DateTime(2026, 9, 30), lines);

    test('one row: the nine boxes under HMRC field names, pence in 1-5, '
        'whole pounds in 6-9', () {
      final csv = mtdBridgingCsv(declaration: d, vatId: 'GB 123 4567 89');
      final rows = csv.trim().split('\r\n');
      expect(rows, hasLength(2));
      final head = rows[0].split(',');
      final row = rows[1].split(',');
      final byName = {for (var i = 0; i < head.length; i++) head[i]: row[i]};
      expect(byName['vrn'], '123456789');
      expect(byName['periodStart'], '2026-07-01');
      expect(byName['periodEnd'], '2026-09-30');
      expect(byName['vatDueSales'], '200.20');
      expect(byName['vatDueAcquisitions'], '0.00');
      expect(byName['totalVatDue'], '200.20');
      expect(byName['vatReclaimedCurrPeriod'], '138.94');
      expect(byName['netVatDue'], '61.26');
      expect(
        byName['totalValueSalesExVAT'],
        '1201',
        reason: 'sales and zero-rated supplies, the pence dropped',
      );
      expect(byName['totalValuePurchasesExVAT'], '694');
      expect(byName['totalValueGoodsSuppliedExVAT'], '0');
      expect(byName['totalAcquisitionsExVAT'], '0');
      expect(csv, endsWith('\r\n'));
    });

    test('without a registration number there is no file', () {
      expect(
        () => mtdBridgingCsv(declaration: d, vatId: 'GB12'),
        throwsA(isA<VatFilingFileException>()),
      );
    });

    test('a UK space gets this file', () {
      const party = VatFilingParty(
        countryCode: 'GB',
        name: 'Desks Ltd',
        street: '1 High St',
        postalCode: 'N1 1AA',
        city: 'London',
        vatId: 'GB123456789',
        legalId: '12345678',
      );
      final file = vatFilingFile(
        declaration: d,
        party: party,
        now: DateTime(2026, 10, 2),
      );
      expect(file.fileName, 'mtd-vat-return-2026-07-01.csv');
      expect(file.text, startsWith('vrn,periodStart,'));
    });
  });

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

  testWidgets('a UK space saves the MTD bridging file of a prepared return', (
    tester,
  ) async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    workspace.workspaces[0] = workspace.workspaces[0].copyWith(
      vatRegime: 'vat_registered',
      countryCode: 'GB',
      vatId: 'GB123456789',
    );
    final money = FakeMoneyRepository()
      ..vatDeclarations.add(
        _declaration(DateTime(2026, 9), DateTime(2026, 9, 30), _british),
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
    // The VAT number is the workspace's own: no question is asked.
    expect(saved.keys, ['mtd-vat-return-2026-09-01.csv']);
    expect(
      String.fromCharCodes(saved.values.single),
      contains('123456789,2026-09-01,2026-09-30,'),
    );
  });
}
