// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Parts of an analysis' figure: the line comparing it with another period,
// and (#3617) the figure on the dashboard that opens its rows beside it,
// from the result already on screen: no second question is asked.
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/adaptive/task_surface.dart';
import '../../../../core/ui/kit/dashboard_grid.dart';
import '../../domain/bi_result.dart';

/// "Compared with …: … (+…)" with the trend's mark.
class BiComparedLine extends StatelessWidget {
  const BiComparedLine({super.key, required this.change, required this.text});

  final BiChange change;
  final String text;

  @override
  Widget build(BuildContext context) {
    final direction = KpiTrendDirection.of(
      change.points ?? change.absolute ?? change.relative,
    );
    return Row(
      children: [
        if (direction != null) ...[
          KpiTrendMark(direction),
          const SizedBox(width: AppSpacing.xs),
        ],
        Flexible(child: Text(text, key: const ValueKey('bi-compared'))),
      ],
    );
  }
}

/// A figure that opens its [rows] beside the page (a side panel at the
/// desk, a sheet on a phone), under the [period] they cover.
class BiFigureOpen extends StatelessWidget {
  const BiFigureOpen({
    super.key,
    required this.period,
    required this.rows,
    required this.child,
  });

  final String period;
  final Widget rows;
  final Widget child;

  @override
  Widget build(BuildContext context) => InkWell(
    key: const ValueKey('bi-figure-open'),
    onTap: () => showTask<void>(
      context,
      size: TaskSize.standard,
      builder: (_) => SingleChildScrollView(
        key: const ValueKey('bi-figure-rows'),
        padding: AppSpacing.mdAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(period, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            rows,
          ],
        ),
      ),
    ),
    child: child,
  );
}
