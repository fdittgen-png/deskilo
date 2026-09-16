// SPDX-License-Identifier: 0BSD
//
// #1326 — the eight cases the issue asks for, red-first, against the
// real registry rather than a fixture of my own invention.
//
// The fixtures are measured, not chosen: `invoicing` is reached through
// `requires` from FIVE subprocesses and has four direct dependents
// (`dunning`, `invoicePdfTemplate`, `memberPaymentTerms`,
// `vatManagement`), and `reportDesigner -> invoicePdfTemplate ->
// invoicing` is the deepest chain in the manifest. Using the live
// registry means a future edit that breaks an invariant fails here
// rather than in a screen.
import 'package:deskilo/features/workspace/application/resolve_processes.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('activation', () {
    test('1 — a multi-level chain comes along, named as prerequisites', () {
      // reportDesign holds reportDesigner, whose chain is
      // invoicePdfTemplate -> invoicing. Neither is in that subprocess.
      final change = resolveActivation(
        active: const {},
        subprocessKeys: const ['reportDesign'],
      );

      expect(change.flags[WorkspaceFeature.reportDesigner.dbKey], isTrue);
      expect(change.flags[WorkspaceFeature.invoicePdfTemplate.dbKey], isTrue,
          reason: 'the intermediate link of the chain');
      expect(change.flags[WorkspaceFeature.invoicing.dbKey], isTrue,
          reason: 'the root of it');

      final prerequisites = change.capabilities
          .where((c) => c.reason == CapabilityReason.prerequisite)
          .map((c) => c.feature)
          .toSet();
      expect(prerequisites, contains(WorkspaceFeature.invoicing));
      expect(prerequisites, isNot(contains(WorkspaceFeature.reportDesigner)),
          reason: 'what the owner selected is not a prerequisite');
    });

    test('2 — two subprocesses sharing a prerequisite enable it ONCE, and '
        'the UI can say who wanted it', () {
      // tax and collection both reach `invoicing`: tax through
      // vatManagement, collection through dunning.
      final change = resolveActivation(
        active: const {},
        subprocessKeys: const ['tax', 'collection'],
      );

      final invoicing = change.capabilities
          .where((c) => c.feature == WorkspaceFeature.invoicing)
          .toList();
      expect(invoicing, hasLength(1),
          reason: 'a shared prerequisite appears once, not once per '
              'subprocess that wanted it');
      expect(invoicing.single.neededBy.length, greaterThan(1),
          reason: 'and it names everything that reached it, so the screen '
              'can explain why it is switching on');
      expect(
        change.flags.keys.where((k) => k == WorkspaceFeature.invoicing.dbKey),
        hasLength(1),
      );
    });

    test('3 — a partially active process reports what is already on', () {
      final first = resolveActivation(
        active: const {},
        subprocessKeys: const ['collection'],
      );
      final applied = {
        for (final entry in first.flags.entries)
          if (entry.value)
            WorkspaceFeature.values.firstWhere((f) => f.dbKey == entry.key),
      };

      final again = resolveActivation(
        active: applied,
        subprocessKeys: const ['collection'],
      );

      expect(again.flags, isEmpty,
          reason: 'nothing left to change');
      expect(
        again.capabilities.every(
            (c) => c.reason == CapabilityReason.alreadyActive),
        isTrue,
        reason: 'and every one of them says so rather than claiming to '
            'have been enabled',
      );
    });

    test('7 — the same intent twice produces the same list, in registry '
        'order', () {
      final a = resolveActivation(
        active: const {},
        subprocessKeys: const ['tax', 'collection'],
      );
      final b = resolveActivation(
        active: const {},
        subprocessKeys: const ['collection', 'tax'],
      );

      expect(a.capabilities.map((c) => c.feature).toList(),
          b.capabilities.map((c) => c.feature).toList(),
          reason: 'the order the caller lists subprocesses in must not '
              'change the change-set');
      expect(a.flags, b.flags);
    });

    test('an internal capability is never selected', () {
      // siteDocuments is classified internal (#1325): no implementation
      // consumes it, so no intent may switch it on.
      for (final key in allSubprocessKeys()) {
        final change =
            resolveActivation(active: const {}, subprocessKeys: [key]);
        expect(change.flags.containsKey(WorkspaceFeature.siteDocuments.dbKey),
            isFalse,
            reason: '$key would enable an internal capability');
      }
    });
  });

  group('deactivation', () {
    test('4 — removing a prerequisite another active process needs is '
        'REFUSED, and nothing is written', () {
      // Turn on tax (which pulls invoicing in), then ask to remove the
      // invoicing subprocess while tax stays.
      final on = resolveActivation(
        active: const {},
        subprocessKeys: const ['tax', 'invoicing'],
      );
      final active = {
        for (final entry in on.flags.entries)
          if (entry.value)
            WorkspaceFeature.values.firstWhere((f) => f.dbKey == entry.key),
      };

      final off = resolveDeactivation(
        active: active,
        subprocessKeys: const ['invoicing'],
      );

      expect(off.isBlocked, isTrue,
          reason: 'vatManagement still needs invoicing');
      expect(off.flags, isEmpty,
          reason: 'a blocked removal writes NOTHING — half a removal is '
              'the state the owner cannot reason about');
      final blocked = off.blockedBy
          .firstWhere((b) => b.feature == WorkspaceFeature.invoicing);
      expect(blocked.orphans, contains(WorkspaceFeature.vatManagement));
    });

    test('a removal that orphans nothing goes through', () {
      final on = resolveActivation(
        active: const {},
        subprocessKeys: const ['collection'],
      );
      final active = {
        for (final entry in on.flags.entries)
          if (entry.value)
            WorkspaceFeature.values.firstWhere((f) => f.dbKey == entry.key),
      };

      final off = resolveDeactivation(
        active: active,
        subprocessKeys: const ['collection'],
      );

      expect(off.isBlocked, isFalse);
      expect(off.flags.values.every((v) => v == false), isTrue);
      expect(off.flags[WorkspaceFeature.dunning.dbKey], isFalse);
    });

    test('deactivating something that is not on changes nothing', () {
      final off = resolveDeactivation(
        active: const {},
        subprocessKeys: const ['tax'],
      );
      expect(off.isEmpty, isTrue);
    });
  });

  group('the registry itself', () {
    test('5 — the requirement closure terminates on every capability', () {
      // requirementChain carries a visited set; this proves no feature
      // in the LIVE registry can hang it, which is the invariant the
      // resolver leans on.
      for (final feature in WorkspaceFeature.values) {
        final chain = requirementChain(feature);
        expect(chain.toSet().length, chain.length,
            reason: '${feature.name} repeats a link — a cycle');
        expect(chain, isNot(contains(feature)),
            reason: '${feature.name} requires itself');
      }
    });

    test('6 — every capability a subprocess names exists in the manifest',
        () {
      for (final key in allSubprocessKeys()) {
        for (final feature in capabilitiesOf(key)) {
          expect(featureManifest.containsKey(feature), isTrue,
              reason: '$key names ${feature.name}, which has no manifest '
                  'entry');
        }
      }
      expect(capabilitiesOf('no-such-subprocess'), isEmpty,
          reason: 'an unknown key resolves to nothing rather than '
              'half-applying an intent');
    });

    test('8 — a stored feature map derives process state, and activating '
        'everything satisfies every subprocess', () {
      // The map a NEW workspace is created with: Core, default-on only.
      final stored = {
        for (final entry in defaultFeatureFlagsForNewWorkspace().entries)
          if (entry.value)
            WorkspaceFeature.values.firstWhere((f) => f.dbKey == entry.key),
      };
      final satisfied = activeSubprocesses(active: stored);
      expect(satisfied, isNotEmpty,
          reason: 'a fresh workspace already satisfies some subprocesses; '
              'deriving none would mean the mapping cannot read an '
              'existing workspace at all');

      // And the other end: everything on satisfies everything.
      final all = WorkspaceFeature.values.toSet();
      expect(activeSubprocesses(active: all), allSubprocessKeys(),
          reason: 'with every capability on, every subprocess is active');
    });

    test('no activation can produce a map effectiveFeatures would prune',
        () {
      // The acceptance criterion "no invalid final feature map can be
      // returned", stated in the app's own terms: effectiveFeatures drops
      // a feature whose chain is not fully on, so a resolver output it
      // prunes would be a green switch with nothing behind it.
      for (final key in allSubprocessKeys()) {
        final change =
            resolveActivation(active: const {}, subprocessKeys: [key]);
        final resulting = {
          for (final entry in change.flags.entries)
            if (entry.value)
              WorkspaceFeature.values.firstWhere((f) => f.dbKey == entry.key),
        };
        expect(effectiveFeatures(resulting), resulting,
            reason: '$key resolves to a map that effectiveFeatures would '
                'prune — something was enabled without its chain');
      }
    });
  });
}
