// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3893 — the desk's top bar gives the page's name its room first: the
// controls leave it, least needed first, before the name is cut; a name
// that still does not fit beside the controls that never leave wraps to a
// second line.
import 'package:deskilo/app/shell/desk_top_bar.dart';
import 'package:deskilo/app/shell/shell_app_bar.dart';
import 'package:deskilo/core/ui/kit/row_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

ShellBarControl _control(String id, int rank, {required bool leaves}) =>
    ShellBarControl(
      id: id,
      rank: rank,
      button: IconButton(
        key: ValueKey(id),
        icon: const Icon(Icons.circle),
        tooltip: id,
        onPressed: () {},
      ),
      entry: leaves
          ? RowAction(id: id, label: id, onSelected: () {})
          : null,
    );

final _controls = [
  _control('search', 1, leaves: true),
  _control('inbox', 0, leaves: false),
  _control('settings', 2, leaves: true),
  _control('account', 0, leaves: false),
];

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  required double titleWidth,
  required String name,
}) async {
  tester.view.physicalSize = Size(width, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            DeskTopBar(
              titleWidth: titleWidth,
              controls: _controls,
              title: ({required wraps}) => Text(
                name,
                key: const ValueKey('name'),
                maxLines: wraps ? 2 : 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

bool _cut(WidgetTester tester) {
  final box = tester.renderObject<RenderParagraph>(
    find.descendant(
      of: find.byKey(const ValueKey('name')),
      matching: find.byType(RichText),
    ),
  );
  return box.didExceedMaxLines;
}

void main() {
  testWidgets('a name that fits keeps every control', (tester) async {
    await _pump(tester, width: 952, titleWidth: 200, name: 'Members');
    expect(find.byKey(const ValueKey('shell-overflow-button')), findsNothing);
    for (final id in ['search', 'inbox', 'settings', 'account']) {
      expect(find.byKey(ValueKey(id)), findsOneWidget, reason: id);
    }
  });

  testWidgets('a long name: the controls that may leave fold behind one '
      'button before the name is cut', (tester) async {
    const name = 'Subscriptions and plans of the members of the workspace';
    final painter = TextPainter(
      text: const TextSpan(text: name, style: TextStyle(fontSize: 22)),
      textDirection: TextDirection.ltr,
    )..layout();
    await _pump(
      tester,
      width: 952,
      titleWidth: painter.width,
      name: name,
    );
    expect(find.byKey(const ValueKey('shell-overflow-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('search')), findsNothing);
    // The ones that never leave stay.
    expect(find.byKey(const ValueKey('inbox')), findsOneWidget);
    expect(find.byKey(const ValueKey('account')), findsOneWidget);
    expect(_cut(tester), isFalse);
    painter.dispose();
  });

  testWidgets('a name wider than the bar can hold even with the controls '
      'folded wraps to a second line and loses nothing', (tester) async {
    const name = 'Name, country and time zone';
    await _pump(tester, width: 600, titleWidth: 540, name: name);
    final bar = tester.getSize(find.byKey(const ValueKey('desk-top-bar')));
    expect(bar.height, greaterThan(kToolbarHeight));
    expect(tester.getSize(find.byKey(const ValueKey('name'))).height, greaterThan(30));
    expect(_cut(tester), isFalse);
  });
}
