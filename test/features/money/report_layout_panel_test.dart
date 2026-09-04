// SPDX-License-Identifier: 0BSD
//
// #875 — the layout panel says which engine draws the document, and
// offers exactly the actions that make sense for that state.
//
// The one lie this guards against: a card that shows "Layout active"
// while the bands print, or offers "Remove layout" when there is none
// to remove. The panel is pure presentation — callbacks in, widgets out
// — so it is tested as such.
import 'package:deskilo/features/money/presentation/widgets/report_layout_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('without a layout: the chip says bands, export/import are '
      'offered, remove and preview are not', (tester) async {
    var exported = 0, imported = 0;
    await tester.pumpWidget(_wrap(ReportLayoutPanel(
      hasLayout: false,
      onExport: () => exported++,
      onImport: () => imported++,
      onRemove: () => fail('nothing to remove'),
      onPreview: () => fail('nothing to preview'),
    )));
    expect(find.text('Bands'), findsOneWidget);
    expect(find.byKey(const ValueKey('report-layout-remove')), findsNothing);
    expect(find.byKey(const ValueKey('report-layout-preview')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('report-layout-export')));
    await tester.tap(find.byKey(const ValueKey('report-layout-import')));
    expect((exported, imported), (1, 1));
  });

  testWidgets('with a layout: the chip says so, and remove + preview appear',
      (tester) async {
    var removed = 0, previewed = 0;
    await tester.pumpWidget(_wrap(ReportLayoutPanel(
      hasLayout: true,
      onExport: () {},
      onImport: () {},
      onRemove: () => removed++,
      onPreview: () => previewed++,
    )));
    expect(find.text('Layout active'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('report-layout-remove')));
    await tester.tap(find.byKey(const ValueKey('report-layout-preview')));
    expect((removed, previewed), (1, 1));
  });

  testWidgets('busy disables every action so a save in flight cannot race '
      'an import', (tester) async {
    await tester.pumpWidget(_wrap(ReportLayoutPanel(
      hasLayout: true,
      busy: true,
      onExport: () => fail('disabled'),
      onImport: () => fail('disabled'),
      onRemove: () => fail('disabled'),
      onPreview: () => fail('disabled'),
    )));
    for (final key in [
      'report-layout-export',
      'report-layout-import',
      'report-layout-remove',
      'report-layout-preview',
    ]) {
      final button = tester.widget<ButtonStyleButton>(
          find.byKey(ValueKey(key)));
      expect(button.onPressed, isNull, reason: key);
    }
  });
}
