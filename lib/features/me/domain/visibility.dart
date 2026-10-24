// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — who sees what of me, and who may start a conversation.
//
// Every field of my account picks an audience; reachability ("who can
// write to me") is chosen separately, with the same four answers. The
// server (my_visibility / set_visibility, #1822) owns the rule and the
// defaults; this is its vocabulary, pure Dart, with the defaults the
// server applies to an account that never chose.

import '../../../core/data/json_reader.dart';

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

  /// #2211 — the audiences this field may have. Contact channels and
  /// presence never go wider than the spaces I am in: a signed-in
  /// stranger — and so anyone known only through another workspace or a
  /// connected installation — never sees them (0392 refuses it too).
  List<VisibilityAudience> get allowedAudiences => switch (this) {
    contactChannels || presence => const [
      VisibilityAudience.nobody,
      VisibilityAudience.mySpaces,
      VisibilityAudience.chosenSpaces,
    ],
    _ => VisibilityAudience.values,
  };
}

/// Who may see a field.
enum VisibilityAudience {
  nobody('nobody'),
  mySpaces('my_spaces'),
  chosenSpaces('chosen_spaces'),
  signedIn('signed_in');

  const VisibilityAudience(this.wire);

  final String wire;

  /// How wide the audience is, narrow to wide: only me < chosen spaces < my
  /// spaces < anyone signed in.
  int get breadth => switch (this) {
    nobody => 0,
    chosenSpaces => 1,
    mySpaces => 2,
    signedIn => 3,
  };

  static VisibilityAudience? fromWire(Object? wire) =>
      values.where((a) => a.wire == wire).firstOrNull;
}

/// The audiences "how others see me" can preview (`preview_my_account`).
enum PreviewAudience {
  mySpaces('my_spaces'),
  signedIn('signed_in'),
  /// Only me: everything, as I alone see it (the server's `nobody`).
  nobody('nobody');

  const PreviewAudience(this.wire);

  final String wire;
}

/// One field's choice.
class FieldAudience {
  const FieldAudience(this.audience, [this.workspaces = const {}]);

  final VisibilityAudience audience;

  /// The chosen spaces, meaningful only for [VisibilityAudience.chosenSpaces].
  final Set<String> workspaces;

  /// Whether this choice shows the field to more people than [before]: a
  /// wider audience, or the same chosen spaces plus more of them.
  bool widens(FieldAudience before) {
    if (audience.breadth != before.audience.breadth) {
      return audience.breadth > before.audience.breadth;
    }
    return audience == VisibilityAudience.chosenSpaces &&
        workspaces.any((id) => !before.workspaces.contains(id));
  }

  /// A choice the server would refuse: chosen spaces, and none chosen.
  bool get incomplete =>
      audience == VisibilityAudience.chosenSpaces && workspaces.isEmpty;

  /// #2558 — the spaces of [after] that [before] did not name, and the
  /// ones it dropped, each sorted: what a widening confirmation lists.
  static ({List<String> added, List<String> removed}) spacesDiff(
    FieldAudience before,
    FieldAudience after,
  ) {
    Set<String> spaces(FieldAudience a) =>
        a.audience == VisibilityAudience.chosenSpaces ? a.workspaces : const {};
    final was = spaces(before);
    final now = spaces(after);
    return (
      added: now.difference(was).toList()..sort(),
      removed: was.difference(now).toList()..sort(),
    );
  }

