// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1288 S2 — the questions a workspace asks, as the app reads them.
//
// Pure Dart, mirroring what 0248 stores. The client renders and
// pre-validates; the server validates again in `field_answer_problem`
// and is the authority. Every rule below therefore exists TWICE on
// purpose: a form that lets somebody type an answer the server will
// refuse wastes their time, and a client that decides alone would be a
// second authority nobody audited.

/// The answer types a question can have.
enum WorkspaceFieldType {
  text,
  // The named argument is not decoration: `no_hardcoded_strings` greps
  // for `Text('`, and `longText('long_text')` contains it.
  longText(wire: 'long_text'),
  integer,
  decimal,
  date,
  boolean,
  singleChoice(wire: 'single_choice'),
  multiChoice(wire: 'multi_choice');

  const WorkspaceFieldType({this._wire});

  final String? _wire;

  /// The value 0248 stores.
  String get wireName => _wire ?? name;

  static WorkspaceFieldType? of(String wire) {
    for (final t in values) {
      if (t.wireName == wire) return t;
    }
    return null;
  }

  /// Whether the answer is one of a list rather than typed in.
  bool get isChoice =>
      this == WorkspaceFieldType.singleChoice ||
      this == WorkspaceFieldType.multiChoice;
}

/// Where a question is asked. A code registry, as 0248's
/// `field_contexts()` is: a definition may name no other.
enum WorkspaceFieldContext {
  /// A member editing their own information in Settings.
  profile,

  /// An administrator editing a managed member.
  managedMember(wire: 'managed_member'),

  /// The join flow, saving onto the pending member row.
  joinRequest(wire: 'join_request');

  const WorkspaceFieldContext({this._wire});

  final String? _wire;

  String get wireName => _wire ?? name;

  static WorkspaceFieldContext? of(String wire) {
    for (final c in values) {
      if (c.wireName == wire) return c;
    }
    return null;
  }
}

/// Who may read an answer.
enum WorkspaceFieldVisibility {
  /// The member themselves, and nobody else.
  self,

  /// And whoever holds `viewPersonalData`.
  managers,

  /// And every member of the workspace.
  members;

  static WorkspaceFieldVisibility of(String wire) => values.firstWhere(
        (v) => v.name == wire,
        orElse: () => WorkspaceFieldVisibility.self,
      );
}

/// One choice of a choice question.
class WorkspaceFieldOption {
  const WorkspaceFieldOption({
    required this.key,
    required this.labels,
    this.sortOrder = 0,
    this.active = true,
  });

  final String key;

  /// Locale → label. The workspace's own language is guaranteed by 0248.
  final Map<String, String> labels;
  final int sortOrder;
  final bool active;

  /// The label in [locale], falling back to [fallbackLocale] and then to
  /// the key — which is ugly on screen and therefore visible, rather
  /// than blank and therefore not.
  String labelIn(String locale, {String fallbackLocale = 'en'}) =>
      labels[locale] ?? labels[fallbackLocale] ?? key;
}

/// One question.
class WorkspaceField {
  const WorkspaceField({
    required this.id,
    required this.key,
    required this.type,
    required this.labels,
    this.helpTexts = const {},
    this.required = false,
    this.personalData = true,
    this.visibility = WorkspaceFieldVisibility.self,
    this.contexts = const {WorkspaceFieldContext.profile},
    this.groupKey = 'general',
    this.sortOrder = 0,
    this.validation = const {},
    this.active = true,
    this.options = const [],
  });

  final String id;
  final String key;
  final WorkspaceFieldType type;
  final Map<String, String> labels;
  final Map<String, String> helpTexts;

  // ignore: avoid_positional_boolean_parameters
  final bool required;
  final bool personalData;
  final WorkspaceFieldVisibility visibility;
  final Set<WorkspaceFieldContext> contexts;
  final String groupKey;
  final int sortOrder;

  /// The curated rules of 0248: `min_length`, `max_length`, `min`, `max`,
  /// `min_date`, `max_date`, `named`.
  final Map<String, Object?> validation;
  final bool active;

  /// Only for a choice question, in `sortOrder` then key order.
  final List<WorkspaceFieldOption> options;

  String labelIn(String locale, {String fallbackLocale = 'en'}) =>
      labels[locale] ?? labels[fallbackLocale] ?? key;

  String? helpIn(String locale, {String fallbackLocale = 'en'}) {
    final text = helpTexts[locale] ?? helpTexts[fallbackLocale];
    return (text == null || text.trim().isEmpty) ? null : text;
  }

  /// The choices a form may offer: the active ones, in order.
  List<WorkspaceFieldOption> get liveOptions =>
      [for (final o in options) if (o.active) o]
        ..sort((a, b) {
          final byOrder = a.sortOrder.compareTo(b.sortOrder);
          return byOrder != 0 ? byOrder : a.key.compareTo(b.key);
        });
}

/// The questions of one context, in the order a form asks them.
List<WorkspaceField> fieldsForContext(
  Iterable<WorkspaceField> fields,
  WorkspaceFieldContext context,
) =>
    [
      for (final f in fields)
        if (f.active && f.contexts.contains(context)) f,
    ]..sort((a, b) {
        final byGroup = a.groupKey.compareTo(b.groupKey);
        if (byGroup != 0) return byGroup;
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        return byOrder != 0 ? byOrder : a.key.compareTo(b.key);
      });
