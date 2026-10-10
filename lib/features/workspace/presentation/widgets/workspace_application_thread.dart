// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../domain/workspace_application.dart';
import '../../providers/workspace_application_providers.dart';

class WorkspaceApplicationThread extends ConsumerStatefulWidget {
  const WorkspaceApplicationThread({
    super.key,
    required this.application,
    required this.account,
  });
  final WorkspaceApplication application;
  final String account;
  @override
  ConsumerState<WorkspaceApplicationThread> createState() => _ThreadState();
}

class _ThreadState extends ConsumerState<WorkspaceApplicationThread> {
  final _body = TextEditingController();
  final _pages = <ApplicationCursor>[];
  bool _sending = false;
  Timer? _refresh;
  @override
  void initState() {
    super.initState();
    // Private admission threads are RPC-only, not a broadly readable table.
    // Refresh only this visible thread; no account-wide background polling.
    _refresh = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_pages.isEmpty &&
          ref.read(authStateProvider).value == widget.account) {
        ref.invalidate(
          workspaceApplicationThreadProvider(widget.application.id),
        );
        ref.invalidate(workspaceApplicationsProvider);
      }
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending ||
        _body.text.trim().isEmpty ||
        ref.read(authStateProvider).value != widget.account) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    setState(() => _sending = true);
    final sent = await runGuarded(
      context,
      domain: 'workspace',
      message: 'application reply failed',
      errorText:
          l10n?.applicationReplyFailed ??
          'Your message was not sent. Your draft is kept; please try again.',
      action: () => ref
          .read(applicationRepliesProvider)
          .send(
            widget.application.id,
            _body.text,
            expectedAccount: widget.account,
          ),
    );
    if (!mounted || ref.read(authStateProvider).value != widget.account) return;
    setState(() {
      _sending = false;
      if (sent) {
        _body.clear();
        _pages.clear();
      }
    });
    if (sent) {
      ref.invalidate(workspaceApplicationThreadProvider(widget.application.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(authStateProvider).value != widget.account) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final provider = workspaceApplicationThreadProvider(
      widget.application.id,
      before: _pages.lastOrNull,
    );
    final thread = ref.watch(provider);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .8,
        child: Column(
          children: [
            ListTile(
              title: Text(widget.application.workspaceName),
              trailing: IconButton(
                key: const ValueKey('workspace-application-thread-close'),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
            Expanded(
              child: switch (thread) {
                AsyncData(value: final rows) => ListView(
                  padding: AppSpacing.mdAll,
                  children: [
                    if (rows.isEmpty)
                      Text(l10n?.applicationNoMessages ?? 'No messages yet.'),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          key: const ValueKey('workspace-application-thread-chevron-left'),
                          tooltip: MaterialLocalizations.of(context)
                              .previousPageTooltip,
                          onPressed: rows.length < 50
                              ? null
                              : () => setState(
                                  () => _pages.add(rows.last.cursor),
                                ),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        IconButton(
                          key: const ValueKey('workspace-application-thread-chevron-right'),
                          tooltip: MaterialLocalizations.of(context)
                              .nextPageTooltip,
                          onPressed: _pages.isEmpty
                              ? null
                              : () => setState(() => _pages.removeLast()),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    for (final message in rows.reversed)
                      Card(
                        color: message.isMine
                            ? Theme.of(context).colorScheme.secondaryContainer
                            : null,
                        child: Padding(
                          padding: AppSpacing.mdAll,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.authorName.isEmpty
                                    ? (l10n?.conversationUnknownMember ??
                                          'Member')
                                    : message.authorName,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              if (message.kind != 'discussion')
                                Text(
                                  message.kind == 'accepted'
                                      ? (l10n?.applicationAcceptedVote ??
                                            'Approved this request')
                                      : (l10n?.applicationRefusedVote ??
                                            'Refused this request'),
                                ),
                              if (message.body.isNotEmpty)
                                SelectableText(message.body),
                              Text(
                                MaterialLocalizations.of(
                                  context,
                                ).formatShortDate(message.createdAt.toLocal()),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                AsyncError() => Center(
                  child: TextButton(
                    key: const ValueKey('workspace-application-thread-retry'),
                    onPressed: () => ref.invalidate(provider),
                    child: Text(l10n?.commonRetry ?? 'Try again'),
                  ),
                ),
                _ => const LoadingView(),
              },
            ),
            Padding(
              padding: AppSpacing.mdAll,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _body,
                      enabled: !_sending,
                      maxLength: 4000,
                      minLines: 1,
                      maxLines: 3,
                      key: const ValueKey('application-reply'),
                      decoration: InputDecoration(
                        labelText: l10n?.memberNoteHint ?? 'Your message',
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('workspace-application-thread-member-note-send'),
                    onPressed: _sending ? null : _send,
                    tooltip: l10n?.memberNoteSend ?? 'Send',
                    icon: const Icon(Icons.send_outlined),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
