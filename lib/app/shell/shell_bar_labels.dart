// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4098 -- the bottom bar's labels are whole or not drawn. A tab is as wide
// as the bar gives it (a fifth of a phone at 320 px), and a label at the
// largest text scale the bar allows can be wider than that in any of the five
// languages ("Calendrier"). The bar measures its longest label once and
// decides for all its tabs: every label is drawn whole, or every tab is its
// icon alone with the label as its tooltip and its spoken name. A label is
// never cut and never drawn smaller than the theme's size.
import 'package:flutter/material.dart';

/// The style of a tab's label: the selected tab's is the heavier one, so it
/// is the one measured.
TextStyle shellBarLabelStyle(BuildContext context, {required bool selected}) =>
    (Theme.of(context).textTheme.labelMedium ?? const TextStyle()).copyWith(
      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
    );

/// Room kept beside a label inside its tab.
const double _labelMargin = 4;

/// Whether every one of [labels] is whole in a tab [tabWidth] wide, at the
/// text scale of [context] (the bar's own, already clamped).
bool shellBarLabelsFit(
  BuildContext context, {
  required Iterable<String> labels,
  required double tabWidth,
}) {
  final style = shellBarLabelStyle(context, selected: true);
  final scaler = MediaQuery.textScalerOf(context);
  final direction = Directionality.of(context);
  for (final label in labels) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    if (width > tabWidth - 2 * _labelMargin) return false;
  }
  return true;
}
