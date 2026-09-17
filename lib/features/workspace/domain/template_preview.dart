// SPDX-License-Identifier: 0BSD
//
// #1280 S2 — what applying a template to THIS workspace would change, as
// the server computed it (`preview_workspace_template`, 0230).
//
// The client never compares configurations itself: the server's
// change-set is the one the apply will perform, so a preview drawn from
// anything else could promise a change that does not happen.

/// The groups a template is applied by — the only vocabulary the UI shows
/// (#1276 decision 2). Wire names are `deployable_entities().group`;
/// `template_groups_test` pins the set against the migration.
enum TemplateGroup {
  space('space'),
  hoursBooking('hours_booking'),
  pricingCredits('pricing_credits'),
  calendarNavigation('calendar_navigation'),
  wording('wording'),
  rolesAccess('roles_access'),
  forms('forms'),
  appearance('appearance'),
  documentsOperations('documents_operations'),

  /// A group a newer server names: shown, never selectable.
  unknown('');

  const TemplateGroup(this.wire);
  final String wire;

  static TemplateGroup fromWire(String? raw) => TemplateGroup.values
      .firstWhere((g) => g.wire == raw && g != unknown, orElse: () => unknown);

  /// Groups whose application moves money or who may do what: applying
  /// one asks for a confirmation that names it.
  bool get needsConfirmation => this == pricingCredits || this == rolesAccess;
}

enum TemplateCompatibility {
  supported,
  partial,
  notSupported,
  unknown;

  static TemplateCompatibility fromWire(String? raw) => switch (raw) {
        'supported' => supported,
        'partial' => partial,
        'not_supported' => notSupported,
        _ => unknown,
      };
}

enum TemplateGroupState {
  /// Nothing like it here yet: selected by default.
  isNew,

  /// Would change what this workspace has: unselected by default, so the
  /// existing configuration is kept unless somebody chooses otherwise.
  change,

  /// Already the same: nothing to apply.
  matching,

  /// The server says it needs a person's attention first; not selectable.
  needsAttention,

  unknown;

  static TemplateGroupState fromWire(String? raw) => switch (raw) {
        'new' => isNew,
        'change' => change,
        'matching' => matching,
        'needs_attention' => needsAttention,
        _ => unknown,
      };
}

class TemplateGroupPreview {
  const TemplateGroupPreview({
    required this.group,
    required this.wire,
    required this.state,
    required this.itemCount,
    this.reason,
  });

  final TemplateGroup group;

  /// The server's name for the group, kept for the apply request even when
  /// this build does not know it.
  final String wire;
  final TemplateGroupState state;
  final int itemCount;

  /// The server's reason code for [TemplateGroupState.needsAttention].
  final String? reason;

  /// Offered for selection at all.
  bool get selectable =>
      group != TemplateGroup.unknown &&
      (state == TemplateGroupState.isNew || state == TemplateGroupState.change);

  /// Ticked when the sheet opens.
  bool get selectedByDefault => state == TemplateGroupState.isNew && selectable;
}

class TemplatePreview {
  const TemplatePreview({
    required this.compatibility,
    required this.groups,
    this.reason,
  });

  final TemplateCompatibility compatibility;
  final String? reason;
  final List<TemplateGroupPreview> groups;

  bool get applicable =>
      compatibility == TemplateCompatibility.supported ||
      compatibility == TemplateCompatibility.partial;

  /// The number of changes applying [selected] performs — the count the
  /// button names.
  int changesFor(Set<String> selected) => [
        for (final g in groups)
          if (selected.contains(g.wire)) g.itemCount,
      ].fold(0, (a, b) => a + b);

  factory TemplatePreview.fromJson(Map<String, dynamic> json) {
    final groups = <TemplateGroupPreview>[
      for (final raw in json['groups'] as List? ?? const <Object?>[])
        if (raw is Map)
          TemplateGroupPreview(
            group: TemplateGroup.fromWire(raw['group'] as String?),
            wire: raw['group'] as String? ?? '',
            state: TemplateGroupState.fromWire(raw['state'] as String?),
            itemCount: (raw['items'] as List?)?.length ?? 0,
            reason: raw['reason'] as String?,
          ),
    ];
    return TemplatePreview(
      compatibility:
          TemplateCompatibility.fromWire(json['compatibility'] as String?),
      reason: json['reason'] as String?,
      groups: groups,
    );
  }
}
