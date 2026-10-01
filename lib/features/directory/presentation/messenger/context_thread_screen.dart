// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/capture/capture_shield.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/messenger.dart';
import '../../providers/messenger_providers.dart';
import 'context_bubble.dart';
import 'refusal_text.dart';
import 'message_actions_sheet.dart';

/// #1824 — one conversation of the unified inbox that is not a space
/// thread of the space I am in: an account conversation, an inquiry, or
/// a space conversation on another server or in another space.
///
/// One screen for all of them, so the receipts, the origin line of a
/// forward, the system lines and the actions look and behave the same.
/// It is always capture-protected: an account conversation belongs to
/// two people and no workspace can switch that off, and an inquiry's
/// requester is outside any space whose flag could.
class ContextThreadScreen extends ConsumerStatefulWidget {
  const ContextThreadScreen({
    super.key,
    required this.kind,
    required this.contextId,
    required this.title,
    this.subtitle = '',
    this.source = '',
    this.peer,
  });

  final MessageContextKind kind;

  /// '' for an account conversation that does not exist yet: the first
  /// message opens it.
  final String contextId;
  final String title;
  final String subtitle;
  final String source;

  /// The other person of an account conversation — who a reply goes to.
  final String? peer;

  @override
  ConsumerState<ContextThreadScreen> createState() => _ContextThreadState();
}

class _ContextThreadState extends ConsumerState<ContextThreadScreen> {
  static const _poll = Duration(seconds: 15);
  final _body = TextEditingController();
  late String _contextId = widget.contextId;
  final List<ContextMessage> _earlier = [];
  bool _busy = false;
  bool _loadingEarlier = false;
  Timer? _refresh;

  bool get _isInquiry => widget.kind.isInquiry;

