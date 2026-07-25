// SPDX-License-Identifier: 0BSD

/// The printable space QR codes (field request): every seat
/// (workstation), desk, office and level carries a QR; scanning it in
/// the app opens that space's permitted actions (reserve / check in).
/// The payload is a self-describing deskilo:// URI — decoded offline,
/// no server lookup:
///
///     deskilo://space?ws=WORKSPACE&kind=seat|desk|office|level&id=UUID
enum SpaceKind { seat, desk, office, level }

/// A decoded space QR payload.
typedef SpaceCode = ({String workspaceId, SpaceKind kind, String id});

abstract final class SpaceCodeCodec {
  static const String scheme = 'deskilo';
  static const String host = 'space';

  static String encode({
    required String workspaceId,
    required SpaceKind kind,
    required String id,
  }) =>
      Uri(
        scheme: scheme,
        host: host,
        queryParameters: {'ws': workspaceId, 'kind': kind.name, 'id': id},
      ).toString();

  /// Decodes a scanned/typed payload; null for anything that is not a
  /// well-formed space code (foreign QR contents must never crash the
  /// scanner).
  static SpaceCode? decode(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme != scheme || uri.host != host) {
      return null;
    }
    final ws = uri.queryParameters['ws'];
    final id = uri.queryParameters['id'];
    final kind = SpaceKind.values
        .where((k) => k.name == uri.queryParameters['kind'])
        .firstOrNull;
    if (ws == null || ws.isEmpty || kind == null || id == null || id.isEmpty) {
      return null;
    }
    return (workspaceId: ws, kind: kind, id: id);
  }
}
