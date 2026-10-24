// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../domain/conversation_target.dart';
import '../../domain/messenger.dart';
import '../../providers/conversation_pane_providers.dart';
import '../../providers/messenger_providers.dart';
import '../account_thread.dart';
import 'context_labels.dart';
import 'context_thread_screen.dart';
import 'message_requests_card.dart';
import 'open_inbox_entry.dart';
import 'unified_inbox_view.dart';

/// The messenger's layout sizes: design constants, not choices.
@visibleForTesting
abstract final class MessengerMetrics {
  /// The conversation list beside an open thread.
  static const double listWidth = 360;

  /// The narrowest thread worth laying beside the list.
  static const double minThreadWidth = 360;
}

/// Whether [width] holds the list and a thread side by side; narrower, an
/// opened conversation is the focused page and Back returns to the list.
bool messengerSplits(double width) =>
    width >= MessengerMetrics.listWidth + 1 + MessengerMetrics.minThreadWidth;

/// Me › Messages in the personal shell: the inbox and the conversation it
/// opens, laid out for the width it has.
///
/// Wide, the list keeps its 360 beside the thread, and no conversation is
/// chosen for the person (Choose a conversation). Narrow, an opened
/// conversation fills the page with its own Back, and the list waits
/// under it — hidden, not rebuilt — so Back finds its filters, search and
/// scroll as they were. A resize moves the same list and the same thread
/// between the two layouts: neither is built again, so nothing is read,
/// marked or sent twice, and a half-written message stays.
class AdaptiveMessenger extends ConsumerStatefulWidget {
  const AdaptiveMessenger({super.key});

  @override
  ConsumerState<AdaptiveMessenger> createState() => _AdaptiveMessengerState();
}

class _AdaptiveMessengerState extends ConsumerState<AdaptiveMessenger> {
  final _listKey = GlobalKey(debugLabel: 'messenger-list');
  GlobalKey? _threadKey;
  String? _threadOf;

  /// The row whose opening waits for an answer (its peer): a later tap,
  /// or another account, makes that answer stale.
  String? _pending;

  /// One thread per conversation: the same key across layouts keeps its
  /// state; another conversation is another thread.
  GlobalKey _keyOf(ConversationTarget target) {
    if (_threadOf != target.key || _threadKey == null) {
      _threadOf = target.key;
      _threadKey = GlobalKey(debugLabel: 'messenger-thread');
    }
    return _threadKey!;
  }

  Future<void> _openEntry(InboxEntry entry) async {
    if (opensInWorkspaceThread(entry)) {
      _pending = null;
      await openInboxEntry(context, ref, entry);
      return;
    }
    final selection = ref.read(conversationSelectionProvider.notifier);
    final account = ref.read(authStateProvider).value;
    _pending = entry.key;
    final peer =
        entry.peerId ??
        (entry.kind == MessageContextKind.account
            ? await inboxEntryPeer(ref, entry)
            : null);
    // Only the last tap opens, and only for the account that tapped.
    if (!mounted ||
        _pending != entry.key ||
        ref.read(authStateProvider).value != account) {
      return;
    }
    _pending = null;
    selection.open(InboxTarget(entry, peer: peer));
  }

  void _close() {
    _pending = null;
    ref.read(conversationSelectionProvider.notifier).close();
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(authStateProvider).value;
    final target = ref.watch(conversationSelectionProvider);
    return LayoutBuilder(
      builder: (context, constraints) {
        final split = messengerSplits(constraints.maxWidth);
        final list = KeyedSubtree(
          key: _listKey,
          child: Column(
            children: [
              const MessageRequestsCard(),
              Expanded(
                child: UnifiedInboxView(
                  onOpen: (entry) => unawaited(_openEntry(entry)),
                  selected: target is InboxTarget ? target.entry.key : null,
                ),
              ),
            ],
          ),
        );
        final thread = target == null || account == null
            ? null
            : KeyedSubtree(
                key: _keyOf(target),
                child: _thread(
                  context,
                  target,
                  account,
                  onBack: split ? null : _close,
                ),
              );
        return PopScope(
          // Narrow, Back closes the focused conversation first.
          canPop: split || thread == null,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _close();
          },
          child: split
              ? Row(
                  key: const ValueKey('messenger-split'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: MessengerMetrics.listWidth, child: list),
                    const VerticalDivider(width: 1),
                    Expanded(child: thread ?? const _ChooseConversation()),
                  ],
                )
              : Stack(
                  key: const ValueKey('messenger-focused'),
                  fit: StackFit.expand,
                  children: [
                    // Under a focused thread the list is kept, not shown:
                    // its tickers and its poll stop with it.
                    Offstage(
                      offstage: thread != null,
                      child: TickerMode(enabled: thread == null, child: list),
                    ),
                    ?thread,
                  ],
                ),
        );
      },
    );
  }

  Widget _thread(
    BuildContext context,
    ConversationTarget target,
    String account, {
    required VoidCallback? onBack,
  }) {
    switch (target) {
      case InboxTarget(:final entry, :final peer):
        final servers = ref.watch(serverLabelsProvider).value ?? const {};
        return ContextThreadScreen(
          kind: entry.kind,
          contextId: entry.contextId,
          title: entry.title,
          subtitle: contextSubtitle(context.l10n, entry, servers),
          source: entry.source,
          peer: peer,
          onBack: onBack,
          onClose: _close,
        );
      case PersonTarget():
        return AccountThread(
          source: target.source,
          recipient: target.recipient,
          name: target.name,
          account: account,
          conversation: target.conversation,
          onBack: onBack,
          onClose: _close,
        );
    }
  }
}

/// The wide layout's thread pane before any conversation is opened.
class _ChooseConversation extends StatelessWidget {
  const _ChooseConversation();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: AppSpacing.lgAll,
      child: Text(
        context.l10n.conversationChoose,
        key: const ValueKey('messenger-choose'),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    ),
  );
}
