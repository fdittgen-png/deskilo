// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Shared pump/fixtures that used to live in onboarding_flow_test.dart and were borrowed by
// importing that test file (#2601). Moved verbatim.

import 'package:deskilo/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../mock_providers.dart';

Future<FakeWorkspaceRepository> pumpWithoutWorkspace(
  WidgetTester tester,
) async {
  final repo = FakeWorkspaceRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(workspace: repo),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('me-home-create')));
  await tester.pumpAndSettle();
  return repo;
}
