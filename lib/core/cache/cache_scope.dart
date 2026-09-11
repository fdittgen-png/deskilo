// SPDX-License-Identifier: 0BSD

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
  // id needs to be legible there for the cache to work. Two different
  // pairs must not collide, which is what the two independent hashes and
  // the length prefix are for.
  return '${_hash(backend)}${_hash(userId)}${userId.length}:';
}

/// FNV-1a, 32 bits, written out rather than taken from `hashCode`.
/// `String.hashCode` is not contractually stable across releases of the
/// SDK, and a cache whose namespace silently changes on an SDK bump
/// invalidates every device at once.
String _hash(String value) {
  var h = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    h = (h ^ unit) & 0xffffffff;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h.toRadixString(16).padLeft(8, '0');
}
