// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2313 — a space's colour drawn in its pattern: what tells one
// workspace from another on its card on Me, its chip and the entry
// transition. The pattern is a lighter tone of the colour itself, so a
// space keeps one colour and gains a texture, never a second palette.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/workspace.dart';
import '../../domain/workspace_branding.dart';

/// #2313 — [space]'s own colour and pattern, or null when it shows none
/// (branding off, or no colour chosen).
({Color color, BrandPattern? pattern})? spaceBrand(Workspace space) {
  if (!brandingOn(space)) return null;
  final branding = WorkspaceBranding.fromJson(space.branding);
  final seed = branding.seedArgb;
  if (seed == null) return null;
  return (color: Color(seed), pattern: branding.pattern);
}

/// Fills its box with [color] drawn in [pattern] ([BrandPattern.solid]
/// or null: a plain fill), with [child] on top.
class BrandSwatch extends StatelessWidget {
  const BrandSwatch({
    required this.color,
    this.pattern,
    this.child,
    this.borderRadius,
    super.key,
  });

  final Color color;
  final BrandPattern? pattern;
  final Widget? child;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final painted = CustomPaint(
      painter: BrandPatternPainter(color: color, pattern: pattern),
      child: child ?? const SizedBox.expand(),
    );
    return borderRadius == null
        ? painted
        : ClipRRect(borderRadius: borderRadius!, child: painted);
  }
}

class BrandPatternPainter extends CustomPainter {
  const BrandPatternPainter({required this.color, this.pattern});

  final Color color;
  final BrandPattern? pattern;

  /// The pattern's ink: the colour, lighter on a dark colour and darker
  /// on a light one, so the texture reads on both.
  Color get ink {
    final light = color.computeLuminance() > 0.45;
    return Color.lerp(color, light ? Colors.black : Colors.white, 0.28)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
    final p = Paint()
      ..color = ink
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    switch (pattern) {
      case null || BrandPattern.solid:
        break;
      case BrandPattern.stripes:
        const step = 14.0;
        for (var x = -size.height; x < size.width; x += step) {
          canvas.drawLine(
            Offset(x, size.height),
            Offset(x + size.height, 0),
            p,
          );
        }
      case BrandPattern.dots:
        final dot = Paint()..color = ink;
        const step = 12.0;
        for (var y = step / 2; y < size.height; y += step) {
          for (var x = step / 2; x < size.width; x += step) {
            canvas.drawCircle(Offset(x, y), 2.4, dot);
          }
        }
      case BrandPattern.grid:
        p.strokeWidth = 1.5;
        const step = 12.0;
        for (var x = 0.0; x <= size.width; x += step) {
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
        }
        for (var y = 0.0; y <= size.height; y += step) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
        }
      case BrandPattern.waves:
        p.strokeWidth = 2;
        const step = 12.0;
        for (var y = step / 2; y < size.height + step; y += step) {
          final path = Path()..moveTo(0, y);
          for (var x = 0.0; x <= size.width; x += 2) {
            path.lineTo(x, y + math.sin(x / 6) * 3);
          }
          canvas.drawPath(path, p);
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BrandPatternPainter old) =>
      old.color != color || old.pattern != pattern;
}
