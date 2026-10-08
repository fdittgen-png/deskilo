// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/theme/seat_state_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// An opaque identifier survives photos and dark mode. At distant zoom only
/// the state symbol remains; the full name is always available in semantics.
void drawSeatIdentifier(
  Canvas canvas,
  Rect rect,
  String name,
  SeatState state, {
  required double scale,
  TextStyle? style,
}) {
  final zoom = scale.clamp(0.1, 10.0);
  final labelStyle = canvasLabelStyle.merge(style)
      .emphasised.apply(fontSizeFactor: (1 / zoom).clamp(0.45, 1.6));
  final fontSize = labelStyle.fontSize!;
  final icon = SeatStateIcons.of(state);
  final symbol = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: labelStyle.copyWith(
        color: Colors.black,
        fontFamily: icon.fontFamily,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final text = TextPainter(
    text: TextSpan(
      text: rect.width * zoom >= 40 ? name : '',
      style: labelStyle.copyWith(color: Colors.black, height: 1),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: (rect.width - symbol.width - 8).clamp(0, 1000));
  final width = (symbol.width + text.width + 8).clamp(0.0, rect.width);
  final height = (fontSize + 5).clamp(0.0, rect.height);
  final badge = Rect.fromLTWH(
    rect.center.dx - width / 2,
    rect.bottom - height,
    width,
    height,
  );
  canvas.save();
  canvas.clipRect(rect);
  canvas.drawRRect(
    RRect.fromRectAndRadius(badge, const Radius.circular(3)),
    Paint()..color = Colors.white,
  );
  symbol.paint(canvas, badge.topLeft + const Offset(3, 2));
  text.paint(canvas, badge.topLeft + Offset(symbol.width + 5, 2));
  canvas.restore();
}
