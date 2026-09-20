// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/invoice_report.dart';
import 'report_page_style.dart';
import '../../../../core/theme/app_radius.dart';

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
                  child: _ZoomablePages(
                    children: [
                      _PreviewSheet(report: report, images: images),
                      // #837 — each regrouped invoice on its own sheet
                      // below, never running into the one above it,
                      // stamped as the PDF stamps it.
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


/// #1217 — the quick preview, zoomable, and fitted to the width when it
/// opens.
///
/// An A4 sheet is 595 logical pixels wide and a phone dialog is about
/// 340, so the page used to open at 100 % inside a pair of nested
/// scrollers: the left margin was off-screen, "Total Hors Taxe" read as
/// "otal Hors Taxe", and the only way to read a line was to drag the
/// page sideways and lose your place vertically.
///
/// It opens at whatever scale shows the whole width — reading is the
/// point of a preview — and pinch or the buttons take it from there.
/// Never above 100 % on a wide screen: a 595 px document blown up to
/// fill a tablet is not what the paper looks like.
class _ZoomablePages extends StatefulWidget {
  const _ZoomablePages({required this.children});

  final List<Widget> children;

  /// What the buttons step by. A little more than a third per tap, so
  /// three taps roughly double it and nobody has to hold anything down.
  static const double step = 1.4;
  static const double minScale = 0.4;
  static const double maxScale = 5;

  @override
  State<_ZoomablePages> createState() => _ZoomablePagesState();
}

class _ZoomablePagesState extends State<_ZoomablePages> {
  final _transform = TransformationController();
  double? _fitted;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  double get _scale => _transform.value.getMaxScaleOnAxis();

  /// Fit the page's WIDTH, never magnifying past 100 %.
  double _fitFor(double viewport) =>
      ((viewport - AppSpacing.md * 2) / ReportPage.width).clamp(
        _ZoomablePages.minScale,
        1.0,
      );

  void _apply(double scale) {
    final clamped =
        scale.clamp(_ZoomablePages.minScale, _ZoomablePages.maxScale);
    final current = _transform.value.getMaxScaleOnAxis();
    if (current == 0) {
      return;
    }
    // Zoom about the CENTRE of what is on screen, so the line you were
    // reading is still the line you are reading.
    final factor = clamped / current;
    _transform.value = _transform.value.clone()
      ..multiply(Matrix4.diagonal3Values(factor, factor, factor));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ColoredBox(
      color: ReportPage.backdrop,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fit = _fitFor(constraints.maxWidth);
          // Re-fit when the viewport changes (a rotation), and once on
          // the first layout — but never while somebody is reading at
          // their own zoom.
          if (_fitted != fit) {
            _fitted = fit;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                // All three axes: `getMaxScaleOnAxis` — which is what
                // InteractiveViewer reads — returns the LARGEST of
                // them, so leaving z at 1 reports a zoom of 1 however
                // small the page is drawn.
                _transform.value =
                    Matrix4.diagonal3Values(fit, fit, fit);
              }
            });
          }
          return Stack(
            children: [
              InteractiveViewer(
                key: const ValueKey('report-quick-preview'),
                transformationController: _transform,
                constrained: false,
                minScale: _ZoomablePages.minScale,
                maxScale: _ZoomablePages.maxScale,
                boundaryMargin: const EdgeInsets.all(AppSpacing.lg),
                child: Padding(
                  padding: AppSpacing.mdAll,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: widget.children,
                  ),
                ),
              ),
              Positioned(
                right: AppSpacing.sm,
                bottom: AppSpacing.sm,
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  elevation: 2,
                  borderRadius: AppRadius.lgAll,
                  clipBehavior: Clip.antiAlias,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: const ValueKey('preview-zoom-out'),
                        tooltip: l10n?.reportPreviewZoomOut ?? 'Zoom out',
                        onPressed: _scale <= _ZoomablePages.minScale + 1e-6
                            ? null
                            : () => _apply(_scale / _ZoomablePages.step),
                        icon: const Icon(Icons.remove),
                      ),
                      IconButton(
                        key: const ValueKey('preview-zoom-fit'),
                        tooltip: l10n?.reportPreviewFit ?? 'Fit the width',
                        onPressed: () => _apply(_fitted ?? 1),
                        icon: const Icon(Icons.fit_screen_outlined),
                      ),
                      IconButton(
                        key: const ValueKey('preview-zoom-in'),
                        tooltip: l10n?.reportPreviewZoomIn ?? 'Zoom in',
                        onPressed: _scale >= _ZoomablePages.maxScale - 1e-6
                            ? null
                            : () => _apply(_scale * _ZoomablePages.step),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

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
