// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1650 — an EntryIntent is a requested action and an immutable target,
// never a URL the app was handed: a return location is accepted only
// when it is a registered route with display queries and no credential
// anywhere in it; a draft on the device is resumed only in the same
// version, on the same installation, for the same account, before it
// expires. Every refusal here is a canary — the place a secret would
// have slipped into the device's preferences.
import 'package:deskilo/app/entry_intent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validatedLocation', () {
    const accepted = {
      '/money': '/money',
      '/member/m-12': '/member/m-12',
      '/help?topic=Privacy&anchor=x': '/help?topic=Privacy&anchor=x',
      '/consent?review=1': '/consent?review=1',
      '/workspace-code': '/workspace-code',
      '/onboarding': '/onboarding',
    };
    for (final entry in accepted.entries) {
      test('accepts ${entry.key}', () {
        expect(EntryIntent.validatedLocation(entry.key), entry.value);
      });
    }

    const refused = [
      '',
      'money',
      'https://evil.example/money',
      '//evil.example/money',
      'javascript:alert(1)',
      r'/money\@evil',
      '/money#access_token=abc',
      '/auth',
      '/auth?next=/money',
      '/nowhere',
      '/money?next=https://evil.example',
      '/reserve?first=1&code=123456',
      '/res/otp-123456',
      '/member/token-abc',
      '/member/pkce_verifier',
      '/help?topic=code',
      '/help?topic=my%20password',
      '/space/kind/state',
    ];
    for (final raw in refused) {
      test('refuses "$raw"', () {
        expect(EntryIntent.validatedLocation(raw), isNull);
      });
    }
  });

  group('destination', () {
    test('each purpose opens its own screen; future references open none',
        () {
      expect(const EntryIntent.defaultEntry('1').destination, '/reserve');
      expect(const EntryIntent.openValidated('1', '/money').destination,
          '/money');
      expect(const EntryIntent.join('1', workspaceHint: 'Pézenas').destination,
          '/onboarding');
      expect(const EntryIntent.create('1').destination, '/onboarding');
      expect(
          const EntryIntent.connectInstallation('1', host: 'db.example.org')
              .destination,
          '/server');
      expect(EntryIntent.account('1', AccountSection.linkedAccounts)
          .destination, '/linked-accounts');
      expect(EntryIntent.account('1', AccountSection.consentReview)
          .destination, '/consent?review=1');
      expect(const EntryIntent.consentReference('1', reference: 'r').destination,
          isNull);
      expect(const EntryIntent.actionConfirmation('1', reference: 'r')
          .destination, isNull);
    });

    test('a hint is carried, never used as a target', () {
      const intent = EntryIntent.join('1', workspaceHint: 'Test Space');
      expect(intent.target, isNull);
      expect(intent.hint, 'Test Space');
    });
  });
}
