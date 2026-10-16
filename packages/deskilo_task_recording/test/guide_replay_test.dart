// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2593 C2 - guide state machine, recovery ordering, the replay seam and the
// capture policy, used by a host that is not Deskilo (the inspection
// checklist): a recording or a guide is never a permission.

import 'package:deskilo_task_recording/deskilo_task_recording.dart';
import 'package:test/test.dart';

import '../example/inspection_checklist.dart';

TaskGuide _guide() => TaskGuide(
  actionContractVersion: 1,
  steps: [
    const GuideStep(id: 'g1', kind: GuideStepKind.instruction, text: 'Read.'),
    const GuideStep(
      id: 'g2',
      kind: GuideStepKind.perform,
      action: Inspection.check,
    ),
    GuideStep(
      id: 'g3',
      kind: GuideStepKind.perform,
      action: Inspection.submit,
      expectedOutcomes: const {Inspection.reportFiled},
      recovery: const [
        GuideStep(id: 'g3r1', kind: GuideStepKind.instruction, text: 'Fix.'),
      ],
    ),
  ],
);

GuideRun _run() => GuideRun(_guide(), registry: inspectionCatalogue());

/// The host the authorizer stands for: where we are, who may do what.
class _Host implements ReplayAuthorizer {
  ReplayScope? scope = const ReplayScope('site-a');
  ReplayDecision decision = const ReplayDecision.allowed();
  int asked = 0;

  @override
  ReplayScope? currentScope() => scope;

  @override
  ReplayDecision authorizeNow(ReplayRequest request, ReplayScope scope) {
    asked++;
    return decision;
  }
}

class _Executor implements ActionExecutor {
  _Executor(this.answer);
  final Future<ReplayExecution> Function() answer;
  int ran = 0;

  @override
  Future<ReplayExecution> execute(
    ReplayRequest request,
    ReplayScope scope,
    ReplayDecision decision,
  ) {
    ran++;
    return answer();
  }
}

const _filed = ReplayExecution(
  outcome: Inspection.reportFiled,
  state: ObservationState.confirmed,
);
const _submit = ReplayRequest(action: Inspection.submit);

