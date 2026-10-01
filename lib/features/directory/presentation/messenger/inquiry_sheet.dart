// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/messenger.dart';
import '../../domain/public_workspace.dart';
import '../../providers/messenger_providers.dart';
import 'context_thread_screen.dart';
import 'refusal_text.dart';

/// #1824 — "Write to the hosts" on a published space page.
///
/// The person sees WHO will read the message before writing it: the
/// space's owners and the admins who agreed to be its public contacts
/// (`space_host_roster`). The message opens an inquiry — a conversation
/// addressed to the space, not to one admin's private inbox — and the
/// sheet continues into its thread.
Future<void> showInquirySheet(
  BuildContext context,
  PublicWorkspace workspace,
) async {
  final inquiry = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => InquirySheet(workspace: workspace),
  );
  if (inquiry == null || !context.mounted) return;
  final l10n = AppLocalizations.of(context);
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ContextThreadScreen(
        kind: MessageContextKind.inquiryOut,
        contextId: inquiry,
        title: workspace.name,
        subtitle:
            l10n?.messengerContextInquiryOut(workspace.name) ??
            'Your inquiry to ${workspace.name}',
        source: workspace.source,
      ),
    ),
  );
}

class InquirySheet extends ConsumerStatefulWidget {
  const InquirySheet({super.key, required this.workspace});

  final PublicWorkspace workspace;

  @override
  ConsumerState<InquirySheet> createState() => _InquirySheetState();
}

class _InquirySheetState extends ConsumerState<InquirySheet> {
  final _body = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  String get _source => widget.workspace.source;

  Future<void> _send() async {
    final text = _body.text.trim();
    if (_busy || text.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    String? inquiry;
    final ok = await runMessenger(
      context,
      message: 'start inquiry failed',
      errorText:
          l10n?.applicationReplyFailed ??
          'Your message was not sent. Your draft is kept; please try again.',
      action: () async {
        inquiry = await ref
            .read(messengerActionsProvider(source: _source))
            .startInquiry(widget.workspace.id, text);
      },
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ref.invalidate(unifiedInboxProvider);
      Navigator.of(context).pop(inquiry);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = hostRosterProvider(widget.workspace.id, source: _source);
    final roster = ref.watch(provider);
    final media = MediaQuery.of(context);
    final hosts = roster.value ?? const <HostRosterEntry>[];
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        key: const ValueKey('inquiry-sheet'),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * .85),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: AppSpacing.lgAll,
                child: Text(
                  l10n?.messengerWriteToHosts ?? 'Write to the hosts',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Flexible(
                child: switch (roster) {
                  AsyncData() when hosts.isEmpty => Padding(
                    padding: AppSpacing.lgAll,
                    child: Text(
                      l10n?.messengerHostsNone ??
                          'This space has nobody answering messages right now.',
                      key: const ValueKey('inquiry-no-hosts'),
                    ),
                  ),
                  AsyncData() => ListView(
                    shrinkWrap: true,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        child: Text(
                          l10n?.messengerHostsIntro ?? 'Your message is read by these hosts of the space:',
                        ),
                      ),
                      for (final (i, host) in hosts.indexed)
                        ListTile(
                          key: ValueKey('inquiry-host-$i'),
                          leading: const Icon(Icons.person_outline),
                          title: Text(host.name),
                          subtitle: Text(
                            host.isOwner
                                ? (l10n?.portalOwner ?? 'Owner')
                                : (l10n?.portalAdmin ?? 'Administrator'),
                          ),
                        ),
                    ],
                  ),
                  AsyncError() => Center(
                    child: TextButton(
                      key: const ValueKey('inquiry-roster-retry'),
                      onPressed: () => ref.invalidate(provider),
                      child: Text(l10n?.commonRetry ?? 'Try again'),
                    ),
                  ),
                  _ => const LoadingView(),
                },
              ),
              if (hosts.isNotEmpty)
                Padding(
                  padding: AppSpacing.lgAll,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        key: const ValueKey('inquiry-body'),
                        controller: _body,
                        enabled: !_busy,
                        maxLength: MessengerRules.maxBody,
                        minLines: 2,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: l10n?.memberNoteHint ?? 'Your message',
                        ),
                      ),
                      FilledButton.icon(
                        key: const ValueKey('inquiry-send'),
                        onPressed: _busy ? null : _send,
                        icon: const Icon(Icons.send_outlined),
                        label: Text(
                          l10n?.messengerInquirySend ?? 'Send inquiry',
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
