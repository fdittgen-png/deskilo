// SPDX-License-Identifier: 0BSD
//
// Profile model round-trip (#223, status_text since #231) plus the
// normalization rules: WhatsApp (keep digits, fold a leading 00 into +,
// prepend +; blank clears) and the status line (trim + hard cap at
// StatusTextRules.maxLength; blank clears).
import 'package:deskilo/features/profile/domain/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Profile.fromDb/toDb', () {
    test('round-trips a full row', () {
      final db = {
        'id': 'user-1',
        'display_name': 'Ada',
        'whatsapp': '+33612345678',
        'status_text': 'In a call · back at 14:00',
        'last_seen_at': '2026-07-11T09:30:00.000Z',
        'avatar_path': 'user-1/avatar',
      };
      final profile = Profile.fromDb(db);

      expect(profile.id, 'user-1');
      expect(profile.displayName, 'Ada');
      expect(profile.whatsapp, '+33612345678');
      expect(profile.statusText, 'In a call · back at 14:00');
      expect(profile.hasStatus, isTrue);
      expect(profile.lastSeenAt, DateTime.utc(2026, 7, 11, 9, 30));
      expect(profile.hasAvatar, isTrue);
      expect(profile.avatarPath, 'user-1/avatar');
      expect(profile.toDb(), db);
    });

    test('tolerates a pre-0028/0029 row (columns absent) and null heartbeat',
        () {
      final profile = Profile.fromDb(const {
        'id': 'user-2',
        'display_name': 'Grace',
      });

      expect(profile.whatsapp, '');
      expect(profile.sharesWhatsapp, isFalse);
      expect(profile.statusText, '');
      expect(profile.hasStatus, isFalse);
      expect(profile.lastSeenAt, isNull);
      expect(profile.toDb()['last_seen_at'], isNull);
    });

    test('whatsappUri is the wa.me link without the +, null when unshared',
        () {
      const shared = Profile(id: 'u', whatsapp: '+33612345678');
      const unshared = Profile(id: 'u');

      expect(shared.whatsappUri, Uri.parse('https://wa.me/33612345678'));
      expect(unshared.whatsappUri, isNull);
    });
  });

  group('normalizeWhatsapp', () {
    test('strips spacing and punctuation down to + and digits', () {
      expect(
        normalizeWhatsapp('+33 6 12-34.56.78'),
        '+33612345678',
      );
      expect(
        normalizeWhatsapp('(+49) 151 / 2345 6789'),
        '+4915123456789',
      );
    });

    test('folds the 00 international dialing prefix into +', () {
      expect(normalizeWhatsapp('0033612345678'), '+33612345678');
    });

    test('prepends + when the input had none', () {
      expect(normalizeWhatsapp('33612345678'), '+33612345678');
    });

    test('blank or digit-less input normalizes to empty (clears)', () {
      expect(normalizeWhatsapp(''), '');
      expect(normalizeWhatsapp('   '), '');
      expect(normalizeWhatsapp('none'), '');
    });
  });

  group('normalizeStatusText (#231)', () {
    test('pins the 40-char cap the editor, normalizer and 0029 check share',
        () {
      expect(StatusTextRules.maxLength, 40);
    });

    test('trims surrounding whitespace', () {
      expect(
        normalizeStatusText('  In a call · back at 14:00  '),
        'In a call · back at 14:00',
      );
    });

    test('hard-caps over-long input at exactly maxLength', () {
      final over = 'x' * (StatusTextRules.maxLength + 15);
      final capped = normalizeStatusText(over);

      expect(capped.length, StatusTextRules.maxLength);
      expect(capped, 'x' * StatusTextRules.maxLength);
      // At or under the cap passes through untouched.
      final exact = 'y' * StatusTextRules.maxLength;
      expect(normalizeStatusText(exact), exact);
    });

    test('caps by code points (Postgres char_length semantics), not '
        'UTF-16 units', () {
      // 25 astral-plane emoji = 25 code points but 50 UTF-16 units; the
      // 0029 check counts 25, so nothing may be cut off.
      final emoji = '\u{1F600}' * 25;
      expect(normalizeStatusText(emoji), emoji);
      // 45 of them exceed the cap by code points → exactly 40 survive.
      expect(
        normalizeStatusText('\u{1F600}' * 45),
        '\u{1F600}' * StatusTextRules.maxLength,
      );
    });

    test('blank input normalizes to empty (clears)', () {
      expect(normalizeStatusText(''), '');
      expect(normalizeStatusText('   '), '');
    });
  });
}
