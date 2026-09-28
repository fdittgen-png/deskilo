// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/workspace/domain/workspace_application.dart';

class FakeWorkspaceApplicationRepository
    implements WorkspaceApplicationRepository {
  final applications = <WorkspaceApplication>[];
  final messages = <String, List<ApplicationMessage>>{};
  final sent = <({String id, String body})>[];
  bool failSend = false;
  bool _before(ApplicationCursor item, ApplicationCursor? before) =>
      before == null ||
      item.at.isBefore(before.at) ||
      (item.at == before.at && item.id.compareTo(before.id) < 0);
  @override
  Future<List<WorkspaceApplication>> list({ApplicationCursor? before}) async =>
      applications
          .where((item) => _before(item.cursor, before))
          .take(50)
          .toList();
  @override
  Future<List<ApplicationMessage>> thread(
    String id, {
    ApplicationCursor? before,
  }) async => (messages[id] ?? [])
      .where((item) => _before(item.cursor, before))
      .take(50)
      .toList();
  @override
  Future<void> send(
    String id,
    String body, {
    required String expectedAccount,
  }) async {
    if (failSend) throw StateError('offline');
    sent.add((id: id, body: body));
  }
}
