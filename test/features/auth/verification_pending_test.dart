// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1649 — a sign-up the server answered with an e-mail instead of a
// session lands in a check-e-mail STATE that names the address and
// offers the three ways on; resend goes through the resend seam under a
// cooldown the server can lengthen; leaving the state keeps the
// nonsecret fields and drops the password; a late answer after the state
// is gone lands nowhere. Deterministic: completer-backed fake, pumped
// time, no sleeps.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:deskilo/features/auth/domain/auth_outcome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

const _email = 'flo@example.com';
final _resend = find.byKey(const ValueKey('verify-resend'));
final _pending = find.byKey(const ValueKey('auth-pending'));

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

/// Signs up as Flo; the fake answers whatever [auth.signUpResult] says.
Future<void> signUp(WidgetTester tester) async {
  await tester.tap(find.text('New here? Create an account'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).at(0), 'Flo');
  await tester.enterText(find.byType(TextFormField).at(1), _email);
  await tester.enterText(find.byType(TextFormField).at(2), 'secret123');
  await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
  await tester.pumpAndSettle();
}

Future<FakeAuthRepository> pumpPending(WidgetTester tester) async {
  final auth = await pumpSignedOut(tester);
  auth.signUpResult = const AuthResult.verificationRequired();
  await signUp(tester);
  expect(_pending, findsOneWidget);
  return auth;
}

bool enabled(WidgetTester tester, Finder f) =>
    tester.widget<FilledButton>(f).enabled;

void main() {
  test('the resend cooldown is gotrue\'s minimum between two e-mails', () {
    expect(AuthCooldowns.resend, const Duration(seconds: 60));
  });

  testWidgets('a sign-up without a session shows the check-e-mail state '
      'with the address, no form, no shell', (tester) async {
    await pumpPending(tester);
    expect(find.byType(ShellBottomBar), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.textContaining(_email), findsOneWidget);
    // Sent, not delivered, not confirmed.
    expect(find.textContaining('confirmed'), findsNothing);
  });

  testWidgets('resend waits out the cooldown, then goes through the '
      'resend seam — never a second sign-up', (tester) async {
    final auth = await pumpPending(tester);
    expect(enabled(tester, _resend), isFalse);
    await tester.pump(AuthCooldowns.resend);
    await tester.pump();
    expect(enabled(tester, _resend), isTrue);

    await tester.tap(_resend);
    await tester.pumpAndSettle();
    expect(auth.resends, [_email]);
    expect(auth.signUps, [_email], reason: 'the one from the form');
    expect(find.text('Sent again.'), findsOneWidget);
    expect(enabled(tester, _resend), isFalse, reason: 'cooling down again');
    await tester.pump(AuthCooldowns.resend);
  });

  testWidgets('a rate-limited resend waits the SERVER\'s time, not ours',
      (tester) async {
    final auth = await pumpPending(tester);
    auth.resendResult =
        const AuthResult.rateLimited(retryAfter: Duration(seconds: 42));
    await tester.pump(AuthCooldowns.resend);
    await tester.pump();
    await tester.tap(_resend);
    await tester.pumpAndSettle();

    expect(find.textContaining('Too many attempts'), findsOneWidget);
    expect(enabled(tester, _resend), isFalse);
    await tester.pump(const Duration(seconds: 41));
    expect(enabled(tester, _resend), isFalse);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(enabled(tester, _resend), isTrue);
  });

  testWidgets('Use another address returns to sign-up with the name and '
      'address kept and the password gone', (tester) async {
    await pumpPending(tester);
    await tester.tap(find.byKey(const ValueKey('verify-change-email')));
    await tester.pumpAndSettle();

    expect(_pending, findsNothing);
    expect(find.text('Create account'), findsWidgets);
    final fields = find.byType(TextFormField);
    expect(tester.widget<TextFormField>(fields.at(0)).controller?.text, 'Flo');
    expect(tester.widget<TextFormField>(fields.at(1)).controller?.text, _email);
    expect(tester.widget<TextFormField>(fields.at(2)).controller?.text, '');
  });

  testWidgets('Back to sign in keeps the address and lands on sign-in',
      (tester) async {
    await pumpPending(tester);
    await tester.tap(find.byKey(const ValueKey('verify-back')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField).at(0))
          .controller
          ?.text,
      _email,
    );
  });

  testWidgets('leaving while a resend is in flight: the late answer lands '
      'nowhere', (tester) async {
    final auth = await pumpPending(tester);
    await tester.pump(AuthCooldowns.resend);
    await tester.pump();
    auth.gate = Completer<void>();
    await tester.tap(_resend);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('verify-change-email')));
    await tester.pumpAndSettle();
    auth.gate!.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(_pending, findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(3));
  });

  testWidgets('sign-in refused for an unconfirmed address continues in '
      'the check-e-mail state', (tester) async {
    final auth = await pumpSignedOut(tester);
    auth.signInResult =
        const AuthResult.refused(AuthRefusal.emailNotConfirmed);
    await tester.enterText(find.byType(TextFormField).at(0), _email);
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(_pending, findsOneWidget);
    expect(find.textContaining(_email), findsOneWidget);
    await tester.pump(AuthCooldowns.resend);
  });

  testWidgets('sign-in accepts an existing short password; sign-up still '
      'asks for eight characters', (tester) async {
    final auth = await pumpSignedOut(tester);
    await tester.enterText(find.byType(TextFormField).at(0), _email);
    await tester.enterText(find.byType(TextFormField).at(1), 'abc');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.byType(ShellBottomBar), findsOneWidget,
        reason: 'the server, not the creation policy, judges it');

    await tester.pumpWidget(const SizedBox());
    final fresh = await pumpSignedOut(tester);
    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Flo');
    await tester.enterText(find.byType(TextFormField).at(1), _email);
    await tester.enterText(find.byType(TextFormField).at(2), 'abc');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(find.text('At least 8 characters'), findsOneWidget);
    expect(fresh.signUps, isEmpty);
    expect(auth.signUps, isEmpty);
  });

  testWidgets('the password field tells the manager new vs existing',
      (tester) async {
    await pumpSignedOut(tester);
    List<String>? hints() => tester
        .widget<EditableText>(find.byType(EditableText).last)
        .autofillHints
        ?.toList();
    expect(hints(), [AutofillHints.password]);
    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();
    expect(hints(), [AutofillHints.newPassword]);
  });

  testWidgets('the check-e-mail state meets the tap-target guidelines',
      (tester) async {
    final handle = tester.ensureSemantics();
    await pumpPending(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
    await tester.pump(AuthCooldowns.resend);
  });
}
