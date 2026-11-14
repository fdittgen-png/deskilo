// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3927 — on the desk a page whose bar would hold only the place's name
// draws no bar and still tells its name; a bar with a control is drawn; off
// the desk the bar is drawn as before.
import 'package:deskilo/core/ui/kit/page_bar.dart';
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
}
