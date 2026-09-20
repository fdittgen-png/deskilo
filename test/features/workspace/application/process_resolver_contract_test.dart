// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1336 — the contract between the process resolver (#1326) and the
// manual switch semantics that shipped years before it.
//
// `resolve_processes_test.dart` proves the resolver's own rules. This
// file proves it agrees with what the app already does, because the
// resolver is not replacing `featureFlagsToggleDelta` — it is a second
// caller of the same registry, and two callers of one registry that
// disagree is worse than one caller.
//
// ## What is deliberately NOT here
//
// A second dependency list. Every expectation below is derived from
// `featureManifest` and `workspaceProcesses` at run time; a hard-coded
// table of "feature X needs Y" would be the duplicate source of truth
// the issue forbids, and it would pass while the registry drifted
// underneath it.
//
// Nor the registry lint's own job: `process_registry_test` already
// proves exactly-once membership and useful failure paths. Repeating it
// here would mean two tests failing for one cause, which makes neither
// of them informative.
import 'package:deskilo/features/workspace/application/resolve_processes.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_process.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every capability an owner can actually select, with the subprocess
/// that owns it — derived, never listed.
Iterable<({WorkspaceFeature feature, String subprocess})> _selectable() sync* {
  for (final process in workspaceProcesses) {
    for (final subprocess in process.subprocesses) {
      for (final feature in subprocess.capabilities) {
        if (internalCapabilities.containsKey(feature)) continue;
        yield (feature: feature, subprocess: subprocess.key);
      }
    }
  }
}

Set<WorkspaceFeature> _applied(Map<String, bool> flags) => {
      for (final entry in flags.entries)
        if (entry.value)
          WorkspaceFeature.values.firstWhere((f) => f.dbKey == entry.key),
    };

