// SPDX-License-Identifier: AGPL-3.0-or-later
import '../domain/workspace_application.dart';

class ApplicationReplies {
  const ApplicationReplies(this.repository);
  final WorkspaceApplicationRepository repository;
  Future<void> send(String id, String body, {required String expectedAccount}) {
    final text = body.trim();
    if (text.isEmpty || text.length > 4000) {
      throw ArgumentError('invalid message');
    }
    return repository.send(id, text, expectedAccount: expectedAccount);
  }
}
