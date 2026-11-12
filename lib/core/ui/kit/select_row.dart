// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-a -- a line of a flow's list that is chosen or not: a checkbox,
// what it is, and its amount. The whole line toggles.
import 'package:flutter/material.dart';

import '../adaptive/task_surface.dart';
import 'kit_metrics.dart';

class SelectRow extends StatelessWidget {
  const SelectRow({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.title,
    required this.caption,
    required this.amount,
    this.enabled = true,
  });

  final bool selected;
  final ValueChanged<bool> onChanged;
  final String title;
  final Widget caption;
  final String amount;

  /// A line that cannot be ticked (it needs a fix): dimmed, and its
  /// semantics say disabled.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The whole line is the one control; the box only shows its state.
    return Semantics(
      checked: selected,
      enabled: enabled,
      child: InkWell(
        onTap: enabled
            ? () {
                TaskSession.maybeOf(context)?.markChanged();
                onChanged(!selected);
              }
            : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: IgnorePointer(
                    // recorder-key-exempt: a picture of the line's state
                    child: Checkbox(
                      value: selected,
                      onChanged: enabled ? (_) {} : null,
                    ),
                  ),
                ),
                const SizedBox(width: KitMetrics.gap / 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: enabled
                              ? null
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      DefaultTextStyle.merge(
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        child: caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: KitMetrics.gap),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    amount,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
