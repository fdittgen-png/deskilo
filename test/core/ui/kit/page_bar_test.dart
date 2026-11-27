// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3927 — on the desk a page whose bar would hold only the place's name
// draws no bar and still tells its name; a bar with a control is drawn; off
// the desk the bar is drawn as before. #4492 — the bar's one main action, the
// worded More behind which the other actions stand, and the bottom bar's
// buttons kept to the page's column.
import 'package:deskilo/core/ui/kit/bottom_action_bar.dart';
import 'package:deskilo/core/ui/kit/page_bar.dart';
import 'package:deskilo/core/ui/kit/page_more_menu.dart';
import 'package:deskilo/core/ui/kit/page_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<String?> _pump(
  WidgetTester tester, {
  String? place,
  List<Widget> actions = const [],
}) async {
  Widget page = Builder(
    builder: (context) => Scaffold(
      appBar: pageBar(context, title: 'Colours', actions: actions),
      body: const Text('body'),
    ),
  );
  if (place != null) page = DeskPlaceLabel(label: place, child: page);
  await tester.pumpWidget(
    MaterialApp(
      home: PageNameScope(path: '/settings/colours', child: page),
    ),
  );
  await tester.pump();
  // The name, as a widget under the scope reads it.
  return PageNameScope.nameOf(tester.element(find.text('body')));
}

/// Lets a menu open or close: two bounded frames past its animation.
Future<void> _menu(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('on the desk, the title only: no bar, the name is told', (
    tester,
  ) async {
    final name = await _pump(tester, place: 'Colours');
    expect(find.byType(AppBar), findsNothing);
    expect(find.text('Colours'), findsNothing);
    expect(tester.getTopLeft(find.text('body')).dy, 0);
    expect(name, 'Colours');
  });

  testWidgets('on the desk, with an action: a bar', (tester) async {
    await _pump(
      tester,
      place: 'Colours',
      actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.add))],
    );
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('on the desk, a name that is not the place\'s: a bar with it', (
    tester,
  ) async {
    await _pump(tester, place: 'Settings');
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Colours'), findsOneWidget);
  });

  testWidgets('off the desk: the bar as before', (tester) async {
    final name = await _pump(tester);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Colours'), findsOneWidget);
    expect(name, 'Colours');
  });

  testWidgets('#4492 the main action of a bar is a filled, worded button '
      'under its own key', (tester) async {
    var pressed = 0;
    await _pump(
      tester,
      place: 'Colours',
      actions: [
        pageBarAction(
          key: const ValueKey('colours-new'),
          label: 'New colour',
          onPressed: () => pressed++,
        ),
      ],
    );
    final button = find.byKey(const ValueKey('colours-new'));
    expect(tester.widget(button), isA<FilledButton>());
    expect(
      find.descendant(of: button, matching: find.text('New colour')),
      findsOneWidget,
    );
    await tester.tap(button);
    expect(pressed, 1);
  });

  testWidgets('#4492 a page\'s other actions are behind one worded More: a '
      'heading does nothing, a line runs its own action', (tester) async {
    final ran = <String>[];
    await _pump(
      tester,
      actions: [
        PageMoreMenu(
          key: const ValueKey('colours-more'),
          entries: [
            const PageMoreEntry.heading(
              key: ValueKey('colours-more-corrections'),
              label: 'Corrections',
            ),
            PageMoreEntry(
              key: const ValueKey('colours-rename'),
              label: 'Rename the colour',
              onSelected: () => ran.add('rename'),
            ),
            PageMoreEntry(
              key: const ValueKey('colours-retire'),
              label: 'Retire the colour',
              onSelected: () => ran.add('retire'),
            ),
          ],
        ),
      ],
    );
    final more = find.byKey(const ValueKey('colours-more'));
    // a word, never an unnamed icon
    expect(find.descendant(of: more, matching: find.text('More')), findsOneWidget);
    await tester.tap(more);
    await _menu(tester);
    expect(find.text('CORRECTIONS'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('colours-more-corrections')));
    await _menu(tester);
    expect(ran, isEmpty, reason: 'a heading is not an action');
    await tester.tap(find.byKey(const ValueKey('colours-retire')));
    await _menu(tester);
    expect(ran, ['retire']);
  });

  testWidgets('#4492 a More with nothing to do is not drawn', (tester) async {
    await _pump(
      tester,
      actions: const [
        PageMoreMenu(
          key: ValueKey('colours-more'),
          entries: [
            PageMoreEntry.heading(
              key: ValueKey('colours-more-corrections'),
              label: 'Corrections',
            ),
          ],
        ),
      ],
    );
    expect(find.text('More'), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
  });

  testWidgets('#4492 the bottom bar keeps its buttons to the page\'s column '
      'when one is given, and shares the whole width otherwise', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Future<double> widthWith(double? maxWidth) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: BottomActionBar(
              maxWidth: maxWidth,
              actions: [
                FilledButton(
                  key: const ValueKey('colours-save'),
                  onPressed: () {},
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      );
      return tester.getSize(find.byKey(const ValueKey('colours-save'))).width;
    }

    expect(await widthWith(null), greaterThan(1100));
    expect(await widthWith(720), 720);
    // centred under the column
    final box = tester.getRect(find.byKey(const ValueKey('colours-save')));
    expect(box.center.dx, 600);
  });
}
