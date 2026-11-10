// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-a -- the main action under the thumb: a bar at the bottom of a
// page on a phone, never a floating button over the content. Its buttons
// share the width; the last one is the main action.
import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import 'kit_metrics.dart';

class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.actions});

  /// The buttons, the main one last.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: KitMetrics.gap,
          ),
          child: Row(
            spacing: KitMetrics.gap,
            children: [for (final a in actions) Expanded(child: a)],
          ),
        ),
      ),
    );
  }
}
