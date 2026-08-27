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
}
