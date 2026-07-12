// SPDX-License-Identifier: MIT
//
// Profile model round-trip (#223) plus the WhatsApp normalization rule:
// keep digits, fold a leading 00 into +, prepend +; blank clears.
import 'package:deskilo/features/profile/domain/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Profile.fromDb/toDb', () {
    test('round-trips a full row', () {
      final db = {
        'id': 'user-1',
        'display_name': 'Ada',
        'whatsapp': '+33612345678',
        'last_seen_at': '2026-07-11T09:30:00.000Z',
      };
      final profile = Profile.fromDb(db);

      expect(profile.id, 'user-1');
      expect(profile.displayName, 'Ada');
      expect(profile.whatsapp, '+33612345678');
      expect(profile.lastSeenAt, DateTime.utc(2026, 7, 11, 9, 30));
      expect(profile.toDb(), db);
    });

    test('tolerates a pre-0028 row (columns absent) and null heartbeat',
        () {
      final profile = Profile.fromDb(const {
        'id': 'user-2',
        'display_name': 'Grace',
      });

      expect(profile.whatsapp, '');
      expect(profile.sharesWhatsapp, isFalse);
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
}
