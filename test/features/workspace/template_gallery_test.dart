// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1280 S1 — one gallery for a hundred templates: built lazily, searched
// and tag-filtered together, ordered builtin first, and one column at
// 360 dp.
import 'package:deskilo/features/workspace/domain/workspace_template.dart';
import 'package:deskilo/features/workspace/presentation/widgets/template_gallery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceTemplate _tpl(int i,
        {TemplateVisibility visibility = TemplateVisibility.public,
        List<String> tags = const [],
        String? name,
        String description = ''}) =>
    WorkspaceTemplate(
      id: 'tpl-$i',
      key: 'k$i',
      name: name ?? 'Template ${i.toString().padLeft(3, '0')}',
      description: description,
      visibility: visibility,
      tags: tags,
    );

Future<void> _pump(WidgetTester tester, List<WorkspaceTemplate> templates,
    {Size size = const Size(800, 900), double textScale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: TemplateGallery(
        sections: [TemplateGallerySection(title: 'All', templates: templates)],
        selectedId: null,
        onSelected: (_) {},
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _search(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const ValueKey('template-search')), text);
  await tester.pump(TemplateGallery.debounce + const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('fifty templates build only the cards in view', (tester) async {
    await _pump(tester, [for (var i = 0; i < 50; i++) _tpl(i)]);
    final built = find.byType(TemplateCard).evaluate().length;
    expect(built, greaterThan(0));
    expect(built, lessThan(20),
        reason: 'a lazy list builds the visible window plus a cache '
            'extent, never all fifty');
  });

  testWidgets('search and a tag filter compose', (tester) async {
    await _pump(tester, [
      _tpl(1, name: 'Studio Lyon', tags: const ['coworking']),
      _tpl(2, name: 'Studio Paris', tags: const ['association']),
      _tpl(3, name: 'Grand hall', tags: const ['coworking'],
          description: 'A studio of forty desks'),
    ]);
    await _search(tester, 'studio');
    expect(find.byType(TemplateCard), findsNWidgets(3),
        reason: 'the description matches too');

    await tester.tap(find.byKey(const ValueKey('template-tag-coworking')));
    await tester.pumpAndSettle();
    expect(find.byType(TemplateCard), findsNWidgets(2));
    expect(find.text('Studio Paris'), findsNothing);

    await _search(tester, 'lyon');
    expect(find.byType(TemplateCard), findsOneWidget);
    expect(find.text('Studio Lyon'), findsOneWidget);
  });

  testWidgets('#1660 a narrowed list announces its count, and focus stays '
      'in the search field', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, [
      _tpl(1, name: 'Studio Lyon', tags: const ['coworking']),
      _tpl(2, name: 'Studio Paris', tags: const ['association']),
      _tpl(3, name: 'Grand hall', tags: const ['coworking']),
    ]);
    const count = ValueKey('template-result-count');
    expect(find.byKey(count), findsNothing,
        reason: 'nothing narrowed, nothing to announce');

    await tester.tap(find.byKey(const ValueKey('template-search')));
    await _search(tester, 'studio');
    expect(find.text('2 templates shown'), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(count)),
      matchesSemantics(label: '2 templates shown', isLiveRegion: true),
    );
    final editable = tester.widget<EditableText>(find.descendant(
      of: find.byKey(const ValueKey('template-search')),
      matching: find.byType(EditableText),
    ));
    expect(editable.focusNode.hasFocus, isTrue,
        reason: 'the announcement never takes the focus');

    await tester.tap(find.byKey(const ValueKey('template-tag-coworking')));
    await tester.pumpAndSettle();
    expect(find.text('1 template shown'), findsOneWidget);
    semantics.dispose();
  });

  test('builtin first, then public, shared and private, then by name', () {
    final ordered = TemplateGallery.ordered([
      _tpl(1, name: 'b', visibility: TemplateVisibility.private),
      _tpl(2, name: 'a', visibility: TemplateVisibility.shared),
      _tpl(3, name: 'z', visibility: TemplateVisibility.public),
      _tpl(4, name: 'y', visibility: TemplateVisibility.builtin),
      _tpl(5, name: 'c', visibility: TemplateVisibility.public),
    ]);
    expect([for (final t in ordered) t.name], ['y', 'c', 'z', 'a', 'b']);
  });

  testWidgets('360 dp: one column, no overflow', (tester) async {
    await _pump(
      tester,
      [
        for (var i = 0; i < 10; i++)
          _tpl(i,
              tags: const ['coworking', 'association', 'small'],
              description: 'A long description that has to wrap on a phone '
                  'without pushing anything off the edge of the screen.'),
      ],
      size: const Size(360, 740),
    );
    expect(tester.takeException(), isNull);
    final first = tester.getTopLeft(find.byType(TemplateCard).first);
    final second = tester.getTopLeft(find.byType(TemplateCard).at(1));
    expect(first.dx, second.dx, reason: 'cards stack in one column');
  });

  // #1660 — the phone at large text, and a short landscape window: the
  // search stays on screen, the results still scroll, nothing overflows.
  for (final (label, size, scale) in [
    ('360 dp at 200 % text', const Size(360, 740), 2.0),
    ('short landscape at 130 % text', const Size(740, 360), 1.3),
  ]) {
    testWidgets('$label: search visible, results reachable, no overflow', (
      tester,
    ) async {
      await _pump(
        tester,
        [
          for (var i = 0; i < 30; i++)
            _tpl(i,
                tags: const ['coworking', 'association', 'small'],
                description: 'A long description that has to wrap without '
                    'pushing anything off the edge of the screen.'),
        ],
        size: size,
        textScale: scale,
      );
      expect(tester.takeException(), isNull);
      final search = tester.getRect(
        find.byKey(const ValueKey('template-search')),
      );
      expect(search.top, greaterThanOrEqualTo(0));
      expect(search.right, lessThanOrEqualTo(size.width));
      expect(search.bottom, lessThanOrEqualTo(size.height),
          reason: 'the search field is on screen, not pushed below it');
      final results = find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first;
      expect(
        tester.state<ScrollableState>(results).position.viewportDimension,
        greaterThanOrEqualTo(size.height / 2),
        reason: 'the results keep at least half the window under the '
            'search and filters',
      );
      final last = find.text('Template 029');
      await tester.scrollUntilVisible(last, 600,
          maxScrolls: 200,
          scrollable: results);
      await tester.pumpAndSettle();
      expect(last.hitTestable(), findsOneWidget,
          reason: 'the last result is reachable by scrolling');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('nothing to show says so', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: TemplateGallery(
          sections: [TemplateGallerySection(title: 'All', templates: [])],
        ),
      ),
    ));
    expect(find.byKey(const ValueKey('template-gallery-empty')), findsOneWidget);
  });

  testWidgets('a shortlist of up to four, separate from the selection (#1660)', (tester) async {
    await _pump(tester, [for (var i = 0; i < 6; i++) _tpl(i)]);
    expect(find.byKey(const ValueKey('template-compare')), findsNothing);
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byKey(ValueKey('template-shortlist-k$i')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Compare (4)'), findsOneWidget, reason: 'the fifth is refused');
    expect(find.textContaining('Up to 4 templates'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('template-shortlist-k0')));
    await tester.pumpAndSettle();
    expect(find.text('Compare (3)'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing, reason: 'shortlisting never selects');
  });
}

