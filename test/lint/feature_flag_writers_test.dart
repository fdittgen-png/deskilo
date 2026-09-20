// SPDX-License-Identifier: 0BSD
//
// #1336 — every feature-flag writer goes through the canonical change-set,
// or is a named exception with its reason.
//
// A toggle writes `featureFlagsToggleDelta`: the feature and, switching
// on, its whole requires chain, merged into the row on the server (#800,
// #963). A screen that builds its own map instead can switch a child on
// without its parent, or put back keys a stale copy remembered — the two
// bugs those issues fixed. The process-first redesign (#1323) must keep
// that property, so the writers are counted here: a new one either uses
// the delta or joins the exception list with a sentence saying why.
import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// Files allowed to call `setFeatureFlags` with a map that is NOT a
/// toggle delta. May only shrink.
const _exceptions = <String, String>{
  'lib/features/workspace/application/process_activation.dart':
      'the ONE process write (#1329, ADR 0027): the delta comes from the '
          '#1326 resolver, not from a toggle, and goes with the read-set '
          'the preview rested on so the server can refuse a stale decision',
  'lib/features/workspace/presentation/screens/workspace_settings_screen.dart':
      'the workspace XML import (#916) writes the imported map whole — it '
          'is not a toggle, the server merges it, and #1329 routes it '
          'through the change-set',
};

/// The one place that may name the RPC.
const _repository =
    'lib/features/workspace/data/supabase_workspace_repository.dart';

void main() {
  final sources = {
    for (final f in handWrittenDartFiles('lib')) f.path: f.readAsStringSync(),
  };

  test('every setFeatureFlags caller writes a toggle delta, or is a named '
      'exception', () {
    final offenders = <String>[];
    sources.forEach((path, source) {
      if (!source.contains('.setFeatureFlags(')) return;
      if (_exceptions.containsKey(path)) return;
      if (!source.contains('featureFlagsToggleDelta(')) {
        offenders.add(path);
      }
    });
    expect(
      offenders,
      isEmpty,
      reason: 'build the write with featureFlagsToggleDelta (the feature and '
          'its requires chain), or add the file to _exceptions with the '
          'reason it cannot',
    );
  });

  test('no exception outlives its writer', () {
    final stale = [
      for (final path in _exceptions.keys)
        if (!(sources[path]?.contains('.setFeatureFlags(') ?? false)) path,
    ];
    expect(stale, isEmpty,
        reason: 'the file no longer writes feature flags — drop it from '
            '_exceptions so the list keeps shrinking');
  });

  test('only the repository names the set_feature_flags RPC', () {
    final callers = [
      for (final MapEntry(key: path, value: source) in sources.entries)
        if (source.contains("'set_feature_flags'") && path != _repository) path,
    ];
    expect(callers, isEmpty);
  });

  test('a new workspace is created with the explicit tier map (#1063)', () {
    expect(
      sources[_repository],
      contains(
          "'p_feature_flags': defaultFeatureFlagsForNewWorkspace(withTwin: "
          "withTwin)"),
      reason: 'an empty map would let every registry default — platform '
          'features included — switch on in a space that never chose them',
    );
  });
}
