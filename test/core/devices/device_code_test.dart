// SPDX-License-Identifier: AGPL-3.0-or-later
// #4466 — the readable pairing code against the shared table (test/fixtures/device_pairing_codes.json), the same table
// the board's host tests read: each case encodes to its code and reads back, each typo is refused for its reason, a code
// typed in lower case with spaces reads as the code; a board's QR reads whole, and gives the same short id and proof.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/core/devices/device_code.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_till_board_journey.dart';

void main() {
  final table = jsonDecode(File('test/fixtures/device_pairing_codes.json').readAsStringSync()) as Map<String, dynamic>;

  test('every code of the shared table encodes and reads back (a profile no board carries yet is refused as unknown)', () {
    final codes = (table['codes'] as List).cast<Map<String, dynamic>>();
    expect(codes, isNotEmpty);
    for (final c in codes) {
      final id = int.parse(c['short_id'] as String, radix: 16);
      expect(readableDeviceCode(id, c['profile'] as int, c['proof'] as int), c['code']);
      final read = readDeviceCode(c['code'] as String);
      if (c['profile'] as int >= BoardProfile.values.length) {
        // a profile no board of today carries: the code is sound, the board unknown to this app
        expect((read as DeviceCodeRefused).reason, DeviceCodeRefusal.profile, reason: c['code'] as String);
        continue;
      }
      expect(read, isA<DeviceCodeOk>(), reason: c['code'] as String);
      final code = (read as DeviceCodeOk).code;
      expect(code.shortId, (c['short_id'] as String).toUpperCase());
      expect(code.profile, BoardProfile.values[c['profile'] as int]);
      expect(code.proof, c['proof']);
    }
  });

  test('every typo of the shared table is refused for its reason', () {
    const reasons = {'check': DeviceCodeRefusal.check, 'alphabet': DeviceCodeRefusal.alphabet, 'length': DeviceCodeRefusal.length};
    for (final c in (table['refused'] as List).cast<Map<String, dynamic>>()) {
      final read = readDeviceCode(c['code'] as String);
      expect(read, isA<DeviceCodeRefused>(), reason: c['code'] as String);
      expect((read as DeviceCodeRefused).reason, reasons[c['reason']], reason: c['code'] as String);
    }
  });

  test('typed in lower case with spaces, a code reads as itself', () {
    for (final c in (table['lenient'] as List).cast<Map<String, dynamic>>()) {
      final a = readDeviceCode(c['typed'] as String), b = readDeviceCode(c['code'] as String);
      expect(a, isA<DeviceCodeOk>());
      expect((a as DeviceCodeOk).code.shortId, (b as DeviceCodeOk).code.shortId);
      expect(a.code.proof, b.code.proof);
    }
  });

  test("a board's QR reads whole, and agrees with its readable code", () {
    final read = readDeviceCode('deskilo-device:v1?id=11111111-1111-4111-8111-111111111111&board=ideaspark_st7789_v1&fw=1.0.3&fp=AB12-CD34');
    final code = (read as DeviceCodeOk).code;
    expect(code.id, '11111111-1111-4111-8111-111111111111');
    expect(code.profile, BoardProfile.ideaspark);
    expect(code.fingerprintShown, 'AB12-CD34');
    expect(code.firmware, '1.0.3');
    // the board's own host test pins this code for this identity (board_logic_test.c)
    final typed = (readDeviceCode('3DNGP-UN9CG') as DeviceCodeOk).code;
    expect(typed.shortId, code.shortId);
    expect(typed.profile, code.profile);
    expect(typed.proof, code.proof);
    expect(typed.fingerprintShown, 'AB');
  });

  test('a QR of another app, or of a board this app does not know, is refused', () {
    expect((readDeviceCode('https://example.org') as DeviceCodeRefused).reason, DeviceCodeRefusal.length);
    const other = 'deskilo-device:v1?id=11111111-1111-4111-8111-111111111111&board=other_v9&fp=AB12-CD34';
    expect((readDeviceCode(other) as DeviceCodeRefused).reason, DeviceCodeRefusal.profile);
    expect((readDeviceCode(readableDeviceCode(0x1234, 3, 0)) as DeviceCodeRefused).reason, DeviceCodeRefusal.profile);
  });
}
