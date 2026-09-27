// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1636 — how far a space is from being usable, one section at a time,
// as workspace_readiness (0285) reads it from what the space holds.
// Nothing here is a checkbox: a section is ready because the data is
// there, and recovery stays unverified until evidence exists.

enum ReadinessArea {
  regionRules,
  resources,
  pricing,
  invitations,
  payments,
  recovery,
  unknown,
}

enum ReadinessState { ready, needsConfiguration, unverified }

class ReadinessSection {
  const ReadinessSection({
    required this.area,
    required this.state,
    required this.required,
    required this.route,
  });

  final ReadinessArea area;
  final ReadinessState state;

  /// Blocks a first real booking when true; later operations otherwise.
  final bool required;

  /// Where it is set up.
  final String route;

  bool get blocking => required && state != ReadinessState.ready;

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
            'recovery' => ReadinessArea.recovery,
            _ => ReadinessArea.unknown,
          },
          state: switch (s['state']) {
            'ready' => ReadinessState.ready,
            'needs_configuration' => ReadinessState.needsConfiguration,
            _ => ReadinessState.unverified,
          },
          required: s['required'] == true,
          route: s['route'] is String && '${s['route']}'.startsWith('/')
              ? s['route'] as String
              : '/workspace-settings',
        ),
  ];
}

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
    if (s.state == ReadinessState.needsConfiguration) return s;
  }
  return null;
}
