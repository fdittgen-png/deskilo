// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-a -- what happened, as dated lines on a thread; the last one is
// "now" (what is awaited today) and is marked.
import 'package:flutter/material.dart';

import 'kit_metrics.dart';

/// One line of a [Story]: what happened and when, in words.
typedef StoryLine = ({String text, String when});

class Story extends StatelessWidget {
  const Story({super.key, required this.lines, this.now});

  final List<StoryLine> lines;

  /// What is awaited today; null when nothing is.
  final StoryLine? now;

  @override
  Widget build(BuildContext context) {
    final all = [...lines, ?now];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, line) in all.indexed)
          _StoryEntry(
            line: line,
            isNow: now != null && i == all.length - 1,
            last: i == all.length - 1,
          ),
      ],
    );
  }
}

class _StoryEntry extends StatelessWidget {
  const _StoryEntry({
    required this.line,
    required this.isNow,
    required this.last,
  });

  final StoryLine line;
  final bool isNow;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 18,
            child: Column(
              children: [
                const SizedBox(height: 5),
                SizedBox.square(
                  dimension: 10,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isNow ? scheme.primary : scheme.outline,
                    ),
                  ),
                ),
                if (!last)
                  Expanded(
                    child: VerticalDivider(
                      width: 2,
                      thickness: 1.5,
                      color: scheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: KitMetrics.gap),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.text,
                    style: isNow ? theme.textTheme.titleSmall : null,
                  ),
                  Text(
                    line.when,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
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
