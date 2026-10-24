// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../workspace/presentation/widgets/conversation_thread.dart';
import '../../../workspace/providers/conversation_providers.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/conversation_target.dart';
import '../../domain/messenger.dart';
import '../../providers/messenger_providers.dart';
import 'guarded_composer.dart';

/// A conversation of one of my workspaces on this server, in the
/// messenger's pane (the focused page on a phone): the workspace's own
/// thread — names, quotes, references to reservations, spaces and
/// documents — read while the messenger lends it that workspace.
///
/// Opening it is reading it: the read mark goes out once, when the
/// thread opens, never for a row that was only listed.
class WorkspaceConversationPane extends ConsumerStatefulWidget {
  const WorkspaceConversationPane({
    super.key,
    required this.entry,
    this.onBack,
  });

  final InboxEntry entry;

  /// The focused page's Back; none beside the list.
  final VoidCallback? onBack;

  @override
  ConsumerState<WorkspaceConversationPane> createState() => _PaneState();
}

class _PaneState extends ConsumerState<WorkspaceConversationPane> {
  bool _lentAgain = false;

  @override
  void initState() {
    super.initState();
    unawaited(Future.microtask(_markRead));
  }

  Future<void> _markRead() async {
    if (!mounted) return;
    try {
      await ref
          .read(messengerActionsProvider())
          .markRead(MessageContextKind.space, widget.entry.contextId);
      if (mounted) ref.invalidate(messengerInboxProvider);
    } on Object catch (e, st) {
      // A receipt that does not move must never block reading.
      TraceLogger.instance.warn(
        'messages',
        'mark workspace conversation read failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final workspace = widget.entry.workspaceId;
    final active = ref.watch(activeWorkspaceIdProvider);
    if (active.hasValue && active.value != workspace) {
      // Another thread gave its own lent workspace back after this one
      // was lent: this conversation's workspace is lent again, once.
      if (!_lentAgain && workspace != null) {
        _lentAgain = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(activeWorkspaceIdProvider.notifier).activate(workspace);
          }
        });
      }
      return const Scaffold(body: LoadingView());
    }
    if (ref.watch(currentWorkspaceProvider).value?.id != workspace) {
      return const Scaffold(body: LoadingView());
    }
    return Scaffold(
      key: const ValueKey('workspace-thread-pane'),
      body: SafeArea(
        child: ConversationThread(
          conversationId: widget.entry.contextId,
          asPage: true,
          inPane: true,
          onBack: widget.onBack,
          // The account thread's rules: one send at a time, also across
          // a thread opened again; no answer in time is "Delivery not
          // confirmed", never resent on its own.
          composerFrame: (attempt, build) => GuardedComposer(
            draftKey: conversationDraftKey(
              source: '',
              kind: MessageContextKind.space,
              contextId: widget.entry.contextId,
            ),
            attempt: attempt,
            build: build,
            onReview: () => ref.invalidate(
                conversationMessagesProvider(widget.entry.contextId)),
          ),
        ),
      ),
    );
  }
}
