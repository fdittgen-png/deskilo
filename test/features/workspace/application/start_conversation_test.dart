// SPDX-License-Identifier: 0BSD
//
// #1449 — the two rules behind starting a conversation, without a sheet.
//
// **What a second person means.** In the messages hub the Group switch
// decides. Outside it there is no switch: picking a second person MAKES
// it a group, because somebody who chose two people did not ask for a
// one-to-one.
//
// **A name already taken is a correction, not a failure.** It is one
// word to change. The sheet used to decide that inside its catch block
// with `'$e'.contains(…)`, so the rule could only be reached by pumping
// the sheet and reading a snackbar — and a reworded server message would
// have quietly downgraded the correction back into "something went
// wrong" with nothing going red.
import 'package:deskilo/core/demo/data/workspace_repository.dart';
import 'package:deskilo/features/workspace/application/start_conversation.dart';
import 'package:flutter_test/flutter_test.dart';

/// A repository that refuses the way the server does.
class _NameTaken extends FakeWorkspaceRepository {
  _NameTaken() : super.withWorkspace();

  @override
  Future<String> createGroupConversation(
    String workspaceId, {
    required String title,
    required List<String> memberIds,
  }) =>
      throw StateError('PostgrestException: $kGroupNameTakenError');
}

/// A repository that fails for some other reason entirely.
class _Broken extends FakeWorkspaceRepository {
  _Broken() : super.withWorkspace();

  @override
  Future<String> createGroupConversation(
    String workspaceId, {
    required String title,
    required List<String> memberIds,
  }) =>
      throw StateError('connection closed');
}

void main() {
  group('what a second person means', () {
    test('in the hub, the switch decides', () {
      expect(Conversations.isGroup(hub: true, groupMode: true, selected: 1),
          isTrue);
      expect(Conversations.isGroup(hub: true, groupMode: false, selected: 3),
          isFalse,
          reason: 'the hub has a switch and it is the answer');
    });

    test('outside it, two people IS a group', () {
      expect(Conversations.isGroup(hub: false, groupMode: false, selected: 2),
          isTrue,
          reason: 'nobody chose a mode — they chose people, and a thread '
              'with two others is not a one-to-one');
      expect(Conversations.isGroup(hub: false, groupMode: false, selected: 1),
          isFalse);
    });
  });

  group('a name already taken', () {
    test('is its own answer, so the sheet can say "pick another"',
        () async {
      final outcome = await Conversations(_NameTaken()).start(
        workspaceId: 'ws-1',
        group: true,
        title: 'Bureau',
        memberIds: const ['m-1', 'm-2'],
      );

      expect(outcome, isA<GroupNameTaken>(),
          reason: 'one word to change is a correction, and the whole '
              'difference between that and a dead end');
    });

    test('and any OTHER failure still is one', () async {
      await expectLater(
        Conversations(_Broken()).start(
          workspaceId: 'ws-1',
          group: true,
          title: 'Bureau',
          memberIds: const ['m-1', 'm-2'],
        ),
        throwsA(isA<StateError>()),
        reason: 'swallowing everything here would turn a dropped '
            'connection into "pick another name"',
      );
    });
  });

  test('a one-to-one opens against the single person chosen', () async {
    final repo = FakeWorkspaceRepository.withWorkspace();

    final outcome = await Conversations(repo).start(
      workspaceId: 'ws-1',
      group: false,
      title: '',
      memberIds: const ['m-2'],
    );

    expect(outcome, isA<ConversationStarted>());
    expect((outcome as ConversationStarted).id, isNotEmpty);
  });

  test('a group is created under its trimmed name', () async {
    final repo = FakeWorkspaceRepository.withWorkspace();

    await Conversations(repo).start(
      workspaceId: 'ws-1',
      group: true,
      title: '  Bureau  ',
      memberIds: const ['m-1', 'm-2'],
    );

    expect(repo.conversations.last.title, 'Bureau',
        reason: 'the sheet used to trim on the way in; the rule belongs '
            'with the decision, not with the text field');
  });
}
