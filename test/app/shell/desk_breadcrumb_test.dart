// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3619 — the desk's breadcrumb gives the page's name its room: the parts
// before it give way first (the middle ones, then the first), each keeping
// its whole name for a screen reader and as a tooltip; the page's name is
// never the part cut while one before it still shows whole.
import 'package:deskilo/app/shell/desk_breadcrumb.dart';
import 'package:deskilo/app/shell/shell_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _first = 'Workspace setup and configuration';
const _middle = 'Configure the workspace and its places';
const _page = 'Name, country, currency, language and time zone';

void main() {
  test('the middle part gives way first, then the first; the last keeps its '
      'width while it can', () {
    // Two chevrons of 24 between three parts.
    expect(crumbWidths([200, 300, 400], room: 600, least: 48), [104, 48, 400]);
    // Room for everything: nothing moves.
    expect(crumbWidths([100, 100, 100], room: 400, least: 48), [100, 100, 100]);
    // Even the smallest ancestors leave too little: the last gives the rest.
    expect(crumbWidths([200, 300, 400], room: 300, least: 48), [48, 48, 156]);
  });

  testWidgets('three long parts at the width the frame leaves at 1024: the '
      'page\'s name whole on two lines, the others whole for a screen reader', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const SizedBox())],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              // The desk's bar at 1024 less its title spacing (measured).
              width: 895,
              child: DeskBreadcrumb(
                router: router,
                wraps: true,
                crumbs: const <DeskCrumb>[
                  (label: _first, entry: null),
                  (label: _middle, entry: null),
                  (label: _page, entry: null),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final page = tester.renderObject<RenderParagraph>(find.text(_page));
    expect(
      page.didExceedMaxLines,
      isFalse,
      reason: 'the page\'s name is whole',
    );
    for (final label in [_first, _middle]) {
      expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
    }
    // A shortened part says where it leads as a tooltip.
    expect(find.byType(Tooltip), findsWidgets);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
