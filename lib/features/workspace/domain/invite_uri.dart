// SPDX-License-Identifier: MIT

/// Role an invite grants on join. There is deliberately no `owner` value:
/// ownership is never invitable — only an owner can grant it, by editing
/// the member row (members_update_owner RLS).
enum InviteRole { user, admin }

/// Builds and parses the `deskilo://join?role=…&code=…` URLs embedded in
/// invite QR codes. The role in the URL is what the code will grant —
/// the server derives the actual role from which secret code matched
/// (0030), so tampering with the role parameter changes nothing.
abstract final class InviteUriCodec {
  static const String _scheme = 'deskilo';
  static const String _host = 'join';

  static String encode({required String code, required InviteRole role}) =>
      '$_scheme://$_host?role=${role.name}&code=$code';

  /// The invite code carried by [payload]: the `code` parameter of an
  /// invite URL, or — legacy printed QRs (#88) predate the URL form —
  /// the raw payload itself. Other URLs yield '' so a random scanned
  /// QR never reaches join_workspace as a phantom code.
  static String decodeCode(String payload) {
    final uri = Uri.tryParse(payload.trim());
    if (uri != null && uri.scheme.isNotEmpty) {
      if (uri.scheme == _scheme && uri.host == _host) {
        return uri.queryParameters['code']?.trim().toUpperCase() ?? '';
      }
      return '';
    }
    return payload.trim().toUpperCase();
  }
}