void main() {
  group('guide state machine and recovery ordering', () {
    test(
      'a command waits for its real outcome; a tap alone completes nothing',
      () {
        final run = _run()..acknowledge();
        run.onAction(Inspection.check);
        expect(run.current!.id, 'g3');
        final token = run.onAction(Inspection.submit);
        expect(run.statusOf('g3'), GuideStepStatus.waiting);
        run.onOutcome(Inspection.reportFiled, token: token);
        expect(run.state, GuideRunState.completed);
      },
    );

    test('a refusal enters the recovery, then returns to the same step', () {
      final run = _run()..acknowledge();
      run.onAction(Inspection.check);
      var token = run.onAction(Inspection.submit);
      run.onOutcome(Inspection.reportRefused, token: token);
      expect(run.current!.id, 'g3r1');
      run.acknowledge();
      expect(run.current!.id, 'g3');
      token = run.onAction(Inspection.submit);
      run.onOutcome(Inspection.reportFiled, token: token);
      expect(run.state, GuideRunState.completed);
    });

    test('a pause never assumes a waiting command happened', () {
      final run = _run()..acknowledge();
      run.onAction(Inspection.check);
      final token = run.onAction(Inspection.submit);
      run
        ..pause()
        ..resume();
      expect(run.statusOf('g3'), GuideStepStatus.pending);
      expect(run.uncertain, isTrue);
      run.onOutcome(Inspection.reportFiled, token: token);
      expect(run.state, GuideRunState.running, reason: 'an old answer');
    });

    test(
      'abandonAttempt: the late answer of another scope completes nothing',
      () {
        final run = _run()..acknowledge();
        run.onAction(Inspection.check);
        expect(run.wouldAttemptCommand(Inspection.submit), isTrue);
        final token = run.onAction(Inspection.submit);
        run.abandonAttempt();
        run.onOutcome(Inspection.reportFiled, token: token);
        expect(run.statusOf('g3'), GuideStepStatus.pending);
        expect(run.uncertain, isTrue);
      },
    );
  });

  group('replay is never a permission', () {
    late _Host host;
    late ReplayCoordinator coordinator;
    const a = ReplayScope('site-a');

    ReplayCoordinator make({ActionExecutor? executor}) => ReplayCoordinator(
      registry: inspectionCatalogue(),
      authorizer: host,
      executor: executor,
    );

    setUp(() {
      host = _Host();
      coordinator = make();
    });

    test(
      'an unknown action or a newer version is refused, never registered',
      () {
        expect(
          coordinator
              .begin(const ReplayRequest(action: 'x.unknown'), startedIn: a)
              .reason,
          ReplayRefusal.unknownAction,
        );
        expect(
          coordinator
              .begin(
                const ReplayRequest(action: Inspection.check, actionVersion: 9),
                startedIn: a,
              )
              .reason,
          ReplayRefusal.unknownVersion,
        );
        expect(host.asked, 0, reason: 'the host is not even asked');
      },
    );

    test('no scope, or another scope than the one started in, is refused', () {
      host.scope = null;
      expect(
        coordinator.begin(_submit, startedIn: a).reason,
        ReplayRefusal.noScope,
      );
      host.scope = const ReplayScope('site-b');
      expect(
        coordinator.begin(_submit, startedIn: a).reason,
        ReplayRefusal.scopeChanged,
      );
    });

    test('the host is asked every time: a role that changed refuses', () {
      expect(coordinator.begin(_submit, startedIn: a).started, isTrue);
      host.decision = const ReplayDecision.refused();
      final again = coordinator.begin(_submit, startedIn: a);
      expect(again.started, isFalse);
      expect(again.reason, ReplayRefusal.notAllowed);
      expect(host.asked, 2);
    });

    test('a price that changed asks the existing confirmation first', () async {
      final executor = _Executor(() async => _filed);
      coordinator = make(executor: executor);
      host.decision = const ReplayDecision.needsConfirmation();
      final asked = await coordinator.replay(_submit, startedIn: a);
      expect(asked.status, ReplayStatus.needsConfirmation);
      expect(executor.ran, 0);
      final confirmed = await coordinator.replay(
        _submit,
        startedIn: a,
        confirmed: true,
      );
      expect(confirmed.status, ReplayStatus.executed);
      expect(confirmed.execution!.outcome, Inspection.reportFiled);
      expect(host.asked, 2, reason: 'confirming re-authorises');
    });

    test(
      'an unknown outcome is recorded and the command is not repeated',
      () async {
        final executor = _Executor(() async => throw StateError('timeout'));
        coordinator = make(executor: executor);
        final first = await coordinator.replay(_submit, startedIn: a);
        expect(first.execution, isNull);
        final second = await coordinator.replay(_submit, startedIn: a);
        expect(second.status, ReplayStatus.refused);
        expect(second.reason, ReplayRefusal.unknownOutcomePending);
        expect(executor.ran, 1);
        coordinator.clearUnknown(_submit, a);
        expect(
          (await coordinator.replay(_submit, startedIn: a)).status,
          ReplayStatus.executed,
        );
      },
    );

    test(
      'a scope change mid-command leaves the answer with the scope it was asked in',
      () async {
        final executor = _Executor(() async {
          host.scope = const ReplayScope('site-b');
          return _filed;
        });
        coordinator = make(executor: executor);
        final result = await coordinator.replay(_submit, startedIn: a);
        expect(result.scope, a);
        expect(result.scopeChangedDuring, isTrue);
      },
    );

    test('a recorded step becomes a request only when it is an action', () {
      final action = RecordedStep(
        seq: 1,
        segment: 0,
        elapsedMs: 0,
        kind: StepKind.action,
        surface: Inspection.screen,
        action: Inspection.check,
        actionVersion: 1,
      );
      expect(ReplayRequest.fromStep(action)!.action, Inspection.check);
      final note = RecordedStep(
        seq: 2,
        segment: 0,
        elapsedMs: 0,
        kind: StepKind.annotation,
        surface: Inspection.screen,
      );
      expect(ReplayRequest.fromStep(note), isNull);
    });
  });

  group('capture policy minimizes before anything is stored', () {
    final policy = CataloguePolicy(
      inspectionCatalogue(),
      protectedSurfaces: const {'inspection.vault': ProtectedSurface.secrets},
    );

    test('canaries become the placeholder or vanish', () {
      const canary = 'CANARY-password-7f3a91';
      final p = policy.minimize(Inspection.check, {
        'verdict': canary,
        'password': canary,
        'note': canary,
      });
      expect(p.values, {'verdict': withheldValue});
      expect(p.toJson().toString(), isNot(contains('CANARY')));
      expect(policy.minimize('x.unknown', {'verdict': 'pass'}).isEmpty, isTrue);
    });

    test('a protected surface reports its category only', () {
      expect(
        policy.protectedCategory('inspection.vault'),
        ProtectedSurface.secrets,
      );
      expect(policy.protectedCategory(Inspection.screen), isNull);
    });
  });
}
