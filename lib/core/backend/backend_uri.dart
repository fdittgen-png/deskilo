// SPDX-License-Identifier: AGPL-3.0-or-later
import 'backend_settings.dart';

/// #1651 — what a scanned or pasted server code carries: the endpoint,
/// and a label whoever shared it chose. The label is a hint for the
/// person, never evidence about the host: it is shown as "named … by
/// whoever shared it" beside the exact host, and nothing keys on it.
class BackendDescriptor {
  const BackendDescriptor(this.endpoint, {this.label});
  final BackendEndpoint endpoint;
  final String? label;
}

/// #780 — `deskilo://server?url=…&key=…`, the one-scan way to hand a
/// community's own Supabase instance to its members.
///
/// Same shape as the join invite (`deskilo://join`, InviteUriCodec): an
/// owner shows the QR from Settings → Server, a member scans it, and
/// nobody types a 40-character key on a phone keyboard.
abstract final class BackendUriCodec {
  static const String _scheme = 'deskilo';
  static const String _host = 'server';

  /// Longer than any legitimate code: a URL, a key and a short label.
  static const int maxPayloadLength = 2048;

  /// The label may not be longer than a line; it is display only.
  static const int maxLabelLength = 80;

  static String encode(BackendEndpoint endpoint, {String? label}) => Uri(
        scheme: _scheme,
        host: _host,
        queryParameters: {
          'url': endpoint.url,
          'key': endpoint.key,
          if (label != null && label.trim().isNotEmpty)
            'name': label.trim().substring(
                0, label.trim().length.clamp(0, maxLabelLength)),
        },
      ).toString();

  /// The endpoint carried by [payload], or null when the QR is anything
  /// else — a stray code must never silently repoint the app.
  static BackendEndpoint? decode(String payload) =>
      decodeDescriptor(payload)?.endpoint;

  /// #1651 — the whole descriptor, refused as one when any part is not
  /// what a server code may carry: an oversized payload, a non-canonical
  /// URL, a key that is not a public client key.
  static BackendDescriptor? decodeDescriptor(String payload) {
    final trimmed = payload.trim();
    if (trimmed.isEmpty || trimmed.length > maxPayloadLength) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.scheme != _scheme || uri.host != _host) return null;
    final url = uri.queryParameters['url']?.trim() ?? '';
    final key = uri.queryParameters['key']?.trim() ?? '';
    if (validateBackendEndpoint(url, key) != null) return null;
    final canonical = canonicalBackendUrl(url);
    if (canonical == null) return null;
    final name = uri.queryParameters['name']?.trim();
    return BackendDescriptor(
      BackendEndpoint(canonical, key),
      label: name == null || name.isEmpty
          ? null
          : name.substring(0, name.length.clamp(0, maxLabelLength)),
    );
  }
}
