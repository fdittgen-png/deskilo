// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/workspace/domain/local_setup.dart';
import '../../../features/workspace/domain/setup_status.dart';
import '../../../features/workspace/domain/setup_step_draft.dart';
import '../../../features/workspace/domain/workspace_readiness.dart';
import 'fixture_clock.dart';

/// #1656 — local needs for tests and Demo (where nothing is missing).
class FakeLocalSetupRepository implements LocalSetupRepository {
  FakeLocalSetupRepository({
    this.needs = const {},
    this.missing = const [],
    this.readinessSections = const [],
    this.status = const SetupStatus(),
    Map<String, SetupStatus> statuses = const {},
  }) : statuses = {...statuses};
  final Map<String, List<LocalSlot>> needs;
  List<LocalSlot> missing;

  /// #1636 — what [sections] answers; empty in Demo (nothing to report).
  List<ReadinessSection> readinessSections;

  /// #2869 — what [setupStatus] answers.
  SetupStatus status;

  /// #2872 — each demo space's own status; [status] for any other.
  final Map<String, SetupStatus> statuses;

  /// 0545 — every step call, as `ack:<step>` or `clear:<step>`.
  final List<String> stepCalls = [];

  /// #2869 — the drafts by `<workspace>/<step>`, as the server keeps them:
  /// a discarded one stays without answers and keeps its version counting.
  final Map<String, _DraftRow> _drafts = {};

  /// #2869 — every save's request id, in order.
  final List<String> draftSaveRequests = [];

  /// #2869 — the next saves that fail: each one is stored first when
  /// [draftAnswerLost] (the answer was lost on the way back), else not.
  int failDraftSaves = 0;
  bool draftAnswerLost = false;

  @override
  Future<SetupStepDraft?> stepDraft(String workspaceId, String step) async {
    final row = _drafts['$workspaceId/$step'];
    final payload = row?.payload;
    if (row == null || payload == null) return null;
    return SetupStepDraft(
      payload: {...payload},
      version: row.version,
      updatedAt: row.updatedAt,
    );
  }

  @override
  Future<SetupDraftWrite> saveStepDraft(
    String workspaceId,
    String step, {
    required Map<String, Object?> payload,
    required int? expectedVersion,
    required String requestId,
  }) async {
    draftSaveRequests.add(requestId);
    final failing = failDraftSaves > 0;
    if (failing) failDraftSaves--;
    if (failing && !draftAnswerLost) throw StateError('offline');
    final saved = _storeDraft(
      '$workspaceId/$step',
      payload,
      expectedVersion: expectedVersion,
      requestId: requestId,
    );
    if (failing) throw StateError('the answer was lost');
    return saved;
  }

  /// Like save_setup_step_draft: idempotent per request, refused when the
  /// stored version is not the one the write was made against.
  SetupDraftWrite _storeDraft(
    String key,
    Map<String, Object?> payload, {
    required int? expectedVersion,
    required String requestId,
  }) {
    final row = _drafts[key];
    if (row != null && row.lastRequestId == requestId) {
      return SetupDraftWrite(version: row.version, updatedAt: row.updatedAt);
    }
    final live = row?.payload == null ? null : row!.version;
    if (live != expectedVersion) {
      throw SetupDraftConflict(
        '${SetupDraftConflict.messagePrefix} $key is at version $live',
      );
    }
    final next = _DraftRow(
      payload: {...payload},
      version: (row?.version ?? 0) + 1,
      updatedAt: kTestNow,
      lastRequestId: requestId,
    );
    _drafts[key] = next;
    return SetupDraftWrite(version: next.version, updatedAt: next.updatedAt);
  }

  @override
  Future<bool> discardStepDraft(
    String workspaceId,
    String step, {
    required int? expectedVersion,
  }) async {
    final key = '$workspaceId/$step';
    final row = _drafts[key];
    if (row == null || row.payload == null) return false;
    if (row.version != expectedVersion) {
      throw SetupDraftConflict(
        '${SetupDraftConflict.messagePrefix} $key is at version ${row.version}',
      );
    }
    _drafts[key] = _DraftRow(
      payload: null,
      version: row.version + 1,
      updatedAt: kTestNow,
    );
    return true;
  }

  @override
  Future<void> acknowledgeStep(String workspaceId, String step) async {
    stepCalls.add('ack:$step');
    _markStep(workspaceId, step, (s) => s.manual
        ? SetupStepState.ready
        : SetupStepState.deferred);
  }

  @override
  Future<void> clearStepAcknowledgement(String workspaceId, String step) async {
    stepCalls.add('clear:$step');
    _markStep(workspaceId, step, (_) => SetupStepState.needsConfiguration);
  }

  /// Like the server: the step's state follows the acknowledgement.
  void _markStep(String workspaceId, String step,
      SetupStepState Function(SetupStepStatus) state) {
    final before = statuses[workspaceId] ?? status;
    final after = SetupStatus(
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
    if (statuses.containsKey(workspaceId)) {
      statuses[workspaceId] = after;
    } else {
      status = after;
    }
  }

  @override
  Future<SetupStatus> setupStatus(String workspaceId) async =>
      statuses[workspaceId] ?? status;

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

/// #2869 — one stored draft of [FakeLocalSetupRepository].
class _DraftRow {
  const _DraftRow({
    required this.payload,
    required this.version,
    required this.updatedAt,
    this.lastRequestId,
  });

  /// Null once discarded.
  final Map<String, Object?>? payload;
  final int version;
  final DateTime updatedAt;
  final String? lastRequestId;
}
