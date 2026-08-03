// SPDX-License-Identifier: 0BSD
//
// Workspace-wide developer mode (#419, migration 0081): set by
// owner/admins, applies to EVERY member. The switch is an admin
// affordance; plain members inherit the state without seeing it.

import 'package:deskilo/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgrestException;

import '../../helpers/mock_providers.dart';

Future<FakeWorkspaceRepository> _pumpSettings(
  WidgetTester tester, {
  required bool viewerAdmin,
  bool devMode = false,
}) async {
  final workspace = FakeWorkspaceRepository.withWorkspace();
  if (!viewerAdmin) {
    workspace.myMember =
        workspace.myMember.copyWith(isOwner: false, isAdmin: false);
  }
  if (devMode) workspace.applyDevMode(true);
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(workspace: workspace),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Advanced'), 100);
  await tester.pumpAndSettle();
  return workspace;
}

void main() {
  testWidgets('an admin flips dev mode for the whole workspace',
      (tester) async {
    final workspace = await _pumpSettings(tester, viewerAdmin: true);
    await tester.scrollUntilVisible(find.text('Developer mode'), 100);
    await tester.tap(find.text('Developer mode'));
    await tester.pumpAndSettle();
    expect(workspace.workspaces.single.devMode, isTrue,
        reason: 'written through the 0081 RPC seam, for everyone');
  });

  testWidgets('a plain member sees NO switch — but inherits the state',
      (tester) async {
    await _pumpSettings(tester, viewerAdmin: false, devMode: true);
    expect(find.text('Developer mode'), findsNothing);
    // The workspace-wide mode still applies: the Developer entry shows.
    await tester.scrollUntilVisible(find.text('Developer'), 100);
    expect(find.text('Developer'), findsOneWidget);
  });

  test('fake mirrors the server gate: non-admin write refuses', () async {
    final repo = FakeWorkspaceRepository.withWorkspace();
    repo.myMember = repo.myMember.copyWith(isOwner: false, isAdmin: false);
    await expectLater(
      repo.setDevMode('ws-1', true),
      throwsA(isA<PostgrestException>().having(
          (e) => e.message, 'message', contains('not an admin'))),
    );
  });
}
