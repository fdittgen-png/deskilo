// SPDX-License-Identifier: AGPL-3.0-or-later
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
//   XL (#2898) is a picture the page is about — a level's plan.
//   `:::` … `|||` … `:::` → side-by-side columns (#482): the fenced
//   region is split at `|||` into equal-width columns, each parsed with
//   the same markup. An empty first column pushes the second to the
//   right — the classic seller-left/client-right address row and the
//   right-aligned totals block of a French facture.
//
// A band that fails to parse or render NEVER blocks an invoice: the
// caller falls back to the built-in layout.
//
// #4160 -- the block vocabulary, the markup parser and the rendered bands moved
// to the neutral document model (package:deskilo_document_model/report_blocks.dart);
// what stays here is the LIQUID expansion, the invoice placeholder defaults
// and the report-kind policy. This file re-exports the neutral names so the
// in-repository callers keep working.
import 'package:deskilo_document_model/report_blocks.dart';
import 'package:liquify/liquify.dart';

import '../../../core/trace/trace_logger.dart';
import 'invoice_pdf_template.dart';
import 'report_kind.dart';

export 'package:deskilo_document_model/report_blocks.dart';

/// The rendered bands of one invoice document (the neutral [RenderedReport]).
typedef InvoiceReport = RenderedReport;

/// The report-kind policy over the neutral bands.
extension InvoiceReportKind on RenderedReport {
  /// This report with page 1 numbered when the kind [kindId] asks for it.
  RenderedReport numberedFor(String kindId) =>
      withNumberFirstPage(reportKindById(kindId)?.numbersFirstPage ?? false);
}

/// Renders ONE band set (#472: the invoice's own, or a reminder
/// level's). Same contract: null on empty or broken bands.
RenderedReport? renderReportBands({
  required ReportBands bands,
  required Map<String, Object?> data,
}) {
  if (!bands.hasBands) return null;
  try {
    // #875 — seed every known placeholder first. An absent one must
    // be EMPTY, not nil, or `{% if x != "" %}` passes and the band
    // prints a bare label. The caller's data always wins.
    final seeded = <String, Object?>{
      ...InvoicePdfTemplate.placeholderDefaults,
      ...data,
    };
    List<ReportBlock> band(String source) => parseReportMarkup(
          Template.parse(source, data: Map.of(seeded)).render(),
        );
    return RenderedReport(
      header: band(bands.header),
      body: band(bands.body),
      footer: band(bands.footer),
      continuation: band(bands.continuation),
    );
  } on Object catch (e, st) {
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
    } on Object catch (e, st) {
      TraceLogger.instance.warn('money', 'report band $name failed',
          error: e, stackTrace: st);
      return '$name: $e';
    }
  }
  return null;
}
