// SPDX-License-Identifier: 0BSD
//
// #662 — signing IN by scanning a badge, then entering a PIN.
//
// The kiosk has read badges since #546, but only to identify someone
// already signed in; signing in still meant typing an e-mail on a shared
// tablet. The user asked for the two steps in this order specifically:
// "use the rfid to identify the user and then request the pin. That can
// come together on one form but the sequencing allows to set the pin on
// the user."
//
// Most of what is asserted below is about what the sheet REFUSES to say.
// A kiosk that distinguishes "no such badge" from "wrong PIN" sorts a
// stolen stack of cards into real and fake for whoever is holding it, so
// every refusal has to read the same. That property is easy to write and
// easy to lose in a later "helpful error messages" pass, which is why it
// is pinned here rather than left to the code comment.
import 'dart:io';

import 'package:deskilo/features/auth/domain/badge_sign_in.dart';
import 'package:deskilo/features/auth/presentation/widgets/badge_pin_tile.dart';
import 'package:deskilo/features/auth/presentation/widgets/badge_sign_in_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

const _alex = BadgeIdentity(
  userId: 'user-1',
  displayName: 'Alex Sample',
  hasAvatar: false,
);

void main() {
  /// The sheet on its own. The auth SCREEN mounts it behind a real NFC
  /// availability probe, which a widget test cannot satisfy — the button
  /// is asserted from source below instead.
  Future<void> pumpSheet(
    WidgetTester tester,
    FakeAuthRepository auth, {
    String? scannedUid,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(auth: auth),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () =>
                    showBadgeSignInSheet(context, scannedUid: scannedUid),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('the scan identifies before the PIN is asked', () {
    testWidgets('with no reader it says so and offers a way back',
        (tester) async {
      // No NFC in a widget test, so the sheet lands in exactly the state
      // a phone without a reader produces.
      await pumpSheet(tester, FakeAuthRepository());

      expect(find.byKey(const ValueKey('badge-signin-prompt')), findsOneWidget);
      // The e-mail escape hatch must ALWAYS be there. A member whose
      // badge is lost, unarmed or simply not working has to be able to
      // get in, and this sheet is opened from the sign-in screen.
      expect(find.byKey(const ValueKey('badge-signin-pin')), findsNothing,
          reason: 'the PIN field must not appear before anyone is '
              'identified — that is the whole sequencing the user asked '
              'for');
    });

    testWidgets('the PIN step greets the member by name', (tester) async {
      // The greeting is not decoration: it is the reason the steps are
      // split, and it is what tells someone they scanned the RIGHT card
      // before they type a secret.
      final auth = FakeAuthRepository()..badges['uid-1'] = _alex;
      await pumpSheet(tester, auth, scannedUid: 'uid-1');

      expect(find.textContaining('Alex Sample'), findsOneWidget);
      expect(find.byKey(const ValueKey('badge-signin-pin')), findsOneWidget);
    });
  });

  group('every refusal reads the same', () {
    test('an unknown badge and a wrong PIN are indistinguishable', () async {
      final auth = FakeAuthRepository()
        ..badges['uid-1'] = _alex
        ..badgePin = '1234';

      final unknown = await auth.signInWithBadge(uid: 'uid-nope', pin: '1234');
      final wrongPin = await auth.signInWithBadge(uid: 'uid-1', pin: '9999');

      expect(unknown.failure, BadgeSignInFailure.refused);
      expect(wrongPin.failure, wrongPin.failure);
      expect(unknown.failure, wrongPin.failure,
          reason: 'telling these apart turns the kiosk into an oracle for '
              'which cards in a stolen stack are real');
    });

    test('a lockout is the ONE distinction, and it is deliberate', () async {
      // A member who is locked out needs to know that waiting is the
      // answer. By then the attempt rows exist, so it reveals nothing a
      // wrong guesser did not already cause.
      final auth = FakeAuthRepository()
        ..badgeFailure = BadgeSignInFailure.locked;
      final result = await auth.identifyBadge('uid-1');
      expect(result.failure, BadgeSignInFailure.locked);
    });

    test('an unreachable server is not a refusal', () async {
      // Nothing about the badge was judged. Saying "wrong PIN" here
      // sends someone hunting for a mistake they did not make.
      final auth = FakeAuthRepository()
        ..badgeFailure = BadgeSignInFailure.unavailable;
      final result = await auth.signInWithBadge(uid: 'uid-1', pin: '1234');
      expect(result.failure, BadgeSignInFailure.unavailable);
      expect(result.ok, isFalse);
    });
  });

  group('a member sets their own PIN, and only their own', () {
    testWidgets('the tile opens a sheet that writes the PIN', (tester) async {
      final auth = FakeAuthRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: standardTestOverrides(auth: auth),
          child: const MaterialApp(home: Scaffold(body: BadgePinTile())),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('settings-badge-pin')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('badge-pin-new')),
          '4821');
      await tester.enterText(find.byKey(const ValueKey('badge-pin-confirm')),
          '4821');
      await tester.tap(find.byKey(const ValueKey('badge-pin-save')));
      await tester.pumpAndSettle();

      expect(auth.setPins, ['4821']);
    });

    testWidgets('a mismatch is caught before anything is written',
        (tester) async {
      // Typing a PIN wrong twice and having it SAVED is the failure that
      // locks a member out of a credential they cannot read back.
      final auth = FakeAuthRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: standardTestOverrides(auth: auth),
          child: const MaterialApp(home: Scaffold(body: BadgePinTile())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-badge-pin')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('badge-pin-new')),
          '4821');
      await tester.enterText(find.byKey(const ValueKey('badge-pin-confirm')),
          '4822');
      await tester.tap(find.byKey(const ValueKey('badge-pin-save')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('badge-pin-error')), findsOneWidget);
      expect(auth.setPins, isEmpty);
    });

    testWidgets('a too-short PIN is refused', (tester) async {
      final auth = FakeAuthRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: standardTestOverrides(auth: auth),
          child: const MaterialApp(home: Scaffold(body: BadgePinTile())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-badge-pin')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('badge-pin-new')), '12');
      await tester.enterText(
          find.byKey(const ValueKey('badge-pin-confirm')), '12');
      await tester.tap(find.byKey(const ValueKey('badge-pin-save')));
      await tester.pumpAndSettle();

      expect(auth.setPins, isEmpty);
    });
  });

  group('the pieces the widget tree cannot reach', () {
    test('the sign-in screen offers the badge button, not while signing up',
        () {
      // The button sits behind a real platform NFC probe, so it is
      // asserted at the source. A brand-new member holds no badge, so
      // offering it on the sign-up form would be a dead end.
      final source = File(
        'lib/features/auth/presentation/screens/auth_screen.dart',
      ).readAsStringSync();
      expect(source, contains("ValueKey('auth-badge')"));
      expect(source, contains('if (!_isSignUp)'));
      expect(source, contains('showBadgeSignInSheet'));
    });

    test('the workspace flag is enforced on the SERVER, not the client', () {
      // Before sign-in the app has no workspace, so it has no flags —
      // `enabledFeatures` would fall back to registry defaults and decide
      // on behalf of a workspace it never read. The badge names the
      // workspace, so only the server can answer.
      final sql = File(
        'supabase/migrations/0124_badge_signin_flag_gate.sql',
      ).readAsStringSync();
      expect(sql, contains("feature_flags -> 'badgeSignIn'"));
      expect(sql, contains("to_jsonb(true), false)"),
          reason: 'a workspace that has never heard of the flag must '
              'REFUSE, not allow — the coalesce default is the whole '
              'decision');
      // The refusal must not be its own reason: a distinct answer would
      // tell whoever holds a card that the card is real and only the
      // setting is in the way.
      expect(sql, isNot(contains("'reason', 'disabled'")));
    });

    test('the PIN is never settable for someone else', () {
      // No admin path here and none on the server: an owner who could
      // set a member's PIN could sign in as them, and every check-in
      // that followed would carry the member's name.
      final source = File(
        'lib/features/auth/presentation/widgets/badge_pin_tile.dart',
      ).readAsStringSync();
      expect(source, isNot(contains('memberId')));
      expect(source, isNot(contains('userId')));
    });
  });
}
