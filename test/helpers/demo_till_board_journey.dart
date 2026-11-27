// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4466 -- the till board journey: the owner types the readable code of the Demo's till board (the ideaspark board the
// firmware's host test pins, id 11111111-…, fingerprint AB12-CD34): the board is found with its model and the first
// digits of its fingerprint; the same code with two symbols swapped is refused by its check, and its QR gives the same
// board. Shared by the scenario checklist. [readableDeviceCode] is the board's encoder, for the tests that need a code.
import 'package:deskilo/core/devices/device_code.dart';

const _alphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';

/// The readable code of [shortId] (32 bits), [profile] (0-3) and [proof] (10 bits): what the board shows
/// (firmware/till/main/readable_code.c, `readable_code_encode`).
String readableDeviceCode(int shortId, int profile, int proof) {
  var v = shortId * 4096 + (profile % 4) * 1024 + proof % 1024;
  final digits = List.filled(9, 0);
  for (var i = 8; i >= 0; i--) {
    digits[i] = v % 31;
    v ~/= 31;
  }
  var sum = 0;
  for (var i = 0; i < 9; i++) {
    sum += (i + 1) * digits[i];
  }
  final s = [for (final d in digits) _alphabet[d], _alphabet[sum % 31]].join();
  return '${s.substring(0, 5)}-${s.substring(5)}';
}

/// True when the Demo board's typed code, a typo of it and its QR answer as they should.
bool tillBoardJourney() {
  final code = readableDeviceCode(
    0x11111111,
    BoardProfile.ideaspark.index,
    (0xAB << 2) | (0x12 >> 6),
  );
  final typed = readDeviceCode(code);
  if (typed is! DeviceCodeOk) return false;
  if (typed.code.shortId != '11111111' ||
      typed.code.profile != BoardProfile.ideaspark ||
      typed.code.fingerprintShown != 'AB') {
    return false;
  }
  final s = code.replaceAll('-', '');
  final swapped = '${s[1]}${s[0]}${s.substring(2)}';
  final typo = readDeviceCode(swapped);
  if (typo is! DeviceCodeRefused || typo.reason != DeviceCodeRefusal.check) {
    return false;
  }
  final qr = readDeviceCode(
    'deskilo-device:v1?id=11111111-1111-4111-8111-111111111111&board=ideaspark_st7789_v1&fw=1.0.3&fp=AB12-CD34',
  );
  return qr is DeviceCodeOk &&
      qr.code.shortId == typed.code.shortId &&
      qr.code.proof == typed.code.proof;
}
