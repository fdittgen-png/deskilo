// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/workspace/domain/local_setup.dart';
import '../../../features/workspace/domain/workspace_readiness.dart';

/// #1656 — local needs for tests and Demo (where nothing is missing).
class FakeLocalSetupRepository implements LocalSetupRepository {
  FakeLocalSetupRepository({
    this.needs = const {},
    this.missing = const [],
    this.readinessSections = const [],
  });
  final Map<String, List<LocalSlot>> needs;
  List<LocalSlot> missing;

  /// #1636 — what [sections] answers; empty in Demo (nothing to report).
  List<ReadinessSection> readinessSections;

  @override
  Future<List<LocalSlot>> templateNeeds(String templateId) async =>
      needs[templateId] ?? const [];

  @override
  Future<List<LocalSlot>> readiness(String workspaceId) async => missing;

  @override
  Future<List<ReadinessSection>> sections(String workspaceId) async =>
      readinessSections;

  /// 0303 — every call, as `ack:<section>` or `clear:<section>`.
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
