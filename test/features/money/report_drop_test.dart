// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3818 — a design file (.json) dropped on the report editor and a layout
// file (.xml) dropped on the layout panel take the SAME path as the picked
// ones: the same parse, the same refusals, the result lands in the editor
// and is stored only by Save. A file of another kind is refused in words.
import 'dart:convert';

import 'package:deskilo/core/files/file_drop_backend.dart';
import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:deskilo/features/money/domain/report_design_file.dart';
import 'package:deskilo/features/money/domain/report_kind.dart';
import 'package:deskilo/features/money/domain/report_layout_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_file_drop.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/screens/invoices.dart' show pumpInvoices, seededMoney;
import '../../helpers/screens/report_designer.dart' show openEditor;

const _invoice = ReportKind(id: 'invoice', slot: ReportRootSlot());

void main() {
  late FakeFileDrop drop;

  setUp(() => drop = FakeFileDrop());

  // The fake keeps one callback (the zone built last), so a test turns on
  // the one place it drives.
  Future<void> pump(WidgetTester tester, {required bool layouts}) async {
    final money = await seededMoney();
    await pumpInvoices(
      tester,
      money: money,
      workspace: FakeWorkspaceRepository.withWorkspace(
        featureFlags: {
          'reportDesignExchange': !layouts,
          'reportLayouts': layouts,
        },
      ),
      picker: (group) async => fail('the picker must not open for a drop'),
      overrides: drop.overrides(),
    );
    await openEditor(tester);
  }

  testWidgets('a dropped design file lands in the editor', (tester) async {
    await pump(tester, layouts: false);
    final file = buildReportDesignFile(
      kind: _invoice,
      language: '',
      workspaceName: 'Test Space',
      bands: const ReportBands(header: '# Dropped', body: 'B', footer: 'F'),
      exportedAt: DateTime.utc(2026, 11, 12),
    );
    drop.drop(DroppedItems([FakeDroppedFile('d.json', bytes: utf8.encode(file))]));
    await tester.pumpAndSettle();
    expect(find.textContaining('Design imported'), findsOneWidget);
  });

  testWidgets('a design drop of another kind is refused in words', (
    tester,
  ) async {
    await pump(tester, layouts: false);
    drop.drop(DroppedItems([FakeDroppedFile('d.png')]));
    await tester.pumpAndSettle();
    expect(find.textContaining('takes .json'), findsOneWidget);
    expect(find.textContaining('Design imported'), findsNothing);
  });

  testWidgets('an unreadable design file is refused like a picked one', (
    tester,
  ) async {
    await pump(tester, layouts: false);
    drop.drop(
      DroppedItems([FakeDroppedFile('d.json', bytes: utf8.encode('{not json'))]),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('not readable JSON'), findsOneWidget);
  });

  testWidgets('a dropped layout file lands in the editor', (tester) async {
    await pump(tester, layouts: true);
    final file = buildReportLayoutFile(
      kind: _invoice,
      language: '',
      workspaceName: 'Test Space',
      layoutXml:
          '<report-layout page="A4"><body><text>Hello</text></body></report-layout>',
      exportedAt: DateTime.utc(2026, 11, 12),
    );
    // The panel sits last in the page: scroll it into the built range.
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('report-layout-panel')),
      find.byType(Scrollable).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    drop.drop(DroppedItems([FakeDroppedFile('l.xml', bytes: utf8.encode(file))]));
    await tester.pumpAndSettle();
    expect(find.textContaining('Layout imported'), findsOneWidget);
  });
}
