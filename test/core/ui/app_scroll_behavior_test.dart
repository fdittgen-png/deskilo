// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3611 -- with a mouse, a list shows its scrollbar at rest; a mouse
// drags a strip, never a page of text; a fading strip gets arrows.
import 'package:deskilo/core/ui/app_scroll_behavior.dart';
import 'package:deskilo/core/ui/edge_fade_scroll.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mouse.dart';

const _page = ValueKey('page');
const _strip = ValueKey('strip');

Widget _host(Widget body) => MaterialApp(
  scrollBehavior: const AppScrollBehavior(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: body),
);

Widget _pageOfText() => ListView(
  key: _page,
  children: [
    for (var i = 0; i < 60; i++)
      SizedBox(height: 40, child: Text('Line $i of the record')),
  ],
);

Widget _chips(int count) => Row(
  children: [
    for (var i = 0; i < count; i++)
      Padding(
        padding: const EdgeInsets.all(4),
        child: Chip(label: Text('Chip $i')),
      ),
  ],
);

/// Whether the page's scrollbar paints its thumb at rest.
bool _thumbAtRest(WidgetTester tester) {
  final bars = tester.widgetList<Scrollbar>(
    find.ancestor(of: find.byType(Viewport), matching: find.byType(Scrollbar)),
  );
  return bars.any((bar) => bar.thumbVisibility ?? false);
}

double _offset(WidgetTester tester, Finder scrollable) =>
    tester.state<ScrollableState>(scrollable).position.pixels;

void main() {
  testWidgets('touch: no scrollbar at rest on a phone', (tester) async {
    await tester.pumpWidget(_host(_pageOfText()));
    expect(_thumbAtRest(tester), isFalse);
  });

  testWidgets('a mouse: the scrollbar stays visible at rest, and the list '
      'keeps its place when the mouse comes', (tester) async {
    await tester.pumpWidget(_host(_pageOfText()));
    final page = find.descendant(
      of: find.byKey(_page),
      matching: find.byType(Scrollable),
    );
    await tester.drag(find.byKey(_page), const Offset(0, -300));
    await tester.pumpAndSettle();
    final before = _offset(tester, page);
    expect(before, greaterThan(0));

    await connectMouse(tester);
    expect(_thumbAtRest(tester), isTrue);
    expect(_offset(tester, page), before);
  });

  testWidgets('a mouse drag over a page of text does not scroll it', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_pageOfText()));
    final page = find.descendant(
      of: find.byKey(_page),
      matching: find.byType(Scrollable),
    );
    final drag = await tester.startGesture(
      tester.getCenter(find.byKey(_page)),
      kind: PointerDeviceKind.mouse,
    );
    await drag.moveBy(const Offset(0, -300));
    await drag.up();
    await tester.pumpAndSettle();
    expect(_offset(tester, page), 0);
  });

  testWidgets('a mouse drags a strip sideways', (tester) async {
    await tester.pumpWidget(
      _host(EdgeFadeScroll(key: _strip, child: _chips(30))),
    );
    await tester.pumpAndSettle();
    final strip = find.descendant(
      of: find.byKey(_strip),
      matching: find.byType(Scrollable),
    );
    final drag = await tester.startGesture(
      tester.getCenter(find.byKey(_strip)),
      kind: PointerDeviceKind.mouse,
    );
    await drag.moveBy(const Offset(-200, 0));
    await drag.up();
    await tester.pumpAndSettle();
    expect(_offset(tester, strip), greaterThan(0));
  });

  testWidgets('a strip has arrows with a mouse and none with touch', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(EdgeFadeScroll(key: _strip, child: _chips(30))),
    );
    await tester.pumpAndSettle();
    const back = ValueKey('edge-fade-back');
    const forward = ValueKey('edge-fade-forward');
    expect(find.byKey(forward), findsNothing);

    await connectMouse(tester);
    // At the start there is only more ahead.
    expect(find.byKey(back), findsNothing);
    expect(find.byKey(forward), findsOneWidget);
    final strip = find.descendant(
      of: find.byKey(_strip),
      matching: find.byType(Scrollable),
    );

    await click(tester, find.byKey(forward));
    final paged = _offset(tester, strip);
    expect(paged, greaterThan(0));
    expect(find.byKey(back), findsOneWidget);

    await click(tester, find.byKey(back));
    expect(_offset(tester, strip), 0);
  });
}
