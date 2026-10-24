// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2556 C1 -- the inbox read where each conversation lives. The personal
// home answers my person-to-person conversations and groups
// (`my_account_inbox_v1`); a workspace host answers my workspace
// conversations and inquiries (`my_workspace_inbox_v1`). Each source is a
// slot with its own state, so one that fails or cannot be reached never
// hides the others. Pure Dart: what a page may say, and what a slot is.
library;

import 'package:meta/meta.dart';

import '../../../core/data/json_reader.dart';

/// One inbox row, in the shape `my_inbox` answers (InboxEntry.fromRow).
typedef InboxRow = Map<String, Object?>;

/// The role a server answers a page of the inbox in.
enum InboxSourceRole {
  /// The personal home: account conversations and groups.
  personalHome('personal_home', 'my_account_inbox_v1', {
    'account',
    'account_group',
  }),

  /// A workspace host: workspace conversations and inquiries.
  workspaceHost('workspace_host', 'my_workspace_inbox_v1', {
    'space',
    'inquiry_out',
    'inquiry_in',
  });

  const InboxSourceRole(this.wire, this.reader, this.kinds);

  /// What the answer's `source_role` says.
  final String wire;

  /// The RPC that reads a page in this role.
  final String reader;

  /// The context kinds a page of this role may hold.
  final Set<String> kinds;

  static InboxSourceRole? fromWire(Object? value) =>
      values.where((r) => r.wire == value).firstOrNull;
}

/// Where the next page starts: the last row's time, as the server wrote
/// it (sent back verbatim, so no precision is lost), and its key.
@immutable
class InboxCursor {
  const InboxCursor({required this.at, required this.key});
  final String at;
  final String key;
}

/// Why a source gave no page.
enum InboxSourceFailure {
  /// The server has no such reader: an older server, read the legacy way.
  unsupported,

  /// The server does not play this role, or its answer claims another one.
  wrongRole,

  /// The server refused the request itself (a cursor of another shape).
  invalid,

  /// The answer does not have the shape of a page.
  malformed,
}

/// A source's typed refusal.
class InboxSourceRefused implements Exception {
  const InboxSourceRefused(this.failure, {this.detail = ''});
  final InboxSourceFailure failure;
  final String detail;

  @override
  String toString() => 'InboxSourceRefused(${failure.name}) $detail';
}

/// One page of one source, checked: the role it claims is the role asked,
/// and every row is of that role's kinds.
@immutable
class InboxSourcePage {
  const InboxSourcePage({
    required this.role,
    required this.installationId,
    required this.rows,
    this.next,
    this.hasMore = false,
  });

  final InboxSourceRole role;
  final String installationId;

  /// The rows, in the shape `my_inbox` answers (InboxEntry.fromRow).
  final List<InboxRow> rows;
  final InboxCursor? next;
  final bool hasMore;

  /// [raw] as a page of [role]; throws [InboxSourceRefused] when it is
  /// not one.
  static InboxSourcePage decode(Object? raw, InboxSourceRole role) {
    try {
      final r = JsonReader.of(raw, context: role.reader);
      if (r.integer('schema_version') != 1) {
        throw const InboxSourceRefused(
          InboxSourceFailure.malformed,
          detail: 'schema_version',
        );
      }
      if (InboxSourceRole.fromWire(r.string('source_role')) != role) {
        throw InboxSourceRefused(
          InboxSourceFailure.wrongRole,
          detail: r.string('source_role'),
        );
      }
      final rows = <InboxRow>[];
      for (final item in r.list('items')) {
        if (item is! Map || !role.kinds.contains(item['context_kind'])) {
          throw const InboxSourceRefused(
            InboxSourceFailure.malformed,
            detail: 'item',
          );
        }
        rows.add(InboxRow.from(item));
      }
      final cursor = r.objectOrNull('next_cursor');
      final hasMore = r.boolOr('has_more', fallback: false);
      if (hasMore != (cursor != null)) {
        throw const InboxSourceRefused(
          InboxSourceFailure.malformed,
          detail: 'cursor',
        );
      }
      return InboxSourcePage(
        role: role,
        installationId: r.string('installation_id'),
        rows: List.unmodifiable(rows),
        next: cursor == null
            ? null
            : InboxCursor(
                at: cursor.string('before_at'),
                key: cursor.string('before_key'),
              ),
        hasMore: hasMore,
      );
    } on JsonShapeException catch (e, st) {
      // trace-exempt: rethrown typed; a malformed page is never shown as empty.
      Error.throwWithStackTrace(
        InboxSourceRefused(InboxSourceFailure.malformed, detail: '$e'),
        st,
      );
    }
  }
}

