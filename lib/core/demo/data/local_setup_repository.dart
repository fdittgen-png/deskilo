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
}
