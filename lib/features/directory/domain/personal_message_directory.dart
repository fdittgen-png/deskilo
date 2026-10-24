// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2472 (P) -- the new discussion's directory as the personal home answers
// it (`my_personal_message_directory_v1`): my workspaces by network
// reference, the people of one of them I may write to, and my groups.
// The server applied every rule (verified relationships, blocks,
// reachability, hidden names); this side only types the answer. The
// decoding is strict: a malformed page is a shape error, never an empty
// list, and a person is always an account of the personal home.
import '../../../core/data/json_reader.dart';

/// The three sections the reader answers.
enum DirectorySection { workspaces, people, groups }

/// Whether the relationships behind a page could be verified.
enum RelationshipStatus {
  /// Every relationship is in force.
  ready,

  /// Some workspaces could not be verified; they are left out.
  partial,

  /// None could (or, for one workspace's people, not this one).
  unavailable;

  static RelationshipStatus fromWire(JsonReader r) {
    final wire = r.string('relationship_status');
    for (final s in values) {
      if (s.name == wire) return s;
    }
    throw JsonShapeException(
      r.context,
      'relationship_status',
      'ready|partial|unavailable',
      wire,
    );
  }
}

/// One workspace I hold a relationship with. [name] is the workspace's own
/// for one the personal home hosts; another installation's is the name my
/// own live fact asserted while its source is enrolled, else null (the
/// screen then shows a neutral label).
class DirectoryWorkspace {
  const DirectoryWorkspace({required this.networkId, this.name});

  factory DirectoryWorkspace.decode(JsonReader r) {
    final name = r.stringOrNull('permitted_name');
    return DirectoryWorkspace(
      networkId: r.string('network_id'),
      name: name == null || name.trim().isEmpty ? null : name,
    );
  }

  final String networkId;
  final String? name;
}

/// One person I may write to, as an account of the personal home. [name]
/// is null when the person does not show it to me.
class DirectoryPerson {
  const DirectoryPerson({
    required this.id,
    required this.workspaceRef,
    this.name,
  });

  factory DirectoryPerson.decode(JsonReader r) {
    final view = r.objectOrNull('view');
    final identity = view?.objectOrNull('identity');
    final name = identity?.stringOrNull('name');
    return DirectoryPerson(
      id: r.string('person_id'),
      workspaceRef: r.string('context_workspace_ref'),
      name: name == null || name.trim().isEmpty ? null : name,
    );
  }

  final String id, workspaceRef;
  final String? name;
}

/// One group I am in, with or without a message.
class DirectoryGroup {
  const DirectoryGroup({
    required this.id,
    required this.title,
    required this.announceOnly,
    required this.canWrite,
  });

  factory DirectoryGroup.decode(JsonReader r) => DirectoryGroup(
    id: r.string('group_id'),
    title: r.string('title'),
    announceOnly: r.boolOr('announce_only', fallback: false),
    canWrite: r.boolOr('can_write', fallback: false),
  );

  final String id, title;
  final bool announceOnly, canWrite;
}

/// One keyset page of a section.
class DirectoryPage<T> {
  const DirectoryPage({
    required this.items,
    required this.status,
    this.nextKey,
  });

  /// [raw] as [section]'s page; anything else is a shape error.
  static DirectoryPage<T> decode<T>(
    Object? raw,
    DirectorySection section,
    T Function(JsonReader row) item,
  ) {
    final r = JsonReader.of(raw, context: 'my_personal_message_directory_v1');
    if (r.integer('schema_version') != 1) {
      throw JsonShapeException(
        r.context,
        'schema_version',
        '1',
        '${r.raw('schema_version')}',
      );
    }
    if (r.string('section') != section.name) {
      throw JsonShapeException(
        r.context,
        'section',
        section.name,
        '${r.raw('section')}',
      );
    }
    if (r.raw('items') is! List) {
      throw JsonShapeException(r.context, 'items', 'List', '${r.raw('items')}');
    }
    final more = r.boolOr('has_more', fallback: false);
    final next = r.stringOrNull('next_key');
    if (more != (next != null)) {
      throw JsonShapeException(
        r.context,
        'next_key',
        'set exactly when has_more',
        '$next',
      );
    }
    return DirectoryPage(
      items: r.objects('items', item),
      status: RelationshipStatus.fromWire(r),
      nextKey: next,
    );
  }

  final List<T> items;
  final RelationshipStatus status;

  /// The cursor of the next page; null on the last one.
  final String? nextKey;
  bool get hasMore => nextKey != null;
}

/// Why the directory could not be read.
enum DirectoryFailure {
  /// The personal home does not offer the reader (an older server).
  unsupported,

  /// The session may not read it, or the workspace is not one of mine.
  forbidden,

  /// The request was refused as malformed (section, cursor, search).
  invalid,

  /// The answer was not a directory page.
  malformed,
}

class DirectoryRefused implements Exception {
  const DirectoryRefused(this.failure, {this.detail = ''});
  final DirectoryFailure failure;
  final String detail;

  @override
  String toString() => 'DirectoryRefused(${failure.name}: $detail)';
}

/// The reader at the personal home.
abstract interface class PersonalMessageDirectoryRepository {
  Future<DirectoryPage<DirectoryWorkspace>> workspaces({String? after});
  Future<DirectoryPage<DirectoryPerson>> people(
    String networkId, {
    String? after,
    String query = '',
  });
  Future<DirectoryPage<DirectoryGroup>> groups({String? after});
}

/// What the new discussion shows: my workspaces with the people loaded so
/// far for each, and my groups.
class PersonalDirectory {
  const PersonalDirectory({
    required this.workspaces,
    required this.people,
    required this.groups,
    required this.status,
  });

  final List<DirectoryWorkspace> workspaces;

  /// Per workspace network id, the people loaded so far.
  final Map<String, DirectoryPage<DirectoryPerson>> people;
  final List<DirectoryGroup> groups;
  final RelationshipStatus status;

  PersonalDirectory withPeople(
    String networkId,
    DirectoryPage<DirectoryPerson> next,
  ) {
    final before = people[networkId];
    return PersonalDirectory(
      workspaces: workspaces,
      groups: groups,
      status: status,
      people: {
        ...people,
        networkId: DirectoryPage(
          items: [...?before?.items, ...next.items],
          status: next.status,
          nextKey: next.nextKey,
        ),
      },
    );
  }
}
