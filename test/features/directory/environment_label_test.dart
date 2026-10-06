// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invariant: two spaces of one pair share a name, so the picker names the
// environment beside it — PROD and DEV each say their own word.
import 'package:deskilo/features/directory/presentation/messenger/environment_pill.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the same name reads PROD once and DEV once', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            children: [
              EnvironmentLabel('COWORKONTI', true),
              EnvironmentLabel('COWORKONTI', false),
            ],
          ),
        ),
      ),
    );
    expect(find.text('COWORKONTI'), findsNWidgets(2));
    expect(find.text('PROD'), findsOneWidget);
    expect(find.text('DEV'), findsOneWidget);
    expect(find.byKey(const ValueKey('env-pill-prod')), findsOneWidget);
    expect(find.byKey(const ValueKey('env-pill-dev')), findsOneWidget);
  });
}
