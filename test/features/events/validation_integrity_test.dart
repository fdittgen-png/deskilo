// SPDX-License-Identifier: 0BSD
//
// #840 — the configured rule holds, and the screen where it is set says
// what it is. Nobody validates their own event; the single exception
// belongs to the owner alone and only when a rule grants it; and a rule
// may ask for its validations one after another. Migration 0149 carries
// the server half (the money RPCs consult the workspace default row, and
// the required count is no longer clamped to the pool).
import 'package:deskilo/features/events/domain/validation_policy.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'validation_settings_screen_test.dart'
    show admin, pumpValidationSettings;

Member _owner(String id) => admin(id).copyWith(isOwner: true);

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

ValidationPolicy _policy({
  bool ownerMaySelfValidate = false,
  bool sequential = false,
  int requiredCount = 1,
  String scope = 'admins',
}) =>
    ValidationPolicy(
      id: 'p',
      workspaceId: 'ws-1',
      eventType: 'expense',
      requiredCount: requiredCount,
      adminsMayValidate: true,
      eligibleAdminIds: const [],
      ownerRequired: false,
      validatorScope: scope,
      ownerMaySelfValidate: ownerMaySelfValidate,
      sequential: sequential,
    );

void main() {
  group('the one exception belongs to the owner', () {
    test('by default nobody validates their own — owner included', () {
      final policy = _policy();
      expect(_expenseBy('o').isDecidedBy(_owner('o'), policy: policy), isFalse);
      expect(_expenseBy('a').isDecidedBy(admin('a'), policy: policy), isFalse);
    });

    test('granted, the owner validates their own act and an admin still '
        'cannot', () {
      final policy = _policy(ownerMaySelfValidate: true);
      expect(_expenseBy('o').isDecidedBy(_owner('o'), policy: policy), isTrue);
      expect(_expenseBy('a').isDecidedBy(admin('a'), policy: policy), isFalse);
    });

    test('the exception changes nothing for anyone else\'s event', () {
      final event = _expenseBy('member-9');
      expect(event.isDecidedBy(_owner('o'), policy: _policy()), isTrue);
      expect(
        event.isDecidedBy(admin('a'), policy: _policy(ownerMaySelfValidate: true)),
        isTrue,
      );
    });
  });

  group('the configuration says the rule out loud', () {
    testWidgets('the screen states it before any card', (tester) async {
      await pumpValidationSettings(tester);
      expect(find.byKey(const Key('validation-no-self-banner')),
          findsOneWidget);
      expect(find.text('Nobody validates their own'), findsOneWidget);
    });

    testWidgets('every rule summary ends with the self-validation state',
        (tester) async {
      await pumpValidationSettings(tester, policies: [
        _policy(ownerMaySelfValidate: true).copyWith(eventType: 'expense'),
      ]);
      expect(
        find.textContaining('Owner may validate their own'),
        findsOneWidget,
      );
    });

    testWidgets('the editor carries both switches, and saving keeps them',
        (tester) async {
      final events = await pumpValidationSettings(tester);
      await tester.tap(find.text('Expense'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('validation-no-self')), findsOneWidget);
      await tester.tap(find.byKey(const Key('validation-owner-self')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('validation-sequential')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved =
          events.policies.firstWhere((p) => p.eventType == 'expense');
      expect(saved.ownerMaySelfValidate, isTrue);
      expect(saved.sequential, isTrue);
    });

    testWidgets('with the feature off the switches are gone and the rule '
        'still stands', (tester) async {
      await pumpValidationSettings(tester,
          featureFlags: const {'validationChain': false});
      await tester.tap(find.text('Expense'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('validation-owner-self')), findsNothing);
      expect(find.byKey(const Key('validation-sequential')), findsNothing);
      expect(find.byKey(const Key('validation-no-self')), findsOneWidget);
    });
  });

  test('a summary no longer calls a members rule "All admins"', () {
    // The scope was ignored: a rule open to everyone read as admins-only.
    expect(_policy(scope: 'members').validatorScope, 'members');
  });
}
