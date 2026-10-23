// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/data/json_reader.dart';
import 'directory_location.dart';

/// One row of `my_reachable_people`: a person I may write to, in
/// one workspace I share with them.
class ReachablePerson {
  const ReachablePerson({
    required this.workspaceId,
    required this.workspaceName,
    required this.id,
    required this.name,
  });

  factory ReachablePerson.fromRow(Object? raw) {
    final r = JsonReader.of(raw, context: 'my_reachable_people');
    return ReachablePerson(
      workspaceId: r.string('workspace_id'),
      workspaceName: r.stringOr('workspace_name'),
      id: r.string('id'),
      name: r.stringOr('name'),
    );
  }

  final String workspaceId, workspaceName, id, name;
}

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
  DirectoryLocation? get location =>
      DirectoryLocation.parse(document['latitude'], document['longitude']);
  double? get latitude => location?.latitude;
  double? get longitude => location?.longitude;
  List<Map<String, dynamic>> get contacts =>
      (document['contacts'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
}

/// #2086 — the public fields that have a counterpart in the workspace's
/// own information: until the owner overrides one, it follows that
/// information. Every other public field is only what the owner typed.
const publicInheritedFields = ['host_type', 'address'];

/// The text fields of a public page the owner writes, beside its host type,
/// in the order the page editor shows them.
const publicPageFields = [
  'description',
  'address',
  'email',
  'phone',
  'website',
  'image_url',
  'plan_url',
  'plans',
];

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
    Map<String, String> document, {
    required bool published,
  });
}

/// #1847 — the PARTICIPANT interface: a signed-in account acting for
/// itself — registering an installation in the directory, asking to join.
abstract interface class DirectoryParticipantRepository {
  Future<void> register(String origin, String key);
  Future<void> apply(PublicWorkspace workspace);

  /// #2343 — where [origin] stands with the global directory.
  Future<DirectoryLinkState> linkState(String origin, String key);
}

/// #2343 — a server and the global directory.
enum DirectoryLinkState {
  /// It carries the directory: its published spaces are always listed.
  directory,

  /// Linked: its published spaces are listed.
  linked,

  /// It answers with published spaces this app reads: it can be linked.
  linkable,

  /// It does not answer, or not with spaces this app can read.
  unreachable,
}

abstract interface class AccountContactRepository {
  Future<bool> availability();
  Future<void> setAvailability({required bool value});
  Future<bool> adminVisibility(String workspace, {bool? visible});
  Future<bool> employment(String member, {bool? employed});
  Future<List<Map<String, dynamic>>> search(String query, {String? before});

  /// The people I may write to, one row per shared workspace.
  Future<List<ReachablePerson>> reachablePeople();
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
