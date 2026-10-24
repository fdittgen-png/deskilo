// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2556 C1 -- a page of an inbox source is what its role may say, and the
// inbox composed from sources keeps each source's state and never shows a
// row a slower source could still precede.
import 'package:deskilo/features/directory/domain/inbox_composition.dart';
import 'package:deskilo/features/directory/domain/inbox_sources.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _row(String kind, String id, String at) => {
  'context_kind': kind,
  'context_id': id,
  'title': id,
  'last_at': at,
  'unread': 0,
};

Map<String, dynamic> _page(
  String role,
  List<Map<String, dynamic>> items, {
  Map<String, dynamic>? cursor,
}) => {
  'schema_version': 1,
  'source_role': role,
  'installation_id': 'inst-p',
  'items': items,
  'next_cursor': cursor,
  'has_more': cursor != null,
};

InboxSourceFailure? _refusal(Object? raw, InboxSourceRole role) {
  try {
    InboxSourcePage.decode(raw, role);
    return null;
  } on InboxSourceRefused catch (e) {
    return e.failure;
  }
}

void main() {
  group('a page', () {
    test('of the personal home: its rows and the cursor verbatim', () {
      final page = InboxSourcePage.decode(
        _page(
          'personal_home',
          [_row('account', 'a1', '2026-07-15T09:00:00.123456+00:00')],
          cursor: {
            'before_at': '2026-07-15T09:00:00.123456+00:00',
            'before_key': 'account:a1',
          },
        ),
        InboxSourceRole.personalHome,
      );
      expect(page.rows.single['context_id'], 'a1');
      expect(page.hasMore, isTrue);
      expect(page.next?.at, '2026-07-15T09:00:00.123456+00:00');
      expect(page.next?.key, 'account:a1');
      expect(page.installationId, 'inst-p');
    });

    test('a workspace host cannot answer as the personal home', () {
      expect(
        _refusal(
          _page('workspace_host', const []),
          InboxSourceRole.personalHome,
        ),
        InboxSourceFailure.wrongRole,
      );
    });

    test('a row of another role\'s kind is refused, not shown', () {
      expect(
        _refusal(
          _page('personal_home', [_row('space', 's1', '2026-07-15T09:00:00Z')]),
          InboxSourceRole.personalHome,
        ),
        InboxSourceFailure.malformed,
      );
    });

    test('more without a cursor, or a cursor without more, is malformed', () {
      expect(
        _refusal({
          ..._page('workspace_host', const []),
          'has_more': true,
        }, InboxSourceRole.workspaceHost),
        InboxSourceFailure.malformed,
      );
      expect(
        _refusal('[]', InboxSourceRole.workspaceHost),
        InboxSourceFailure.malformed,
      );
      expect(
        _refusal({
          ..._page('workspace_host', const []),
          'schema_version': 2,
        }, InboxSourceRole.workspaceHost),
        InboxSourceFailure.malformed,
      );
    });
  });

  group('the composition', () {
    InboxSlot loaded(
      InboxSourceRole role,
      List<Map<String, dynamic>> rows, {
      bool more = false,
    }) => InboxSlot.reading(role: role, source: '').firstPage(
      InboxSourcePage(
        role: role,
        installationId: 'i',
        rows: rows,
        hasMore: more,
        next: more ? const InboxCursor(at: 'x', key: 'y') : null,
      ),
    );

    test('shows each source as it answers, the others still reading', () {
      final inbox = composeInbox([
        loaded(InboxSourceRole.personalHome, [
          _row('account', 'a1', '2026-07-15T08:00:00Z'),
        ]),
        const InboxSlot.reading(
          role: InboxSourceRole.workspaceHost,
          source: '',
        ),
      ]);
      expect(inbox.entries.map((e) => e.contextId), ['a1']);
      expect(inbox.reading, isTrue);
    });

    test('stops at the oldest row of a source that has more', () {
      final inbox = composeInbox([
        loaded(InboxSourceRole.personalHome, [
          _row('account', 'a1', '2026-07-15T07:00:00Z'),
        ]),
        loaded(InboxSourceRole.workspaceHost, [
          _row('space', 's1', '2026-07-15T09:00:00Z'),
        ], more: true),
      ]);
      expect(inbox.entries.map((e) => e.contextId), ['s1']);
      expect(inbox.hasMore, isTrue);
    });

    test('a failed source keeps what it showed; an unavailable one shows '
        'nothing of it any more', () {
      final shown = loaded(InboxSourceRole.personalHome, [
        _row('account', 'a1', '2026-07-15T07:00:00Z'),
      ]);
      expect(
        composeInbox([shown.failed(StateError('x'))]).entries,
        hasLength(1),
      );
      final gone = shown.unavailable(StateError('x'));
      expect(composeInbox([gone]).entries, isEmpty);
      expect(gone.state, InboxSlotState.unavailable);
    });

    test('the same conversation answered by two roles of a legacy server '
        'is one row', () {
      final all = [
        _row('account', 'a1', '2026-07-15T07:00:00Z'),
        _row('space', 's1', '2026-07-15T08:00:00Z'),
      ];
      final inbox = composeInbox([
        const InboxSlot.reading(
          role: InboxSourceRole.personalHome,
          source: '',
        ).legacyRows(all),
        const InboxSlot.reading(
          role: InboxSourceRole.workspaceHost,
          source: '',
        ).legacyRows(all),
      ]);
      expect(inbox.entries.map((e) => e.contextId), ['s1', 'a1']);
    });
  });
}
