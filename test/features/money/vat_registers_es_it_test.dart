// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Spanish and Italian registers of issued invoices. The libro registro
// has the columns of the AEAT's normalised design (LSIJ.xlsx, shipped
// verbatim) in their order, one line per rate, the AEAT's keys derived
// from the category; the SII message validates against SuministroLR.xsd
// (VAT_FILING_SAMPLES_DIR + tool/vat_filing/validate.sh); the registro
// fatture emesse names the Natura of an exempt line: N4.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/core/files/xlsx.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/application/vat_register_files.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/vat_declaration.dart';
import 'package:deskilo/features/money/domain/vat_filing_files.dart';
import 'package:deskilo/features/money/domain/vat_rate.dart';
import 'package:deskilo/features/money/domain/vat_register_es.dart';
import 'package:deskilo/features/money/domain/vat_register_es_sii.dart';
import 'package:deskilo/features/money/domain/vat_register_it.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:xml/xml.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

Invoice _invoice(
  String number,
  DateTime issued, {
  required List<InvoiceVatTotal> vat,
  String vatId = 'ESB98765432',
  String country = 'ES',
  int total = 0,
  bool voided = false,
  String correctionReason = '',
}) => Invoice(
  id: number,
  workspaceId: 'ws-1',
  memberId: 'member-1',
  number: number,
  issuedAt: issued,
  title: 'Puesto fijo septiembre',
  lines: const [],
  totalCents: total,
  currency: 'EUR',
  memberName: 'Cliente',
  memberAddress: '',
  workspaceName: 'Demo',
  workspaceAddress: '',
  issuerName: '',
  signature: '',
  vatTotals: vat,
  voidedAt: voided ? issued : null,
  correctionReason: correctionReason,
  buyerParty: InvoiceParty(
    name: 'Ana',
    company: 'Cliente SL',
    country: country,
    vatId: vatId,
  ),
);

InvoiceVatTotal _total(double percent, int net, int vat, {String c = 'S'}) =>
    InvoiceVatTotal(
      percent: percent,
      category: c,
      grossCents: net + vat,
      netCents: net,
      vatCents: vat,
    );

/// The cells of one row of a sheet of the fixture, by column index.
Map<int, String> _fixtureRow(String path, String sheet, int row) {
  final archive = ZipDecoder().decodeBytes(File(path).readAsBytesSync());
  XmlDocument doc(String name) => XmlDocument.parse(
    utf8.decode(archive.findFile(name)!.content as List<int>),
  );
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
  final id = doc('xl/workbook.xml')
      .findAllElements('sheet')
      .firstWhere((s) => s.getAttribute('name') == sheet)
      .getAttribute('r:id');
  final target = rels[id]!.replaceFirst('/xl/', '');
  int column(String ref) =>
      RegExp('[A-Z]+')
          .stringMatch(ref)!
          .codeUnits
          .fold(0, (n, c) => n * 26 + c - 64) -
      1;
  final r = doc('xl/$target')
      .findAllElements('row')
      .firstWhere((e) => e.getAttribute('r') == '$row');
  return {
    for (final c in r.findElements('c'))
      if (c.getAttribute('t') == 's')
        column(
          c.getAttribute('r')!,
        ): shared[int.parse(c.getElement('v')!.innerText)]
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim(),
  };
}

