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
}
