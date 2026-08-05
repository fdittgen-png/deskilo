// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/invoice_report.dart';

/// The QUICK preview (#474): the report engine's blocks rendered as
/// Flutter widgets — instant, in-app, no PDF round-trip. The mapping
/// mirrors the PDF renderer's styles, so what you see here is what the
/// document will say (typography aside).
class ReportBlocksView extends StatelessWidget {
  const ReportBlocksView({super.key, required this.report});

  final InvoiceReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final muted = theme.colorScheme.onSurfaceVariant;

    Widget block(ReportBlock b) => switch (b) {
          ReportHeading(:final text) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(text,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
          ReportSubheading(:final text) => Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 3),
              child: Text(text.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: muted,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2)),
            ),
          ReportText(:final text) =>
            Text(text, style: theme.textTheme.bodyMedium),
          ReportMuted(:final text) => Text(text,
              style: theme.textTheme.bodySmall?.copyWith(color: muted)),
          ReportDivider() => Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              height: 2,
              color: accent),
          ReportSpacer() => const SizedBox(height: 8),
          // #482 — side-by-side columns; an empty first column pushes
          // the second (totals, the client box) to the right.
          ReportColumns(:final columns) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < columns.length; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [for (final c in columns[i]) block(c)],
                      ),
                    ),
                  ),
              ],
            ),
          ReportTableRow(:final cells, :final bold) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < cells.length; i++)
                    i == 0
                        ? Expanded(
                            child: Text(cells[i],
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(
                                        fontWeight: bold
                                            ? FontWeight.bold
                                            : null)),
                          )
                        : Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Text(cells[i],
                                textAlign: TextAlign.right,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(
                                        fontWeight: bold
                                            ? FontWeight.bold
                                            : null)),
                          ),
                ],
              ),
            ),
        };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in [...report.header, ...report.body]) block(b),
        if (report.footer.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final b in report.footer) block(b),
        ],
      ],
    );
  }
}

/// Opens the quick preview as a paper-like dialog.
Future<void> showReportQuickPreview(
  BuildContext context, {
  required InvoiceReport report,
  required bool simulated,
}) =>
    showDialog<void>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                  child: Text(
                    simulated
                        ? (l10n?.reportPreviewSimulated ??
                            'Quick preview — sample data')
                        : (l10n?.reportPreviewTitle ??
                            'Quick preview — your newest invoice'),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    key: const ValueKey('report-quick-preview'),
                    padding: AppSpacing.lgAll,
                    child: ReportBlocksView(report: report),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(
                        right: AppSpacing.sm, bottom: AppSpacing.xs),
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                          l10n?.directoryClose ?? 'Close'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
