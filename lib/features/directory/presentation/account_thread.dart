// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/directory_providers.dart';

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
  final _body = TextEditingController();
  final _pages = <({DateTime at, String id})>[];
  String? _conversation;
  bool _busy = false, _loading = true, _failed = false;
  Timer? _refresh;
  @override
  void initState() {
    super.initState();
    _conversation = widget.conversation;
    Future.microtask(_lookup);
    _refresh = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted &&
          _conversation != null &&
          _pages.isEmpty &&
          ref.read(authStateProvider).value == widget.account) {
        ref.invalidate(
          accountMessagesProvider(_conversation!, source: widget.source),
        );
      }
    });
  }

  @override
  void dispose() {
    _body.dispose();
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> _lookup() async {
    if (_conversation != null) {
      setState(() => _loading = false);
      return;
    }
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
          setState(() => _conversation = id);
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

  Future<void> _send() async {
    if (_busy ||
        _body.text.trim().isEmpty ||
        ref.read(authStateProvider).value != widget.account) {
      return;
    }
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    String? id;
    final ok = await runGuarded(
      context,
      domain: 'messages',
      message: 'send account message failed',
      errorText:
          l?.applicationReplyFailed ??
          'Your message was not sent. Your draft is kept; please try again.',
      action: () async {
        id = await ref
            .read(accountContactActionsProvider(source: widget.source))
            .send(widget.recipient, _body.text.trim());
      },
    );
    if (!mounted || ref.read(authStateProvider).value != widget.account) return;
    setState(() {
      _busy = false;
      if (ok) {
        _body.clear();
        _pages.clear();
        _conversation = id;
        _failed = false;
      }
    });
    if (ok) {
      ref.invalidate(accountMessagesProvider(id!, source: widget.source));
      ref.invalidate(accountConversationsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(authStateProvider).value != widget.account) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    final cursor = _pages.lastOrNull;
    final provider = _conversation == null
        ? null
        : accountMessagesProvider(
            _conversation!,
            source: widget.source,
            beforeAt: cursor?.at,
            beforeId: cursor?.id,
          );
    final messages = provider == null ? null : ref.watch(provider);
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const LoadingView()
                : _failed
                ? Center(
                    child: TextButton(
                      onPressed: _lookup,
                      child: Text(l?.commonRetry ?? 'Try again'),
                    ),
                  )
                : switch (messages) {
                    AsyncData(value: final rows) => ListView(
                      padding: AppSpacing.mdAll,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              tooltip: MaterialLocalizations.of(context)
                                  .previousPageTooltip,
                              onPressed: rows.length < 50
                                  ? null
                                  : () => setState(
                                      () => _pages.add((
                                        at: DateTime.parse(
                                          rows.last['created_at'] as String,
                                        ),
                                        id: rows.last['id'] as String,
                                      )),
                                    ),
                              icon: const Icon(Icons.chevron_left),
                            ),
                            IconButton(
                              tooltip: MaterialLocalizations.of(context)
                                  .nextPageTooltip,
                              onPressed: _pages.isEmpty
                                  ? null
                                  : () => setState(() => _pages.removeLast()),
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                        for (final row in rows.reversed)
                          Card(
                            color: row['is_mine'] == true
                                ? Theme.of(context)
                                      .colorScheme
                                      .secondaryContainer
                                : null,
                            child: Padding(
                              padding: AppSpacing.mdAll,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SelectableText(row['body'] as String),
                                  Text(
                                    DateFormat.yMd(
                                      Localizations.localeOf(context)
                                          .toLanguageTag(),
                                    ).add_jm().format(
                                      DateTime.parse(
                                        row['created_at'] as String,
                                      ).toLocal(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    AsyncError() => Center(
                      child: TextButton(
                        onPressed: () => ref.invalidate(provider!),
                        child: Text(l?.commonRetry ?? 'Try again'),
                      ),
                    ),
                    null => Center(
                      child: Text(
                        l?.applicationNoMessages ?? 'No messages yet.',
                      ),
                    ),
                    _ => const LoadingView(),
                  },
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: AppSpacing.mdAll,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _body,
                      enabled: !_busy,
                      maxLength: 4000,
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: l?.memberNoteHint ?? 'Your message',
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l?.memberNoteSend ?? 'Send',
                    onPressed: _busy ? null : _send,
                    icon: const Icon(Icons.send_outlined),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
