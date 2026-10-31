// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2488 (S5 of #2483) -- the shape a public third-party endpoint must have
// before the app sends a request to it: the map's tile server and the
// directory's geocoder, which an operator may now point elsewhere from the
// platform settings. A `startsWith('https')` is not a check: the address is
// parsed, and everything that would turn a public lookup into something
// else is refused -- a plain-text scheme, credentials in the address, a
// fragment, a loopback/private/link-local host (the device's own network),
// and, for the geocoder, a query the app would silently overwrite.
//
// Loopback hosts are accepted only when the build says so
// (`--dart-define=DESKILO_LOCAL_ENDPOINTS=true`, the local test stack):
// public input never reaches localhost by default.

/// Which kind of endpoint a value is checked as.
enum PublicEndpointKind {
  /// A base URL the app adds `?q=…&limit=1` to.
  geocoder,

  /// A tile URL template: `{z}`, `{x}` and `{y}` are filled in per tile;
  /// a `{s}` subdomain placeholder may stand at the host's start.
  tileTemplate,
}

/// Why a value is not an acceptable public endpoint.
enum PublicEndpointProblem {
  notAUrl,
  notHttps,
  hasCredentials,
  hasFragment,
  privateHost,
  hasQuery,
  missingTilePlaceholders,
}

/// Whether the build allows endpoints on the device's own host.
const bool localEndpointsAllowed =
    bool.fromEnvironment('DESKILO_LOCAL_ENDPOINTS');

/// Why [value] is not a usable [kind] endpoint, or null when it is.
///
/// [allowLocal] defaults to the build's policy; tests pass it explicitly.
PublicEndpointProblem? publicEndpointProblem(
  String value,
  PublicEndpointKind kind, {
  bool allowLocal = localEndpointsAllowed,
}) {
  final text = value.trim();
  if (text.isEmpty || text != value) return PublicEndpointProblem.notAUrl;
  if (kind == PublicEndpointKind.tileTemplate &&
      !(text.contains('{z}') && text.contains('{x}') && text.contains('{y}'))) {
    return PublicEndpointProblem.missingTilePlaceholders;
  }
  // Placeholders are not URL syntax: replace them with a neutral token
  // before parsing so the structure, not the template, is checked.
  final probe = text.replaceAllMapped(RegExp(r'\{[a-z]+\}'), (_) => 'p');
  final Uri uri;
  try {
    uri = Uri.parse(probe);
  } on FormatException {
    return PublicEndpointProblem.notAUrl;
  }
  if (!uri.hasScheme || uri.host.isEmpty) return PublicEndpointProblem.notAUrl;
  final local = _isLoopback(uri.host);
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'https' && !(scheme == 'http' && local && allowLocal)) {
    return PublicEndpointProblem.notHttps;
  }
  if (uri.userInfo.isNotEmpty) return PublicEndpointProblem.hasCredentials;
  if (uri.hasFragment || text.contains('#')) {
    return PublicEndpointProblem.hasFragment;
  }
  if (local ? !allowLocal : _isPrivate(uri.host)) {
    return PublicEndpointProblem.privateHost;
  }
  if (kind == PublicEndpointKind.geocoder && uri.hasQuery) {
    return PublicEndpointProblem.hasQuery;
  }
  return null;
}

bool _isLoopback(String host) {
  final h = host.toLowerCase();
  if (h == 'localhost' || h.endsWith('.localhost')) return true;
  final v4 = _ipv4(h);
  if (v4 != null) return v4[0] == 127;
  return h == '::1' || h == '[::1]';
}

/// A host the public internet does not route to: RFC 1918, link-local,
/// carrier-grade NAT, "this network", unique-local and link-local IPv6, and
/// names that only resolve on a local network.
bool _isPrivate(String host) {
  final h = host.toLowerCase();
  if (const ['.local', '.internal', '.lan'].any(h.endsWith)) return true;
  final v4 = _ipv4(h);
  if (v4 != null) return _privateV4(v4[0], v4[1]);
  final v6 = h.replaceAll('[', '').replaceAll(']', '');
  return v6.contains(':') && _privateV6(v6);
}

bool _privateV4(int a, int b) =>
    const [0, 10, 127].contains(a) ||
    a >= 224 ||
    (a == 100 && b >= 64 && b <= 127) ||
    (a == 169 && b == 254) ||
    (a == 172 && b >= 16 && b <= 31) ||
    (a == 192 && b == 168);

bool _privateV6(String v6) =>
    v6 == '::' ||
    v6 == '::1' ||
    const ['fc', 'fd', 'fe8', 'fe9', 'fea', 'feb', '::ffff:'].any(v6.startsWith);

List<int>? _ipv4(String host) {
  final parts = host.split('.');
  if (parts.length != 4) return null;
  final out = <int>[];
  for (final p in parts) {
    final n = int.tryParse(p);
    if (n == null || n < 0 || n > 255) return null;
    out.add(n);
  }
  return out;
}
