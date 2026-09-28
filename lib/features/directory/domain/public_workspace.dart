// SPDX-License-Identifier: AGPL-3.0-or-later
/// The deliberately public projection, separate from the private workspace.
class PublicWorkspace {
  const PublicWorkspace(this.id, this.source, this.key, this.document);
  final String id, source, key;
  final Map<String, dynamic> document;
  String text(String field) =>
      document[field] is String ? document[field] as String : '';
  String get name => text('name');
  double? get latitude => double.tryParse(text('latitude'));
  double? get longitude => double.tryParse(text('longitude'));
  List<Map<String, dynamic>> get contacts =>
      (document['contacts'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
}

class DirectoryPage {
  const DirectoryPage(
    this.workspaces, {
    this.unavailable = const [],
    this.moreSources = false,
    this.moreWorkspaces = false,
  });
  final List<PublicWorkspace> workspaces;
  final List<String> unavailable;
  final bool moreSources, moreWorkspaces;
}

abstract interface class DirectoryRepository {
  Future<DirectoryPage> search(
    String query, {
    int sourcePage = 0,
    int workspacePage = 0,
  });
  Future<Map<String, dynamic>> ownPage(String workspace);
  Future<Map<String, dynamic>> savePage(
    String workspace,
    Map<String, String> document,
    bool published,
  );
  Future<void> register(String origin, String key);
  Future<void> apply(PublicWorkspace workspace);
}

abstract interface class AccountContactRepository {
  Future<bool> availability();
  Future<void> setAvailability(bool value);
  Future<bool> adminVisibility(String workspace, {bool? visible});
  Future<bool> employment(String member, {bool? employed});
  Future<List<Map<String, dynamic>>> search(String query, {String? before});
  Future<List<Map<String, dynamic>>> conversations({
    DateTime? beforeAt,
    String? beforeId,
  });
  Future<List<Map<String, dynamic>>> messages(
    String conversation, {
    DateTime? beforeAt,
    String? beforeId,
  });
  Future<String?> conversationWith(String recipient);
  Future<String> send(String recipient, String body);
}
