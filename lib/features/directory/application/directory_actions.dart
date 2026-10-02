// SPDX-License-Identifier: AGPL-3.0-or-later
import '../domain/public_workspace.dart';

/// #1847 — the owner's publication decisions (MANAGEMENT). Server
/// authorization remains authoritative for every operation.
class PublicationActions {
  const PublicationActions(this.repository);
  final PublicationRepository repository;
  Future<Map<String, dynamic>> ownPage(String workspace) =>
      repository.ownPage(workspace);

  /// Saves the page. An inherited field named in [following] is left out,
  /// so it keeps following the workspace information (#2086); any other
  /// value, even blank, is the owner's override.
  Future<Map<String, dynamic>> savePage(
    String workspace,
    Map<String, String> document,
    bool published, {
    Set<String> following = const {},
  }) {
    final normalized = {
      for (final entry in document.entries)
        if (!(following.contains(entry.key) &&
            publicInheritedFields.contains(entry.key)))
          entry.key: entry.value.trim(),
    };
    final host = normalized['host_type'];
    if (host != null && !{'association', 'company', 'person'}.contains(host)) {
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

  /// #2086 — back to the workspace information: [fields], or every
  /// inherited field when null.
  Future<Map<String, dynamic>> resetPage(
    String workspace, {
    Set<String>? fields,
  }) {
    if (fields != null &&
        (fields.isEmpty || !fields.every(publicInheritedFields.contains))) {
      throw ArgumentError('not an inherited public field');
    }
    return repository.resetPage(workspace, fields: fields);
  }
}

/// #1847 — what a signed-in account does for itself from a public card
/// (PARTICIPANT): register an installation, ask to join.
class DirectoryActions {
  const DirectoryActions(this.repository);
  final DirectoryParticipantRepository repository;
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
