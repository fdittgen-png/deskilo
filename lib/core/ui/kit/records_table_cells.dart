// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4035 -- how a records table lays its cells out: each column holds its
// longest word, the same in the header and in every row.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import 'records_table_model.dart';

/// The cells of a row (or the header) in their columns.
Widget recordCells<T>(
  List<RecordColumn<T>> columns,
  List<Widget> cells, {
  Widget? leading,
  Widget? trailing,
  double? lineHeight,
  Map<String, double> mins = const {},
}) => Row(
  // #3614 — with [lineHeight], every cell is centred in the row's first
  // line: a cell that wraps (a state in two parts, #3773) grows downwards
  // and its neighbours stay level with its first line.
  crossAxisAlignment: lineHeight == null
      ? CrossAxisAlignment.center
      : CrossAxisAlignment.start,
  children: [
    ?leading,
    // #4035 — a column holds its longest word: where a share by flex would
    // not, the cells take widths that do (the same in the header and every
    // row, so they line up); otherwise flex alone decides, as it always did.
    Expanded(
      child: LayoutBuilder(
        builder: (context, box) {
          final widths = recordColumnWidths(columns, mins, box.maxWidth);
          return Row(
            crossAxisAlignment: lineHeight == null
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              for (final (i, c) in columns.indexed)
                recordCell(
                  c,
                  cells[i],
                  lineHeight: lineHeight,
                  width: widths?[i],
                ),
            ],
          );
        },
      ),
    ),
    ?trailing,
  ],
);

/// One cell in its column: [width] when the table decided it, else its flex.
Widget recordCell<T>(
  RecordColumn<T> c,
  Widget cell, {
  double? lineHeight,
  double? width,
}) {
  // A gap between neighbours: an end-aligned amount never touches the column
  // after it.
  final box = Container(
    constraints: BoxConstraints(minHeight: lineHeight ?? 0),
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    child: Align(
      heightFactor: 1,
      alignment: c.numeric
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: c.numeric
          ? DefaultTextStyle.merge(
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              child: cell,
            )
          : cell,
    ),
  );
  return width == null
      ? Expanded(flex: c.flex, child: box)
      : SizedBox(width: width, child: box);
}

/// The narrowest each of [columns] may be (by id) at the reader's text size
/// (#4035): its heading's longest word with the room of its sort control, or
/// its [RecordColumn.sample], whichever is wider, and the cell's side gaps.
Map<String, double> recordColumnMins<T>(
  BuildContext context,
  List<RecordColumn<T>> columns,
) {
  final theme = Theme.of(context);
  final scaler = MediaQuery.textScalerOf(context);
  final direction = Directionality.of(context);
  final heading = theme.textTheme.labelSmall;
  final body = theme.textTheme.bodyMedium;
  double word(String text, TextStyle? style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  double longestWord(String text, TextStyle? style) => text
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .fold(0.0, (widest, w) => math.max(widest, word(w, style)));

  return {
    for (final c in columns)
      c.id:
          2 * AppSpacing.sm +
          math.max(
            longestWord(c.label.toUpperCase(), heading) +
                (c.sortKey == null
                    // the sort button's own padding and its arrow
                    ? 0
                    : 2 * AppSpacing.xs + AppSpacing.md + AppSpacing.sm),
            c.sample == null ? 0 : word(c.sample!, body),
          ),
  };
}

/// The columns of [wanted] that fit [available] wide at the reader's text
/// size, with the narrowest width of each of [wanted] (#4035).
({List<RecordColumn<T>> columns, Map<String, double> mins}) fitRecordColumns<T>(
  BuildContext context,
  List<RecordColumn<T>> wanted,
  double available,
) {
  final mins = recordColumnMins(context, wanted);
  return (columns: columnsFitting(wanted, mins, available), mins: mins);
}
