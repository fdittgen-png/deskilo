// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — who sees what of me, and who may start a conversation.
//
// Every field of my account picks an audience; reachability ("who can
// write to me") is chosen separately, with the same four answers. The
// server (my_visibility / set_visibility, #1822) owns the rule and the
// defaults; this is its vocabulary, pure Dart, with the defaults the
// server applies to an account that never chose.

/// A part of my account someone else might see.
enum VisibilityField {
  /// Name and photo.
  identity('identity', VisibilityAudience.mySpaces),

  /// Profession and bio.
  about('about', VisibilityAudience.nobody),

  /// WhatsApp and e-mail.
  contactChannels('contact_channels', VisibilityAudience.nobody),

  /// "In the space today".
  presence('presence', VisibilityAudience.nobody),

  /// Who can start a conversation with me.
  reachability('reachability', VisibilityAudience.mySpaces);

  const VisibilityField(this.wire, this.defaultAudience);

  final String wire;

  /// What the server answers for an account that never chose.
  final VisibilityAudience defaultAudience;

  /// The four fields "how others see me" shows; reachability is asked
  /// separately.
  static const List<VisibilityField> seen = [
    identity,
    about,
    contactChannels,
    presence,
  ];

  static VisibilityField? fromWire(String? wire) =>
      values.where((f) => f.wire == wire).firstOrNull;
}

/// Who may see a field.
enum VisibilityAudience {
  nobody('nobody'),
  mySpaces('my_spaces'),
  chosenSpaces('chosen_spaces'),
  signedIn('signed_in');

  const VisibilityAudience(this.wire);

  final String wire;

  static VisibilityAudience? fromWire(Object? wire) =>
      values.where((a) => a.wire == wire).firstOrNull;
}

/// The audiences "how others see me" can preview (`preview_my_account`).
enum PreviewAudience {
  mySpaces('my_spaces'),
  signedIn('signed_in'),
  nobody('nobody');

  const PreviewAudience(this.wire);

  final String wire;
}

/// One field's choice.
class FieldAudience {
  const FieldAudience(this.audience, [this.workspaces = const []]);

  final VisibilityAudience audience;

  /// The chosen spaces, meaningful only for [VisibilityAudience.chosenSpaces].
  final List<String> workspaces;

  /// A choice the server would refuse: chosen spaces, and none chosen.
  bool get incomplete =>
      audience == VisibilityAudience.chosenSpaces && workspaces.isEmpty;

  factory FieldAudience.fromJson(Object? raw, VisibilityField field) {
    if (raw is! Map) return FieldAudience(field.defaultAudience);
    return FieldAudience(
      VisibilityAudience.fromWire(raw['audience']) ?? field.defaultAudience,
      [
        for (final id in (raw['workspaces'] as List<dynamic>? ?? const []))
          if (id is String) id,
      ],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FieldAudience &&
      other.audience == audience &&
      other.workspaces.length == workspaces.length &&
      other.workspaces.every(workspaces.contains);

  @override
  int get hashCode => Object.hash(audience, workspaces.length);
}

/// `my_visibility()`: every field, reachability included, with the
/// server's defaults filled in for anything it did not name.
class MyVisibility {
  const MyVisibility(this.fields);

  final Map<VisibilityField, FieldAudience> fields;

  FieldAudience of(VisibilityField field) =>
      fields[field] ?? FieldAudience(field.defaultAudience);

  static const MyVisibility defaults = MyVisibility({});

  factory MyVisibility.fromJson(Map<String, dynamic> json) {
    final raw = json['fields'] is Map ? json['fields'] as Map : const <String, dynamic>{};
    return MyVisibility({
      for (final field in VisibilityField.values)
        field: FieldAudience.fromJson(
          field == VisibilityField.reachability
              ? (json['reachability'] ?? raw['reachability'])
              : raw[field.wire],
          field,
        ),
    });
  }

  MyVisibility withField(VisibilityField field, FieldAudience audience) =>
      MyVisibility({...fields, field: audience});
}

/// What one account shows another: `visible_account(user)` and
/// `preview_my_account(as)`. Every field is null when it is hidden.
class AccountView {
  const AccountView({
    this.name,
    this.hasPhoto = false,
    this.profession,
    this.bio,
    this.whatsapp,
    this.email,
    this.presence,
    this.canMessage = false,
  });

  final String? name;
  final bool hasPhoto;
  final String? profession;
  final String? bio;
  final String? whatsapp;
  final String? email;
  final String? presence;
  final bool canMessage;

  /// Nothing at all is shown.
  bool get isEmpty =>
      name == null &&
      !hasPhoto &&
      profession == null &&
      bio == null &&
      whatsapp == null &&
      email == null &&
      presence == null;

  factory AccountView.fromJson(Map<String, dynamic> json) {
    String? text(String key) {
      final value = json[key];
      return value is String && value.trim().isNotEmpty ? value : null;
    }

    final photo = json['has_avatar'] ?? json['has_photo'];
    return AccountView(
      name: text('name') ?? text('display_name'),
      hasPhoto: photo == true || text('avatar_path') != null,
      profession: text('profession'),
      bio: text('bio'),
      whatsapp: text('whatsapp'),
      email: text('email'),
      presence: text('presence'),
      canMessage: json['can_message'] == true,
    );
  }
}
