// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2313 — the minimised guide's circle, tapped: a menu of what the pane
// offers (open the guide, show me, go to page, done, skip, back, resume,
// stop), so the person can act without unfolding the pane first.
//
// It is drawn inside the guide's layer, which sits above the navigator:
// a route-based popup (showMenu, MenuAnchor) has no overlay there.

import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import 'guide_bubble.dart';

/// One entry of the circle's menu.
class GuideBubbleAction {
  const GuideBubbleAction({
    required this.id,
    required this.icon,
    required this.label,
    required this.perform,
  });

  /// Keys the entry `guide-host-menu-<id>`.
  final String id;
  final IconData icon;
  final String label;
  final VoidCallback perform;
}

/// The menu beside the circle at [bubble], kept on the layer.
class GuideBubbleMenu extends StatelessWidget {
  const GuideBubbleMenu({
    required this.bubble,
    required this.bounds,
    required this.actions,
    required this.onDismiss,
    super.key,
  });

  /// The circle's top-left corner, in the layer's coordinates.
  final Offset bubble;
  final Size bounds;
  final List<GuideBubbleAction> actions;
  final VoidCallback onDismiss;

  static const double width = 260;

  @override
  Widget build(BuildContext context) {
    // Opens towards the larger free side: above a circle in the lower
    // half, below one in the upper half; its right edge on the circle's.
    final above = bubble.dy + guideBubbleSize / 2 > bounds.height / 2;
    final left = (bubble.dx + guideBubbleSize - width).clamp(
      AppSpacing.sm,
      (bounds.width - width - AppSpacing.sm).clamp(
        AppSpacing.sm,
        double.infinity,
      ),
    );
    return Stack(
      children: [
        // A tap anywhere else closes the menu, as a popup does.
        Positioned.fill(
          child: GestureDetector(
            key: const ValueKey('guide-host-menu-barrier'),
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
          ),
        ),
        Positioned(
          left: left,
          width: width,
          top: above ? null : bubble.dy + guideBubbleSize + AppSpacing.xs,
          bottom: above ? bounds.height - bubble.dy + AppSpacing.xs : null,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight:
                  ((above
                              ? bubble.dy
                              : bounds.height - bubble.dy - guideBubbleSize) -
                          AppSpacing.md)
                      .clamp(48.0, double.infinity),
            ),
            child: Material(
              key: const ValueKey('guide-host-menu'),
              elevation: 8,
              borderRadius: AppRadius.lgAll,
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final action in actions)
                      ListTile(
                        key: ValueKey('guide-host-menu-${action.id}'),
                        leading: Icon(action.icon),
                        title: Text(action.label),
                        onTap: () {
                          onDismiss();
                          action.perform();
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
