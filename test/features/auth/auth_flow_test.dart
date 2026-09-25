// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Sign-in, sign-up and sign-out move between the auth screen and the
// shell; a failure stays put with an error.
import 'dart:async';

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

  testWidgets('failed sign-in keeps the refusal on the form and stays put',
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

    // #1649 — the refusal is a banner IN the form, not a snackbar that
    // slides away, and it is our sentence: the server's own wording
    // ("invalid credentials" in the fake) is never shown.
    expect(find.byKey(const ValueKey('auth-outcome')), findsOneWidget);
    expect(
      find.textContaining('Authentication failed.'),
      findsOneWidget,
    );
    expect(find.textContaining('invalid credentials'), findsNothing);
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

  testWidgets(
      'Enter pressed twice while the first sign-up is in flight sends ONE',
      (tester) async {
    final auth = await pumpSignedOut(tester);
    auth.gate = Completer<void>();
    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Flo');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'flo@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'secret123');

    // #1649 — the keyboard's Done bypasses the disabled button, so the
    // guard has to live in the submit path itself. Done also drops the
    // focus, so the second press needs the field focused again — or it
    // reaches nobody and the test proves nothing.
    final password = find.byType(TextFormField).at(2);
    await tester.showKeyboard(password);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.showKeyboard(password);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(auth.signUps, ['flo@example.com']);

    auth.gate!.complete();
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

  testWidgets('password visibility toggle reveals and hides the input',
      (tester) async {
    await pumpSignedOut(tester);
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');

    bool obscured() => tester
        .widget<EditableText>(find.byType(EditableText).last)
        .obscureText;

    expect(obscured(), isTrue);

    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(obscured(), isFalse);

    await tester.tap(find.byTooltip('Hide password'));
    await tester.pump();
    expect(obscured(), isTrue);
  });

  testWidgets('auth screen meets the tap-target guideline', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpSignedOut(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    // #402: the iOS floor (44dp) and the LABELED guideline — every
    // tappable must carry a semantic label, or it reads as "button" to a
    // screen reader.
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
