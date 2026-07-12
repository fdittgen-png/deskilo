// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

/// A [ShapeBorder] that carves a concave half-circle notch into the top
/// edge of the bottom bar so the central Reserve button docks into it
/// (#207, ported from the Sparkilo shell pattern).
///
/// The notch is a [CircularNotchedRectangle] scallop whose guest circle is
/// centred on the bar's TOP edge, cutting a smooth concave half-circle the
/// button nests into. When [notchRadius] is `<= 0` the border degenerates
/// to a plain rectangle.
///
/// Hosted on a [Material]: the host both clips the notch and casts a shadow
/// that follows the notched silhouette (it derives its elevation shadow
/// from this border's path), so the border itself paints nothing.
class NotchedBarBorder extends ShapeBorder {
  final double notchRadius;

  const NotchedBarBorder({required this.notchRadius});

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    if (notchRadius <= 0) return Path()..addRect(rect);
    final guest = Rect.fromCircle(
      center: Offset(rect.center.dx, rect.top),
      radius: notchRadius,
    );
    return const CircularNotchedRectangle().getOuterPath(rect, guest);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => NotchedBarBorder(notchRadius: notchRadius * t);
}
