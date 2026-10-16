// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2593 C2 - a guide is not a permission. A booking guide started while the
// person could book in workspace A asks again, now, before its command step
// is attempted: a lost membership, a lost staff right or a feature turned off
// refuses the attempt (the step stays open, the app's own command still
// answers for itself), and an answer that comes back after the workspace
// changed is never attributed to the new workspace.
import 'package:deskilo/features/task_recorder/domain/action_registry.dart';
import 'package:deskilo/features/task_recorder/guide/guide_replay.dart';
import 'package:deskilo/features/task_recorder/guide/guide_runner.dart';
import 'package:deskilo/features/task_recorder/guide/guide_session.dart';
import 'package:deskilo/features/task_recorder/guide/task_guide.dart';
import 'package:deskilo/features/task_recorder/providers/recorder_providers.dart';
import 'package:deskilo_task_recording/deskilo_task_recording.dart'
    show ReplayRefusal, ReplayRequest, ReplayVerdict;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/recording_fixtures.dart';

class _Facts extends Notifier<GuideReplayFacts?> {
  @override
  GuideReplayFacts? build() => _facts();
  void set(GuideReplayFacts? next) => state = next;
}

final _factsProvider = NotifierProvider<_Facts, GuideReplayFacts?>(_Facts.new);

GuideReplayFacts _facts({
  String workspace = 'ws-a',
  bool member = true,
  bool staff = false,
  bool feature = true,
}) => GuideReplayFacts(
  accountDigest: canaryScope.digest,
  workspaceId: workspace,
  featureOn: feature,
  activeMember: member,
  actsForReservations: staff,
);

TaskGuide _bookingGuide() => TaskGuide(
  actionContractVersion: actionContractVersion,
  steps: [
    const GuideStep(
      id: 'g1',
      kind: GuideStepKind.perform,
      action: RecorderActions.confirmBooking,
      destination: '/reserve',
      expectedOutcomes: {RecorderOutcomes.bookingConfirmed},
    ),
  ],
);

void main() {
  test('a booking recorded for another member needs the staff right today', () {
    GuideReplayFacts? facts = _facts();
    final authorizer = DeskiloReplayAuthorizer(() => facts);
    const other = ReplayRequest(
      action: RecorderActions.confirmBooking,
      payload: {'for_whom': 'other_member'},
    );
    final scope = authorizer.currentScope()!;
    expect(
      authorizer.authorizeNow(other, scope).verdict,
      ReplayVerdict.refused,
    );
    facts = _facts(staff: true);
    expect(
      authorizer.authorizeNow(other, scope).verdict,
      ReplayVerdict.allowed,
    );
    facts = _facts(workspace: 'ws-b', staff: true);
    expect(
      authorizer.authorizeNow(other, scope).reason,
      ReplayRefusal.scopeChanged,
    );
  });

  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: [
        recorderScopeProvider.overrideWithValue(canaryScope),
        taskRecorderAvailableProvider.overrideWith((ref) => true),
        guideReplayFactsProvider.overrideWith(
          (ref) => ref.watch(_factsProvider),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  GuideSession start(ProviderContainer c) {
    final session = c.read(guideSessionProvider.notifier);
    expect(session.start(_bookingGuide()), isTrue);
    return session;
  }

  test('the same person in the same workspace is allowed', () {
    final c = make();
    final session = start(c);
    final token = session.action(RecorderActions.confirmBooking);
    expect(token, isNotNull);
    session.outcome(RecorderOutcomes.bookingConfirmed, token: token);
    expect(c.read(guideSessionProvider).run!.state, GuideRunState.completed);
  });

  for (final entry in <String, GuideReplayFacts>{
    'membership lost': _facts(member: false),
    'feature turned off': _facts(feature: false),
  }.entries) {
    test('${entry.key}: the attempt is refused and the step stays open', () {
      final c = make();
      final session = start(c);
      c.read(_factsProvider.notifier).set(entry.value);
      expect(session.action(RecorderActions.confirmBooking), isNull);
      final state = c.read(guideSessionProvider);
      expect(state.refusal, ReplayRefusal.notAllowed);
      expect(state.run!.statusOf('g1'), GuideStepStatus.pending);
    });
  }

  test('signed out there is no scope to ask in', () {
    final c = make();
    final session = start(c);
    c.read(_factsProvider.notifier).set(null);
    expect(session.action(RecorderActions.confirmBooking), isNull);
    expect(c.read(guideSessionProvider).refusal, ReplayRefusal.noScope);
  });

  test('an answer that comes back in another workspace completes nothing', () {
    final c = make();
    final session = start(c);
    final token = session.action(RecorderActions.confirmBooking);
    expect(token, isNotNull);
    c.read(_factsProvider.notifier).set(_facts(workspace: 'ws-b'));
    session.outcome(RecorderOutcomes.bookingConfirmed, token: token);
    final run = c.read(guideSessionProvider).run!;
    expect(run.statusOf('g1'), GuideStepStatus.pending);
    expect(run.uncertain, isTrue);
    expect(run.state, GuideRunState.running);
    // Asking again in the new workspace is a new attempt, authorised there.
    final again = session.action(RecorderActions.confirmBooking);
    expect(again, isNotNull);
    session.outcome(RecorderOutcomes.bookingConfirmed, token: again);
    expect(c.read(guideSessionProvider).run!.state, GuideRunState.completed);
  });
}
