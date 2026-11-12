// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3611 -- a row's actions, declared once, open the same menu from the
// ⋯ button, a right click, a long press and the keyboard.
import 'package:deskilo/core/ui/kit/row_menu.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/mouse.dart';

const _row = ValueKey('row');

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Center(child: SizedBox(width: 400, child: child)),
  ),
);

Widget _menu(
  List<String> chosen, {
  RowMenuButton button = RowMenuButton.always,
  bool focusable = false,
}) => RowMenu(
  keyPrefix: 'm',
  button: button,
  focusable: focusable,
  actions: [
    RowAction(
      id: 'quote',
      label: 'Quote',
      icon: Icons.format_quote,
      onSelected: () => chosen.add('quote'),
    ),
    RowAction(
      id: 'delete',
      label: 'Delete',
      destructive: true,
      onSelected: () => chosen.add('delete'),
    ),
    RowAction(
      id: 'pin',
      label: 'Pin',
      disabledReason: 'Only an admin can pin',
      onSelected: () => chosen.add('pin'),
    ),
  ],
  child: const ListTile(key: _row, title: Text('A row')),
);

/// The entries the open menu shows, by key, in order.
List<String> _entries(WidgetTester tester) => tester
    .widgetList<PopupMenuItem<RowAction>>(find.byType(PopupMenuItem<RowAction>))
    .map(
      (item) =>
          '${(item.key! as ValueKey<String>).value}'
          '${item.enabled ? '' : ' (off)'}',
    )
    .toList();

Future<void> _close(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
  expect(find.byType(PopupMenuItem<RowAction>), findsNothing);
}

void main() {
  const expected = ['m-quote', 'm-delete', 'm-pin (off)'];

  testWidgets('the ⋯, a right click, a long press and the keyboard open '
      'the same menu with the same entries', (tester) async {
    final chosen = <String>[];
    await tester.pumpWidget(_host(_menu(chosen, focusable: true)));
    final opened = <String, List<String>>{};

    await tester.tap(find.byKey(const ValueKey('m-more')));
    await tester.pumpAndSettle();
    opened['more'] = _entries(tester);
    await _close(tester);

    await rightClick(tester, find.byKey(_row));
    opened['right click'] = _entries(tester);
    await _close(tester);

    await tester.longPress(find.byKey(_row));
    await tester.pumpAndSettle();
    opened['long press'] = _entries(tester);
    await _close(tester);

    // The keyboard: focus the row, then the context-menu key, then
    // Shift+F10.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.pumpAndSettle();
    opened['menu key'] = _entries(tester);
    await _close(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    opened['shift f10'] = _entries(tester);
    await _close(tester);

    expect(opened, {
      'more': expected,
      'right click': expected,
      'long press': expected,
      'menu key': expected,
      'shift f10': expected,
    });
    expect(chosen, isEmpty);
  });

  testWidgets('an entry runs its action; a disabled one says why and runs '
      'nothing', (tester) async {
    final chosen = <String>[];
    await tester.pumpWidget(_host(_menu(chosen)));
    await rightClick(tester, find.byKey(_row));
    expect(find.text('Only an admin can pin'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('m-pin')), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(chosen, isEmpty);
    await _close(tester);

    await rightClick(tester, find.byKey(_row));
    await tester.tap(find.byKey(const ValueKey('m-delete')));
    await tester.pumpAndSettle();
    expect(chosen, ['delete']);
    // Destructive entries wear the error colour.
    await rightClick(tester, find.byKey(_row));
    final label = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('m-delete')),
        matching: find.text('Delete'),
      ),
    );
    final context = tester.element(find.byKey(_row));
    expect(label.style?.color, Theme.of(context).colorScheme.error);
  });

  testWidgets('a hover button shows for a mouse over the row and never at '
      'rest on a phone', (tester) async {
    await tester.pumpWidget(
      _host(_menu(<String>[], button: RowMenuButton.onHover)),
    );
    expect(find.byKey(const ValueKey('m-more')), findsNothing);

    final mouse = await connectMouse(tester);
    expect(find.byKey(const ValueKey('m-more')), findsNothing);
    await hoverOver(tester, mouse, find.byKey(_row));
    expect(find.byKey(const ValueKey('m-more')), findsOneWidget);
    await click(tester, find.byKey(const ValueKey('m-more')));
    expect(_entries(tester), expected);
  });
}
