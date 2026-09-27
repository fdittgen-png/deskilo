// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/workspace/domain/local_setup.dart';

/// #1656 — local needs for tests and Demo (where nothing is missing).
class FakeLocalSetupRepository implements LocalSetupRepository {
  FakeLocalSetupRepository({this.needs = const {}, this.missing = const []});
  final Map<String, List<LocalSlot>> needs;
  List<LocalSlot> missing;

  @override
  Future<List<LocalSlot>> templateNeeds(String templateId) async =>
      needs[templateId] ?? const [];

  @override
  Future<List<LocalSlot>> readiness(String workspaceId) async => missing;
}
