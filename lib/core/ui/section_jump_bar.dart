// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2313 — the one way a long form lists its sections.
//
// Settings and Workspace each listed their sections as wrapped text
// links, two rows of them on a narrow column, while other screens used
// tabs or pills for the same job. A section bar is now a row of pills;
// each pill opens its section and scrolls to it. A destructive section
// reads in the error colour.
import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// One entry of a [SectionJumpBar].
class SectionJump {
  const SectionJump({
    required this.key,
    required this.label,
    required this.onPressed,
    this.destructive = false,
  });

  /// The pill's widget key (kept from the links it replaces).
  final String key;
  final String label;
  final VoidCallback onPressed;

  /// The danger zone: drawn in the error colour.
  final bool destructive;
}

/// The row of section pills above a long form.
class SectionJumpBar extends StatelessWidget {
  const SectionJumpBar({required this.items, super.key});

  final List<SectionJump> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      // A Wrap, not a sideways scroller: a second Scrollable on these
      // screens would make every "scroll until visible" ambiguous, and a
      // section list is short enough to flow onto a second row of pills.
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (final item in items)
            ActionChip(
              key: ValueKey(item.key),
              label: Text(item.label),
              labelStyle: item.destructive
                  ? TextStyle(color: scheme.error)
                  : null,
              side: item.destructive
                  ? BorderSide(color: scheme.error.withValues(alpha: .5))
                  : null,
              onPressed: item.onPressed,
            ),
        ],
      ),
    );
  }
}
