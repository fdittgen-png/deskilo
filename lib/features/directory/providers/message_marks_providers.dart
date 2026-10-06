// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
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
