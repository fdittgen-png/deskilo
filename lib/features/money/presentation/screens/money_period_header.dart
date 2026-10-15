// SPDX-License-Identifier: AGPL-3.0-or-later




import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../domain/statement.dart';
import 'money_screen_ops.dart';

/// The period bar of the Money tab: previous month, the month's name, next
/// month (disabled on the running one) and, when the PDF export is on, the
/// bill export.
class MoneyPeriodHeader extends StatelessWidget {
  const MoneyPeriodHeader({
    super.key,
    required this.ops,
    required this.showExport,
    required this.statement,
  });

  final MoneyScreenOps ops;

  /// The `pdfExport` feature is on.
  final bool showExport;

  /// The visible month's statement; the export waits for it.
  final Statement? statement;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final visible = statement;
    final monthLabel = DateFormat.yMMMM(
      Localizations.maybeLocaleOf(context)?.toString(),
    ).format(ops.month);
    return Row(
      children: [
        IconButton(
          key: const ValueKey('money-chevron-left'),
          tooltip: MaterialLocalizations.of(context).previousMonthTooltip,
          icon: const Icon(Icons.chevron_left),
          onPressed: () => ops.shiftMonth(-1),
        ),
        Expanded(
          child: Text(
            monthLabel,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          key: const ValueKey('money-chevron-right'),
          tooltip: MaterialLocalizations.of(context).nextMonthTooltip,
          icon: const Icon(Icons.chevron_right),
          onPressed: ops.isCurrentPeriod ? null : () => ops.shiftMonth(1),
        ),
        if (showExport)
          IconButton(
            key: const ValueKey('money-bill-pdf-export'),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: l10n.billPdfExport,
            onPressed: visible == null ? null : () => ops.exportBill(visible),
          ),
      ],
    );
  }
}
