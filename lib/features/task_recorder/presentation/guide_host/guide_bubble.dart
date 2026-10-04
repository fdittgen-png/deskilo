// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The task wizard, minimised: the pane folds into one small circle the
// person can drag out of the way and tap to bring the pane back. The
// pointer on the control stays; only the explanation is put aside.

import 'package:flutter/material.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../l10n/app_localizations.dart';

/// Diameter of the circle: above the 48 dp touch target.
const double guideBubbleSize = 56;

class GuideBubble extends StatelessWidget {
  const GuideBubble({
    required this.position,
    required this.bounds,
    required this.current,
    required this.total,
    required this.onMove,
    required this.onRestore,
    super.key,
  });

  /// Top-left corner, in the layer's coordinates.
  final Offset position;
  final Size bounds;
  final int current;
  final int total;
  final ValueChanged<Offset> onMove;
  final VoidCallback onRestore;

  /// Keeps the circle fully on the layer.
  Offset clamp(Offset p) => Offset(
    p.dx.clamp(0.0, (bounds.width - guideBubbleSize).clamp(0.0, double.infinity)),
    p.dy.clamp(0.0, (bounds.height - guideBubbleSize).clamp(0.0, double.infinity)),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final label =
        l10n?.guideHostRestore(current, total) ??
        'Show the guide (step $current of $total)';
    final at = clamp(position);
    return Positioned(
      left: at.dx,
      top: at.dy,
      width: guideBubbleSize,
      height: guideBubbleSize,
      child: Semantics(
        key: const ValueKey('guide-host-bubble-semantics'),
        button: true,
        label: label,
        onTap: onRestore,
        child: ExcludeSemantics(
          child: GestureDetector(
            key: const ValueKey('guide-host-bubble'),
            behavior: HitTestBehavior.opaque,
            onTap: onRestore,
            onPanUpdate: (d) => onMove(clamp(at + d.delta)),
            child: Material(
              elevation: 6,
              shape: const CircleBorder(),
              color: scheme.primaryContainer,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.assistant_navigation, color: scheme.onPrimaryContainer),
                  Positioned(
                    right: 2,
                    top: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: AppRadius.mdAll,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        child: Text(
                          '$current/$total',
                          key: const ValueKey('guide-host-bubble-progress'),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
