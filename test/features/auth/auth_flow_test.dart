// SPDX-License-Identifier: MIT
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

Future<FakeAuthRepository> pumpSignedOut(WidgetTester tester) async {
  final auth = FakeAuthRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(auth: auth),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  return auth;
}

void main() {
  testWidgets('successful sign-in navigates into the shell', (tester) async {
    await pumpSignedOut(tester);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'flo@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.byType(ShellBottomBar), findsOneWidget);
  });

  testWidgets('failed sign-in shows the error snackbar and stays put',
      (tester) async {
    final auth = await pumpSignedOut(tester);
    auth.failingEmails.add('flo@example.com');

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'flo@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Authentication failed.'),
      findsOneWidget,
    );
    expect(find.textContaining('invalid credentials'), findsOneWidget);
    expect(find.byType(ShellBottomBar), findsNothing);
  });

  testWidgets('sign-up mode collects a display name and signs in',
      (tester) async {
    await pumpSignedOut(tester);

    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Flo');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'flo@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'secret123');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.byType(ShellBottomBar), findsOneWidget);
  });

  testWidgets('sign-out from settings returns to the auth screen',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    // The settings list outgrew the test viewport (#147): scroll down.
    // scrollUntilVisible stops once the tile is BUILT (cache extent), which
    // can leave it a few px off-screen — ensureVisible finishes the job.
    await tester.scrollUntilVisible(find.text('Sign out'), 100);
    await tester.ensureVisible(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });

  testWidgets('auth screen meets the tap-target guideline', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpSignedOut(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });
}
