// SPDX-License-Identifier: MIT

/// Rules for the self-set status line (#231). The cap is enforced three
/// times with this single constant: the editor's `maxLength`, the
/// [normalizeStatusText] hard cap, and the 0029 column check
/// (`char_length(status_text) <= 40`) — cross-pinned by test.
abstract final class StatusTextRules {
  static const int maxLength = 40;
}

/// A `profiles` row (0001, extended by 0028 with WhatsApp + presence,
/// #223, and by 0029 with the status line, #231). Cross-workspace: one
/// profile per auth user, visible to every member sharing a workspace
/// (profiles_select RLS).
class Profile {
  const Profile({
    required this.id,
    this.displayName = '',
    this.whatsapp = '',
    this.statusText = '',
    this.lastSeenAt,
    this.avatarPath,
  });

  /// auth.users id (uuid).
  final String id;

  final String displayName;

  /// Opt-in WhatsApp number in wire shape `+<digits>`; '' = not shared
  /// (mirrors the display_name not-null-empty convention).
  final String whatsapp;

  /// Self-set status line shown in the member directory (#231/#232),
  /// e.g. "In a call · back at 14:00"; '' = no status. At most
  /// [StatusTextRules.maxLength] characters (0029 column check).
  final String statusText;

  /// Last foreground heartbeat (UTC); null until the first beat.
  final DateTime? lastSeenAt;

  /// Storage path of the member's photo in the private `avatars` bucket
  /// (`<user_id>/avatar`, 0038); null = no photo, the initial avatar shows.
  final String? avatarPath;

  bool get hasAvatar => avatarPath != null && avatarPath!.isNotEmpty;

  bool get sharesWhatsapp => whatsapp.isNotEmpty;

  /// Chat deep link for the member directory (#224), or null when the
  /// member does not share a number. wa.me wants the E.164 digits
  /// without the leading `+`.
  Uri? get whatsappUri =>
      sharesWhatsapp ? Uri.https('wa.me', '/${whatsapp.substring(1)}') : null;

  bool get hasStatus => statusText.isNotEmpty;

  factory Profile.fromDb(Map<String, dynamic> db) => Profile(
        id: db['id'] as String,
        displayName: db['display_name'] as String? ?? '',
        whatsapp: db['whatsapp'] as String? ?? '',
        statusText: db['status_text'] as String? ?? '',
        lastSeenAt: db['last_seen_at'] == null
            ? null
            : DateTime.parse(db['last_seen_at'] as String).toUtc(),
        avatarPath: db['avatar_path'] as String?,
      );

  Map<String, dynamic> toDb() => {
        'id': id,
        'display_name': displayName,
        'whatsapp': whatsapp,
        'status_text': statusText,
        'last_seen_at': lastSeenAt?.toUtc().toIso8601String(),
        'avatar_path': avatarPath,
      };

  Profile copyWith({
    String? displayName,
    String? whatsapp,
    String? statusText,
    DateTime? lastSeenAt,
    String? avatarPath,
  }) =>
      Profile(
        id: id,
        displayName: displayName ?? this.displayName,
        whatsapp: whatsapp ?? this.whatsapp,
        statusText: statusText ?? this.statusText,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
        avatarPath: avatarPath ?? this.avatarPath,
      );
}

/// Normalizes user input to the stored wire shape (#223): keep digits
/// only, fold the `00` international dialing prefix into `+`, prepend
/// `+`. Blank/digit-less input normalizes to '' — which clears the
/// number. `"+33 6 12-34.56.78"` → `"+33612345678"`.
String normalizeWhatsapp(String input) {
  var digits = input.replaceAll(RegExp('[^0-9]'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);
  return digits.isEmpty ? '' : '+$digits';
}

/// Normalizes status-line input to the stored shape (#231): trim, then
/// hard-cap at [StatusTextRules.maxLength]. Blank input normalizes to
/// '' — which clears the status. The cap counts Unicode code points
/// (runes), matching Postgres `char_length` in the 0029 check exactly —
/// the editor's grapheme-based `maxLength` alone would let a 40-emoji
/// status exceed 40 code points and bounce off the column check.
String normalizeStatusText(String input) {
  final trimmed = input.trim();
  if (trimmed.runes.length <= StatusTextRules.maxLength) return trimmed;
  return String.fromCharCodes(
    trimmed.runes.take(StatusTextRules.maxLength),
  ).trim();
}
