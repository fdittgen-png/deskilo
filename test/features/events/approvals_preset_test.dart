// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2871 — the approvals preset of the setup guide. The people who can
// approve are the owners and the administrators; a count above them is
// unreachable and is never written, by the command either. The default
// rule the preset writes is decided by owners and every administrator,
// keeps the stored row's identity and its other choices, and starts from
// the built-in rule when none is stored.
import 'package:deskilo/features/events/application/apply_approvals_preset.dart';
import 'package:deskilo/features/events/domain/approvals_preset.dart';
import 'package:deskilo/features/events/domain/validation_policy.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_event_repository.dart';

void main() {
  const preset = ApprovalsPreset(owners: 1, admins: 2);

  test('reachable from one approval up to the people who can approve', () {
    expect(preset.people, 3);
    expect(preset.reachable(0), isFalse);
    expect(preset.reachable(1), isTrue);
    expect(preset.reachable(3), isTrue);
    expect(preset.reachable(4), isFalse);
  });

  test('the default rule keeps the stored row and its other choices', () {
    const stored = ValidationPolicy(
      id: 'p-1',
      workspaceId: 'ws-1',
      requiredCount: 1,
      adminsMayValidate: false,
      eligibleAdminIds: ['m-9'],
      ownerRequired: true,
      validatorScope: 'listed',
      sequential: true,
    );
    final rule = preset.defaultRule('ws-1', stored, 2);
    expect(rule.id, 'p-1');
    expect(rule.eventType, isNull);
    expect(rule.requiredCount, 2);
    expect(rule.adminsMayValidate, isTrue);
    expect(rule.eligibleAdminIds, isEmpty);
    expect(rule.validatorScope, 'admins');
    expect(rule.ownerRequired, isFalse);
    expect(rule.sequential, isTrue, reason: 'not the preset\'s to change');
  });

  test('without a stored rule it starts from the built-in one', () {
    final rule = preset.defaultRule('ws-1', null, 3);
    expect(rule.id, isNull);
    expect(rule.workspaceId, 'ws-1');
    expect(rule.requiredCount, 3);
  });

  group('the command', () {
    test('writes the default rule', () async {
      final events = FakeEventRepository();
      await ApplyApprovalsPreset(events)
          .apply('ws-1', preset, stored: null, requiredCount: 2);
      final row = events.policies.single;
      expect(row.eventType, isNull);
      expect(row.requiredCount, 2);
    });

    test('refuses a count nobody can reach and writes nothing', () async {
      final events = FakeEventRepository();
      expect(
        () =>
            ApplyApprovalsPreset(events)
                .apply('ws-1', preset, stored: null, requiredCount: 4),
        throwsArgumentError,
      );
      expect(events.policies, isEmpty);
    });
  });
}
