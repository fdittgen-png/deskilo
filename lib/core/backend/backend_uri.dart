// SPDX-License-Identifier: 0BSD
import 'backend_settings.dart';

/// #780 — `deskilo://server?url=…&key=…`, the one-scan way to hand a
/// community's own Supabase instance to its members.
///
/// Same shape as the join invite (`deskilo://join`, InviteUriCodec): an
/// owner shows the QR from Settings → Server, a member scans it, and
/// nobody types a 40-character key on a phone keyboard.
abstract final class BackendUriCodec {
  static const String _scheme = 'deskilo';
  static const String _host = 'server';

  static String encode(BackendEndpoint endpoint) => Uri(
        scheme: _scheme,
        host: _host,
        queryParameters: {'url': endpoint.url, 'key': endpoint.key},
      ).toString();

  /// The endpoint carried by [payload], or null when the QR is anything
  /// else — a stray code must never silently repoint the app.
  static BackendEndpoint? decode(String payload) {
    final uri = Uri.tryParse(payload.trim());
    if (uri == null || uri.scheme != _scheme || uri.host != _host) return null;
    final url = uri.queryParameters['url']?.trim() ?? '';
    final key = uri.queryParameters['key']?.trim() ?? '';
    if (validateBackendEndpoint(url, key) != null) return null;
    return BackendEndpoint(url, key);
  }
}
