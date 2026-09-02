// SPDX-License-Identifier: 0BSD
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/invoice_report.dart';
import 'report_page_style.dart';

/// The report blocks rendered as Flutter widgets with PRINT FIDELITY
/// (#474, refit in #548): every style, padding, color and the font
/// itself come from [ReportPage], the shared mirror of the PDF
/// renderer — what you see here IS what the document prints, typography
/// included. Always ink-on-paper, independent of the app theme.
class ReportBlocksView extends StatelessWidget {
  const ReportBlocksView({
    super.key,
    required this.report,
    this.images = const {},
  });

  final InvoiceReport report;

  /// #488 — resolved report-library images (name → bytes).
  final Map<String, Uint8List> images;

  @override
  Widget build(BuildContext context) {
    Widget block(ReportBlock b) => switch (b) {
          ReportHeading(:final text) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(text, style: ReportPage.heading),
            ),
          ReportSubheading(:final text) => Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 3),
              child:
                  Text(text.toUpperCase(), style: ReportPage.subheading),
            ),
          ReportText(:final text) => Text(text, style: ReportPage.body),
          ReportMuted(:final text) => Text(text, style: ReportPage.small),
          ReportDivider() => Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              height: 2,
              color: ReportPage.accent),
          ReportSpacer() => const SizedBox(height: 8),
          // #488 — a library image; unresolved names render nothing.
          ReportImage(:final name, :final size, :final align) =>
            images[name] == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Align(
                      // #822 — `![name|size|align]`, as the PDF draws it.
                      alignment: reportImageAlignment(align),
                      child: Image.memory(
                        images[name]!,
                        height: size.height,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
          // #482 — side-by-side columns; an empty first column pushes
          // the second (totals, the client box) to the right. 16pt
          // gutter, like the PDF.
          ReportColumns(:final columns) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < columns.length; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : 16),
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
                                style: ReportPage.row(bold: bold)),
                          )
                        : Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Text(cells[i],
                                textAlign: TextAlign.right,
                                style: ReportPage.row(bold: bold)),
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

/// Opens the quick preview as a PAGE (#548): white A4-wide paper at the
/// document's own margins, panning sideways on narrow screens instead
/// of reflowing — the preview never lies about the layout.
/// #837 — a document shown after the main one as reference, wearing the
/// stamp its PDF page wears.
typedef QuickPreviewAnnex = ({InvoiceReport report, String stamp});

Future<void> showReportQuickPreview(
  BuildContext context, {
  required InvoiceReport report,
  required bool simulated,
  Map<String, Uint8List> images = const {},
  List<QuickPreviewAnnex> annexes = const [],
}) =>
    showDialog<void>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
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
                  child: ColoredBox(
                    color: ReportPage.backdrop,
                    child: SingleChildScrollView(
                      key: const ValueKey('report-quick-preview'),
                      padding: AppSpacing.mdAll,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _PreviewSheet(report: report, images: images),
                            // #837 — each regrouped invoice on its own
                            // sheet below, never running into the one
                            // above it, stamped as the PDF stamps it.
                            for (final annex in annexes) ...[
                              const SizedBox(height: AppSpacing.lg),
                              _PreviewSheet(
                                key: ValueKey('preview-annex-${annex.stamp}'),
                                report: annex.report,
                                images: images,
                                stamp: annex.stamp,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
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

/// #837 — one sheet of the quick preview: the paper, and behind the
/// content the same diagonal stamp the PDF prints.
class _PreviewSheet extends StatelessWidget {
  const _PreviewSheet({
    super.key,
    required this.report,
    required this.images,
    this.stamp = '',
  });

  final InvoiceReport report;
  final Map<String, Uint8List> images;
  final String stamp;

  @override
  Widget build(BuildContext context) {
    final sheet = Container(
      width: ReportPage.width,
      color: ReportPage.paper,
      padding: ReportPage.margins,
      child: ReportBlocksView(report: report, images: images),
    );
    if (stamp.isEmpty) return sheet;
    return Stack(
      alignment: Alignment.center,
      children: [
        sheet,
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Transform.rotate(
                angle: -math.pi / 4,
                child: Opacity(
                  opacity: 0.5,
                  child: Text(
                    stamp.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFBDBDBD),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
