// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2519 — "no platform entry with `defaultOn: true` without a stated
// reason", as a ratchet and not a waiver.
//
// A platform feature is "asked for, never assumed" (FeatureTier), yet some
// start ON in a new workspace. The reason is written beside the registry in
// `platformDefaultReasons`. This counts the platform default-on entries
// that still have none and holds the count where it is: up means a new
// platform default-on entry arrived without its reason (state it, or make
// the entry default off); down must be recorded by lowering the ceiling.
// A reason is never invented to lower the count.
import 'package:deskilo/features/workspace/domain/platform_default_reasons.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

import 'literal_ratchet.dart';

/// Platform default-on entries without a stated reason, on 2026-11-02:
/// 51 entries, 30 reasons stated from what their own code, catalogue text or
/// issue says (13, 11, then 6 more); the other 21 say what the feature is,
/// not why it starts on, and stay counted.
const _withoutReason = 21;

Set<WorkspaceFeature> _platformDefaultOn() => {
  for (final e in featureManifest.values)
    if (e.tier == FeatureTier.platform && e.defaultOn) e.feature,
};

void main() {
  test('platform default-on entries without a reason only fall (ratchet)', () {
    final missing = _platformDefaultOn()
        .where((f) => !platformDefaultReasons.containsKey(f))
        .map((f) => f.name)
        .toList()
      ..sort();
    expect(
      missing.length,
      _withoutReason,
      reason: ratchetMessage(
        rule: 'platform_default_reason (#2519)',
        kind: 'platform default-on entries without a stated reason',
        ceiling: _withoutReason,
        actual: missing.length,
        perFile: {for (final n in missing) n: 1},
      ),
    );
  });

  test('a reason says something', () {
    for (final entry in platformDefaultReasons.entries) {
      expect(
        entry.value.trim().length,
        greaterThan(20),
        reason: '${entry.key.name}: a reason is a sentence, not a label',
      );
      expect(
        entry.value,
        matches(RegExp(r'#\d+')),
        reason: '${entry.key.name}: name the issue that states it',
      );
    }
  });

  test('a reason belongs to a platform default-on entry (no stale rows)', () {
    final on = _platformDefaultOn();
    for (final feature in platformDefaultReasons.keys) {
      expect(
        on.contains(feature),
        isTrue,
        reason: '${feature.name} has a reason but is not a platform entry '
            'that starts on: delete the reason',
      );
    }
  });
}
