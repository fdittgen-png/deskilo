// SPDX-License-Identifier: 0BSD
//
// #848 — a chained rule (#840) asks for one particular validation, and
// the server writes which one into the event's payload each time an
// accept lands. Until now nothing read it: the flag's only visible
// effect was the wording of the trail. The feed now says which step is
// open, which is the question a validator actually has.
import 'package:deskilo/features/events/domain/event_decision.dart';
import 'package:deskilo/features/events/domain/validation_policy.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_event_repository.dart';
import '../../helpers/mock_providers.dart';
import 'events_screen_test.dart' show pumpEvents;

ValidationPolicy _policy({required bool sequential, int required = 3}) =>
    ValidationPolicy(
      id: 'p1',
      workspaceId: 'ws-1',
      eventType: 'expense',
      requiredCount: required,
      adminsMayValidate: true,
      eligibleAdminIds: const [],
      ownerRequired: false,
      sequential: sequential,
    );

WorkspaceEvent _event({
  Map<String, dynamic> extraPayload = const {},
  EventStatus status = EventStatus.pending,
}) =>
    WorkspaceEvent(
      id: 'evt-1',
      workspaceId: 'ws-1',
      type: EventType.expense,
      action: EventAction.submitted,
      actorMemberId: 'member-9',
      subjectMemberId: 'member-9',
      payload: {'amount_cents': 1200, ...extraPayload},
      status: status,
      createdAt: kTestNow,
    );

Future<FakeEventRepository> _pump(
  WidgetTester tester, {
  required bool sequential,
  Map<String, dynamic> extraPayload = const {},
  int decided = 0,
  EventStatus status = EventStatus.pending,
}) async {
  return pumpEvents(
    tester,
    seed: [_event(extraPayload: extraPayload, status: status)],
    policies: [_policy(sequential: sequential)],
    decisions: [
      for (var i = 0; i < decided; i++)
        EventDecision(
          id: 'dec-$i',
          eventId: 'evt-1',
          memberId: 'member-${i + 2}',
          accept: true,
          decidedBySystem: false,
          decidedAt: kTestNow,
        ),
    ],
  );
}

void main() {
  testWidgets('an open quorum still counts what it has', (tester) async {
    await _pump(tester, sequential: false, decided: 1);
    expect(find.textContaining('1/3 validations'), findsWidgets);
    expect(find.textContaining('requested'), findsNothing);
  });

  testWidgets('a chained rule names the step the server is asking for',
      (tester) async {
    await _pump(tester,
        sequential: true,
        decided: 1,
        extraPayload: const {'validation_stage': 2});
    expect(find.textContaining('Validation 2 of 3 requested'), findsWidgets);
    expect(find.textContaining('1/3 validations'), findsNothing);
  });

  testWidgets('an event that never got the marker falls back to the '
      'accepts in hand', (tester) async {
    // A rule switched to chained mid-flight: nothing wrote a stage.
    await _pump(tester, sequential: true, decided: 1);
    expect(find.textContaining('Validation 2 of 3 requested'), findsWidgets);
  });

  testWidgets('a stage past the end is clamped, never printed as such',
      (tester) async {
    await _pump(tester,
        sequential: true,
        decided: 2,
        extraPayload: const {'validation_stage': 9});
    expect(find.textContaining('Validation 3 of 3 requested'), findsWidgets);
  });

  testWidgets('a decided event says nothing about steps', (tester) async {
    await _pump(tester,
        sequential: true,
        decided: 3,
        status: EventStatus.confirmed,
        extraPayload: const {'validation_stage': 4});
    expect(find.textContaining('requested'), findsNothing);
  });
}
