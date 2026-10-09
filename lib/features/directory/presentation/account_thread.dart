// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/trace/guarded.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/providers/auth_providers.dart';
import '../domain/messenger.dart';
import '../providers/directory_providers.dart';
import '../providers/messenger_providers.dart';
import 'messenger/context_labels.dart';
import 'messenger/context_thread_screen.dart';

/// An account conversation with one person, found by who they are.
///
/// #1824 — the thread itself is the context thread every conversation of
/// the unified inbox uses: receipts, unread, deleting my own message,
/// forwarding, the history sheet and capture protection come with it.
/// What stays here is finding the conversation (the first message opens
/// it) and dropping the thread when the signed-in account changes.
class AccountThread extends ConsumerStatefulWidget {
  const AccountThread({
    super.key,
    required this.source,
    required this.recipient,
    required this.name,
    required this.account,
    this.conversation,
  });
  final String source, recipient, name, account;
  final String? conversation;
  @override
  ConsumerState<AccountThread> createState() => _ThreadState();
}

class _ThreadState extends ConsumerState<AccountThread> {
  String? _conversation;
  bool _loading = true, _failed = false;

  @override
  void initState() {
    super.initState();
    _conversation = widget.conversation;
    Future.microtask(_lookup);
  }

  Future<void> _lookup() async {
    if (_conversation != null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    final l = AppLocalizations.of(context);
    final ok = await runGuarded(
      context,
      domain: 'messages',
      message: 'load account conversation failed',
      errorText:
          l?.portalActionFailed ??
          'Could not save this change. Please try again.',
      action: () async {
        final id = await ref
            .read(accountContactActionsProvider(source: widget.source))
            .conversationWith(widget.recipient);
        if (mounted && ref.read(authStateProvider).value == widget.account) {
          _conversation = id;
        }
      },
    );
    if (mounted) {
      setState(() {
        _loading = false;
        _failed = !ok;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(authStateProvider).value != widget.account) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    if (_loading || _failed) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.name)),
        body: _loading
            ? const LoadingView()
            : Center(
                child: TextButton(
                  key: const ValueKey('account-thread-retry'),
                  onPressed: _lookup,
                  child: Text(l?.commonRetry ?? 'Try again'),
                ),
              ),
      );
    }
    final servers = ref.watch(serverLabelsProvider).value ?? const {};
    final entry = InboxEntry(
      source: widget.source,
      kind: MessageContextKind.account,
      contextId: _conversation ?? '',
      lastAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
    return ContextThreadScreen(
      key: ValueKey((widget.account, widget.source, widget.recipient)),
      kind: MessageContextKind.account,
      contextId: _conversation ?? '',
      title: widget.name,
      subtitle: contextSubtitle(l, entry, servers),
      source: widget.source,
      peer: widget.recipient,
    );
  }
}