/// Where one source's read stands.
enum InboxSlotState {
  /// Its first page is being read (rows of an earlier read may stay).
  reading,

  /// Read.
  loaded,

  /// The read failed; Try again reads it once more.
  failed,

  /// Its server cannot be reached with this sign-in, or the personal home
  /// does not answer as one.
  unavailable,

  /// The server does not play this role: nothing to read, nothing to say.
  absent,
}

/// One source of the inbox: a role on one server ('' is the server the app
/// is signed in to, else a connected server's origin).
@immutable
class InboxSlot {
  const InboxSlot._({
    required this.role,
    required this.source,
    required this.label,
    required this.state,
    this.rows = const [],
    this.next,
    this.hasMore = false,
    this.loadingMore = false,
    this.legacy = false,
    this.failure,
  });

  /// A source whose first page is being read.
  const InboxSlot.reading({
    required InboxSourceRole role,
    required String source,
    String label = '',
  }) : this._(
         role: role,
         source: source,
         label: label,
         state: InboxSlotState.reading,
       );

  final InboxSourceRole role;
  final String source;

  /// The server's name for a connected server; '' for this one.
  final String label;
  final InboxSlotState state;
  final List<InboxRow> rows;
  final InboxCursor? next;
  final bool hasMore;
  final bool loadingMore;

  /// Read through the legacy `my_inbox` of a server without the reader.
  final bool legacy;

  /// Why the last read did not come.
  final Object? failure;

  /// The slot's identity: one role on one server.
  String get key => '${role.wire}|$source';

  InboxSlot _with({
    InboxSlotState? state,
    List<InboxRow>? rows,
    InboxCursor? next,
    bool? hasMore,
    bool? legacy,
    Object? failure,
  }) => InboxSlot._(
    role: role,
    source: source,
    label: label,
    state: state ?? this.state,
    rows: rows ?? this.rows,
    next: next,
    hasMore: hasMore ?? this.hasMore,
    legacy: legacy ?? this.legacy,
    failure: failure,
  );

  /// Read again: what was shown stays until the new page replaces it.
  InboxSlot get rereading =>
      _with(state: InboxSlotState.reading, next: next, legacy: legacy);

  /// The next page is being read.
  InboxSlot get readingMore => InboxSlot._(
    role: role,
    source: source,
    label: label,
    state: state,
    rows: rows,
    next: next,
    hasMore: hasMore,
    loadingMore: true,
    legacy: legacy,
  );

  /// [page] as the first page.
  InboxSlot firstPage(InboxSourcePage page) => _with(
    state: InboxSlotState.loaded,
    rows: page.rows,
    next: page.next,
    hasMore: page.hasMore,
    legacy: false,
  );

  /// [page] after the pages so far.
  InboxSlot appended(InboxSourcePage page) => _with(
    state: InboxSlotState.loaded,
    rows: List.unmodifiable([...rows, ...page.rows]),
    next: page.next,
    hasMore: page.hasMore,
  );

  /// Every row of a server without the reader, read the legacy way.
  InboxSlot legacyRows(List<InboxRow> all) => _with(
    state: InboxSlotState.loaded,
    rows: List.unmodifiable(all),
    hasMore: false,
    legacy: true,
  );

  /// The read failed: rows already shown stay, and Try again reads the
  /// first page once more.
  InboxSlot failed(Object error) =>
      _with(state: InboxSlotState.failed, next: next, failure: error);

  /// The server refuses this sign-in: nothing of it is shown any more.
  InboxSlot unavailable(Object error) => _with(
    state: InboxSlotState.unavailable,
    rows: const [],
    hasMore: false,
    failure: error,
  );

  /// The server does not play this role.
  InboxSlot get absent =>
      _with(state: InboxSlotState.absent, rows: const [], hasMore: false);
}

/// The slots of the inbox: the personal home's and this server's
/// workspace part, then both roles of every connected server, which
/// answers the role it plays (and says it does not play the other).
List<InboxSlot> inboxSlotsFor(List<({String origin, String host})> connected) =>
    [
      const InboxSlot.reading(role: InboxSourceRole.personalHome, source: ''),
      const InboxSlot.reading(role: InboxSourceRole.workspaceHost, source: ''),
      for (final c in connected) ...[
        InboxSlot.reading(
          role: InboxSourceRole.personalHome,
          source: c.origin,
          label: c.host,
        ),
        InboxSlot.reading(
          role: InboxSourceRole.workspaceHost,
          source: c.origin,
          label: c.host,
        ),
      ],
    ];
