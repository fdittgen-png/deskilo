// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant: translated workspace entries and account shortcuts remain
// readable and actionable at narrow widths with doubled text size.
import 'package:deskilo/features/me/presentation/me_shell.dart';
import 'package:deskilo/features/profile/domain/personal_preferences.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:deskilo/core/demo/data/personal_preferences_repository.dart';
import 'me_app.dart';

void main() {
  for (final code in ['en', 'fr', 'de', 'es', 'it']) {
    testWidgets('$code: paired entry and account shortcuts fit large text', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = twoSpaces();
      if (code == 'de') {
        repo.myMember = repo.myMember.copyWith(isAdmin: false, isOwner: false);
      }
      repo.workspaces[0] = repo.workspaces[0].copyWith(
        name: 'A very long shared workspace name near the city centre',
        pairId: 'pair-1',
        environment: 'prod',
      );
      repo.workspaces[1] = repo.workspaces[1].copyWith(
        name: 'A very long shared workspace name near the city centre',
        pairId: 'pair-1',
        environment: 'dev',
      );
      final preferences = FakePersonalPreferencesRepository()
        ..defaults[PersonalPreference.uiLocale] = code;
      final router = await pumpMeApp(
        tester,
        workspace: repo,
        preferences: preferences,
        size: const Size(320, 900),
      );
      await goTo(tester, router, '/me');
      final words = AppLocalizations.of(tester.element(find.byType(MeShell)))!;
      expect(find.text(words.uxOpenWorkspace), findsOneWidget);
      expect(find.text(words.uxTestSpace), findsOneWidget);
      expect(find.text(words.uxTestSpaceHint), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('me-space-ws-1')))
            .onPressed,
        isNotNull,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('me-space-ws-2')))
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
      await goTo(tester, router, '/me?tab=me');
      final preferencesShortcut = find.byKey(const ValueKey('me-section-2'));
      expect(preferencesShortcut.hitTestable(), findsOneWidget);
      await tester.tap(preferencesShortcut);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.language).hitTestable(), findsOneWidget);
      expect(
        find.byIcon(Icons.brightness_6_outlined).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
