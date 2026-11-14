// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3789 — the desk names a place once and with one name, and the crumbs
// follow the page. For every desk route, through the app at 1024 and 1440
// in English and German:
// - the entry crumb is the label of the entry the navigation selects;
// - the last crumb is the page's own name where its bar has one (a
//   sub-page: "Settings › Colours"), and the window's title is that crumb;
// - nothing in the page's own bar repeats the last crumb (PageTitle is
//   silent there);
// - the routes whose page gives no name show the entry crumb only, counted:
//   the count only falls.
// A pushed sub-page names itself and its pop gives the name back. On a
// phone and a medium window every page keeps its title as before.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/route_classes.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/core/demo/data/device_prefs.dart';
import 'package:deskilo/core/locale/locale_controller.dart';
import 'package:deskilo/core/ui/kit/page_bar.dart';
import 'package:deskilo/core/ui/kit/page_title.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

Finder _k(String key) => find.byKey(ValueKey(key));

/// The desk routes without a parameter: each a place of its own.
final List<String> _deskRoutes = [
  for (final r in routeRules)
    if (!r.pattern.contains(':') &&
        r.kind == RouteClass.workspace &&
        chromeOf(r.pattern) == RouteChrome.desk)
      r.pattern,
];

Future<GoRouter> _pump(
  WidgetTester tester, {
  required Size size,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final features = WorkspaceFeature.values.toSet();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          workspace: FakeWorkspaceRepository.withWorkspace(
            featureFlags: {for (final f in features) f.name: true},
          ),
        ),
        enabledFeaturesSyncProvider.overrideWithValue(features),
        localeStoreProvider.overrideWithValue(
          InMemoryLocaleStore()..languageCode = locale.languageCode,
        ),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(DeskiloApp)))
      .read(routerProvider);
}

List<String> _crumbs(WidgetTester tester) => [
  for (final t in tester.widgetList<Text>(
    find.descendant(of: _k('desk-breadcrumb'), matching: find.byType(Text)),
  ))
    t.data!,
];

/// The titles the page's own bars ask for (PageTitle's text, or a Text),
/// a bar the kit leaves out on the desk (#3927) included.
List<String> _pageTitles(WidgetTester tester, {required Finder within}) => [
  for (final bar in tester.widgetList<AppBar>(
    find.descendant(of: within, matching: find.byType(AppBar)),
  ))
    if (bar.title case PageTitle(:final text))
      text
    else if (bar.title case Text(:final data?))
      data,
  for (final bar in tester.widgetList<QuietPageBar>(
    find.descendant(of: within, matching: find.byType(QuietPageBar)),
  ))
    bar.title,
];

/// The texts the page's own bars show.
List<String> _barTexts(WidgetTester tester) => [
  for (final t in tester.widgetList<Text>(
    find.descendant(
      of: find.descendant(of: _k('desk-page'), matching: find.byType(AppBar)),
      matching: find.byType(Text),
    ),
  ))
    ?t.data,
];

/// The label of the entry the navigation selects.
String _windowTitle(WidgetTester tester) =>
    tester.widget<Title>(_k('window-title')).title;

/// The desk routes whose page gives no name of its own when this landed: they
/// show the entry crumb only. The count only falls.
const _namelessBudget = 9;

/// The desk pages whose own bar is left empty when this landed (no title
/// drawn, no leading, no actions): collapsing them is for the desk pages
/// (#3614 on). The count only falls.
const _emptyBarBudget = 39;

/// Whether the page's own bar draws nothing on the desk.
bool _barEmpty(AppBar bar, String lastCrumb) {
  final title = bar.title;
  final silent =
      title == null || (title is PageTitle && title.text == lastCrumb);
  return silent && bar.leading == null && (bar.actions?.isEmpty ?? true);
}

String? _selectedEntry(WidgetTester tester) {
  for (final tile in tester.widgetList<ListTile>(
    find.descendant(of: _k('desk-navigation'), matching: find.byType(ListTile)),
  )) {
    if (!tile.selected) continue;
    if (tile.title case Text(:final data?)) return data;
  }
  return null;
}

