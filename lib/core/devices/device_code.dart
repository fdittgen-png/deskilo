// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:meta/meta.dart' show immutable;

/// #4466 — the till boards this app knows, in the order of the profile number the readable code carries (the board's
/// `BOARD_PROFILE_CODE`, firmware/till/main/board.h).
enum BoardProfile {
  e32r40t('lcdwiki_e32r40t_v1', 'LCDwiki E32R40T'),
  ideaspark('ideaspark_st7789_v1', 'ideaspark ST7789');

  const BoardProfile(this.key, this.model);

  /// The profile's name in the QR (`board=`).
  final String key;

  /// The board's model, as printed on it.
  final String model;
}

/// Why a scanned or typed code is not a board's code.
enum DeviceCodeRefusal {
  /// Not a board's QR, and not 10 symbols.
  length,

  /// A symbol a code never holds (0, O, 1, I, L or another sign).
  alphabet,

  /// The check symbol disagrees: a symbol typed wrong, or two swapped.
  check,

  /// A board of a kind this app does not know yet.
  profile,
}

/// What a board's code says. The QR carries the whole id and fingerprint and (#4454) the SHA-256 of the board's secret,
/// which the code that connects the board is bound to; the readable code the id's first 8 hex digits and the
/// fingerprint's first 10 bits (its [proof]).
@immutable
class DeviceCode {
  const DeviceCode({
    required this.shortId,
    required this.profile,
    required this.proof,
    this.id,
    this.fingerprint,
    this.firmware,
    this.secretHash,
  });

  /// The first 8 hex digits of the board's id, upper case.
  final String shortId;
  final BoardProfile profile;
  final int proof;

  /// From the QR only.
  final String? id, fingerprint, firmware;

  /// From the QR of a board whose firmware names it (#4454): the SHA-256 of its secret, lower-case hex. Null for an
  /// older firmware's QR and for a typed code: such a board cannot be connected until it shows a newer QR.
  final String? secretHash;

  /// Whether this code names everything a connection code is made for.
  bool get connectable => id != null && secretHash != null;

  /// The fingerprint to compare with the board's screen: whole from the QR; from a typed code its first two digits.
  String get fingerprintShown => fingerprint ?? (proof >> 2).toRadixString(16).toUpperCase().padLeft(2, '0');
}

/// A code read, or why it is refused.
sealed class DeviceCodeRead {
  const DeviceCodeRead();
}

final class DeviceCodeOk extends DeviceCodeRead {
  const DeviceCodeOk(this.code);
  final DeviceCode code;
}

final class DeviceCodeRefused extends DeviceCodeRead {
  const DeviceCodeRefused(this.reason);
  final DeviceCodeRefusal reason;
}

const _alphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
const _base = 31, _data = 9;
const _qrPrefix = 'deskilo-device:';

// The code's value is short id × 4096 + profile × 1024 + proof: arithmetic, not shifts, because the web build's
// bitwise operators cut at 32 bits.
const _proofSpace = 1024, _codeSpace = 17592186044416; // 2^10, 2^44

/// Reads a board's QR text (`deskilo-device:v1?id=…&board=…&fw=…&fp=…`) or its readable code (`XXXXX-XXXXX`, any
/// case, spaces and dashes ignored).
DeviceCodeRead readDeviceCode(String text) {
  final t = text.trim();
  return t.startsWith(_qrPrefix) ? _readQr(t) : _readTyped(t);
}

DeviceCodeRead _readQr(String t) {
  final query = Uri.tryParse(t)?.queryParameters ?? const <String, String>{};
  String? q(String name) => query[name];
  final id = q('id') ?? '', fp = q('fp') ?? '';
  if (!RegExp(r'^[0-9a-fA-F]{8}-').hasMatch(id) || !RegExp(r'^[0-9A-F]{4}-[0-9A-F]{4}$').hasMatch(fp)) {
    return const DeviceCodeRefused(DeviceCodeRefusal.length);
  }
  final profile = BoardProfile.values.where((p) => p.key == q('board')).firstOrNull;
  if (profile == null) return const DeviceCodeRefused(DeviceCodeRefusal.profile);
  final proof = (int.parse(fp.substring(0, 2), radix: 16) << 2) | (int.parse(fp.substring(2, 4), radix: 16) >> 6);
  // the secret's hash, when the QR names it, must give the fingerprint the QR shows
  final hash = q('h');
  if (hash != null &&
      (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hash) ||
          '${hash.substring(0, 4)}-${hash.substring(4, 8)}'.toUpperCase() != fp)) {
    return const DeviceCodeRefused(DeviceCodeRefusal.check);
  }
  return DeviceCodeOk(DeviceCode(
    shortId: id.substring(0, 8).toUpperCase(),
    profile: profile,
    proof: proof,
    id: id.toLowerCase(),
    fingerprint: fp,
    firmware: q('fw'),
    secretHash: hash,
  ));
}

DeviceCodeRead _readTyped(String t) {
  final s = t.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
  if (s.length != _data + 1) return const DeviceCodeRefused(DeviceCodeRefusal.length);
  final digits = [for (final c in s.split('')) _alphabet.indexOf(c)];
  if (digits.contains(-1)) return const DeviceCodeRefused(DeviceCodeRefusal.alphabet);
  if (_check(digits.sublist(0, _data)) != digits[_data]) return const DeviceCodeRefused(DeviceCodeRefusal.check);
  var v = 0;
  for (final d in digits.take(_data)) {
    v = v * _base + d;
  }
  // 31^9 is about 2^44.6: a value beyond the 44 bits a code holds was never made by a board
  if (v >= _codeSpace) return const DeviceCodeRefused(DeviceCodeRefusal.check);
  final profileNo = (v ~/ _proofSpace) % 4;
  if (profileNo >= BoardProfile.values.length) return const DeviceCodeRefused(DeviceCodeRefusal.profile);
  return DeviceCodeOk(DeviceCode(
    shortId: (v ~/ (_proofSpace * 4)).toRadixString(16).toUpperCase().padLeft(8, '0'),
    profile: BoardProfile.values[profileNo],
    proof: v % _proofSpace,
  ));
}

/// The position-weighted sum of the data symbols, mod 31 (the board's `check_of`, readable_code.c).
int _check(List<int> digits) {
  var sum = 0;
  for (var i = 0; i < digits.length; i++) {
    sum += (i + 1) * digits[i];
  }
  return sum % _base;
}
