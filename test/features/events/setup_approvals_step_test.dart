// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2871 — the approvals step of the setup guide. The count is prefilled
// from the stored default rule; the flow names who approves (the owner
// and the active administrators, counted as the server counts them) and
// the preview says how many approvals a member's request waits for, both
// following the count before anything is saved. Applying stores the
// default rule; a count above the people who can approve says why and
// cannot be saved. One column on a phone.
import 'package:deskilo/app/routes/setup_run_pages.dart';
import 'package:deskilo/features/events/domain/validation_policy.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_step_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_event_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _phone = Size(360, 2400);

Member _member(String id, {bool admin = false, MemberStatus? status}) => Member(
  id: id,
  workspaceId: 'ws-1',
  userId: 'user-$id',
  isAdmin: admin,
  isOwner: false,
  status: status ?? MemberStatus.active,
);

/// The owner, one active administrator, one administrator who left and
/// one member: two people can approve.
FakeWorkspaceRepository _repo() => FakeWorkspaceRepository.withWorkspace()
  ..otherMembers.addAll([
    _member('admin-1', admin: true),
    _member('admin-gone', admin: true, status: MemberStatus.exited),
    _member('member-2'),
  ]);

Future<void> _pump(WidgetTester tester, FakeEventRepository events) async {
  await pumpApp(
    tester,
    const SetupStepScreen(stepId: 'approvals', runPages: setupRunPages),
    size: _phone,
    overrides: standardTestOverrides(workspace: _repo(), events: events),
  );
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

String _subtitle(WidgetTester tester, String key) =>
    (tester
                .widget<ListTile>(
                  find.descendant(
                    of: find.byKey(ValueKey(key)),
                    matching: find.byType(ListTile),
                  ),
                )
                .subtitle!
            as Text)
        .data!;

Future<void> _increase(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('setup-approvals-increase')));
  await tester.pump();
}

void main() {
  testWidgets('prefilled from the stored default rule; the flow names who '
      'approves', (tester) async {
    final events = FakeEventRepository()
      ..policies.add(
        const ValidationPolicy(
          id: 'p-default',
          workspaceId: 'ws-1',
          requiredCount: 2,
          adminsMayValidate: true,
          eligibleAdminIds: [],
          ownerRequired: false,
        ),
      );
    await _pump(tester, events);
    expect(_text(tester, 'setup-approvals-count'), '2');
    expect(_text(tester, 'setup-approvals-people'), '2 people can approve.');
    expect(
      _subtitle(tester, 'setup-approvals-flow-validators'),
      'The owner and 1 administrator',
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('setup-approvals-flow-validators')),
        matching: find.text('2 of 2 approve'),
      ),
      findsOneWidget,
    );
    expect(
      _text(tester, 'setup-approvals-preview-waiting'),
      'Waiting for 2 approvals',
    );
    expect(
      find.byKey(const ValueKey('setup-approvals-preview-sent')),
      findsOneWidget,
    );
  });

  testWidgets('applying stores the default rule with the chosen count', (
    tester,
  ) async {
    final events = FakeEventRepository();
    await _pump(tester, events);
    expect(_text(tester, 'setup-approvals-count'), '1');
    await _increase(tester);
    expect(
      _text(tester, 'setup-approvals-preview-waiting'),
      'Waiting for 2 approvals',
    );
    expect(events.policies, isEmpty, reason: 'nothing saved yet');

    await tester.tap(find.byKey(const ValueKey('setup-approvals-apply')));
    await tester.pumpAndSettle();
    final rule = events.policies.single;
    expect(rule.eventType, isNull);
    expect(rule.requiredCount, 2);
    expect(rule.validatorScope, 'admins');
    expect(rule.adminsMayValidate, isTrue);
  });

  testWidgets('more approvals than people: it says why and cannot be saved', (
    tester,
  ) async {
    final events = FakeEventRepository();
    await _pump(tester, events);
    await _increase(tester);
    expect(
      find.byKey(const ValueKey('setup-approvals-too-many')),
      findsNothing,
    );
    await _increase(tester);
    expect(_text(tester, 'setup-approvals-count'), '3');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('setup-approvals-too-many')),
        matching: find.textContaining('only 2 people can approve'),
      ),
      findsOneWidget,
    );
    final apply = find.byKey(const ValueKey('setup-approvals-apply'));
    expect(tester.widget<FilledButton>(apply).onPressed, isNull);
    await tester.tap(apply, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(events.policies, isEmpty);
  });

  testWidgets('one column on a phone', (tester) async {
    await _pump(tester, FakeEventRepository());
    expect(find.byKey(const ValueKey('setup-step-one-column')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
