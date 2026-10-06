// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../domain/message_marks.dart';

/// The emoji people put on a message, under its bubble: each emoji with how
/// many chose it, mine highlighted; tapping one toggles mine.
class ReactionStrip extends StatelessWidget {
  const ReactionStrip({
    super.key,
    required this.messageId,
    required this.reactions,
    this.onReact,
  });

  final String messageId;
  final List<ReactionCount> reactions;
  final ValueChanged<String>? onReact;

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final r in reactions)
            InkWell(
              key: ValueKey('reaction-$messageId-${r.emoji}'),
              borderRadius: AppRadius.lgAll,
              onTap: onReact == null ? null : () => onReact!(r.emoji),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: r.mine
                      ? scheme.secondaryContainer
                      : scheme.surfaceContainerHigh,
                  border: Border.all(
                    color: r.mine ? scheme.secondary : scheme.outlineVariant,
                  ),
                  borderRadius: AppRadius.lgAll,
                ),
                child: Text(
                  r.count > 1 ? '${r.emoji} ${r.count}' : r.emoji,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
