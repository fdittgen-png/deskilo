// SPDX-License-Identifier: 0BSD
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/invoice_pdf_template.dart';
import '../../domain/invoice_report.dart';
import '../../providers/money_providers.dart';
import 'report_page_style.dart';
import 'report_preview.dart';
import 'report_visual_editor.dart';

/// The PAGE-TRUE design surface (#548) — the professional-designer
/// model (Crystal Reports / DevExpress / Docentric): the three bands
/// are edited ON one white A4 page at the document's own margins, in
/// document order, with band strips as chrome, dashed page-break
/// guides where the PDF will paginate, a zoom control, and a
/// Design ↔ Preview toggle that merges the CURRENT unsaved bands with
/// live or sample data through the real report engine. Everything the
/// page shows draws through [ReportPage], the shared mirror of the PDF
/// renderer — the surface is the generated report.
class ReportPageDesigner extends ConsumerStatefulWidget {
  const ReportPageDesigner({
    super.key,
    required this.header,
    required this.body,
    required this.footer,
    required this.headerLabel,
    required this.bodyLabel,
    required this.footerLabel,
    required this.editorKeyPrefix,
    required this.previewData,
  });

  final TextEditingController header;
  final TextEditingController body;
  final TextEditingController footer;
  final String headerLabel;
  final String bodyLabel;
  final String footerLabel;

  /// Keys the three band editors so a document switch rebuilds them
  /// (the host bumps its epoch into this prefix).
  final String editorKeyPrefix;

  /// The data preview merges with — the host's live data, or its
  /// sample set.
  final Map<String, Object?> Function() previewData;

  @override
  ConsumerState<ReportPageDesigner> createState() =>
      _ReportPageDesignerState();
}

class _ReportPageDesignerState extends ConsumerState<ReportPageDesigner> {
  bool _preview = false;

  /// Page scale: null = fit the available width.
  double? _zoom;

  /// '100 %' — a number, not a translatable phrase.
  String _zoomLabel(double zoom) => '${(zoom * 100).round()} %';

  ReportBands get _bands => ReportBands(
        header: widget.header.text,
        body: widget.body.text,
        footer: widget.footer.text,
      );

  /// The white page: margins, guides, and [content] on the printable
  /// area. Print colors — never the app theme.
  Widget _page(Widget content) => Container(
        width: ReportPage.width,
        constraints:
            const BoxConstraints(minHeight: ReportPage.height),
        decoration: const BoxDecoration(
          color: ReportPage.paper,
          boxShadow: [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: ReportPage.margins,
        child: Stack(
          children: [
            // Margin + page-break guides: designer chrome over the
            // printable area, so the owner SEES the geometry the PDF
            // will honor.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: ReportPage.chrome.withValues(alpha: .25),
                      width: .5,
                    ),
                  ),
                  child: const CustomPaint(
                    painter: PageBreakGuidePainter(),
                  ),
                ),
              ),
            ),
            content,
          ],
        ),
      );

  /// Fit-to-width, or a fixed zoom with sideways panning.
  Widget _zoomed(Widget page) {
    final zoom = _zoom;
    if (zoom == null) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topCenter,
        child: page,
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: ReportPage.width * zoom,
        child: FittedBox(
          fit: BoxFit.fitWidth,
          alignment: Alignment.topLeft,
          child: page,
        ),
      ),
    );
  }

  Widget _designContent() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ReportVisualEditor(
            key: ValueKey('${widget.editorKeyPrefix}-header'),
            controller: widget.header,
            label: widget.headerLabel,
            bandKey: 'visual-header',
          ),
          ReportVisualEditor(
            key: ValueKey('${widget.editorKeyPrefix}-body'),
            controller: widget.body,
            label: widget.bodyLabel,
            bandKey: 'visual-body',
          ),
          ReportVisualEditor(
            key: ValueKey('${widget.editorKeyPrefix}-footer'),
            controller: widget.footer,
            label: widget.footerLabel,
            bandKey: 'visual-footer',
          ),
        ],
      );

  Widget _previewContent(AppLocalizations? l10n) {
    final report = renderReportBands(
      bands: _bands,
      data: widget.previewData(),
    );
    if (report == null) {
      return Text(
        l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
        key: const ValueKey('report-designer-preview-error'),
        style: const TextStyle(fontSize: 10, color: ReportPage.accent),
      );
    }
    final images = <String, Uint8List>{};
    for (final name in reportImageRefs(report)) {
      final bytes = ref.watch(reportImageBytesProvider(name)).value;
      if (bytes != null) images[name] = bytes;
    }
    return KeyedSubtree(
      key: const ValueKey('report-designer-preview'),
      child: ReportBlocksView(report: report, images: images),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            // Design ↔ Preview: the Docentric loop — same page, fields
            // or merged data.
            SegmentedButton<bool>(
              key: const ValueKey('report-designer-mode'),
              showSelectedIcon: false,
              style: const ButtonStyle(
                  visualDensity: VisualDensity.compact),
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.design_services_outlined,
                      size: 18),
                  label: Text(l10n?.reportDesignerDesign ?? 'Design'),
                ),
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: Text(l10n?.reportDesignerPreview ?? 'Preview'),
                ),
              ],
              selected: {_preview},
              onSelectionChanged: (selection) =>
                  setState(() => _preview = selection.first),
            ),
            const Spacer(),
            // A null-valued PopupMenuItem never reaches onSelected —
            // fit-width travels as the 0 sentinel instead.
            PopupMenuButton<double>(
              key: const ValueKey('report-designer-zoom'),
              tooltip: l10n?.reportDesignerZoom ?? 'Zoom',
              initialValue: _zoom ?? 0,
              onSelected: (zoom) =>
                  setState(() => _zoom = zoom == 0 ? null : zoom),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 0.0,
                  child:
                      Text(l10n?.reportDesignerZoomFit ?? 'Fit width'),
                ),
                for (final zoom in const [0.75, 1.0, 1.5])
                  PopupMenuItem(
                    value: zoom,
                    child: Text(_zoomLabel(zoom)),
                  ),
              ],
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.zoom_in, size: 20),
                  Text(
                    _zoom == null
                        ? (l10n?.reportDesignerZoomFit ?? 'Fit width')
                        : _zoomLabel(_zoom!),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ]),
              ),
            ),
          ],
        ),
        // The desk the paper lies on.
        Container(
          color: ReportPage.backdrop,
          padding: const EdgeInsets.all(12),
          child: _zoomed(
            _page(_preview ? _previewContent(l10n) : _designContent()),
          ),
        ),
      ],
    );
  }
}
