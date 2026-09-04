// SPDX-License-Identifier: 0BSD
//
// #864 — the designer hands a design out as a file and takes one back.
// An import lands in the EDITOR, not in the workspace: nothing is stored
// until Save, which is what makes it reviewable before it counts.
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart' show XFile;
import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:deskilo/features/money/domain/report_design_file.dart';
import 'package:deskilo/features/money/domain/report_kind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'invoices_test.dart' show pumpInvoices, seededMoney;
import 'report_designer_test.dart' show openEditor;

const _invoice = ReportKind(id: 'invoice', slot: ReportRootSlot());
const _statement = ReportKind(id: 'statement', slot: ReportStatementSlot());

String _designFile(ReportKind kind, String header) => buildReportDesignFile(
      kind: kind,
      language: '',
      workspaceName: 'Test Space',
      bands: ReportBands(header: header, body: 'Body', footer: 'Footer'),
      exportedAt: DateTime.utc(2026, 9, 4),
    );

void main() {
  testWidgets('exporting writes a file that names the report and explains '
      'itself', (tester) async {
    String? savedName;
    List<int>? savedBytes;
    final money = await seededMoney();
    await pumpInvoices(
      tester,
      money: money,
      saver: ({required bytes, required fileName}) async {
        savedName = fileName;
        savedBytes = bytes;
        return 'Download/$fileName';
      },
    );
    await openEditor(tester);

    await tester.tap(find.byKey(const ValueKey('report-design-export')));
    await tester.pumpAndSettle();

    expect(savedName, endsWith('.json'));
    expect(savedName, contains('invoice'));
    final json =
        jsonDecode(utf8.decode(savedBytes!)) as Map<String, dynamic>;
    expect(json['kind'], 'invoice');
    expect(json['schema'], 'deskilo.report-design');
    expect((json['howToEdit'] as Map)['placeholders'],
        InvoicePdfTemplate.placeholders);
  });

  testWidgets('importing a design lands in the editor and is not stored '
      'until Save', (tester) async {
    final money = await seededMoney();
    await pumpInvoices(
      tester,
      money: money,
      picker: (group) async => XFile.fromData(
        Uint8List.fromList(utf8.encode(_designFile(_invoice, '# Imported'))),
        name: 'design.json',
      ),
    );
    await openEditor(tester);

    await tester.tap(find.byKey(const ValueKey('report-design-import')));
    await tester.pumpAndSettle();

    // In the editor…
    expect(find.textContaining('Design imported'), findsOneWidget);
    // …and NOT in the workspace: no save happened.
    expect(money.pdfTemplate.invoiceBands.header, isNot(contains('Imported')));

    await tester.tap(find.byKey(const ValueKey('invoice-template-save')));
    await tester.pumpAndSettle();
    expect(money.pdfTemplate.invoiceBands.header, contains('Imported'));
  });

  testWidgets('a design for another report is refused with the reason',
      (tester) async {
    final money = await seededMoney();
    await pumpInvoices(
      tester,
      money: money,
      picker: (group) async => XFile.fromData(
        Uint8List.fromList(utf8.encode(_designFile(_statement, '# Wrong'))),
        name: 'design.json',
      ),
    );
    await openEditor(tester);

    await tester.tap(find.byKey(const ValueKey('report-design-import')));
    await tester.pumpAndSettle();

    expect(find.textContaining('belongs to a different report'),
        findsOneWidget);
    expect(money.pdfTemplate.invoiceBands.header, isNot(contains('Wrong')));
  });

  testWidgets('an unreadable file is refused, and nothing changes',
      (tester) async {
    final money = await seededMoney();
    await pumpInvoices(
      tester,
      money: money,
      picker: (group) async => XFile.fromData(
        Uint8List.fromList(utf8.encode('{not json')),
        name: 'design.json',
      ),
    );
    await openEditor(tester);
    await tester.tap(find.byKey(const ValueKey('report-design-import')));
    await tester.pumpAndSettle();
    expect(find.textContaining('not readable JSON'), findsOneWidget);
  });

  testWidgets('with the flag off neither action is offered', (tester) async {
    final money = await seededMoney();
    await pumpInvoices(
      tester,
      money: money,
      workspace: FakeWorkspaceRepository.withWorkspace(
          featureFlags: const {'reportDesignExchange': false}),
    );
    await openEditor(tester);
    expect(find.byKey(const ValueKey('report-design-export')), findsNothing);
    expect(find.byKey(const ValueKey('report-design-import')), findsNothing);
  });
}
