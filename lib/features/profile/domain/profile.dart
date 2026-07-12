// SPDX-License-Identifier: MIT

/// A `profiles` row (0001, extended by 0028 with WhatsApp + presence,
/// #223). Cross-workspace: one profile per auth user, visible to every
/// member sharing a workspace (profiles_select RLS).
class Profile {
  const Profile({
    required this.id,
    this.displayName = '',
    this.whatsapp = '',
    this.lastSeenAt,
  });

  /// auth.users id (uuid).
  final String id;

  final String displayName;

  /// Opt-in WhatsApp number in wire shape `+<digits>`; '' = not shared
  /// (mirrors the display_name not-null-empty convention).
  final String whatsapp;

  /// Last foreground heartbeat (UTC); null until the first beat.
  final DateTime? lastSeenAt;

  bool get sharesWhatsapp => whatsapp.isNotEmpty;

  /// Chat deep link for the member directory (#224), or null when the
  /// member does not share a number. wa.me wants the E.164 digits
  /// without the leading `+`.
  Uri? get whatsappUri =>
      sharesWhatsapp ? Uri.https('wa.me', '/${whatsapp.substring(1)}') : null;

  factory Profile.fromDb(Map<String, dynamic> db) => Profile(
        id: db['id'] as String,
        displayName: db['display_name'] as String? ?? '',
        whatsapp: db['whatsapp'] as String? ?? '',
        lastSeenAt: db['last_seen_at'] == null
            ? null
            : DateTime.parse(db['last_seen_at'] as String).toUtc(),
      );

  Map<String, dynamic> toDb() => {
        'id': id,
        'display_name': displayName,
        'whatsapp': whatsapp,
        'last_seen_at': lastSeenAt?.toUtc().toIso8601String(),
      };

  Profile copyWith({
    String? displayName,
    String? whatsapp,
    DateTime? lastSeenAt,
  }) =>
      Profile(
        id: id,
        displayName: displayName ?? this.displayName,
        whatsapp: whatsapp ?? this.whatsapp,
        lastSeenAt: lastSeenAt ?? this.lastSeenAt,
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
