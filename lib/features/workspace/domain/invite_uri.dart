// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/backend/backend_settings.dart';
import '../../../core/backend/backend_uri.dart';

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

  /// #1652 — the invitation version that names its server. A v1 link
  /// (no `v`) and a raw code are resolved on the server this device
  /// chose; a v2 link carries the installation it was issued on.
  static const int currentVersion = 2;

  /// Longer than any legitimate invitation message; a paste beyond it is
  /// refused whole rather than searched.
  static const int maxInputLength = 8192;

  /// The v1 URL, or — with [target] — the v2 one that also carries the
  /// installation's public endpoint (#1652), so the invitation is only
  /// ever checked on the server that issued it.
  static String encode({
    required String code,
    required InviteRole role,
    BackendEndpoint? target,
    String? targetLabel,
  }) {
    if (target == null) return '$_scheme://$_host?role=${role.name}&code=$code';
    final label = targetLabel?.trim() ?? '';
    return Uri(scheme: _scheme, host: _host, queryParameters: {
      'v': '$currentVersion',
      'role': role.name,
      'code': code,
      'url': target.url,
      'key': target.key,
      if (label.isNotEmpty)
        'name': label.substring(0, label.length.clamp(0, BackendUriCodec.maxLabelLength)),
    }).toString();
  }

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
  static final _anyJoinUrl = RegExp('$_scheme://$_host/?\\?[^)\\]>\u00ab\u00bb"\'\\s]+');

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

/// Why an invitation could not be read.
enum InvitationProblem {
  /// Nothing code-like in the text.
  noCode,

  /// A link from a newer app: refused, never guessed at.
  unsupportedVersion,

  /// A v2 link whose server is not a server code this app accepts.
  badTarget,
}

/// #1652 — what one pasted, scanned or opened invitation says. The code
/// is the secret; [target] is where it may be checked. Nothing here is
/// trusted: the role in the link and any label are hints, and the server
/// derives both the workspace and the role from the code alone.
final class InvitationDescriptor {
  const InvitationDescriptor({required this.code, this.target, this.version = 1})
      : problem = null;
  const InvitationDescriptor.refused(InvitationProblem this.problem)
      : code = '',
        target = null,
        version = 0;

  final String code;
  final BackendDescriptor? target;
  final int version;
  final InvitationProblem? problem;

  bool get usable => problem == null && code.isNotEmpty;

  /// Whether this invitation may be checked on [active]: a legacy code
  /// on the server the person chose, a v2 link only on its own.
  bool belongsTo(BackendEndpoint? active) {
    final target = this.target;
    if (target == null) return true;
    if (active == null) return false;
    return canonicalBackendUrl(target.endpoint.url) == canonicalBackendUrl(active.url);
  }
}

/// Reads an invitation from a bare code, a link, or a whole pasted
/// message (#1652). Cleans up whitespace and line wrapping only; it never
/// fetches or follows anything.
abstract final class InvitationReader {
  static InvitationDescriptor read(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.length > InviteUriCodec.maxInputLength) {
      return const InvitationDescriptor.refused(InvitationProblem.noCode);
    }
    InvitationDescriptor? refusal;
    // 1. A link intact on one line.
    for (final match in InviteUriCodec._anyJoinUrl.allMatches(trimmed)) {
      final read = _fromUrl(match.group(0)!);
      if (read.usable) return read;
      if (read.problem != InvitationProblem.noCode) refusal ??= read;
    }
    // 2. A link wrapped across lines by a messenger.
    if (trimmed.contains(RegExp(r'\s'))) {
      final compact = trimmed.replaceAll(RegExp(r'\s+'), '');
      final match = InviteUriCodec._joinUrl.firstMatch(compact);
      if (match != null) {
        final read = _fromUrl(match.group(0)!);
        if (read.usable) return read;
      }
    }
    if (refusal != null) return refusal;
    // 3. A bare code, or the code alone on its line.
    final code = InviteUriCodec.extractCode(trimmed);
    return _codeShaped(code)
        ? InvitationDescriptor(code: code)
        : const InvitationDescriptor.refused(InvitationProblem.noCode);
  }

  static bool _codeShaped(String code) =>
      code.isNotEmpty && code.length <= 64 && !code.contains(RegExp(r'\s'));

  static InvitationDescriptor _fromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != InviteUriCodec._scheme ||
        uri.host != InviteUriCodec._host) {
      return const InvitationDescriptor.refused(InvitationProblem.noCode);
    }
    final Map<String, String> query;
    try {
      query = uri.queryParameters;
    } on FormatException {
      return const InvitationDescriptor.refused(InvitationProblem.noCode);
    }
    final code = (query['code'] ?? '').trim().toUpperCase();
    final version = query['v'];
    if (version != null && version != '1' && version != '${InviteUriCodec.currentVersion}') {
      return const InvitationDescriptor.refused(InvitationProblem.unsupportedVersion);
    }
    if (!_codeShaped(code)) {
      return const InvitationDescriptor.refused(InvitationProblem.noCode);
    }
    if (version == null || version == '1') return InvitationDescriptor(code: code);
    final target = BackendUriCodec.decodeDescriptor(Uri(
      scheme: InviteUriCodec._scheme,
      host: 'server',
      queryParameters: {
        'url': query['url'] ?? '',
        'key': query['key'] ?? '',
        if ((query['name'] ?? '').trim().isNotEmpty) 'name': query['name']!,
      },
    ).toString());
    if (target == null) {
      return const InvitationDescriptor.refused(InvitationProblem.badTarget);
    }
    return InvitationDescriptor(code: code, target: target, version: 2);
  }
}
