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
//   `a | b`    → table row, last cell right-aligned (amounts)
//   `= a | b`  → bold table row (totals)
//   blank line → vertical spacing      anything else → body text
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

/// The three rendered bands of one invoice document.
class InvoiceReport {
  const InvoiceReport({
    required this.header,
    required this.body,
    required this.footer,
  });

  final List<ReportBlock> header;
  final List<ReportBlock> body;
  final List<ReportBlock> footer;
}

/// Renders [template]'s bands against [data]. Returns null when the
/// template defines no bands OR any band fails — the invoice then
/// renders with the built-in layout (a broken template must never block
/// a legal document).
InvoiceReport? renderInvoiceReport({
  required InvoicePdfTemplate template,
  required Map<String, Object?> data,
}) {
  if (!template.hasBands) return null;
  try {
    List<ReportBlock> band(String source) => parseReportMarkup(
          Template.parse(source, data: Map.of(data)).render(),
        );
    return InvoiceReport(
      header: band(template.header),
      body: band(template.body),
      footer: band(template.footer),
    );
  } catch (e, st) {
    TraceLogger.instance.warn(
        'money', 'invoice template failed — using the built-in layout',
        error: e, stackTrace: st);
    return null;
  }
}

/// Line-by-line markup → blocks; see the header comment for the rules.
List<ReportBlock> parseReportMarkup(String rendered) {
  final blocks = <ReportBlock>[];
  var pendingSpace = false;
  for (final raw in rendered.split('\n')) {
    final line = raw.trimRight();
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
