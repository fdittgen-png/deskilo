// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Forgot-password flow: a one-time code is emailed (Supabase recovery
// OTP — no links, so no Site-URL/deep-link dependency); entering the
// code in the app is the temporary credential that forces setting a
// brand-new password. Send, verify and save are three answers (#1649):
// a code accepted before a save that failed is its own step, retried
// through the update seam and never by redeeming the code again;
// "Password updated" is said only when the update itself landed;
// dismissing the sheet at that step cleans the recovery session up; a
// late answer after the sheet closed lands nowhere. Deterministic:
// completer-backed fake, no sleeps.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:deskilo/features/auth/domain/auth_outcome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

const _updated = 'Password updated — you are signed in.';
final _code = find.byKey(const ValueKey('reset-code'));
final _password = find.byKey(const ValueKey('reset-password'));
final _primary = find.byKey(const ValueKey('reset-primary'));
final _cancel = find.byKey(const ValueKey('reset-cancel'));

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

/// Opens the sheet, sends the code, and fills [code] + [newPassword].
Future<void> atVerify(
  WidgetTester tester, {
  String code = '123456',
  String newPassword = 'brandnewpw',
}) async {
  await openResetSheet(tester, email: 'flo@example.com');
  await tester.tap(find.text('Send code'));
  await tester.pumpAndSettle();
  await tester.enterText(_code, code);
  await tester.enterText(_password, newPassword);
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
    expect(_code, findsOneWidget);
    expect(_password, findsOneWidget);
  });

  testWidgets('code + new password sets the password, signs the user in '
      'and says so', (tester) async {
    final auth = await pumpSignedOut(tester);
    await atVerify(tester);
    await tester.tap(find.text('Set new password'));
    await tester.pumpAndSettle();

    expect(auth.confirmedResets.single,
        ('flo@example.com', '123456', 'brandnewpw'));
    expect(find.byType(ShellBottomBar), findsOneWidget);
    expect(find.text(_updated), findsOneWidget);
  });

  testWidgets('an invalid code shows the dedicated error and stays put',
      (tester) async {
    final auth = await pumpSignedOut(tester);
    auth.failingCodes.add('000000');
    await atVerify(tester, code: '000000');
    await tester.tap(find.text('Set new password'));
    await tester.pumpAndSettle();

    expect(find.text('That code is invalid or expired.'), findsOneWidget);
    expect(find.byType(ShellBottomBar), findsNothing);
  });

  testWidgets('a too-short new password never reaches the repository',
      (tester) async {
    final auth = await pumpSignedOut(tester);
    await atVerify(tester, newPassword: 'short');
    await tester.tap(find.text('Set new password'));
    await tester.pumpAndSettle();

    expect(auth.confirmedResets, isEmpty);
    expect(find.text('At least 8 characters'), findsOneWidget);
  });

  testWidgets('a rate-limited request stays on the e-mail step and says so',
      (tester) async {
    final auth = await pumpSignedOut(tester);
    auth.resetRequestResult = const AuthResult.rateLimited();
    await openResetSheet(tester, email: 'flo@example.com');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    // "sent" is the server's answer, not the button's.
    expect(_code, findsNothing);
    expect(find.textContaining('Too many attempts'), findsOneWidget);
    expect(find.text('Code sent — check your email.'), findsNothing);
  });

  testWidgets('a code accepted but a password not saved is its own step: '
      'no code field, the retry goes through the update seam, then done',
      (tester) async {
    final auth = await pumpSignedOut(tester);
    auth.confirmResetResult =
        const AuthResult.recoverySessionReadyButPasswordNotUpdated();
    await atVerify(tester);
    await tester.tap(find.text('Set new password'));
    await tester.pumpAndSettle();

    expect(find.textContaining('the new password was not saved'),
        findsOneWidget);
    expect(find.text('That code is invalid or expired.'), findsNothing);
    expect(_code, findsNothing, reason: 'the code is spent');
    expect(find.text('Save the new password again'), findsOneWidget);
    expect(find.byType(ShellBottomBar), findsNothing);
    expect(find.text(_updated), findsNothing);

    await tester.tap(_primary);
    await tester.pumpAndSettle();
    expect(auth.passwordUpdates, ['brandnewpw']);
    expect(auth.confirmedResets, isEmpty, reason: 'never redeemed twice');
    expect(find.byType(ShellBottomBar), findsOneWidget);
    expect(find.text(_updated), findsOneWidget);
  });

  testWidgets('a retry that finds the session gone goes back to the code '
      'step with its own sentence', (tester) async {
    final auth = await pumpSignedOut(tester);
    auth.confirmResetResult =
        const AuthResult.recoverySessionReadyButPasswordNotUpdated();
    auth.updatePasswordResult = const AuthResult.recoveryVerificationRequired();
    await atVerify(tester);
    await tester.tap(find.text('Set new password'));
    await tester.pumpAndSettle();
    await tester.tap(_primary);
    await tester.pumpAndSettle();

    expect(find.textContaining('no longer valid here'), findsOneWidget);
    expect(_code, findsOneWidget);
    expect(find.text('Set new password'), findsOneWidget);
    expect(find.byType(ShellBottomBar), findsNothing);
  });

  testWidgets('cancelling after a spent code says nothing and cleans the '
      'recovery session up; cancelling before one touches nothing',
      (tester) async {
    final auth = await pumpSignedOut(tester);
    await openResetSheet(tester, email: 'flo@example.com');
    await tester.tap(_cancel);
    await tester.pumpAndSettle();
    expect(auth.recoveryCancelled, isFalse);

    auth.confirmResetResult =
        const AuthResult.recoverySessionReadyButPasswordNotUpdated();
    await atVerify(tester);
    await tester.tap(find.text('Set new password'));
    await tester.pumpAndSettle();
    await tester.tap(_cancel);
    await tester.pumpAndSettle();

    expect(find.text(_updated), findsNothing);
    expect(find.byType(ShellBottomBar), findsNothing);
    expect(auth.recoveryCancelled, isTrue);
  });

  testWidgets('closing the sheet while the code is being verified: the '
      'late answer neither navigates nor throws', (tester) async {
    final auth = await pumpSignedOut(tester);
    await atVerify(tester);
    auth.gate = Completer<void>();
    await tester.tap(find.text('Set new password'));
    await tester.pump();
    await tester.tap(_cancel);
    await tester.pumpAndSettle();
    auth.gate!.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(_updated), findsNothing);
    expect(find.byKey(const ValueKey('reset-email')), findsNothing);
  });

  testWidgets('Enter in the new-password field twice verifies ONCE',
      (tester) async {
    final auth = await pumpSignedOut(tester);
    await atVerify(tester);
    auth.gate = Completer<void>();
    await tester.showKeyboard(_password);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.showKeyboard(_password);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    auth.gate!.complete();
    await tester.pumpAndSettle();

    expect(auth.confirmedResets.length, 1);
    expect(find.byType(ShellBottomBar), findsOneWidget);
  });

  testWidgets('the sheet meets the tap-target guidelines at every step',
      (tester) async {
    final handle = tester.ensureSemantics();
    final auth = await pumpSignedOut(tester);
    auth.confirmResetResult =
        const AuthResult.recoverySessionReadyButPasswordNotUpdated();
    await openResetSheet(tester, email: 'flo@example.com');
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await tester.enterText(_code, '123456');
    await tester.enterText(_password, 'brandnewpw');
    await tester.tap(find.text('Set new password'));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
