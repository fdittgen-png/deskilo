// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Which backend this process actually talks to.
///
/// `ActiveBackend` is the *stored* choice and changes the moment Settings
/// writes it, but `Supabase.initialize` runs once per start — so a device
/// that has just switched instances still speaks to the old one until the
/// restart. The cache must be named after the server the rows came FROM,
/// which is this one and not the stored one.
///
/// `initializeApp` sets it. Tests leave it at the compiled default.
String bootBackendUrl = '';

/// The prefix every cache key carries: the backend plus the principal.
///
/// Without it, one device's cache is one namespace shared by everyone who
/// ever signs in on it (#1124). The files survive `signOut`, so the next
/// user's first read of `levels:<workspace>` is served the previous
/// user's rows — including rows RLS would have refused them.
///
/// Signed out there is no scope and no cache: `anon:` entries would be
/// written by a session that has no business persisting rows at all.
/// [cacheScope] returns null then, and the store treats null as "do not
/// read, do not write".
String? cacheScope({required String? backendUrl, required String? userId}) {
  if (userId == null || userId.isEmpty) return null;
  final backend = (backendUrl == null || backendUrl.isEmpty) ? '?' : backendUrl;
  // Hashed, not spelled out: a cache file name is visible in a file
  // manager and on a backup, and neither the instance host nor the user
  // id needs to be legible there for the cache to work.
  //
  // #2008 — SHA-256 over a versioned, length-prefixed encoding of the
  // exact pair, truncated to 128 bits. Two 32-bit FNV hashes plus the id
  // length were constructible to collide (two UUID-shaped ids shared one
  // namespace); the store also checks the exact key it was given.
  return 's2${cacheDigest('cache-scope-v2', [backend, userId], 32)}:';
}

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