void main() {
  final q3 = [
    _invoice(
      'F-2026-0007',
      DateTime(2026, 7, 3),
      vat: [
        _total(21, 100000, 21000),
        _total(0, 5000, 0, c: 'E'),
      ],
      total: 126000,
    ),
    _invoice(
      'F-2026-0008',
      DateTime(2026, 8, 10),
      vat: [_total(0, 30000, 0, c: 'AE')],
      vatId: 'FR12123456789',
      country: 'FR',
      total: 30000,
    ),
    _invoice(
      'F-2026-0009',
      DateTime(2026, 9),
      vat: [_total(21, -10000, -2100)],
      total: -12100,
      correctionReason: 'R1',
    ),
    _invoice(
      'F-2026-0010',
      DateTime(2026, 9, 2),
      vat: [_total(21, 1000, 210)],
      vatId: '',
      total: 1210,
    ),
    _invoice(
      'F-2026-0006',
      DateTime(2026, 7, 2),
      vat: [_total(21, 999, 210)],
      voided: true,
    ),
  ];

  group('libro registro de facturas expedidas (ES)', () {
    const design = 'test/fixtures/vat_filing/es_libro/LSIJ.xlsx';

    test('the design\'s columns, in its order', () {
      final groups = _fixtureRow(design, 'EXPEDIDAS_INGRESOS', 7);
      final columns = _fixtureRow(design, 'EXPEDIDAS_INGRESOS', 8);
      expect(groups.keys.toSet(), esLibroGroups.keys.toSet());
      for (final MapEntry(:key, :value) in esLibroGroups.entries) {
        expect(groups[key], startsWith(value), reason: 'group at $key');
      }
      expect(columns, esLibroColumns);
      final types = _fixtureRow(design, 'EXPEDIDAS_INGRESOS', 9);
      expect(types.keys.reduce((a, b) => a > b ? a : b) + 1, 36);
    });

    test('one line per rate, the AEAT keys from the category', () {
      final docs = registerDocuments(
        q3,
        from: DateTime(2026),
        to: DateTime(2026, 10),
      );
      expect(docs.map((d) => d.number), [
        'F-2026-0007',
        'F-2026-0008',
        'F-2026-0009',
        'F-2026-0010',
      ], reason: 'issue order, the voided document left out');
      final sheet = esLibroExpedidas(docs, activity: 'A038612');
      expect(sheet.name, 'EXPEDIDAS');
      final lines = sheet.rows.skip(2).toList();
      expect(lines, hasLength(5));
      for (final l in lines) {
        expect(l, hasLength(36));
      }
      Object? amount(Object? cell) => (cell! as XlsxAmount).value;
      final taxed = lines[0];
      expect(taxed.sublist(0, 6), [2026, '3T', 'A', '03', '8612', 'F1']);
      expect(taxed[8], '03/07/2026');
      expect(taxed.sublist(11, 20), [
        'F-2026-0007',
        null,
        '',
        '',
        'B98765432',
        'Cliente SL',
        '01',
        'S1',
        '',
      ]);
      expect(amount(taxed[20]), 1210.0, reason: 'base + cuota');
      expect(amount(taxed[21]), 1000.0);
      expect(taxed[22], 21.0);
      expect(amount(taxed[23]), 210.0);
      final exempt = lines[1];
      expect(exempt.sublist(17, 20), ['01', '', 'E1']);
      expect(
        amount(exempt[20]),
        50.0,
        reason: 'an exempt line totals its base',
      );
      expect(exempt[22], 0);
      final eu = lines[2];
      expect(eu.sublist(13, 16), ['02', 'FR', 'FR12123456789']);
      expect(eu[18], 'N2', reason: 'a B2B service across a border');
      expect(lines[3][5], 'R1', reason: 'the frozen rectification reason');
      expect(lines[4][5], 'F2', reason: 'no buyer identification');
    });

    test('an activity of the wrong shape is refused before the book', () {
      expect(isEsActivity('A038612'), isTrue);
      expect(isEsActivity(''), isTrue);
      expect(isEsActivity('X038612'), isFalse);
      expect(isEsActivity('A0386123'), isFalse);
    });
  });

  group('an empty period writes nothing', () {
    final files = VatRegisterFiles(
      party: const VatFilingParty(
        countryCode: 'ES',
        name: 'Cowork',
        street: '',
        postalCode: '',
        city: '',
        vatId: 'ESB12345678',
        legalId: '',
      ),
      invoices: () async => const [],
      declarations: () async => const [],
      reference: ActiveTaxReference.current,
    );
    final end = DateTime(2026, 9, 30);

    test('the libro, the 347, the annual sheet and the registro', () async {
      expect(await files.esLibro(end: end, activity: ''), isNull);
      expect(await files.es347(year: 2026, immediateSupply: false), isNull);
      expect(
        await files.annualSummary(
          year: 2026,
          header: const ['a', 'b', 'c', 'd'],
        ),
        isNull,
      );
      expect(
        await files.itRegistro(start: DateTime(2026, 7), end: end),
        isNull,
      );
      expect(await files.esSii(start: DateTime(2026, 7), end: end), isNull);
    });
  });

  test('a monthly filer\'s libro names the month', () {
    final sheet = esLibroExpedidas(
      registerDocuments(q3, from: DateTime(2026), to: DateTime(2026, 10)),
      activity: '',
      monthly: true,
    );
    expect(sheet.rows[2][1], '07');
    expect(sheet.rows[2].sublist(2, 5), ['', '', ''], reason: 'no activity');
  });

  group('SII facturas emitidas (ES)', () {
    test(
      'a valid message of the period, the breakdown the buyer calls for',
      () {
        final docs = registerDocuments(
          q3,
          from: DateTime(2026, 7),
          to: DateTime(2026, 10),
        );
        final xml = siiFacturasEmitidasXml(
          docs,
          vatId: 'ESB12345678',
          name: 'Cowork Peñíscola SL',
        );
        final dir = Platform.environment['VAT_FILING_SAMPLES_DIR'];
        if (dir != null && dir.isNotEmpty) {
          File('$dir/es_sii.xml')
            ..parent.createSync(recursive: true)
            ..writeAsStringSync(xml);
        }
        final root = XmlDocument.parse(xml).rootElement;
        final records = root.findElements('siiLR:RegistroLRFacturasEmitidas');
        expect(records, hasLength(4));
        final first = records.first;
        expect(first.findAllElements('sii:Periodo').single.innerText, '07');
        expect(
          first
              .findAllElements('sii:FechaExpedicionFacturaEmisor')
              .single
              .innerText,
          '03-07-2026',
        );
        expect(first.findAllElements('sii:DesgloseFactura'), hasLength(1));
        expect(
          first.findAllElements('sii:CausaExencion').single.innerText,
          'E1',
        );
        expect(
          first.findAllElements('sii:TipoNoExenta').single.innerText,
          'S1',
        );
        final foreign = records.elementAt(1);
        expect(
          foreign.findAllElements('sii:PrestacionServicios'),
          hasLength(1),
        );
        expect(
          foreign
              .findAllElements('sii:ImporteTAIReglasLocalizacion')
              .single
              .innerText,
          '300.00',
        );
        final credit = records.elementAt(2);
        expect(
          credit.findAllElements('sii:TipoFactura').single.innerText,
          'R1',
        );
        expect(
          credit.findAllElements('sii:TipoRectificativa').single.innerText,
          'I',
        );
        expect(
          credit.findAllElements('sii:ImporteTotal').single.innerText,
          '-121.00',
        );
      },
    );

    test('an invoice with more rates than the schema holds is refused', () {
      final many = _invoice(
        'F-2026-0099',
        DateTime(2026, 7, 9),
        vat: [for (var r = 1; r <= 7; r++) _total(r.toDouble(), 1000, 10 * r)],
      );
      expect(
        () => siiFacturasEmitidasXml([many], vatId: 'ESB12345678', name: 'X'),
        throwsA(
          isA<VatFilingFileException>().having(
            (e) => e.problem,
            'problem',
            VatFilingFileProblem.unmappedBox,
          ),
        ),
      );
    });

    test('the space names its NIF', () {
      expect(
        () => siiFacturasEmitidasXml(q3, vatId: 'ES12', name: 'X'),
        throwsA(
          isA<VatFilingFileException>().having(
            (e) => e.problem,
            'problem',
            VatFilingFileProblem.vatNumber,
          ),
        ),
      );
    });
  });

  group('registro fatture emesse (IT)', () {
    test('an exempt line names Natura N4', () {
      final csv = registroFattureEmesseCsv(
        [
          _invoice(
            'FT-2026-0003',
            DateTime(2026, 5, 4),
            vat: [
              _total(22, 10000, 2200),
              _total(0, 8000, 0, c: 'E'),
            ],
            vatId: 'IT01234567890',
            country: 'IT',
            total: 20200,
          ),
        ],
        from: DateTime(2026, 4),
        to: DateTime(2026, 7),
      );
      final lines = const LineSplitter().convert(csv);
      expect(lines.first, startsWith('numero;data;cliente;'));
      expect(
        lines[1],
        '"FT-2026-0003";2026-05-04;"Cliente SL";"IT01234567890";100.00;22.00;22.00;;202.00;EUR',
      );
      expect(
        lines[2],
        '"FT-2026-0003";2026-05-04;"Cliente SL";"IT01234567890";80.00;0.00;0.00;N4;202.00;EUR',
      );
    });
  });

  /// The declarations screen of a space changed by [change], with [money];
  /// what a button saved lands in [saved].
  Future<void> openDeclarations(
    WidgetTester tester,
    Map<String, List<int>> saved,
    Workspace Function(Workspace) change,
    FakeMoneyRepository money,
  ) async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    workspace.workspaces[0] = change(
      workspace.workspaces[0].copyWith(vatRegime: 'vat_registered'),
    );
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...standardTestOverrides(money: money, workspace: workspace),
          typedFileSaverProvider.overrideWithValue(({
            required bytes,
            required fileName,
          }) async {
            saved[fileName] = bytes;
            return SavedFile(fileName);
          }),
        ],
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    unawaited(GoRouter.of(context).push('/vat-declarations'));
    await tester.pumpAndSettle();
  }

  testWidgets('a Spanish space saves its libro, refusing a bad activity', (
    tester,
  ) async {
    final saved = <String, List<int>>{};
    final now = kTestNow;
    final money = FakeMoneyRepository()
      ..invoices.add(
        _invoice(
          'F-1',
          DateTime(now.year, now.month),
          vat: [_total(21, 1000, 210)],
        ),
      );
    await openDeclarations(
      tester,
      saved,
      (w) =>
          w.copyWith(countryCode: 'ES', vatId: 'ESB12345678', name: 'Cowork'),
      money,
    );
    expect(
      find.byKey(const ValueKey('vat-register-it-registro')),
      findsNothing,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('vat-register-es-libro')),
    );
    await tester.tap(find.byKey(const ValueKey('vat-register-es-libro')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('vat-register-activity')),
      'X1',
    );
    await tester.tap(find.byKey(const ValueKey('vat-register-activity-ok')));
    await tester.pumpAndSettle();
    expect(find.textContaining('A code from A to D'), findsOneWidget);
    expect(saved, isEmpty);
    await tester.enterText(
      find.byKey(const ValueKey('vat-register-activity')),
      'A038612',
    );
    await tester.tap(find.byKey(const ValueKey('vat-register-activity-ok')));
    await tester.pumpAndSettle();
    expect(saved.keys, ['${now.year}B12345678ECowork.xlsx']);
  });

  testWidgets('an Italian space saves its registro and the annual sheet', (
    tester,
  ) async {
    final saved = <String, List<int>>{};
    final now = kTestNow;
    final quarter = DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1);
    final money = FakeMoneyRepository()
      ..invoices.add(
        _invoice(
          'FT-1',
          quarter,
          vat: [_total(0, 8000, 0, c: 'E')],
          country: 'IT',
          vatId: 'IT01234567890',
          total: 8000,
        ),
      )
      ..vatDeclarations.add(
        VatDeclaration(
          id: 'd1',
          workspaceId: 'ws-1',
          periodStart: quarter,
          periodEnd: DateTime(quarter.year, quarter.month + 3, 0),
          status: 'prepared',
          lines: const [
            VatDeclarationLine(
              percent: 0,
              category: 'E',
              grossCents: 8000,
              netCents: 8000,
              vatCents: 0,
              invoiceCount: 1,
            ),
          ],
          totalNetCents: 8000,
          totalVatCents: 0,
          currency: 'EUR',
          invoiceCount: 1,
          createdAt: quarter,
        ),
      );
    await openDeclarations(
      tester,
      saved,
      (w) => w.copyWith(countryCode: 'IT', vatId: 'IT01234567890'),
      money,
    );
    expect(find.byKey(const ValueKey('vat-register-es-libro')), findsNothing);
    await tester.ensureVisible(
      find.byKey(const ValueKey('vat-register-it-registro')),
    );
    await tester.tap(find.byKey(const ValueKey('vat-register-it-registro')));
    await tester.pumpAndSettle();
    final csv = utf8.decode(saved.values.single);
    expect(csv, contains(';N4;'));
    await tester.ensureVisible(
      find.byKey(const ValueKey('vat-annual-summary')),
    );
    await tester.tap(find.byKey(const ValueKey('vat-annual-summary')));
    await tester.pumpAndSettle();
    expect(saved.keys, contains('vat-annual-summary-${now.year}.xlsx'));
  });
}