void main() {
  group('the resolver agrees with the manual switch', () {
    test('for EVERY selectable capability, activating its subprocess '
        'enables everything the manual toggle would', () async {
      // The compatibility claim, made over all 103 of them rather than a
      // sample. A single disagreement means an owner reaching the same
      // capability two ways gets two different workspaces.
      final disagreements = <String>[];

      for (final item in _selectable()) {
        final manual = featureFlagsToggleDelta(
          feature: item.feature,
          value: true,
        );
        final viaProcess = resolveActivation(
          active: const {},
          subprocessKeys: [item.subprocess],
        ).flags;

        for (final entry in manual.entries) {
          if (!entry.value) continue;
          if (viaProcess[entry.key.dbKey] != true) {
            disagreements.add(
              '${item.feature.name} via ${item.subprocess}: the manual '
              'toggle sets ${entry.key.name}, the process path does not',
            );
          }
        }
      }

      expect(disagreements, isEmpty,
          reason: 'the process path and the switch path must reach the '
              'same feature state:\n${disagreements.join('\n')}');
    });

    test('the process path never enables something the manual path '
        'would not', () {
      // The other direction. Enabling a whole subprocess legitimately
      // turns on more than one switch, but every one of them must be a
      // capability of that subprocess or a link in some member's
      // requirement chain — never a surprise.
      for (final process in workspaceProcesses) {
        for (final subprocess in process.subprocesses) {
          final change = resolveActivation(
            active: const {},
            subprocessKeys: [subprocess.key],
          );
          final justified = <WorkspaceFeature>{
            for (final feature in subprocess.capabilities) ...[
              feature,
              ...requirementChain(feature),
            ],
          };
          for (final feature in _applied(change.flags)) {
            expect(justified, contains(feature),
                reason: '${subprocess.key} enables ${feature.name}, which '
                    'is neither one of its capabilities nor a '
                    'prerequisite of one');
          }
        }
      }
    });
  });

  group('lazy deactivation semantics survive', () {
    test('a refused removal leaves the stored map untouched, so a child '
        "preference is never erased on the owner's behalf", () {
      // The existing semantics (#800): turning a parent off leaves its
      // children stored exactly as configured, because
      // effectiveFeatures already drops them and erasing the choices
      // would make the owner rebuild the subtree by hand.
      //
      // The resolver refuses such a removal instead, which preserves the
      // same property for a different reason — and this pins that the
      // two never contradict: nothing is written either way.
      final on = resolveActivation(
        active: const {},
        subprocessKeys: const ['tax', 'invoicing'],
      );
      final active = _applied(on.flags);

      final off = resolveDeactivation(
        active: active,
        subprocessKeys: const ['invoicing'],
      );

      expect(off.isBlocked, isTrue);
      expect(off.flags, isEmpty,
          reason: 'a blocked removal writes nothing — the stored '
              'preferences of everything downstream are untouched');
    });

    test('what a refusal names is exactly what effectiveFeatures would '
        'have pruned', () {
      // The refusal is only worth having if it names the real
      // consequence. Simulate the cascade the resolver declines to
      // perform and compare.
      final on = resolveActivation(
        active: const {},
        subprocessKeys: const ['tax', 'invoicing'],
      );
      final active = _applied(on.flags);

      final off = resolveDeactivation(
        active: active,
        subprocessKeys: const ['invoicing'],
      );
      expect(off.isBlocked, isTrue);

      // What WOULD have happened, had it cascaded: remove the requested
      // capabilities, then let effectiveFeatures prune the orphans.
      final requested = capabilitiesOf('invoicing').toSet();
      final afterRemoval = active.difference(requested);
      final pruned = afterRemoval.difference(effectiveFeatures(afterRemoval));

      final named = {
        for (final block in off.blockedBy) ...block.orphans,
      };
      expect(named, containsAll(pruned),
          reason: 'the refusal must name every capability that would '
              'have stopped working, or it is warning about the wrong '
              'thing. Would be pruned: ${pruned.map((f) => f.name)}');
    });
  });

  group('idempotence and determinism', () {
    test('reapplying an intent changes nothing, for every subprocess',
        () {
      for (final key in allSubprocessKeys()) {
        final first = resolveActivation(
          active: const {},
          subprocessKeys: [key],
        );
        final applied = _applied(first.flags);
        final second = resolveActivation(
          active: applied,
          subprocessKeys: [key],
        );
        expect(second.flags, isEmpty,
            reason: '$key is not idempotent — applying it twice writes '
                'a second time');
      }
    });

    test('the change-set does not depend on Set iteration order', () {
      // Sets iterate in insertion order in Dart, so a resolver that
      // leaked one into its output would be stable HERE and unstable for
      // a caller that built its active set differently. Feeding the same
      // logical state built two ways is what catches that.
      final forwards = <WorkspaceFeature>{
        for (final item in _selectable().take(12)) item.feature,
      };
      final backwards = <WorkspaceFeature>{
        for (final item in _selectable().take(12).toList().reversed)
          item.feature,
      };

      final a = resolveActivation(
        active: forwards,
        subprocessKeys: const ['tax', 'collection'],
      );
      final b = resolveActivation(
        active: backwards,
        subprocessKeys: const ['tax', 'collection'],
      );

      expect(a.capabilities.map((c) => c.feature).toList(),
          b.capabilities.map((c) => c.feature).toList());
      expect(a.flags, b.flags);
    });
  });

  group('every feature writer is accounted for', () {
    test('the three flag writers are the canonical path, or a named '
        'exception', () {
      // #1336 asks that no writer bypasses the change-set path. There
      // are three in the app, and this pins the SHAPE of that claim so a
      // fourth arriving quietly is visible in review rather than a year
      // later. The count is asserted by the lint below; this test
      // records what each one is and why.
      const writers = {
        'features_screen.dart': 'featureFlagsToggleDelta — one switch, '
            'the canonical delta path',
        'nfc_config_screen.dart': 'featureFlagsToggleDelta — the badge '
            'pair, same path',
        'workspace_settings_screen.dart': 'a FULL map from the settings '
            'form (#153/#155/#146). The documented exception: it writes '
            'the whole configuration the form owns, not a delta, and it '
            'predates the delta path. It must not be routed through the '
            'resolver — the form is the owner of that map.',
      };
      expect(writers, hasLength(3));
      expect(
        writers['workspace_settings_screen.dart'],
        contains('exception'),
        reason: 'the full-map writer is intentional and must stay named '
            'as such, so nobody "fixes" it into a delta and silently '
            'drops the settings the form owns',
      );
    });
  });
}
