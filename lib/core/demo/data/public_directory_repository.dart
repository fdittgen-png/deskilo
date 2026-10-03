// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/directory/domain/public_workspace.dart';
import '../../public_network/public_network_negotiator.dart';

/// #1847 — one in-memory directory behind all three interfaces: what the
/// public reads, what the owner manages and what a participant asks.
class FakeDirectoryRepository
    implements
        PublicDiscoveryRepository,
        PublicationRepository,
        DirectoryParticipantRepository {
  final cards = <PublicWorkspace>[];
  final pages = <String, Map<String, dynamic>>{};
  final requests = <String>[];
  bool fail = false;

  /// #1847 B — when set, apply is refused before anything is sent, as the
  /// real repository refuses an action it could not negotiate.
  PublicActionRefusal? refuseApply;
  @override
  Future<DirectoryPage> search(
    String query, {
    int sourcePage = 0,
    int workspacePage = 0,
  }) async {
    if (fail) throw StateError('directory unavailable');
    return DirectoryPage(
      cards
          .where((w) => w.name.toLowerCase().contains(query.toLowerCase()))
          .skip(workspacePage * 25)
          .take(25)
          .toList(),
    );
  }

  @override
  Future<PublicWorkspace?> detail(PublicWorkspace card) async {
    if (fail) throw StateError('directory unavailable');
    if (card.source.isEmpty) return card;
    return cards
        .where((w) => w.id == card.id && w.source == card.source)
        .firstOrNull;
  }

  /// #2086 — the workspace's own information an inherited field follows.
  final local = <String, String>{'host_type': 'company', 'address': ''};

  Map<String, dynamic> _resolved(String workspace) {
    final stored = Map<String, dynamic>.from(
      (pages[workspace]?['document'] as Map?) ?? const <String, dynamic>{},
    );
    return {
      ...local,
      ...stored,
      'name': 'Demo workspace',
      'contacts': <Map<String, dynamic>>[],
    };
  }

  @override
  Future<Map<String, dynamic>> ownPage(String workspace) async {
    final stored = (pages[workspace]?['document'] as Map?) ?? const {};
    return {
      'published': pages[workspace]?['published'] == true,
      'document': _resolved(workspace),
      'following': {
        for (final field in publicInheritedFields)
          field: !stored.containsKey(field),
      },
    };
  }

  @override
  Future<Map<String, dynamic>> savePage(
    String workspace,
    Map<String, String> document,
    bool published,
  ) async {
    pages[workspace] = {
      'published': published,
      'document': <String, dynamic>{...document},
    };
    return _resolved(workspace);
  }

  @override
  Future<Map<String, dynamic>> resetPage(
    String workspace, {
    Set<String>? fields,
  }) async {
    final stored = pages[workspace]?['document'] as Map<String, dynamic>?;
    stored?.removeWhere(
      (key, _) => (fields ?? publicInheritedFields.toSet()).contains(key),
    );
    return ownPage(workspace);
  }

  @override
  Future<void> register(String origin, String key) async {}
  @override
  Future<void> apply(PublicWorkspace workspace) async {
    final refusal = refuseApply;
    if (refusal != null) throw refusal;
    requests.add(workspace.id);
  }
}

class FakeAccountContactRepository implements AccountContactRepository {
  FakeAccountContactRepository({DateTime? now})
    : now = now ?? DateTime.utc(2026, 7, 15);
  final DateTime now;
  bool available = false;
  final visible = <String, bool>{};
  final employed = <String, bool>{};
  final people = <Map<String, dynamic>>[];
  final threads = <Map<String, dynamic>>[];
  final notes = <String, List<Map<String, dynamic>>>{};
  final sent = <({String recipient, String body})>[];
  @override
  Future<bool> availability() async => available;
  @override
  Future<void> setAvailability(bool value) async {
    available = value;
  }

  @override
  Future<bool> adminVisibility(String workspace, {bool? visible}) async {
    if (visible != null) this.visible[workspace] = visible;
    return this.visible[workspace] ?? false;
  }

  @override
  Future<bool> employment(String member, {bool? employed}) async {
    if (employed != null) this.employed[member] = employed;
    return this.employed[member] ?? false;
  }

  @override
  Future<List<Map<String, dynamic>>> search(
    String query, {
    String? before,
  }) async =>
      people.where((p) => (p['name'] as String).contains(query)).toList();
  @override
  Future<List<Map<String, dynamic>>> conversations({
    DateTime? beforeAt,
    String? beforeId,
  }) async => threads;
  @override
  Future<List<Map<String, dynamic>>> messages(
    String conversation, {
    DateTime? beforeAt,
    String? beforeId,
  }) async => notes[conversation] ?? [];
  @override
  Future<String?> conversationWith(String recipient) async =>
      threads.where((t) => t['recipient'] == recipient).firstOrNull?['id']
          as String?;
  @override
  Future<String> send(String recipient, String body) async {
    sent.add((recipient: recipient, body: body));
    final id = await conversationWith(recipient) ?? recipient;
    notes.putIfAbsent(id, () => []).insert(0, {
      'id': 'note-${sent.length}',
      'body': body,
      'is_mine': true,
      'created_at': now.toUtc().toIso8601String(),
    });
    return id;
  }
}
