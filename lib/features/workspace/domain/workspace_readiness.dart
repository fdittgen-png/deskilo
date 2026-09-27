// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1636 — how far a space is from being usable, one section at a time,
// as workspace_readiness (0285) reads it from what the space holds.
// Nothing here is a checkbox: a section is ready because the data is
// there, and recovery stays unverified until evidence exists.

import '../../../core/instance/schema_compatibility.dart';

enum ReadinessArea {
  /// Whether the server runs the schema this build needs — asked by the
  /// app itself (#1312), not by workspace_readiness.
  backend,
  regionRules,
  resources,
  pricing,
  invitations,
  payments,

  /// 0295 — a validation policy nobody present can satisfy.
  rolesValidation,
  recovery,

  /// 0287 — what the switched-on features still need locally (0280).
  localSetup,

  /// 0295 — assistant (MCP) access: optional, listed only while
  /// `mcpAccess` is on, never required for a booking.
  assistant,
  unknown,
}

enum ReadinessState {
  ready,
  needsConfiguration,

  /// Someone outside the space has to act: the installation's operator.
  needsOperator,

  /// Nothing to set up here: no policy asks for a validator, say.
  notApplicable,
  unverified,

  /// The answer could not be read.
  unavailable,
}

/// Who can move a section forward: the space's owner, the installation's
/// operator, or a database administrator (assistant eligibility).
enum ReadinessActor { owner, operator, administrator }

class ReadinessSection {
  const ReadinessSection({
    required this.area,
    required this.state,
    required this.required,
    required this.route,
    this.actor = ReadinessActor.owner,
    this.reason,
  });

  final ReadinessArea area;
  final ReadinessState state;

  /// Blocks a first real booking when true; later operations otherwise.
  final bool required;

  /// Where it is set up.
  final String route;

  final ReadinessActor actor;

  /// The server's code for why, where the state alone does not say it
  /// (`too_few_validators`, `no_policies`, `no_evidence`, `not_exposed`,
  /// `eligibility_*`); null otherwise.
  final String? reason;

  /// Only what someone must still do blocks. An unverified or unavailable
  /// answer is shown, never demanded: offline is not a missing setup.
  bool get blocking =>
      required &&
      (state == ReadinessState.needsConfiguration ||
          state == ReadinessState.needsOperator);

  /// Counts towards "n of m ready"; a not-applicable section does not.
  bool get applicable => state != ReadinessState.notApplicable;

  static List<ReadinessSection> listFromJson(Object? json) => [
    for (final s in json is List ? json : const [])
      if (s is Map)
        ReadinessSection(
          area: switch (s['section']) {
            'region_rules' => ReadinessArea.regionRules,
            'resources' => ReadinessArea.resources,
            'pricing' => ReadinessArea.pricing,
            'invitations' => ReadinessArea.invitations,
            'payments' => ReadinessArea.payments,
            'roles_validation' => ReadinessArea.rolesValidation,
            'recovery' => ReadinessArea.recovery,
            'local_setup' => ReadinessArea.localSetup,
            'assistant' => ReadinessArea.assistant,
            _ => ReadinessArea.unknown,
          },
          state: switch (s['state']) {
            'ready' => ReadinessState.ready,
            'needs_configuration' => ReadinessState.needsConfiguration,
            'needs_operator' => ReadinessState.needsOperator,
            'not_applicable' => ReadinessState.notApplicable,
            'unavailable' => ReadinessState.unavailable,
            _ => ReadinessState.unverified,
          },
          actor: switch (s['actor']) {
            'operator' => ReadinessActor.operator,
            'administrator' => ReadinessActor.administrator,
            _ => ReadinessActor.owner,
          },
          reason: s['reason'] is String ? s['reason'] as String : null,
          required: s['required'] == true,
          route: s['route'] is String && '${s['route']}'.startsWith('/')
              ? s['route'] as String
              : '/workspace-settings',
        ),
  ];
}

/// #1636 — the backend section, from the app's own schema check: the
/// server behind this build needs its operator (and blocks, since the
/// first screen reading a missing column fails); an unanswered question
/// stays unverified and never blocks.
ReadinessSection backendReadiness(SchemaCompatibility? compatibility) =>
    ReadinessSection(
      area: ReadinessArea.backend,
      state: switch (compatibility) {
        SchemaCompatibility.current ||
        SchemaCompatibility.ahead => ReadinessState.ready,
        SchemaCompatibility.behind => ReadinessState.needsOperator,
        SchemaCompatibility.unknown || null => ReadinessState.unverified,
      },
      required: true,
      route: '/server',
      actor: ReadinessActor.operator,
    );

/// The first section that still needs something, blockers before the
/// rest, in the server's order; null when nothing is left to set up.
/// An unverified section is never "next": it is shown, not demanded.
ReadinessSection? nextReadinessStep(List<ReadinessSection> sections) {
  final known = [
    for (final s in sections)
      if (s.area != ReadinessArea.unknown) s,
  ];
  for (final s in known) {
    if (s.blocking) return s;
  }
  for (final s in known) {
    if (s.state == ReadinessState.needsConfiguration ||
        s.state == ReadinessState.needsOperator) {
      return s;
    }
  }
  return null;
}
