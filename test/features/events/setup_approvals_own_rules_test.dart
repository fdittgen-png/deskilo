// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2871 — the approvals step lists the rules a request type has of its
// own, each with how many approvals it waits for and how many people can
// give them. A rule asking for more is called out with why its requests
// are never decided; the step opens the rule editor to change it and
// edits nothing itself. Without a rule of their own, every request
// follows the default rule.
import 'package:deskilo/app/routes/setup_run_pages.dart';
import 'package:deskilo/features/events/domain/validation_policy.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_step_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_event_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/pump_app.dart';

const _phone = Size(360, 2400);

/// The owner and one active administrator: two people can approve under
/// the administrators' scope.
FakeWorkspaceRepository _repo() =>
    FakeWorkspaceRepository.withWorkspace()
      ..otherMembers.add(
        const Member(
          id: 'admin-1',
          workspaceId: 'ws-1',
          userId: 'user-admin-1',
          isAdmin: true,
          isOwner: false,
          status: MemberStatus.active,
        ),
      );

ValidationPolicy _rule(String type, int required) => ValidationPolicy(
  id: 'p-$type',
  workspaceId: 'ws-1',
  eventType: type,
  requiredCount: required,
  adminsMayValidate: true,
  eligibleAdminIds: const [],
  ownerRequired: false,
);

Widget get _page =>
    const SetupStepScreen(stepId: 'approvals', runPages: setupRunPages);

Future<void> _pump(WidgetTester tester, FakeEventRepository events) async {
  await pumpApp(
    tester,
    _page,
    size: _phone,
    overrides: standardTestOverrides(workspace: _repo(), events: events),
  );
  await tester.pumpAndSettle();
}

String _subtitle(WidgetTester tester, String type) =>
    (tester
                .widget<ListTile>(
                  find.byKey(ValueKey('setup-approvals-rule-$type')),
                )
                .subtitle!
            as Text)
        .data!;

void main() {
  testWidgets('no rule of their own: every request follows the default', (
    tester,
  ) async {
    await _pump(tester, FakeEventRepository());
    expect(
      find.byKey(const ValueKey('setup-approvals-own-rules-none')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('setup-approvals-own-rules-short')),
      findsNothing,
    );
  });

  testWidgets('each rule with its reach; a short one is called out and '
      'nothing is edited here', (tester) async {
    final events = FakeEventRepository()
      ..policies.addAll([_rule('payment', 3), _rule('expense', 2)]);
    await _pump(tester, events);
    expect(
      _subtitle(tester, 'payment'),
      '3 approvals, but only 2 people can approve',
    );
    expect(_subtitle(tester, 'expense'), '2 approvals, 2 people can approve');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('setup-approvals-own-rules-short')),
        matching: find.textContaining('One rule asks for more approvals'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('setup-approvals-own-rules-none')),
      findsNothing,
    );
    expect(events.policies.map((p) => p.requiredCount), [3, 2]);
  });

  testWidgets('the rule editor opens from the step', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => _page),
        GoRoute(
          path: '/validation',
          builder: (_, _) => const Text('approval rules screen'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await pumpApp(
      tester,
      null,
      router: router,
      size: _phone,
      overrides: standardTestOverrides(
        workspace: _repo(),
        events: FakeEventRepository()..policies.add(_rule('payment', 3)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('setup-approvals-open-rules')));
    await tester.pumpAndSettle();
    expect(find.text('approval rules screen'), findsOneWidget);
  });
}
