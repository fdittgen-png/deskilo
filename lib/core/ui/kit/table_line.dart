// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-c -- a list line as a table row on a wide window: cells in
// columns that align under a [KitTableHeader] with the same [KitColumns].
// The numbers column and those after it sit at the end.
import 'package:flutter/material.dart';

/// The columns of a table: each column's share of the width, and the first
/// column that aligns to the end.
typedef KitColumns = ({List<int> flex, int endFrom});

Widget _cells(KitColumns columns, List<Widget> cells) => Row(
  children: [
    for (final (i, cell) in cells.indexed)
      Expanded(
        flex: columns.flex[i],
        child: Align(
          alignment: i >= columns.endFrom
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: cell,
        ),
      ),
  ],
);

/// The header of a wide table.
class KitTableHeader extends StatelessWidget {
  const KitTableHeader({
    super.key,
    required this.columns,
    required this.labels,
  });

  final KitColumns columns;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: _cells(columns, [
        for (final l in labels) Text(l.toUpperCase(), style: style),
      ]),
    );
  }
}

/// One row of a wide table; the whole row opens what it names.
class KitTableLine extends StatelessWidget {
  const KitTableLine({
    super.key,
    required this.columns,
    required this.cells,
    required this.onTap,
  });

  final KitColumns columns;
  final List<Widget> cells;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: _cells(columns, cells),
      ),
    ),
  );
}