  @override
  void initState() {
    super.initState();
    Future.microtask(_markRead);
    _refresh = Timer.periodic(_poll, (_) {
      if (mounted && _contextId.isNotEmpty && _earlier.isEmpty) {
        ref.invalidate(_provider);
      }
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _body.dispose();
    super.dispose();
  }

  ContextMessagesProvider get _provider =>
      contextMessagesProvider(widget.kind, _contextId, source: widget.source);

  Future<void> _markRead() async {
    if (_contextId.isEmpty || !mounted) return;
    try {
      await ref
          .read(messengerActionsProvider(source: widget.source))
          .markRead(widget.kind, _contextId);
      if (mounted) ref.invalidate(unifiedInboxProvider);
    } catch (e, st) {
      // A receipt that does not move must never block reading.
      TraceLogger.instance.warn(
        'messages',
        'mark conversation read failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _send() async {
    final text = _body.text.trim();
    if (_busy || text.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    String? landed;
    final ok = await runMessenger(
      context,
      message: 'send message failed',
      errorText:
          l10n?.applicationReplyFailed ??
          'Your message was not sent. Your draft is kept; please try again.',
      action: () async {
        landed = await ref
            .read(messengerActionsProvider(source: widget.source))
            .send(
              kind: widget.kind,
              contextId: _contextId,
              body: text,
              peer: widget.peer,
            );
      },
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        _body.clear();
        _earlier.clear();
        _contextId = landed ?? _contextId;
      }
    });
    if (ok) {
      ref
        ..invalidate(_provider)
        ..invalidate(unifiedInboxProvider);
    }
  }

  Future<void> _loadEarlier(ContextMessage oldest) async {
    if (_loadingEarlier) return;
    setState(() => _loadingEarlier = true);
    try {
      final page = await ref
          .read(messengerActionsProvider(source: widget.source))
          .messages(widget.kind, _contextId, before: oldest);
      if (mounted) setState(() => _earlier.addAll(page));
    } catch (e, st) {
      TraceLogger.instance.error(
        'messages',
        'load earlier messages failed',
        error: e,
        stackTrace: st,
      );
    } finally {
      if (mounted) setState(() => _loadingEarlier = false);
    }
  }

  Future<void> _recordCapture() async {
    if (_contextId.isEmpty) return;
    try {
      await ref
          .read(messengerActionsProvider(source: widget.source))
          .recordScreenCapture(widget.kind, _contextId);
      if (mounted) ref.invalidate(_provider);
    } catch (e, st) {
      TraceLogger.instance.error(
        'messages',
        'record screen capture failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _delete(ContextMessage message) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        content: Text(
          l10n?.messengerDeleteConfirm ??
              'Delete this message for everyone in the conversation?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(MaterialLocalizations.of(dialog).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('context-delete-confirm'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l10n?.messengerDelete ?? 'Delete message'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await runGuarded(
      context,
      domain: 'messages',
      message: 'delete account message failed',
      errorText:
          l10n?.portalActionFailed ??
          'Could not save this change. Please try again.',
      action: () => ref
          .read(messengerActionsProvider(source: widget.source))
          .deleteAccountMessage(message),
    );
    if (!ok || !mounted) return;
    setState(_earlier.clear);
    ref.invalidate(_provider);
    AppSnack.success(
      context,
      l10n?.messengerDeleted ?? 'Message deleted.',
      replace: true,
    );
  }

  Future<void> _close() async {
    final l10n = AppLocalizations.of(context);
    final ok = await runGuarded(
      context,
      domain: 'messages',
      message: 'close inquiry failed',
      errorText:
          l10n?.portalActionFailed ??
          'Could not save this change. Please try again.',
      action: () => ref
          .read(messengerActionsProvider(source: widget.source))
          .closeInquiry(_contextId),
    );
    if (!ok || !mounted) return;
    ref.invalidate(unifiedInboxProvider);
    AppSnack.success(
      context,
      l10n?.messengerInquiryClosed ?? 'Inquiry closed.',
      replace: true,
    );
  }

  void _actions(ContextMessage message) => showMessageActions(
    context,
    ref,
    MessageRef(
      kind: message.kind,
      messageId: message.id,
      contextKind: widget.kind,
      contextId: _contextId,
      mine: message.mine,
      noForward: message.noForward,
      source: widget.source,
    ),
    onDelete: message.mine && message.kind == MessageKind.accountMessage
        ? () => _delete(message)
        : null,
    onChanged: () => ref.invalidate(_provider),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final messages = _contextId.isEmpty
        ? const AsyncData<List<ContextMessage>>([])
        : ref.watch(_provider);
    if (_contextId.isNotEmpty) {
      // A message that lands while the thread is open is read as it
      // lands, so the other side's receipt and my badge stay true.
      ref.listen(_provider, (previous, next) {
        final before = previous?.value?.length ?? 0;
        final after = next.value?.length ?? 0;
        if (after > before && before > 0) _markRead();
      });
    }
    return Scaffold(
      key: const ValueKey('context-thread'),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, overflow: TextOverflow.ellipsis),
            if (widget.subtitle.isNotEmpty)
              Text(
                widget.subtitle,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          if (_isInquiry && _contextId.isNotEmpty)
            IconButton(
              key: const ValueKey('inquiry-close'),
              tooltip: l10n?.messengerInquiryClose ?? 'Close inquiry',
              onPressed: _close,
              icon: const Icon(Icons.task_alt),
            ),
        ],
      ),
      body: CaptureShield(
        onScreenshot: _recordCapture,
        child: Column(
          children: [
            Expanded(
              child: switch (messages) {
                AsyncData(value: final newest) => _list(context, [
                  ...newest,
                  ..._earlier,
                ], full: newest.length >= MessengerRules.pageSize),
                AsyncError() => Center(
                  child: TextButton(
                    key: const ValueKey('context-thread-retry'),
                    onPressed: () => ref.invalidate(_provider),
                    child: Text(l10n?.commonRetry ?? 'Try again'),
                  ),
                ),
                _ => const LoadingView(),
              },
            ),
            _composer(l10n),
          ],
        ),
      ),
    );
  }

  Widget _list(
    BuildContext context,
    List<ContextMessage> rows, {
    required bool full,
  }) {
    final l10n = AppLocalizations.of(context);
    if (rows.isEmpty) {
      return Center(
        child: Text(
          l10n?.applicationNoMessages ?? 'No messages yet.',
          key: const ValueKey('context-thread-empty'),
        ),
      );
    }
    final more = full && widget.kind != MessageContextKind.space;
    return ListView.builder(
      key: const ValueKey('context-thread-list'),
      reverse: true,
      padding: AppSpacing.mdAll,
      itemCount: rows.length + (more ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == rows.length) {
          return Center(
            child: TextButton.icon(
              key: const ValueKey('context-load-earlier'),
              onPressed: _loadingEarlier ? null : () => _loadEarlier(rows.last),
              icon: const Icon(Icons.history, size: 18),
              label: Text(
                l10n?.conversationLoadEarlier ?? 'Load earlier messages',
              ),
            ),
          );
        }
        final message = rows[index];
        return ContextBubble(
          message: message,
          onActions: message.isNotice ? null : () => _actions(message),
        );
      },
    );
  }

  Widget _composer(AppLocalizations? l10n) => SafeArea(
    top: false,
    child: Padding(
      padding: AppSpacing.mdAll,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('context-composer'),
              controller: _body,
              enabled: !_busy,
              maxLength: MessengerRules.maxBody,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: l10n?.memberNoteHint ?? 'Your message',
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('context-send'),
            tooltip: l10n?.memberNoteSend ?? 'Send',
            onPressed: _busy ? null : _send,
            icon: const Icon(Icons.send_outlined),
          ),
        ],
      ),
    ),
  );
}
