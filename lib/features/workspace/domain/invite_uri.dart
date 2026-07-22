// SPDX-License-Identifier: 0BSD

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

  /// A deskilo://join URL anywhere in free text. WhatsApp copies the
  /// WHOLE invitation message, and line-wrapping may inject whitespace
  /// into the URL — the text is compacted before matching.
  static final _joinUrl = RegExp('$_scheme://[^)\\]>\u00ab\u00bb"\']+');

  /// The invite code found in [text], which may be a bare code, an
  /// invite URL, or an ENTIRE pasted invitation message (0049 — the
  /// join field accepts a wholesale WhatsApp/SMS paste). '' when
  /// nothing code-like is found.
  static String extractCode(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    // A single token (no whitespace) is a bare code or a lone URL —
    // the historical decode path.
    if (!trimmed.contains(RegExp(r'\s'))) return decodeCode(trimmed);
    // Free text: find the join URL (tolerating wrap breaks inside it),
    // and read its code parameter.
    final compact = trimmed.replaceAll(RegExp(r'\s+'), '');
    final match = _joinUrl.firstMatch(compact);
    if (match != null) {
      final code = decodeCode(match.group(0)!);
      if (code.isNotEmpty) return code;
    }
    // No URL: accept a line holding exactly one code-shaped token (the
    // invitation template puts the ID alone on its line). Digits are
    // required so prose words never masquerade as codes. WhatsApp's
    // monospace markers (```CODE```, #318) survive a copy as literal
    // backticks — strip them before matching.
    for (final line in trimmed.split('\n')) {
      final token = line.trim().replaceAll(RegExp(r'^`+|`+$'), '').trim();
      if (RegExp(r'^[A-Za-z0-9]{4,20}$').hasMatch(token) &&
          RegExp(r'[0-9]').hasMatch(token)) {
        return token.toUpperCase();
      }
    }
    return '';
  }
}
