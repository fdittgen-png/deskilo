// SPDX-License-Identifier: AGPL-3.0-or-later
/// The deliberately public projection, separate from the private workspace.
///
/// [document] is the allow-listed projection the public network adapter
/// produced (#1847): only fields the contract lists, never a raw row.
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
    this.incompatible = const [],
    this.moreSources = false,
    this.moreWorkspaces = false,
  });
  final List<PublicWorkspace> workspaces;

  /// Sources that could not be reached.
  final List<String> unavailable;

  /// #1847 — sources that answered with a card this version cannot honour
  /// (an unknown required term or state). Their other cards still show.
  final List<String> incompatible;
  final bool moreSources, moreWorkspaces;
}

/// #1847 — the PUBLIC discovery interface: anonymous reads of deliberately
/// published cards, on this installation and every registered one. It
/// holds no session and offers no write.
abstract interface class PublicDiscoveryRepository {
  Future<DirectoryPage> search(
    String query, {
    int sourcePage = 0,
    int workspacePage = 0,
  });

  /// The card as its installation publishes it NOW; null when it is no
  /// longer published.
  Future<PublicWorkspace?> detail(PublicWorkspace card);
}

/// #2086 — the public fields that have a counterpart in the workspace's
/// own information: until the owner overrides one, it follows that
/// information. Every other public field is only what the owner typed.
const publicInheritedFields = ['host_type', 'address'];

/// The inherited fields that follow the workspace information in [page],
/// a `publication.page.read` answer. A page without the marker (an older
/// server) follows nothing: what it stored is what it shows.
Set<String> publicFollowing(Map<String, dynamic> page) {
  final following = page['following'];
  if (following is! Map) return {};
  return {
    for (final field in publicInheritedFields)
      if (following[field] == true) field,
  };
}

/// #1847 — the MANAGEMENT interface: the owner authors the public page.
abstract interface class PublicationRepository {
  /// `{published, document, following}` — the owner's own page, draft
  /// included, inherited fields resolved (#2086).
  Future<Map<String, dynamic>> ownPage(String workspace);

  /// #2086 — returns [fields] (every inherited field when null) to the
  /// workspace information; answers the page as [ownPage] does. Never
  /// publishes or withdraws the page.
  Future<Map<String, dynamic>> resetPage(
    String workspace, {
    Set<String>? fields,
  });

  /// Saves and publishes or withdraws; answers the public projection.
  Future<Map<String, dynamic>> savePage(
    String workspace,
    Map<String, String> document,
    bool published,
  );
}

/// #1847 — the PARTICIPANT interface: a signed-in account acting for
/// itself — registering an installation in the directory, asking to join.
abstract interface class DirectoryParticipantRepository {
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
