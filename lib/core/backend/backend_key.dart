// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1651 — what kind of credential a pasted "key" actually is.
//
// The Server screen used to accept any `eyJ…` three-part shape as the
// legacy anon key, so a service-role JWT, a user's access token or an
// OIDC id token pasted by mistake were "valid", got sent to the
// candidate host, stored on the device and encoded into a QR for the
// whole community. Classification is pure Dart: it reads the shape and
// the declared claims, sends nothing, and PROVES nothing — a claim of
// `role: anon` is a reason not to reject, never evidence that the host
// is who it says it is.

import 'dart:convert';

/// The shape a pasted credential has. Only [publishable] and
/// [legacyAnon] may be sent, stored or shared.
enum BackendKeyKind {
  /// `sb_publishable_…` — the current public client key.
  publishable,

  /// The legacy anon JWT: `role: anon`, no subject.
  legacyAnon,

  /// `sb_secret_…` or a JWT declaring `role: service_role`: bypasses RLS.
  secret,

  /// `sbp_…` — a Supabase personal access token (the Management API).
  personalAccessToken,

  /// A user's access, refresh-bearing or OIDC id token: it names a person.
  userToken,

  /// `postgres://…` — a database connection string.
  connectionString,

  /// Nothing recognisable, or a JWT whose claims cannot be read.
  malformed,
}

/// Longer than any legitimate key; anything above is refused unread.
const int backendKeyMaxLength = 4096;

/// Classifies [raw] by shape and declared claims. Never throws.
BackendKeyKind classifyBackendKey(String raw) {
  final k = raw.trim();
  if (k.isEmpty || k.length > backendKeyMaxLength) {
    return BackendKeyKind.malformed;
  }
  if (RegExp(r'\s').hasMatch(k)) return BackendKeyKind.malformed;
  final lower = k.toLowerCase();
  if (lower.startsWith('postgres://') || lower.startsWith('postgresql://')) {
    return BackendKeyKind.connectionString;
  }
  if (k.startsWith('sb_publishable_')) {
    return k.length > 20
        ? BackendKeyKind.publishable
        : BackendKeyKind.malformed;
  }
  if (k.startsWith('sb_secret_')) return BackendKeyKind.secret;
  if (k.startsWith('sbp_')) return BackendKeyKind.personalAccessToken;
  if (k.startsWith('eyJ')) return _classifyJwt(k);
  return BackendKeyKind.malformed;
}

BackendKeyKind _classifyJwt(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return BackendKeyKind.malformed;
  final claims = jwtClaims(parts[1]);
  if (claims == null) return BackendKeyKind.malformed;
  final role = claims['role'];
  if (role == 'service_role') return BackendKeyKind.secret;
  if (claims.containsKey('sub') || role == 'authenticated') {
    return BackendKeyKind.userToken;
  }
  if (role == 'anon') return BackendKeyKind.legacyAnon;
  return BackendKeyKind.malformed;
}

/// The claims of a JWT payload segment, or null when it is not a JSON
/// object in base64url. Signature and expiry are NOT checked here — this
/// is a classifier, not a verifier.
Map<String, Object?>? jwtClaims(String segment) {
  try {
    var s = segment.replaceAll('-', '+').replaceAll('_', '/');
    while (s.length % 4 != 0) {
      s += '=';
    }
    final decoded = jsonDecode(utf8.decode(base64.decode(s)));
    return decoded is Map<String, Object?> ? decoded : null;
  } on FormatException {
    return null;
  }
}

/// A public client key that may be sent, stored and shared.
bool isPublicBackendKey(BackendKeyKind kind) =>
    kind == BackendKeyKind.publishable || kind == BackendKeyKind.legacyAnon;
