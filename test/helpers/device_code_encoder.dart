// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4466 -- the board's side of the readable pairing code (firmware/till/main/readable_code.c), written again here so the
// app's reader (lib/features/money/domain/device_code.dart) is proved against an encoder it does not share.

const _alphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
const _base = 31, _data = 9, _proofSpace = 1024;

/// The readable code of [shortId] (32 bits), [profile] (0-3) and [proof] (10 bits): what the board shows.
String readableDeviceCode(int shortId, int profile, int proof) {
  var v = shortId * _proofSpace * 4 + (profile % 4) * _proofSpace + proof % _proofSpace;
  final digits = List.filled(_data, 0);
  for (var i = _data - 1; i >= 0; i--) {
    digits[i] = v % _base;
    v ~/= _base;
  }
  var check = 0;
  for (var i = 0; i < _data; i++) {
    check += (i + 1) * digits[i];
  }
  final s = [for (final d in digits) _alphabet[d], _alphabet[check % _base]].join();
  return '${s.substring(0, 5)}-${s.substring(5)}';
}
