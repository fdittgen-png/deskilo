// SPDX-License-Identifier: 0BSD
//
// #732 — a validation rule names WHO validates: the admins (as before),
// listed persons of any role, or every member. The editor offers the
// scope and, for a listed rule, the persons; the stored policy carries
// it; the client's eligibility mirror agrees with respond_to_event.
import 'package:deskilo/features/events/domain/validation_policy.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'validation_settings_screen_test.dart' show admin, pumpValidationSettings;

Member plain(String id) => admin(id).copyWith(isAdmin: false);
Member owner(String id) => admin(id).copyWith(isOwner: true);

WorkspaceEvent _expenseBy(String actor) => WorkspaceEvent(
      id: 'evt-1',
      workspaceId: 'ws-1',
      type: EventType.expense,
      action: EventAction.submitted,
      actorMemberId: actor,
      subjectMemberId: actor,
      payload: const {'amount_cents': 1200},
      status: EventStatus.pending,
      createdAt: kTestNow,
    );

ValidationPolicy _policy(String scope, {List<String> ids = const []}) =>
    ValidationPolicy(
      id: 'p',
      workspaceId: 'ws-1',
      eventType: 'expense',
      requiredCount: 1,
      adminsMayValidate: true,
      eligibleAdminIds: ids,
      ownerRequired: false,
      validatorScope: scope,
    );

void main() {
  group('isDecidedBy mirrors the scope', () {
    final event = _expenseBy('member-9');
    test('admins: the owner and admins, never a plain member', () {
      final p = _policy('admins');
      expect(event.isDecidedBy(owner('o'), policy: p), isTrue);
      expect(event.isDecidedBy(admin('a'), policy: p), isTrue);
      expect(event.isDecidedBy(plain('m'), policy: p), isFalse);
    });
    test('listed: exactly the listed persons, whatever their role', () {
      final p = _policy('listed', ids: ['m']);
      expect(event.isDecidedBy(plain('m'), policy: p), isTrue);
      expect(event.isDecidedBy(admin('a'), policy: p), isFalse);
      expect(event.isDecidedBy(owner('o'), policy: p), isTrue);
    });
    test('members: any active member — but never the actor', () {
      final p = _policy('members');
      expect(event.isDecidedBy(plain('m'), policy: p), isTrue);
      expect(event.isDecidedBy(plain('member-9'), policy: p), isFalse);
    });
  });

  testWidgets('the editor offers the scope; a listed rule picks persons of '
      'any role and stores them', (tester) async {
    final events = await pumpValidationSettings(
      tester,
      otherMembers: [admin('member-2'), plain('member-3')],
    );
    await tester.tap(find.text('Payment'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('validation-scope')), findsOneWidget);
    // Admin scope: only the admin (Ana) is offered.
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Bo'), findsNothing);

    await tester.tap(find.text('Listed persons'));
    await tester.pumpAndSettle();
    // Listed scope: everyone active but the owner — Bo is a plain member.
    expect(find.byKey(const ValueKey('validation-person-member-3')),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('validation-person-member-3')));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final stored = events.policies.single;
    expect(stored.validatorScope, 'listed');
    expect(stored.eligibleAdminIds, ['member-3']);
  });

  testWidgets('all members needs no list', (tester) async {
    final events = await pumpValidationSettings(tester);
    await tester.tap(find.text('Payment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All members'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('validation-person-member-2')),
        findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(events.policies.single.validatorScope, 'members');
    expect(events.policies.single.eligibleAdminIds, isEmpty);
  });
}
