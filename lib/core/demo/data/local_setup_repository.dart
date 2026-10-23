// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/workspace/domain/local_setup.dart';
import '../../../features/workspace/domain/setup_status.dart';
import '../../../features/workspace/domain/workspace_readiness.dart';

/// #1656 — local needs for tests and Demo (where nothing is missing).
class FakeLocalSetupRepository implements LocalSetupRepository {
  FakeLocalSetupRepository({
    this.needs = const {},
    this.missing = const [],
    this.readinessSections = const [],
    this.status = const SetupStatus(),
  });
  final Map<String, List<LocalSlot>> needs;
  List<LocalSlot> missing;

  /// #1636 — what [sections] answers; empty in Demo (nothing to report).
  List<ReadinessSection> readinessSections;

  /// #2869 — what [setupStatus] answers.
  SetupStatus status;

  /// 0545 — every step call, as `ack:<step>` or `clear:<step>`.
  final List<String> stepCalls = [];

  @override
  Future<void> acknowledgeStep(String workspaceId, String step) async {
    stepCalls.add('ack:$step');
    _markStep(step, (s) => s.manual
        ? SetupStepState.ready
        : SetupStepState.deferred);
  }

  @override
  Future<void> clearStepAcknowledgement(String workspaceId, String step) async {
    stepCalls.add('clear:$step');
    _markStep(step, (_) => SetupStepState.needsConfiguration);
  }

  /// Like the server: the step's state follows the acknowledgement.
  void _markStep(String step, SetupStepState Function(SetupStepStatus) state) {
    final before = status;
    status = SetupStatus(
      milestones: before.milestones,
      steps: [
        for (final s in before.steps)
          if (s.step == step)
            SetupStepStatus(
              step: s.step,
              milestone: s.milestone,
              required: s.required,
              state: state(s),
              route: s.route,
              blockedBy: s.blockedBy,
              manual: s.manual,
              estimateMinutes: s.estimateMinutes,
            )
          else
            s,
      ],
    );
  }

  @override
  Future<SetupStatus> setupStatus(String workspaceId) async => status;

  @override
  Future<List<LocalSlot>> templateNeeds(String templateId) async =>
      needs[templateId] ?? const [];

  @override
  Future<List<LocalSlot>> readiness(String workspaceId) async => missing;

  @override
  Future<List<ReadinessSection>> sections(String workspaceId) async =>
      readinessSections;

  /// 0307 — every call, as `ack:<section>` or `clear:<section>`.
  final List<String> acknowledgementCalls = [];

  @override
  Future<void> acknowledgeSection(String workspaceId, String section) async {
    acknowledgementCalls.add('ack:$section');
    _mark(section, acknowledged: true);
  }

  @override
  Future<void> clearAcknowledgement(String workspaceId, String section) async {
    acknowledgementCalls.add('clear:$section');
    _mark(section, acknowledged: false);
  }

  void _mark(String section, {required bool acknowledged}) {
    readinessSections = [
      for (final s in readinessSections)
        if (readinessSectionCode(s.area) == section)
          ReadinessSection(
            area: s.area,
            state: s.state,
            required: s.required,
            route: s.route,
            actor: s.actor,
            reason: s.reason,
            recordedAt: s.recordedAt,
            acknowledged: acknowledged,
          )
        else
          s,
    ];
  }
}
