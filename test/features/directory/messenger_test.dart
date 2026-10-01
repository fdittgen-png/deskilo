// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1824 — the messenger's decisions, without a widget: several servers'
// inboxes become ONE list newest first, a server that failed is named
// rather than fatal, a forward only goes to another conversation on the
// same server, and the actions refuse what the server would refuse.
import 'package:deskilo/core/demo/data/messenger_repository.dart';
import 'package:deskilo/features/directory/application/messenger_actions.dart';
import 'package:deskilo/features/directory/domain/messenger.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> row(
  String kind,
  String id,
  String at, {
  int unread = 0,
  String title = '',
}) => {
  'context_kind': kind,
  'context_id': id,
  'title': title.isEmpty ? id : title,
  'workspace_name': 'Pézenas',
  'last_body': 'hi',
  'last_at': at,
  'unread': unread,
};

void main() {
  group('mergeInboxes', () {
    test('several servers become one list, newest first', () {
      final inbox = mergeInboxes({
        '': [
          row('space', 's1', '2026-09-01T09:00:00Z', unread: 2),
          row('account', 'a1', '2026-09-03T09:00:00Z'),
        ],
        'https://other.example': [
          row('inquiry_out', 'i1', '2026-09-02T09:00:00Z', unread: 1),
        ],
      });
      expect(inbox.entries.map((e) => e.contextId), ['a1', 'i1', 's1']);
      expect(inbox.entries[1].isRemote, isTrue);
      expect(inbox.entries[1].kind, MessageContextKind.inquiryOut);
      expect(inbox.unread, 3);
    });

    test('an unknown context is left out, a duplicate kept once', () {
      final inbox = mergeInboxes(
        {
          '': [
            row('space', 's1', '2026-09-01T09:00:00Z'),
            row('space', 's1', '2026-09-01T09:00:00Z'),
            row('newsletter', 'n1', '2026-09-01T09:00:00Z'),
          ],
        },
        unavailable: ['down.example'],
      );
      expect(inbox.entries, hasLength(1));
      expect(inbox.unavailable, ['down.example']);
    });

    test('an unreadable stamp sorts last instead of throwing', () {
      final inbox = mergeInboxes({
        '': [
          row('space', 'bad', 'not a date'),
          row('space', 'good', '2026-09-01T09:00:00Z'),
        ],
      });
      expect(inbox.entries.map((e) => e.contextId), ['good', 'bad']);
    });
  });

  test('forward targets: same server, never the source conversation', () {
    final inbox = mergeInboxes({
      '': [
        row('space', 'c1', '2026-09-01T09:00:00Z'),
        row('space', 'c2', '2026-09-01T09:00:00Z'),
        row('account', 'c1', '2026-09-01T09:00:00Z'),
      ],
      'https://other.example': [row('space', 'c3', '2026-09-01T09:00:00Z')],
    });
    final targets = forwardTargets(
      inbox.entries,
      source: '',
      fromKind: MessageContextKind.space,
      fromContextId: 'c1',
    );
    expect(
      targets.map((t) => '${t.kind.wire}:${t.contextId}'),
      unorderedEquals(['space:c2', 'account:c1']),
    );
  });

  test('a message row carries its origin, notice, lock and receipt', () {
    final message = ContextMessage.fromRow({
      'id': 'm1',
      'body': 'copy',
      'is_mine': true,
      'created_at': '2026-09-01T09:00:00Z',
      'read_at': '2026-09-01T10:00:00Z',
      'no_forward': true,
      'forwarded_from': {
        'kind': 'member_note',
        'message_id': 'orig',
        'context_kind': 'space',
        'context_label': 'Étage 2 group',
        'author_name': 'Léa M.',
      },
    }, kind: MessageKind.accountMessage);
    expect(message.mine, isTrue);
    expect(message.readAt, isNotNull);
    expect(message.forwardable, isFalse);
    expect(message.forwardedFrom?.authorName, 'Léa M.');
    expect(message.forwardedFrom?.contextKind, MessageContextKind.space);
    final notice = ContextMessage.fromRow({
      'id': 'n1',
      'created_at': '2026-09-01T09:00:00Z',
      'notice': {'kind': 'captured', 'actor_name': 'Ana'},
    }, kind: MessageKind.accountMessage);
    expect(notice.isNotice, isTrue);
    expect(notice.forwardable, isFalse);
  });

  test('the wire names are the contract', () {
    expect(MessageKind.values.map((k) => k.wire), [
      'member_note',
      'account_message',
      'inquiry_message',
    ]);
    expect(MessageContextKind.values.map((k) => k.targetWire), [
      'conversation',
      'account_conversation',
      'inquiry',
      'inquiry',
    ]);
    expect(MessengerRules.maxBody, 4000);
    expect(MessengerRules.pageSize, 50);
  });

  group('MessengerActions', () {
    late FakeMessengerRepository repo;
    late MessengerActions actions;
    setUp(() {
      repo = FakeMessengerRepository();
      actions = MessengerActions(repo);
    });

    test(
      'an empty or oversized message is refused before the server',
      () async {
        expect(() => actions.startInquiry('ws', '  '), throwsArgumentError);
        expect(
          () => actions.startInquiry('ws', 'x' * 4001),
          throwsArgumentError,
        );
        expect(
          () => actions.send(
            kind: MessageContextKind.account,
            contextId: '',
            body: 'hi',
          ),
          throwsArgumentError,
          reason: 'an account reply needs the other person',
        );
      },
    );

    test(
      'a locked message is not forwarded, even from a stale screen',
      () async {
        final target = InboxEntry(
          source: '',
          kind: MessageContextKind.account,
          contextId: 'a1',
          lastAt: DateTime.utc(2026),
        );
        final locked = ContextMessage(
          id: 'm1',
          kind: MessageKind.accountMessage,
          body: 'secret',
          mine: false,
          createdAt: DateTime.utc(2026),
          noForward: true,
        );
        expect(() => actions.forward(locked, target), throwsStateError);
        expect(repo.forwards, isEmpty);
      },
    );

    test('only my own ordinary account message can be deleted', () {
      ContextMessage m({
        bool mine = true,
        MessageKind kind = MessageKind.accountMessage,
      }) => ContextMessage(
        id: 'm1',
        kind: kind,
        body: 'x',
        mine: mine,
        createdAt: DateTime.utc(2026),
      );
      expect(
        () => actions.deleteAccountMessage(m(mine: false)),
        throwsStateError,
      );
      expect(
        () => actions.deleteAccountMessage(m(kind: MessageKind.inquiryMessage)),
        throwsStateError,
      );
    });

    test(
      'a first account message answers the conversation it opened',
      () async {
        repo.inboxRows.add({
          'context_kind': 'account',
          'context_id': 'conv-7',
          'peer_id': 'ana',
        });
        final landed = await actions.send(
          kind: MessageContextKind.account,
          contextId: '',
          body: 'hello',
          peer: 'ana',
        );
        expect(landed, 'conv-7');
      },
    );
  });

  test('the refusals the server words are told apart from faults', () {
    expect(MessengerRefusal.of('the author locked this message'),
        MessengerRefusal.locked);
    expect(MessengerRefusal.of('forwarding is off in this space'),
        MessengerRefusal.forwardingOff);
    expect(MessengerRefusal.of('message too long for this conversation'),
        MessengerRefusal.tooLong);
    expect(MessengerRefusal.of('inquiry closed'), MessengerRefusal.closed);
    expect(MessengerRefusal.of('workspace not published'),
        MessengerRefusal.unavailable);
    expect(MessengerRefusal.of('message limit reached'),
        MessengerRefusal.limit);
    expect(MessengerRefusal.of('connection reset'), isNull);
    expect(MessengerRefusal.of(null), isNull);
  });
}
