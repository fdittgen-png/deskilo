// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/directory/domain/discovery_paging.dart';
import '../../../features/directory/domain/public_workspace.dart';
import '../../public_network/public_network_negotiator.dart';
import '../../public_network/public_network_operations.dart';

/// #1847 — one in-memory directory behind all three interfaces: what the
/// public reads, what the owner manages and what a participant asks.
class FakeDirectoryRepository
    implements
        PublicDiscoveryRepository,
        PublicationRepository,
        DirectoryParticipantRepository {
  final cards = <PublicWorkspace>[];

  /// #2343 — the origins linked to the global directory, and the state a
  /// probe answers for any other.
  final linked = <String>[];
  DirectoryLinkState unlinked = DirectoryLinkState.linkable;
  final pages = <String, Map<String, dynamic>>{};
  final requests = <String>[];
  bool fail = false;

  /// #1847 B — when set, apply is refused before anything is sent, as the
  /// real repository refuses an action it could not negotiate.
  PublicActionRefusal? refuseApply;

  /// Every page of cards asked, as `origin#page`, in order.
  final reads = <String>[];

  /// Pages of a source that fail, as `origin#page`; a test clears one to
  /// let its retry succeed.
  final failPages = <String>{};

  /// Cards per page of one source; the contract's page size by default.
  int pageSize = PublicNetworkOperations.directoryWorkspacesSearch.pageSize!;

  /// Every source the cards name, in the order they first appear, on one
  /// page of the directory.
  @override
  Future<DirectorySourcesPage> sources({int page = 0}) async {
    if (fail) throw StateError('directory unavailable');
    final origins = <String, String>{};
    for (final c in cards) {
      origins.putIfAbsent(c.source, () => c.key);
    }
    return DirectorySourcesPage([
      if (page == 0)
        for (final e in origins.entries) DirectorySource(e.key, e.value),
    ], more: false);
  }

  @override
  Future<SourceCardsPage> workspaces(
    DirectorySource source,
    String query, {
    int page = 0,
  }) async {
    reads.add('${source.origin}#$page');
    if (fail || failPages.contains('${source.origin}#$page')) {
      throw StateError('directory unavailable');
    }
    final matching = cards
        .where((w) => w.source == source.origin)
        .where((w) => w.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
    final slice = matching.skip(page * pageSize).take(pageSize).toList();
    return SourceCardsPage(slice, more: slice.length == pageSize);
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

  /// The workspace's own name, which its public page always carries.
  String ownName = 'Demo workspace';

  Map<String, dynamic> _resolved(String workspace) {
    final stored = Map<String, dynamic>.from(
      (pages[workspace]?['document'] as Map?) ?? const <String, dynamic>{},
    );
    return {
      ...local,
      ...stored,
      'name': ownName,
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
    Map<String, String> document, {
    required bool published,
  }) async {
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
  Future<void> register(String origin, String key) async {
    if (fail) throw StateError('directory unavailable');
    if (!linked.contains(origin)) linked.add(origin);
  }

  @override
  Future<DirectoryLinkState> linkState(String origin, String key) async =>
      linked.contains(origin) ? DirectoryLinkState.linked : unlinked;
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
  // What my_reachable_people answers.
  final reachable = <ReachablePerson>[];
  // When set, my_reachable_people fails (a server that cannot answer).
  bool failReachable = false;
  // When set, answers in place of [reachable], at the time of the call
  // (the demo's persona can change between two calls).
  List<ReachablePerson> Function()? reachableOf;
  final threads = <Map<String, dynamic>>[];
  final notes = <String, List<Map<String, dynamic>>>{};
  final sent = <({String recipient, String body})>[];
  @override
  Future<bool> availability() async => available;
  @override
  Future<void> setAvailability({required bool value}) async {
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
  Future<List<ReachablePerson>> reachablePeople() async {
    if (failReachable) throw StateError('directory unavailable');
    return reachableOf?.call() ?? reachable;
  }
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
