// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3603 (desk F2, second part) — every workspace page inside the desk, not
// only the five tabs: through the app's builder a page opened from the
// navigation keeps its place selected, the top bar names that place as the
// sidebar shows it, and the window is titled "place — business". A place
// whose entry is not offered selects nothing and breaks nothing. The desk is
// one element while the pages change under it; a phone is unchanged.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/app/shell/desk_scaffold.dart';
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

final _en = AppLocalizationsEn();

Finder _key(String k) => find.byKey(ValueKey(k));

Future<GoRouter> _pump(
  WidgetTester tester, {
  Size size = const Size(1440, 900),
  Set<WorkspaceFeature> off = const {},
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final features = {
    for (final f in WorkspaceFeature.values)
      if (!off.contains(f)) f,
  };
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          workspace: FakeWorkspaceRepository.withWorkspace(
            featureFlags: {for (final f in features) f.name: true},
          ),
        ),
        enabledFeaturesSyncProvider.overrideWithValue(features),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(DeskiloApp)))
      .read(routerProvider);
}

Future<void> _go(WidgetTester tester, GoRouter router, String path) async {
  router.go(path);
  await tester.pumpAndSettle();
}

bool _selected(WidgetTester tester, String key) =>
    tester.widget<ListTile>(_key(key)).selected;

List<String> _crumbs(WidgetTester tester) => [
  for (final t in tester.widgetList<Text>(
    find.descendant(of: _key('desk-breadcrumb'), matching: find.byType(Text)),
  ))
    t.data!,
];

String _windowTitle(WidgetTester tester) =>
    tester.widget<Title>(find.byType(Title).last).title;

void main() {
  // The five pages of the acceptance, each with the entry it is reached from.
  final pages = {
    '/money/purchases': 'drawer-purchases',
    '/invoice-register': 'drawer-accounting-export',
    '/bi': 'drawer-bi',
    '/money/accounting': 'drawer-accounting',
    '/member/member-1': 'drawer-members',
  };

  for (final MapEntry(key: path, value: entry) in pages.entries) {
    testWidgets('at 1440 $path has the sidebar with $entry selected', (
      tester,
    ) async {
      final router = await _pump(tester);
      await _go(tester, router, path);
      expect(router.state.uri.path, path);
      expect(_key('shell-sidebar'), findsOneWidget);
      expect(_key('desk-top-bar'), findsOneWidget);
      expect(find.byType(ShellBottomBar), findsNothing);
      expect(_selected(tester, entry), isTrue);
      final label = tester
          .widget<Text>(
            find.descendant(of: _key(entry), matching: find.byType(Text)),
          )
          .data!;
      expect(_crumbs(tester).last, label);
      expect(_windowTitle(tester), '$label — Test Space');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the breadcrumb names the group and the entry, two levels: a '
      'detail page shows the place it is reached from', (tester) async {
    final router = await _pump(tester);
    await _go(tester, router, '/money/suppliers');
    expect(_crumbs(tester), [_en.navPurchasesGroup, _en.bookRoleSuppliers]);
    await _go(tester, router, '/member/member-1');
    expect(_crumbs(tester), [_en.uxNavPeople, _crumbs(tester).last]);
    expect(_crumbs(tester), hasLength(2));
  });

  testWidgets('at 1024 a page outside the tabs has the rail', (tester) async {
    final router = await _pump(tester, size: const Size(1024, 768));
    await _go(tester, router, '/money/purchases');
    expect(_key('desk-rail'), findsOneWidget);
    expect(_key('shell-sidebar'), findsNothing);
  });

  testWidgets('at 390 a page outside the tabs is unchanged: no desk', (
    tester,
  ) async {
    final router = await _pump(tester, size: const Size(390, 844));
    await _go(tester, router, '/money/purchases');
    expect(_key('desk-top-bar'), findsNothing);
    expect(_key('desk-navigation'), findsNothing);
  });

  testWidgets('a place whose entry is off: the desk renders, nothing is '
      'selected, nothing throws', (tester) async {
    // The status page opens with its own feature; its place, the Money tab,
    // is not offered without the money tab.
    final router = await _pump(tester, off: {WorkspaceFeature.moneyTab});
    await _go(tester, router, '/money/status');
    expect(router.state.uri.path, '/money/status');
    expect(_key('shell-sidebar'), findsOneWidget);
    expect(_key('drawer-tab-3'), findsNothing);
    final selected = tester
        .widgetList<ListTile>(
          find.descendant(
            of: _key('shell-sidebar'),
            matching: find.byType(ListTile),
          ),
        )
        .where((t) => t.selected);
    expect(selected, isEmpty);
    expect(_crumbs(tester), isEmpty);
    expect(_windowTitle(tester), 'Test Space');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a page pushed inside the desk: back returns, and the '
      'selection follows the address both ways; the desk is one element', (
    tester,
  ) async {
    final router = await _pump(tester);
    await _go(tester, router, '/money/purchases');
    final desk = tester.element(find.byType(DeskScaffold));
    expect(_selected(tester, 'drawer-purchases'), isTrue);

    unawaited(router.push('/money/suppliers'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/money/suppliers');
    expect(_selected(tester, 'drawer-suppliers'), isTrue);
    expect(_selected(tester, 'drawer-purchases'), isFalse);
    expect(find.byType(DeskScaffold), findsOneWidget);
    expect(tester.element(find.byType(DeskScaffold)), same(desk));

    router.pop();
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/money/purchases');
    expect(_selected(tester, 'drawer-purchases'), isTrue);
    expect(_selected(tester, 'drawer-suppliers'), isFalse);
    expect(tester.element(find.byType(DeskScaffold)), same(desk));
  });

  testWidgets('the desk does not rebuild or animate when the page changes', (
    tester,
  ) async {
    final router = await _pump(tester);
    await _go(tester, router, '/money/purchases');
    final desk = tester.element(find.byType(DeskScaffold));
    final sidebar = tester.element(_key('shell-sidebar'));
    router.go('/money/sales');
    await tester.pump();
    // The page may slide in; the navigation beside it stays put.
    expect(tester.element(find.byType(DeskScaffold)), same(desk));
    expect(tester.element(_key('shell-sidebar')), same(sidebar));
    expect(tester.getTopLeft(_key('desk-navigation')), Offset.zero);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/money/sales');
    expect(_selected(tester, 'drawer-sales'), isTrue);
  });
}
