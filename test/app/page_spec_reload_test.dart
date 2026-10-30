// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3065 — the invariant: a page that is opened with an object it needs (a
// PageSpec with an extra) and reached again without it — a reload, a typed
// or shared address — lands on its fallback, never on a blank or broken
// page. This is the path that showing pushed addresses exposes.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/presentation/workspace_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/mock_providers.dart';

void main() {
  testWidgets('a page reached without its object lands on its fallback', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(),
        child: const DeskiloApp(),
      ),
    );
    await tester.pump();
    final context = tester.element(find.byType(Scaffold).first);
    final router = GoRouter.of(context)..go(templateDetailPage.path);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final location = router.routeInformationProvider.value.uri.path;
    expect(location, isNot(templateDetailPage.path),
        reason: 'a page without its object is never shown');
    expect(tester.takeException(), isNull);
  });
}
