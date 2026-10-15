// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Shared pump/fixtures that used to live in accessories_screen_test.dart and were borrowed by
// importing that test file (#2601). Moved verbatim.

import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../fake_accessory_repository.dart';
import '../fake_money_repository.dart';
import '../mock_providers.dart';

/// Widget tests default to 800x600 with lazy lists — use a taller
/// viewport so every list item is on-stage when tapped.
void useTallViewport(WidgetTester tester, {Size size = const Size(800, 1600)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<FakeAccessoryRepository> pumpAccessories(
  WidgetTester tester, {
  FakeAccessoryRepository? accessories,
  FakeWorkspaceRepository? workspace,
  FakeMoneyRepository? money,
  // #1339 — the responsive matrix asks for a narrow surface. Every
  // other caller keeps the tall one this file has always used, so
  // nothing existing changes.
  Size size = const Size(800, 1600),
}) async {
  useTallViewport(tester, size: size);
  accessories ??= FakeAccessoryRepository()..seedSmallCatalog();
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        // /accessories is gated on the accessorySupplements feature (#170,
        // default-off) since the admin-menu feature-gating refactor.
        workspace:
            workspace ??
            FakeWorkspaceRepository.withWorkspace(
              featureFlags: const {'accessorySupplements': true},
            ),
        accessories: accessories,
        money: money,
      ),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(Scaffold).first);
  unawaited(GoRouter.of(context).push('/accessories'));
  await tester.pumpAndSettle();
  return accessories;
}
