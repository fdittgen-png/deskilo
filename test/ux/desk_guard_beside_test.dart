// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3860 — the desk guards guard what they gained: the page kind "a record
// beside its table" (its table keeps a floor, its pane the reading measure,
// together they fill the work area, no word is cut in a row, and the 60 %
// rule stays for a table alone), and the reading of a switch inside a tile
// that is itself the tap target.
import 'package:deskilo/core/demo/data/device_prefs.dart';
import 'package:deskilo/core/ui/kit/list_detail_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';
import 'experience_guards.dart';

const _window = Size(1440, 900);

/// A row of a planted table: its cells are as wide as they are given.
class _PlantedRow extends StatelessWidget {
  const _PlantedRow({required this.cellWidth});

  final double cellWidth;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 36,
    child: Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(width: cellWidth, child: const Text('STATUS')),
    ),
  );
}

Future<void> _pumpBeside(
  WidgetTester tester, {
  String? selected = 'a',
  double listMin = ListDetailMetrics.listMin,
  double cellWidth = 200,
  Size size = _window,
}) async {
  await pumpApp(
    tester,
    Scaffold(
      body: ListDetailScaffold(
        id: 'guard-beside',
        paneStore: InMemoryPaneWidthStore(),
        listMin: listMin,
        selected: selected,
        onClose: () {},
        list: _PlantedRow(cellWidth: cellWidth),
        detail: (_, _) => const Text('A record'),
      ),
    ),
    size: size,
  );
  await tester.pumpAndSettle();
}

Set<String> _problems(WidgetTester tester, PageKind kind) => deskGuardProblems(
  tester,
  kind: kind,
  size: _window,
  rowTypes: const [_PlantedRow],
);

void main() {
  setUpAll(() => loadSheetFonts(always: true));

  group('a record beside its table', () {
    testWidgets('a table and a pane that fill the work area pass', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpBeside(tester);
      expect(_problems(tester, PageKind.recordBesideTable), isEmpty);
      semantics.dispose();
    });

    testWidgets('the 60 % rule is for a table alone: a table of 600 in 1440 '
        'fails it, and beside a record the same window is not held to it', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        const Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: 600, child: _PlantedRow(cellWidth: 200)),
          ),
        ),
        size: _window,
      );
      expect(
        deskGuardProblems(
          tester,
          kind: PageKind.records,
          size: _window,
          rowTypes: const [_PlantedRow],
          tableTypes: const [_PlantedRow],
        ),
        contains('table under 60 %'),
      );
      await _pumpBeside(tester);
      expect(
        _problems(tester, PageKind.recordBesideTable),
        isNot(contains('table under 60 %')),
      );
      semantics.dispose();
    });

    testWidgets('no record open: there is no table beside one', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpBeside(tester, selected: null);
      expect(
        _problems(tester, PageKind.recordBesideTable),
        contains('no record beside the table'),
      );
      semantics.dispose();
    });

    testWidgets('a table squeezed under its floor fails', (tester) async {
      final semantics = tester.ensureSemantics();
      // A scaffold that lets the list go down to 100: in 800 the pane at
      // its default leaves the list 352.
      await _pumpBeside(tester, listMin: 100, size: const Size(800, 900));
      expect(
        besideTableProblems(tester),
        contains('table beside a record under 400'),
      );
      semantics.dispose();
    });

    testWidgets('a word cut across lines in a row fails', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpBeside(tester, cellWidth: 20);
      final details = <String>[];
      expect(
        deskGuardProblems(
          tester,
          kind: PageKind.recordBesideTable,
          size: _window,
          rowTypes: const [_PlantedRow],
          details: details,
        ),
        contains('a word cut across lines'),
      );
      expect(details.join(), contains('STATUS'));
      semantics.dispose();
    });
  });

  group('the table and the record beside it are two Tab groups', () {
    testWidgets('Tab walks the table, then the record, and leaves the record '
        'again: the pane does not keep it', (tester) async {
      final list = FocusNode(), pane = FocusNode();
      addTearDown(list.dispose);
      addTearDown(pane.dispose);
      await pumpApp(
        tester,
        Scaffold(
          body: ListDetailScaffold(
            id: 'guard-tab',
            paneStore: InMemoryPaneWidthStore(),
            selected: 'a',
            onClose: () {},
            list: TextButton(
              focusNode: list,
              onPressed: () {},
              child: const Text('List'),
            ),
            detail: (_, _) => TextButton(
              focusNode: pane,
              onPressed: () {},
              child: const Text('Record'),
            ),
          ),
        ),
        size: _window,
      );
      await tester.pumpAndSettle();
      list.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(pane.hasPrimaryFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(pane.hasPrimaryFocus, isFalse);
    });
  });

  group('a switch inside a tile that is the tap target', () {
    Future<void> pumpTile(WidgetTester tester, Widget tile) =>
        pumpApp(tester, Scaffold(body: tile), size: _window);

    testWidgets('a SwitchListTile is measured by the tile: the tile is the '
        '48 dp target and carries the name, the 60 x 40 switch inside it is '
        'the same action', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpTile(
        tester,
        SwitchListTile(
          secondary: const Icon(Icons.layers),
          title: const Text('Level'),
          subtitle: const Text('Allowed'),
          value: true,
          onChanged: (_) {},
        ),
      );
      expect(
        deskGuardProblems(tester, kind: PageKind.document, size: _window),
        isEmpty,
      );
      expect(guardProblems(tester, width: _window.width), isEmpty);
      semantics.dispose();
    });

    testWidgets('a switch that stands alone, unnamed and 60 x 40, still '
        'fails both rules', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpTile(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: Switch(
            value: true,
            onChanged: (_) {},
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      );
      final problems = deskGuardProblems(
        tester,
        kind: PageKind.document,
        size: _window,
      );
      expect(problems, containsAll(['target under 48 dp', 'unnamed control']));
      semantics.dispose();
    });

    testWidgets('a small button inside a tappable tile is still its own '
        'target: only a switch, checkbox or radio is read as the tile', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpTile(
        tester,
        ListTile(
          title: const Text('A tile'),
          onTap: () {},
          trailing: SizedBox(
            width: 32,
            height: 32,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'Small',
              onPressed: () {},
              icon: const Icon(Icons.add, size: 16),
            ),
          ),
        ),
      );
      expect(
        deskGuardProblems(tester, kind: PageKind.document, size: _window),
        contains('target under 48 dp'),
      );
      semantics.dispose();
    });
  });
}
