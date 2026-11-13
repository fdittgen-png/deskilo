// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3619 — sections beside the one shown: the chosen section is the one in
// view; the others stay mounted (a draft typed in one survives a visit to
// another) but are not painted, not read by a screen reader and never a Tab
// stop: Tab walks the list, then the shown section, then Save.
import 'package:deskilo/core/ui/kit/sections_beside.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({ValueKey<String>? saveKey}) => MaterialApp(
  home: Scaffold(
    body: AddressedSections(
      id: 't',
      sections: [
        for (final id in ['a', 'b'])
          BesideSection(
            id: id,
            title: 'Section $id',
            child: TextField(
              key: ValueKey('field-$id'),
              decoration: InputDecoration(labelText: 'Field $id'),
            ),
          ),
      ],
      footer: FilledButton(
        key: saveKey ?? const ValueKey('save'),
        onPressed: () {},
        child: const Text('Save'),
      ),
    ),
  ),
);

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();
}

/// The key of the widget holding the primary focus, among the ones named.
String? _focused(WidgetTester tester) {
  final focus = FocusManager.instance.primaryFocus?.context;
  if (focus == null) return null;
  for (final key in [
    't-section-a',
    't-section-b',
    'field-a',
    'field-b',
    'save',
  ]) {
    final found = find.byKey(ValueKey(key));
    if (found.evaluate().isEmpty) continue;
    final element = found.evaluate().first;
    var hit = element == focus;
    if (!hit) {
      focus.visitAncestorElements((a) {
        hit = a == element;
        return !hit;
      });
    }
    if (hit) return key;
  }
  return null;
}

void main() {
  testWidgets('the first section is shown; choosing one shows it instead', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Field a'), findsOneWidget);
    expect(find.text('Field b'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('t-section-b')));
    await tester.pumpAndSettle();
    expect(find.text('Field b'), findsOneWidget);
    expect(find.text('Field a'), findsNothing);
  });

  testWidgets('a hidden section keeps its draft and is not read', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);
    await tester.enterText(find.byKey(const ValueKey('field-a')), 'draft');
    await tester.tap(find.byKey(const ValueKey('t-section-b')));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Field a'), findsNothing);
    expect(find.bySemanticsLabel('Field b'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('t-section-a')));
    await tester.pumpAndSettle();
    expect(find.text('draft'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('Tab walks the list, the shown section and Save, never a '
      'hidden one', (tester) async {
    await _pump(tester);
    final walked = <String?>[];
    for (var i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      walked.add(_focused(tester));
    }
    expect(walked.take(4), ['t-section-a', 't-section-b', 'field-a', 'save']);
    expect(walked, isNot(contains('field-b')));
  });
}
