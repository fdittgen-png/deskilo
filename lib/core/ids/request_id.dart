// SPDX-License-Identifier: 0BSD
import 'dart:math';

/// A fresh idempotency key, as a RFC 4122 version-4 UUID string.
///
/// Hand-rolled rather than pulling in `uuid`: it is a transitive
/// dependency of the Supabase client, and importing one of those is how
/// a package upgrade three levels away becomes a compile error here.
/// Sixteen secure-random bytes with the version and variant nibbles
/// stamped is the whole specification.
String newRequestId() {
  final bytes = List<int>.generate(16, (_) => _secure.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1
  String hex(int from, int to) => [
        for (var i = from; i < to; i++)
          bytes[i].toRadixString(16).padLeft(2, '0'),
      ].join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

final _secure = Random.secure();
