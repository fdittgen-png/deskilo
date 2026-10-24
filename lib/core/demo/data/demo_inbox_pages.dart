// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2556 C1 -- the in-memory messenger's inbox in the two roles of a split
// deployment: a page of the rows of one role's kinds, newest first, keyset
// after a cursor -- the order and the cursor `my_account_inbox_v1` and
// `my_workspace_inbox_v1` keep. Widget tests set which roles a fake server
// plays and whether it predates the readers.
import '../../../features/directory/domain/inbox_sources.dart';
import '../../settings/setting_defaults.g.dart';

mixin DemoInboxPages {
  /// Every row this server's legacy `my_inbox` answers.
  Future<List<InboxRow>> inbox();

  /// False answers as a server older than the split readers.
  bool splitReaders = true;

  /// The roles this server plays; a reader of another role refuses.
  Set<InboxSourceRole> roles = {...InboxSourceRole.values};

  /// The page size `messaging.inbox_page_size` sets on this server.
  int inboxPageSize = SettingDefaults.messagingInboxPageSize;

  /// Every page read: `role:cursor key`.
  final inboxPageLog = <String>[];

  static String _keyOf(InboxRow r) => '${r['context_kind']}:${r['context_id']}';

  static DateTime _atOf(Object? at) =>
      DateTime.tryParse('$at')?.toUtc() ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  /// Newest first; at the same time, the greater key first.
  static int _newestFirst(InboxRow a, InboxRow b) {
    final byTime = _atOf(b['last_at']).compareTo(_atOf(a['last_at']));
    return byTime != 0 ? byTime : _keyOf(b).compareTo(_keyOf(a));
  }

  Future<InboxSourcePage> inboxPage(
    InboxSourceRole role, {
    InboxCursor? before,
  }) async {
    final all = await inbox();
    if (!splitReaders) {
      throw const InboxSourceRefused(InboxSourceFailure.unsupported);
    }
    if (!roles.contains(role)) {
      throw const InboxSourceRefused(InboxSourceFailure.wrongRole);
    }
    inboxPageLog.add('${role.wire}:${before?.key ?? ''}');
    final edge = before == null
        ? null
        : <String, Object?>{
            'last_at': before.at,
            'context_kind': before.key.split(':').first,
            'context_id': before.key.substring(before.key.indexOf(':') + 1),
          };
    final rows = [
      for (final r in all)
        if (role.kinds.contains(r['context_kind']) &&
            (edge == null || _newestFirst(edge, r) < 0))
          r,
    ]..sort(_newestFirst);
    final page = rows.take(inboxPageSize).toList();
    final more = rows.length > inboxPageSize;
    return InboxSourcePage(
      role: role,
      installationId: 'demo',
      rows: List.unmodifiable(page),
      next: more
          ? InboxCursor(at: '${page.last['last_at']}', key: _keyOf(page.last))
          : null,
      hasMore: more,
    );
  }
}
