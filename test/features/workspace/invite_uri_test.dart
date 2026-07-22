// SPDX-License-Identifier: 0BSD
import 'package:deskilo/features/workspace/domain/invite_uri.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InviteUriCodec.encode', () {
    test('member invite URL carries the user role and the code', () {
      final url = InviteUriCodec.encode(
        code: 'GOODCODE22',
        role: InviteRole.user,
      );
      expect(url, 'deskilo://join?role=user&code=GOODCODE22');
    });

    test('admin invite URL carries the admin role and the code', () {
      final url = InviteUriCodec.encode(
        code: 'ADMINCODE33',
        role: InviteRole.admin,
      );
      expect(url, 'deskilo://join?role=admin&code=ADMINCODE33');
    });
  });

  group('InviteUriCodec.decodeCode', () {
    test('extracts the code from an invite URL', () {
      expect(
        InviteUriCodec.decodeCode('deskilo://join?role=admin&code=ADMINCODE33'),
        'ADMINCODE33',
      );
    });

    test('legacy printed QRs — a raw code — pass through unchanged', () {
      expect(InviteUriCodec.decodeCode('GOODCODE22'), 'GOODCODE22');
    });

    test('an invite URL without a code yields the empty string', () {
      expect(InviteUriCodec.decodeCode('deskilo://join?role=user'), '');
    });

    test('unrelated URLs are not mistaken for invite codes', () {
      expect(InviteUriCodec.decodeCode('https://example.com/x'), '');
    });
  });

  group('extractCode (0049 smart paste)', () {
    test('bare code and lone URL behave like decodeCode', () {
      expect(InviteUriCodec.extractCode('mma3eracep'), 'MMA3ERACEP');
      expect(
        InviteUriCodec.extractCode(
          'deskilo://join?role=user&code=MMA3ERACEP',
        ),
        'MMA3ERACEP',
      );
    });

    test('a whole WhatsApp invitation message yields the code — even '
        'with the URL wrapped across lines', () {
      const message = 'Bonjour F ! Vous êtes invité·e à rejoindre notre '
          'espace « test Google » sur DesKilo.\n\n'
          "3. Choisissez « Rejoindre un espace » et saisissez l'identifiant :\n"
          'MMA3ERACEP\n'
          "(ou scannez le QR d'invitation sur place — "
          'deskilo://join?role=user&code=\nMMA3ERACEP)\n\n'
          'À bientôt chez test Google !';
      expect(InviteUriCodec.extractCode(message), 'MMA3ERACEP');
    });

    test('a message without the URL still finds the standalone-ID line',
        () {
      expect(
        InviteUriCodec.extractCode(
          'Join us! The workspace ID:\nGOODCODE22\nsee you soon',
        ),
        'GOODCODE22',
      );
    });

    test('prose without a code, and foreign URLs, yield nothing', () {
      expect(InviteUriCodec.extractCode('just some words here'), '');
      expect(
        InviteUriCodec.extractCode('visit https://example.com/?code=EVIL1 now'),
        '',
      );
    });
  });
}
