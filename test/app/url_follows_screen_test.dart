// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3065 — the invariant: a screen opened with push shows its own address, so
// reload and browser Back return to it and it can be bookmarked or shared.
import 'package:deskilo/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/mock_providers.dart';

void main() {
  testWidgets('the router reflects imperative pushes in the address', (
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
    expect(GoRouter.optionURLReflectsImperativeAPIs, isTrue);
  });
}
