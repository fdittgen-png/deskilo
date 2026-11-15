// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4057 — Privacy & data and the task assistant opened from a business's
// sidebar keep that business's shell; the way back returns to the page that
// was left, in the shell it had (capture 21: Documents, Privacy, Back).
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/route_classes.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

Finder _k(String key) => find.byKey(ValueKey(key));

Future<ProviderContainer> _pump(WidgetTester tester, {Size? size}) async {
  tester.view.physicalSize = size ?? const Size(1280, 900);
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
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(DeskiloApp)));
}

String _path(ProviderContainer c) =>
    c.read(routerProvider).routeInformationProvider.value.uri.path;

void main() {
  testWidgets('Documents, Privacy from the sidebar, Back: Documents is in '
      'the desk again', (tester) async {
    final c = await _pump(tester);
    c.read(routerProvider).go('/documents');
    await tester.pumpAndSettle();
    expect(_k('desk-breadcrumb'), findsOneWidget);

    await tester.ensureVisible(_k('drawer-privacy'));
    await tester.pumpAndSettle();
    await tester.tap(_k('drawer-privacy'));
    await tester.pumpAndSettle();
    expect(_path(c), anyOf('/privacy', contains('privacy')));

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(_path(c), '/documents');
    expect(_k('desk-breadcrumb'), findsOneWidget);
    expect(_k('desk-page'), findsOneWidget);
  });

  for (final (entry, route) in [
    ('drawer-privacy', '/business-privacy'),
    ('drawer-task-wizard', '/business-task-wizard'),
  ]) {
    testWidgets('$entry opens $route inside the business\'s shell, and Back '
        'returns to the page that was left', (tester) async {
      final c = await _pump(tester);
      c.read(routerProvider).go('/documents');
      await tester.pumpAndSettle();
      await tester.ensureVisible(_k(entry));
      await tester.pumpAndSettle();
      await tester.tap(_k(entry));
      await tester.pumpAndSettle();
      expect(_path(c), route);
      expect(_k('desk-breadcrumb'), findsOneWidget, reason: 'the breadcrumb');
      expect(_k(entry), findsOneWidget, reason: 'the sidebar, still there');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(_path(c), '/documents');
      expect(_k('desk-breadcrumb'), findsOneWidget);
    });
  }

  test('which chrome each way of opening gets', () {
    // From a business's sidebar: the business's own route, on the desk.
    for (final path in ['/business-privacy', '/business-task-wizard']) {
      expect(classifyRoute(path), RouteClass.workspace, reason: path);
      expect(chromeOf(path), RouteChrome.desk, reason: path);
      expect(isPersonalLayer(path), isFalse, reason: path);
    }
    expect(placeOf('/business-privacy'), 'drawer-privacy');
    expect(placeOf('/business-task-wizard'), 'drawer-task-wizard');
    // From Me, the signed-out pages and a consent step: as before.
    expect(classifyRoute('/privacy'), RouteClass.publicEntry);
    expect(chromeOf('/privacy'), RouteChrome.public);
    expect(classifyRoute('/task-wizard'), RouteClass.nativeAccount);
    expect(chromeOf('/task-wizard'), RouteChrome.account);
    expect(isPersonalLayer('/privacy'), isTrue);
    expect(isPersonalLayer('/task-wizard'), isTrue);
  });
}
