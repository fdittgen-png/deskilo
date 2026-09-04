// SPDX-License-Identifier: 0BSD
//
// The invoice REPORTING engine (#470) — a rebuild of the classic banded
// report model (JasperReports/Crystal Reports): a header band, a detail
// band carrying the invoice lines, and a footer band. Each band is a
// LIQUID template (the template language built for end users —
// `{{ field }}`, `{% if %}`, `{% for %}`, filters), rendered against
// the invoice data; the rendered text then maps line-by-line onto PDF
// blocks through a small markup:
//
//   `# text`   → document title        `## text` → section heading
//   `> text`   → small muted text      `---`     → accent divider
//   `a | b`    → table row, cells after the first right-aligned
//   `= a | b`  → bold table row (headers, totals)
//   blank line → vertical spacing      anything else → body text
//   `![name]` → an image from the workspace's report-image library
//   (#488) — the logo, a stamp, a signature scan; unresolved names
//   render as nothing. `![name|size|align]` (#822) sizes it S/M/L and
//   aligns it left/center/right; a bare `![name]` stays medium, left.
//   `:::` … `|||` … `:::` → side-by-side columns (#482): the fenced
//   region is split at `|||` into equal-width columns, each parsed with
//   the same markup. An empty first column pushes the second to the
//   right — the classic seller-left/client-right address row and the
//   right-aligned totals block of a French facture.
//
// A band that fails to parse or render NEVER blocks an invoice: the
// caller falls back to the built-in layout.
import 'package:liquify/liquify.dart';

import '../../../core/trace/trace_logger.dart';
import 'invoice_pdf_template.dart';

/// One renderable block of a band.
sealed class ReportBlock {
  const ReportBlock();
}

class ReportHeading extends ReportBlock {
  const ReportHeading(this.text);
  final String text;
}

class ReportSubheading extends ReportBlock {
  const ReportSubheading(this.text);
  final String text;
}

class ReportText extends ReportBlock {
  const ReportText(this.text);
  final String text;
}

class ReportMuted extends ReportBlock {
  const ReportMuted(this.text);
  final String text;
}

class ReportDivider extends ReportBlock {
  const ReportDivider();
}

class ReportSpacer extends ReportBlock {
  const ReportSpacer();
}

class ReportTableRow extends ReportBlock {
  const ReportTableRow(this.cells, {this.bold = false});
  final List<String> cells;
  final bool bold;
}

/// An image reference (#488): `![name]` names a file in the workspace's
/// report-image library. The renderers resolve it to bytes; an unknown
/// name renders as nothing — a template must never break on a deleted
/// image.
class ReportImage extends ReportBlock {
  const ReportImage(
    this.name, {
    this.size = ReportImageSize.medium,
    this.align = ReportImageAlign.left,
  });

  /// `![name|size|align]` (#822) — the size and alignment are optional
  /// and order-free after the name; unknown words are ignored.
  factory ReportImage.parse(String inner) {
    final parts = inner.split('|').map((p) => p.trim()).toList();
    var size = ReportImageSize.medium;
    var align = ReportImageAlign.left;
    for (final part in parts.skip(1)) {
      size = ReportImageSize.values
              .where((v) => v.code == part.toLowerCase())
              .firstOrNull ??
          size;
      align = ReportImageAlign.values
              .where((v) => v.name == part.toLowerCase())
              .firstOrNull ??
          align;
    }
    return ReportImage(parts.first, size: size, align: align);
  }

  final String name;
  final ReportImageSize size;
  final ReportImageAlign align;

  /// The inner markup (`name|size|align`), the defaults left out so a
  /// plain `![logo]` round-trips as itself.
  String get markup => [
        name,
        if (size != ReportImageSize.medium) size.code,
        if (align != ReportImageAlign.left) align.name,
      ].join('|');
}

/// The image sizes a band can ask for (#822) — heights in points.
enum ReportImageSize {
  small('s', 40),
  medium('m', 64),
  large('l', 96);

  const ReportImageSize(this.code, this.height);
  final String code;
  final double height;
}

/// Where an image sits on its line (#822).
enum ReportImageAlign { left, center, right }

/// Side-by-side columns (#482) — each an independently parsed block
/// list, rendered equal-width. Nesting is not supported: an inner `:::`
/// simply closes the group.
class ReportColumns extends ReportBlock {
  const ReportColumns(this.columns);
  final List<List<ReportBlock>> columns;
}

/// The rendered bands of one invoice document.
class InvoiceReport {
  const InvoiceReport({
    required this.header,
    required this.body,
    required this.footer,
    this.continuation = const [],
  });

  final List<ReportBlock> header;
  final List<ReportBlock> body;
  final List<ReportBlock> footer;