  factory FieldAudience.fromJson(Object? raw, VisibilityField field) {
    if (raw is! Map) return FieldAudience(field.defaultAudience);
    // Fail-closed (#2387): a malformed field reads as the default.
    final r = JsonReader.of(raw, context: 'field_audience');
    // #2558 — the personal home names the chosen spaces by network
    // reference (`workspace_refs`, my_visibility_network_v1); a legacy or
    // linked server by local id (`workspaces`, my_visibility).
    final spaces = r.json.containsKey('workspace_refs')
        ? r.listOrAbsent('workspace_refs')
        : r.listOrAbsent('workspaces');
    return FieldAudience(
      VisibilityAudience.fromWire(r.json['audience']) ?? field.defaultAudience,
      {
        for (final id in spaces)
          if (id is String) id,
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FieldAudience &&
      other.audience == audience &&
      other.workspaces.length == workspaces.length &&
      other.workspaces.containsAll(workspaces);

  @override
  int get hashCode =>
      Object.hash(audience, Object.hashAllUnordered(workspaces));
}

/// `my_visibility()`: every field, reachability included, with the
/// server's defaults filled in for anything it did not name — and my own
/// profession and bio, which only `set_my_about` writes.
class MyVisibility {
  const MyVisibility(
    this.fields, {
    this.profession = '',
    this.bio = '',
    this.home = '',
  });

  final Map<VisibilityField, FieldAudience> fields;
  final String profession;
  final String bio;

  /// #2558 — the installation id of the personal home that answered
  /// (`home.installation_id` of my_visibility_network_v1); empty from a
  /// reader that names none. Only a chosen space of THIS installation can
  /// be written through today's `set_visibility`.
  final String home;

  /// The local workspace id [ref] names when it is a space of [home]; null
  /// for a space on another installation, an unqualified id, or when no
  /// home answered. A qualified reference is never read as a local id of
  /// another installation.
  String? localIdOf(String ref) {
    final at = ref.indexOf(':');
    if (home.isEmpty || at <= 0 || ref.substring(0, at) != home) return null;
    final local = ref.substring(at + 1);
    return local.isEmpty ? null : local;
  }

  /// Whether [field]'s saved choice names a space this home cannot write
  /// for: such a field is read-only here until the network writer exists.
  bool namesSpaceElsewhere(VisibilityField field) =>
      of(field).workspaces.any((ref) => localIdOf(ref) == null);

  FieldAudience of(VisibilityField field) =>
      fields[field] ?? FieldAudience(field.defaultAudience);

  static const MyVisibility defaults = MyVisibility({});

  factory MyVisibility.fromJson(Map<String, dynamic> json) {
    // Fail-closed (#2387): a malformed field reads as the default.
    final r = JsonReader(json, context: 'my_visibility');
    final fields = r.objectOrAbsent('fields');
    final about = r.objectOrAbsent('about');
    return MyVisibility(
      profession: about.textOrAbsent('profession') ?? '',
      bio: about.textOrAbsent('bio') ?? '',
      home: r.objectOrAbsent('home').textOrAbsent('installation_id') ?? '',
      {
        for (final field in VisibilityField.values)
          field: FieldAudience.fromJson(
            field == VisibilityField.reachability
                ? _reachability(r, fields)
                : fields.json[field.wire],
            field,
          ),
      },
    );
  }

  /// Who may write to me, as the reply carries it. `my_visibility` (0315)
  /// answers it at the top level, beside `fields`, because it is chosen
  /// apart from what others see; a reply that carries it among `fields`
  /// instead is still read, as the fallback.
  static Object? _reachability(JsonReader reply, JsonReader fields) =>
      reply.json['reachability'] ?? fields.json['reachability'];

  MyVisibility withField(VisibilityField field, FieldAudience audience) =>
      MyVisibility({...fields, field: audience},
          profession: profession, bio: bio, home: home);

  MyVisibility withAbout(String profession, String bio) =>
      MyVisibility(fields, profession: profession, bio: bio, home: home);

  MyVisibility withHome(String home) =>
      MyVisibility(fields, profession: profession, bio: bio, home: home);
}

/// What one account shows another: `visible_account(user)` and
/// `preview_my_account(as)`. The server leaves a hidden part OUT (#1822):
/// `{identity?:{name, avatar_path}, about?:{profession, bio},
/// contact_channels?:{whatsapp, email}, presence?:{last_seen_at,
/// status_text}, can_message}`; here a hidden or empty value is null.
class AccountView {
  const AccountView({
    this.name,
    this.hasPhoto = false,
    this.profession,
    this.bio,
    this.whatsapp,
    this.email,
    this.presence,
    this.presenceShared = false,
    this.canMessage = false,
  });

  final String? name;
  final bool hasPhoto;
  final String? profession;
  final String? bio;
  final String? whatsapp;
  final String? email;
  /// The status line shared with the presence, when there is one.
  final String? presence;

  /// Whether the presence part is shown at all.
  final bool presenceShared;
  final bool canMessage;

  /// Nothing at all is shown.
  bool get isEmpty =>
      name == null &&
      !hasPhoto &&
      profession == null &&
      bio == null &&
      whatsapp == null &&
      email == null &&
      !presenceShared;

  factory AccountView.fromJson(Map<String, dynamic> json) {
    // Fail-closed (#2387): a malformed or blank field reads as absent.
    final r = JsonReader(json, context: 'account_view');
    String? text(String part, String key) {
      final value = r.objectOrAbsent(part).textOrAbsent(key);
      return value != null && value.trim().isNotEmpty ? value : null;
    }

    return AccountView(
      name: text('identity', 'name'),
      hasPhoto: text('identity', 'avatar_path') != null,
      profession: text('about', 'profession'),
      bio: text('about', 'bio'),
      whatsapp: text('contact_channels', 'whatsapp'),
      email: text('contact_channels', 'email'),
      presence: text('presence', 'status_text'),
      presenceShared: r.json['presence'] is Map,
      canMessage: r.isTrue('can_message'),
    );
  }
}
