// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1282 — a builtin template's feature profile, written as intent and
// expanded into every flag.
//
// A template's `feature_flags` must name all hundred features explicitly
// (the contract test), so that a later registry default can never switch
// something on in a space created from it. Nobody should type a hundred
// flags by hand, and nobody should review them that way either. The JSON
// carries `feature_profile`: the base (the flags a new workspace gets) and
// the few features the template turns on or off; `dart run
// tool/build_builtin_templates.dart` expands it, and the contract test
// fails if the expansion and the file disagree.
import 'workspace_feature.dart';

/// Every flag, from a base plus explicit [on] and [off] lists of feature
/// keys. Unknown keys throw — a typo must not silently mean "off".
Map<String, bool> expandFeatureProfile({
  String base = 'core',
  Iterable<String> on = const [],
  Iterable<String> off = const [],
}) {
  if (base != 'core') {
    throw ArgumentError.value(base, 'base', 'only "core" is a known base');
  }
  final flags = defaultFeatureFlagsForNewWorkspace();
  for (final key in [...on, ...off]) {
    if (!flags.containsKey(key)) {
      throw ArgumentError.value(key, 'feature', 'is not a WorkspaceFeature');
    }
  }
  for (final key in on) {
    flags[key] = true;
  }
  for (final key in off) {
    flags[key] = false;
  }
  return flags;
}

/// The expansion for a template JSON's `feature_profile`, or null when the
/// template has none.
Map<String, bool>? expandTemplateProfile(Map<String, dynamic> template) {
  final profile = template['feature_profile'];
  if (profile is! Map) return null;
  return expandFeatureProfile(
    base: '${profile['base'] ?? 'core'}',
    on: [for (final k in profile['on'] as List? ?? const <Object?>[]) '$k'],
    off: [for (final k in profile['off'] as List? ?? const <Object?>[]) '$k'],
  );
}
