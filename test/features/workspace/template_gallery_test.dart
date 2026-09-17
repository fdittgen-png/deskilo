// SPDX-License-Identifier: 0BSD
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
    {Size size = const Size(800, 900)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
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
}
