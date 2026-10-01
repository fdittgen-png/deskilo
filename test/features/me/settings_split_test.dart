// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — My account left the workspace's Settings for Me. The space's
// Settings keep the way there, the badge and PIN of the membership, and
// the per-space override named as the exception it is.
import 'package:deskilo/core/demo/data/personal_preferences_repository.dart';
import 'package:deskilo/features/profile/domain/personal_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'me_app.dart';

void main() {
  testWidgets('Settings no longer holds the account rows; its row opens Me',
      (tester) async {
    final router = await pumpMeApp(tester);
    await pushTo(tester, router, '/settings');
    expect(find.byKey(const ValueKey('settings-photo')), findsNothing);
    expect(find.byKey(const ValueKey('settings-linked-accounts')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('settings-open-me')));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), '/me?tab=me');
    expect(find.byKey(const ValueKey('settings-photo')), findsOneWidget);
  });

  testWidgets('a per-space override is shown as the exception', (tester) async {
    final preferences = FakePersonalPreferencesRepository();
    await preferences.patch({PersonalPreference.theme: 'dark'}, workspaceId: 'ws-1');
    final router = await pumpMeApp(tester, preferences: preferences);
    await pushTo(tester, router, '/settings');
    expect(find.byKey(const ValueKey('settings-space-exception')), findsOneWidget);
    expect(find.text('Theme: Dark'), findsOneWidget);
  });

  testWidgets('switching the scope on shows the rows that edit this space',
      (tester) async {
    final router = await pumpMeApp(tester);
    await pushTo(tester, router, '/settings');
    expect(find.text('Language'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('preferences-workspace-only')));
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
  });
}
