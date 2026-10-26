// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Spanish and Italian filing files. The Modelo 303 file follows the
// AEAT's "diseño de registro" field for field: the layout the builder
// writes is read against the published workbook, shipped verbatim under
// test/fixtures/vat_filing/es_303/, and each page has the design's length.
// The LIPE is the fornitura IVP18 of the Agenzia delle Entrate; with
// VAT_FILING_SAMPLES_DIR set this test writes its samples there and
// tool/vat_filing/validate.sh reads them against the published XSD.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/features/money/domain/vat_declaration.dart';
import 'package:deskilo/features/money/domain/vat_filing_es.dart';
import 'package:deskilo/features/money/domain/vat_filing_es_layout.dart';
import 'package:deskilo/features/money/domain/vat_filing_files.dart';
import 'package:deskilo/features/money/domain/vat_filing_it.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
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
  List<VatDeclarationLine> lines,
) => VatDeclaration(
  id: 'd1',
  workspaceId: 'ws-1',
  periodStart: start,
  periodEnd: end,
  status: 'prepared',
  lines: lines,
  totalNetCents: 0,
  totalVatCents: 0,
  currency: 'EUR',
  invoiceCount: lines.length,
  createdAt: DateTime.utc(2026, 10, 2),
);

Matcher _refused(VatFilingFileProblem problem) => throwsA(
  isA<VatFilingFileException>().having((e) => e.problem, 'problem', problem),
);

/// The rows of one sheet of an .xlsx: column letter → text.
List<Map<String, String>> _sheetRows(String path, String sheetName) {
  final archive = ZipDecoder().decodeBytes(File(path).readAsBytesSync());
  XmlDocument doc(String name) =>
      XmlDocument.parse(_utf8(archive.findFile(name)!.content as List<int>));
  final shared = [
    for (final si in doc('xl/sharedStrings.xml').findAllElements('si'))
      si.findAllElements('t').map((t) => t.innerText).join(),
  ];
  final rels = {
    for (final r in doc(
      'xl/_rels/workbook.xml.rels',
    ).findAllElements('Relationship'))
      r.getAttribute('Id')!: r.getAttribute('Target')!,
  };
  final sheet = doc('xl/workbook.xml')
      .findAllElements('sheet')
      .firstWhere((s) => s.getAttribute('name') == sheetName);
  final target = rels[sheet.getAttribute('r:id')]!.replaceFirst('/xl/', '');
  return [
    for (final row in doc('xl/$target').findAllElements('row'))
      {
        for (final c in row.findElements('c'))
          RegExp('[A-Z]+').stringMatch(c.getAttribute('r')!)!: switch (c
              .getAttribute('t')) {
            's' => shared[int.parse(c.getElement('v')!.innerText)],
            'inlineStr' =>
              c.findAllElements('t').map((t) => t.innerText).join(),
            _ => c.getElement('v')?.innerText ?? '',
          }.trim(),
      },
  ];
}

String _utf8(List<int> bytes) => utf8.decode(bytes);

void _writeSample(String name, String text) {
  final dir = Platform.environment['VAT_FILING_SAMPLES_DIR'];
  if (dir == null || dir.isEmpty) return;
  File('$dir/$name')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(text);
}

