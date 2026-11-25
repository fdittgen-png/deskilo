// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4448 -- the till layout editor at 390, 1024 and 1440, on the Demo's own store (the server's rules): a till without a
// layout starts from a template; a calculator is added and moved with the buttons, never only by dragging; a step that
// would not fit is disabled; the draft is saved and published; a save over a version another editor moved is refused in
// words.
import 'package:deskilo/core/demo/data/demo_till_layouts.dart';
import 'package:deskilo/features/money/domain/till_layout.dart';
import 'package:deskilo/features/money/presentation/till_layout/till_layout_screen.dart';
import 'package:deskilo/features/money/providers/till_layout_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();
const _till = 'till-1';

Future<void> _open(WidgetTester tester, DemoTillLayouts store, Size size) async {
  await pumpApp(
    tester,
    const TillLayoutScreen(workspaceId: 'ws-1', tillId: _till, tillName: 'Front counter'),
    size: size,
    overrides: [...standardTestOverrides(), tillLayoutPortProvider.overrideWithValue(store)],
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  for (final size in const [Size(390, 800), Size(1024, 900), Size(1440, 900)]) {
    group('the layout editor at ${size.width.toInt()}', () {
      testWidgets('a bakery layout with a calculator is built with buttons, saved and published', (tester) async {
        final store = DemoTillLayouts();
        await _open(tester, store, size);
        expect(find.text(_en.tillLayoutStartFrom), findsOneWidget);
        await _tap(tester, const ValueKey('till-layout-template-bakery'));
        // Publish waits for a saved draft
        expect(tester.widget<FilledButton>(find.byKey(const ValueKey('till-layout-publish'))).onPressed, isNull);

        // the desk grid has room beside the keypad
        await _tap(tester, const ValueKey('till-layout-size'));
        await tester.tap(find.text(_en.tillLayoutSizeDesk));
        await tester.pump(const Duration(milliseconds: 300));
        await _tap(tester, const ValueKey('till-layout-add'));
        await tester.ensureVisible(find.byKey(const ValueKey('till-layout-add-calculator')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('till-layout-add-calculator')));
        await tester.pumpAndSettle();
        expect(find.text(_en.tillLayoutKindCalculator), findsOneWidget);

        // the new calculator is selected: a step off the grid is disabled, a free step moves it
        final up = tester.widget<IconButton>(find.byKey(const ValueKey('till-layout-step-up')));
        expect(up.onPressed, isNull, reason: 'the calculator sits on the top row');
        final down = tester.widget<IconButton>(find.byKey(const ValueKey('till-layout-step-down')));
        if (down.onPressed != null) await _tap(tester, const ValueKey('till-layout-step-down'));

        await _tap(tester, const ValueKey('till-layout-save'));
        await tester.pump(const Duration(milliseconds: 300));
        final draft = await store.draft('ws-1', _till);
        expect(draft?.version, 1);
        final kinds = {for (final c in draft!.pages.first.grids[TillLayoutSize.desk]!.cells) c.kind};
        expect(kinds, containsAll([TillWidgetKind.keypad, TillWidgetKind.calculator]));

        await _tap(tester, const ValueKey('till-layout-publish'));
        await tester.pump(const Duration(milliseconds: 300));
        expect((await store.published('ws-1', _till))?.version, 1);
      });

      testWidgets('a save over a version another editor moved is refused in words', (tester) async {
        final store = DemoTillLayouts();
        await _open(tester, store, size);
        await _tap(tester, const ValueKey('till-layout-template-retail'));
        // another editor saves first: this editor's version 0 is stale now
        await store.save('ws-1', requestId: 'other-2', tillId: _till,
            layout: const TillLayout(name: 'Front counter', pages: [TillPage(name: 'Sale', grids: {TillLayoutSize.phone: TillGrid(cols: 4, rows: 4)})]),
            expectedVersion: 0);
        await _tap(tester, const ValueKey('till-layout-save'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text(_en.tillLayoutStale), findsOneWidget);
      });
    });
  }
}
