// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3401 -- the one stable, domain-separated digest the application's caches and
// data revisions name themselves with (moved out of core/cache with the tax
// reference, whose set computes its own revision).
import 'dart:convert';

import 'package:crypto/crypto.dart';

/// #2008 — a stable, domain-separated SHA-256 digest of [parts], as the
/// first [hexChars] hex characters. Each part is length-prefixed so no
/// two different lists encode alike. Not encryption, not a permission.
String cacheDigest(String domain, List<String> parts, int hexChars) {
  final encoded = StringBuffer(domain);
  for (final part in parts) {
    encoded
      ..write('\n')
      ..write(utf8.encode(part).length)
      ..write(':')
      ..write(part);
  }
  return sha256
      .convert(utf8.encode(encoded.toString()))
      .toString()
      .substring(0, hexChars);
}