/// Goes to [path] and lets the page build: fixed frames, since some pages
/// animate without end (a progress spinner), and what a page throws while
/// it loads is not this test's subject.
Future<void> _visit(WidgetTester tester, GoRouter router, String path) async {
  router.go(path);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  // The page tells its name after its first frame: one more for the crumbs.
  await tester.pump();
  while (tester.takeException() != null) {}
}

void main() {
  for (final locale in const [Locale('en'), Locale('de')]) {
    for (final size in const [Size(1024, 768), Size(1440, 900)]) {
      testWidgets('every desk route at ${size.width.toInt()} '
          '(${locale.languageCode}): the crumbs are the navigation\'s words '
          'followed by the page\'s name, said once', (tester) async {
        final router = await _pump(tester, size: size, locale: locale);
        final problems = <String>[];
        final nameless = <String>[];
        final empty = <String>[];
        for (final path in _deskRoutes) {
          await _visit(tester, router, path);
          final crumbs = _crumbs(tester);
          if (crumbs.isEmpty) continue;
          final titles = _pageTitles(tester, within: _k('desk-page'));
          final title = titles.isEmpty ? null : titles.last;
          final selected = _selectedEntry(tester);
          final entry =
              title != null &&
                  crumbs.length > 1 &&
                  crumbs.last == title &&
                  crumbs.last != selected
              ? crumbs[crumbs.length - 2]
              : crumbs.last;
          if (selected != null && selected != entry) {
            problems.add('$path: entry crumb "$entry", navigation "$selected"');
          }
          for (final bar in tester.widgetList<AppBar>(
            find.descendant(of: _k('desk-page'), matching: find.byType(AppBar)),
          )) {
            if (_barEmpty(bar, crumbs.last)) empty.add(path);
          }
          if (title == null) {
            nameless.add(path);
          } else if (crumbs.last != title) {
            problems.add('$path: last crumb "${crumbs.last}", page "$title"');
          }
          if (_barTexts(tester).contains(crumbs.last)) {
            problems.add('$path: "${crumbs.last}" shown twice');
          }
          if (_windowTitle(tester) != crumbs.last &&
              !_windowTitle(tester).startsWith('${crumbs.last} ')) {
            problems.add(
              '$path: window "${_windowTitle(tester)}", '
              'crumb "${crumbs.last}"',
            );
          }
        }
        expect(problems, isEmpty, reason: problems.join('\n'));
        expect(
          nameless.length,
          lessThanOrEqualTo(_namelessBudget),
          reason: 'a new page without a PageTitle:\n${nameless.join('\n')}',
        );
        expect(
          empty.length,
          lessThanOrEqualTo(_emptyBarBudget),
          reason: 'a new empty bar on the desk:\n${empty.join('\n')}',
        );
      });
    }
  }

  testWidgets('a sub-page pushed over its entry names itself; its pop gives '
      'the entry\'s name back', (tester) async {
    final router = await _pump(tester, size: const Size(1440, 900));
    await _visit(tester, router, '/settings');
    final entry = _crumbs(tester).last;
    unawaited(router.push('/settings/colours'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(_crumbs(tester).last, isNot(entry));
    expect(_crumbs(tester), contains(entry));
    expect(_windowTitle(tester), startsWith(_crumbs(tester).last));
    router.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(_crumbs(tester).last, entry);
    expect(_windowTitle(tester), startsWith(entry));
  });

  for (final size in const [Size(390, 844), Size(800, 900)]) {
    testWidgets('at ${size.width.toInt()} every page shows its own title as '
        'before', (tester) async {
      final router = await _pump(tester, size: size);
      final silent = <String>[];
      for (final path in _deskRoutes) {
        await _visit(tester, router, path);
        for (final t in tester.widgetList<PageTitle>(find.byType(PageTitle))) {
          if (find.text(t.text).evaluate().isEmpty) {
            silent.add('$path: ${t.text}');
          }
        }
      }
      expect(silent, isEmpty, reason: silent.join('\n'));
    });
  }
}
