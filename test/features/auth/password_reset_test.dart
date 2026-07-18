// SPDX-License-Identifier: MIT
//
// Forgot-password flow: a one-time code is emailed (Supabase recovery
// OTP — no links, so no Site-URL/deep-link dependency); entering the
// code in the app is the temporary credential that forces setting a
// brand-new password.
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

Future<void> openResetSheet(WidgetTester tester, {String? email}) async {
  if (email != null) {
    await tester.enterText(find.byType(TextFormField).at(0), email);
  }
  await tester.tap(find.text('Forgot password?'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sign-in offers Forgot password; sign-up does not',
      (tester) async {
    await pumpSignedOut(tester);
    expect(find.text('Forgot password?'), findsOneWidget);

    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();
    expect(find.text('Forgot password?'), findsNothing);
  });

  testWidgets(
      'requesting a code prefills the typed email and calls the repository',
      (tester) async {
    final auth = await pumpSignedOut(tester);
    await openResetSheet(tester, email: 'flo@example.com');

    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('reset-email')))
          .controller
          ?.text,
      'flo@example.com',
    );
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    expect(auth.resetRequests, ['flo@example.com']);
    expect(find.text('Code sent — check your email.'), findsOneWidget);
    expect(find.byKey(const ValueKey('reset-code')), findsOneWidget);
    expect(find.byKey(const ValueKey('reset-password')), findsOneWidget);
  });

  testWidgets(
      'code + new password sets the password and signs the user in',
      (tester) async {
    final auth = await pumpSignedOut(tester);
    await openResetSheet(tester, email: 'flo@example.com');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('reset-code')),
      '123456',
    );
    await tester.enterText(
      find.byKey(const ValueKey('reset-password')),
      'brandnewpw',
    );
    await tester.tap(find.text('Set new password'));
    await tester.pumpAndSettle();

    expect(auth.confirmedResets.single,
        ('flo@example.com', '123456', 'brandnewpw'));
    // Signed in: the shell replaced the auth screen.
    expect(find.byType(ShellBottomBar), findsOneWidget);
  });

  testWidgets('an invalid code shows the dedicated error and stays put',
      (tester) async {
    final auth = await pumpSignedOut(tester);
    auth.failingCodes.add('000000');
    await openResetSheet(tester, email: 'flo@example.com');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('reset-code')),
      '000000',
    );
    await tester.enterText(
      find.byKey(const ValueKey('reset-password')),
      'brandnewpw',
    );
    await tester.tap(find.text('Set new password'));
    await tester.pumpAndSettle();

    expect(find.text('That code is invalid or expired.'), findsOneWidget);
    expect(find.byType(ShellBottomBar), findsNothing);
  });

  testWidgets('a too-short new password never reaches the repository',
      (tester) async {
    final auth = await pumpSignedOut(tester);
    await openResetSheet(tester, email: 'flo@example.com');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('reset-code')),
      '123456',
    );
    await tester.enterText(
      find.byKey(const ValueKey('reset-password')),
      'short',
    );
    await tester.tap(find.text('Set new password'));
    await tester.pumpAndSettle();

    expect(auth.confirmedResets, isEmpty);
    expect(find.text('At least 8 characters'), findsOneWidget);
  });
}