  /// #872 — the header pages 2+ carry instead of the letterhead. Empty
  /// means the document draws its built-in identification strip.
  final List<ReportBlock> continuation;
}

/// Renders [template]'s bands against [data]. Returns null when the
/// template defines no bands OR any band fails — the invoice then
/// renders with the built-in layout (a broken template must never block
/// a legal document).
InvoiceReport? renderInvoiceReport({
  required InvoicePdfTemplate template,
  required Map<String, Object?> data,
}) =>
    renderReportBands(bands: template.invoiceBands, data: data);

/// Renders ONE band set (#472: the invoice's own, or a reminder
/// level's). Same contract: null on empty or broken bands.
InvoiceReport? renderReportBands({
  required ReportBands bands,
  required Map<String, Object?> data,
}) {
  if (!bands.hasBands) return null;
  try {
    List<ReportBlock> band(String source) => parseReportMarkup(
          Template.parse(source, data: Map.of(data)).render(),
        );
    return InvoiceReport(
      header: band(bands.header),
      body: band(bands.body),
      footer: band(bands.footer),
      continuation: band(bands.continuation),
    );
  } catch (e, st) {
    TraceLogger.instance.warn(
        'money', 'report bands failed — using the built-in layout',
        error: e, stackTrace: st);
    return null;
  }
}

/// #822 — WHY a band set fails, for the designer to show: the band
/// and the template engine's own message. Null when every band renders.
/// The renderers keep their null-on-failure contract; this is the
/// diagnosis beside it.
String? reportBandsError({
  required ReportBands bands,
  required Map<String, Object?> data,
}) {
  for (final (name, source) in [
    ('header', bands.header),
    ('body', bands.body),
    ('footer', bands.footer),
  ]) {
    try {
      Template.parse(source, data: Map.of(data)).render();
    } catch (e, st) {
      TraceLogger.instance.warn('money', 'report band $name failed',
          error: e, stackTrace: st);
      return '$name: $e';
    }
  }
  return null;
}

/// Every image name a rendered report references (#488) — what the
/// PDF builders must resolve to bytes before rendering.
Set<String> reportImageRefs(InvoiceReport report) {
  final refs = <String>{};
  void walk(List<ReportBlock> blocks) {
    for (final block in blocks) {
      if (block is ReportImage) refs.add(block.name);
      if (block is ReportColumns) block.columns.forEach(walk);
    }
  }

  walk(report.header);
  walk(report.body);
  walk(report.footer);
  return refs;
}

/// Line-by-line markup → blocks; see the header comment for the rules.
List<ReportBlock> parseReportMarkup(String rendered) =>
    _parseLines(rendered.split('\n'));

List<ReportBlock> _parseLines(List<String> lines) {
  final blocks = <ReportBlock>[];
  var pendingSpace = false;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trimRight();
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      // Collapse runs of blank lines into ONE spacer, and never lead
      // with one.
      pendingSpace = blocks.isNotEmpty;
      continue;
    }
    if (pendingSpace) {
      blocks.add(const ReportSpacer());
      pendingSpace = false;
    }
    if (trimmed == ':::') {
      // Column group (#482): collect to the closing fence, split at
      // `|||`, parse each column with the same rules.
      final columns = <List<String>>[[]];
      var j = i + 1;
      for (; j < lines.length && lines[j].trim() != ':::'; j++) {
        if (lines[j].trim() == '|||') {
          columns.add([]);
        } else {
          columns.last.add(lines[j]);
        }
      }
      i = j;
      blocks.add(ReportColumns(
        [for (final column in columns) _parseLines(column)],
      ));
      continue;
    }
    if (trimmed.startsWith('![') && trimmed.endsWith(']')) {
      blocks.add(ReportImage.parse(
          trimmed.substring(2, trimmed.length - 1).trim()));
      continue;
    }
    if (trimmed == '---') {
      blocks.add(const ReportDivider());
    } else if (trimmed.startsWith('## ')) {
      blocks.add(ReportSubheading(trimmed.substring(3).trim()));
    } else if (trimmed.startsWith('# ')) {
      blocks.add(ReportHeading(trimmed.substring(2).trim()));
    } else if (trimmed.startsWith('> ')) {
      blocks.add(ReportMuted(trimmed.substring(2).trim()));
    } else if (trimmed.contains('|')) {
      final bold = trimmed.startsWith('= ');
      final rowText = bold ? trimmed.substring(2) : trimmed;
      blocks.add(ReportTableRow(
        [for (final cell in rowText.split('|')) cell.trim()],
        bold: bold,
      ));
    } else {
      blocks.add(ReportText(trimmed));
    }
  }
  return blocks;
}
