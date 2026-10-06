// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../domain/account_group.dart';
import '../domain/group_details.dart';
import '../domain/message_marks.dart';
import 'messenger_providers.dart';

/// Which thread's marks: the context (`conversation | account_conversation |
/// inquiry`), its id, and the server it lives on ('' = this one).
typedef MarksKey = ({String contextWire, String contextId, String source});

/// Reactions, my stars and the edited messages of one thread (0382).
final messageMarksProvider =
    FutureProvider.autoDispose.family<MessageMarks, MarksKey>((ref, key) {
  if (key.contextId.isEmpty || ref.watch(authStateProvider).value == null) {
    return Future.value(MessageMarks.none);
  }
  return ref
      .watch(messengerRepositoryProvider(source: key.source))
      .marks(key.contextWire, key.contextId);
});

/// My bookmarked messages across every conversation.
final starredMessagesProvider =
    FutureProvider.autoDispose<List<StarredMessage>>((ref) {
  if (ref.watch(authStateProvider).value == null) return Future.value(const []);
  return ref.watch(messengerRepositoryProvider()).starred();
});

/// A group's description and announcement-only switch (0383).
final conversationDetailsProvider = FutureProvider.autoDispose
    .family<ConversationDetails, String>((ref, id) {
  if (ref.watch(authStateProvider).value == null) {
    return Future.value(ConversationDetails.none);
  }
  return ref.watch(messengerActionsProvider()).conversationDetails(id);
});

/// Who a message of mine reached (0383).
final messageReachProvider =
    FutureProvider.autoDispose.family<MessageReach, String>((ref, id) =>
        ref.watch(messengerActionsProvider()).messageReach(id));

/// A group of people: its title, description, switches and my role (0384).
final accountGroupInfoProvider =
    FutureProvider.autoDispose.family<AccountGroupInfo, String>((ref, id) =>
        ref.watch(messengerActionsProvider()).groupInfo(id));

final accountGroupMembersProvider =
    FutureProvider.autoDispose.family<List<GroupMember>, String>((ref, id) =>
        ref.watch(messengerActionsProvider()).groupMembers(id));

/// The workspaces every member of the group belongs to — where its
/// references may point (empty: none can be shared).
final groupSharedWorkspacesProvider = FutureProvider.autoDispose
    .family<List<({String id, String name})>, String>((ref, id) => ref
        .watch(messengerRepositoryProvider())
        .groupSharedWorkspaces(id));
