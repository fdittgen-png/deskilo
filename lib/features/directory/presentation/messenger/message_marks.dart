// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/messenger.dart';

/// #1824 — the marks every messenger draws the same way, whichever
/// thread shows them: the origin line of a forwarded copy and the system
/// line of a forward or a screenshot. One widget each, so a space thread
/// and an account thread cannot tell the same event two ways.

/// "Forwarded from … · written by …" above a forwarded copy. Its readers
/// see where it came from; nothing about the copy is left to guess.
class ForwardOriginLine extends StatelessWidget {
  const ForwardOriginLine({super.key, required this.origin, this.color});

  final ForwardOrigin origin;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final text =
        l10n?.messengerForwardedFrom(origin.contextLabel, origin.authorName) ??
        'Forwarded from ${origin.contextLabel} · written by ${origin.authorName}';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shortcut, size: 14, color: color),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              text,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The sentence a system line says, in the reader's language.
String noticeText(AppLocalizations? l10n, MessageNotice notice) =>
    switch (notice.kind) {
      // A personal conversation is never named to the source (0316).
      NoticeKind.forwarded when notice.targetLabel.isEmpty =>
        l10n?.messengerNoticeForwardedPrivate(notice.actorName) ??
            '${notice.actorName} forwarded a message of this conversation '
                'to a personal conversation.',
      NoticeKind.forwarded =>
        l10n?.messengerNoticeForwarded(notice.actorName, notice.targetLabel) ??
            '${notice.actorName} forwarded a message of this conversation '
                'to ${notice.targetLabel}.',
      NoticeKind.captured =>
        l10n?.messengerNoticeCaptured(notice.actorName) ??
            '${notice.actorName} took a screenshot of this conversation.',
    };

/// A centred system line in the thread: not a message, no actions.
class MessageNoticeLine extends StatelessWidget {
  const MessageNoticeLine({super.key, required this.notice});

  final MessageNotice notice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = noticeText(AppLocalizations.of(context), notice);
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.lgAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              notice.kind == NoticeKind.captured
                  ? Icons.screenshot_monitor_outlined
                  : Icons.shortcut,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
