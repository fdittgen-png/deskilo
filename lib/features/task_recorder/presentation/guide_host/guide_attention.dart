// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The task wizard's pointer: what the person is told to look at.
//
// Three things draw the eye to the control the step names, none of which
// takes a tap (the whole layer is ignored by the pointer):
//   * a ring that pulses and alternates between the theme's two accent
//     colours, so it reads on any background;
//   * an arrow beside the control, on the side that has room, that bobs
//     toward it;
//   * a flash — one ring that expands from the control and fades — each
//     time the wizard moves to a new control.
// The pulse runs a bounded number of cycles after the step appears and
// then rests on a steady ring (every animation in the app is finite, so a
// screen can always settle). With motion off — the workspace flag or the
// platform's reduced-motion setting — the ring and the arrow are drawn
// still and nothing flashes.

import 'package:flutter/material.dart';

import '../../../../core/motion/motion.dart';
import '../../../../core/theme/app_radius.dart';

/// How many pulse cycles run after a step appears (each ~1.6 s, there and
/// back) before the highlight rests.
const int guidePulseCycles = 6;

class GuideAttention extends StatefulWidget {
  const GuideAttention({required this.target, required this.bounds, super.key});

  /// The control, in this layer's coordinates.
  final Rect target;

  /// The layer's own size, to choose the side the arrow has room on.
  final Size bounds;

  @override
  State<GuideAttention> createState() => _GuideAttentionState();
}

class _GuideAttentionState extends State<GuideAttention>
    with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MotionSettings.enabledOf(context)) {
      _flash.forward();
      // there and back, `guidePulseCycles` times, then it rests.
      _pulse.repeat(reverse: true, count: guidePulseCycles * 2);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shadow = scheme.shadow.withValues(alpha: 0.4);
    final target = widget.target;
    final side = _side(target, widget.bounds);
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulse, _flash]),
        builder: (context, _) {
          // Resting (and motion off): the first accent, steady.
          final t = _pulse.isAnimating ? Curves.easeInOut.transform(_pulse.value) : 0.0;
          final color = Color.lerp(scheme.primary, scheme.tertiary, t)!;
          final ring = target.inflate(6 + 3 * t);
          final flash = _flash.value;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              if (_flash.isAnimating)
                Positioned.fromRect(
                  rect: target.inflate(6 + 44 * flash),
                  child: DecoratedBox(
                    key: const ValueKey('guide-host-flash'),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.7 * (1 - flash)),
                        width: 3,
                      ),
                      borderRadius: AppRadius.lgAll,
                    ),
                  ),
                ),
              Positioned.fromRect(
                rect: ring,
                child: DecoratedBox(
                  key: const ValueKey('guide-host-ring'),
                  decoration: BoxDecoration(
                    border: Border.all(color: color, width: 3 + 2 * t),
                    borderRadius: AppRadius.lgAll,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.45 * t),
                        blurRadius: 10 + 10 * t,
                        spreadRadius: 2 * t,
                      ),
                    ],
                  ),
                ),
              ),
              _arrow(side, ring, color, shadow, t),
            ],
          );
        },
      ),
    );
  }

  Widget _arrow(_Side side, Rect ring, Color color, Color shadow, double t) {
    const size = 40.0;
    const gap = 2.0;
    final bob = 8 * t; // toward the control
    final icon = switch (side) {
      _Side.above => Icons.arrow_downward_rounded,
      _Side.below => Icons.arrow_upward_rounded,
      _Side.left => Icons.arrow_forward_rounded,
      _Side.right => Icons.arrow_back_rounded,
    };
    final Offset origin = switch (side) {
      _Side.above => Offset(ring.center.dx - size / 2, ring.top - size - gap + bob),
      _Side.below => Offset(ring.center.dx - size / 2, ring.bottom + gap - bob),
      _Side.left => Offset(ring.left - size - gap + bob, ring.center.dy - size / 2),
      _Side.right => Offset(ring.right + gap - bob, ring.center.dy - size / 2),
    };
    return Positioned(
      left: origin.dx.clamp(0.0, (widget.bounds.width - size).clamp(0.0, double.infinity)),
      top: origin.dy.clamp(0.0, (widget.bounds.height - size).clamp(0.0, double.infinity)),
      width: size,
      height: size,
      child: Icon(
        icon,
        key: const ValueKey('guide-host-pointer'),
        size: size,
        color: color,
        shadows: [Shadow(blurRadius: 4, color: shadow)],
      ),
    );
  }
}

enum _Side { above, below, left, right }

/// Where the arrow stands: above the control when there is room for it,
/// else below, else beside it.
_Side _side(Rect target, Size bounds) {
  const need = 48.0;
  if (target.top - 6 >= need) return _Side.above;
  if (bounds.height - target.bottom - 6 >= need) return _Side.below;
  if (target.left - 6 >= need) return _Side.left;
  return _Side.right;
}
