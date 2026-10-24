// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../domain/conversation_link.dart';
import '../../domain/messenger.dart';
import '../../providers/messenger_providers.dart';

/// Follows a link to one conversation (`?conversation=`, ConversationLink)
/// wherever the messenger shows it: the conversation opens
/// ([openAuthorized]) only once the source that holds it lists it for the
/// signed-in person; a link it does not list, or cannot be asked about,
/// says so and opens nothing. Each link is answered once, and only for the
/// account it was asked for.
mixin ConversationLinkFollowing<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  ProviderSubscription<AsyncValue<UnifiedInbox>>? _linkWatch;
  String? _linkAnswered;

  /// Opens the conversation its source authorized.
  void openAuthorized(InboxEntry entry);

  /// Stops waiting on a link's source.
  void stopFollowing() {
    _linkWatch?.close();
    _linkWatch = null;
  }

  /// Waits for [raw]'s source to answer for the signed-in person, then
  /// opens the conversation or says why nothing opened — once per link.
  void followLink(String? raw) {
    stopFollowing();
    if (raw == null || raw == _linkAnswered) return;
    final link = ConversationLink.parse(raw);
    void answer(LinkVerdict verdict, InboxEntry? entry) {
      if (raw == _linkAnswered) return;
      _linkAnswered = raw;
      // The answer is the signed-in account's; another one opens nothing.
      final account = ref.read(authStateProvider).value;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        stopFollowing();
        if (!mounted || ref.read(authStateProvider).value != account) return;
        final l10n = context.l10n;
        switch (verdict) {
          case LinkVerdict.authorized:
            openAuthorized(entry!);
          case LinkVerdict.unreachable:
            AppSnack.error(context, l10n.conversationLinkUnreachable);
          case LinkVerdict.refused || LinkVerdict.pending:
            AppSnack.error(context, l10n.conversationLinkRefused);
        }
      });
    }

    if (link == null) return answer(LinkVerdict.refused, null);
    _linkWatch = ref.listenManual(messengerInboxProvider, (_, inbox) {
      final (verdict, entry) = switch (inbox) {
        AsyncData(:final value) => authorizeLink(value, link),
        AsyncError() => (LinkVerdict.unreachable, null),
        _ => (LinkVerdict.pending, null),
      };
      if (verdict != LinkVerdict.pending) answer(verdict, entry);
    }, fireImmediately: true);
  }
}
