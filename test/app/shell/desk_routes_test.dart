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
import 'package:deskilo/core/ui/app_frame.dart';
import 'package:deskilo/core/ui/form_kit.dart';
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
    tester.widget<Title>(find.byKey(const ValueKey('window-title'))).title;

void main() {
  // The five pages of the acceptance, each with the entry it is reached from.
  final pages = {
    '/money/purchases': 'drawer-purchases',
    '/invoice-register': 'drawer-accounting-export',
    '/bi': 'drawer-bi',
    '/money/accounting': 'drawer-accounting',
    '/member/member-1': 'drawer-members',
    // Built since #3307 and never shown until it joined its group.
    '/money/purchase-orders': 'drawer-purchase-orders',
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
      expect(_windowTitle(tester), '$label — Test Space — DesKilo');
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
    // No place: the app's name alone (#3605).
    expect(_windowTitle(tester), 'DesKilo');
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
    final at = tester.getTopLeft(_key('desk-navigation'));
    router.go('/money/sales');
    await tester.pump();
    // The page may slide in; the navigation beside it stays put.
    expect(tester.element(find.byType(DeskScaffold)), same(desk));
    expect(tester.element(_key('shell-sidebar')), same(sidebar));
    expect(tester.getTopLeft(_key('desk-navigation')), at);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/money/sales');
    expect(_selected(tester, 'drawer-sales'), isTrue);
  });

  testWidgets('a page pushed from the desk that its guard sends to another '
      'desk page: one desk, no second copy of it', (tester) async {
    final router = await _pump(tester, off: {WorkspaceFeature.managedProfiles});
    await _go(tester, router, '/money/purchases');
    final desk = tester.element(find.byType(DeskScaffold));
    unawaited(router.push('/members/managed'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/members');
    expect(find.byType(DeskScaffold), findsOneWidget);
    expect(tester.element(find.byType(DeskScaffold)), same(desk));
    expect(_selected(tester, 'drawer-members'), isTrue);
    router.pop();
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/money/purchases');
    expect(_selected(tester, 'drawer-purchases'), isTrue);
    expect(tester.takeException(), isNull);
  });

  /// The page's own scaffold, inside the desk's page area.
  Finder pageScaffold() => find
      .descendant(of: _key('desk-page'), matching: find.byType(Scaffold))
      .first;

  /// The page inside the desk's page area: its own scaffold.
  Rect pageRect(WidgetTester tester) => tester.getRect(
    find
        .descendant(
          of: _key('desk-page'),
          matching: find.byType(Scaffold),
        )
        .first,
  );

  for (final (width, rail) in [
    (1024.0, true),
    (1440.0, false),
    (1920.0, false),
  ]) {
    testWidgets('at ${width.toInt()} the window is the desk\'s and the reading '
        'column the page\'s', (tester) async {
      final router = await _pump(tester, size: Size(width, 900));
      await _go(tester, router, '/money/purchases');
      final nav = tester.getRect(_key('desk-navigation'));
      expect(nav.left, 0);
      expect(
        nav.width,
        rail ? DeskScaffold.railWidth : DeskScaffold.sidebarWidth,
      );
      final top = tester.getRect(_key('desk-top-bar'));
      expect(top.right, width);
      final area = Rect.fromLTRB(top.left, top.bottom, width, 900);
      final page = pageRect(tester);
      expect(page.width, lessThanOrEqualTo(frameWidthFor('/money/purchases')));
      expect(
        page.width,
        area.width < kReadingColumnMaxWidth
            ? area.width
            : kReadingColumnMaxWidth,
      );
      expect(page.center.dx, closeTo(area.center.dx, 0.5));
    });
  }

  testWidgets('a canvas page gets the wide column beside the navigation', (
    tester,
  ) async {
    final router = await _pump(tester, size: const Size(1920, 900));
    // A canvas route still on today's frame (#3604: /invoices has its own).
    await _go(tester, router, '/editor');
    expect(pageRect(tester).width, kAppFrameMaxWidth);
  });

  testWidgets('a medium window is unchanged: no desk, the page as wide as '
      'the window', (tester) async {
    final router = await _pump(tester, size: const Size(800, 900));
    await _go(tester, router, '/money/purchases');
    expect(_key('desk-navigation'), findsNothing);
    expect(tester.getRect(find.byType(Scaffold).last).width, 800);
  });

  testWidgets('a sheet and a dialog over a desk page keep their master '
      'widths (the sheet its own 640, the dialog the column less its insets)', (
    tester,
  ) async {
    final router = await _pump(tester);
    await _go(tester, router, '/money/purchases');
    final context = tester.element(
      find
          .descendant(
            of: _key('desk-page'),
            matching: find.byType(Scaffold),
          )
          .first,
    );
    unawaited(
      showAppFormSheet(
        context,
        AppFormSheet(
          title: 'T',
          submitLabel: 'S',
          onSubmit: () async => null,
          builder: (context, refresh) => [const Text('x')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(AppFormSheet)).width, 640);
    Navigator.of(tester.element(find.byType(AppFormSheet))).pop();
    await tester.pumpAndSettle();
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(
          key: ValueKey('desk-dialog'),
          content: Text(
            'A sentence long enough to fill the dialog to its '
            'widest on a desktop window, and then some more words beyond.',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final dialog = tester.getRect(
      find
          .descendant(
            of: find.byKey(const ValueKey('desk-dialog')),
            matching: find.byType(Material),
          )
          .first,
    );
    // 880 on master at 1440 and 1920: the column less the two insets.
    expect(dialog.width, 880);
  });

  testWidgets('one desk for all: the same element across a tab, a page pushed '
      'over it, and a go between two places', (tester) async {
    final router = await _pump(tester);
    await _go(tester, router, '/money');
    final desk = tester.element(find.byType(DeskScaffold));
    expect(find.byType(DeskScaffold), findsOneWidget);
    unawaited(router.push('/money/purchases'));
    await tester.pumpAndSettle();
    expect(tester.element(find.byType(DeskScaffold)), same(desk));
    await _go(tester, router, '/members');
    expect(tester.element(find.byType(DeskScaffold)), same(desk));
    expect(find.byType(DeskScaffold), findsOneWidget);
  });

  testWidgets('a phone keeps the back arrow of a page pushed over a tab, as '
      'on master', (tester) async {
    final router = await _pump(tester, size: const Size(390, 844));
    unawaited(router.push('/money/purchases'));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/reserve');
  });

  testWidgets('a window open over the page rests the navigation: a sidebar '
      'tap changes nothing and the sheet stays', (tester) async {
    final router = await _pump(tester);
    await _go(tester, router, '/money/purchases');
    unawaited(
      showAppFormSheet(
        tester.element(pageScaffold()),
        AppFormSheet(
          title: 'T',
          submitLabel: 'S',
          onSubmit: () async => null,
          builder: (context, refresh) => [const Text('x')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_key('desk-scrim'), findsWidgets);
    await tester.tap(_key('drawer-reserve'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/money/purchases');
    expect(find.byType(AppFormSheet), findsOneWidget);
    Navigator.of(tester.element(find.byType(AppFormSheet))).pop();
    await tester.pumpAndSettle();
    expect(_key('desk-scrim'), findsNothing);
    await tester.tap(_key('drawer-reserve'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/reserve');
  });

  testWidgets('at 1024 the desk\'s own chrome has an overlay: a tooltip in '
      'the top bar and a group\'s menu on the rail', (tester) async {
    final router = await _pump(tester, size: const Size(1024, 768));
    await _go(tester, router, '/money/purchases');
    await tester.longPress(_key('shell-settings-button'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(Tooltip), findsWidgets);
    expect(find.text(_en.settingsTitle), findsWidgets);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.tap(_key('rail-group-people'));
    await tester.pumpAndSettle();
    expect(_key('rail-drawer-members'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opened directly on an address at 1440, the desk draws with '
      'its place selected on the first settled frame', (tester) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        '/money/purchases';
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
    final router = await _pump(tester);
    expect(router.state.uri.path, '/money/purchases');
    expect(_key('shell-sidebar'), findsOneWidget);
    expect(_selected(tester, 'drawer-purchases'), isTrue);
  });

  testWidgets('from a page with no arrow on the desk, the breadcrumb\'s entry '
      'and the selected sidebar entry lead back to the place\'s page', (
    tester,
  ) async {
    final router = await _pump(tester);
    await _go(tester, router, '/members');
    unawaited(router.push('/member/member-1'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/member/member-1');
    await tester.tap(_key('desk-crumb-drawer-members'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/members');

    unawaited(router.push('/member/member-1'));
    await tester.pumpAndSettle();
    await tester.tap(_key('drawer-members'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/members');
  });
}
