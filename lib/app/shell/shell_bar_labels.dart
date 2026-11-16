// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4098 -- the bottom bar's labels are whole or not drawn. A tab is as wide
// as the bar gives it (a fifth of a phone), and a label can be wider than
// that in some languages ("Meine Finanzen") or at the largest text scale the
// bar allows. The bar measures its labels once, with the label's own style
// and the bar's text scale, and decides for ALL its tabs, in this order:
//   1. every label whole on one line: the bar as it was;
//   2. else every label whole within two lines, broken only at a space and
//      never inside a word: every tab keeps two label lines, so the icons
//      stay level, and the bar is as tall as two lines need;
//   3. else every tab is its icon alone, the label being its tooltip and its
//      spoken name.
// A label is never cut and never drawn smaller than the theme's size; the
// decision is measured with the selected tab's weight (the heavier), so
// selecting a tab never changes it.
import 'package:flutter/material.dart';

/// How the bar draws its labels.
enum ShellBarLabels { oneLine, twoLines, none }

/// The style of a tab's label.
TextStyle shellBarLabelStyle(BuildContext context, {required bool selected}) =>
    (Theme.of(context).textTheme.labelMedium ?? const TextStyle()).copyWith(
      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
    );

TextPainter _painter(
  BuildContext context,
  String text,
  TextScaler scaler, {
  int? maxLines,
}) => TextPainter(
  text: TextSpan(
    text: text,
    style: shellBarLabelStyle(context, selected: true),
  ),
  textDirection: Directionality.of(context),
  textScaler: scaler,
  maxLines: maxLines,
);

/// The height of one label line at [scaler].
double shellBarLabelLineHeight(BuildContext context, TextScaler scaler) {
  final painter = _painter(context, 'Ag', scaler)..layout();
  final height = painter.height;
  painter.dispose();
  return height;
}

/// The decision for [labels] in tabs [tabWidth] wide at [scaler].
ShellBarLabels shellBarLabelsFor(
  BuildContext context, {
  required Iterable<String> labels,
  required double tabWidth,
  required TextScaler scaler,
}) {
  var oneLine = true;
  var twoLines = true;
  for (final label in labels) {
    final whole = _painter(context, label, scaler)..layout();
    final width = whole.width;
    whole.dispose();
    if (width <= tabWidth) continue;
    oneLine = false;
    // A word wider than the tab would be broken inside; two lines hold only
    // what a space can break.
    for (final word in label.split(' ')) {
      final w = _painter(context, word, scaler)..layout();
      final wordWidth = w.width;
      w.dispose();
      if (wordWidth > tabWidth) twoLines = false;
    }
    final wrapped = _painter(context, label, scaler, maxLines: 2)
      ..layout(maxWidth: tabWidth);
    if (wrapped.didExceedMaxLines) twoLines = false;
    wrapped.dispose();
  }
  if (oneLine) return ShellBarLabels.oneLine;
  return twoLines ? ShellBarLabels.twoLines : ShellBarLabels.none;
}
