// SPDX-License-Identifier: AGPL-3.0-or-later
import '../domain/public_workspace.dart';

/// Admission and publication decisions shared by the editor and public cards.
/// Server authorization remains authoritative for every operation.
class DirectoryActions {
  const DirectoryActions(this.repository);
  final DirectoryRepository repository;
  Future<Map<String, dynamic>> ownPage(String workspace) =>
      repository.ownPage(workspace);
  Future<Map<String, dynamic>> savePage(
    String workspace,
    Map<String, String> document,
    bool published,
  ) {
    final normalized = {
      for (final entry in document.entries) entry.key: entry.value.trim(),
    };
    if (!{
      'association',
      'company',
      'person',
    }.contains(normalized['host_type'])) {
      throw ArgumentError('invalid host type');
    }
    for (final key in ['website', 'image_url', 'plan_url']) {
      final value = normalized[key] ?? '';
      if (value.isEmpty) continue;
      final uri = Uri.tryParse(value);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        throw ArgumentError('public links require HTTPS');
      }
    }
    return repository.savePage(workspace, normalized, published);
  }

  Future<void> register(String origin, String key) =>
      repository.register(origin.trim(), key.trim());
  Future<void> apply(PublicWorkspace workspace) {
    if (workspace.id.isEmpty) throw ArgumentError('workspace required');
    return repository.apply(workspace);
  }
}

/// Account controls do not create, promote or reactivate workspace memberships.
class AccountContactActions {
  const AccountContactActions(this.repository);
  final AccountContactRepository repository;
  Future<void> setAvailability(bool value) => repository.setAvailability(value);
  Future<bool> adminVisibility(String workspace, {bool? visible}) =>
      repository.adminVisibility(workspace, visible: visible);
  Future<bool> employment(String member, {bool? employed}) =>
      repository.employment(member, employed: employed);
  Future<String?> conversationWith(String recipient) =>
      repository.conversationWith(recipient);
  Future<String> send(String recipient, String body) {
    final message = body.trim();
    if (recipient.isEmpty || message.isEmpty || message.length > 4000) {
      throw ArgumentError('invalid message');
    }
    return repository.send(recipient, message);
  }
}
