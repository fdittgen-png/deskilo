// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/messenger.dart';
import '../../../workspace/presentation/widgets/note_check.dart';
import 'message_marks.dart';

/// #1824 — one message of an account conversation, an inquiry or a
/// space conversation opened from the unified inbox: its origin line when
/// it is a forward, its receipt when it is mine, and the way into its
/// actions. A system line renders as [MessageNoticeLine] instead.
class ContextBubble extends ConsumerWidget {
  const ContextBubble({super.key, required this.message, this.onActions});

  final ContextMessage message;
  final VoidCallback? onActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notice = message.notice;
    if (notice != null) {
      return MessageNoticeLine(
        key: ValueKey('context-notice-${message.id}'),
        notice: notice,
      );
    }
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final mine = message.mine;
    final fg = mine
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;
    final muted = mine
        ? fg.withValues(alpha: .7)
        : theme.colorScheme.onSurfaceVariant;
    final when = ref.watch(appFormatProvider).dateTime(message.createdAt);
    final read = message.readAt != null;
    // Beside the bubble, never inside it: a long press on the bubble
    // must not land on the button's tooltip.
    final actions = onActions == null
        ? null
        : IconButton(
            key: ValueKey('context-actions-${message.id}'),
            tooltip: l10n?.messengerMessageActions ?? 'Message actions',
            visualDensity: VisualDensity.compact,
            iconSize: 18,
            color: theme.colorScheme.onSurfaceVariant,
            onPressed: onActions,
            icon: const Icon(Icons.more_horiz),
          );
    final bubble = GestureDetector(
      key: ValueKey('context-bubble-${message.id}'),
      onLongPress: onActions,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: mine
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.lgAll,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!mine && message.authorName.isNotEmpty)
              Text(
                message.authorName,
                style: theme.textTheme.labelMedium?.copyWith(color: muted),
              ),
            if (message.forwardedFrom != null)
              ForwardOriginLine(
                key: ValueKey('forward-origin-${message.id}'),
                origin: message.forwardedFrom!,
                color: muted,
              ),
            Text(
              message.body,
              style: theme.textTheme.bodyMedium?.copyWith(color: fg),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.noForward)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: Icon(
                      Icons.lock_outline,
                      key: ValueKey('context-locked-${message.id}'),
                      size: 12,
                      color: muted,
                    ),
                  ),
                Text(
                  when,
                  style: theme.textTheme.labelSmall?.copyWith(color: muted),
                ),
                if (mine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    read ? Icons.done_all : Icons.done,
                    key: ValueKey(
                      read
                          ? 'context-read-${message.id}'
                          : 'context-delivered-${message.id}',
                    ),
                    size: 14,
                    semanticLabel: read
                        ? (l10n?.messengerRead ?? 'Read')
                        : (l10n?.messengerDelivered ?? 'Delivered'),
                    color: read ? noteReadBlue : muted,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: actions == null
          ? bubble
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (mine) actions,
                Flexible(child: bubble),
                if (!mine) actions,
              ],
            ),
    );
  }
}
