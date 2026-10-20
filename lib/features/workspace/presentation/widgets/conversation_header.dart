// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/conversation.dart';

/// The top of a conversation: back or close, the title, a mute mark and the
/// line that says where a tap leads (the profile, or the roster of a group).
class ConversationHeader extends StatelessWidget {
  const ConversationHeader({
    super.key,
    required this.title,
    required this.conversation,
    required this.asPage,
    required this.onOpen,
  });

  final String title;
  final Conversation? conversation;
  final bool asPage;

  /// Null when the conversation is unknown or the other member is gone.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final conversation = this.conversation;
    final chevron = Icon(
      Icons.chevron_right,
      size: 16,
      color: theme.textTheme.bodySmall?.color,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        asPage ? AppSpacing.xs : AppSpacing.xl,
        asPage ? AppSpacing.xs : AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          if (asPage)
            IconButton(
              key: const ValueKey('conversation-back'),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
          Expanded(
            // The HEADER is the way into the roster — WhatsApp's idiom, and
            // the one place people look for "who is in this".
            child: InkWell(
              key: const ValueKey('conversation-header'),
              onTap: onOpen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: theme.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conversation?.muted ?? false) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ],
                  ),
                  if (!(conversation?.isGroup ?? true))
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.conversationSeeProfile,
                          style: theme.textTheme.bodySmall,
                        ),
                        chevron,
                      ],
                    ),
                  if (conversation != null && conversation.isGroup)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.conversationMemberCount(
                            conversation.participantCount,
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                        chevron,
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (!asPage)
            IconButton(
              key: const ValueKey('conversation-thread-close'),
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }
}
