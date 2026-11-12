// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3605 (the title half of #3613) — the window's, or the browser tab's,
// title through the app's builder: "place — business — DesKilo" on the desk
// and off it (a phone reads as a window does), "place — DesKilo" with no
// business selected, the app's name alone where a page has no place.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

Future<String> _titleAt(
  WidgetTester tester,
  String path, {
  Size size = const Size(1440, 900),
  FakeWorkspaceRepository? workspace,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(workspace: workspace),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  ProviderScope.containerOf(tester.element(find.byType(DeskiloApp)))
      .read(routerProvider)
      .go(path);
  await tester.pumpAndSettle();
  return tester.widget<Title>(find.byKey(const ValueKey('window-title'))).title;
}

void main() {
  testWidgets('on the desk: place, business, app', (tester) async {
    expect(
      await _titleAt(tester, '/members'),
      'Members & plans — Test Space — DesKilo',
    );
  });

  testWidgets('off the desk, on a phone, the same title', (tester) async {
    expect(
      await _titleAt(tester, '/members', size: const Size(390, 844)),
      'Members & plans — Test Space — DesKilo',
    );
  });

  testWidgets('with no business selected: place and app', (tester) async {
    expect(
      await _titleAt(
        tester,
        '/settings',
        workspace: FakeWorkspaceRepository(workspaces: []),
      ),
      'Settings — DesKilo',
    );
  });

  testWidgets('a page with no place in the business: the app alone', (
    tester,
  ) async {
    expect(await _titleAt(tester, '/me'), 'DesKilo');
  });
}