void main() {
  group('Modelo 303 (ES)', () {
    const dr = 'test/fixtures/vat_filing/es_303/DR303e26v101.xlsx';
    const kinds = {
      'An': Aeat303Kind.alphanumeric,
      'A': Aeat303Kind.alphanumeric,
      'Num': Aeat303Kind.unsigned,
      'N': Aeat303Kind.signed,
    };

    for (final MapEntry(key: page, value: fields) in aeat303Pages.entries) {
      test('page $page is the design, field for field', () {
        final rows = [
          for (final r in _sheetRows(dr, 'DP303${page.substring(0, 2)}'))
            if (int.tryParse(r['A'] ?? '') != null &&
                int.tryParse(r['B'] ?? '') != null)
              r,
        ];
        expect(fields, hasLength(rows.length));
        for (final (i, row) in rows.indexed) {
          final f = fields[i];
          final what = 'field ${row['A']} ${row['E']}';
          expect(f.number, int.parse(row['A']!), reason: what);
          expect(f.position, int.parse(row['B']!), reason: what);
          expect(f.length, int.parse(row['C']!), reason: what);
          expect(f.kind, kinds[row['D']], reason: what);
          if (f.box case final box?) {
            expect(row['E'], contains('[$box]'), reason: what);
          }
          if (f.constant case final constant?) {
            expect(row['G'], contains('"$constant"'), reason: what);
          }
        }
        final total = _sheetRows(
          dr,
          'DP303${page.substring(0, 2)}',
        ).firstWhere((r) => r['A'] == 'TOTAL');
        final last = fields.last;
        expect(last.position + last.length - 1, int.parse(total['C']!));
      });
    }

    final quarter = _declaration(DateTime(2026, 7), DateTime(2026, 9, 30), [
      _line(21, 100000, 21000),
      _line(10, 20000, 2000),
      _line(0, 30000, 0, category: 'AE'),
      _line(21, 40000, 8400, direction: 'input'),
    ]);
    String file(
      VatDeclaration d, {
      VatFilingFacts facts = const VatFilingFacts(),
      String vatId = 'ESB12345678',
    }) => aeat303File(
      declaration: d,
      vatId: vatId,
      name: 'Espacio Coworking Peñíscola, S.L.',
      onReceipts: false,
      facts: facts,
    );
    String at(String text, int position, int length) =>
        text.substring(position - 1, position - 1 + length);

    test('the envelope, the identification and the casillas', () {
      final text = file(quarter);
      _writeSample('es_303.txt', text);
      expect(text, startsWith('<T303020263T0000><AUX>'));
      expect(text, endsWith('</T303020263T0000>'));
      final aux = text.indexOf('</AUX>') + '</AUX>'.length;
      expect(aux, 328, reason: 'the content starts at position 329');
      final page01 = text.substring(aux, aux + 1581);
      final page03 = text.substring(aux + 1581, aux + 1581 + 1017);
      expect(page01, startsWith('<T30301000>'));
      expect(page01, endsWith('</T30301000>'));
      expect(page03, startsWith('<T30303000>'));
      expect(page03, endsWith('</T30303000>'));
      expect(at(page01, 13, 1), 'I', reason: 'a result to pay');
      expect(at(page01, 14, 9), 'B12345678');
      expect(at(page01, 23, 80).trimRight(), 'ESPACIO COWORKING PEÑISCOLA S L');
      expect(at(page01, 103, 4), '2026');
      expect(at(page01, 107, 2), '3T');
      // 109-117: no foral import VAT, no REDEME, régimen general only, not
      // joint, no cash criterion either way, no prorrata, no insolvency.
      expect(at(page01, 109, 9), '223222222');
      expect(at(page01, 126, 5), ' 2000', reason: 'not in SII, Nota 3/4/8');
      // 21 %: casillas 07 (base) and 09 (cuota); 10 %: 04 and 06.
      expect(at(page01, 326, 17), '00000000000100000');
      expect(at(page01, 343, 5), '02100');
      expect(at(page01, 348, 17), '00000000000021000');
      expect(at(page01, 287, 17), '00000000000020000');
      expect(at(page01, 309, 17), '00000000000002000');
      expect(at(page01, 209, 17), '0' * 17, reason: 'nothing at 4 %');
      expect(at(page01, 696, 17), '00000000000023000', reason: '[27]');
      expect(at(page01, 713, 17), '00000000000040000', reason: '[28]');
      expect(at(page01, 730, 17), '00000000000008400', reason: '[29]');
      expect(at(page01, 1019, 17), '00000000000014600', reason: '[46]');
      expect(at(page03, 12, 17), '00000000000030000', reason: '[59]');
      expect(at(page03, 216, 5), '10000', reason: '[65] 100 %');
      expect(at(page03, 408, 17), '00000000000014600', reason: '[71]');
    });

    test('a negative result is compensated and carries its N', () {
      final text = file(
        _declaration(DateTime(2026, 4), DateTime(2026, 4, 30), [
          _line(21, 1000, 210),
          _line(21, 10000, 2100, direction: 'input'),
        ]),
        facts: const VatFilingFacts(monthlyRefund: true),
      );
      final page01 = text.substring(328, 328 + 1581);
      expect(at(page01, 13, 1), 'C');
      expect(at(page01, 107, 2), '04');
      expect(at(page01, 110, 1), '1', reason: 'REDEME');
      expect(at(page01, 130, 1), '2', reason: 'Nota 8 from February on');
      expect(at(page01, 1019, 17), 'N0000000000001890');
    });

    test('what the file cannot say refuses it', () {
      expect(
        () => file(_declaration(DateTime(2026), DateTime(2026, 12, 31), [])),
        _refused(VatFilingFileProblem.period),
      );
      expect(
        () => file(quarter, vatId: 'ES12'),
        _refused(VatFilingFileProblem.vatNumber),
      );
      expect(
        () => file(
          _declaration(DateTime(2026, 7), DateTime(2026, 9, 30), [
            _line(5, 1000, 50),
          ]),
        ),
        _refused(VatFilingFileProblem.unmappedBox),
      );
      expect(
        () => file(
          _declaration(DateTime(2026, 7), DateTime(2026, 9, 30), [
            _line(21, -1000, -210),
          ]),
        ),
        _refused(VatFilingFileProblem.negativeAmount),
      );
      expect(
        () => file(
          _declaration(DateTime(2026, 10), DateTime(2026, 12, 31), []),
          facts: const VatFilingFacts(immediateSupply: true),
        ),
        _refused(VatFilingFileProblem.annualVolume),
      );
    });

    test('the dispatcher writes it as ISO-8859-1', () {
      final f = vatFilingFile(
        declaration: quarter,
        party: const VatFilingParty(
          countryCode: 'ES',
          name: 'Cowork',
          street: '',
          postalCode: '',
          city: '',
          vatId: 'ESB12345678',
          legalId: '',
        ),
        now: DateTime(2026, 10, 2),
      );
      expect(f.fileName, 'modelo-303-2026-07-01.txt');
      expect(f.encoding.name, 'iso-8859-1');
    });
  });

  group('LIPE (IT)', () {
    final quarter = _declaration(DateTime(2026, 4), DateTime(2026, 6, 30), [
      _line(22, 100000, 22000),
      _line(0, 50000, 0, category: 'E'),
      _line(22, 30000, 6600, direction: 'input'),
    ]);
    String lipe(
      VatDeclaration d, {
      VatFilingFacts facts = const VatFilingFacts(
        declarantFiscalCode: 'RSSMRA80A01H501U',
        declarantRole: '1',
      ),
      String vatId = 'IT01234567890',
      String fiscalCode = '01234567890',
    }) => lipeXml(
      declaration: d,
      vatId: vatId,
      fiscalCode: fiscalCode,
      facts: facts,
    );

    test('one Modulo of the quarter, VP2-VP6 and VP14', () {
      final text = lipe(quarter);
      _writeSample('it_lipe.xml', text);
      final root = XmlDocument.parse(text).rootElement;
      expect(root.name.qualified, 'iv:Fornitura');
      expect(
        root.getAttribute('xmlns:iv'),
        'urn:www.agenziaentrate.gov.it:specificheTecniche:sco:ivp',
      );
      String at(String path) {
        var node = root;
        for (final part in path.split('/')) {
          node = node.getElement('iv:$part')!;
        }
        return node.innerText;
      }

      expect(at('Intestazione/CodiceFornitura'), 'IVP18');
      expect(at('Comunicazione/Frontespizio/CodiceFiscale'), '01234567890');
      expect(at('Comunicazione/Frontespizio/AnnoImposta'), '2026');
      expect(at('Comunicazione/Frontespizio/PartitaIVA'), '01234567890');
      expect(
        at('Comunicazione/Frontespizio/CFDichiarante'),
        'RSSMRA80A01H501U',
      );
      expect(at('Comunicazione/Frontespizio/CodiceCaricaDichiarante'), '1');
      const m = 'Comunicazione/DatiContabili/Modulo';
      expect(at('$m/Trimestre'), '2');
      expect(at('$m/TotaleOperazioniAttive'), '1500,00');
      expect(at('$m/TotaleOperazioniPassive'), '300,00');
      expect(at('$m/IvaEsigibile'), '220,00');
      expect(at('$m/IvaDetratta'), '66,00');
      expect(at('$m/IvaDovuta'), '154,00');
      expect(at('$m/ImportoDaVersare'), '154,00');
    });

    test('a month with more VAT deducted than due carries the credit', () {
      final text = lipe(
        _declaration(DateTime(2026, 5), DateTime(2026, 5, 31), [
          _line(22, 1000, 220),
          _line(22, 10000, 2200, direction: 'input'),
        ]),
        facts: const VatFilingFacts(),
        fiscalCode: 'RSSMRA80A01H501U',
      );
      _writeSample('it_lipe_month.xml', text);
      expect(text, contains('<iv:Mese>5</iv:Mese>'));
      expect(text, contains('<iv:IvaCredito>19,80</iv:IvaCredito>'));
      expect(text, contains('<iv:ImportoACredito>19,80</iv:ImportoACredito>'));
      expect(text, isNot(contains('CFDichiarante')));
    });

    test('what the file cannot say refuses it', () {
      expect(
        () => lipe(quarter, vatId: 'IT123'),
        _refused(VatFilingFileProblem.vatNumber),
      );
      expect(
        () => lipe(quarter, fiscalCode: ''),
        _refused(VatFilingFileProblem.fiscalCode),
      );
      expect(
        () => lipe(
          quarter,
          facts: const VatFilingFacts(declarantFiscalCode: 'RSSMRA80A01H501U'),
        ),
        _refused(VatFilingFileProblem.declarant),
      );
      expect(
        () => lipe(_declaration(DateTime(2026), DateTime(2026, 12, 31), [])),
        _refused(VatFilingFileProblem.period),
      );
    });
  });

  /// The declarations screen of a space of [change]'s country with one
  /// prepared quarter; what the filing button saved lands in [saved].
  Future<void> openDeclarations(
    WidgetTester tester,
    Map<String, List<int>> saved,
    Workspace Function(Workspace) change,
    List<VatDeclarationLine> lines,
  ) async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    workspace.workspaces[0] = change(
      workspace.workspaces[0].copyWith(vatRegime: 'vat_registered'),
    );
    final money = FakeMoneyRepository()
      ..vatDeclarations.add(
        _declaration(DateTime(2026, 7), DateTime(2026, 9, 30), lines),
      );
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
  }

  testWidgets('a Spanish space states its registers and saves the 303 file', (
    tester,
  ) async {
    final saved = <String, List<int>>{};
    await openDeclarations(
      tester,
      saved,
      (w) => w.copyWith(
        countryCode: 'ES',
        vatId: 'ESB12345678',
        name: 'Peñíscola Cowork',
      ),
      [_line(21, 100000, 21000)],
    );
    await tester.tap(find.byKey(const ValueKey('vat-filing-es-redeme')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('vat-filing-es-ok')));
    await tester.pumpAndSettle();
    expect(saved.keys, ['modelo-303-2026-07-01.txt']);
    final bytes = saved.values.single;
    final page01 = latin1.decode(bytes).substring(328);
    expect(page01.substring(22, 39).trimRight(), 'PEÑISCOLA COWORK');
    expect(bytes[328 + 22 + 2], 0xD1, reason: 'Ñ is one ISO-8859-1 byte');
    expect(page01.substring(109, 110), '1', reason: 'REDEME');
  });

  testWidgets('an Italian company names its declarant and saves the LIPE', (
    tester,
  ) async {
    final saved = <String, List<int>>{};
    await openDeclarations(
      tester,
      saved,
      (w) => w.copyWith(
        countryCode: 'IT',
        vatId: 'IT01234567890',
        legalId: '01234567890',
      ),
      [_line(22, 100000, 22000)],
    );
    await tester.enterText(
      find.byKey(const ValueKey('vat-filing-it-cf')),
      'RSSMRA80A01H501U',
    );
    await tester.enterText(
      find.byKey(const ValueKey('vat-filing-it-role')),
      '1',
    );
    await tester.tap(find.byKey(const ValueKey('vat-filing-it-ok')));
    await tester.pumpAndSettle();
    expect(saved.keys, ['lipe-2026-07-01.xml']);
    expect(
      utf8.decode(saved.values.single),
      contains('<iv:CFDichiarante>RSSMRA80A01H501U</iv:CFDichiarante>'),
    );
  });

  testWidgets('an Italian space without its codice fiscale is told so', (
    tester,
  ) async {
    final saved = <String, List<int>>{};
    await openDeclarations(
      tester,
      saved,
      (w) => w.copyWith(countryCode: 'IT', vatId: 'IT01234567890', legalId: ''),
      [_line(22, 100000, 22000)],
    );
    await tester.tap(find.byKey(const ValueKey('vat-filing-it-ok')));
    await tester.pumpAndSettle();
    expect(saved, isEmpty);
    expect(
      find.textContaining('codice fiscale of the workspace'),
      findsOneWidget,
    );
  });
}
