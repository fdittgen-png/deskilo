// SPDX-License-Identifier: MIT
import 'package:deskilo/features/events/domain/validation_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const expensePolicy = ValidationPolicy(
    id: 'vp-1',
    workspaceId: 'ws-1',
    eventType: 'expense',
    requiredCount: 3,
    adminsMayValidate: true,
    eligibleAdminIds: [],
    ownerRequired: true,
  );
  const defaultPolicy = ValidationPolicy(
    id: 'vp-2',
    workspaceId: 'ws-1',
    eventType: null,
    requiredCount: 2,
    adminsMayValidate: false,
    eligibleAdminIds: [],
    ownerRequired: false,
  );

  group('policyFor', () {
    test('the exact event-type row wins', () {
      expect(
        policyFor('expense', [defaultPolicy, expensePolicy]),
        expensePolicy,
      );
    });

    test('falls back to the workspace-default (null type) row', () {
      expect(
        policyFor('reservation', [defaultPolicy, expensePolicy]),
        defaultPolicy,
      );
    });

    test('absent rows yield the pre-quorum defaults', () {
      final policy = policyFor('payment', const []);
      expect(policy.id, isNull);
      expect(policy.requiredCount, 1);
      expect(policy.adminsMayValidate, isTrue);
      expect(policy.eligibleAdminIds, isEmpty);
      expect(policy.ownerRequired, isFalse);
    });

    test('defaults inherit the workspace of the stored rows', () {
      expect(policyFor('payment', [expensePolicy]).workspaceId, 'ws-1');
    });
  });

  test('ValidationPolicy.defaults mirrors the pre-#130 protocol', () {
    final policy = ValidationPolicy.defaults('ws-9', 'service_charge');
    expect(policy.workspaceId, 'ws-9');
    expect(policy.eventType, 'service_charge');
    expect(policy.requiredCount, 1);
    expect(policy.adminsMayValidate, isTrue);
    expect(policy.eligibleAdminIds, isEmpty);
    expect(policy.ownerRequired, isFalse);
  });
}
