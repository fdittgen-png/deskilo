// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3065 — the acceptance, as behaviour: each screen the header opens with
// push (settings, the task assistant, the inbox) shows its own address,
// that address opened cold stays where it is (a reload), and Back returns to
// the screen it was opened from.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/task_recorder/presentation/route_classification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/mock_providers.dart';

const _pushed = ['/settings', '/calendar?view=alerts', taskWorkbenchRoute];

String _where(GoRouter router) =>
    router.routeInformationProvider.value.uri.toString();

Future<GoRouter> _app(WidgetTester tester) async {
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
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  return GoRouter.of(tester.element(find.byType(Scaffold).first));
}

void main() {
  for (final address in _pushed) {
    testWidgets('$address pushed shows its address and Back returns', (
      tester,
    ) async {
      final router = await _app(tester);
      final origin = _where(router);
      unawaited(router.push<void>(address));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(_where(router), address);

      router.pop();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(_where(router), origin);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$address opened cold stays on its own address', (
      tester,
    ) async {
      final router = await _app(tester);
      router.go(address);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(_where(router), address);
      expect(tester.takeException(), isNull);
    });
  }
}
