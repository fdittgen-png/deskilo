// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/messenger.dart';
import '../../providers/messenger_providers.dart';

/// #1824 — "What happened" to one message: sent, read by, forwarded by
/// whom and where to, deleted, screenshots. The server decides what the
/// reader may see: the original conversation's participants see every
/// event, a forward's readers only its provenance.
Future<void> showMessageHistory(
  BuildContext context, {
  required MessageKind kind,
  required String messageId,
  String source = '',
}) => showAppSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) =>
      _MessageHistorySheet(kind: kind, messageId: messageId, source: source),
);

class _MessageHistorySheet extends ConsumerWidget {
  const _MessageHistorySheet({
    required this.kind,
    required this.messageId,
    this.source = '',
  });

  final MessageKind kind;
  final String messageId;
  final String source;

  static String line(AppLocalizations l10n, MessageEvent e) {
    final actor = e.actorName;
    return switch (e.event) {
      'sent' => l10n.messengerEventSent(actor),
      'read' => l10n.messengerEventRead(actor),
      'forwarded' when e.targetLabel.isEmpty =>
        l10n.messengerEventForwardedPrivate(actor),
      'forwarded' =>
        l10n.messengerEventForwarded(actor, e.targetLabel),
      // On a copy: where the original was written.
      'forwarded_from' =>
        l10n.messengerEventForwardedFrom(actor, e.targetLabel),
      'deleted' => l10n.messengerEventDeleted(actor),
      'captured' =>
        l10n.messengerEventCaptured(actor),
      _ => l10n.messengerEventOther(e.event, actor),
    };
  }

  static IconData icon(MessageEvent e) => switch (e.event) {
    'sent' => Icons.send_outlined,
    'read' => Icons.done_all,
    'forwarded' || 'forwarded_from' => Icons.shortcut,
    'deleted' => Icons.delete_outline,
    'captured' => Icons.screenshot_monitor_outlined,
    _ => Icons.circle_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final format = ref.watch(appFormatProvider);
    final provider = messageHistoryProvider(kind, messageId, source: source);
    final events = ref.watch(provider);
    return SafeArea(
      key: const ValueKey('message-history-sheet'),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * .85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: AppSpacing.lgAll,
              child: Text(
                l10n.messengerHistory,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Flexible(
              child: switch (events) {
                AsyncData(value: final list) when list.isEmpty => Padding(
                  padding: AppSpacing.lgAll,
                  child: Text(
                    l10n.messengerHistoryEmpty,
                    key: const ValueKey('message-history-empty'),
                  ),
                ),
                AsyncData(value: final list) => ListView(
                  shrinkWrap: true,
                  children: [
                    for (final (i, e) in list.indexed)
                      ListTile(
                        key: ValueKey('message-history-$i'),
                        leading: Icon(icon(e)),
                        title: Text(line(l10n, e)),
                        subtitle: Text(format.dateTime(e.at)),
                      ),
                  ],
                ),
                AsyncError() => Center(
                  child: TextButton(
                    key: const ValueKey('message-history-retry'),
                    onPressed: () => ref.invalidate(provider),
                    child: Text(l10n.commonRetry),
                  ),
                ),
                _ => const LoadingView(),
              },
            ),
          ],
        ),
      ),
    );
  }
}
