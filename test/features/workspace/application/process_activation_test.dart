// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1329 — the preview says exactly what a process intent writes, what it
// drags along, and every flag the decision rested on; a deactivation that
// would orphan stored-on dependants is refused unless the owner says how.
import 'package:deskilo/features/workspace/application/process_activation.dart';
import 'package:deskilo/features/workspace/application/resolve_processes.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_process.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A subprocess whose capabilities have a prerequisite in ANOTHER
  // subprocess, found from the registry rather than hard-coded, so the
  // test follows the manifest when it moves.
  late String withPrerequisite;
  late WorkspaceFeature child;
  late WorkspaceFeature parent;

  setUpAll(() {
    for (final process in workspaceProcesses) {
      for (final sub in process.subprocesses) {
        for (final feature in sub.capabilities) {
          if (internalCapabilities.containsKey(feature)) continue;
          final chain = requirementChain(feature);
          if (chain.isEmpty) continue;
          if (internalCapabilities.containsKey(chain.first)) continue;
          if (sub.capabilities.contains(chain.first)) continue;
          withPrerequisite = sub.key;
          child = feature;
          parent = chain.first;
          return;
        }
      }
    }
    fail('the registry has no subprocess with an outside prerequisite');
  });

  group('activation', () {
    test('writes the selected capabilities and their prerequisites, and the '
        'read-set covers every one of them as read', () {
      final plan = planProcessChange(
        raw: const {},
        subprocessKeys: [withPrerequisite],
        activate: true,
      );
      expect(plan.flags[child.dbKey], isTrue);
      expect(plan.flags[parent.dbKey], isTrue, reason: 'pulled in');
      expect(plan.expected[child.dbKey], isFalse);
      expect(plan.expected[parent.dbKey], isFalse);
      expect(plan.expected.keys, containsAll(plan.flags.keys));
      expect(plan.isBlocked, isFalse);
    });

    test('a capability already on is in the read-set as true and not in '
        'the delta', () {
      final plan = planProcessChange(
        raw: {parent},
        subprocessKeys: [withPrerequisite],
        activate: true,
      );
      expect(plan.flags.containsKey(parent.dbKey), isFalse);
      expect(plan.expected[parent.dbKey], isTrue);
      expect(
        plan.changeSet.capabilities
            .firstWhere((c) => c.feature == parent)
            .reason,
        CapabilityReason.alreadyActive,
      );
    });

    test('a stored-on capability held back by the prerequisite is revived, '
        'named, and part of the read-set', () {
      // The child is stored on while its parent is off: effective drops it.
      final plan = planProcessChange(
        raw: {child},
        subprocessKeys: [withPrerequisite],
        activate: true,
      );
      expect(plan.flags[parent.dbKey], isTrue);
      expect(plan.flags.containsKey(child.dbKey), isFalse,
          reason: 'stored on already — nothing to write');
      expect(plan.expected[child.dbKey], isTrue);
      final revivedElsewhere = plan.revived.where((f) => f != child);
      for (final f in revivedElsewhere) {
        expect(plan.expected[f.dbKey], isTrue);
      }
    });

    test('an intent already satisfied has nothing to do', () {
      final all = planProcessChange(
        raw: const {},
        subprocessKeys: [withPrerequisite],
        activate: true,
      );
      final again = planProcessChange(
        raw: all.written.toSet(),
        subprocessKeys: [withPrerequisite],
        activate: true,
      );
      expect(again.nothingToDo, isTrue);
      expect(again.flags, isEmpty);
    });
  });

  group('deactivation', () {
    late Set<WorkspaceFeature> raw;
    late String parentSubprocess;

    setUp(() {
      raw = planProcessChange(
        raw: const {},
        subprocessKeys: [withPrerequisite],
        activate: true,
      ).written.toSet();
      parentSubprocess = [
        for (final process in workspaceProcesses)
          for (final sub in process.subprocesses)
            if (sub.capabilities.contains(parent)) sub.key,
      ].first;
    });

    test('switching the child off writes only the child, and its read-set '
        'is the child', () {
      final plan = planProcessChange(
        raw: raw,
        subprocessKeys: [withPrerequisite],
        activate: false,
      );
      expect(plan.isBlocked, isFalse);
      expect(plan.flags[child.dbKey], isFalse);
      expect(plan.flags.containsKey(parent.dbKey), isFalse);
      expect(plan.expected[child.dbKey], isTrue);
    });

    test('switching the prerequisite off while the child is stored on is '
        'refused by default, naming the dependant', () {
      final plan = planProcessChange(
        raw: raw,
        subprocessKeys: [parentSubprocess],
        activate: false,
      );
      expect(plan.isBlocked, isTrue);
      expect(plan.flags, isEmpty, reason: 'nothing is written');
      expect(plan.changeSet.blockedBy.any((b) => b.orphans.contains(child)),
          isTrue);
      expect(plan.expected[child.dbKey], isTrue,
          reason: 'the dependant is part of the decision');
    });

    test('keeping the dependants writes false only for what was asked, and '
        'names what stays stored but stops working', () {
      final plan = planProcessChange(
        raw: raw,
        subprocessKeys: [parentSubprocess],
        activate: false,
        mode: DeactivationMode.keepDependants,
      );
      expect(plan.isBlocked, isTrue, reason: 'the resolver still says so');
      expect(plan.flags[parent.dbKey], isFalse);
      expect(plan.flags.containsKey(child.dbKey), isFalse,
          reason: 'the stored child choice survives');
      expect(plan.heldBack, contains(child));
      expect(plan.alsoOff, isEmpty);
      // The effective set after the write is dependency-safe.
      final after = effectiveFeatures({
        for (final f in raw)
          if (plan.flags[f.dbKey] != false) f,
      });
      expect(after.contains(child), isFalse);
    });

    test('removing the dependants is a distinct intent that writes them '
        'off too', () {
      final plan = planProcessChange(
        raw: raw,
        subprocessKeys: [parentSubprocess],
        activate: false,
        mode: DeactivationMode.removeDependants,
      );
      expect(plan.flags[parent.dbKey], isFalse);
      expect(plan.flags[child.dbKey], isFalse);
      expect(plan.alsoOff, contains(child));
      expect(plan.heldBack, isEmpty);
    });
  });
}
