// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1650 — the draft on the device round-trips every purpose and nothing
// else: no credential word ever appears in it, and a draft of another
// version, garbage, an unknown purpose or a location that no longer
// validates is dropped rather than reinterpreted.
import 'package:deskilo/app/entry_intent.dart';
import 'package:deskilo/app/entry_intents.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('draft', () {
    final expires = DateTime.utc(2026, 9, 26, 12);
    EntryIntentDraft draft(EntryIntent intent, {String? user}) =>
        EntryIntentDraft(
          intent: intent,
          installation: 'default',
          userId: user,
          expiresAt: expires,
        );

    test('round-trips every purpose', () {
      for (final intent in [
        const EntryIntent.defaultEntry('a'),
        const EntryIntent.openValidated('b', '/help?topic=Privacy'),
        const EntryIntent.join('c', workspaceHint: 'Space'),
        const EntryIntent.create('d'),
        const EntryIntent.connectInstallation('e', host: 'h.example'),
        EntryIntent.account('f', AccountSection.privacy),
        const EntryIntent.consentReference('g', reference: 'ref-1'),
      ]) {
        final back = EntryIntentDraft.decode(draft(intent, user: 'u').encode());
        expect(back, isNotNull, reason: '$intent');
        expect(back!.intent.id, intent.id);
        expect(back.intent.purpose, intent.purpose);
        expect(back.intent.target, intent.target);
        expect(back.intent.hint, intent.hint);
        expect(back.userId, 'u');
        expect(back.expiresAt, expires);
      }
    });

    test('the encoded draft never carries a credential word', () {
      final json = draft(const EntryIntent.join('c', workspaceHint: 'Space'),
              user: 'u')
          .encode()
          .toLowerCase();
      for (final canary in kCredentialCanaries) {
        expect(json, isNot(contains('"$canary"')));
      }
    });

    test('another version, garbage, an unknown purpose and a location that '
        'no longer validates are dropped', () {
      expect(EntryIntentDraft.decode('not json'), isNull);
      expect(EntryIntentDraft.decode('[]'), isNull);
      expect(EntryIntentDraft.decode('{"v":0,"id":"a","purpose":"open",'
          '"target":"/money","installation":"default",'
          '"expires":"2026-09-26T12:00:00Z"}'), isNull);
      expect(EntryIntentDraft.decode('{"v":1,"id":"a","purpose":"teleport",'
          '"installation":"default","expires":"2026-09-26T12:00:00Z"}'),
          isNull);
      expect(EntryIntentDraft.decode('{"v":1,"id":"a","purpose":"open",'
          '"target":"/money?access_token=x","installation":"default",'
          '"expires":"2026-09-26T12:00:00Z"}'), isNull);
      expect(EntryIntentDraft.decode('{"v":1,"id":"a","purpose":"open",'
          '"target":"https://evil.example/","installation":"default",'
          '"expires":"2026-09-26T12:00:00Z"}'), isNull);
    });
  });
}
