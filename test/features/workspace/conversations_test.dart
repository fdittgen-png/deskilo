// SPDX-License-Identifier: 0BSD
//
// #687 — the conversation model and write path (migrations 0125/0126).
//
// The messaging centre grows groups, and a group is the first thing
// `member_notes` could not carry: a row addressed to one member has
// nowhere to hang a name, a photo, or a roster.
//
// Verified live against the hosted project, 11 rolled-back cases:
// direct threads are idempotent, a direct message keeps its recipient so
// read receipts still work, a group message has none, a non-admin cannot
// add anyone, unread counts from the watermark and clear on open, FTS
// matches by prefix, and the last admin leaving promotes someone.
import 'dart:io';

import 'package:deskilo/features/workspace/domain/conversation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

Conversation conv({
  String id = 'c1',
  ConversationKind kind = ConversationKind.direct,
  String? title,
  String? other,
  String lastBody = 'hi',
  String? lastFrom,
  int unread = 0,
  DateTime? at,
}) =>
    Conversation(
      id: id,
      kind: kind,
      title: title,
      otherMemberId: other,
      lastBody: lastBody,
      lastFromMemberId: lastFrom,
      unread: unread,
      lastAt: at ?? DateTime.utc(2026, 8, 27, 12),
    );

void main() {
  group('the list is ordered by activity, not by kind', () {
    test('newest first, groups and people interleaved', () async {
      // WhatsApp's ordering, and the owner asked for it by name. A list
      // that grouped people above groups would bury the conversation
      // someone just wrote in.
      final repo = FakeWorkspaceRepository()
        ..conversations.addAll([
          conv(id: 'old-group', kind: ConversationKind.group, title: 'Team',
              at: DateTime.utc(2026, 8, 20)),
          conv(id: 'new-direct', other: 'm-2', at: DateTime.utc(2026, 8, 27)),
          conv(id: 'mid-group', kind: ConversationKind.group, title: 'Ops',
              at: DateTime.utc(2026, 8, 25)),
        ]);

      final list = await repo.fetchConversations('workspace-1');
      expect(list.map((c) => c.id),
          orderedEquals(['new-direct', 'mid-group', 'old-group']));
    });
  });

  group('a direct thread is one thread', () {
    test('opening the same person twice returns the same id', () async {
      // Two people opening each other at the same moment must not end up
      // with two threads — the server looks up by the PARTICIPANT PAIR,
      // never by anything a client passes.
      final repo = FakeWorkspaceRepository();
      final first = await repo.openDirectConversation('w', otherMemberId: 'm-2');
      final again = await repo.openDirectConversation('w', otherMemberId: 'm-2');
      expect(again, first);
      expect(repo.conversations.length, 1);
    });
  });

  group('a group knows what it is', () {
    test('creating one makes the creator an admin and counts the roster',
        () async {
      final repo = FakeWorkspaceRepository();
      final id = await repo.createGroupConversation(
        'w',
        title: 'Coworking 2026',
        memberIds: ['m-2', 'm-3'],
      );
      final roster = await repo.fetchParticipants(id);
      expect(roster.firstWhere((p) => p.memberId == 'member-1').isAdmin, isTrue);
      expect(roster.length, 3);
    });

    test('removing someone marks them LEFT rather than deleting them',
        () async {
      // Their past messages stay in the thread. A group whose history
      // develops holes when someone leaves is worse than a name nobody
      // recognises.
      final repo = FakeWorkspaceRepository();
      final id = await repo.createGroupConversation('w',
          title: 'Ops', memberIds: ['m-2']);
      await repo.removeParticipant(id, 'm-2');
      final roster = await repo.fetchParticipants(id);
      expect(roster.any((p) => p.memberId == 'm-2'), isTrue,
          reason: 'still listed, with an exit stamp');
      expect(roster.firstWhere((p) => p.memberId == 'm-2').isActive, isFalse);
    });
  });

  group('the read check points the right way', () {
    test('sentByMe is true only for my own last message', () {
      // A check on someone ELSE's message would claim they read what I
      // sent, which is backwards.
      expect(conv(lastFrom: 'member-1').sentByMe('member-1'), isTrue);
      expect(conv(lastFrom: 'm-2').sentByMe('member-1'), isFalse);
      expect(conv().sentByMe('member-1'), isFalse,
          reason: 'a thread with no messages has nothing to check');
    });
  });

  group('search', () {
    test('a blank query is nothing, never everything', () async {
      // Returning the whole history would flash the entire workspace
      // between keystrokes.
      final repo = FakeWorkspaceRepository();
      await repo.sendConversationMessage('c1', 'meeting at ten');
      expect(await repo.searchMessages('w', ''), isEmpty);
      expect(await repo.searchMessages('w', '   '), isEmpty);
      expect(await repo.searchMessages('w', 'meet'), hasLength(1));
    });

    test('the real query is a PREFIX search on the 0125 index', () {
      // Nobody finishes a word before expecting results, and the config
      // must match the index or the search silently sequential-scans.
      final source = File('lib/features/workspace/data/conversation_api.dart')
          .readAsStringSync();
      expect(source, contains("config: 'simple'"));
      expect(source, contains(r"'$word:*'"));
    });
  });

  group('what the schema deliberately refuses', () {
    late String schema;

    setUpAll(() {
      schema = File('supabase/migrations/0125_conversations.sql')
          .readAsStringSync();
    });

    test('no attachment COLUMN anywhere', () {
      // Asked for directly, and the right default: a coworking app that
      // accepts arbitrary uploads becomes a file host with none of the
      // retention, scanning or takedown machinery that implies.
      //
      // Matched as column DEFINITIONS: the header comment says the word
      // "attachments" out loud to record the decision, and a test that
      // tripped on its own documentation would be deleted rather than
      // understood.
      for (final column in [
        'image_path text',
        'attachment_path text',
        'document_path text',
        'media_url text',
      ]) {
        expect(schema, isNot(contains(column)), reason: '$column must not exist');
      }
      // And no bucket for message media.
      expect(schema, isNot(contains('storage.buckets')));
    });

    test('the roster policy does not recurse', () {
      // A policy on conversation_participants that queries
      // conversation_participants raises `infinite recursion detected in
      // policy`. The SECURITY DEFINER helper is what breaks the cycle,
      // and it is easy to "simplify" back into a bug.
      expect(schema, contains('create or replace function public.in_conversation'));
      expect(schema, contains('security definer'));
      expect(schema, contains('for select using (public.in_conversation(conversation_id))'));
    });

    test('a direct thread cannot be named', () {
      expect(schema, contains("(kind = 'direct' and title is null)"));
    });
  });

  group('groups can be started, run and left', () {
    test('a group needs a name; a one-to-one does not', () {
      // A direct thread is titled by the other person — a name that is
      // theirs to change, never ours to snapshot. The schema enforces
      // it; the sheet only asks once two people are picked.
      final schema = File('supabase/migrations/0125_conversations.sql')
          .readAsStringSync();
      expect(schema, contains("(kind = 'direct' and title is null)"));
      final sheet = File('lib/features/workspace/presentation/widgets/'
              'new_conversation_sheet.dart')
          .readAsStringSync();
      expect(sheet, contains('bool get _isGroup => _selected.length > 1;'));
      expect(sheet, contains("if (_isGroup)"),
          reason: 'the name field appears only once it means something');
    });

    test('the start button is disabled until the choice is complete', () {
      // A button that fails on tap teaches nothing about why.
      final sheet = File('lib/features/workspace/presentation/widgets/'
              'new_conversation_sheet.dart')
          .readAsStringSync();
      expect(sheet, contains('bool get _canStart'));
      expect(sheet, contains('!_isGroup || _groupName.text.trim().isNotEmpty'));
    });

    test('neither picker offers a kiosk or yourself', () async {
      // A kiosk is a shared tablet, not someone to write to; and a
      // thread with yourself is refused server-side anyway.
      for (final path in [
        'lib/features/workspace/presentation/widgets/new_conversation_sheet.dart',
        'lib/features/workspace/presentation/widgets/group_info_sheet.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source, contains('!m.isKiosk'), reason: path);
      }
      final sheet = File('lib/features/workspace/presentation/widgets/'
              'new_conversation_sheet.dart')
          .readAsStringSync();
      expect(sheet, contains('m.id != me?.id'));
    });

    test('admin-only controls are HIDDEN, not shown-then-refused', () {
      // Showing a control the server would refuse produces a tap, a
      // refusal and no explanation. Hiding it is the explanation.
      final sheet = File('lib/features/workspace/presentation/widgets/'
              'group_info_sheet.dart')
          .readAsStringSync();
      expect(sheet, contains('if (iAmAdmin)'));
      expect(sheet, contains('iAmAdmin &&'));
    });

    test('an admin cannot REMOVE themselves — that is leaving', () {
      // Leaving carries the last-admin rule (0126); removing does not,
      // so routing self-removal through remove would let the last admin
      // strand a group nobody can manage.
      final sheet = File('lib/features/workspace/presentation/widgets/'
              'group_info_sheet.dart')
          .readAsStringSync();
      expect(sheet, contains('p.memberId != myMemberId'));
      final sql = File('supabase/migrations/0126_conversation_rpcs.sql')
          .readAsStringSync();
      expect(sql, contains('use leave_conversation to remove yourself'));
    });

    test('leaving is confirmed, and says what actually happens', () {
      // "Leave" alone reads like it might delete the group for everyone.
      final sheet = File('lib/features/workspace/presentation/widgets/'
              'group_info_sheet.dart')
          .readAsStringSync();
      expect(sheet, contains("ValueKey('group-leave-confirm')"));
      expect(sheet, contains('conversationLeaveConfirm'));
    });

    test('someone who left stays LISTED, dimmed and last', () {
      // Their messages are still in the thread above; a name with no row
      // is a name nobody can place.
      final sheet = File('lib/features/workspace/presentation/widgets/'
              'group_info_sheet.dart')
          .readAsStringSync();
      expect(sheet, contains('if (!p.isActive) p,'));
      expect(sheet, contains('Opacity('));
    });
  });

  group('the centre can start what it shows', () {
    test('there is a compose button ON the screen', () {
      // Its first empty state pointed at a member profile on ANOTHER
      // screen — the app telling someone to leave the screen they opened
      // for exactly this.
      final screen = File('lib/features/workspace/presentation/screens/'
              'messages_screen.dart')
          .readAsStringSync();
      expect(screen, contains("ValueKey('new-conversation')"));
      expect(screen, contains('showNewConversationSheet'));
    });

    test('the group header opens the roster, with a chevron to say so', () {
      // A tappable subtitle that looks like plain text is a control
      // nobody finds.
      final thread = File('lib/features/workspace/presentation/widgets/'
              'conversation_thread.dart')
          .readAsStringSync();
      expect(thread, contains("ValueKey('conversation-header')"));
      expect(thread, contains('showGroupInfoSheet'));
      expect(thread, contains('Icons.chevron_right'));
      // A DIRECT thread has no roster to open.
      expect(thread, contains('!conversation.isGroup'));
    });
  });

  group('search finds three kinds and each goes somewhere', () {
    late String screen;

    setUpAll(() {
      screen = File('lib/features/workspace/presentation/screens/'
              'message_search_screen.dart')
          .readAsStringSync();
    });

    test('one field, three labelled sections', () {
      // "Find that thing about the invoice" and "find Alex" are the same
      // impulse; nobody wants to choose a category first. Labelled so
      // the three never blur.
      for (final key in ['search-person-', 'search-group-', 'search-message-']) {
        expect(screen, contains(key), reason: '$key results are missing');
      }
      expect(screen, contains('messageSearchPeople'));
      expect(screen, contains('messageSearchGroups'));
      expect(screen, contains('messageSearchMessages'));
    });

    test('people and groups filter LOCALLY; only text search waits', () {
      // They are already in memory. Debouncing them too would make the
      // list lag behind the field for no reason.
      expect(screen, contains('Timer('));
      expect(screen, contains('milliseconds: 300'));
      expect(screen, contains('_query'), reason: 'the debounced term is '
          'separate from the field text');
    });

    test('a message with NO conversation is not tappable', () {
      // Pre-0125 notes and admin broadcasts have no thread to open, and
      // a dead tap is worse than none.
      expect(screen, contains('enabled: note.conversationId != null'));
      expect(screen, contains('note.conversationId == null\n                            ? null'));
    });

    test('finding a PERSON opens a thread, creating it if new', () {
      // Which is the whole point of finding them here.
      expect(screen, contains('openDirectConversation'));
    });
  });

  group('messages are not notifications any more', () {
    test('the bell counts pending confirmations ONLY', () {
      // It used to count unread messages too — and sent them to a feed
      // to find a conversation that was one tab away.
      final shell =
          File('lib/app/shell/shell_screen.dart').readAsStringSync();
      expect(shell, contains('myPendingEventCountProvider'));
      // The bell's count line must not add anything to it.
      expect(shell, isNot(contains('+\n        (ref.watch(unreadNoteCountProvider)')));
      expect(shell, contains('Unread messages moved to the'));
    });

    test('the feed carries BROADCASTS only', () {
      // A message in two places is one you can mark read in one and
      // still see unread in the other. But emptying the list outright
      // left admin broadcasts homeless: a broadcast is a fan-out to
      // whoever is an admin at READ time — no recipient, no thread,
      // nowhere in the messaging centre to live. It would have vanished
      // from the app entirely.
      // The filter lives beside the feed it serves, so the screen only
      // asks for it.
      final filter = File('lib/features/events/presentation/'
              'feed_notes.dart')
          .readAsStringSync();
      expect(filter, contains('if (n.isBroadcast) n,'));
      final events = File('lib/features/events/presentation/screens/'
              'events_screen.dart')
          .readAsStringSync();
      expect(events, contains('broadcastsForFeed(ref)'));
      expect(events, contains('BROADCASTS STAY'));
    });

    test('unread never counts what I SENT', () {
      // An inbox reporting your own outbox. This was already right at
      // the note level and must stay that way.
      final providers = File('lib/features/workspace/providers/'
              'workspace_providers.dart')
          .readAsStringSync();
      expect(providers, contains('n.fromMemberId != me?.id'));
    });

    test('a message alert opens the CONVERSATION, groups included', () {
      // Resolving a "partner" has no answer when eight people are in
      // the thread.
      final link = File('lib/features/workspace/presentation/screens/'
              'message_link_screen.dart')
          .readAsStringSync();
      expect(link, contains('note?.conversationId'));
      expect(link, contains('ConversationThread(conversationId:'));
      // And it lands in the messaging centre, not the events feed.
      expect(link, contains("context.go('/messages')"));
      expect(link, isNot(contains("context.go('/events')")));
    });
  });
}
